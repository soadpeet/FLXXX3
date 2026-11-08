#pragma once

// Android edition: the Color FX of the Pioneer players (SPACE, DUB ECHO, CRUSH,
// SWEEP, NOISE; FILTER is the filter effect of Mixxx). They run as the quick
// effect of every channel and are controlled with the channel's filter knob:
// the centre of the knob is off, the amount grows towards both ends. The only
// parameter "knob" follows the position of the knob (0 left end, 1 right end).

#include <QMap>
#include <vector>

#include "effects/backends/effectprocessor.h"
#include "engine/engine.h"
#include "util/class.h"

class ColorFxState : public EffectState {
  public:
    static constexpr int kMaxDelaySeconds = 4;

    ColorFxState(const mixxx::EngineParameters& engineParameters)
            : EffectState(engineParameters) {
        audioParametersChanged(engineParameters);
    }
    void audioParametersChanged(const mixxx::EngineParameters& engineParameters);
    void clear();

    // reverb (SPACE): per channel 4 comb filters and 2 all pass filters
    std::vector<float> comb[2][4];
    std::vector<float> allpass[2][2];
    size_t combPos[2][4] = {};
    size_t allpassPos[2][2] = {};
    float combStore[2][4] = {};

    // delay (DUB ECHO)
    std::vector<float> delay;
    size_t delayPos = 0;
    float feedbackLowPass[2] = {};
    float prevAmount = 0.f;

    // crush
    float held[2] = {};
    int holdCounter = 0;

    // filters (SWEEP, NOISE): state variable filter per channel
    float low[2] = {};
    float band[2] = {};
    float noiseLow[2] = {};
    float noiseBand[2] = {};
    uint32_t noiseSeed = 22222u;
    float smoothedAmount = 0.f;
};

class ColorFxBase : public EffectProcessorImpl<ColorFxState> {
  public:
    void loadEngineEffectParameters(
            const QMap<QString, EngineEffectParameterPointer>& parameters) override;

    // Release (1 = normal, 0 = silent): while SMART CFX is switched off the Color FX
    // are faded out with this factor instead of being cut (set by the effects manager).
    static void setRelease(float release);
    static float release();

  protected:
    // The two halves of the knob.
    static void addSidedParameters(const EffectManifestPointer& pManifest);
    // amount (0 - 1) and the half of the knob (-1 left, +1 right)
    void amountAndSide(float* pAmount, int* pSide) const;

    EngineEffectParameterPointer m_pKnob;
};

#define COLORFX_CLASS(NAME)                                                  \
    class NAME : public ColorFxBase {                                         \
      public:                                                                 \
        NAME() = default;                                                     \
        static QString getId();                                               \
        static EffectManifestPointer getManifest();                           \
        void processChannel(ColorFxState* pState,                             \
                const CSAMPLE* pInput,                                        \
                CSAMPLE* pOutput,                                             \
                const mixxx::EngineParameters& engineParameters,              \
                const EffectEnableState enableState,                          \
                const GroupFeatureState& groupFeatures) override;             \
                                                                              \
      private:                                                                \
        DISALLOW_COPY_AND_ASSIGN(NAME);                                       \
    };

COLORFX_CLASS(SpaceColorEffect)
COLORFX_CLASS(DubEchoColorEffect)
COLORFX_CLASS(CrushColorEffect)
COLORFX_CLASS(SweepColorEffect)
COLORFX_CLASS(NoiseColorEffect)
