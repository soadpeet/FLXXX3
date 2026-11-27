#ifdef __ANDROID__

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include "soundio/androidusbaudio.h"

#include "controllers/midi/flx10jogscreen.h"
#include "controllers/supportedcontrollers.h"

#include <android/log.h>
#include <libusb.h>

#include <QJniEnvironment>
#include <QJniObject>
#include <QtCore/qnativeinterface.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <string>

namespace {
constexpr const char* kTag = "mixxx-usbaudio";
#define ULOG(...) __android_log_print(ANDROID_LOG_INFO, kTag, __VA_ARGS__)

void LIBUSB_CALL transferCallback(libusb_transfer* pTransfer) {
    static_cast<AndroidUsbAudio*>(pTransfer->user_data)->transferDone(pTransfer);
}

void LIBUSB_CALL inputTransferCallback(libusb_transfer* pTransfer) {
    static_cast<AndroidUsbAudio*>(pTransfer->user_data)->inputTransferDone(pTransfer);
}

void LIBUSB_CALL hidTransferCallback(libusb_transfer* pTransfer) {
    static_cast<AndroidUsbAudio*>(pTransfer->user_data)->hidTransferDone(pTransfer);
}

// Reports of the jog screens in flight at most (more are dropped: a newer one follows).
constexpr int kMaxHidOutPending = 64;

// Raises the calling thread to the audio priority of Android (Process.setThreadPriority).
void boostThread() {
    QJniObject::callStaticMethod<void>("android/os/Process",
            "setThreadPriority",
            "(I)V",
            static_cast<jint>(-19));
}

// Channel count and bytes per sample of an audio streaming alt setting, from its
// class specific descriptors (USB Audio Class 1 or 2). 0 if they are not there.
struct StreamFormat {
    int channels = 0;
    int bytesPerSample = 0;
};

StreamFormat streamFormatOf(const libusb_interface_descriptor& alt) {
    StreamFormat format;
    const bool uac2 = alt.bInterfaceProtocol == 0x20;
    const unsigned char* p = alt.extra;
    int left = alt.extra_length;
    while (left >= 2 && p[0] >= 2 && p[0] <= left) {
        const int length = p[0];
        if (p[1] == 0x24) { // CS_INTERFACE
            if (p[2] == 0x01 && uac2 && length >= 11) { // AS_GENERAL: bNrChannels
                format.channels = p[10];
            } else if (p[2] == 0x02 && length >= 6) { // FORMAT_TYPE
                if (uac2) {
                    format.bytesPerSample = p[4]; // bSubslotSize
                } else {
                    format.channels = p[4];       // bNrChannels
                    format.bytesPerSample = p[5]; // bSubframeSize
                }
            }
        }
        left -= length;
        p += length;
    }
    return format;
}

// Interface number and clock source id of a USB Audio Class 2 device (audio
// control interface), or -1.
void uac2ClockOf(const libusb_config_descriptor* pConfig, int* pInterface, int* pClockId) {
    *pInterface = -1;
    *pClockId = -1;
    for (int i = 0; i < pConfig->bNumInterfaces; ++i) {
        const libusb_interface& itf = pConfig->interface[i];
        for (int a = 0; a < itf.num_altsetting; ++a) {
            const libusb_interface_descriptor& alt = itf.altsetting[a];
            if (alt.bInterfaceClass != LIBUSB_CLASS_AUDIO || alt.bInterfaceSubClass != 1 ||
                    alt.bInterfaceProtocol != 0x20) {
                continue;
            }
            const unsigned char* p = alt.extra;
            int left = alt.extra_length;
            while (left >= 2 && p[0] >= 2 && p[0] <= left) {
                if (p[1] == 0x24 && p[2] == 0x0A && p[0] >= 4) { // CLOCK_SOURCE
                    *pInterface = alt.bInterfaceNumber;
                    *pClockId = p[3];
                    return;
                }
                left -= p[0];
                p += p[0];
            }
        }
    }
}

std::string hexOf(const unsigned char* p, int n) {
    std::string s;
    char b[4];
    for (int i = 0; i < n && i < 200; ++i) {
        snprintf(b, sizeof(b), "%02x ", p[i]);
        s += b;
    }
    return s;
}
} // namespace

AndroidUsbAudio::AndroidUsbAudio(int sampleRate, int channelCount, int chunkFrames, Render render)
        : m_sampleRate(sampleRate),
          m_channels(channelCount),
          m_chunkFrames(chunkFrames),
          m_render(std::move(render)) {
}

