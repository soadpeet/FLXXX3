// FLXXX3: limiter on the main output (see enginelimiter.h).
// AI disclaimer: written autonomously by an AI agent (Claude).

#include "engine/enginelimiter.h"

#include <algorithm>
#include <cmath>

void EngineLimiter::reset() {
    m_envelope = 0.0f;
    m_holdLeft = 0;
    m_lastReductionDb = 0.0;
}

void EngineLimiter::process(CSAMPLE* pBuffer, std::size_t numSamples, double sampleRate) {
    if (sampleRate <= 0.0) {
        return;
    }
    if (sampleRate != m_sampleRate) {
        m_sampleRate = sampleRate;
        m_releaseCoefficient = static_cast<float>(std::exp(-1.0 / (kReleaseSeconds * sampleRate)));
        m_holdSamples = static_cast<std::size_t>(kHoldSeconds * sampleRate);
    }
    float lowestGain = 1.0f;
    for (std::size_t i = 0; i + 1 < numSamples; i += 2) {
        const float peak = std::max(std::fabs(pBuffer[i]), std::fabs(pBuffer[i + 1]));
        if (peak >= m_envelope) {
            m_envelope = peak;
            m_holdLeft = m_holdSamples;
        } else if (m_holdLeft > 0) {
            --m_holdLeft;
        } else {
            m_envelope = std::max(peak, m_envelope * m_releaseCoefficient);
        }
        if (m_envelope > kCeiling) {
            // envelope >= peak, so the result stays at or below the ceiling.
            const float gain = kCeiling / m_envelope;
            pBuffer[i] *= gain;
            pBuffer[i + 1] *= gain;
            lowestGain = std::min(lowestGain, gain);
        }
    }
    m_lastReductionDb = lowestGain < 1.0f ? -20.0 * std::log10(lowestGain) : 0.0;
}
