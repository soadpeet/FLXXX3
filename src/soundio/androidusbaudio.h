#pragma once

#ifdef __ANDROID__

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <functional>
#include <mutex>
#include <thread>
#include <vector>

struct libusb_context;
struct libusb_device_handle;
struct libusb_transfer;

// Android edition: own USB audio output for the DDJ-FLX4 (4 channels) with
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
    double latencyMs() const {
        return m_latencyMs;
    }

    // libusb callback (events thread)
    void transferDone(libusb_transfer* pTransfer);

  private:
    struct Slot {
        libusb_transfer* pTransfer = nullptr;
        std::vector<unsigned char> buffer;
    };

    // Opens the device and starts the isochronous transfers (also used again after
    // the FLX4 was unplugged and plugged in).
    bool connectUsb(bool firstTime);
    void disconnectUsb();
    void fill(Slot& slot);
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
    int m_packetsPerTransfer = 2;
    int m_transferCount = 4;
    std::vector<Slot> m_slots;
    std::atomic<int> m_pending{0};
    std::atomic<bool> m_connected{false};
    std::thread m_superThread;

    // Rate accumulator (frames per 1 ms packet: 48 at 48 kHz).
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
