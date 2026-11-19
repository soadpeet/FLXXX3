#include "analyzer/analyzerebur128.h"

#include <QtDebug>
#include <algorithm>

#include "analyzer/analyzertrack.h"
#include "analyzer/constants.h"
#include "track/track.h"
#include "util/math.h"
#include "util/timer.h"

namespace {
constexpr double kReplayGain2ReferenceLUFS = -18;
} // anonymous namespace

AnalyzerEbur128::AnalyzerEbur128(UserSettingsPointer pConfig)
        : m_rgSettings(pConfig),
          m_pState(nullptr) {
}

AnalyzerEbur128::~AnalyzerEbur128() {
    cleanup(); // ...to prevent memory leaks
}

bool AnalyzerEbur128::initialize(
        const AnalyzerTrack& track,
        mixxx::audio::SampleRate sampleRate,
        mixxx::audio::ChannelCount channelCount,
        SINT frameLength) {
    if (m_rgSettings.isAnalyzerDisabled(2, track.getTrack()) || frameLength <= 0) {
        qDebug() << "Skipping AnalyzerEbur128";
        return false;
    }
    DEBUG_ASSERT(m_pState == nullptr);
    m_pState = ebur128_init(
            channelCount,
            sampleRate,
#ifdef FLXXX3
            // FLXXX3: also the loudest sample, so that AUTO GAIN never makes a track clip.
            EBUR128_MODE_I | EBUR128_MODE_SAMPLE_PEAK);
#else
            EBUR128_MODE_I);
#endif
    return m_pState != nullptr;
}

void AnalyzerEbur128::cleanup() {
    if (m_pState) {
        ebur128_destroy(&m_pState);
        // ebur128_destroy clears the pointer but let's not rely on that.
        m_pState = nullptr;
    }
}

bool AnalyzerEbur128::processSamples(const CSAMPLE* pIn, SINT count) {
    VERIFY_OR_DEBUG_ASSERT(m_pState) {
        return false;
    }
    ScopedTimer t(QStringLiteral("AnalyzerEbur128::processSamples()"));
    size_t frames = count / m_pState->channels;
    int e = ebur128_add_frames_float(m_pState, pIn, frames);
    VERIFY_OR_DEBUG_ASSERT(e == EBUR128_SUCCESS) {
        qWarning() << "AnalyzerEbur128::processSamples() failed with" << e;
        return false;
    }
    return true;
}

void AnalyzerEbur128::storeResults(TrackPointer pTrack) {
    VERIFY_OR_DEBUG_ASSERT(m_pState) {
        return;
    }
    double averageLufs;
    int e = ebur128_loudness_global(m_pState, &averageLufs);
    VERIFY_OR_DEBUG_ASSERT(e == EBUR128_SUCCESS) {
        qWarning() << "AnalyzerEbur128::storeResults() failed with" << e;
        return;
    }
    if (averageLufs == -HUGE_VAL ||
            averageLufs == HUGE_VAL ||
            // This catches 0 and abnormal values inf and -inf (that may have
            // slipped through in libebur128 for some reason.
            !util_isnormal(averageLufs)) {
        qWarning() << "AnalyzerEbur128::storeResults() averageLufs invalid:"
                   << averageLufs;
        return;
    }

    const double fReplayGain2 = kReplayGain2ReferenceLUFS - averageLufs;
    mixxx::ReplayGain replayGain(pTrack->getReplayGain());
    replayGain.setRatio(db2ratio(fReplayGain2));
#ifdef FLXXX3
    double peak = 0.0;
    for (unsigned int channel = 0; channel < m_pState->channels; ++channel) {
        double channelPeak = 0.0;
        if (ebur128_sample_peak(m_pState, channel, &channelPeak) == EBUR128_SUCCESS) {
            peak = std::max(peak, channelPeak);
        }
    }
    if (peak > 0.0) {
        replayGain.setPeak(static_cast<CSAMPLE>(peak));
    }
#endif
    pTrack->setReplayGain(replayGain);
    qDebug() << "ReplayGain 2.0 (libebur128) result is" << fReplayGain2
             << "dB for" << pTrack->getFileInfo();
}
