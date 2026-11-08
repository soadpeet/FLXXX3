#include "effects/effectsmanager.h"

#include "effects/backends/builtin/colorfxeffects.h"

#include <QDir>
#include <QElapsedTimer>
#include <QMetaType>
#include <QTimer>
#include <algorithm>
#include <cmath>

#include "control/controlobject.h"

#include "effects/chains/equalizereffectchain.h"
#include "effects/chains/outputeffectchain.h"
#include "effects/chains/quickeffectchain.h"
#include "effects/chains/standardeffectchain.h"
#include "effects/effectslot.h"
#include "effects/effectsmessenger.h"
#include "effects/presets/effectchainpreset.h"
#include "effects/presets/effectpresetmanager.h"
#include "effects/presets/effectxmlelements.h"
#include "effects/visibleeffectslist.h"
#include "engine/effects/engineeffectsmanager.h"
#include "util/assert.h"

namespace {
const unsigned int kEffectMessagePipeFifoSize = 2048;
const QString kEffectsXmlFile = QStringLiteral("effects.xml");
} // anonymous namespace

#ifdef __ANDROID__
#include <android/log.h>

namespace {
// Owns the two controls of the Color FX and calls applyColorFx() (in the main
// thread) when one of them changes.
class AndroidColorFxHelper : public QObject {
  public:
    explicit AndroidColorFxHelper(EffectsManager* pManager)
            : m_pColorFx(std::make_unique<ControlObject>(
                      ConfigKey(QStringLiteral("[AndroidDJ]"), QStringLiteral("color_fx")),
                      false,
                      false,
                      false,
                      5.0)),
              m_pColorFxOn(std::make_unique<ControlObject>(
                      ConfigKey(QStringLiteral("[AndroidDJ]"), QStringLiteral("color_fx_on")),
                      false,
                      false,
                      false,
                      0.0)) {
        connect(m_pColorFx.get(), &ControlObject::valueChanged, this, [pManager](double) {
            pManager->applyColorFx();
        });
        connect(m_pColorFxOn.get(), &ControlObject::valueChanged, this, [pManager](double) {
            pManager->applyColorFx();
        });
    }

  private:
    std::unique_ptr<ControlObject> m_pColorFx;
    std::unique_ptr<ControlObject> m_pColorFxOn;
};
} // namespace
#endif

EffectsManager::EffectsManager(
        UserSettingsPointer pConfig,
        std::shared_ptr<ChannelHandleFactory> pChannelHandleFactory)
        : m_pConfig(pConfig),
          m_pChannelHandleFactory(pChannelHandleFactory),
          m_loEqFreq(ConfigKey(kMixerProfile, kLowEqFrequency), 0., 22040),
          m_hiEqFreq(ConfigKey(kMixerProfile, kHighEqFrequency), 0., 22040),
          m_initializedFromEffectsXml(false) {
    qRegisterMetaType<EffectChainMixMode>("EffectChainMixMode");

    m_pBackendManager = EffectsBackendManagerPointer(new EffectsBackendManager());

    auto [requestPipe, responsePipe] = makeTwoWayMessagePipe<EffectsRequest*,
            EffectsResponse>(kEffectMessagePipeFifoSize,
            kEffectMessagePipeFifoSize);

    m_pMessenger = EffectsMessengerPointer::create(std::move(requestPipe));
    m_pEngineEffectsManager = std::make_unique<EngineEffectsManager>(std::move(responsePipe));

    m_pEffectPresetManager = EffectPresetManagerPointer(
            new EffectPresetManager(pConfig, m_pBackendManager));

    m_pChainPresetManager = EffectChainPresetManagerPointer(
            new EffectChainPresetManager(pConfig, m_pBackendManager));

    m_pVisibleEffectsList = VisibleEffectsListPointer(new VisibleEffectsList());
#ifdef __ANDROID__
    m_pColorFxHelper = std::make_unique<AndroidColorFxHelper>(this);
#endif
}

#ifdef __ANDROID__

