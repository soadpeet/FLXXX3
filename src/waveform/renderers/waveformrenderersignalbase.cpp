#include <unordered_map>
#include <algorithm>
#include <algorithm>
#include "waveformrenderersignalbase.h"

#include "control/controlproxy.h"
#include "moc_waveformrenderersignalbase.cpp"
#include "waveform/waveform.h"
#include "waveform/waveformwidgetfactory.h"
#include "waveformwidgetrenderer.h"

namespace {
const QString kEffectGroupFormat = QStringLiteral("[EqualizerRack1_%1_Effect1]");
} // namespace

WaveformRendererSignalBase::WaveformRendererSignalBase(
        WaveformWidgetRenderer* waveformWidgetRenderer, Options)
        : WaveformRendererAbstract(waveformWidgetRenderer),
          m_alignment(Qt::AlignCenter),
          m_orientation(Qt::Horizontal),
          m_allChannelVisualGain(1),
          m_lowVisualGain(1),
          m_midVisualGain(1),
          m_highVisualGain(1),
          m_axesColor_r(0),
          m_axesColor_g(0),
          m_axesColor_b(0),
          m_axesColor_a(0),
          m_signalColor_r(0),
          m_signalColor_g(0),
          m_signalColor_b(0),
          m_lowColor_r(0),
          m_lowColor_g(0),
          m_lowColor_b(0),
          m_midColor_r(0),
          m_midColor_g(0),
          m_midColor_b(0),
          m_highColor_r(0),
          m_highColor_g(0),
          m_highColor_b(0),
          m_rgbLowColor_r(0),
          m_rgbLowColor_g(0),
          m_rgbLowColor_b(0),
          m_rgbMidColor_r(0),
          m_rgbMidColor_g(0),
          m_rgbMidColor_b(0),
          m_rgbHighColor_r(0),
          m_rgbHighColor_g(0),
          m_rgbHighColor_b(0),
          m_rgbLowFilteredColor_r(0),
          m_rgbLowFilteredColor_g(0),
          m_rgbLowFilteredColor_b(0),
          m_rgbMidFilteredColor_r(0),
          m_rgbMidFilteredColor_g(0),
          m_rgbMidFilteredColor_b(0),
          m_rgbHighFilteredColor_r(0),
          m_rgbHighFilteredColor_g(0),
          m_rgbHighFilteredColor_b(0) {
}

WaveformRendererSignalBase::~WaveformRendererSignalBase() = default;

bool WaveformRendererSignalBase::init() {
    m_pEQEnabled = std::make_unique<ControlProxy>(
            m_waveformRenderer->getGroup(), QStringLiteral("filterWaveformEnable"));
    const QString effectGroup = kEffectGroupFormat.arg(m_waveformRenderer->getGroup());
    m_pLowFilterControlObject = std::make_unique<ControlProxy>(
            effectGroup, QStringLiteral("parameter1"));
    m_pMidFilterControlObject = std::make_unique<ControlProxy>(
            effectGroup, QStringLiteral("parameter2"));
    m_pHighFilterControlObject = std::make_unique<ControlProxy>(
            effectGroup, QStringLiteral("parameter3"));
    m_pLowKillControlObject = std::make_unique<ControlProxy>(
            effectGroup, QStringLiteral("button_parameter1"));
    m_pMidKillControlObject = std::make_unique<ControlProxy>(
            effectGroup, QStringLiteral("button_parameter2"));
    m_pHighKillControlObject = std::make_unique<ControlProxy>(
            effectGroup, QStringLiteral("button_parameter3"));

    return onInit();
}