AndroidUsbAudio::~AndroidUsbAudio() {
    close();
}

bool AndroidUsbAudio::open() {
    m_ring.assign(static_cast<size_t>(m_ringFrames) * m_channels, 0.0f);
    m_writePos = 0;
    m_readPos = 0;
    m_rateAcc = 0;
    m_running = true;
    // Render the first block before the first packets go out (no start-up gap).
    {
        std::vector<float> first(static_cast<size_t>(m_chunkFrames) * m_channels);
        if (m_render(first.data(), m_chunkFrames)) {
            std::memcpy(m_ring.data(), first.data(), sizeof(float) * first.size());
            m_writePos.store(m_chunkFrames, std::memory_order_release);
        }
    }
    if (!connectUsb(true)) {
        m_running = false;
        return false;
    }
    m_renderThread = std::thread(&AndroidUsbAudio::renderLoop, this);
    m_superThread = std::thread(&AndroidUsbAudio::superviseLoop, this);
    ++s_activeCount;
    m_latencyMs = 1000.0 *
            (m_chunkFrames + m_transferCount * kMsPerTransfer * (m_sampleRate / 1000)) /
            m_sampleRate;
    ULOG("open ok, chunk %d frames, estimated latency %.1f ms", m_chunkFrames, m_latencyMs);
    return true;
}

