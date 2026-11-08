#include "controllers/midi/androidmidicontroller.h"

#include <chrono>

#include <android/log.h>

#include <QJniEnvironment>
#include <QMutex>
#include <QMutexLocker>
#include <atomic>

#include "control/controlobject.h"
#include "controllers/midi/midiutils.h"
#include "moc_androidmidicontroller.cpp"
#include "util/duration.h"

namespace {
std::atomic<int> s_openControllers{0};
QMutex s_nameMutex;
QString s_lastOpenedName;

constexpr const char* kLogTag = "mixxx-midi";
constexpr int kOpenTimeoutMs = 5000;
constexpr size_t kReceiveBufferSize = 512;
// Upper bound of packets handled per poll() so that a flood of messages cannot
// block the controller thread.
constexpr int kMaxPacketsPerPoll = 256;

QString nameFor(const AndroidMidiController::DeviceDescription& description) {
    if (!description.product.isEmpty()) {
        return description.product;
    }
    if (!description.name.isEmpty()) {
        return description.name;
    }
    return QStringLiteral("Android MIDI device %1").arg(description.deviceId);
}
} // namespace

int AndroidMidiController::openControllerCount() {
    return s_openControllers.load();
}

QString AndroidMidiController::lastOpenedControllerName() {
    const QMutexLocker locker(&s_nameMutex);
    return s_lastOpenedName;
}

AndroidMidiController::AndroidMidiController(
        const DeviceDescription& description, const QJniObject& helper)
        : MidiController(nameFor(description)),
          m_description(description),
          m_helper(helper) {
    setInputDevice(description.deviceOutputPorts > 0);
    setOutputDevice(description.deviceInputPorts > 0);
}

AndroidMidiController::~AndroidMidiController() {
    if (isOpen()) {
        close();
    }
}

int AndroidMidiController::open(const QString& resourcePath) {
    if (isOpen()) {
        qCWarning(m_logBase) << "Android MIDI device" << getName() << "already open";
        return -1;
    }

    m_parser.reset();

    qCInfo(m_logBase) << "AndroidMidiController: Opening" << getName() << "id"
                      << m_description.deviceId;
    __android_log_print(ANDROID_LOG_INFO,
            kLogTag,
            "opening '%s' id=%d (device ports: in=%d out=%d)",
            getName().toUtf8().constData(),
            m_description.deviceId,
            m_description.deviceInputPorts,
            m_description.deviceOutputPorts);

    m_midiDevice = m_helper.callObjectMethod("openDevice",
            "(II)Landroid/media/midi/MidiDevice;",
            static_cast<jint>(m_description.deviceId),
            static_cast<jint>(kOpenTimeoutMs));
    QJniEnvironment env;
    env.checkAndClearExceptions();
    if (!m_midiDevice.isValid()) {
        qCWarning(m_logBase) << "Could not open Android MIDI device" << getName();
        __android_log_print(ANDROID_LOG_WARN, kLogTag, "MidiHelper.openDevice failed");
        return -2;
    }

    media_status_t status = AMidiDevice_fromJava(env.jniEnv(), m_midiDevice.object(), &m_pDevice);
    if (status != AMEDIA_OK || !m_pDevice) {
        qCWarning(m_logBase) << "AMidiDevice_fromJava failed:" << status;
        __android_log_print(ANDROID_LOG_WARN, kLogTag, "AMidiDevice_fromJava failed: %d", status);
        m_pDevice = nullptr;
        m_helper.callMethod<void>("closeDevice", "(I)V", static_cast<jint>(m_description.deviceId));
        m_midiDevice = QJniObject();
        return -3;
    }

    if (isInputDevice() && AMidiDevice_getNumOutputPorts(m_pDevice) > 0) {
        status = AMidiOutputPort_open(m_pDevice, 0, &m_pReadPort);
        if (status != AMEDIA_OK) {
            qCWarning(m_logBase) << "AMidiOutputPort_open failed:" << status;
            m_pReadPort = nullptr;
        }
    }
    if (isOutputDevice() && AMidiDevice_getNumInputPorts(m_pDevice) > 0) {
        status = AMidiInputPort_open(m_pDevice, 0, &m_pWritePort);
        if (status != AMEDIA_OK) {
            qCWarning(m_logBase) << "AMidiInputPort_open failed:" << status;
            m_pWritePort = nullptr;
        }
    }

    if (!m_pReadPort && !m_pWritePort) {
        releasePorts();
        return -4;
    }

    startEngine();
    if (!applyMapping(resourcePath)) {
        qCWarning(m_logBase) << "AndroidMidiController: applying the mapping failed for" << getName();
    }
    setOpen(true);
    s_openControllers.fetch_add(1);
    {
        const QMutexLocker locker(&s_nameMutex);
        s_lastOpenedName = getName();
    }
    return 0;
}

void AndroidMidiController::releasePorts() {
    if (m_pReadPort) {
        AMidiOutputPort_close(m_pReadPort);
        m_pReadPort = nullptr;
    }
    if (m_pWritePort) {
        AMidiInputPort_close(m_pWritePort);
        m_pWritePort = nullptr;
    }
    if (m_pDevice) {
        AMidiDevice_release(m_pDevice);
        m_pDevice = nullptr;
    }
    if (m_midiDevice.isValid()) {
        m_helper.callMethod<void>("closeDevice", "(I)V", static_cast<jint>(m_description.deviceId));
        QJniEnvironment().checkAndClearExceptions();
        m_midiDevice = QJniObject();
    }
}