void WaveformRendererSignalBase::setup(const QDomNode& node,
                                       const SkinContext& context) {
    QString orientationString = context.selectString(node, "Orientation").toLower();
    if (orientationString == "vertical") {
        m_orientation = Qt::Vertical;
    } else {
        m_orientation = Qt::Horizontal;
    }

    QString alignString = context.selectString(node, "Align").toLower();
    if (m_orientation == Qt::Horizontal) {
        if (alignString == "bottom") {
            m_alignment = Qt::AlignBottom;
        } else if (alignString == "top") {
            m_alignment = Qt::AlignTop;
        } else {
            m_alignment = Qt::AlignCenter;
        }
    } else {
        if (alignString == "left") {
            m_alignment = Qt::AlignLeft;
        } else if (alignString == "right") {
            m_alignment = Qt::AlignRight;
        } else {
            m_alignment = Qt::AlignCenter;
        }
    }

    const auto* pColors = m_waveformRenderer->getWaveformSignalColors();

    pColors->getLowColor().getRgbF(&m_lowColor_r, &m_lowColor_g, &m_lowColor_b);
    pColors->getMidColor().getRgbF(&m_midColor_r, &m_midColor_g, &m_midColor_b);
    pColors->getHighColor().getRgbF(&m_highColor_r, &m_highColor_g, &m_highColor_b);
    pColors->getRgbLowColor().getRgbF(&m_rgbLowColor_r, &m_rgbLowColor_g, &m_rgbLowColor_b);
    pColors->getRgbMidColor().getRgbF(&m_rgbMidColor_r, &m_rgbMidColor_g, &m_rgbMidColor_b);
    pColors->getRgbHighColor().getRgbF(&m_rgbHighColor_r, &m_rgbHighColor_g, &m_rgbHighColor_b);
    pColors->getRgbLowFilteredColor().getRgbF(
            &m_rgbLowFilteredColor_r,
            &m_rgbLowFilteredColor_g,
            &m_rgbLowFilteredColor_b);

    pColors->getRgbMidFilteredColor().getRgbF(
            &m_rgbMidFilteredColor_r,
            &m_rgbMidFilteredColor_g,
            &m_rgbMidFilteredColor_b);

    pColors->getRgbHighFilteredColor().getRgbF(
            &m_rgbHighFilteredColor_r,
            &m_rgbHighFilteredColor_g,
            &m_rgbHighFilteredColor_b);

    pColors->getAxesColor().getRgbF(
            &m_axesColor_r,
            &m_axesColor_g,
            &m_axesColor_b,
            &m_axesColor_a);
    pColors->getSignalColor().getRgbF(&m_signalColor_r, &m_signalColor_g, &m_signalColor_b);
    onSetup(node);

    auto* pWaveformFactory = WaveformWidgetFactory::instance();
    connect(pWaveformFactory,
            &WaveformWidgetFactory::visualGainChanged,
            this,
            [this](CSAMPLE_GAIN allChannelGain,
                    CSAMPLE_GAIN lowGain,
                    CSAMPLE_GAIN midGain,
                    CSAMPLE_GAIN highGain) {
                setAllChannelVisualGain(allChannelGain);
                setLowVisualGain(lowGain);
                setMidVisualGain(midGain);
                setHighVisualGain(highGain);
            });

    setAllChannelVisualGain(pWaveformFactory->getVisualGain(BandIndex::AllBand));
    setLowVisualGain(pWaveformFactory->getVisualGain(BandIndex::Low));
    setMidVisualGain(pWaveformFactory->getVisualGain(BandIndex::Mid));
    setHighVisualGain(pWaveformFactory->getVisualGain(BandIndex::High));
}