bool AndroidUsbAudio::connectUsb(bool firstTime) {
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        return false;
    }
    // The names of all supported controllers, the helper opens the one plugged in.
    QStringList names;
    for (const auto& controller : flxxx3::kSupportedControllers) {
        names << QString::fromLatin1(controller.name);
    }
    const QJniObject name = QJniObject::fromString(names.join(QChar('|')));
    const jint fd = QJniObject::callStaticMethod<jint>("de/biggo/flxxx3/UsbAudioHelper",
            "openDevice",
            "(Landroid/content/Context;Ljava/lang/String;)I",
            context.object(),
            name.object<jstring>());
    if (fd < 0) {
        if (firstTime) {
            ULOG("could not open the device (%d)", static_cast<int>(fd));
        }
        return false;
    }

    libusb_set_option(nullptr, LIBUSB_OPTION_NO_DEVICE_DISCOVERY);
    int rc = libusb_init(&m_pContext);
    if (rc != 0) {
        ULOG("libusb_init failed: %s", libusb_error_name(rc));
        disconnectUsb();
        return false;
    }
    rc = libusb_wrap_sys_device(m_pContext, static_cast<intptr_t>(fd), &m_pHandle);
    if (rc != 0) {
        ULOG("libusb_wrap_sys_device failed: %s", libusb_error_name(rc));
        disconnectUsb();
        return false;
    }

    libusb_device* pDevice = libusb_get_device(m_pHandle);
    libusb_device_descriptor deviceDescriptor{};
    libusb_get_device_descriptor(pDevice, &deviceDescriptor);
    const flxxx3::SupportedController* pController = flxxx3::findSupportedController(
            deviceDescriptor.idVendor, deviceDescriptor.idProduct);
    if (firstTime) {
        ULOG("device %04x:%04x (%s), USB speed %d",
                deviceDescriptor.idVendor,
                deviceDescriptor.idProduct,
                pController ? pController->name : "unknown",
                libusb_get_device_speed(pDevice));
    }
    // What the maker's driver sends before the audio starts (DDJ-FLX10).
    if (pController) {
        for (int i = 0; i < pController->audioUnlockCount; ++i) {
            rc = libusb_control_transfer(m_pHandle,
                    0x40,
                    3,
                    pController->pAudioUnlock[i][0],
                    pController->pAudioUnlock[i][1],
                    nullptr,
                    0,
                    500);
            if (rc < 0) {
                ULOG("unlock request %d failed: %s", i, libusb_error_name(rc));
            }
        }
    }
    // High speed devices take a packet every (micro)frame interval, full speed
    // ones every 1 ms.
    const bool highSpeed = libusb_get_device_speed(pDevice) >= LIBUSB_SPEED_HIGH;

    libusb_config_descriptor* pConfig = nullptr;
    rc = libusb_get_active_config_descriptor(pDevice, &pConfig);
    if (rc != 0) {
        ULOG("no config descriptor: %s", libusb_error_name(rc));
        disconnectUsb();
        return false;
    }
    int bestAlt = -1;
    m_bytesPerSample = 0;
    m_inInterface = -1;
    m_inFrameBytes = 0;
    m_hidInterface = -1;
    m_hidOutEndpoint = 0;
    m_hidInEndpoint = 0;
    m_hidClaimed = false;
    m_hidFailed = false;
    for (int i = 0; i < pConfig->bNumInterfaces; ++i) {
        const libusb_interface& itf = pConfig->interface[i];
        for (int a = 0; a < itf.num_altsetting; ++a) {
            const libusb_interface_descriptor& alt = itf.altsetting[a];
            const StreamFormat format = streamFormatOf(alt);
            if (firstTime) {
                for (int e = 0; e < alt.bNumEndpoints; ++e) {
                    const libusb_endpoint_descriptor& ep = alt.endpoint[e];
                    ULOG("  interface %d alt %d class %d/%d/%d: %d ch, %d bytes, endpoint "
                         "0x%02x attributes 0x%02x max packet 0x%04x interval %d",
                            alt.bInterfaceNumber,
                            alt.bAlternateSetting,
                            alt.bInterfaceClass,
                            alt.bInterfaceSubClass,
                            alt.bInterfaceProtocol,
                            format.channels,
                            format.bytesPerSample,
                            ep.bEndpointAddress,
                            ep.bmAttributes,
                            ep.wMaxPacketSize,
                            ep.bInterval);
                }
            }
            // HID interface with an interrupt OUT endpoint: the jog screens (DDJ-FLX10).
            if (alt.bInterfaceClass == LIBUSB_CLASS_HID && pController &&
                    pController->hidScreen) {
                for (int e = 0; e < alt.bNumEndpoints; ++e) {
                    const libusb_endpoint_descriptor& ep = alt.endpoint[e];
                    if ((ep.bmAttributes & 0x03) != LIBUSB_TRANSFER_TYPE_INTERRUPT) {
                        continue;
                    }
                    if (ep.bEndpointAddress & 0x80) {
                        m_hidInEndpoint = ep.bEndpointAddress;
                        m_hidInMaxPacket = ep.wMaxPacketSize & 0x7FF;
                    } else {
                        m_hidOutEndpoint = ep.bEndpointAddress;
                        m_hidOutMaxPacket = ep.wMaxPacketSize & 0x7FF;
                        m_hidInterface = alt.bInterfaceNumber;
                    }
                }
            }
            // The sound card's input (capture) stream: some devices (DDJ-FLX10)
            // clock their output from it (implicit feedback).
            for (int e = 0; e < alt.bNumEndpoints; ++e) {
                const libusb_endpoint_descriptor& ep = alt.endpoint[e];
                // Usage type data (0) or implicit feedback data (2), not feedback (1).
                if ((ep.bEndpointAddress & 0x80) == 0 ||
                        (ep.bmAttributes & 0x03) != LIBUSB_TRANSFER_TYPE_ISOCHRONOUS ||
                        ((ep.bmAttributes >> 4) & 0x3) == 1 || format.channels <= 0 ||
                        format.bytesPerSample <= 0) {
                    continue;
                }
                const int frameBytes = format.channels * format.bytesPerSample;
                if (frameBytes > m_inFrameBytes) {
                    m_inInterface = alt.bInterfaceNumber;
                    m_inAlt = alt.bAlternateSetting;
                    m_inEndpoint = ep.bEndpointAddress;
                    m_inFrameBytes = frameBytes;
                    m_inMaxPacket = (ep.wMaxPacketSize & 0x7FF) *
                            (highSpeed ? 1 + ((ep.wMaxPacketSize >> 11) & 0x3) : 1);
                }
            }
            for (int e = 0; e < alt.bNumEndpoints; ++e) {
                const libusb_endpoint_descriptor& ep = alt.endpoint[e];
                if ((ep.bEndpointAddress & 0x80) != 0 ||
                        (ep.bmAttributes & 0x03) != LIBUSB_TRANSFER_TYPE_ISOCHRONOUS) {
                    continue;
                }
                // High speed: bits 11..12 are extra transactions per microframe.
                const int maxPacket = (ep.wMaxPacketSize & 0x7FF) *
                        (highSpeed ? 1 + ((ep.wMaxPacketSize >> 11) & 0x3) : 1);
                const int interval = highSpeed
                        ? 1 << std::clamp(static_cast<int>(ep.bInterval) - 1, 0, 3)
                        : 1;
                const int packetsPerSecond = highSpeed ? 8000 / interval : 1000;
                const int framesPerPacket =
                        (m_sampleRate + packetsPerSecond - 1) / packetsPerSecond;
                for (int bytes = 2; bytes <= 4; ++bytes) {
                    bool fits;
                    if (format.channels > 0 && format.bytesPerSample > 0) {
                        // Described by the class descriptors (USB Audio Class 1 and 2):
                        // the largest packet must fit (45 frames at 44.1 kHz).
                        fits = format.channels == m_channels && format.bytesPerSample == bytes &&
                                maxPacket >= framesPerPacket * m_channels * bytes;
                    } else {
                        // Only the packet size: at 48 kHz 48 frames fit exactly.
                        fits = bytes <= 3 && !highSpeed &&
                                maxPacket / framesPerPacket == m_channels * bytes;
                    }
                    // Prefer 24 bit, then 32, then 16.
                    const auto rank = [](int b) {
                        return b == 3 ? 3 : (b == 4 ? 2 : (b == 2 ? 1 : 0));
                    };
                    if (fits && rank(bytes) > rank(m_bytesPerSample)) {
                        bestAlt = alt.bAlternateSetting;
                        m_interface = alt.bInterfaceNumber;
                        m_endpoint = ep.bEndpointAddress;
                        m_bytesPerSample = bytes;
                        m_maxPacket = maxPacket;
                        m_packetsPerSecond = packetsPerSecond;
                        m_uac2 = alt.bInterfaceProtocol == 0x20;
                        // Asynchronous devices tell the rate they want on a feedback
                        // endpoint. Not followed yet: logged, so that a device test shows it.
                        m_hasFeedback = false;
                        for (int f = 0; f < alt.bNumEndpoints; ++f) {
                            const libusb_endpoint_descriptor& fb = alt.endpoint[f];
                            if ((fb.bEndpointAddress & 0x80) != 0 &&
                                    ((fb.bmAttributes >> 4) & 0x3) == 1) {
                                m_hasFeedback = true;
                            }
                        }
                    }
                }
            }
        }
    }
    int clockInterface = -1;
    int clockId = -1;
    uac2ClockOf(pConfig, &clockInterface, &clockId);
    libusb_free_config_descriptor(pConfig);
    if (bestAlt < 0) {
        ULOG("no matching isochronous output alt setting");
        disconnectUsb();
        return false;
    }
    // 2 ms per transfer, as many packets as fit in it.
    m_packetsPerTransfer = std::max(1, kMsPerTransfer * m_packetsPerSecond / 1000);
    ULOG("using interface %d alt %d endpoint 0x%02x, %d bytes per sample, max packet %d, "
         "%d packets per second, UAC%d%s",
            m_interface,
            bestAlt,
            m_endpoint,
            m_bytesPerSample,
            m_maxPacket,
            m_packetsPerSecond,
            m_uac2 ? 2 : 1,
            m_hasFeedback ? ", has a feedback endpoint (not used)" : "");

    libusb_set_auto_detach_kernel_driver(m_pHandle, 1);
    rc = libusb_claim_interface(m_pHandle, m_interface);
    if (rc != 0) {
        ULOG("claim interface failed: %s", libusb_error_name(rc));
        m_interface = -1;
        disconnectUsb();
        return false;
    }
    rc = libusb_set_interface_alt_setting(m_pHandle, m_interface, bestAlt);
    if (rc != 0) {
        ULOG("set alt setting failed: %s", libusb_error_name(rc));
        disconnectUsb();
        return false;
    }
    if (m_uac2) {
        // UAC2: the rate belongs to the clock source of the audio control
        // interface. That interface must stay with the kernel driver: taking it
        // over shuts the whole USB sound card down, its MIDI port as well (the
        // DDJ-FLX10 then ignores every button). The controllers with UAC2 run
        // at one rate only (DDJ-FLX10: 44.1 kHz), so it is not set.
        ULOG("UAC2 clock %d on interface %d left as it is (%d Hz expected)",
                clockId,
                clockInterface,
                m_sampleRate);
    } else {
        // UAC1: sampling frequency control of the endpoint (errors are not fatal).
        unsigned char rate[3] = {
                static_cast<unsigned char>(m_sampleRate & 0xFF),
                static_cast<unsigned char>((m_sampleRate >> 8) & 0xFF),
                static_cast<unsigned char>((m_sampleRate >> 16) & 0xFF)};
        rc = libusb_control_transfer(m_pHandle, 0x22, 0x01, 0x0100, m_endpoint, rate, 3, 500);
        ULOG("set sample rate %d: %d", m_sampleRate, rc);
    }

    m_rateAcc = 0;
    m_pending = 0;
    m_inPending = 0;
    m_inputFrames.clear();
    if (pController && pController->implicitFeedback) {
        startInput();
    }
    m_slots.resize(m_transferCount);
    for (auto& slot : m_slots) {
        slot.buffer.assign(static_cast<size_t>(m_maxPacket) * m_packetsPerTransfer, 0);
        slot.pTransfer = libusb_alloc_transfer(m_packetsPerTransfer);
        libusb_fill_iso_transfer(slot.pTransfer,
                m_pHandle,
                static_cast<unsigned char>(m_endpoint),
                slot.buffer.data(),
                static_cast<int>(slot.buffer.size()),
                m_packetsPerTransfer,
                transferCallback,
                this,
                1000);
    }
    m_connected = true;
    // All transfers are submitted before the event thread starts: until then no
    // callback runs, so fill() and the input callback never run at the same time.
    for (auto& slot : m_slots) {
        fill(slot);
        rc = libusb_submit_transfer(slot.pTransfer);
        if (rc != 0) {
            ULOG("submit failed: %s", libusb_error_name(rc));
            m_eventThread = std::thread(&AndroidUsbAudio::eventLoop, this);
            disconnectUsb();
            return false;
        }
        ++m_pending;
    }
    m_eventThread = std::thread(&AndroidUsbAudio::eventLoop, this);
    if (m_hidInterface >= 0) {
        std::lock_guard<std::mutex> lock(s_screenMutex);
        s_pScreenDriver = this;
    }
    return true;
}

