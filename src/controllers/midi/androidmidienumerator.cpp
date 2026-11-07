#include "controllers/midi/androidmidienumerator.h"

#include <android/log.h>

#include <QCoreApplication>
#include <QJniEnvironment>
#include <QStringList>
#include <QThread>

#include "controllers/midi/androidmidicontroller.h"
#include "moc_androidmidienumerator.cpp"

namespace {
constexpr const char* kLogTag = "mixxx-midi";
// android.media.midi.MidiDeviceInfo.TYPE_USB
constexpr int kMidiDeviceTypeUsb = 1;
// Android's MIDI service lists a freshly attached USB controller up to a few
// seconds after the USB and audio services know it. If USB devices are attached
// but no MIDI device is listed yet, wait a little before giving up.
constexpr int kMidiWaitStepMs = 500;
constexpr int kMidiWaitMaxSteps = 12; // 6 seconds
} // namespace

AndroidMidiEnumerator::AndroidMidiEnumerator() {
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    m_helper = QJniObject("org/mixxx/MidiHelper", "(Landroid/content/Context;)V", context.object());
    QJniEnvironment().checkAndClearExceptions();
    if (!m_helper.isValid()) {
        qWarning() << "AndroidMidiEnumerator: could not create org.mixxx.MidiHelper";
        __android_log_print(ANDROID_LOG_WARN, kLogTag, "MidiHelper not available");
    }
}

AndroidMidiEnumerator::~AndroidMidiEnumerator() {
    qDebug() << "Deleting Android MIDI devices...";
    deleteDevices();
}

void AndroidMidiEnumerator::deleteDevices() {
    qDeleteAll(m_devices);
    m_devices.clear();
}

QList<Controller*> AndroidMidiEnumerator::queryDevices() {
    deleteDevices();
    if (!m_helper.isValid()) {
        return m_devices;
    }

    QString listing;
    for (int attempt = 0;; ++attempt) {
        listing = m_helper.callObjectMethod("listDevices", "()Ljava/lang/String;").toString();
        QJniEnvironment().checkAndClearExceptions();
        const bool hasUsbMidi = listing.contains('\n') && !listing.isEmpty();
        if (hasUsbMidi || attempt >= kMidiWaitMaxSteps) {
            break;
        }
        const jint usbCount = m_helper.callMethod<jint>("usbDeviceCount", "()I");
        QJniEnvironment().checkAndClearExceptions();
        if (usbCount <= 0) {
            break; // nothing attached, nothing to wait for
        }
        __android_log_print(ANDROID_LOG_INFO,
                kLogTag,
                "no MIDI device yet, %d USB device(s) attached, waiting (%d/%d)",
                static_cast<int>(usbCount),
                attempt + 1,
                kMidiWaitMaxSteps);
        QThread::msleep(kMidiWaitStepMs);
    }
    const QStringList lines = listing.split('\n', Qt::SkipEmptyParts);
    for (const QString& line : lines) {
        // id, type, inputPorts, outputPorts, manufacturer, product, name, serial, vid, pid
        const QStringList fields = line.split('\t');
        if (fields.size() < 10) {
            continue;
        }
        AndroidMidiController::DeviceDescription description;
        description.deviceId = fields[0].toInt();
        const int type = fields[1].toInt();
        description.deviceInputPorts = fields[2].toInt();
        description.deviceOutputPorts = fields[3].toInt();
        description.manufacturer = fields[4];
        description.product = fields[5];
        description.name = fields[6];
        description.serial = fields[7];
        const int vendorId = fields[8].toInt();
        const int productId = fields[9].toInt();
        if (vendorId >= 0) {
            description.vendorId = static_cast<uint16_t>(vendorId);
        }
        if (productId >= 0) {
            description.productId = static_cast<uint16_t>(productId);
        }

        __android_log_print(ANDROID_LOG_INFO,
                kLogTag,
                "device id=%d type=%d in=%d out=%d product='%s' name='%s'",
                description.deviceId,
                type,
                description.deviceInputPorts,
                description.deviceOutputPorts,
                description.product.toUtf8().constData(),
                description.name.toUtf8().constData());

        // Only USB controllers: virtual (app/system) and Bluetooth MIDI
        // devices are not DJ controllers we handle here.
        if (type != kMidiDeviceTypeUsb) {
            continue;
        }
        if (description.deviceInputPorts == 0 && description.deviceOutputPorts == 0) {
            continue;
        }
        m_devices.push_back(new AndroidMidiController(description, m_helper));
    }
    return m_devices;
}
