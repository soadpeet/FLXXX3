#include "waveform/renderers/allshader/waveformrenderbeat.h"
#include "rendergraph/material/rgbmaterial.h"
#include "rendergraph/vertexupdaters/rgbvertexupdater.h"

#include <QDomNode>

#include "engine/engine.h"
#include "moc_waveformrenderbeat.cpp"
#include "rendergraph/geometry.h"
#include "rendergraph/material/unicolormaterial.h"
#include "rendergraph/vertexupdaters/vertexupdater.h"
#include "skin/legacy/skincontext.h"
#include "track/track.h"
#include "waveform/renderers/waveformwidgetrenderer.h"
#include "waveform/waveform.h"
#include "waveform/waveformwidgetfactory.h"
#include "widget/wskincolor.h"

using namespace rendergraph;

namespace allshader {

WaveformRenderBeat::WaveformRenderBeat(WaveformWidgetRenderer* waveformWidget,
        ::WaveformRendererAbstract::PositionSource type)
        : ::WaveformRendererAbstract(waveformWidget),
          m_isSlipRenderer(type == ::WaveformRendererAbstract::Slip) {
    initForRectangles<UniColorMaterial>(0);
    setUsePreprocess(true);
#ifdef __ANDROID__
    auto pBarNode = std::make_unique<GeometryNode>();
    m_pBarNode = pBarNode.get();
    m_pBarNode->initForRectangles<RGBMaterial>(0);
    appendChildNode(std::move(pBarNode));
#endif
}

void WaveformRenderBeat::setup(const QDomNode& node, const SkinContext& skinContext) {
    m_color = QColor(skinContext.selectString(node, QStringLiteral("BeatColor")));
    m_color = WSkinColor::getCorrectColor(m_color).toRgb();
}

void WaveformRenderBeat::draw(QPainter* painter, QPaintEvent* event) {
    Q_UNUSED(painter);
    Q_UNUSED(event);
    DEBUG_ASSERT(false);
}

void WaveformRenderBeat::preprocess() {
    if (!preprocessInner()) {
        geometry().allocate(0);
        markDirtyGeometry();
#ifdef __ANDROID__
        m_pBarNode->geometry().allocate(0);
        m_pBarNode->markDirtyGeometry();
#endif
    }
}

bool WaveformRenderBeat::preprocessInner() {
    const TrackPointer trackInfo = m_waveformRenderer->getTrackInfo();

    if (!trackInfo || (m_isSlipRenderer && !m_waveformRenderer->isSlipActive())) {
        return false;
    }

    const bool isStemTrack = trackInfo && trackInfo->hasStem() &&
            trackInfo->getWaveform() && trackInfo->getWaveform()->hasStem();
    const bool splitStemTracks = isStemTrack && WaveformWidgetFactory::isCreated() &&
            WaveformWidgetFactory::instance()->isStemSplitTracks();

    auto positionType = m_isSlipRenderer ? ::WaveformRendererAbstract::Slip
                                         : ::WaveformRendererAbstract::Play;

    mixxx::BeatsPointer trackBeats = trackInfo->getBeats();
    if (!trackBeats) {
        return false;
    }

#ifndef __SCENEGRAPH__
    int alpha = m_waveformRenderer->getBeatGridAlpha();
    if (alpha == 0) {
        return false;
    }
    m_color.setAlphaF(alpha / 100.0f);
#endif

    if (!m_color.alpha()) {
        // Don't render the beatgrid lines is there are fully transparent
        return false;
    }

    const float devicePixelRatio = m_waveformRenderer->getDevicePixelRatio();

    const double trackSamples = m_waveformRenderer->getTrackSamples();
    if (trackSamples <= 0.0) {
        return false;
    }

    const double firstDisplayedPosition =
            m_waveformRenderer->getFirstDisplayedPosition(positionType);
    const double lastDisplayedPosition =
            m_waveformRenderer->getLastDisplayedPosition(positionType);

    // The beat grid is only drawn inside the track: a constant tempo grid
    // extends infinitely before the start and behind the end.
    auto startPosition = mixxx::audio::FramePos::fromEngineSamplePos(
            firstDisplayedPosition * trackSamples);
    auto endPosition = mixxx::audio::FramePos::fromEngineSamplePos(
            lastDisplayedPosition * trackSamples);

    if (!startPosition.isValid() || !endPosition.isValid()) {
        return false;
    }
    const auto trackEndPosition = mixxx::audio::FramePos::fromEngineSamplePos(trackSamples);
    // A grid whose first beat lies a few ms before the start of the track
    // (Rekordbox) still shows that beat.
    constexpr double kFirstBeatToleranceFrames = -3000.0;
    if (startPosition < mixxx::audio::FramePos(kFirstBeatToleranceFrames)) {
        startPosition = mixxx::audio::FramePos(kFirstBeatToleranceFrames);
    }
    if (endPosition > trackEndPosition) {
        endPosition = trackEndPosition;
    }
    if (startPosition > endPosition) {
        return false;
    }

    const float rendererBreadth = m_waveformRenderer->getBreadth();

    const int numVerticesPerLine = 6; // 2 triangles

    // Count the number of beats in the range to reserve space in the m_vertices vector.
    // Note that we could also use
    //   int numBearsInRange = trackBeats->numBeatsInRange(startPosition, endPosition);
    // for this, but there have been reports of that method failing with a DEBUG_ASSERT.
    int numBeatsInRange = 0;
#ifdef __ANDROID__
    int numBarsInRange = 0;
#endif
#ifdef __ANDROID__
    // Index of the first beat: computed once (the difference of two iterators
    // is not free), then counted up.
    const int firstBeatIndex = trackBeats->iteratorFrom(startPosition) - trackBeats->cbegin();
    int beatIndex = firstBeatIndex;
#endif
    for (auto it = trackBeats->iteratorFrom(startPosition);
            it != trackBeats->cend() && *it <= endPosition;
            ++it) {
        numBeatsInRange++;
#ifdef __ANDROID__
        if (beatIndex++ % 4 == 0) {
            numBarsInRange++;
        }
#endif
    }

    [[maybe_unused]] const int numBoxesPerBeat = (m_isSlipRenderer && splitStemTracks)
            ? mixxx::kMaxSupportedStems
            : 1;
#ifdef __ANDROID__
    // RX3 style: only short ticks at the top and at the bottom of the waveform.
    const int reserved = (numBeatsInRange - numBarsInRange) * numVerticesPerLine * 2;
    geometry().allocate(reserved);
    m_pBarNode->geometry().allocate(numBarsInRange * numVerticesPerLine * 2);
    RGBVertexUpdater barVertexUpdater{m_pBarNode->geometry().vertexDataAs<Geometry::RGBColoredPoint2D>()};
    const QVector3D barColor(1.f, 122.f / 255.f, 26.f / 255.f);
    // All ticks have the same size; every 4th beat is only drawn in orange.
    const float tickHeight = std::max(3.f, rendererBreadth * 0.05f);
#else
    const int reserved = numBeatsInRange * numVerticesPerLine * numBoxesPerBeat;
    geometry().allocate(reserved);
#endif

    VertexUpdater vertexUpdater{geometry().vertexDataAs<Geometry::Point2D>()};

    [[maybe_unused]] const float boxBreadth = splitStemTracks
            ? rendererBreadth / static_cast<float>(mixxx::kMaxSupportedStems)
            : rendererBreadth;

#ifdef __ANDROID__
    beatIndex = firstBeatIndex;
#endif
    for (auto it = trackBeats->iteratorFrom(startPosition);
            it != trackBeats->cend() && *it <= endPosition;
            ++it) {
        double beatPosition = it->toEngineSamplePos();
        double xBeatPoint =
                m_waveformRenderer->transformSamplePositionInRendererWorld(
                        beatPosition, positionType);

        xBeatPoint = qRound(xBeatPoint * devicePixelRatio) / devicePixelRatio;

        const float x1 = static_cast<float>(xBeatPoint);
        const float x2 = x1 + 1.f;

#ifdef __ANDROID__
        if (beatIndex++ % 4 == 0) {
            barVertexUpdater.addRectangle({x1 - 0.5f, 0.f}, {x2 + 0.5f, tickHeight}, barColor);
            barVertexUpdater.addRectangle({x1 - 0.5f, rendererBreadth - tickHeight},
                    {x2 + 0.5f, rendererBreadth},
                    barColor);
        } else {
            vertexUpdater.addRectangle({x1 - 0.5f, 0.f}, {x2 + 0.5f, tickHeight});
            vertexUpdater.addRectangle({x1 - 0.5f, rendererBreadth - tickHeight},
                    {x2 + 0.5f, rendererBreadth});
        }
#else
        if (m_isSlipRenderer && splitStemTracks) {
            for (int stemIdx = 0; stemIdx < mixxx::kMaxSupportedStems; ++stemIdx) {
                const float posy1 = stemIdx * boxBreadth;
                const float posy2 = posy1 + boxBreadth / 2.f;
                vertexUpdater.addRectangle({x1, posy1}, {x2, posy2});
            }
        } else {
            vertexUpdater.addRectangle({x1, 0.f},
                    {x2, m_isSlipRenderer ? rendererBreadth / 2 : rendererBreadth});
        }
#endif
    }
    markDirtyGeometry();
#ifdef __ANDROID__
    m_pBarNode->markDirtyGeometry();
#endif

    DEBUG_ASSERT(reserved == vertexUpdater.index());

    material().setUniform(1, m_color);
    markDirtyMaterial();

    return true;
}

} // namespace allshader
