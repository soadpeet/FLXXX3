#ifdef __ANDROID__

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include "soundio/androidusbaudio.h"

#include <android/log.h>
#include <libusb.h>

#include <QJniEnvironment>
#include <QJniObject>
#include <QtCore/qnativeinterface.h>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <string>

namespace {
constexpr const char* kTag = "mixxx-usbaudio";
#define ULOG(...) __android_log_print(ANDROID_LOG_INFO, kTag, __VA_ARGS__)

void LIBUSB_CALL transferCallback(libusb_transfer* pTransfer) {
    static_cast<AndroidUsbAudio*>(pTransfer->user_data)->transferDone(pTransfer);
}

// Raises the calling thread to the audio priority of Android (Process.setThreadPriority).
void boostThread() {
    QJniObject::callStaticMethod<void>("android/os/Process",
            "setThreadPriority",
            "(I)V",
            static_cast<jint>(-19));
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
    m_latencyMs = 1000.0 *
            (m_chunkFrames + m_transferCount * m_packetsPerTransfer * (m_sampleRate / 1000)) /
            m_sampleRate;
    ULOG("open ok, chunk %d frames, estimated latency %.1f ms", m_chunkFrames, m_latencyMs);
    return true;
}

bool AndroidUsbAudio::connectUsb(bool firstTime) {
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (!context.isValid()) {
        return false;
    }
    const QJniObject name = QJniObject::fromString(QStringLiteral("DDJ-FLX4"));
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

    libusb_config_descriptor* pConfig = nullptr;
    rc = libusb_get_active_config_descriptor(libusb_get_device(m_pHandle), &pConfig);
    if (rc != 0) {
        ULOG("no config descriptor: %s", libusb_error_name(rc));
        disconnectUsb();
        return false;
    }
    int bestAlt = -1;
    m_bytesPerSample = 0;
    for (int i = 0; i < pConfig->bNumInterfaces; ++i) {
        const libusb_interface& itf = pConfig->interface[i];
        for (int a = 0; a < itf.num_altsetting; ++a) {
            const libusb_interface_descriptor& alt = itf.altsetting[a];
            for (int e = 0; e < alt.bNumEndpoints; ++e) {
                const libusb_endpoint_descriptor& ep = alt.endpoint[e];
                if ((ep.bEndpointAddress & 0x80) == 0 &&
                        (ep.bmAttributes & 0x03) == LIBUSB_TRANSFER_TYPE_ISOCHRONOUS) {
                    const int perFrame = ep.wMaxPacketSize / 48;
                    for (int bytes = 3; bytes >= 2; --bytes) {
                        // Prefer 24 bit: the packet of 48 frames fits exactly.
                        if (perFrame == m_channels * bytes && bytes > m_bytesPerSample) {
                            bestAlt = alt.bAlternateSetting;
                            m_interface = alt.bInterfaceNumber;
                            m_endpoint = ep.bEndpointAddress;
                            m_bytesPerSample = bytes;
                            m_maxPacket = ep.wMaxPacketSize;
                        }
                    }
                }
            }
        }
    }
    libusb_free_config_descriptor(pConfig);
    if (bestAlt < 0) {
        ULOG("no matching isochronous output alt setting");
        disconnectUsb();
        return false;
    }
    ULOG("using interface %d alt %d endpoint 0x%02x, %d bytes per sample, max packet %d",
            m_interface,
            bestAlt,
            m_endpoint,
            m_bytesPerSample,
            m_maxPacket);

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
    // UAC1 sampling frequency control of the endpoint (errors are not fatal).
    unsigned char rate[3] = {
            static_cast<unsigned char>(m_sampleRate & 0xFF),
            static_cast<unsigned char>((m_sampleRate >> 8) & 0xFF),
            static_cast<unsigned char>((m_sampleRate >> 16) & 0xFF)};
    rc = libusb_control_transfer(m_pHandle, 0x22, 0x01, 0x0100, m_endpoint, rate, 3, 500);
    ULOG("set sample rate %d: %d", m_sampleRate, rc);

    m_rateAcc = 0;
    m_pending = 0;
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
    m_eventThread = std::thread(&AndroidUsbAudio::eventLoop, this);
    for (auto& slot : m_slots) {
        fill(slot);
        rc = libusb_submit_transfer(slot.pTransfer);
        if (rc != 0) {
            ULOG("submit failed: %s", libusb_error_name(rc));
            disconnectUsb();
            return false;
        }
        ++m_pending;
    }
    return true;
}

void AndroidUsbAudio::fill(Slot& slot) {
    libusb_transfer* t = slot.pTransfer;
    unsigned char* p = slot.buffer.data();
    for (int k = 0; k < m_packetsPerTransfer; ++k) {
        m_rateAcc += m_sampleRate;
        const int frames = m_rateAcc / 1000;
        m_rateAcc -= frames * 1000;
        const int bytes = frames * m_channels * m_bytesPerSample;
        t->iso_packet_desc[k].length = std::min(bytes, m_maxPacket);
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
            p += m_maxPacket - bytes;
            continue;
        }
        p += m_maxPacket;
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
    while (m_connected || m_pending.load() > 0) {
        timeval tv{0, 100000};
        libusb_handle_events_timeout_completed(m_pContext, &tv, nullptr);
    }
}

void AndroidUsbAudio::disconnectUsb() {
    m_connected = false;
    for (auto& slot : m_slots) {
        if (slot.pTransfer && m_pending.load() > 0) {
            libusb_cancel_transfer(slot.pTransfer);
        }
    }
    if (m_eventThread.joinable()) {
        // The event loop ends once all transfers came back.
        for (int i = 0; i < 50 && m_pending.load() > 0; ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(20));
        }
        m_pending = 0;
        m_eventThread.join();
    }
    for (auto& slot : m_slots) {
        if (slot.pTransfer) {
            libusb_free_transfer(slot.pTransfer);
            slot.pTransfer = nullptr;
        }
    }
    m_slots.clear();
    if (m_pHandle) {
        if (m_interface >= 0) {
            libusb_release_interface(m_pHandle, m_interface);
        }
        libusb_close(m_pHandle);
        m_pHandle = nullptr;
    }
    m_interface = -1;
    if (m_pContext) {
        libusb_exit(m_pContext);
        m_pContext = nullptr;
    }
    QJniObject::callStaticMethod<void>("de/biggo/flxxx3/UsbAudioHelper", "close", "()V");
}

// Notices when the FLX4 was unplugged (all transfers ended) and connects again
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
        ULOG("closed, underruns %d", m_underruns.load());
    }
}

#endif // __ANDROID__
