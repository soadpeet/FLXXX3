#ifdef __ANDROID__

#include "soundio/androidopenslout.h"

#include <android/log.h>
#include <dlfcn.h>

#include <QFile>
#include <algorithm>
#include <thread>

namespace {
constexpr const char* kLogTag = "mixxx-audio";

// The interface IDs are read from libOpenSLES.so itself: the binary contains
// other definitions of the SL_IID_* variables (from a static library), whose
// values are not valid for the system library.
SLInterfaceID systemIid(const char* name) {
    static void* handle = dlopen("libOpenSLES.so", RTLD_NOW);
    if (!handle) {
        return nullptr;
    }
    auto* pIid = static_cast<SLInterfaceID*>(dlsym(handle, name));
    return pIid ? *pIid : nullptr;
}

void queueCallback(SLAndroidSimpleBufferQueueItf, void* context) {
    static_cast<AndroidOpenSLOutput*>(context)->bufferDone();
}
} // namespace

AndroidOpenSLOutput::AndroidOpenSLOutput(
        int sampleRate, int channelCount, int chunkFrames, Render render)
        : m_sampleRate(sampleRate),
          m_channelCount(channelCount),
          m_chunkFrames(chunkFrames),
          m_render(std::move(render)),
          m_float(static_cast<size_t>(chunkFrames) * channelCount, 0.f) {
}

AndroidOpenSLOutput::~AndroidOpenSLOutput() {
    close();
}

bool AndroidOpenSLOutput::open() {
    // Number of queued buffers (test: file ".../files/audio_bufs").
    {
        QFile file(QStringLiteral("/sdcard/Android/data/org.mixxx/files/audio_bufs"));
        if (file.open(QIODevice::ReadOnly)) {
            const int value = file.readAll().trimmed().toInt();
            if (value >= 1 && value <= 16) {
                m_bufferCount = value;
            }
        }
    }
    auto fail = [this](const char* step, SLresult r) {
        __android_log_print(ANDROID_LOG_WARN,
                kLogTag,
                "opensl: %s failed: %d",
                step,
                static_cast<int>(r));
        close();
        return false;
    };
    {
        QFile file(QStringLiteral("/sdcard/Android/data/org.mixxx/files/audio_mul"));
        if (file.open(QIODevice::ReadOnly)) {
            const int value = file.readAll().trimmed().toInt();
            if (value >= 1 && value <= 16) {
                m_blocksPerBuffer = value;
            }
        }
    }
    m_pacing = !QFile::exists(QStringLiteral("/sdcard/Android/data/org.mixxx/files/audio_nopace"));
    SLresult result = slCreateEngine(&m_engineObj, 0, nullptr, 0, nullptr, nullptr);
    if (result != SL_RESULT_SUCCESS) {
        return fail("slCreateEngine", result);
    }
    SLEngineItf engine = nullptr;
    __android_log_print(ANDROID_LOG_INFO,
            kLogTag,
            "opensl: SL_IID_ENGINE=%p engineObj=%p",
            static_cast<const void*>(systemIid("SL_IID_ENGINE")),
            static_cast<const void*>(m_engineObj));
    if ((result = (*m_engineObj)->Realize(m_engineObj, SL_BOOLEAN_FALSE)) != SL_RESULT_SUCCESS) {
        return fail("engine Realize", result);
    }
    if ((result = (*m_engineObj)->GetInterface(m_engineObj, systemIid("SL_IID_ENGINE"), &engine)) !=
            SL_RESULT_SUCCESS) {
        return fail("engine GetInterface", result);
    }
    if ((result = (*engine)->CreateOutputMix(engine, &m_outputMix, 0, nullptr, nullptr)) !=
            SL_RESULT_SUCCESS) {
        return fail("CreateOutputMix", result);
    }
    if ((result = (*m_outputMix)->Realize(m_outputMix, SL_BOOLEAN_FALSE)) != SL_RESULT_SUCCESS) {
        return fail("outputmix Realize", result);
    }

    SLDataLocator_AndroidSimpleBufferQueue locator = {
            SL_DATALOCATOR_ANDROIDSIMPLEBUFFERQUEUE, static_cast<SLuint32>(m_bufferCount)};
    SLDataFormat_PCM format = {SL_DATAFORMAT_PCM,
            static_cast<SLuint32>(m_channelCount),
            static_cast<SLuint32>(m_sampleRate) * 1000,
            SL_PCMSAMPLEFORMAT_FIXED_16,
            SL_PCMSAMPLEFORMAT_FIXED_16,
            // FRONT_LEFT | FRONT_RIGHT | BACK_LEFT | BACK_RIGHT
            SL_SPEAKER_FRONT_LEFT | SL_SPEAKER_FRONT_RIGHT | SL_SPEAKER_BACK_LEFT |
                    SL_SPEAKER_BACK_RIGHT,
            SL_BYTEORDER_LITTLEENDIAN};
    SLDataSource source = {&locator, &format};
    SLDataLocator_OutputMix outLocator = {SL_DATALOCATOR_OUTPUTMIX, m_outputMix};
    SLDataSink sink = {&outLocator, nullptr};
    const SLInterfaceID ids[2] = {systemIid("SL_IID_ANDROIDSIMPLEBUFFERQUEUE"),
            systemIid("SL_IID_ANDROIDCONFIGURATION")};
    const SLboolean required[2] = {SL_BOOLEAN_TRUE, SL_BOOLEAN_TRUE};
    result = (*engine)->CreateAudioPlayer(engine, &m_playerObj, &source, &sink, 2, ids, required);
    if (result != SL_RESULT_SUCCESS) {
        return fail("CreateAudioPlayer", result);
    }
    SLAndroidConfigurationItf config;
    if ((result = (*m_playerObj)->GetInterface(m_playerObj, systemIid("SL_IID_ANDROIDCONFIGURATION"), &config)) ==
            SL_RESULT_SUCCESS) {
        SLuint32 performance = SL_ANDROID_PERFORMANCE_LATENCY;
        (*config)->SetConfiguration(
                config, SL_ANDROID_KEY_PERFORMANCE_MODE, &performance, sizeof(performance));
    } else {
        __android_log_print(ANDROID_LOG_WARN, kLogTag, "opensl: config interface failed: %d", static_cast<int>(result));
    }
    if ((result = (*m_playerObj)->Realize(m_playerObj, SL_BOOLEAN_FALSE)) != SL_RESULT_SUCCESS) {
        return fail("player Realize", result);
    }
    if ((result = (*m_playerObj)->GetInterface(m_playerObj, systemIid("SL_IID_PLAY"), &m_play)) !=
            SL_RESULT_SUCCESS) {
        return fail("player GetInterface PLAY", result);
    }
    if ((result = (*m_playerObj)->GetInterface(
                 m_playerObj, systemIid("SL_IID_ANDROIDSIMPLEBUFFERQUEUE"), &m_queue)) != SL_RESULT_SUCCESS) {
        return fail("player GetInterface BUFFERQUEUE", result);
    }
    (*m_queue)->RegisterCallback(m_queue, queueCallback, this);

    m_buffers.assign(m_bufferCount,
            std::vector<int16_t>(static_cast<size_t>(m_chunkFrames) * m_blocksPerBuffer * m_channelCount, 0));
    m_running = true;
    m_next = 0;
    for (int i = 0; i < m_bufferCount; ++i) {
        fillAndEnqueue(i);
    }
    m_next = 0;
    m_producedFrames = static_cast<int64_t>(m_bufferCount) * m_blocksPerBuffer * m_chunkFrames;
    m_leadFrames = m_producedFrames;
    m_startTime = std::chrono::steady_clock::now();
    if ((result = (*m_play)->SetPlayState(m_play, SL_PLAYSTATE_PLAYING)) != SL_RESULT_SUCCESS) {
        return fail("SetPlayState", result);
    }
    m_latencyMs = 1000.0 * m_chunkFrames * m_blocksPerBuffer * m_bufferCount / m_sampleRate;
    __android_log_print(ANDROID_LOG_INFO,
            kLogTag,
            "opensl output opened: rate=%d ch=%d chunk=%d buffers=%d blocks/buffer=%d",
            m_sampleRate,
            m_channelCount,
            m_chunkFrames,
            m_bufferCount,
            m_blocksPerBuffer);
    return true;
}

