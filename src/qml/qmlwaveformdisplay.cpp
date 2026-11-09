#include "qml/qmlwaveformdisplay.h"

#include <QQuickWindow>
#include <QScreen>
#ifdef __ANDROID__
#include <android/log.h>
#include <chrono>
#endif
#include <QSGFlatColorMaterial>
#include <QSGSimpleRectNode>
#include <QSGVertexColorMaterial>
#include <Qt>
#include <QtQuick/QSGGeometryNode>
#include <QtQuick/QSGMaterial>
#include <QtQuick/QSGRectangleNode>
#include <QtQuick/QSGTexture>
#include <QtQuick/QSGTextureProvider>
#include <algorithm>
#include <cmath>

#include "library/library.h"
#include "mixer/basetrackplayer.h"
#include "moc_qmlwaveformdisplay.cpp"
#include "qml/qmlconfigproxy.h"
#include "qml/qmlplayerproxy.h"
#include "qmllibraryproxy.h"
#include "rendergraph/context.h"
#include "rendergraph/node.h"
#include "util/assert.h"
#include "waveform/visualplayposition.h"

using namespace allshader;

namespace {
constexpr int kDefaultFrameRate = 60;
} // namespace

namespace mixxx {
namespace qml {

QmlWaveformDisplay::QmlWaveformDisplay(QQuickItem* parent)
        : QQuickItem(parent),
          WaveformWidgetRenderer(),
          m_syncInterval(1'000'000 / kDefaultFrameRate),
          m_frameRate(kDefaultFrameRate),
          m_pPlayer(nullptr),
          m_pTrack(nullptr),
          m_visualPlayPosition(QSharedPointer<VisualPlayPosition>::create()) {
    m_visualPlayPosition->set(0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            SlipModeState::Disabled,
            false,
            false,
            false,
            0.0,
            0.0,
            0.0,
            0.0);
    setFlag(QQuickItem::ItemHasContents, true);

    m_frameRateTimer.setSingleShot(true);
    m_frameRateTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_frameRateTimer, &QTimer::timeout, this, [this]() {
        m_frameRequestTimer.restart();
        update();
    });