void EffectsManager::applyColorFx() {
    static const QStringList kEffectIds = {
            QStringLiteral("org.mixxx.effects.cfx_space"),
            QStringLiteral("org.mixxx.effects.cfx_dubecho"),
            QStringLiteral("org.mixxx.effects.cfx_crush"),
            QStringLiteral("org.mixxx.effects.cfx_sweep"),
            QStringLiteral("org.mixxx.effects.cfx_noise"),
            QStringLiteral("org.mixxx.effects.filter"),
    };
    const int index = std::clamp(
            static_cast<int>(std::lround(ControlObject::get(ConfigKey(
                    QStringLiteral("[AndroidDJ]"), QStringLiteral("color_fx"))))),
            0,
            static_cast<int>(kEffectIds.size()) - 1);
    const bool on = ControlObject::get(ConfigKey(
                            QStringLiteral("[AndroidDJ]"), QStringLiteral("color_fx_on"))) > 0.5;
    const EffectManifestPointer pManifest =
            m_pBackendManager->getManifest(kEffectIds.at(index), EffectBackendType::BuiltIn);
    // SMART CFX off: the Color FX fade out instead of being cut, like the Beat FX.
    // The times differ per effect (see below), the filter is switched off at once.
    static std::unique_ptr<QTimer> s_releaseTimer;
    static QElapsedTimer s_releaseClock;
    static bool s_releasing = false;
    // Release time per effect: the reverb and the echo ring out, the others are short, the
    // filter is cut at once.
    static const int kReleaseMsByIndex[6] = {3000, 2500, 300, 500, 500, 0};
    static int s_releaseMs = 2000;
    const auto setChainsEnabled = [this](bool enabled) {
        for (const auto& pChain : std::as_const(m_quickEffectChains)) {
            ControlObject::set(
                    ConfigKey(pChain->group(), QStringLiteral("enabled")), enabled ? 1.0 : 0.0);
        }
    };
    bool enable = on;
    if (on) {
        if (s_releaseTimer) {
            s_releaseTimer->stop();
        }
        s_releasing = false;
        ColorFxBase::setRelease(1.0f);
    } else if (s_releasing) {
        enable = true; // keep running until the release is over
    } else if (kReleaseMsByIndex[index] > 0 && !m_quickEffectChains.isEmpty() &&
            ControlObject::get(ConfigKey(m_quickEffectChains.cbegin().value()->group(),
                    QStringLiteral("enabled"))) > 0.5) {
        s_releasing = true;
        enable = true;
        s_releaseMs = kReleaseMsByIndex[index];
        s_releaseClock.start();
        if (!s_releaseTimer) {
            s_releaseTimer = std::make_unique<QTimer>();
            s_releaseTimer->setInterval(20);
            QObject::connect(s_releaseTimer.get(), &QTimer::timeout, [setChainsEnabled]() {
                const double t = static_cast<double>(s_releaseClock.elapsed()) / s_releaseMs;
                if (t >= 1.0) {
                    s_releaseTimer->stop();
                    s_releasing = false;
                    setChainsEnabled(false);
                    ColorFxBase::setRelease(1.0f);
                } else {
                    ColorFxBase::setRelease(static_cast<float>(1.0 - t));
                }
            });
        }
        s_releaseTimer->start();
    }
    for (const auto& pChain : std::as_const(m_quickEffectChains)) {
        if (pManifest) {
            const auto pSlot = pChain->getEffectSlot(0);
            if (pSlot && (!pSlot->isLoaded() || pSlot->getManifest() != pManifest)) {
                pSlot->loadEffectWithDefaults(pManifest);
                // take over the position of the knob at once
                pChain->setSuperParameter(
                        ControlObject::get(ConfigKey(pChain->group(), QStringLiteral("super1"))),
                        true);
            }
        }
        __android_log_print(ANDROID_LOG_INFO, "mixxx-cfx", "applyColorFx %s: effect %d on %d",
                pChain->group().toUtf8().constData(), index, enable ? 1 : 0);
        ControlObject::set(ConfigKey(pChain->group(), QStringLiteral("enabled")), enable ? 1.0 : 0.0);
    }
}
#endif