void AndroidOpenSLOutput::fillAndEnqueue(int index) {
    std::vector<int16_t>& buffer = m_buffers[index];
    const size_t blockSamples = static_cast<size_t>(m_chunkFrames) * m_channelCount;
    for (int block = 0; block < m_blocksPerBuffer; ++block) {
        const bool keepRunning = m_render(m_float.data(), m_chunkFrames);
        if (!keepRunning) {
            m_running = false;
        }
        int16_t* dst = buffer.data() + block * blockSamples;
        for (size_t i = 0; i < blockSamples; ++i) {
            const float v = std::clamp(m_float[i], -1.f, 1.f);
            dst[i] = static_cast<int16_t>(v * 32767.f);
        }
    }
    (*m_queue)->Enqueue(m_queue,
            buffer.data(),
            static_cast<SLuint32>(buffer.size() * sizeof(int16_t)));
}

void AndroidOpenSLOutput::bufferDone() {
    if (!m_running) {
        return;
    }
    const int index = m_next;
    m_next = (m_next + 1) % m_bufferCount;
    if (m_pacing) {
        // The next block is rendered only when the player has played so much of
        // what we gave it that at most "lead" frames are still waiting. The
        // position comes from the player itself (frames really consumed).
        const auto limit = std::chrono::steady_clock::now() + std::chrono::milliseconds(60);
        while (std::chrono::steady_clock::now() < limit) {
            SLmillisecond positionMs = 0;
            if ((*m_play)->GetPosition(m_play, &positionMs) != SL_RESULT_SUCCESS) {
                break;
            }
            const int64_t playedFrames = static_cast<int64_t>(positionMs) * m_sampleRate / 1000;
            if (m_producedFrames - playedFrames <= m_leadFrames) {
                break;
            }
            std::this_thread::sleep_for(std::chrono::milliseconds(1));
        }
    }
    m_producedFrames += static_cast<int64_t>(m_blocksPerBuffer) * m_chunkFrames;
    fillAndEnqueue(index);
}

void AndroidOpenSLOutput::close() {
    m_running = false;
    if (m_play) {
        (*m_play)->SetPlayState(m_play, SL_PLAYSTATE_STOPPED);
    }
    if (m_playerObj) {
        (*m_playerObj)->Destroy(m_playerObj);
        m_playerObj = nullptr;
        m_play = nullptr;
        m_queue = nullptr;
    }
    if (m_outputMix) {
        (*m_outputMix)->Destroy(m_outputMix);
        m_outputMix = nullptr;
    }
    if (m_engineObj) {
        (*m_engineObj)->Destroy(m_engineObj);
        m_engineObj = nullptr;
    }
}

#endif // __ANDROID__
