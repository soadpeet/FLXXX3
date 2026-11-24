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


// Longer sweeps and the direction (the "+" and "-" ranges of the DDJ-FLX10 BEAT keys for ENIGMA JET and
// MOBIUS): "mult" multiplies the time of the first parameter (1 - 8, for 16 to 64 beats),
// "direction" is below 0.5 for "-" (falling sweep) and above for "+" (rising sweep).
void addSweepParameters(const EffectManifestPointer& pManifest, double defaultDirection) {
    EffectManifestParameterPointer mult = pManifest->addParameter();
    mult->setId("mult");
    mult->setName(QObject::tr("Range"));
    mult->setShortName(QObject::tr("Range"));
    mult->setDescription(QObject::tr("Factor on the time (for 16 to 64 beats)"));
    mult->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    mult->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    mult->setRange(1.0, 1.0, 8.0);

    EffectManifestParameterPointer direction = pManifest->addParameter();
    direction->setId("direction");
    direction->setName(QObject::tr("Direction"));
    direction->setShortName(QObject::tr("Direction"));
    direction->setDescription(QObject::tr("Rising (+) or falling (-) sweep"));
    direction->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    direction->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    direction->setRange(0.0, defaultDirection, 1.0);
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
    pManifest->setAuthor("FLXXX3");
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
    pManifest->setAuthor("FLXXX3");
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
    pManifest->setAuthor("FLXXX3");
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
    pManifest->setAuthor("FLXXX3");
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

// ============================ LOW CUT ECHO =================================

// static
QString LowCutEchoEffect::getId() {
    return "org.mixxx.effects.lowcutecho";
}

// static
EffectManifestPointer LowCutEchoEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setAddDryToWet(true);
    pManifest->setEffectRampsFromDry(true);
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Low Cut Echo"));
    pManifest->setShortName(QObject::tr("Low Cut Echo"));
    pManifest->setAuthor("FLXXX3");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Echo whose repeats lose their low end, so that the bass stays clean"));

    addBeatsParameter(pManifest);

    EffectManifestParameterPointer feedback = pManifest->addParameter();
    feedback->setId("feedback");
    feedback->setName(QObject::tr("Feedback"));
    feedback->setShortName(QObject::tr("Feedback"));
    feedback->setDescription(QObject::tr("Amount of the repeats"));
    feedback->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    feedback->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    feedback->setRange(0.0, 0.5, 0.9);

    EffectManifestParameterPointer cutoff = pManifest->addParameter();
    cutoff->setId("cutoff");
    cutoff->setName(QObject::tr("Low Cut"));
    cutoff->setShortName(QObject::tr("Low Cut"));
    cutoff->setDescription(QObject::tr("Frequency below which the repeats are cut (Hz)"));
    cutoff->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    cutoff->setUnitsHint(EffectManifestParameter::UnitsHint::Hertz);
    cutoff->setRange(80.0, 400.0, 2000.0);

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

void LowCutEchoEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pFeedback = parameters.value("feedback");
    m_pCutoff = parameters.value("cutoff");
    m_pSend = parameters.value("send");
}