bool AndroidUsbAudio::sendScreenReport(const unsigned char* pData, int length) {
    std::lock_guard<std::mutex> lock(s_screenMutex);
    return s_pScreenDriver && s_pScreenDriver->sendHid(pData, length);
}

// Called with s_screenMutex held (disconnectUsb() takes it before it tears down).
bool AndroidUsbAudio::sendHid(const unsigned char* pData, int length) {
    if (!m_connected || m_hidFailed || m_hidInterface < 0 || length <= 0) {
        return false;
    }
    if (!m_hidClaimed) {
        // The kernel's HID driver is detached (auto detach of the handle).
        const int rc = libusb_claim_interface(m_pHandle, m_hidInterface);
        if (rc != 0) {
            ULOG("jog screens: claim HID interface %d failed: %s",
                    m_hidInterface,
                    libusb_error_name(rc));
            m_hidFailed = true;
            return false;
        }
        m_hidClaimed = true;
        // The device's reports to the host are read and thrown away.
        if (m_hidInEndpoint != 0 && m_hidInMaxPacket > 0) {
            m_hidInSlots.resize(2);
            for (auto& slot : m_hidInSlots) {
                slot.buffer.assign(static_cast<size_t>(m_hidInMaxPacket), 0);
                slot.pTransfer = libusb_alloc_transfer(0);
                libusb_fill_interrupt_transfer(slot.pTransfer,
                        m_pHandle,
                        static_cast<unsigned char>(m_hidInEndpoint),
                        slot.buffer.data(),
                        m_hidInMaxPacket,
                        hidTransferCallback,
                        this,
                        0);
                if (libusb_submit_transfer(slot.pTransfer) == 0) {
                    ++m_hidPending;
                }
            }
        }
        ULOG("jog screens: HID interface %d, out 0x%02x (%d bytes), in 0x%02x",
                m_hidInterface,
                m_hidOutEndpoint,
                m_hidOutMaxPacket,
                m_hidInEndpoint);
    }
    if (m_hidPending.load() >= kMaxHidOutPending) {
        return false;
    }
    const int size = m_hidOutMaxPacket > 0 ? std::min(length, m_hidOutMaxPacket) : length;
    libusb_transfer* pTransfer = libusb_alloc_transfer(0);
    auto* pBuffer = static_cast<unsigned char*>(std::malloc(static_cast<size_t>(size)));
    if (!pTransfer || !pBuffer) {
        libusb_free_transfer(pTransfer);
        std::free(pBuffer);
        return false;
    }
    std::memcpy(pBuffer, pData, static_cast<size_t>(size));
    libusb_fill_interrupt_transfer(pTransfer,
            m_pHandle,
            static_cast<unsigned char>(m_hidOutEndpoint),
            pBuffer,
            size,
            hidTransferCallback,
            this,
            200);
    pTransfer->flags = LIBUSB_TRANSFER_FREE_BUFFER;
    ++m_hidPending;
    if (libusb_submit_transfer(pTransfer) != 0) {
        --m_hidPending;
        libusb_free_transfer(pTransfer);
        return false;
    }
    return true;
}