EffectsManager::~EffectsManager() {
    m_pMessenger->initiateShutdown();

    saveEffectsXml();

    // The EffectChains must be deleted before the EffectsBackends in case
    // there is an LV2 effect currently loaded.
    // ~LV2GroupState calls lilv_instance_free, which will segfault if called
    // after ~LV2Backend calls lilv_world_free.
    m_equalizerEffectChains.clear();
    m_quickStemEffectChains.clear();
    m_quickEffectChains.clear();
    m_standardEffectChains.clear();
    m_outputEffectChain.clear();
    m_effectChainSlotsByGroup.clear();

    m_pMessenger->processEffectsResponses();
}

void EffectsManager::setup() {
    // Add postfader effect chain slots
    addStandardEffectChains();
    addOutputEffectChain();
    // EQ and QuickEffect chain slots are initialized when PlayerManager creates decks.
    // Now read effects.xml to load defaults or restore previous states of standard
    // effect chains and QuickEffect chain, though only for decks that have been
    // created by now. For decks added later on see addDeck().
    // Note: flip this bool now so any deck potentially being added while
    // readEffectsXml() is running is also initialized.
    m_initializedFromEffectsXml = true;
    readEffectsXml();
}

void EffectsManager::registerInputChannel(const ChannelHandleAndGroup& handle_group) {
    VERIFY_OR_DEBUG_ASSERT(!m_registeredInputChannels.contains(handle_group)) {
        return;
    }
    m_registeredInputChannels.insert(handle_group);

    // EqualizerEffectChains, QuickEffectChains, and OutputEffectChains
    // only process one input channel, so they do not need to have new input
    // channels registered.
    for (EffectChainPointer pChainSlot : std::as_const(m_standardEffectChains)) {
        pChainSlot->registerInputChannel(handle_group);
    }
}

void EffectsManager::registerOutputChannel(const ChannelHandleAndGroup& handle_group) {
    VERIFY_OR_DEBUG_ASSERT(!m_registeredOutputChannels.contains(handle_group)) {
        return;
    }
    m_registeredOutputChannels.insert(handle_group);
}

void EffectsManager::addStandardEffectChains() {
    for (int i = 0; i < kNumStandardEffectUnits; ++i) {
        VERIFY_OR_DEBUG_ASSERT(!m_effectChainSlotsByGroup.contains(
                StandardEffectChain::formatEffectChainGroup(i))) {
            continue;
        }

        auto pChainSlot = StandardEffectChainPointer(
                new StandardEffectChain(i, this, m_pMessenger));

        m_standardEffectChains.append(pChainSlot);
        m_effectChainSlotsByGroup.insert(pChainSlot->group(), pChainSlot);
    }
}

void EffectsManager::addOutputEffectChain() {
    m_outputEffectChain = OutputEffectChainPointer(
            new OutputEffectChain(this, m_pMessenger));
    m_effectChainSlotsByGroup.insert(m_outputEffectChain->group(), m_outputEffectChain);
}

EffectChainPointer EffectsManager::getOutputEffectChain() const {
    return m_outputEffectChain;
}

EffectChainPointer EffectsManager::getStandardEffectChain(int unitNumber) const {
    VERIFY_OR_DEBUG_ASSERT(0 <= unitNumber && unitNumber < m_standardEffectChains.size()) {
        return EffectChainPointer();
    }
    return m_standardEffectChains.at(unitNumber);
}

void EffectsManager::addDeck(const ChannelHandleAndGroup& deckHandleGroup) {
    addEqualizerEffectChain(deckHandleGroup);
    addQuickEffectChain(deckHandleGroup);
    // If a deck is added after setup() was run we need to read effects.xml
    // again to initialize its QuickEffect chain, either with defaults or the
    // previous state.
    if (m_initializedFromEffectsXml) {
        readEffectsXmlSingleDeck(deckHandleGroup.m_name);
    }
}

