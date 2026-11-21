#pragma once

#ifdef __ANDROID__

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <atomic>
#include <condition_variable>
#include <deque>
#include <cstdint>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

struct libusb_context;
struct libusb_device_handle;
struct libusb_transfer;

// Android edition: own USB audio output for the DDJ-FLX4 and DDJ-FLX10 (4 channels) with
// libusb, bypassing the Android audio stack (whose USB path adds 70..150 ms).
// The audio interface is taken over from the kernel driver, isochronous packets
// of 1 ms are sent directly, and the mixer is rendered just in time.
class AndroidUsbAudio {
  public:
    // render fills `frames` frames of interleaved float samples (channelCount)
    // and returns false when the output should stop.
    using Render = std::function<bool(float* out, int frames)>;

    AndroidUsbAudio(int sampleRate, int channelCount, int chunkFrames, Render render);
    ~AndroidUsbAudio();

    bool open();
    void close();
    /// True while an instance of the USB audio output is open.
    static bool isActive() {
        return s_activeCount.load() > 0;
    }
    double latencyMs() const {
        return m_latencyMs;
    }

    /// DDJ-FLX10: sends one report to the HID interface of the jog screens (the
    /// mapping script builds them). Any thread; false when no such device is open.
    static bool sendScreenReport(const unsigned char* pData, int length);

    // libusb callbacks (events thread)
    void transferDone(libusb_transfer* pTransfer);
    void inputTransferDone(libusb_transfer* pTransfer);
    void hidTransferDone(libusb_transfer* pTransfer);

  private:
    static inline std::atomic<int> s_activeCount{0};
    // The open driver whose device has a jog screen interface (guarded by s_screenMutex).
    static inline std::mutex s_screenMutex;
    static inline AndroidUsbAudio* s_pScreenDriver = nullptr;

    struct Slot {
        libusb_transfer* pTransfer = nullptr;
        std::vector<unsigned char> buffer;
    };

    // Opens the device and starts the isochronous transfers (also used again after
    // the controller was unplugged and plugged in).
    bool connectUsb(bool firstTime);
    void disconnectUsb();
    void fill(Slot& slot);
    // Starts the device's input stream (implicit feedback), see connectUsb().
    bool startInput();
    bool sendHid(const unsigned char* pData, int length);
    void renderLoop();
    void eventLoop();
    void superviseLoop();

    int m_sampleRate;
    int m_channels;
    int m_chunkFrames;
    Render m_render;

    libusb_context* m_pContext = nullptr;
    libusb_device_handle* m_pHandle = nullptr;
    int m_interface = -1;
    int m_endpoint = 0;
    int m_bytesPerSample = 3;
    int m_maxPacket = 0;
    // Each transfer carries 2 ms of sound.
    static constexpr int kMsPerTransfer = 2;
    int m_packetsPerTransfer = 2;
    // 1000 (full speed, DDJ-FLX4) or up to 8000 (high speed).
    int m_packetsPerSecond = 1000;
    bool m_uac2 = false;
    bool m_hasFeedback = false;
    int m_transferCount = 4;
    std::vector<Slot> m_slots;
    std::atomic<int> m_pending{0};

    // Input stream of the device for implicit feedback (DDJ-FLX10): its packets
    // are read and thrown away, only their frame counts are used.
    int m_inInterface = -1;
    int m_inAlt = 0;
    int m_inEndpoint = 0;
    int m_inMaxPacket = 0;
    int m_inFrameBytes = 0;
    bool m_inClaimed = false;
    std::vector<Slot> m_inSlots;
    std::atomic<int> m_inPending{0};
    // Frame counts of input packets not yet used for output (events thread only).
    std::deque<int> m_inputFrames;
    std::atomic<bool> m_connected{false};

    // HID interface of the jog screens (DDJ-FLX10): interrupt OUT for the reports,
    // interrupt IN read and thrown away (the device's acknowledgements).
    int m_hidInterface = -1;
    int m_hidOutEndpoint = 0;
    int m_hidOutMaxPacket = 0;
    int m_hidInEndpoint = 0;
    int m_hidInMaxPacket = 0;
    bool m_hidClaimed = false;
    bool m_hidFailed = false;
    std::vector<Slot> m_hidInSlots;
    // Transfers of the HID interface in flight (out and in).
    std::atomic<int> m_hidPending{0};
    std::thread m_superThread;

    // Rate accumulator (frames per packet: 48 at 48 kHz and 1000 packets a second,
    // 44 or 45 at 44.1 kHz).
    int m_rateAcc = 0;

    // Ring buffer of rendered frames (single producer / single consumer).
    std::vector<float> m_ring;
    int m_ringFrames = 16384;
    std::atomic<uint64_t> m_writePos{0};
    std::atomic<uint64_t> m_readPos{0};

    std::atomic<bool> m_running{false};
    std::thread m_renderThread;
    std::thread m_eventThread;
    std::mutex m_mutex;
    std::condition_variable m_cv;
    std::atomic<int> m_underruns{0};
    double m_latencyMs = 0.0;
};

#endif // __ANDROID__