// Events thread: an OUT report was sent (freed here) or an IN report came (submitted again).
void AndroidUsbAudio::hidTransferDone(libusb_transfer* pTransfer) {
    const bool isIn = (pTransfer->endpoint & 0x80) != 0;
    // FLXXX3: the input reports of the jog screens' interface carry the absolute position of
    // the jog wheels (16 bit counters at bytes 5-6 and 7-8, see flx10jogscreen.cpp).
    if (isIn && pTransfer->status == LIBUSB_TRANSFER_COMPLETED && pTransfer->actual_length >= 9) {
        const unsigned char* pData = pTransfer->buffer;
        const int left = pData[5] | (pData[6] << 8);
        const int right = pData[7] | (pData[8] << 8);
        if (left != m_lastJogLeft || right != m_lastJogRight) {
            m_lastJogLeft = left;
            m_lastJogRight = right;
            flxxx3::jogscreen::publishJogPosition(left, right);
        }
    }
    if (isIn && m_connected && pTransfer->status != LIBUSB_TRANSFER_NO_DEVICE &&
            pTransfer->status != LIBUSB_TRANSFER_CANCELLED &&
            libusb_submit_transfer(pTransfer) == 0) {
        return;
    }
    --m_hidPending;
    if (!isIn) {
        libusb_free_transfer(pTransfer);
    }
}