    connect(this,
            &QmlWaveformDisplay::windowChanged,
            this,
            &QmlWaveformDisplay::slotWindowChanged,
            Qt::DirectConnection);
    slotWindowChanged(window());
}

void QmlWaveformDisplay::setFrameRate(int frameRate) {
    const int clampedFrameRate = std::clamp(frameRate, 1, 240);
    if (m_frameRate == clampedFrameRate) {
        return;
    }
    m_frameRate = clampedFrameRate;
    m_syncInterval = std::chrono::microseconds(
            std::max(1, 1'000'000 / m_frameRate));
    if (window()) {
        m_frameRateTimer.stop();
        requestUpdateAtFrameRate();
    }
    emit frameRateChanged();
}

QmlWaveformDisplay::~QmlWaveformDisplay() {
    // The stack contains references to Renderer that are owned and cleared by a BaseNode
    m_rendererStack.clear();
}

void QmlWaveformDisplay::componentComplete() {
    if (!getGroup().isEmpty()) {
        qDebug() << "QmlWaveformDisplay ready for group" << getGroup() << "with"
                 << m_waveformRenderers.count() << "renderer(s)";
    } else if (m_pTrack && m_pTrack->internal()) {
        qDebug() << "QmlWaveformDisplay ready for track" << m_pTrack->internal().get() << "with"
                 << m_waveformRenderers.count() << "renderer(s)";
    } else {
        qWarning() << "QmlWaveformDisplay initialised with neither a track nor a group!";
    }

    if (auto* pConfig = qobject_cast<QmlConfigProxy*>(QmlConfigProxyBase::s_pInstance)) {
        const auto refreshRenderers = [this]() {
            this->refreshRenderers();
        };
        constexpr auto connectionType = Qt::QueuedConnection;
        connect(pConfig,
                &QmlConfigProxy::waveformDefaultZoomChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformPlayMarkerPositionChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformEnabledChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformFrameRateChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformUntilMarkShowBeatsChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformUntilMarkShowTimeChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformUntilMarkAlignChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformUntilMarkTextPointSizeChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformUntilMarkTextHeightLimitChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformVisualGainAllChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformVisualGainLowChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformVisualGainMediumChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformVisualGainHighChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformEndOfTrackWarningTimeChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformTypeChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformOptionsChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformBeatGridAlphaChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformStemOpacityChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformStemOutlineOpacityChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformStemReorderOnChangeChanged,
                this,
                refreshRenderers,
                connectionType);
        connect(pConfig,
                &QmlConfigProxy::waveformStemSplitTracksChanged,
                this,
                refreshRenderers,
                connectionType);
    }
    QQuickItem::componentComplete();
}

double QmlWaveformDisplay::getPosition() const {
    return m_visualPlayPosition->getEnginePlayPos();
}

void QmlWaveformDisplay::setPosition(double value) {
    if (!m_pTrack || !m_pTrack->internal()) {
        return;
    }
    m_visualPlayPosition->set(std::clamp(value, 0.0, 1.0),
            1.0,
            0,
            0.0,
            0.0,
            SlipModeState::Disabled,
            false,
            false,
            false,
            0,
            0,
            m_pTrack->internal()->getDuration(),
            0);
    update();
}

void QmlWaveformDisplay::setStaticTrack(QmlTrackProxy* track) {
    m_pTrack = track;
    if (!m_pTrack) {
        if (!m_pPlayer) {
            setCurrentTrack(nullptr);
        }
        return;
    }
    if (!track->internal()) {
        return;
    }
    if (!track->internal()->getWaveform()) {
        emit QmlLibraryProxy::get() -> analyzeTracks({track->internal()->getId()});
    }
    setVisualPlayPosition(m_visualPlayPosition);
    m_visualPlayPosition->set(0.0,
            1.0,
            1024. /
                    static_cast<double>(m_pTrack->internal()->getBitrate()) *
                    m_pTrack->internal()->getDuration(),
            0.0,
            0.0,
            SlipModeState::Disabled,
            false,
            false,
            false,
            0,
            0,
            m_pTrack->internal()->getDuration(),
            1024. / static_cast<double>(mixxx::kEngineChannelOutputCount) /
                    static_cast<double>(m_pTrack->internal()->getSampleRate()) * 1000000.0);
    setCurrentTrack(track->internal());
    emit trackChanged(track);
    emit groupChanged("");
    update();
}

#ifdef __ANDROID__
namespace {
// TEMP-DIAG10 (remove before commit): where the time of a slow frame goes.
struct FrameDiag {
    using Clock = std::chrono::steady_clock;
    Clock::time_point syncBegin, syncEnd, renderBegin, renderEnd, frameEnd, lastFrameEnd;
    double sumSync = 0, sumRender = 0, sumSwap = 0, sumIdle = 0;
    double worstSync = 0, worstRender = 0, worstSwap = 0;
    int frames = 0, slow = 0;
    Clock::time_point statStart = Clock::now();
};
FrameDiag g_frameDiag;
double msBetween(FrameDiag::Clock::time_point a, FrameDiag::Clock::time_point b) {
    return std::chrono::duration<double, std::milli>(b - a).count();
}
} // namespace
#endif

void QmlWaveformDisplay::slotWindowChanged(QQuickWindow* window) {
    m_dirtyFlag.setFlag(DirtyFlag::Window, true);
#ifdef __ANDROID__
    static bool diagConnected = false;
    if (window && !diagConnected) {
        diagConnected = true;
        using C = FrameDiag::Clock;
        connect(window, &QQuickWindow::beforeSynchronizing, window, [] { g_frameDiag.syncBegin = C::now(); }, Qt::DirectConnection);
        connect(window, &QQuickWindow::afterSynchronizing, window, [] { g_frameDiag.syncEnd = C::now(); }, Qt::DirectConnection);
        connect(window, &QQuickWindow::beforeRendering, window, [] { g_frameDiag.renderBegin = C::now(); }, Qt::DirectConnection);
        connect(window, &QQuickWindow::afterRendering, window, [] { g_frameDiag.renderEnd = C::now(); }, Qt::DirectConnection);
        connect(window, &QQuickWindow::afterFrameEnd, window, [] {
            FrameDiag& d = g_frameDiag;
            d.frameEnd = C::now();
            const double sync = msBetween(d.syncBegin, d.syncEnd);
            const double render = msBetween(d.renderBegin, d.renderEnd);
            const double swap = msBetween(d.renderEnd, d.frameEnd);
            const double total = msBetween(d.syncBegin, d.frameEnd);
            if (d.frames++ > 0 && total > 20.0) ++d.slow;
            d.sumSync += sync; d.sumRender += render; d.sumSwap += swap;
            d.worstSync = std::max(d.worstSync, sync);
            d.worstRender = std::max(d.worstRender, render);
            d.worstSwap = std::max(d.worstSwap, swap);
            if (msBetween(d.statStart, d.frameEnd) > 5000 && d.frames > 10) {
                __android_log_print(ANDROID_LOG_INFO, "mixxx-wf",
                        "FRAMES n=%d slow(>20ms) %d | sync avg %.1f worst %.1f | render(cpu) avg %.1f worst %.1f | swap avg %.1f worst %.1f ms",
                        d.frames, d.slow, d.sumSync / d.frames, d.worstSync, d.sumRender / d.frames,
                        d.worstRender, d.sumSwap / d.frames, d.worstSwap);
                d = FrameDiag();
            }
        }, Qt::DirectConnection);
    }
#endif
    if (window) {
        connect(window,
                &QQuickWindow::afterFrameEnd,
                this,
                &QmlWaveformDisplay::slotFrameSwapped,
                Qt::UniqueConnection);
    }
    m_timer.restart();
    m_frameRateTimer.stop();
    m_frameRequestTimer.restart();
}

void QmlWaveformDisplay::setOptions(mixxx::qml::WaveformRendererSignalBaseOptions options) {
    m_options = options;
    emit optionsChanged(options);

    m_dirtyFlag.setFlag(DirtyFlag::Window, true);
    update();
}

void QmlWaveformDisplay::refreshRenderers() {
    // Renderer objects and their render-graph nodes live on the scene-graph
    // thread. Only mark the item dirty here; updatePaintNode() clears and
    // rebuilds the stack on that thread.
    m_dirtyFlag.setFlag(DirtyFlag::Window, true);
    update();
}

std::chrono::microseconds QmlWaveformDisplay::fromTimerToNextSync(const PerformanceTimer& timer) {
    // TODO @m0dB probably better to use a singleton instead of deriving QmlWaveformDisplay from
    // ISyncTimeProvider and have each keep track of this.
    if (m_pTrack) {
        return m_syncInterval;
    }
    return m_syncInterval + std::chrono::microseconds(m_timer.difference(timer).toIntegerMicros());
}

void QmlWaveformDisplay::slotFrameSwapped() {
    m_timer.restart();
    requestUpdateAtFrameRate();
}

void QmlWaveformDisplay::requestUpdateAtFrameRate() {
    if (!window()) {
        return;
    }

#ifdef __ANDROID__
    // Android edition: a timer that rounds up to whole milliseconds misses the vsync
    // from time to time (a frame is shown twice, the waveform judders). At the frame
    // rate of the display (60 or more) the next frame is requested right away: the swap
    // waits for the vsync by itself, so the frames follow the display exactly.
    if (m_frameRate >= 60) {
        if (window() && window()->screen() && window()->screen()->refreshRate() > 1.0) {
            m_syncInterval = std::chrono::microseconds(
                    static_cast<qint64>(1'000'000 / window()->screen()->refreshRate()));
        }
        m_frameRateTimer.stop();
        update();
        return;
    }
#endif
    if (!m_frameRequestTimer.isValid()) {
        m_frameRequestTimer.start();
    }

    const qint64 elapsedMicros = m_frameRequestTimer.nsecsElapsed() / 1000;
    const qint64 intervalMicros = m_syncInterval.count();
    if (elapsedMicros >= intervalMicros) {
        m_frameRateTimer.stop();
        m_frameRequestTimer.restart();
        update();
        return;
    }

    const qint64 remainingMicros = intervalMicros - elapsedMicros;
    const int remainingMillis = static_cast<int>(
            std::max<qint64>(1, (remainingMicros + 999) / 1000));
    m_frameRateTimer.start(remainingMillis);
}

void QmlWaveformDisplay::geometryChange(const QRectF& newGeometry, const QRectF& oldGeometry) {
    m_dirtyFlag.setFlag(DirtyFlag::Geometry, true);
    update();
    QQuickItem::geometryChange(newGeometry, oldGeometry);
}

QSGNode* QmlWaveformDisplay::updatePaintNode(QSGNode* node, UpdatePaintNodeData*) {
    if (m_dirtyFlag.testFlag(DirtyFlag::Window)) {
        delete node;
        node = nullptr;
        m_dirtyFlag.setFlag(DirtyFlag::Window, false);
    }

    DEBUG_ASSERT(!node || node->childCount() == 1);

    // The node tree (clip node -> background node -> renderers) is only ever
    // created below, so static_cast is safe. dynamic_cast failed on Android
    // (type_info of Qt classes is not unique across the shared libraries): the
    // whole renderer stack, including all waveform marks, was rebuilt every
    // frame.
    auto* pClipNode = node ? static_cast<QSGClipNode*>(node) : nullptr;
    auto* pBgNode = pClipNode ? static_cast<QSGSimpleRectNode*>(pClipNode->lastChild()) : nullptr;

    if (!pBgNode) {
        if (pClipNode) {
            delete pClipNode;
        }
        pClipNode = new QSGClipNode();
        pBgNode = new QSGSimpleRectNode();
        m_dirtyFlag.setFlag(DirtyFlag::Background, true);
        m_dirtyFlag.setFlag(DirtyFlag::Geometry, true);

        pClipNode->setIsRectangular(true);
        pClipNode->setGeometry(pBgNode->geometry());

        pClipNode->setClipRect(boundingRect());
        pBgNode->setRect(boundingRect());

        if (getContext()) {
            delete getContext();
        }
        setContext(new rendergraph::Context(window()));
        rendergraph::Node* pTopNode = new rendergraph::Node;

        m_rendererStack.clear();
        for (auto* pQmlRenderer : std::as_const(m_waveformRenderers)) {
            if (!pQmlRenderer->isEnabled()) {
                continue;
            }
            if (!pQmlRenderer->isSupported()) {
                qWarning() << "Ignoring the unsupported" << pQmlRenderer << "renderer";
                continue;
            }
            auto renderer = pQmlRenderer->create(this, m_options);
            // FIXME Some renderer will return nullptr till
            // WaveformRendererTextured is supported (#14990)
            // It is also expected for the stem renderer to return a null value in
            // case STEM are not enabled.
            if (!renderer.renderer) {
                continue;
            }
            addRenderer(renderer.renderer);
            pTopNode->appendChildNode(std::move(renderer.node));
        }

        pBgNode->appendChildNode(pTopNode);
        pClipNode->appendChildNode(pBgNode);
        init();
        // The track can be assigned before the scene-graph renderer stack is
        // created. Replay it after renderer initialization so marks and STEM
        // renderers receive their onSetTrack() setup on the render thread.
        if (getTrackInfo()) {
            setTrack(getTrackInfo());
        }
    }

    if (m_dirtyFlag.testFlag(DirtyFlag::Background)) {
        m_dirtyFlag.setFlag(DirtyFlag::Background, false);
        pBgNode->setColor(m_backgroundColor);
    }

    if (m_dirtyFlag.testFlag(DirtyFlag::Geometry)) {
        m_dirtyFlag.setFlag(DirtyFlag::Geometry, false);
        pBgNode->setRect(boundingRect());
        pClipNode->setClipRect(boundingRect());
        pBgNode->markDirty(QSGNode::DirtyGeometry);
        pClipNode->markDirty(QSGNode::DirtyGeometry);
        resizeRenderer(boundingRect().width(),
                boundingRect().height(),
                window()->devicePixelRatio());
    }

    onPreRender(this);

    for (auto* pRenderer : std::as_const(m_rendererStack)) {
        pRenderer->update();
    }

    pBgNode->markDirty(QSGNode::DirtyForceUpdate);
    return pClipNode;
}

QmlPlayerProxy* QmlWaveformDisplay::getPlayer() const {
    return m_pPlayer;
}

void QmlWaveformDisplay::setPlayer(QmlPlayerProxy* pPlayer) {
    if (m_pPlayer == pPlayer) {
        return;
    }

    if (m_pPlayer != nullptr) {
        m_pPlayer->internalTrackPlayer()->disconnect(this);
    }

    m_pPlayer = pPlayer;

    if (m_pPlayer != nullptr) {
        setGroup(m_pPlayer->internalTrackPlayer()->getGroup());
        setCurrentTrack(m_pPlayer->internalTrackPlayer()->getLoadedTrack());
        connect(m_pPlayer->internalTrackPlayer(),
                &BaseTrackPlayer::newTrackLoaded,
                this,
                &QmlWaveformDisplay::slotTrackLoaded);
        connect(m_pPlayer->internalTrackPlayer(),
                &BaseTrackPlayer::loadingTrack,
                this,
                &QmlWaveformDisplay::slotTrackLoading);
        connect(m_pPlayer->internalTrackPlayer(),
                &BaseTrackPlayer::playerEmpty,
                this,
                &QmlWaveformDisplay::slotTrackUnloaded);
    }

    emit playerChanged();
    update();
}

void QmlWaveformDisplay::setGroup(const QString& group) {
    if (getGroup() == group) {
        return;
    }

    WaveformWidgetRenderer::setGroup(group);
    emit groupChanged(group);
}

void QmlWaveformDisplay::slotTrackLoaded(TrackPointer pTrack) {
    // TODO: Investigate if it's a bug that this debug assertion fails when
    // passing tracks on the command line
    // DEBUG_ASSERT(m_pCurrentTrack == pTrack);
    setCurrentTrack(pTrack);
}

void QmlWaveformDisplay::slotTrackLoading(TrackPointer pNewTrack, TrackPointer pOldTrack) {
    Q_UNUSED(pOldTrack); // only used in DEBUG_ASSERT
    DEBUG_ASSERT(getTrackInfo() == pOldTrack);
    setCurrentTrack({});
}

void QmlWaveformDisplay::slotTrackUnloaded() {
    setCurrentTrack(nullptr);
}

void QmlWaveformDisplay::setCurrentTrack(TrackPointer pTrack) {
    auto pCurrentTrack = getTrackInfo();
    // TODO: Check if this is actually possible
    if (pCurrentTrack == pTrack) {
        return;
    }

    if (pCurrentTrack != nullptr) {
        disconnect(pCurrentTrack.get(), nullptr, this, nullptr);
    }

    setTrack(pTrack);
    if (pTrack != nullptr) {
        connect(pTrack.get(),
                &Track::waveformSummaryUpdated,
                this,
                &QmlWaveformDisplay::slotWaveformUpdated);
    }
    slotWaveformUpdated();
}

void QmlWaveformDisplay::slotWaveformUpdated() {
    update();
}

QQmlListProperty<QmlWaveformRendererFactory> QmlWaveformDisplay::renderers() {
    return {this,
            nullptr,
            &QmlWaveformDisplay::renderers_append,
            &QmlWaveformDisplay::renderers_count,
            &QmlWaveformDisplay::renderers_at,
            &QmlWaveformDisplay::renderers_clear};
}

// Static
void QmlWaveformDisplay::renderers_append(
        QQmlListProperty<QmlWaveformRendererFactory>* pList,
        QmlWaveformRendererFactory* value) {
    QmlWaveformDisplay* pWaveform = static_cast<QmlWaveformDisplay*>(pList->object);
    VERIFY_OR_DEBUG_ASSERT(pWaveform) {
        return;
    }
    pWaveform->m_dirtyFlag.setFlag(DirtyFlag::Window, true);
    pWaveform->m_waveformRenderers.append(value);
    QObject::connect(value,
            &QmlWaveformRendererFactory::enabledChanged,
            pWaveform,
            [pWaveform]() {
                pWaveform->m_dirtyFlag.setFlag(DirtyFlag::Window, true);
                pWaveform->update();
            });
}

// Static
qsizetype QmlWaveformDisplay::renderers_count(QQmlListProperty<QmlWaveformRendererFactory>* pList) {
    QmlWaveformDisplay* pWaveform = static_cast<QmlWaveformDisplay*>(pList->object);
    VERIFY_OR_DEBUG_ASSERT(pWaveform) {
        return 0;
    }
    pWaveform->m_dirtyFlag.setFlag(DirtyFlag::Window, true);
    return pWaveform->m_waveformRenderers.count();
}

// Static
QmlWaveformRendererFactory* QmlWaveformDisplay::renderers_at(
        QQmlListProperty<QmlWaveformRendererFactory>* pList, qsizetype index) {
    VERIFY_OR_DEBUG_ASSERT(pList && pList->object) {
        return nullptr;
    }
    QmlWaveformDisplay* pWaveform = static_cast<QmlWaveformDisplay*>(pList->object);
    VERIFY_OR_DEBUG_ASSERT(pWaveform) {
        return nullptr;
    }
    pWaveform->m_dirtyFlag.setFlag(DirtyFlag::Window, true);
    return pWaveform->m_waveformRenderers.at(index);
}

// Static
void QmlWaveformDisplay::renderers_clear(QQmlListProperty<QmlWaveformRendererFactory>* pList) {
    QmlWaveformDisplay* pWaveform = static_cast<QmlWaveformDisplay*>(pList->object);
    VERIFY_OR_DEBUG_ASSERT(pWaveform) {
        return;
    }
    pWaveform->m_dirtyFlag.setFlag(DirtyFlag::Window, true);
    return pWaveform->m_waveformRenderers.clear();
}

} // namespace qml
} // namespace mixxx