void LowCutEchoEffect::processChannel(LowCutEchoGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    const double sampleRate = engineParameters.sampleRate();
    const size_t delayLength = pState->delayBuffer.size() / 2;

    const double period = std::min(periodSeconds(m_pBeats->value(), groupFeatures),
            static_cast<double>(LowCutEchoGroupState::kMaxDelaySeconds) - 0.1);
    const size_t delayFrames = std::min<size_t>(
            static_cast<size_t>(std::max(1.0, period * sampleRate)), delayLength - 1);
    const float feedback = static_cast<float>(math_clamp(m_pFeedback->value(), 0.0, 0.95));
    const float sendTarget = static_cast<float>(math_clamp(m_pSend->value(), 0.0, 1.0));
    // one pole high pass: y = a * (y_prev + x - x_prev)
    const double cutoff = math_clamp(m_pCutoff->value(), 20.0, 4000.0);
    const double rc = 1.0 / (2.0 * M_PI * cutoff);
    const float a = static_cast<float>(rc / (rc + 1.0 / sampleRate));

    for (SINT f = 0; f < frames; ++f) {
        const float send = pState->prevSend +
                (sendTarget - pState->prevSend) * static_cast<float>(f + 1) / frames;
        const size_t readPos = (pState->writePos + delayLength - delayFrames) % delayLength;
        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float raw = pState->delayBuffer[readPos * 2 + ch];
            const float cut = a * (pState->hpOut[ch] + raw - pState->hpIn[ch]);
            pState->hpIn[ch] = raw;
            pState->hpOut[ch] = cut;
            const float in = pInput[f * channels + c];
            pState->delayBuffer[pState->writePos * 2 + ch] =
                    SampleUtil::clampSample(in * send + cut * feedback);
            pOutput[f * channels + c] = cut;
        }
        pState->writePos = (pState->writePos + 1) % delayLength;
    }
    if (enableState == EffectEnableState::Disabling) {
        SampleUtil::applyRampingGain(pOutput, 1.0, 0.0, engineParameters.samplesPerBuffer());
        std::fill(pState->delayBuffer.begin(), pState->delayBuffer.end(), 0.f);
        pState->prevSend = 0.f;
        for (int c = 0; c < 2; ++c) {
            pState->hpIn[c] = 0.f;
            pState->hpOut[c] = 0.f;
        }
    } else {
        pState->prevSend = sendTarget;
    }
}

// ============================== ENIGMA JET =================================

// static
QString EnigmaJetEffect::getId() {
    return "org.mixxx.effects.enigmajet";
}

// static
EffectManifestPointer EnigmaJetEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Enigma Jet"));
    pManifest->setShortName(QObject::tr("Enigma Jet"));
    pManifest->setAuthor("FLXXX3");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Jet sound: a flanger with a long sweep and strong feedback"));
    pManifest->setEffectRampsFromDry(true);

    addBeatsParameter(pManifest);

    EffectManifestParameterPointer feedback = pManifest->addParameter();
    feedback->setId("feedback");
    feedback->setName(QObject::tr("Feedback"));
    feedback->setShortName(QObject::tr("Feedback"));
    feedback->setDescription(QObject::tr("Strength of the jet sound"));
    feedback->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    feedback->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    feedback->setRange(0.0, 0.8, 0.95);

    EffectManifestParameterPointer depth = pManifest->addParameter();
    depth->setId("depth");
    depth->setName(QObject::tr("Depth"));
    depth->setShortName(QObject::tr("Depth"));
    depth->setDescription(QObject::tr("Amount of the effect"));
    depth->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    depth->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    depth->setDefaultLinkType(EffectManifestParameter::LinkType::Linked);
    depth->setRange(0.0, 1.0, 1.0);
    addSweepParameters(pManifest, 0.0);
    return pManifest;
}

void EnigmaJetEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pFeedback = parameters.value("feedback");
    m_pDepth = parameters.value("depth");
    m_pMult = parameters.value("mult");
    m_pDirection = parameters.value("direction");
}

void EnigmaJetEffect::processChannel(EnigmaJetGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    const double sampleRate = engineParameters.sampleRate();
    // a sweep up and down takes four times the time
    const double periodFrames = std::max(1.0,
            periodSeconds(m_pBeats->value(), groupFeatures) * 4.0 * sampleRate *
                    math_clamp(m_pMult->value(), 1.0, 8.0));
    const bool rising = m_pDirection->value() > 0.5;
    const float feedback = static_cast<float>(math_clamp(m_pFeedback->value(), 0.0, 0.95));
    const float depth = static_cast<float>(math_clamp(m_pDepth->value(), 0.0, 1.0));
    const size_t length = EnigmaJetGroupState::kBufferFrames;
    const double minDelay = 0.0003 * sampleRate;
    const double maxDelay = std::min(0.008 * sampleRate, static_cast<double>(length) - 4.0);

    for (SINT f = 0; f < frames; ++f) {
        pState->phase += 1.0 / periodFrames;
        if (pState->phase >= 1.0) {
            pState->phase -= std::floor(pState->phase);
        }
        const double tri = pState->phase < 0.5 ? pState->phase * 2.0 : 2.0 - pState->phase * 2.0;
        const double sweep = rising ? 1.0 - tri : tri;
        const double delay = minDelay + (maxDelay - minDelay) * sweep * sweep;
        double pos = static_cast<double>(pState->writePos) - delay;
        if (pos < 0) {
            pos += static_cast<double>(length);
        }
        const size_t i0 = static_cast<size_t>(pos) % length;
        const size_t i1 = (i0 + 1) % length;
        const float frac = static_cast<float>(pos - std::floor(pos));
        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float a = pState->buffer[i0 * 2 + ch];
            const float b = pState->buffer[i1 * 2 + ch];
            const float delayed = a + (b - a) * frac;
            const float in = pInput[f * channels + c];
            pState->buffer[pState->writePos * 2 + ch] =
                    SampleUtil::clampSample(in + delayed * feedback);
            pOutput[f * channels + c] = SampleUtil::clampSample(
                    (in + delayed * depth) / (1.0f + 0.5f * depth));
        }
        pState->writePos = (pState->writePos + 1) % length;
    }
    blendWithDry(pInput, pOutput, engineParameters, enableState);
}