void AndroidUsbAudio::fill(Slot& slot) {
    libusb_transfer* t = slot.pTransfer;
    unsigned char* p = slot.buffer.data();
    // The packets lie one after the other in the buffer (each as long as its
    // length), as libusb and the kernel expect.
    const int frameBytes = m_channels * m_bytesPerSample;
    for (int k = 0; k < m_packetsPerTransfer; ++k) {
        int frames;
        if (!m_inputFrames.empty()) {
            // Implicit feedback: as many frames as the device's input packet had.
            frames = m_inputFrames.front();
            m_inputFrames.pop_front();
        } else {
            m_rateAcc += m_sampleRate;
            frames = m_rateAcc / m_packetsPerSecond;
            m_rateAcc -= frames * m_packetsPerSecond;
        }
        frames = std::min(frames, m_maxPacket / frameBytes);
        const int bytes = frames * frameBytes;
        t->iso_packet_desc[k].length = bytes;
        const uint64_t r = m_readPos.load(std::memory_order_relaxed);
        const uint64_t w = m_writePos.load(std::memory_order_acquire);
        const bool have = (w - r) >= static_cast<uint64_t>(frames);
        if (!have) {
            ++m_underruns;
            std::memset(p, 0, bytes);
        } else {
            for (int f = 0; f < frames; ++f) {
                const float* src = &m_ring[((r + f) % m_ringFrames) * m_channels];
                for (int c = 0; c < m_channels; ++c) {
                    const float v = std::max(-1.0f, std::min(1.0f, src[c]));
                    if (m_bytesPerSample == 3) {
                        const int s = static_cast<int>(std::lrintf(v * 8388607.0f));
                        *p++ = static_cast<unsigned char>(s & 0xFF);
                        *p++ = static_cast<unsigned char>((s >> 8) & 0xFF);
                        *p++ = static_cast<unsigned char>((s >> 16) & 0xFF);
                    } else {
                        const int s = static_cast<int>(std::lrintf(v * 32767.0f));
                        *p++ = static_cast<unsigned char>(s & 0xFF);
                        *p++ = static_cast<unsigned char>((s >> 8) & 0xFF);
                    }
                }
            }
            m_readPos.store(r + frames, std::memory_order_release);
            m_cv.notify_one();
            continue;
        }
        p += bytes;
    }
}

