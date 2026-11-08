#include "waveform/renderers/allshader/waveformrendererfiltered.h"

#include <algorithm>
#ifdef __ANDROID__
#include <android/log.h>
#include <unordered_map>
#endif

#include "rendergraph/material/rgbmaterial.h"
#include "rendergraph/vertexupdaters/rgbvertexupdater.h"
#include "track/track.h"
#include "util/math.h"
#include "waveform/renderers/waveformwidgetrenderer.h"
#include "waveform/rekordbox3band.h"
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

WaveformRendererFiltered::WaveformRendererFiltered(
        WaveformWidgetRenderer* waveformWidget,
        bool bRgbStacked,
        ::WaveformRendererSignalBase::Options options)
        : WaveformRendererSignalBase(waveformWidget, options),
          m_bRgbStacked(bRgbStacked) {
    initForRectangles<RGBMaterial>(0);
    setUsePreprocess(true);
}

void WaveformRendererFiltered::onSetup(const QDomNode&) {
}

void WaveformRendererFiltered::preprocess() {
    if (!preprocessInner()) {
        if (geometry().vertexCount() != 0) {
            geometry().allocate(0);
            markDirtyGeometry();
        }
    }
}

bool WaveformRendererFiltered::preprocessInner() {
    TrackPointer pTrack = m_waveformRenderer->getTrackInfo();

    if (!pTrack) {
        return diagFail(this, "return-false #1");
    }

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
            m_waveformRenderer->getFirstDisplayedPosition() * visualFramesSize;
    const double lastVisualFrame =
            m_waveformRenderer->getLastDisplayedPosition() * visualFramesSize;

    // Represents the # of visual frames per horizontal pixel.
    const double visualIncrementPerPixel =
            (lastVisualFrame - firstVisualFrame) / static_cast<double>(pixelLength);
    if (visualIncrementPerPixel == 0.0) {
        return diagFail(this, "return-false #6");
    }

    // Per-band gain from the EQ knobs.
    float allGain(1.0);
    float bandGain[3] = {1.0, 1.0, 1.0};
    getGains(&allGain, &bandGain[0], &bandGain[1], &bandGain[2]);
#ifdef __ANDROID__
    // Built from the 3-band waveform of Rekordbox: real band levels.
    const bool threeBand = rekordbox3band::isMarked(waveform.data());
    allGain = trackAutoGain(waveform.data(), dataSize, threeBand);
#endif

    const float breadth = static_cast<float>(m_waveformRenderer->getBreadth());
    const float halfBreadth = breadth / 2.0f;
#ifdef __ANDROID__
    { // TEMP-DIAG: what changes from frame to frame (log only on a change)
        struct Prev {
            float allGain, low, mid, high, breadth;
            double inc, first;
            int length;
        };
        static thread_local std::unordered_map<const void*, Prev> prevMap;
        Prev now{allGain, bandGain[0], bandGain[1], bandGain[2], breadth, visualIncrementPerPixel, firstVisualFrame, length};
        auto it = prevMap.find(this);
        if (it != prevMap.end()) {
            const Prev& p = it->second;
            if (std::abs(p.allGain - now.allGain) > 1e-4f || std::abs(p.low - now.low) > 1e-3f ||
                    std::abs(p.mid - now.mid) > 1e-3f || std::abs(p.high - now.high) > 1e-3f ||
                    std::abs(p.breadth - now.breadth) > 0.01f ||
                    std::abs(p.inc - now.inc) > 1e-6 || p.length != now.length) {
                __android_log_print(ANDROID_LOG_INFO,
                        "mixxx-wf",
                        "change %p: gain %.3f->%.3f bands %.3f/%.3f/%.3f -> %.3f/%.3f/%.3f breadth %.1f->%.1f inc %.4f->%.4f len %d->%d",
                        this, p.allGain, now.allGain, p.low, p.mid, p.high, now.low, now.mid, now.high,
                        p.breadth, now.breadth, p.inc, now.inc, p.length, now.length);
            }
        }
        prevMap[this] = now;
    }
#endif

    const float heightFactor = allGain * halfBreadth / m_maxValue;

    // Effective visual frame for x
    double xVisualFrame = qRound(firstVisualFrame / visualIncrementPerPixel) *
            visualIncrementPerPixel;

    const int numVerticesPerLine = 6; // 2 triangles

    // low, mid, high + horizontal axis
#ifdef __ANDROID__
    // plus a fourth layer: the darker inner part of the mid band
    int reserved = numVerticesPerLine * (pixelLength * 4 + 1);
#else
    int reserved = numVerticesPerLine * (pixelLength * 3 + 1);
#endif

    geometry().setDrawingMode(Geometry::DrawingMode::Triangles);
    geometry().allocate(reserved);
    markDirtyGeometry();

    QVector3D rgb[4];
    if (m_bRgbStacked) {
        rgb[0] = QVector3D(static_cast<float>(m_rgbLowColor_r),
                static_cast<float>(m_rgbLowColor_g),
                static_cast<float>(m_rgbLowColor_b));
        rgb[1] = QVector3D(static_cast<float>(m_rgbMidColor_r),
                static_cast<float>(m_rgbMidColor_g),
                static_cast<float>(m_rgbMidColor_b));
        rgb[2] = QVector3D(static_cast<float>(m_rgbHighColor_r),
                static_cast<float>(m_rgbHighColor_g),
                static_cast<float>(m_rgbHighColor_b));
    } else {
        rgb[0] = QVector3D(static_cast<float>(m_lowColor_r),
                static_cast<float>(m_lowColor_g),
                static_cast<float>(m_lowColor_b));
        rgb[1] = QVector3D(static_cast<float>(m_midColor_r),
                static_cast<float>(m_midColor_g),
                static_cast<float>(m_midColor_b));
        rgb[2] = QVector3D(static_cast<float>(m_highColor_r),
                static_cast<float>(m_highColor_g),
                static_cast<float>(m_highColor_b));
    }

#ifdef __ANDROID__
    // Rekordbox 3-band look: blue / brown / cream, everywhere (also in the
    // part that was already played).
    // Blue = low, amber = mid (darker brown in its inner part), cream = high.
    rgb[0] = QVector3D(0x1f / 255.f, 0x64 / 255.f, 0xf0 / 255.f);
    rgb[1] = QVector3D(0xff / 255.f, 0xa2 / 255.f, 0x1f / 255.f);
    rgb[2] = QVector3D(0xf6 / 255.f, 0xe8 / 255.f, 0xd4 / 255.f);
    rgb[3] = QVector3D(0xb7 / 255.f, 0x70 / 255.f, 0x0f / 255.f);
#endif

    RGBVertexUpdater axisVertexUpdater{geometry().vertexDataAs<Geometry::RGBColoredPoint2D>()};
    axisVertexUpdater.addRectangle({0.f,
                                           halfBreadth - 0.5f},
            {static_cast<float>(length),
                    halfBreadth + 0.5f},
            {static_cast<float>(m_axesColor_r),
                    static_cast<float>(m_axesColor_g),
                    static_cast<float>(m_axesColor_b)});

    RGBVertexUpdater vertexUpdater[3]{
            {geometry().vertexDataAs<Geometry::RGBColoredPoint2D>() +
                    numVerticesPerLine},
            {geometry().vertexDataAs<Geometry::RGBColoredPoint2D>() +
                    numVerticesPerLine * (1 + pixelLength)},
            {geometry().vertexDataAs<Geometry::RGBColoredPoint2D>() +
                    numVerticesPerLine * (1 + pixelLength * 2)}};
#ifdef __ANDROID__
    RGBVertexUpdater innerMidVertexUpdater{geometry().vertexDataAs<Geometry::RGBColoredPoint2D>() +
            numVerticesPerLine * (1 + pixelLength * 3)};
#endif
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

        // 3 bands, 2 channels
        float max[3][2]{};
        uchar u8max[3][2]{};
#ifdef __ANDROID__
        uchar u8maxAll[2]{};
#endif
        for (int chn = 0; chn < 2; chn++) {
            for (int i = visualIndexStart + chn; i < visualIndexStop + chn; i += 2) {
                const WaveformData& waveformData = data[i];
#ifdef __ANDROID__
                u8maxAll[chn] = math_max(u8maxAll[chn], waveformData.filtered.all);
#endif

                u8max[0][chn] = math_max(u8max[0][chn], waveformData.filtered.low);
                u8max[1][chn] = math_max(u8max[1][chn], waveformData.filtered.mid);
                u8max[2][chn] = math_max(u8max[2][chn], waveformData.filtered.high);
            }
            // Cast to float
            max[0][chn] = static_cast<float>(u8max[0][chn]);
            max[1][chn] = static_cast<float>(u8max[1][chn]);
            max[2][chn] = static_cast<float>(u8max[2][chn]);
        }

#ifdef __ANDROID__
        // The Rekordbox waveform has the column height and the level of each
        // band (3 bit). A band is drawn with its share of the column height.
        for (int chn = 0; chn < 2 && !threeBand; chn++) {
            const float height = expandPeaks(static_cast<float>(u8maxAll[chn]));
            for (int band = 0; band < 3; band++) {
                max[band][chn] = height * max[band][chn] / 255.f;
            }
        }
#endif
        // TODO: this can be optimized by using one geometrynode per band
        // + one for the horizontal axis, and uniform color materials,
        // instead of passing constant color as vertex.

#ifdef __ANDROID__
        // Layers from the back to the front, like the Rekordbox 3-band view:
        // blue (low), orange (mid), brown (inner part of mid), cream (high).
        // From the centre outwards that is cream, brown, orange, blue.
        float amplitude[4][2];
        for (int band = 0; band < 3; band++) {
            amplitude[band][0] = max[band][0] * bandGain[band];
            amplitude[band][1] = max[band][1] * bandGain[band];
        }
        if (threeBand) {
            // Like Rekordbox: nested layers, low (blue) outside, then mid (brown),
            // high (cream) in the core. Each is drawn with its own level.
            for (int chn = 0; chn < 2; chn++) {
                // Layer heights measured against Rekordbox (same track and
                // section, 2026-11-09): cream ~18 %, orange ~18 %, blue ~60 % of
                // the column height. Cream and mid were too tall before.
                amplitude[3][chn] = amplitude[1][chn] * 0.54f; // mid in brown
                amplitude[2][chn] *= 0.45f;                    // high in cream
                amplitude[1][chn] = 0.f;                       // the orange layer is not used
            }
        } else {
        // Proportions of the layers, from the outside in: blue (low, small
        // share), orange (mid), brown (inner part of mid) and the cream core
        // (high, inside the brown part). The values are tuned by eye.
        for (int chn = 0; chn < 2; chn++) {
            // Blue (low) is the outer layer: it always sticks out of the orange
            // one by a share of its own level, so that it stays visible in loud
            // parts, where mid is high. Orange leaves room for that rim.
            const float lowLevel = amplitude[0][chn];
            amplitude[1][chn] = std::min(255.f * 0.8f, amplitude[1][chn] * 1.3f);
            amplitude[0][chn] = std::min(255.f, amplitude[1][chn] + lowLevel * 0.3f);
            amplitude[3][chn] = amplitude[1][chn] * 0.7f;
            amplitude[2][chn] = std::min(amplitude[2][chn], amplitude[1][chn] * 0.4f);
        }
        }
        const int order[4] = {0, 1, 3, 2};
        for (int rank = 0; rank < 4; rank++) {
            const int layer = order[rank];
            RGBVertexUpdater& updater = rank < 3 ? vertexUpdater[rank] : innerMidVertexUpdater;
            updater.addRectangle(
                    {fpos - halfPixelSize, halfBreadth - heightFactor * amplitude[layer][0]},
                    {fpos + halfPixelSize, halfBreadth + heightFactor * amplitude[layer][1]},
                    {rgb[layer]});
        }
#ifdef __ANDROID__
        diagSum += amplitude[0][0] + amplitude[0][1] + amplitude[2][0] + amplitude[3][0];
#endif
        xVisualFrame += visualIncrementPerPixel;
        continue;
#endif
        for (int bandIndex = 0; bandIndex < 3; bandIndex++) {
            max[bandIndex][0] *= bandGain[bandIndex];
            max[bandIndex][1] *= bandGain[bandIndex];

            vertexUpdater[bandIndex].addRectangle(
                    {fpos - halfPixelSize,
                            halfBreadth - heightFactor * max[bandIndex][0]},
                    {fpos + halfPixelSize,
                            halfBreadth + heightFactor * max[bandIndex][1]},
#ifdef __ANDROID__
                    {rgb[bandIndex]});
#else
                    {rgb[bandIndex]});
#endif
        }

        xVisualFrame += visualIncrementPerPixel;
    }

#ifndef __ANDROID__
    DEBUG_ASSERT(reserved ==
            vertexUpdater[0].index() + vertexUpdater[1].index() +
                    vertexUpdater[2].index() +
                    numVerticesPerLine); // all lines on the three channels and
                                         // the axis
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
