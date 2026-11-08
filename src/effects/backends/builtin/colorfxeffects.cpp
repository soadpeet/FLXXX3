#include "effects/backends/builtin/colorfxeffects.h"

#include <algorithm>
#include <atomic>
#include <cmath>

#include "effects/backends/effectmanifest.h"
#include "engine/effects/engineeffectparameter.h"
#include "util/math.h"
#include "util/sample.h"

namespace {

constexpr float kPi = 3.14159265358979f;

float clampSample(float x) {
    return std::max(-1.0f, std::min(1.0f, x));
}

// white noise in -1 .. 1
float whiteNoise(uint32_t* pSeed) {
    *pSeed = *pSeed * 1664525u + 1013904223u;
    return static_cast<float>(static_cast<int32_t>(*pSeed)) / 2147483648.0f;
}

// While the effect is switched on or off the output is blended with the input
// (for the effects that replace the dry signal).
void blendWithDry(const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        EffectEnableState enableState) {
    if (enableState != EffectEnableState::Enabling &&
            enableState != EffectEnableState::Disabling) {
        return;
    }
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    for (SINT f = 0; f < frames; ++f) {
        const float t = static_cast<float>(f + 1) / static_cast<float>(frames);
        const float wet = enableState == EffectEnableState::Enabling ? t : 1.0f - t;
        for (SINT c = 0; c < channels; ++c) {
            const SINT i = f * channels + c;
            pOutput[i] = pOutput[i] * wet + pInput[i] * (1.0f - wet);
        }
    }
}

EffectManifestPointer baseManifest(const QString& id, const QString& name, const QString& description) {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(id);
    pManifest->setName(name);
    pManifest->setShortName(name);
    pManifest->setAuthor("Android edition");
    pManifest->setVersion("1.0");
    pManifest->setDescription(description);
    pManifest->setEffectRampsFromDry(true);
    pManifest->setMetaknobDefault(0.5);
    return pManifest;
}

} // namespace

// ---- state -----------------------------------------------------------------

void ColorFxState::audioParametersChanged(const mixxx::EngineParameters& engineParameters) {
    const double scale = engineParameters.sampleRate() / 44100.0;
    static const int combLengths[4] = {1116, 1188, 1277, 1356};
    static const int allpassLengths[2] = {556, 441};
    for (int ch = 0; ch < 2; ++ch) {
        for (int i = 0; i < 4; ++i) {
            comb[ch][i].assign(static_cast<size_t>((combLengths[i] + ch * 23) * scale), 0.f);
        }
        for (int i = 0; i < 2; ++i) {
            allpass[ch][i].assign(static_cast<size_t>((allpassLengths[i] + ch * 23) * scale), 0.f);
        }
    }
    delay.assign(static_cast<size_t>(kMaxDelaySeconds * engineParameters.sampleRate()) * 2, 0.f);
    clear();
}

void ColorFxState::clear() {
    for (int ch = 0; ch < 2; ++ch) {
        for (int i = 0; i < 4; ++i) {
            std::fill(comb[ch][i].begin(), comb[ch][i].end(), 0.f);
            combPos[ch][i] = 0;
            combStore[ch][i] = 0.f;
        }
        for (int i = 0; i < 2; ++i) {
            std::fill(allpass[ch][i].begin(), allpass[ch][i].end(), 0.f);
            allpassPos[ch][i] = 0;
        }
        feedbackLowPass[ch] = 0.f;
        held[ch] = 0.f;
        low[ch] = band[ch] = noiseLow[ch] = noiseBand[ch] = 0.f;
    }
    std::fill(delay.begin(), delay.end(), 0.f);
    delayPos = 0;
    holdCounter = 0;
    prevAmount = 0.f;
    smoothedAmount = 0.f;
}

// ---- base ------------------------------------------------------------------