// ================================ STRETCH ==================================

// static
QString StretchEffect::getId() {
    return "org.mixxx.effects.stretch";
}

// static
EffectManifestPointer StretchEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Stretch"));
    pManifest->setShortName(QObject::tr("Stretch"));
    pManifest->setAuthor("FLXXX3");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Takes in the sound for the length of the effect and repeats it, "
            "slowing down and falling in pitch"));
    pManifest->setEffectRampsFromDry(true);

    addBeatsParameter(pManifest);

    EffectManifestParameterPointer slow = pManifest->addParameter();
    slow->setId("slow");
    slow->setName(QObject::tr("Slow"));
    slow->setShortName(QObject::tr("Slow"));
    slow->setDescription(QObject::tr("Speed the repeat has slowed down to"));
    slow->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    slow->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    slow->setRange(0.2, 0.5, 1.0);

    EffectManifestParameterPointer hold = pManifest->addParameter();
    hold->setId("hold");
    hold->setName(QObject::tr("Hold"));
    hold->setShortName(QObject::tr("Hold"));
    hold->setDescription(QObject::tr("Amount of the stretched sound against the live sound"));
    hold->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    hold->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    hold->setDefaultLinkType(EffectManifestParameter::LinkType::Linked);
    hold->setRange(0.0, 1.0, 1.0);
    return pManifest;
}

void StretchEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pSlow = parameters.value("slow");
    m_pHold = parameters.value("hold");
}

void StretchEffect::processChannel(StretchGroupState* pState,
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
    const double slowRate = math_clamp(m_pSlow->value(), 0.2, 1.0);

    if (enableState == EffectEnableState::Disabling) {
        pState->playing = false;
        pState->loopFrames = 0;
        SampleUtil::copy(pOutput, pInput, engineParameters.samplesPerBuffer());
        return;
    }
    if (pState->loopFrames == 0) {
        const double period = std::min(periodSeconds(m_pBeats->value(), groupFeatures),
                static_cast<double>(StretchGroupState::kMaxSeconds) - 0.1);
        pState->loopFrames = std::min<size_t>(
                std::max<size_t>(static_cast<size_t>(period * sampleRate), 64), length - 1);
        pState->recordPos = 0;
        pState->playing = false;
        pState->readPos = 0.0;
        pState->rate = 1.0;
    }
    const size_t fade = std::min<size_t>(static_cast<size_t>(0.003 * sampleRate),
            pState->loopFrames / 4);
    // the speed falls to slowRate over about two passes of the loop
    const double rateStep = (1.0 - slowRate) / (2.0 * static_cast<double>(pState->loopFrames));
    for (SINT f = 0; f < frames; ++f) {
        float loop[2] = {0.f, 0.f};
        if (!pState->playing) {
            // recording (the sound is played live)
            for (int c = 0; c < 2; ++c) {
                pState->buffer[pState->recordPos * 2 + c] =
                        pInput[f * channels + std::min<int>(c, channels - 1)];
            }
            if (++pState->recordPos >= pState->loopFrames) {
                pState->playing = true;
                pState->readPos = 0.0;
                pState->rate = 1.0;
            }
        } else {
            const size_t i0 = static_cast<size_t>(pState->readPos) % pState->loopFrames;
            const size_t i1 = (i0 + 1) % pState->loopFrames;
            const float frac = static_cast<float>(pState->readPos - std::floor(pState->readPos));
            float gain = 1.0f;
            if (fade > 0) {
                if (i0 < fade) {
                    gain = static_cast<float>(i0) / fade;
                } else if (i0 + fade >= pState->loopFrames) {
                    gain = static_cast<float>(pState->loopFrames - i0) / fade;
                }
            }
            for (int c = 0; c < 2; ++c) {
                const float a = pState->buffer[i0 * 2 + c];
                const float b = pState->buffer[i1 * 2 + c];
                loop[c] = (a + (b - a) * frac) * gain;
            }
            pState->readPos += pState->rate;
            if (pState->readPos >= static_cast<double>(pState->loopFrames)) {
                pState->readPos -= static_cast<double>(pState->loopFrames);
            }
            pState->rate = std::max(slowRate, pState->rate - rateStep);
        }
        const float wet = pState->playing ? holdTarget : 0.0f;
        for (SINT c = 0; c < channels; ++c) {
            const float in = pInput[f * channels + c];
            pOutput[f * channels + c] = in * (1.0f - wet) + loop[std::min<int>(c, 1)] * wet;
        }
    }
    if (enableState == EffectEnableState::Enabling) {
        blendWithDry(pInput, pOutput, engineParameters, enableState);
    }
}

