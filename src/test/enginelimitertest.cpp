// FLXXX3: tests of the main output limiter (src/engine/enginelimiter.*).
// AI disclaimer: written autonomously by an AI agent (Claude).

#include "engine/enginelimiter.h"

#include <gtest/gtest.h>

#include <cmath>
#include <vector>

namespace {

constexpr double kRate = 48000.0;

std::vector<CSAMPLE> sine(double amplitude, std::size_t frames, double hz = 440.0) {
    std::vector<CSAMPLE> buffer(frames * 2);
    for (std::size_t f = 0; f < frames; ++f) {
        const auto v = static_cast<CSAMPLE>(amplitude * std::sin(2.0 * M_PI * hz * f / kRate));
        buffer[2 * f] = v;
        buffer[2 * f + 1] = -v;
    }
    return buffer;
}

CSAMPLE peakOf(const std::vector<CSAMPLE>& buffer, std::size_t from = 0) {
    CSAMPLE peak = 0;
    for (std::size_t i = from; i < buffer.size(); ++i) {
        peak = std::max(peak, std::fabs(buffer[i]));
    }
    return peak;
}

TEST(EngineLimiterTest, QuietSignalIsUntouched) {
    EngineLimiter limiter;
    auto buffer = sine(0.9, 4800);
    const auto original = buffer;
    limiter.process(buffer.data(), buffer.size(), kRate);
    EXPECT_EQ(original, buffer);
    EXPECT_DOUBLE_EQ(0.0, limiter.lastReductionDb());
}

TEST(EngineLimiterTest, LoudSignalStaysBelowTheCeiling) {
    EngineLimiter limiter;
    auto buffer = sine(2.0, 4800); // +6 dB
    limiter.process(buffer.data(), buffer.size(), kRate);
    EXPECT_LE(peakOf(buffer), EngineLimiter::kCeiling + 1e-6f);
    EXPECT_GT(limiter.lastReductionDb(), 5.0);
}

TEST(EngineLimiterTest, BothChannelsGetTheSameGain) {
    EngineLimiter limiter;
    std::vector<CSAMPLE> buffer(2 * 480);
    for (std::size_t f = 0; f < 480; ++f) {
        buffer[2 * f] = 1.5f;  // loud left
        buffer[2 * f + 1] = 0.3f; // quiet right
    }
    limiter.process(buffer.data(), buffer.size(), kRate);
    for (std::size_t f = 0; f < 480; ++f) {
        EXPECT_NEAR(buffer[2 * f] / buffer[2 * f + 1], 5.0f, 1e-4f);
    }
}

TEST(EngineLimiterTest, GainComesBackAfterAPeak) {
    EngineLimiter limiter;
    auto loud = sine(2.0, 480);
    limiter.process(loud.data(), loud.size(), kRate);
    // Two seconds of a quiet signal: at the end it passes untouched again.
    auto quiet = sine(0.5, 96000);
    const auto original = quiet;
    limiter.process(quiet.data(), quiet.size(), kRate);
    const std::size_t lastTenth = quiet.size() * 9 / 10;
    for (std::size_t i = lastTenth; i < quiet.size(); ++i) {
        ASSERT_FLOAT_EQ(original[i], quiet[i]);
    }
}

} // namespace