// static
void ColorFxBase::addSidedParameters(const EffectManifestPointer& pManifest) {
    // One knob parameter that follows the filter knob 1:1 (0 = left end, 0.5 = centre
    // = off, 1 = right end). Mixxx' left / right link types do not fit an amount that
    // grows towards both ends.
    EffectManifestParameterPointer knob = pManifest->addParameter();
    knob->setId("knob");
    knob->setName(QObject::tr("Knob"));
    knob->setShortName(QObject::tr("Knob"));
    knob->setDescription(QObject::tr("Position of the filter knob: the centre is off"));
    knob->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    knob->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    knob->setDefaultLinkType(EffectManifestParameter::LinkType::Linked);
    knob->setNeutralPointOnScale(0.5);
    knob->setRange(0.0, 0.5, 1.0);
}

void ColorFxBase::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pKnob = parameters.value("knob");
}

namespace {
std::atomic<float> g_release{1.0f};
}

// static
void ColorFxBase::setRelease(float release) {
    g_release.store(std::clamp(release, 0.0f, 1.0f));
}

// static
float ColorFxBase::release() {
    return g_release.load();
}

void ColorFxBase::amountAndSide(float* pAmount, int* pSide) const {
    const float knob = static_cast<float>(math_clamp(m_pKnob->value(), 0.0, 1.0));
    *pAmount = std::abs(knob - 0.5f) * 2.0f * g_release.load();
    *pSide = knob < 0.5f ? -1 : 1;
}

// ============================ SPACE (reverb) ================================

// static
QString SpaceColorEffect::getId() {
    return "org.mixxx.effects.cfx_space";
}

// static
EffectManifestPointer SpaceColorEffect::getManifest() {
    auto pManifest = baseManifest(getId(),
            QObject::tr("Space"),
            QObject::tr("Reverb that grows towards both ends of the knob"));
    pManifest->setAddDryToWet(true);
    addSidedParameters(pManifest);
    return pManifest;
}

void SpaceColorEffect::processChannel(ColorFxState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState&) {
    float amount;
    int side;
    amountAndSide(&amount, &side);
    // the tail grows with the amount; the left half is darker
    const float feedback = 0.70f + 0.20f * amount;
    const float damp = side < 0 ? 0.55f : 0.25f;
    const float wetGain = amount * 1.6f;
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    for (SINT f = 0; f < frames; ++f) {
        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float in = pInput[f * channels + c] * 0.15f;
            float sum = 0.f;
            for (int i = 0; i < 4; ++i) {
                std::vector<float>& buf = pState->comb[ch][i];
                size_t& pos = pState->combPos[ch][i];
                const float out = buf[pos];
                pState->combStore[ch][i] = out * (1.f - damp) + pState->combStore[ch][i] * damp;
                buf[pos] = in + pState->combStore[ch][i] * feedback;
                pos = (pos + 1) % buf.size();
                sum += out;
            }
            for (int i = 0; i < 2; ++i) {
                std::vector<float>& buf = pState->allpass[ch][i];
                size_t& pos = pState->allpassPos[ch][i];
                const float bufOut = buf[pos];
                const float out = -sum + bufOut;
                buf[pos] = sum + bufOut * 0.5f;
                pos = (pos + 1) % buf.size();
                sum = out;
            }
            pOutput[f * channels + c] = clampSample(sum * wetGain);
        }
    }
    if (enableState == EffectEnableState::Disabling) {
        SampleUtil::applyRampingGain(pOutput, 1.0, 0.0, engineParameters.samplesPerBuffer());
        pState->clear();
    }
}

// =========================== DUB ECHO (echo) ================================

// static
QString DubEchoColorEffect::getId() {
    return "org.mixxx.effects.cfx_dubecho";
}

// static
EffectManifestPointer DubEchoColorEffect::getManifest() {
    auto pManifest = baseManifest(getId(),
            QObject::tr("Dub Echo"),
            QObject::tr("Echo with dark repeats that grows towards both ends of the knob"));
    pManifest->setAddDryToWet(true);
    addSidedParameters(pManifest);
    return pManifest;
}

