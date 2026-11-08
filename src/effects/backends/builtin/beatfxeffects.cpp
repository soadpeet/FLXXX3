#include "effects/backends/builtin/beatfxeffects.h"

#include <algorithm>

#include "effects/backends/effectmanifest.h"
#include "engine/effects/engineeffectparameter.h"
#include "util/math.h"
#include "util/sample.h"

namespace {

constexpr double kMinBeats = 1.0 / 16.0;

// Time of the effect in seconds: the first parameter is a number of beats (0 -
// 8); without a beat grid it is a number of seconds.
double periodSeconds(double beats, const GroupFeatureState& groupFeatures) {
    beats = std::max(beats, kMinBeats);
    if (groupFeatures.beat_length.has_value()) {
        return beats * groupFeatures.beat_length->seconds;
    }
    return beats;
}

EffectManifestParameterPointer addBeatsParameter(const EffectManifestPointer& pManifest) {
    EffectManifestParameterPointer beats = pManifest->addParameter();
    beats->setId("beats");
    beats->setName(QObject::tr("Time"));
    beats->setShortName(QObject::tr("Time"));
    beats->setDescription(QObject::tr("Length of the effect in beats"));
    beats->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    beats->setUnitsHint(EffectManifestParameter::UnitsHint::Beats);
    beats->setRange(0.0, 1.0, 8.0);
    return beats;
}

// The wet signal in pOutput replaces the dry signal. While the effect is
// switched on or off, the output is blended with the input over one buffer.
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

} // namespace

// ============================== TRANS ======================================

// static
QString TransEffect::getId() {
    return "org.mixxx.effects.trans";
}

// static
EffectManifestPointer TransEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Trans"));
    pManifest->setShortName(QObject::tr("Trans"));
    pManifest->setAuthor("Android edition");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Cuts the sound in the rhythm of the beat (gate)"));
    pManifest->setEffectRampsFromDry(true);

    addBeatsParameter(pManifest);

    EffectManifestParameterPointer depth = pManifest->addParameter();
    depth->setId("depth");
    depth->setName(QObject::tr("Depth"));
    depth->setShortName(QObject::tr("Depth"));
    depth->setDescription(QObject::tr("How much the sound is cut"));
    depth->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    depth->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    depth->setDefaultLinkType(EffectManifestParameter::LinkType::Linked);
    depth->setRange(0.0, 1.0, 1.0);

    EffectManifestParameterPointer gate = pManifest->addParameter();
    gate->setId("gate");
    gate->setName(QObject::tr("Gate"));
    gate->setShortName(QObject::tr("Gate"));
    gate->setDescription(QObject::tr("Part of the time in which the sound is open"));
    gate->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    gate->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    gate->setRange(0.1, 0.5, 0.9);
    return pManifest;
}

void TransEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pDepth = parameters.value("depth");
    m_pGate = parameters.value("gate");
}

void TransEffect::processChannel(TransGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    const double period = periodSeconds(m_pBeats->value(), groupFeatures);
    const double periodFrames = std::max(1.0, period * engineParameters.sampleRate());
    const float cut = static_cast<float>(math_clamp(m_pDepth->value(), 0.0, 1.0));
    const double duty = math_clamp(m_pGate->value(), 0.05, 0.95);
    // about 2 ms to open or close the gate (no clicks)
    const float smooth = 1.0f - std::exp(-1.0f / (0.002f * static_cast<float>(engineParameters.sampleRate())));
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    for (SINT f = 0; f < frames; ++f) {
        pState->phase += 1.0 / periodFrames;
        if (pState->phase >= 1.0) {
            pState->phase -= std::floor(pState->phase);
        }
        const float target = pState->phase < duty ? 1.0f : 1.0f - cut;
        pState->gain += (target - pState->gain) * smooth;
        for (SINT c = 0; c < channels; ++c) {
            pOutput[f * channels + c] = pInput[f * channels + c] * pState->gain;
        }
    }
    blendWithDry(pInput, pOutput, engineParameters, enableState);
}

// ============================= FILTER (sweep) ===============================