void EffectsManager::addStem(const ChannelHandleAndGroup& stemHandleGroup) {
    VERIFY_OR_DEBUG_ASSERT(!m_quickStemEffectChains.contains(
            QuickEffectChain::formatEffectChainGroup(stemHandleGroup.name()))) {
        return;
    }
    auto pChainSlot = QuickEffectChainPointer(
            new QuickEffectChain(stemHandleGroup, this, m_pMessenger));
    m_quickStemEffectChains.insert(stemHandleGroup.name(), pChainSlot);
    m_effectChainSlotsByGroup.insert(pChainSlot->group(), pChainSlot);

    // If a stem is added after setup() was run we need to read effects.xml
    // again to initialize its QuickEffect chain, either with defaults or the
    // previous state.
    if (m_initializedFromEffectsXml) {
        readEffectsXmlSingleDeckStem(stemHandleGroup.m_name);
    }
}

void EffectsManager::resetStemQuickFxKnob(const ChannelHandleAndGroup& stemHandleGroup) {
    VERIFY_OR_DEBUG_ASSERT(m_quickStemEffectChains.contains(stemHandleGroup.name())) {
        return;
    }
    auto pChainSlot = m_quickStemEffectChains[stemHandleGroup.name()];

    VERIFY_OR_DEBUG_ASSERT(pChainSlot) {
        return;
    }

    pChainSlot->resetToDefault();
}

void EffectsManager::addEqualizerEffectChain(const ChannelHandleAndGroup& deckHandleGroup) {
    VERIFY_OR_DEBUG_ASSERT(!m_equalizerEffectChains.contains(
            EqualizerEffectChain::formatEffectChainGroup(deckHandleGroup.name()))) {
        return;
    }

    auto pChainSlot = EqualizerEffectChainPointer(
            new EqualizerEffectChain(deckHandleGroup, this, m_pMessenger));

    m_equalizerEffectChains.insert(deckHandleGroup.name(), pChainSlot);
    m_effectChainSlotsByGroup.insert(pChainSlot->group(), pChainSlot);
}

void EffectsManager::addQuickEffectChain(const ChannelHandleAndGroup& deckHandleGroup) {
    VERIFY_OR_DEBUG_ASSERT(!m_quickEffectChains.contains(
            QuickEffectChain::formatEffectChainGroup(deckHandleGroup.name()))) {
        return;
    }

    auto pChainSlot = QuickEffectChainPointer(
            new QuickEffectChain(deckHandleGroup, this, m_pMessenger));

    m_quickEffectChains.insert(deckHandleGroup.name(), pChainSlot);
    m_effectChainSlotsByGroup.insert(pChainSlot->group(), pChainSlot);
}

void EffectsManager::loadDefaultEqsAndQuickEffects() {
    auto pDefaultEqEffect = m_pChainPresetManager->getDefaultEqEffect();
    for (const auto& pEqChainSlot : std::as_const(m_equalizerEffectChains)) {
        const auto pEqEffectSlot = pEqChainSlot->getEffectSlot(0);
        VERIFY_OR_DEBUG_ASSERT(pEqEffectSlot) {
            return;
        }
        pEqEffectSlot->loadEffectWithDefaults(pDefaultEqEffect);
    }

    const auto pDefaultQuickEffectPreset =
            m_pChainPresetManager->getDefaultQuickEffectPreset();
    for (const auto& pChainSlot : std::as_const(m_quickEffectChains)) {
        pChainSlot->loadChainPreset(pDefaultQuickEffectPreset);
    }
}

EffectChainPointer EffectsManager::getEffectChain(
        const QString& group) const {
    return m_effectChainSlotsByGroup.value(group);
}

bool EffectsManager::isAdoptMetaknobSettingEnabled() const {
    return m_pConfig->getValue(ConfigKey("[Effects]", "AdoptMetaknobValue"), true);
}