void DubEchoColorEffect::processChannel(ColorFxState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    float amount;
    int side;
    amountAndSide(&amount, &side);
    // time: half a beat (left: a quarter of a beat)
    double seconds = groupFeatures.beat_length.has_value()
            ? groupFeatures.beat_length->seconds * (side < 0 ? 0.25 : 0.5)
            : (side < 0 ? 0.25 : 0.5);
    seconds = std::min(seconds, static_cast<double>(ColorFxState::kMaxDelaySeconds) - 0.1);
    const size_t length = pState->delay.size() / 2;
    const size_t delayFrames = std::min<size_t>(
            static_cast<size_t>(std::max(1.0, seconds * engineParameters.sampleRate())),
            length - 1);
    const float feedback = 0.35f + 0.45f * amount;
    // The repeats get darker (one pole low pass, about 2.5 kHz).
    const float lp = 1.0f - std::exp(-2.0f * kPi * 2500.0f / static_cast<float>(engineParameters.sampleRate()));
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    for (SINT f = 0; f < frames; ++f) {
        const float a = pState->prevAmount +
                (amount - pState->prevAmount) * static_cast<float>(f + 1) / frames;
        const size_t readPos = (pState->delayPos + length - delayFrames) % length;
        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float delayed = pState->delay[readPos * 2 + ch];
            pState->feedbackLowPass[ch] += lp * (delayed - pState->feedbackLowPass[ch]);
            pState->delay[pState->delayPos * 2 + ch] = clampSample(
                    pInput[f * channels + c] * a + pState->feedbackLowPass[ch] * feedback);
            pOutput[f * channels + c] = delayed * a * 1.5f;
        }
        pState->delayPos = (pState->delayPos + 1) % length;
    }
    if (enableState == EffectEnableState::Disabling) {
        SampleUtil::applyRampingGain(pOutput, 1.0, 0.0, engineParameters.samplesPerBuffer());
        pState->clear();
    } else {
        pState->prevAmount = amount;
    }
}

// ============================== CRUSH =======================================

// static
QString CrushColorEffect::getId() {
    return "org.mixxx.effects.cfx_crush";
}

// static
EffectManifestPointer CrushColorEffect::getManifest() {
    auto pManifest = baseManifest(getId(),
            QObject::tr("Crush"),
            QObject::tr("Bit and sample rate reduction that grows towards both ends of the knob"));
    addSidedParameters(pManifest);
    return pManifest;
}

void CrushColorEffect::processChannel(ColorFxState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState&) {
    float amount;
    int side;
    amountAndSide(&amount, &side);
    // bits: 16 down to 3; sample hold: 1 up to 40 samples
    const float bits = 16.0f - 13.0f * amount;
    const float levels = std::pow(2.0f, bits - 1.0f);
    const int hold = 1 + static_cast<int>(amount * amount * 40.0f);
    // the effect fades in over the first part of the knob
    const float wet = std::min(1.0f, amount * 4.0f);
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    for (SINT f = 0; f < frames; ++f) {
        if (pState->holdCounter <= 0) {
            for (int ch = 0; ch < 2; ++ch) {
                const float x = pInput[f * channels + std::min<int>(ch, channels - 1)];
                pState->held[ch] = std::round(clampSample(x) * levels) / levels;
            }
            pState->holdCounter = hold;
        }
        --pState->holdCounter;
        for (SINT c = 0; c < channels; ++c) {
            const float dry = pInput[f * channels + c];
            const float crushed = pState->held[std::min<int>(c, 1)];
            pOutput[f * channels + c] = dry * (1.0f - wet) + crushed * wet;
        }
    }
    blendWithDry(pInput, pOutput, engineParameters, enableState);
}

// ============================== SWEEP =======================================

// static
QString SweepColorEffect::getId() {
    return "org.mixxx.effects.cfx_sweep";
}

