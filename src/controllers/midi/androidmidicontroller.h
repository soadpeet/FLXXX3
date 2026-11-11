#pragma once

#include <amidi/AMidi.h>

#include <QJniObject>
#include <optional>

#include "controllers/midi/androidmidiparser.h"
#include "controllers/midi/midicontroller.h"

/// MIDI controller on Android, based on android.media.midi (device discovery
/// and opening through de.biggo.flxxx3.MidiHelper) and AMidi (native data transfer,
/// API 29+). Counterpart of PortMidiController.
///
/// Naming follows AMidi: an "output port" of a device delivers data to the app
/// (Mixxx input), an "input port" of a device accepts data from the app
/// (Mixxx output).
class AndroidMidiController : public MidiController {
    Q_OBJECT
  public:
    struct DeviceDescription {
        int deviceId = -1;
        QString name;
        QString manufacturer;
        QString product;
        QString serial;
        std::optional<uint16_t> vendorId;
        std::optional<uint16_t> productId;
        int deviceInputPorts = 0;  // app -> device
        int deviceOutputPorts = 0; // device -> app
    };

    AndroidMidiController(const DeviceDescription& description, const QJniObject& helper);

    /// Number of currently open Android MIDI controllers and the name of the
    /// most recently opened one (for the status bar of the touch UI).
    static int openControllerCount();
    static QString lastOpenedControllerName();
    ~AndroidMidiController() override;

    PhysicalTransportProtocol getPhysicalTransportProtocol() const override {
        return PhysicalTransportProtocol::USB;
    }
    QString getVendorString() const override {
        return m_description.manufacturer;
    }
    QString getProductString() const override {
        return m_description.product;
    }
    std::optional<uint16_t> getVendorId() const override {
        return m_description.vendorId;
    }
    std::optional<uint16_t> getProductId() const override {
        return m_description.productId;
    }
    QString getSerialNumber() const override {
        return m_description.serial;
    }
    std::optional<uint8_t> getUsbInterfaceNumber() const override {
        return std::nullopt;
    }

  private slots:
    bool poll() override;

  protected:
    void sendShortMsg(unsigned char status, unsigned char byte1, unsigned char byte2) override;

  private:
    int open(const QString& resourcePath) override;
    int close() override;

    // The sysex data must already contain the start byte 0xf0 and the end byte
    // 0xf7.
    bool sendBytes(const QByteArray& data) override;

    bool isPolling() const override {
        return true;
    }

    void releasePorts();

    const DeviceDescription m_description;
    QJniObject m_helper;
    QJniObject m_midiDevice;
    AMidiDevice* m_pDevice = nullptr;
    AMidiOutputPort* m_pReadPort = nullptr;  // device -> Mixxx
    AMidiInputPort* m_pWritePort = nullptr;  // Mixxx -> device
    AndroidMidiParser m_parser;
};