void EffectsManager::readEffectsXml() {
    QDir settingsPath(m_pConfig->getSettingsPath());
    QFile file(settingsPath.absoluteFilePath(kEffectsXmlFile));
    QDomDocument doc;

    if (file.open(QIODevice::ReadOnly)) {
        doc.setContent(&file);
    }
    file.close();

    // Note: QuickEffect and EQ chains are created only for existing main decks,
    // thus only for those the configured presets are requested
    const QStringList deckStrings = m_quickEffectChains.keys();
    EffectsXmlData data = m_pChainPresetManager->readEffectsXml(doc, deckStrings);

    for (int i = 0; i < data.standardEffectChainPresets.size(); i++) {
        m_standardEffectChains.value(i)->loadChainPreset(data.standardEffectChainPresets.at(i));
    }

    if (!data.outputChainPreset.isNull()) {
        m_outputEffectChain->loadChainPreset(data.outputChainPreset);
    }

    QHashIterator<QString, EffectManifestPointer> eqIt(data.eqEffectManifests);
    while (eqIt.hasNext()) {
        eqIt.next();
        auto pChainSlot = m_equalizerEffectChains.value(eqIt.key());
        if (pChainSlot) {
            const auto pEffectSlot = pChainSlot->getEffectSlot(0);
            VERIFY_OR_DEBUG_ASSERT(pEffectSlot) {
                return;
            }
            pEffectSlot->loadEffectWithDefaults(eqIt.value());
        }
    }

    QHashIterator<QString, EffectChainPresetPointer> qeDataIt(data.quickEffectChainPresets);
    while (qeDataIt.hasNext()) {
        qeDataIt.next();
        auto pChainSlot = m_quickEffectChains.value(qeDataIt.key());
        if (pChainSlot) {
            pChainSlot->loadChainPreset(qeDataIt.value());
        }
    }

    QHashIterator<QString, EffectChainPresetPointer> qseDataIt(data.quickStemEffectChainPresets);
    while (qseDataIt.hasNext()) {
        qseDataIt.next();
        auto pChainSlot = m_quickStemEffectChains.value(qseDataIt.key());
        if (pChainSlot) {
            pChainSlot->loadChainPreset(qseDataIt.value());
        }
    }

    m_pVisibleEffectsList->readEffectsXml(doc, m_pBackendManager);
}

void EffectsManager::readEffectsXmlSingleDeck(const QString& deckGroup) {
    QDir settingsPath(m_pConfig->getSettingsPath());
    QFile file(settingsPath.absoluteFilePath(kEffectsXmlFile));
    QDomDocument doc;

    if (file.open(QIODevice::ReadOnly)) {
        doc.setContent(&file);
    }
    file.close();

    EffectXmlDataSingleDeck data =
            m_pChainPresetManager->readEffectsXmlSingleDeck(doc, deckGroup);

    // Load EQ effect
    auto pEqChainSlot = m_equalizerEffectChains.value(deckGroup);
    if (pEqChainSlot) {
        const auto pEffectSlot = pEqChainSlot->getEffectSlot(0);
        VERIFY_OR_DEBUG_ASSERT(pEffectSlot) {
            return;
        }
        pEffectSlot->loadEffectWithDefaults(data.eqEffectManifest);
    }

    // Load Quick Effect
    auto pQuickEffectChainSlot = m_quickEffectChains.value(deckGroup);
    if (pQuickEffectChainSlot) {
        pQuickEffectChainSlot->loadChainPreset(data.quickEffectChainPreset);
    }
}

void EffectsManager::readEffectsXmlSingleDeckStem(const QString& deckStemGroup) {
    QDir settingsPath(m_pConfig->getSettingsPath());
    QFile file(settingsPath.absoluteFilePath(kEffectsXmlFile));
    QDomDocument doc;

    if (file.open(QIODevice::ReadOnly)) {
        doc.setContent(&file);
    }
    file.close();

    EffectChainPresetPointer pPreset =
            m_pChainPresetManager->readEffectsXmlSingleDeckStem(doc, deckStemGroup);

    auto pQuickEffectChainSlot = m_quickStemEffectChains.value(deckStemGroup);
    if (pQuickEffectChainSlot) {
        pQuickEffectChainSlot->loadChainPreset(pPreset);
    }
}