// static
EffectManifestPointer SweepColorEffect::getManifest() {
    auto pManifest = baseManifest(getId(),
            QObject::tr("Sweep"),
            QObject::tr("Resonant filter sweep: low pass to the left, high pass to the right"));
    addSidedParameters(pManifest);
    return pManifest;
}

void SweepColorEffect::processChannel(ColorFxState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState&) {
    float amount;
    int side;
    amountAndSide(&amount, &side);
    const double sampleRate = engineParameters.sampleRate();
    // The cutoff moves with the knob: left from 12 kHz down to 250 Hz (low pass),
    // right from 150 Hz up to 8 kHz (high pass). Resonant.
    const double a = amount;
    const double cutoff = side < 0 ? 12000.0 * std::pow(250.0 / 12000.0, a)
                                   : 150.0 * std::pow(8000.0 / 150.0, a);
    const float coef = static_cast<float>(2.0 * std::sin(M_PI * std::min(cutoff, sampleRate / 6.0) / sampleRate));
    const float damp = 0.35f;
    const float wet = std::min(1.0f, amount * 5.0f);
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    for (SINT f = 0; f < frames; ++f) {
        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float x = pInput[f * channels + c];
            pState->low[ch] += coef * pState->band[ch];
            const float high = x - pState->low[ch] - damp * pState->band[ch];
            pState->band[ch] += coef * high;
            const float filtered = side < 0 ? pState->low[ch] : high;
            pOutput[f * channels + c] = clampSample(x * (1.0f - wet) + filtered * wet);
        }
    }
    blendWithDry(pInput, pOutput, engineParameters, enableState);
}

// ============================== NOISE =======================================

// static
QString NoiseColorEffect::getId() {
    return "org.mixxx.effects.cfx_noise";
}

// static
EffectManifestPointer NoiseColorEffect::getManifest() {
    auto pManifest = baseManifest(getId(),
            QObject::tr("Noise"),
            QObject::tr("Adds filtered noise: dark to the left, bright to the right"));
    pManifest->setAddDryToWet(true);
    addSidedParameters(pManifest);
    return pManifest;
}

void NoiseColorEffect::processChannel(ColorFxState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState&) {
    float amount;
    int side;
    amountAndSide(&amount, &side);
    const double sampleRate = engineParameters.sampleRate();
    // Like the Pioneer NOISE: the noise comes in slowly and opens up while the knob is
    // turned further. Left: dark noise (low pass 400 Hz -> 3 kHz), right: bright noise
    // (high pass 7 kHz -> 1.8 kHz).
    const double cutoff = side < 0 ? 400.0 + 2600.0 * amount
                                   : 7000.0 - 5200.0 * amount;
    const float coef = static_cast<float>(2.0 * std::sin(M_PI * std::min(cutoff, sampleRate / 6.0) / sampleRate));
    const float damp = 1.2f;
    // soft start: quiet over the first half of the knob travel
    const float level = std::pow(amount, 2.2f) * 0.5f;
    const float prev = pState->smoothedAmount;
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    for (SINT f = 0; f < frames; ++f) {
        const float gain = (prev + (level - prev) * static_cast<float>(f + 1) / frames);
        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float n = whiteNoise(&pState->noiseSeed);
            pState->noiseLow[ch] += coef * pState->noiseBand[ch];
            const float high = n - pState->noiseLow[ch] - damp * pState->noiseBand[ch];
            pState->noiseBand[ch] += coef * high;
            const float shaped = side < 0 ? pState->noiseLow[ch] * 1.8f : high;
            pOutput[f * channels + c] = shaped * gain;
        }
    }
    if (enableState == EffectEnableState::Disabling) {
        SampleUtil::applyRampingGain(pOutput, 1.0, 0.0, engineParameters.samplesPerBuffer());
        pState->smoothedAmount = 0.f;
    } else {
        pState->smoothedAmount = level;
    }
}