bool AndroidUsbAudio::startInput() {
    if (m_inInterface < 0 || m_inInterface == m_interface || m_inFrameBytes <= 0) {
        ULOG("implicit feedback: no input stream found");
        return false;
    }
    int rc = libusb_claim_interface(m_pHandle, m_inInterface);
    if (rc != 0) {
        ULOG("implicit feedback: claim input interface %d failed: %s",
                m_inInterface,
                libusb_error_name(rc));
        return false;
    }
    rc = libusb_set_interface_alt_setting(m_pHandle, m_inInterface, m_inAlt);
    if (rc != 0) {
        ULOG("implicit feedback: input alt setting failed: %s", libusb_error_name(rc));
        libusb_release_interface(m_pHandle, m_inInterface);
        return false;
    }
    m_inClaimed = true;
    m_inSlots.resize(m_transferCount);
    for (auto& slot : m_inSlots) {
        slot.buffer.assign(static_cast<size_t>(m_inMaxPacket) * m_packetsPerTransfer, 0);
        slot.pTransfer = libusb_alloc_transfer(m_packetsPerTransfer);
        libusb_fill_iso_transfer(slot.pTransfer,
                m_pHandle,
                static_cast<unsigned char>(m_inEndpoint),
                slot.buffer.data(),
                static_cast<int>(slot.buffer.size()),
                m_packetsPerTransfer,
                inputTransferCallback,
                this,
                1000);
        libusb_set_iso_packet_lengths(slot.pTransfer, static_cast<unsigned int>(m_inMaxPacket));
    }
    // The event thread is not running yet: no callback can come before all are submitted.
    for (auto& slot : m_inSlots) {
        rc = libusb_submit_transfer(slot.pTransfer);
        if (rc != 0) {
            ULOG("implicit feedback: submit input failed: %s", libusb_error_name(rc));
            break;
        }
        ++m_inPending;
    }
    ULOG("implicit feedback: input interface %d alt %d endpoint 0x%02x, %d bytes per frame",
            m_inInterface,
            m_inAlt,
            m_inEndpoint,
            m_inFrameBytes);
    return true;
}

// Input packets of the device (events thread, like transferDone): their frame
// counts set the length of the next output packets.
void AndroidUsbAudio::inputTransferDone(libusb_transfer* pTransfer) {
    if (!m_running.load() || !m_connected || pTransfer->status == LIBUSB_TRANSFER_NO_DEVICE ||
            pTransfer->status == LIBUSB_TRANSFER_CANCELLED) {
        --m_inPending;
        return;
    }
    for (int k = 0; k < pTransfer->num_iso_packets; ++k) {
        const libusb_iso_packet_descriptor& packet = pTransfer->iso_packet_desc[k];
        if (packet.status == LIBUSB_TRANSFER_COMPLETED && packet.actual_length > 0) {
            m_inputFrames.push_back(static_cast<int>(packet.actual_length) / m_inFrameBytes);
        }
    }
    // Not more than about 20 ms ahead (the output may have started later).
    while (m_inputFrames.size() > static_cast<size_t>(m_packetsPerSecond / 50)) {
        m_inputFrames.pop_front();
    }
    if (libusb_submit_transfer(pTransfer) != 0) {
        --m_inPending;
    }
}

void AndroidUsbAudio::transferDone(libusb_transfer* pTransfer) {
    if (!m_running.load() || !m_connected) {
        --m_pending;
        return;
    }
    if (pTransfer->status == LIBUSB_TRANSFER_NO_DEVICE ||
            pTransfer->status == LIBUSB_TRANSFER_CANCELLED) {
        ULOG("transfer ended: status %d", pTransfer->status);
        --m_pending;
        return;
    }
    for (auto& slot : m_slots) {
        if (slot.pTransfer == pTransfer) {
            fill(slot);
            const int rc = libusb_submit_transfer(pTransfer);
            if (rc != 0) {
                ULOG("resubmit failed: %s", libusb_error_name(rc));
                --m_pending;
            }
            return;
        }
    }
}

void AndroidUsbAudio::renderLoop() {
    boostThread();
    double worstMs = 0.0;
    std::vector<float> chunk(static_cast<size_t>(m_chunkFrames) * m_channels);
    int lastUnderruns = 0;
    auto lastLog = std::chrono::steady_clock::now();
    while (m_running.load()) {
        const uint64_t w = m_writePos.load(std::memory_order_relaxed);
        const uint64_t r = m_readPos.load(std::memory_order_acquire);
        if (w - r < static_cast<uint64_t>(m_chunkFrames)) {
            const auto t0 = std::chrono::steady_clock::now();
            if (!m_render(chunk.data(), m_chunkFrames)) {
                break;
            }
            worstMs = std::max(worstMs,
                    std::chrono::duration<double, std::milli>(
                            std::chrono::steady_clock::now() - t0)
                            .count());
            for (int f = 0; f < m_chunkFrames; ++f) {
                std::memcpy(&m_ring[((w + f) % m_ringFrames) * m_channels],
                        &chunk[static_cast<size_t>(f) * m_channels],
                        sizeof(float) * m_channels);
            }
            m_writePos.store(w + m_chunkFrames, std::memory_order_release);
            continue;
        }
        std::unique_lock<std::mutex> lock(m_mutex);
        m_cv.wait_for(lock, std::chrono::microseconds(500));
        const auto now = std::chrono::steady_clock::now();
        if (now - lastLog > std::chrono::seconds(5)) {
            lastLog = now;
            const int u = m_underruns.load();
            if (u != lastUnderruns) {
                ULOG("underruns: %d, slowest render %.1f ms (chunk %d frames)",
                        u,
                        worstMs,
                        m_chunkFrames);
                worstMs = 0.0;
                lastUnderruns = u;
            }
        }
    }
}