int AndroidMidiController::close() {
    if (!isOpen()) {
        qCWarning(m_logBase) << "Android MIDI device" << getName() << "already closed";
        return -1;
    }

    stopEngine();
    MidiController::close();
    releasePorts();
    setOpen(false);
    s_openControllers.fetch_sub(1);
    __android_log_print(ANDROID_LOG_INFO, kLogTag, "closed '%s'", getName().toUtf8().constData());
    return 0;
}

bool AndroidMidiController::poll() {
    if (!m_pReadPort) {
        return false;
    }

    uint8_t buffer[kReceiveBufferSize];
    bool received = false;
    for (int packet = 0; packet < kMaxPacketsPerPoll; ++packet) {
        int32_t opcode = 0;
        size_t numBytes = 0;
        int64_t timestampNs = 0;
        const ssize_t numMessages = AMidiOutputPort_receive(
                m_pReadPort, &opcode, buffer, sizeof(buffer), &numBytes, &timestampNs);
        if (numMessages < 0) {
            qCWarning(m_logInput) << "AMidiOutputPort_receive error:" << numMessages;
            return received;
        }
        if (numMessages == 0) {
            break;
        }
        if (opcode != AMIDI_OPCODE_DATA || numBytes == 0) {
            continue;
        }
        received = true;

        const mixxx::Duration timestamp = mixxx::Duration::fromNanos(timestampNs);
        m_parser.feed(
                buffer,
                numBytes,
                [this, timestamp](uint8_t status, uint8_t data1, uint8_t data2) {
                    {
                        // The DDJ-FLX4 sends bogus trim values (CC 04/24 of the same deck)
                        // while the Color FX knob of that deck is in one of its end zones
                        // (crosstalk in the device); mapped to the gain they mute the
                        // channel. Trim messages are dropped while the Color FX knob is in
                        // an end zone. A burst can start with the bogus trim before the
                        // Color FX message tells where the knob is: then the gain goes
                        // back to its value from before that burst. The trim knob itself
                        // keeps working everywhere else.
                        using Clock = std::chrono::steady_clock;
                        static Clock::time_point lastPass[2];
                        static bool inZone[2] = {false, false};
                        static double gainBeforeBurst[2] = {1.0, 1.0};
                        static const ConfigKey kPregain[2] = {
                                ConfigKey(QStringLiteral("[Channel1]"), QStringLiteral("pregain")),
                                ConfigKey(QStringLiteral("[Channel2]"), QStringLiteral("pregain"))};
                        const auto now = Clock::now();
                        const bool cfx1 = status == 0xB6 && (data1 == 0x17 || data1 == 0x37);
                        const bool cfx2 = status == 0xB6 && (data1 == 0x18 || data1 == 0x38);
                        if (cfx1 || cfx2) {
                            const int deck = cfx1 ? 0 : 1;
                            // The MSB tells the position (0..127); the LSB only refines it.
                            if (data1 == 0x17 || data1 == 0x18) {
                                const bool zone = data2 <= 22 || data2 >= 108;
                                if (zone && !inZone[deck] &&
                                        now - lastPass[deck] < std::chrono::milliseconds(150)) {
                                    ControlObject::set(kPregain[deck], gainBeforeBurst[deck]);
                                }
                                inZone[deck] = zone;
                            }
                        } else if ((status == 0xB0 || status == 0xB1) &&
                                (data1 == 0x04 || data1 == 0x24)) {
                            const int deck = status == 0xB0 ? 0 : 1;
                            if (inZone[deck]) {
                                return;
                            }
                            if (now - lastPass[deck] > std::chrono::milliseconds(150)) {
                                gainBeforeBurst[deck] = ControlObject::get(kPregain[deck]);
                            }
                            lastPass[deck] = now;
                        }
                    }
                    receivedShortMessage(status, data1, data2, timestamp);
                },
                [this, timestamp](const QByteArray& sysex) {
                    receive(sysex, timestamp);
                });
    }
    return received;
}

void AndroidMidiController::sendShortMsg(
        unsigned char status, unsigned char byte1, unsigned char byte2) {
    if (!m_pWritePort) {
        return;
    }

    const int length = AndroidMidiParser::messageLength(status);
    const uint8_t bytes[3] = {status, byte1, byte2};
    const ssize_t sent = AMidiInputPort_send(m_pWritePort, bytes, static_cast<size_t>(length));
    if (sent == length) {
        qCDebug(m_logOutput) << QStringLiteral("outgoing: ")
                             << MidiUtils::formatMidiOpCode(getName(),
                                        status,
                                        byte1,
                                        byte2,
                                        MidiUtils::channelFromStatus(status),
                                        MidiUtils::opCodeFromStatus(status));
    } else {
        qCWarning(m_logOutput) << "Error sending short message" << status << byte1
                               << byte2 << "result" << sent;
    }
}

bool AndroidMidiController::sendBytes(const QByteArray& data) {
    if (!data.endsWith(MidiUtils::opCodeValue(MidiOpCode::EndOfExclusive))) {
        qCDebug(m_logOutput) << "SysEx message does not end with 0xF7 -- ignoring.";
        return false;
    }
    if (!m_pWritePort) {
        return false;
    }

    const ssize_t sent = AMidiInputPort_send(m_pWritePort,
            reinterpret_cast<const uint8_t*>(data.constData()),
            static_cast<size_t>(data.size()));
    if (sent == data.size()) {
        qCDebug(m_logOutput) << QStringLiteral("outgoing: ")
                             << MidiUtils::formatSysexMessage(getName(), data);
        return true;
    }
    qCWarning(m_logOutput) << "Error sending SysEx message:"
                           << MidiUtils::formatSysexMessage(getName(), data)
                           << "result" << sent;
    return false;
}