// ================================ MOBIUS ===================================

namespace {

EffectManifestPointer mobiusManifest(const QString& id,
        const QString& name,
        const QString& description,
        double defaultDirection) {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(id);
    pManifest->setName(name);
    pManifest->setShortName(name);
    pManifest->setAuthor("FLXXX3");
    pManifest->setVersion("1.0");
    pManifest->setDescription(description);
    pManifest->setEffectRampsFromDry(true);

    addBeatsParameter(pManifest);

    EffectManifestParameterPointer feedback = pManifest->addParameter();
    feedback->setId("feedback");
    feedback->setName(QObject::tr("Feedback"));
    feedback->setShortName(QObject::tr("Feedback"));
    feedback->setDescription(QObject::tr("Strength of the sweep"));
    feedback->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    feedback->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    feedback->setRange(0.0, 0.6, 0.9);

    EffectManifestParameterPointer depth = pManifest->addParameter();
    depth->setId("depth");
    depth->setName(QObject::tr("Depth"));
    depth->setShortName(QObject::tr("Depth"));
    depth->setDescription(QObject::tr("Amount of the effect"));
    depth->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    depth->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    depth->setDefaultLinkType(EffectManifestParameter::LinkType::Linked);
    depth->setRange(0.0, 1.0, 1.0);
    addSweepParameters(pManifest, defaultDirection);
    return pManifest;
}

// Flanger with a sweep of one period of `beats` x 2: saw = the delay shortens and then jumps
// back (a pitch that rises again and again), triangle = up and down.
void processMobius(EnigmaJetGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures,
        double beats,
        double feedbackValue,
        double depthValue,
        double mult,
        bool rising,
        bool saw) {
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    const double sampleRate = engineParameters.sampleRate();
    const double periodFrames = std::max(
            1.0, periodSeconds(beats, groupFeatures) * 2.0 * sampleRate * math_clamp(mult, 1.0, 8.0));
    const float feedback = static_cast<float>(math_clamp(feedbackValue, 0.0, 0.95));
    const float depth = static_cast<float>(math_clamp(depthValue, 0.0, 1.0));
    const size_t length = EnigmaJetGroupState::kBufferFrames;
    const double minDelay = 0.0005 * sampleRate;
    const double maxDelay = std::min(0.012 * sampleRate, static_cast<double>(length) - 4.0);
    // the saw jumps back: short cross fade of the delay is not needed with the feedback low pass
    for (SINT f = 0; f < frames; ++f) {
        pState->phase += 1.0 / periodFrames;
        if (pState->phase >= 1.0) {
            pState->phase -= std::floor(pState->phase);
        }
        const double raw = saw ? pState->phase
                               : (pState->phase < 0.5 ? pState->phase * 2.0
                                                      : 2.0 - pState->phase * 2.0);
        // "+" (rising): the delay shortens during the sweep, "-": it lengthens
        const double shape = rising ? 1.0 - raw : raw;
        const double delay = minDelay + (maxDelay - minDelay) * shape;
        double pos = static_cast<double>(pState->writePos) - delay;
        if (pos < 0) {
            pos += static_cast<double>(length);
        }
        const size_t i0 = static_cast<size_t>(pos) % length;
        const size_t i1 = (i0 + 1) % length;
        const float frac = static_cast<float>(pos - std::floor(pos));
        for (SINT c = 0; c < channels; ++c) {
            const int ch = std::min<int>(c, 1);
            const float a = pState->buffer[i0 * 2 + ch];
            const float b = pState->buffer[i1 * 2 + ch];
            const float delayed = a + (b - a) * frac;
            const float in = pInput[f * channels + c];
            pState->buffer[pState->writePos * 2 + ch] =
                    SampleUtil::clampSample(in + delayed * feedback);
            pOutput[f * channels + c] = SampleUtil::clampSample(
                    (in + delayed * depth) / (1.0f + 0.5f * depth));
        }
        pState->writePos = (pState->writePos + 1) % length;
    }
    blendWithDry(pInput, pOutput, engineParameters, enableState);
}

} // namespace

