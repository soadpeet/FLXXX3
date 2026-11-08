#include "waveform/renderers/allshader/waveformrendererrgb.h"

#include <algorithm>
#include <cmath>
#ifdef __ANDROID__
#include <android/log.h>
#include <unordered_map>
#endif

#include "rendergraph/material/rgbmaterial.h"
#include "rendergraph/vertexupdaters/rgbvertexupdater.h"
#include "track/track.h"
#include "util/math.h"
#include "waveform/renderers/waveformwidgetrenderer.h"
#include "waveform/waveform.h"

using namespace rendergraph;

#ifdef __ANDROID__
// TEMP-DIAG3: a frame without geometry makes the waveform vanish for one frame.
// Log why, but only if the previous frame of this renderer was drawn.
static std::unordered_map<const void*, bool>& diagDrawn() {
    static thread_local std::unordered_map<const void*, bool> m;
    return m;
}
static bool diagFail(const void* self, const char* why) {
    if (diagDrawn()[self]) {
        __android_log_print(ANDROID_LOG_INFO, "mixxx-wf", "NO-DRAW %p: %s", self, why);
    }
    diagDrawn()[self] = false;
    return false;
}
#endif


namespace allshader {

WaveformRendererRGB::WaveformRendererRGB(WaveformWidgetRenderer* waveformWidget,
        ::WaveformRendererAbstract::PositionSource type,
        ::WaveformRendererSignalBase::Options options)
        : WaveformRendererSignalBase(waveformWidget, options),
          m_isSlipRenderer(type == ::WaveformRendererAbstract::Slip),
          m_options(options) {
    initForRectangles<RGBMaterial>(0);
    setUsePreprocess(true);
}

void WaveformRendererRGB::onSetup(const QDomNode&) {
}

void WaveformRendererRGB::preprocess() {
    if (!preprocessInner()) {
        if (geometry().vertexCount() != 0) {
            geometry().allocate(0);
            markDirtyGeometry();
        }
    }
}

bool WaveformRendererRGB::preprocessInner() {
    TrackPointer pTrack = m_waveformRenderer->getTrackInfo();

    if (!pTrack || (m_isSlipRenderer && !m_waveformRenderer->isSlipActive())) {
        return diagFail(this, "return-false #1");
    }

    auto positionType = m_isSlipRenderer ? ::WaveformRendererAbstract::Slip
                                         : ::WaveformRendererAbstract::Play;

    ConstWaveformPointer waveform = pTrack->getWaveform();
    if (waveform.isNull()) {
        return diagFail(this, "return-false #2");
    }

    const int dataSize = waveform->getDataSize();
    if (dataSize <= 1) {
        return diagFail(this, "return-false #3");
    }

    const WaveformData* data = waveform->data();
    if (data == nullptr) {
        return diagFail(this, "return-false #4");
    }
#ifdef __STEM__
    auto stemInfo = pTrack->getStemInfo();
    // If this track is a stem track, skip the rendering
    if (!stemInfo.isEmpty() && waveform->hasStem() && !m_ignoreStem) {
        return diagFail(this, "return-false #5");
    }
#endif

    const float devicePixelRatio = m_waveformRenderer->getDevicePixelRatio();
    const int length = static_cast<int>(m_waveformRenderer->getLength());
    const int pixelLength = static_cast<int>(m_waveformRenderer->getLength() * devicePixelRatio);
    const float invDevicePixelRatio = 1.f / devicePixelRatio;
    const float halfPixelSize = 0.5f / devicePixelRatio;

    // See waveformrenderersimple.cpp for a detailed explanation of the frame and index calculation
    const int visualFramesSize = dataSize / 2;
    const double firstVisualFrame =
            m_waveformRenderer->getFirstDisplayedPosition(positionType) * visualFramesSize;
    const double lastVisualFrame =
            m_waveformRenderer->getLastDisplayedPosition(positionType) * visualFramesSize;

    // Represents the # of visual frames per horizontal pixel.
    const double visualIncrementPerPixel =
            (lastVisualFrame - firstVisualFrame) / static_cast<double>(pixelLength);

    // Fixes a sporadic crash caused by a division by zero on waveform initialization
    if (visualIncrementPerPixel == 0.0) {
        return diagFail(this, "return-false #6");
    }

    // Per-band gain from the EQ knobs.
    float allGain = 1.0f;
    float lowGain = 1.0f;
    float midGain = 1.0f;
    float highGain = 1.0f;
    getGains(&allGain, &lowGain, &midGain, &highGain);
#ifdef __ANDROID__
    allGain = trackAutoGain(waveform.data(), dataSize) * 1.25f; // same height as the Rekordbox look
#endif

    const float breadth = static_cast<float>(m_waveformRenderer->getBreadth());
    const float halfBreadth = breadth / 2.0f;

    const float heightFactorAbs = allGain * halfBreadth / m_maxValue;
    const float heightFactor[2] = {-heightFactorAbs, heightFactorAbs};
    const bool splitLeftRight = m_options & ::WaveformRendererSignalBase::Option::SplitStereoSignal;

    const float low_r = static_cast<float>(m_rgbLowColor_r);
    const float mid_r = static_cast<float>(m_rgbMidColor_r);
    const float high_r = static_cast<float>(m_rgbHighColor_r);
    const float low_g = static_cast<float>(m_rgbLowColor_g);
    const float mid_g = static_cast<float>(m_rgbMidColor_g);
    const float high_g = static_cast<float>(m_rgbHighColor_g);
    const float low_b = static_cast<float>(m_rgbLowColor_b);
    const float mid_b = static_cast<float>(m_rgbMidColor_b);
    const float high_b = static_cast<float>(m_rgbHighColor_b);

    // Effective visual frame for x
    double xVisualFrame = qRound(firstVisualFrame / visualIncrementPerPixel) *
            visualIncrementPerPixel;

    const int numVerticesPerLine = 6; // 2 triangles

#ifdef __ANDROID__
    // Android edition: dense area like Rekordbox, drawn in two layers (darker
    // outer part, brighter inner part), so two bars per pixel column.
    const int reserved = numVerticesPerLine * (pixelLength * 2 + 1);
#else
    const int reserved = numVerticesPerLine *
            // Slip renderer only render a single channel, so the vertices count doesn't change
            ((splitLeftRight && !m_isSlipRenderer ? pixelLength * 2 : pixelLength) + 1);
#endif

    geometry().setDrawingMode(Geometry::DrawingMode::Triangles);
    geometry().allocate(reserved);
    markDirtyGeometry();

    RGBVertexUpdater vertexUpdater{geometry().vertexDataAs<Geometry::RGBColoredPoint2D>()};
#ifdef __ANDROID__
    RGBVertexUpdater innerUpdater{geometry().vertexDataAs<Geometry::RGBColoredPoint2D>() +
            numVerticesPerLine * (1 + pixelLength)};
    // BLUE scheme (set in WaveformDisplay.qml): the high colour is white.
    const bool blueScheme = high_r > 0.9f && high_g > 0.9f && high_b > 0.9f;
#endif
    vertexUpdater.addRectangle({0.f,
                                       halfBreadth - 0.5f},
            {static_cast<float>(length),
                    m_isSlipRenderer ? halfBreadth : halfBreadth + 0.5f},
            {static_cast<float>(m_axesColor_r),
                    static_cast<float>(m_axesColor_g),
                    static_cast<float>(m_axesColor_b)});

    const double maxSamplingRange = visualIncrementPerPixel / 2.0;
#ifdef __ANDROID__
    double diagSum = 0.0;
#endif

    for (int pos = 0; pos < pixelLength; ++pos) {
        const int visualFrameStart = std::lround(xVisualFrame - maxSamplingRange);
        const int visualFrameStop = std::lround(xVisualFrame + maxSamplingRange);

        const int visualIndexStart = std::max(visualFrameStart * 2, 0);
        const int visualIndexStop =
                std::min(std::max(visualFrameStop, visualFrameStart + 1) * 2, dataSize - 1);

        const float fpos = static_cast<float>(pos) * invDevicePixelRatio;

        // Find the max values for low, mid, high and all in the waveform data.
        // - Max of left and right
        uchar u8maxLow[2]{};
        uchar u8maxMid[2]{};
        uchar u8maxHigh[2]{};
        // - Per channel
        uchar u8maxAllChn[2]{};
        for (int chn = 0; chn < 2; chn++) {
            // In case we don't render individual color per channel, we use only
            // the first field of the arrays to perform signal max
            int signalChn = splitLeftRight ? chn : 0;
            // data is interleaved left / right
            for (int i = visualIndexStart + chn; i < visualIndexStop + chn; i += 2) {
                const WaveformData& waveformData = data[i];

                u8maxLow[signalChn] = math_max(u8maxLow[signalChn], waveformData.filtered.low);
                u8maxMid[signalChn] = math_max(u8maxMid[signalChn], waveformData.filtered.mid);
                u8maxHigh[signalChn] = math_max(u8maxHigh[signalChn], waveformData.filtered.high);
                u8maxAllChn[signalChn] = math_max(
                        u8maxAllChn[signalChn], waveformData.filtered.all);
            }
        }
        float maxAllChn[2]{static_cast<float>(u8maxAllChn[0]), static_cast<float>(u8maxAllChn[1])};
#ifdef __ANDROID__
        maxAllChn[0] = expandPeaks(maxAllChn[0]);
        maxAllChn[1] = expandPeaks(maxAllChn[1]);
#endif

        // In case we don't render individual color per channel, all the
        // signal information is in the first field of each array. If
        // this is the split render, we only render the left channel
        // anyway.
        for (int chn = 0;
                chn < (splitLeftRight && !m_isSlipRenderer ? 2 : 1);
                chn++) {
            // Cast to float
            float maxLowU = static_cast<float>(u8maxLow[chn]);
            float maxMidU = static_cast<float>(u8maxMid[chn]);
            float maxHighU = static_cast<float>(u8maxHigh[chn]);

            // Apply the gains
            float maxLow = maxLowU * lowGain;
            float maxMid = maxMidU * midGain;
            float maxHigh = maxHighU * highGain;

            float allUnscaled = maxLowU + maxMidU + maxHighU;
            float eqGain = 1.0f;
            if (allUnscaled > 0.0f) {
                eqGain = (maxLow + maxMid + maxHigh) / allUnscaled;
            }

            // Use the gained maxLow, maxMid and maxHigh values to calculate the color components
            float red = maxLow * low_r + maxMid * mid_r + maxHigh * high_r;
            float green = maxLow * low_g + maxMid * mid_g + maxHigh * high_g;
            float blue = maxLow * low_b + maxMid * mid_b + maxHigh * high_b;

#ifdef __ANDROID__
            {
                // Rekordbox look: strong colours (contrast between the bands
                // instead of a mix that ends up white) and a gradient from the
                // bright centre to the darker tips (two layers).
                const float strongest = math_max3(maxLow, maxMid, maxHigh);
                float wl = 0.f, wm = 0.f, wh = 0.f;
                if (strongest > 0.f) {
                    wl = std::pow(maxLow / strongest, 2.5f);
                    wm = std::pow(maxMid / strongest, 2.5f);
                    wh = std::pow(maxHigh / strongest, 2.5f);
                }
                red = wl * low_r + wm * mid_r + wh * high_r;
                green = wl * low_g + wm * mid_g + wh * high_g;
                blue = wl * low_b + wm * mid_b + wh * high_b;
                const float mx = math_max3(red, green, blue);
                float innerRgb[3] = {0.f, 0.f, 0.f};
                float outerRgb[3] = {0.f, 0.f, 0.f};
                if (mx > 0.f) {
                    innerRgb[0] = red / mx;
                    innerRgb[1] = green / mx;
                    innerRgb[2] = blue / mx;
                    if (blueScheme) {
                        // pale blue core, deeper blue at the tips
                        const float t = std::min(1.f, wh);
                        innerRgb[0] = 0.47f + 0.28f * t;
                        innerRgb[1] = 0.58f + 0.26f * t;
                        innerRgb[2] = 0.89f + 0.06f * t;
                        outerRgb[0] = 0.20f + 0.20f * t;
                        outerRgb[1] = 0.30f + 0.22f * t;
                        outerRgb[2] = 0.75f + 0.07f * t;
                    } else {
                        for (int k = 0; k < 3; k++) {
                            outerRgb[k] = innerRgb[k] * 0.62f;
                        }
                    }
                }
                const float amp = heightFactorAbs * eqGain * maxAllChn[chn];
                diagSum += amp + outerRgb[0] + innerRgb[1];
                vertexUpdater.addRectangle({fpos - halfPixelSize, halfBreadth - amp},
                        {fpos + halfPixelSize, halfBreadth + amp},
                        {outerRgb[0], outerRgb[1], outerRgb[2]});
                innerUpdater.addRectangle({fpos - halfPixelSize, halfBreadth - amp * 0.6f},
                        {fpos + halfPixelSize, halfBreadth + amp * 0.6f},
                        {innerRgb[0], innerRgb[1], innerRgb[2]});
                continue;
            }
#endif
            // Normalize the color components using the maximum of the three
            const float maxComponent = math_max3(red, green, blue);
            if (maxComponent == 0.f) {
                // Avoid division by 0
                red = 0.f;
                green = 0.f;
                blue = 0.f;
            } else {
                const float normFactor = 1.f / maxComponent;
                red *= normFactor;
                green *= normFactor;
                blue *= normFactor;
            }

            // Lines are thin rectangles
            if (!splitLeftRight) {
                vertexUpdater.addRectangle(
                        {fpos - halfPixelSize,
                                halfBreadth -
                                        heightFactorAbs * eqGain *
                                                maxAllChn[chn]},
                        {fpos + halfPixelSize,
                                m_isSlipRenderer ? halfBreadth
                                                 : halfBreadth +
                                                heightFactorAbs * eqGain *
                                                        maxAllChn[chn]},
                        {red, green, blue});
            } else {
                // note: heightFactor is the same for left and right,
                // but negative for left (chn 0) and positive for right (chn 1)
                vertexUpdater.addRectangle({fpos - halfPixelSize,
                                                   halfBreadth},
                        {fpos + halfPixelSize,
                                halfBreadth + heightFactor[chn] * eqGain * maxAllChn[chn]},
                        {red,
                                green,
                                blue});
            }
        }

        xVisualFrame += visualIncrementPerPixel;
    }

#ifndef __ANDROID__
    DEBUG_ASSERT(reserved == vertexUpdater.index());
#endif


#ifdef __ANDROID__
    { // TEMP-DIAG2: checksum of everything drawn; changes while the position and zoom stay the same?
        struct PrevSum {
            double sum;
            double first;
            double inc;
            int count;
        };
        static thread_local std::unordered_map<const void*, PrevSum> prevSums;
        auto it2 = prevSums.find(this);
        if (it2 != prevSums.end() && it2->second.first == firstVisualFrame &&
                it2->second.inc == visualIncrementPerPixel &&
                std::abs(it2->second.sum - diagSum) > 1e-3) {
            __android_log_print(ANDROID_LOG_INFO,
                    "mixxx-wf",
                    "SUM %p: %.3f -> %.3f at the same position/zoom (first %.2f, inc %.5f)",
                    this, it2->second.sum, diagSum, firstVisualFrame, visualIncrementPerPixel);
        }
        prevSums[this] = PrevSum{diagSum, firstVisualFrame, visualIncrementPerPixel, 0};
    }
#endif
    markDirtyMaterial();

#ifdef __ANDROID__
    diagDrawn()[this] = true;
#endif
    return true;
}

} // namespace allshader