void WaveformRendererSignalBase::getGains(float* pAllGain,
        float* pLowGain,
        float* pMidGain,
        float* pHighGain) {
    if (pAllGain) {
#ifdef __ANDROID__
        // Android edition: fixed height. The tracks are normalised beforehand,
        // so the loudest points reach just below the beat ticks (5 % of the
        // height at the top and at the bottom).
        *pAllGain = 0.9f;
#else
        *pAllGain = static_cast<CSAMPLE_GAIN>(
                            m_waveformRenderer->getGain()) *
                m_allChannelVisualGain;
#endif
    }

    if (pLowGain || pMidGain || pHighGain) {
        // Per-band gain from the EQ knobs.
        CSAMPLE_GAIN lowVisualGain = 1.0, midVisualGain = 1.0, highVisualGain = 1.0;

        // Android edition: the waveform does not change with the EQ knobs or
        // kill switches (like on the Pioneer players).
#ifdef __ANDROID__
        const bool followEq = false;
#else
        const bool followEq = !m_pEQEnabled || m_pEQEnabled->get() > 0.0;
#endif
        // Only adjust low/mid/high gains if EQs are enabled or if there is no EQs CO setup.
        if (followEq) {
            if (m_pLowFilterControlObject &&
                    m_pMidFilterControlObject &&
                    m_pHighFilterControlObject) {
                lowVisualGain = static_cast<CSAMPLE_GAIN>(m_pLowFilterControlObject->get());
                midVisualGain = static_cast<CSAMPLE_GAIN>(m_pMidFilterControlObject->get());
                highVisualGain = static_cast<CSAMPLE_GAIN>(m_pHighFilterControlObject->get());
            }

            lowVisualGain *= m_lowVisualGain;
            midVisualGain *= m_midVisualGain;
            highVisualGain *= m_highVisualGain;

            if (m_pLowKillControlObject && m_pLowKillControlObject->get() > 0.0) {
                lowVisualGain = 0;
            }

            if (m_pMidKillControlObject && m_pMidKillControlObject->get() > 0.0) {
                midVisualGain = 0;
            }

            if (m_pHighKillControlObject && m_pHighKillControlObject->get() > 0.0) {
                highVisualGain = 0;
            }
        }

#ifdef __ANDROID__
        lowVisualGain *= m_lowVisualGain;
        midVisualGain *= m_midVisualGain;
        highVisualGain *= m_highVisualGain;
#endif
        if (pLowGain != nullptr) {
            *pLowGain = lowVisualGain;
        }
        if (pMidGain != nullptr) {
            *pMidGain = midVisualGain;
        }
        if (pHighGain != nullptr) {
            *pHighGain = highVisualGain;
        }
    }
}

#ifdef __ANDROID__
float WaveformRendererSignalBase::trackAutoGain(const Waveform* pWaveform, int dataSize) {
    // The result is cached per waveform for all renderers (the renderer
    // objects themselves can be recreated).
    struct Entry {
        int dataSize;
        int completionStep;
        float gain;
    };
    static thread_local std::unordered_map<const Waveform*, Entry> cache;

    // While the analysis is still running the completion grows; rescan only
    // after every 5 % of progress, not in every frame.
    const int step = std::max(1, dataSize / 20);
    const int completionStep = pWaveform->getCompletion() / step;
    const auto it = cache.find(pWaveform);
    if (it != cache.end() && it->second.dataSize == dataSize &&
            it->second.completionStep == completionStep) {
        return it->second.gain;
    }
    const WaveformData* pData = pWaveform->data();
    // A few single spikes must not decide the height: use the value that 99.5 %
    // of the columns stay below (histogram, one pass).
    int histogram[256] = {};
    int nonZero = 0;
    for (int i = 0; i < dataSize; ++i) {
        const unsigned char v = pData[i].filtered.all;
        ++histogram[v];
        if (v > 0) {
            ++nonZero;
        }
    }
    int maxAll = 0;
    const int allowed = nonZero / 200; // 0.5 %
    int above = 0;
    for (int v = 255; v >= 0; --v) {
        above += histogram[v];
        if (above > allowed) {
            maxAll = v;
            break;
        }
    }
    // 0.9: leave room for the ticks at the top and bottom.
    const float gain = maxAll > 8
            ? std::min(4.0f, 0.855f * 255.0f / expandPeaks(static_cast<float>(maxAll)))
            : 0.855f;
    if (cache.size() > 16) {
        cache.clear();
    }
    cache[pWaveform] = Entry{dataSize, completionStep, gain};
    return gain;
}
#endif