void EffectsManager::saveEffectsXml() {
    QDomDocument doc(EffectXml::kRoot);
    doc.setContent(EffectXml::kFileHeader);
    QDomElement rootElement = doc.createElement(EffectXml::kRoot);
    rootElement.setAttribute(
            "schemaVersion", QString::number(EffectXml::kXmlSchemaVersion));
    doc.appendChild(rootElement);

    QHash<QString, EffectManifestPointer> eqEffectManifests;
    eqEffectManifests.reserve(m_equalizerEffectChains.size());
    QHashIterator<QString, EqualizerEffectChainPointer> eqIt(m_equalizerEffectChains);
    while (eqIt.hasNext()) {
        eqIt.next();
        const auto pEffectSlot = eqIt.value()->getEffectSlot(0);
        VERIFY_OR_DEBUG_ASSERT(pEffectSlot) {
            return;
        }
        auto pManifest = pEffectSlot->getManifest();
        eqEffectManifests.insert(eqIt.key(), pManifest);
    }

    QHash<QString, EffectChainPresetPointer> quickEffectChainPresets;
    quickEffectChainPresets.reserve(m_quickEffectChains.size());
    QHashIterator<QString, QuickEffectChainPointer> qeIt(m_quickEffectChains);
    while (qeIt.hasNext()) {
        qeIt.next();
        auto* pQuickEffectChain = qeIt.value().data();
        auto pPreset = EffectChainPresetPointer::create(pQuickEffectChain);
        quickEffectChainPresets.insert(qeIt.key(), pPreset);
    }

    QHash<QString, EffectChainPresetPointer> quickStemEffectChainPresets;
    quickStemEffectChainPresets.reserve(m_quickStemEffectChains.size());
    QHashIterator<QString, QuickEffectChainPointer> qseIt(m_quickStemEffectChains);
    while (qseIt.hasNext()) {
        qseIt.next();
        auto* pQuickEffectChain = qseIt.value().data();
        auto pPreset = EffectChainPresetPointer::create(pQuickEffectChain);
        quickStemEffectChainPresets.insert(qseIt.key(), pPreset);
    }

    QList<EffectChainPresetPointer> standardEffectChainPresets;
    standardEffectChainPresets.reserve(m_standardEffectChains.size());
    for (const auto& pChainSlot : std::as_const(m_standardEffectChains)) {
        auto* pChain = pChainSlot.data();
        auto pPreset = EffectChainPresetPointer::create(pChain);
        standardEffectChainPresets.append(pPreset);
    }

    const auto outputChainPreset = m_outputEffectChain.isNull()
            // required for tests when no output effect chain exists
            ? EffectChainPresetPointer::create()
            // no ownership concerns apply because we're just calling
            // EffectChainPreset::EffectChainPreset(const EffectChain* chain)
            : EffectChainPresetPointer::create(m_outputEffectChain.data());

    m_pChainPresetManager->saveEffectsXml(&doc,
            EffectsXmlData{
                    eqEffectManifests,
                    quickEffectChainPresets,
                    quickStemEffectChainPresets,
                    standardEffectChainPresets,
                    outputChainPreset});

    m_pVisibleEffectsList->saveEffectsXml(&doc, m_pBackendManager);

    QDir settingsPath(m_pConfig->getSettingsPath());
    if (!settingsPath.exists()) {
        return;
    }
    QFile file(settingsPath.absoluteFilePath(kEffectsXmlFile));
    if (!file.open(QIODevice::Truncate | QIODevice::WriteOnly)) {
        qWarning() << "EffectsManager: could not save effects.xml file";
        return;
    }
    file.write(doc.toString().toUtf8());
    file.close();
}