// static
QString SweepFilterEffect::getId() {
    return "org.mixxx.effects.sweepfilter";
}

// static
EffectManifestPointer SweepFilterEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Filter"));
    pManifest->setShortName(QObject::tr("Filter"));
    pManifest->setAuthor("Android edition");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Low pass filter that sweeps up and down in the rhythm of the beat"));
    pManifest->setEffectRampsFromDry(true);

    addBeatsParameter(pManifest);

    EffectManifestParameterPointer res = pManifest->addParameter();
    res->setId("resonance");
    res->setName(QObject::tr("Resonance"));
    res->setShortName(QObject::tr("Res"));
    res->setDescription(QObject::tr("Resonance of the filter"));
    res->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    res->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    res->setDefaultLinkType(EffectManifestParameter::LinkType::Linked);
    res->setRange(0.0, 0.5, 1.0);
    return pManifest;
}

void SweepFilterEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pResonance = parameters.value("resonance");
}

void SweepFilterEffect::processChannel(SweepGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    // A full up and down sweep takes two beats.
    const double period = periodSeconds(m_pBeats->value(), groupFeatures) * 2.0;
    const double periodFrames = std::max(1.0, period * engineParameters.sampleRate());
    const double res = math_clamp(m_pResonance->value(), 0.0, 1.0);
    const float damp = static_cast<float>(1.4 - 0.9 * res);
    const double sampleRate = engineParameters.sampleRate();
    const double minCutoff = 150.0;
    const double maxCutoff = std::min(9000.0, sampleRate / 6.0);
    const double ratio = maxCutoff / minCutoff;
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    for (SINT f = 0; f < frames; ++f) {
        pState->phase += 1.0 / periodFrames;
        if (pState->phase >= 1.0) {
            pState->phase -= std::floor(pState->phase);
        }
        const double tri = pState->phase < 0.5 ? pState->phase * 2.0 : 2.0 - pState->phase * 2.0;
        const double cutoff = minCutoff * std::pow(ratio, tri);
        const float coef = static_cast<float>(2.0 * std::sin(M_PI * cutoff / sampleRate));
        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float x = pInput[f * channels + c];
            pState->low[ch] += coef * pState->band[ch];
            const float high = x - pState->low[ch] - damp * pState->band[ch];
            pState->band[ch] += coef * high;
            pOutput[f * channels + c] = SampleUtil::clampSample(pState->low[ch]);
        }
    }
    blendWithDry(pInput, pOutput, engineParameters, enableState);
}

// ============================== SPIRAL =====================================

// static
QString SpiralEffect::getId() {
    return "org.mixxx.effects.spiral";
}

// static
EffectManifestPointer SpiralEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setAddDryToWet(true);
    pManifest->setEffectRampsFromDry(true);
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Spiral"));
    pManifest->setShortName(QObject::tr("Spiral"));
    pManifest->setAuthor("Android edition");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Echo whose repeats rise in pitch, so that the sound spirals upwards"));

    addBeatsParameter(pManifest);

    EffectManifestParameterPointer feedback = pManifest->addParameter();
    feedback->setId("feedback");
    feedback->setName(QObject::tr("Feedback"));
    feedback->setShortName(QObject::tr("Feedback"));
    feedback->setDescription(QObject::tr("Amount of the repeats"));
    feedback->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    feedback->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    feedback->setRange(0.0, 0.6, 0.9);

    EffectManifestParameterPointer pitch = pManifest->addParameter();
    pitch->setId("pitch");
    pitch->setName(QObject::tr("Pitch"));
    pitch->setShortName(QObject::tr("Pitch"));
    pitch->setDescription(QObject::tr("Semitones that each repeat rises"));
    pitch->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    pitch->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    pitch->setRange(0.0, 3.0, 12.0);

    EffectManifestParameterPointer send = pManifest->addParameter();
    send->setId("send");
    send->setName(QObject::tr("Send"));
    send->setShortName(QObject::tr("Send"));
    send->setDescription(QObject::tr("How much of the signal goes into the effect"));
    send->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    send->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    send->setDefaultLinkType(EffectManifestParameter::LinkType::Linked);
    send->setRange(0.0, 0.7, 1.0);
    return pManifest;
}

void SpiralEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pFeedback = parameters.value("feedback");
    m_pPitch = parameters.value("pitch");
    m_pSend = parameters.value("send");
}

void SpiralEffect::processChannel(SpiralGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    const double sampleRate = engineParameters.sampleRate();
    const size_t delayLength = pState->delayBuffer.size() / 2;
    const size_t shiftLength = SpiralGroupState::kShiftBufferFrames;

    const double period = std::min(periodSeconds(m_pBeats->value(), groupFeatures),
            static_cast<double>(SpiralGroupState::kMaxDelaySeconds) - 0.1);
    const size_t delayFrames = std::min<size_t>(
            static_cast<size_t>(std::max(1.0, period * sampleRate)), delayLength - 1);
    const float feedback = static_cast<float>(math_clamp(m_pFeedback->value(), 0.0, 0.95));
    const float sendTarget = static_cast<float>(math_clamp(m_pSend->value(), 0.0, 1.0));
    const double ratio = std::pow(2.0, math_clamp(m_pPitch->value(), 0.0, 12.0) / 12.0);
    // window of the pitch shifter (50 ms)
    const double window = std::min(0.05 * sampleRate, static_cast<double>(shiftLength) / 2.0);
    const double phaseStep = (ratio - 1.0) / window;

    for (SINT f = 0; f < frames; ++f) {
        const float send = pState->prevSend +
                (sendTarget - pState->prevSend) * static_cast<float>(f + 1) / frames;
        const size_t readPos = (pState->writePos + delayLength - delayFrames) % delayLength;
        float delayed[2] = {pState->delayBuffer[readPos * 2], pState->delayBuffer[readPos * 2 + 1]};

        // Pitch shift of the repeat (two taps that cross-fade).
        pState->shiftBuffer[pState->shiftWritePos * 2] = delayed[0];
        pState->shiftBuffer[pState->shiftWritePos * 2 + 1] = delayed[1];
        pState->shiftPhase += phaseStep;
        if (pState->shiftPhase >= 1.0) {
            pState->shiftPhase -= std::floor(pState->shiftPhase);
        }
        float shifted[2] = {0.f, 0.f};
        for (int tap = 0; tap < 2; ++tap) {
            double phase = pState->shiftPhase + 0.5 * tap;
            if (phase >= 1.0) {
                phase -= 1.0;
            }
            const double delay = window * (1.0 - phase);
            const float gain = static_cast<float>(0.5 - 0.5 * std::cos(2.0 * M_PI * phase));
            double pos = static_cast<double>(pState->shiftWritePos) - delay;
            if (pos < 0) {
                pos += static_cast<double>(shiftLength);
            }
            const size_t i0 = static_cast<size_t>(pos) % shiftLength;
            const size_t i1 = (i0 + 1) % shiftLength;
            const float frac = static_cast<float>(pos - std::floor(pos));
            for (int c = 0; c < 2; ++c) {
                const float a = pState->shiftBuffer[i0 * 2 + c];
                const float b = pState->shiftBuffer[i1 * 2 + c];
                shifted[c] += (a + (b - a) * frac) * gain;
            }
        }
        pState->shiftWritePos = (pState->shiftWritePos + 1) % shiftLength;

        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float in = pInput[f * channels + c];
            pState->delayBuffer[pState->writePos * 2 + ch] =
                    SampleUtil::clampSample(in * send + shifted[ch] * feedback);
            pOutput[f * channels + c] = delayed[ch];
        }
        pState->writePos = (pState->writePos + 1) % delayLength;
    }
    if (enableState == EffectEnableState::Disabling) {
        // The wet signal ramps to zero (the dry signal is added by the chain).
        SampleUtil::applyRampingGain(pOutput, 1.0, 0.0, engineParameters.samplesPerBuffer());
        std::fill(pState->delayBuffer.begin(), pState->delayBuffer.end(), 0.f);
        std::fill(pState->shiftBuffer.begin(), pState->shiftBuffer.end(), 0.f);
        pState->prevSend = 0.f;
    } else {
        pState->prevSend = sendTarget;
    }
}