// static
QString MobiusSawEffect::getId() {
    return "org.mixxx.effects.mobiussaw";
}

// static
EffectManifestPointer MobiusSawEffect::getManifest() {
    return mobiusManifest(getId(),
            QObject::tr("Mobius Saw"),
            QObject::tr("Flanger whose sweep rises again and again (saw wave)"),
            1.0);
}

void MobiusSawEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pFeedback = parameters.value("feedback");
    m_pDepth = parameters.value("depth");
    m_pMult = parameters.value("mult");
    m_pDirection = parameters.value("direction");
}

void MobiusSawEffect::processChannel(EnigmaJetGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    processMobius(pState, pInput, pOutput, engineParameters, enableState, groupFeatures,
            m_pBeats->value(), m_pFeedback->value(), m_pDepth->value(),
            m_pMult->value(), m_pDirection->value() > 0.5, true);
}

// static
QString MobiusTriangleEffect::getId() {
    return "org.mixxx.effects.mobiustriangle";
}

// static
EffectManifestPointer MobiusTriangleEffect::getManifest() {
    return mobiusManifest(getId(),
            QObject::tr("Mobius Triangle"),
            QObject::tr("Flanger whose sweep goes up and down (triangle wave)"),
            0.0);
}

void MobiusTriangleEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pFeedback = parameters.value("feedback");
    m_pDepth = parameters.value("depth");
    m_pMult = parameters.value("mult");
    m_pDirection = parameters.value("direction");
}

void MobiusTriangleEffect::processChannel(EnigmaJetGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    processMobius(pState, pInput, pOutput, engineParameters, enableState, groupFeatures,
            m_pBeats->value(), m_pFeedback->value(), m_pDepth->value(),
            m_pMult->value(), m_pDirection->value() > 0.5, false);
}

// =========================== ROLL / SLIP ROLL ===============================

