#pragma once

// FLXXX3: limiter on the main output, like the one built into the Pioneer
// mixers and players. AI disclaimer: written autonomously by an AI agent
// (Claude).
//
// It does nothing while the signal stays below the ceiling (-0.3 dBFS). A peak
// above it lowers the gain at once, so that the output never goes over the
// ceiling (no hard clipping in the sound card or the recording); the gain then
// comes back smoothly (release). Both channels get the same gain, so the
// stereo image stays. No look-ahead: it adds no latency (jog wheel, cues).

#include <cstddef>

#include "util/types.h"

class EngineLimiter {
  public:
    // Highest output level, linear (-0.3 dBFS).
    static constexpr CSAMPLE kCeiling = 0.966051f;
    // After a peak the gain is held this long (longer than one wave of a
    // 20 Hz bass, so the gain does not move within a wave: no distortion) ...
    static constexpr double kHoldSeconds = 0.05;
    // ... and then the reduction falls to about a third in this time.
    static constexpr double kReleaseSeconds = 0.2;

    // Processes an interleaved stereo buffer in place (numSamples = frames * 2).
    void process(CSAMPLE* pBuffer, std::size_t numSamples, double sampleRate);
    // Forgets the state (for example after the limiter was switched off).
    void reset();

    // Gain reduction of the last processed buffer in dB (0 = untouched), for
    // a display.
    double lastReductionDb() const {
        return m_lastReductionDb;
    }

  private:
    double m_sampleRate = 0.0;
    float m_releaseCoefficient = 0.0f;
    std::size_t m_holdSamples = 0;
    std::size_t m_holdLeft = 0;
    // Peak envelope: jumps up to a new peak at once, falls with the release.
    float m_envelope = 0.0f;
    double m_lastReductionDb = 0.0;
};