// =============================== HELIX =====================================

// static
QString HelixEffect::getId() {
    return "org.mixxx.effects.helix";
}

// static
EffectManifestPointer HelixEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Helix"));
    pManifest->setShortName(QObject::tr("Helix"));
    pManifest->setAuthor("Android edition");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Takes in the sound for the length of the effect and repeats it "
            "(beat repeat)"));
    pManifest->setEffectRampsFromDry(true);

    addBeatsParameter(pManifest);

    EffectManifestParameterPointer hold = pManifest->addParameter();
    hold->setId("hold");
    hold->setName(QObject::tr("Hold"));
    hold->setShortName(QObject::tr("Hold"));
    hold->setDescription(QObject::tr("Amount of the repeated sound against the live sound"));
    hold->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    hold->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    hold->setDefaultLinkType(EffectManifestParameter::LinkType::Linked);
    hold->setRange(0.0, 1.0, 1.0);
    return pManifest;
}

void HelixEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pHold = parameters.value("hold");
}

void HelixEffect::processChannel(HelixGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    const double sampleRate = engineParameters.sampleRate();
    const size_t length = pState->buffer.size() / 2;
    const float holdTarget = static_cast<float>(math_clamp(m_pHold->value(), 0.0, 1.0));

    if (enableState == EffectEnableState::Disabling) {
        // Back to the live sound.
        pState->frozen = false;
        pState->loopFrames = 0;
        SampleUtil::copy(pOutput, pInput, engineParameters.samplesPerBuffer());
        return;
    }
    if (pState->loopFrames == 0) {
        // Start: the sound of the next period is recorded (and played live),
        // then it is repeated.
        const double period = std::min(periodSeconds(m_pBeats->value(), groupFeatures),
                static_cast<double>(HelixGroupState::kMaxSeconds) - 0.1);
        pState->loopFrames = std::max<size_t>(
                static_cast<size_t>(period * sampleRate), 64);
        pState->loopFrames = std::min(pState->loopFrames, length - 1);
        pState->loopStart = pState->writePos;
        pState->loopPos = 0;
        pState->frozen = false;
    }
    const size_t fade = std::min<size_t>(static_cast<size_t>(0.003 * sampleRate),
            pState->loopFrames / 4);
    for (SINT f = 0; f < frames; ++f) {
        float loop[2] = {0.f, 0.f};
        if (!pState->frozen) {
            // recording
            const size_t index = (pState->loopStart + pState->loopPos) % length;
            for (int c = 0; c < 2; ++c) {
                pState->buffer[index * 2 + c] = pInput[f * channels + std::min<int>(c, channels - 1)];
            }
            ++pState->loopPos;
            if (pState->loopPos >= pState->loopFrames) {
                pState->frozen = true;
                pState->loopPos = 0;
            }
        } else {
            const size_t index = (pState->loopStart + pState->loopPos) % length;
            // short fades at the ends of the loop (no clicks)
            float gain = 1.0f;
            if (fade > 0) {
                if (pState->loopPos < fade) {
                    gain = static_cast<float>(pState->loopPos) / fade;
                } else if (pState->loopPos + fade >= pState->loopFrames) {
                    gain = static_cast<float>(pState->loopFrames - pState->loopPos) / fade;
                }
            }
            loop[0] = pState->buffer[index * 2] * gain;
            loop[1] = pState->buffer[index * 2 + 1] * gain;
            if (++pState->loopPos >= pState->loopFrames) {
                pState->loopPos = 0;
            }
        }
        const float wet = pState->frozen ? holdTarget : 0.0f;
        for (SINT c = 0; c < channels; ++c) {
            const float in = pInput[f * channels + c];
            pOutput[f * channels + c] = in * (1.0f - wet) + loop[std::min<int>(c, 1)] * wet;
        }
    }
    pState->writePos = pState->loopStart; // (the recording index is derived from loopStart)
    if (enableState == EffectEnableState::Enabling) {
        blendWithDry(pInput, pOutput, engineParameters, enableState);
    }
}