void AndroidUsbAudio::eventLoop() {
    boostThread();
    while (m_connected || m_pending.load() > 0 || m_inPending.load() > 0 ||
            m_hidPending.load() > 0) {
        timeval tv{0, 100000};
        libusb_handle_events_timeout_completed(m_pContext, &tv, nullptr);
    }
}

void AndroidUsbAudio::disconnectUsb() {
    {
        // No more reports of the jog screens (a send in progress finishes first).
        std::lock_guard<std::mutex> lock(s_screenMutex);
        if (s_pScreenDriver == this) {
            s_pScreenDriver = nullptr;
        }
    }
    m_connected = false;
    for (auto& slot : m_hidInSlots) {
        if (slot.pTransfer && m_hidPending.load() > 0) {
            libusb_cancel_transfer(slot.pTransfer);
        }
    }
    for (auto& slot : m_slots) {
        if (slot.pTransfer && m_pending.load() > 0) {
            libusb_cancel_transfer(slot.pTransfer);
        }
    }
    for (auto& slot : m_inSlots) {
        if (slot.pTransfer && m_inPending.load() > 0) {
            libusb_cancel_transfer(slot.pTransfer);
        }
    }
    if (m_eventThread.joinable()) {
        // The event loop ends once all transfers came back.
        for (int i = 0; i < 50 &&
                (m_pending.load() > 0 || m_inPending.load() > 0 || m_hidPending.load() > 0);
                ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
        m_pending = 0;
        m_inPending = 0;
        m_hidPending = 0;
        m_eventThread.join();
    }
    for (auto& slot : m_slots) {
        if (slot.pTransfer) {
            libusb_free_transfer(slot.pTransfer);
            slot.pTransfer = nullptr;
        }
    }
    m_slots.clear();
    for (auto& slot : m_inSlots) {
        if (slot.pTransfer) {
            libusb_free_transfer(slot.pTransfer);
            slot.pTransfer = nullptr;
        }
    }
    m_inSlots.clear();
    for (auto& slot : m_hidInSlots) {
        if (slot.pTransfer) {
            libusb_free_transfer(slot.pTransfer);
            slot.pTransfer = nullptr;
        }
    }
    m_hidInSlots.clear();
    if (m_pHandle) {
        if (m_hidClaimed) {
            libusb_release_interface(m_pHandle, m_hidInterface);
            m_hidClaimed = false;
        }
        if (m_interface >= 0) {
            libusb_release_interface(m_pHandle, m_interface);
        }
        if (m_inClaimed) {
            libusb_release_interface(m_pHandle, m_inInterface);
        }
        libusb_close(m_pHandle);
        m_pHandle = nullptr;
    }
    m_interface = -1;
    m_inClaimed = false;
    if (m_pContext) {
        libusb_exit(m_pContext);
        m_pContext = nullptr;
    }
    QJniObject::callStaticMethod<void>("de/biggo/flxxx3/UsbAudioHelper", "close", "()V");
}

// Notices when the controller was unplugged (all transfers ended) and connects again
// once it is plugged in: the mixer keeps its clock, only the output pauses.
void AndroidUsbAudio::superviseLoop() {
    while (m_running.load()) {
        std::this_thread::sleep_for(std::chrono::milliseconds(300));
        if (!m_running.load()) {
            break;
        }
        if (m_connected && m_pending.load() <= 0) {
            ULOG("device lost");
            disconnectUsb();
        }
        if (!m_connected) {
            if (connectUsb(false)) {
                ULOG("device connected again");
            }
        }
    }
}

void AndroidUsbAudio::close() {
    if (m_running.exchange(false)) {
        m_cv.notify_all();
        if (m_superThread.joinable()) {
            m_superThread.join();
        }
        if (m_renderThread.joinable()) {
            m_renderThread.join();
        }
        disconnectUsb();
        --s_activeCount;
        ULOG("closed, underruns %d", m_underruns.load());
    }
}

#endif // __ANDROID__