namespace {

// The first period is recorded (and played live), then it is repeated. `live` is the part of
// the live sound that is heard under the repeat.
void processRoll(HelixGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures,
        double beats,
        float live) {
    const SINT channels = engineParameters.channelCount();
    const SINT frames = engineParameters.framesPerBuffer();
    const double sampleRate = engineParameters.sampleRate();
    const size_t length = pState->buffer.size() / 2;

    if (enableState == EffectEnableState::Disabling) {
        pState->frozen = false;
        pState->loopFrames = 0;
        SampleUtil::copy(pOutput, pInput, engineParameters.samplesPerBuffer());
        return;
    }
    if (pState->loopFrames == 0) {
        const double period = std::min(periodSeconds(beats, groupFeatures),
                static_cast<double>(HelixGroupState::kMaxSeconds) - 0.1);
        pState->loopFrames = std::min<size_t>(
                std::max<size_t>(static_cast<size_t>(period * sampleRate), 64), length - 1);
        pState->loopStart = 0;
        pState->loopPos = 0;
        pState->frozen = false;
    }
    const size_t fade = std::min<size_t>(static_cast<size_t>(0.002 * sampleRate),
            pState->loopFrames / 4);
    for (SINT f = 0; f < frames; ++f) {
        float loop[2] = {0.f, 0.f};
        if (!pState->frozen) {
            for (int c = 0; c < 2; ++c) {
                pState->buffer[pState->loopPos * 2 + c] =
                        pInput[f * channels + std::min<int>(c, channels - 1)];
            }
            if (++pState->loopPos >= pState->loopFrames) {
                pState->frozen = true;
                pState->loopPos = 0;
            }
        } else {
            float gain = 1.0f;
            if (fade > 0) {
                if (pState->loopPos < fade) {
                    gain = static_cast<float>(pState->loopPos) / fade;
                } else if (pState->loopPos + fade >= pState->loopFrames) {
                    gain = static_cast<float>(pState->loopFrames - pState->loopPos) / fade;
                }
            }
            loop[0] = pState->buffer[pState->loopPos * 2] * gain;
            loop[1] = pState->buffer[pState->loopPos * 2 + 1] * gain;
            if (++pState->loopPos >= pState->loopFrames) {
                pState->loopPos = 0;
            }
        }
        for (SINT c = 0; c < channels; ++c) {
            const float in = pInput[f * channels + c];
            pOutput[f * channels + c] = pState->frozen
                    ? SampleUtil::clampSample(loop[std::min<int>(c, 1)] + in * live)
                    : in;
        }
    }
    if (enableState == EffectEnableState::Enabling) {
        blendWithDry(pInput, pOutput, engineParameters, enableState);
    }
}

} // namespace

// static
QString RollEffect::getId() {
    return "org.mixxx.effects.roll";
}

// static
EffectManifestPointer RollEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Roll"));
    pManifest->setShortName(QObject::tr("Roll"));
    pManifest->setAuthor("FLXXX3");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Takes in the sound for the length of the effect and repeats it (roll)"));
    pManifest->setEffectRampsFromDry(true);
    addBeatsParameter(pManifest);
    return pManifest;
}

void RollEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
}

void RollEffect::processChannel(HelixGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    processRoll(pState, pInput, pOutput, engineParameters, enableState, groupFeatures,
            m_pBeats->value(), 0.0f);
}

// static
QString SlipRollEffect::getId() {
    return "org.mixxx.effects.sliproll";
}

// static
EffectManifestPointer SlipRollEffect::getManifest() {
    EffectManifestPointer pManifest(new EffectManifest());
    pManifest->setId(getId());
    pManifest->setName(QObject::tr("Slip Roll"));
    pManifest->setShortName(QObject::tr("Slip Roll"));
    pManifest->setAuthor("FLXXX3");
    pManifest->setVersion("1.0");
    pManifest->setDescription(QObject::tr(
            "Repeats the sound for the length of the effect; the live sound runs on under it"));
    pManifest->setEffectRampsFromDry(true);
    addBeatsParameter(pManifest);

    EffectManifestParameterPointer live = pManifest->addParameter();
    live->setId("live");
    live->setName(QObject::tr("Live"));
    live->setShortName(QObject::tr("Live"));
    live->setDescription(QObject::tr("Amount of the live sound under the repeat"));
    live->setValueScaler(EffectManifestParameter::ValueScaler::Linear);
    live->setUnitsHint(EffectManifestParameter::UnitsHint::Unknown);
    live->setRange(0.0, 0.35, 1.0);
    return pManifest;
}

void SlipRollEffect::loadEngineEffectParameters(
        const QMap<QString, EngineEffectParameterPointer>& parameters) {
    m_pBeats = parameters.value("beats");
    m_pLive = parameters.value("live");
}

void SlipRollEffect::processChannel(HelixGroupState* pState,
        const CSAMPLE* pInput,
        CSAMPLE* pOutput,
        const mixxx::EngineParameters& engineParameters,
        const EffectEnableState enableState,
        const GroupFeatureState& groupFeatures) {
    processRoll(pState, pInput, pOutput, engineParameters, enableState, groupFeatures,
            m_pBeats->value(), static_cast<float>(math_clamp(m_pLive->value(), 0.0, 1.0)));
}
