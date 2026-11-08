#pragma once

// Android edition: tempo based effects that are missing in Mixxx but belong to
// the Beat FX of the Pioneer players: TRANS, FILTER (sweep with a tempo),
// SPIRAL and HELIX. All of them have the time of the effect in beats as first
// parameter (0 - 8 beats, like Delay / Echo), and the second parameter is
// linked to the super knob (DEPTH).

#include <QMap>
#include <cmath>
#include <vector>

#include "effects/backends/effectprocessor.h"
#include "engine/engine.h"
#include "util/class.h"
#include "util/samplebuffer.h"

// ---- TRANS: the sound is cut in the rhythm of the beat ---------------------

class TransGroupState : public EffectState {
  public:
    TransGroupState(const mixxx::EngineParameters& engineParameters)
            : EffectState(engineParameters) {
    }
    double phase = 0.0; // 0 .. 1 within the period
    float gain = 1.0f;  // smoothed gate gain
};

class TransEffect : public EffectProcessorImpl<TransGroupState> {
  public:
    TransEffect() = default;
    static QString getId();
    static EffectManifestPointer getManifest();
    void loadEngineEffectParameters(
            const QMap<QString, EngineEffectParameterPointer>& parameters) override;
    void processChannel(TransGroupState* pState,
            const CSAMPLE* pInput,
            CSAMPLE* pOutput,
            const mixxx::EngineParameters& engineParameters,
            const EffectEnableState enableState,
            const GroupFeatureState& groupFeatures) override;

  private:
    EngineEffectParameterPointer m_pBeats;
    EngineEffectParameterPointer m_pDepth;
    EngineEffectParameterPointer m_pGate;
    DISALLOW_COPY_AND_ASSIGN(TransEffect);
};

// ---- FILTER with a tempo: low pass that sweeps up and down ----------------

class SweepGroupState : public EffectState {
  public:
    SweepGroupState(const mixxx::EngineParameters& engineParameters)
            : EffectState(engineParameters) {
    }
    double phase = 0.0;
    float low[2] = {0.f, 0.f};
    float band[2] = {0.f, 0.f};
};

class SweepFilterEffect : public EffectProcessorImpl<SweepGroupState> {
  public:
    SweepFilterEffect() = default;
    static QString getId();
    static EffectManifestPointer getManifest();
    void loadEngineEffectParameters(
            const QMap<QString, EngineEffectParameterPointer>& parameters) override;
    void processChannel(SweepGroupState* pState,
            const CSAMPLE* pInput,
            CSAMPLE* pOutput,
            const mixxx::EngineParameters& engineParameters,
            const EffectEnableState enableState,
            const GroupFeatureState& groupFeatures) override;

  private:
    EngineEffectParameterPointer m_pBeats;
    EngineEffectParameterPointer m_pResonance;
    DISALLOW_COPY_AND_ASSIGN(SweepFilterEffect);
};

// ---- SPIRAL: echo whose repeats rise in pitch ------------------------------

class SpiralGroupState : public EffectState {
  public:
    static constexpr int kMaxDelaySeconds = 8;
    static constexpr int kShiftBufferFrames = 16384;

    SpiralGroupState(const mixxx::EngineParameters& engineParameters)
            : EffectState(engineParameters) {
        audioParametersChanged(engineParameters);
    }
    void audioParametersChanged(const mixxx::EngineParameters& engineParameters) {
        delayBuffer.assign(static_cast<size_t>(kMaxDelaySeconds) *
                        engineParameters.sampleRate() * 2,
                0.f);
        shiftBuffer.assign(static_cast<size_t>(kShiftBufferFrames) * 2, 0.f);
        writePos = 0;
        shiftWritePos = 0;
        shiftPhase = 0.0;
        prevSend = 0.f;
    }
    std::vector<float> delayBuffer;
    std::vector<float> shiftBuffer;
    size_t writePos = 0;      // in frames
    size_t shiftWritePos = 0; // in frames
    double shiftPhase = 0.0;
    float prevSend = 0.f;
};

class SpiralEffect : public EffectProcessorImpl<SpiralGroupState> {
  public:
    SpiralEffect() = default;
    static QString getId();
    static EffectManifestPointer getManifest();
    void loadEngineEffectParameters(
            const QMap<QString, EngineEffectParameterPointer>& parameters) override;
    void processChannel(SpiralGroupState* pState,
            const CSAMPLE* pInput,
            CSAMPLE* pOutput,
            const mixxx::EngineParameters& engineParameters,
            const EffectEnableState enableState,
            const GroupFeatureState& groupFeatures) override;

  private:
    EngineEffectParameterPointer m_pBeats;
    EngineEffectParameterPointer m_pSend;
    EngineEffectParameterPointer m_pFeedback;
    EngineEffectParameterPointer m_pPitch;
    DISALLOW_COPY_AND_ASSIGN(SpiralEffect);
};

// ---- HELIX: the last beats are held and looped -----------------------------

class HelixGroupState : public EffectState {
  public:
    static constexpr int kMaxSeconds = 8;

    HelixGroupState(const mixxx::EngineParameters& engineParameters)
            : EffectState(engineParameters) {
        audioParametersChanged(engineParameters);
    }
    void audioParametersChanged(const mixxx::EngineParameters& engineParameters) {
        buffer.assign(static_cast<size_t>(kMaxSeconds) * engineParameters.sampleRate() * 2, 0.f);
        writePos = 0;
        frozen = false;
        loopFrames = 0;
        loopStart = 0;
        loopPos = 0;
        wetGain = 0.f;
    }
    std::vector<float> buffer;
    size_t writePos = 0; // in frames
    bool frozen = false;
    size_t loopFrames = 0;
    size_t loopStart = 0;
    size_t loopPos = 0;
    float wetGain = 0.f;
};

class HelixEffect : public EffectProcessorImpl<HelixGroupState> {
  public:
    HelixEffect() = default;
    static QString getId();
    static EffectManifestPointer getManifest();
    void loadEngineEffectParameters(
            const QMap<QString, EngineEffectParameterPointer>& parameters) override;
    void processChannel(HelixGroupState* pState,
            const CSAMPLE* pInput,
            CSAMPLE* pOutput,
            const mixxx::EngineParameters& engineParameters,
            const EffectEnableState enableState,
            const GroupFeatureState& groupFeatures) override;

  private:
    EngineEffectParameterPointer m_pBeats;
    EngineEffectParameterPointer m_pHold;
    DISALLOW_COPY_AND_ASSIGN(HelixEffect);
};
