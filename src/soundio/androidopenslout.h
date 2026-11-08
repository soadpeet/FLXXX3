#pragma once

#ifdef __ANDROID__

#include <SLES/OpenSLES.h>
#include <SLES/OpenSLES_Android.h>

#include <atomic>
#include <chrono>
#include <cstdint>
#include <functional>
#include <vector>

// Android edition: 16 bit, 4 channel (positional QUAD mask) output through
// OpenSL ES with a buffer queue, the way Rekordbox opens the DDJ-FLX4. Android
// then opens a DIRECT output, and since only a few small buffers are queued,
// the latency stays low (about 30 ms in the measurements with Rekordbox).
class AndroidOpenSLOutput {
  public:
    // render fills `frames` frames of interleaved float samples and returns
    // false when the output should stop.
    using Render = std::function<bool(float* out, int frames)>;

    AndroidOpenSLOutput(int sampleRate, int channelCount, int chunkFrames, Render render);
    ~AndroidOpenSLOutput();

    bool open();
    void close();
    double latencyMs() const {
        return m_latencyMs;
    }

    void bufferDone();

  private:
    void fillAndEnqueue(int index);

    int m_sampleRate;
    int m_channelCount;
    int m_chunkFrames;
    int m_bufferCount = 3;
    // Mixer blocks per OpenSL buffer (test: file ".../files/audio_mul").
    int m_blocksPerBuffer = 1;
    Render m_render;
    std::vector<float> m_float;
    std::vector<std::vector<int16_t>> m_buffers;
    int m_next = 0;
    std::atomic<bool> m_running{false};
    // Real-time pacing: the next block is rendered not earlier than "lead"
    // frames before it is played. Without it Android fills the whole stream
    // buffer at once (the mixer renders much faster than real time) and the
    // latency grows to about 270 ms.
    std::chrono::steady_clock::time_point m_startTime;
    int64_t m_producedFrames = 0;
    int64_t m_leadFrames = 0;
    bool m_pacing = true;
    double m_latencyMs = 0.0;

    SLObjectItf m_engineObj = nullptr;
    SLObjectItf m_outputMix = nullptr;
    SLObjectItf m_playerObj = nullptr;
    SLPlayItf m_play = nullptr;
    SLAndroidSimpleBufferQueueItf m_queue = nullptr;
};

#endif // __ANDROID__
