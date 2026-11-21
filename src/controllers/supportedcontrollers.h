#pragma once

// FLXXX3: the controllers the app is made for. They are set up automatically
// (mapping, sound routing, own USB audio driver on Android); there is no
// controller preferences page. AI disclaimer: written autonomously by an AI
// agent (Claude).
//
// To add a controller: one line in kSupportedControllers, its mapping in
// res/controllers and its USB ids in packaging/android/res/xml/usb_device_filter.xml.

#include <QString>
#include <QStringList>
#include <array>
#include <iterator>
#include <cstdint>

namespace flxxx3 {

struct SupportedController {
    // Part of every name the system gives it: MIDI port, sound device, USB
    // product. Unique: no name contains the name of another controller.
    const char* name;
    // Mapping in res/controllers.
    const char* mappingFile;
    std::uint16_t usbVendorId;
    std::uint16_t usbProductId;
    // Sample rate of its sound card (the only one it runs with).
    int sampleRate;
    // Vendor control requests (bmRequestType 0x40, bRequest 3: wValue, wIndex)
    // the maker's driver sends before the audio starts; 0 = none.
    const std::uint16_t (*pAudioUnlock)[2];
    int audioUnlockCount;
    // Android: the system opens its sound card briefly before the own USB audio
    // driver takes over. USB Audio Class 2 devices (DDJ-FLX10) get their clock
    // from the system's driver this way: the own driver cannot set it without
    // shutting down the device's MIDI port.
    bool startClockViaSystem;
    // Android: the device clocks its output from its input stream (implicit
    // feedback, like the Pioneer mixers in the Linux sound driver): the own USB
    // audio driver runs the input stream and sends as many frames as come in.
    bool implicitFeedback;
    // Android: the jog screens are driven over the device's HID interface (DDJ-FLX10):
    // the own USB audio driver sends the reports the mapping script builds.
    bool hidScreen;
};

// DDJ-FLX10: the seven requests of the Pioneer driver, without them the jog
// displays show "no audio driver" and its clock gives no sample rate (captured
// on Windows by Victor Pineda, github.com/Veezuhz/Mixxx_FLX10_Controller_Mapping).
inline constexpr std::uint16_t kFlx10AudioUnlock[][2] = {
        {0x0100, 0xC028},
        {0x0000, 0xC029},
        {0x0200, 0xC013},
        {0x0000, 0xC02B},
        {0x0100, 0xC026},
        {0x0000, 0xC01D},
        {0x0100, 0xC027},
};

inline constexpr std::array<SupportedController, 2> kSupportedControllers = {{
        {"DDJ-FLX4",
                "Pioneer-DDJ-FLX4.midi.xml",
                0x2B73,
                0x0045,
                48000,
                nullptr,
                0,
                false,
                false,
                false},
        {"DDJ-FLX10",
                "Pioneer-DDJ-FLX10.midi.xml",
                0x2B73,
                0x0041,
                44100,
                kFlx10AudioUnlock,
                static_cast<int>(std::size(kFlx10AudioUnlock)),
                true,
                true,
                true},
}};

/// The supported controller whose name is part of `systemName` (MIDI port, sound
/// device or USB product name), or nullptr.
inline const SupportedController* findSupportedController(const QString& systemName) {
    for (const auto& controller : kSupportedControllers) {
        if (systemName.contains(QLatin1String(controller.name), Qt::CaseInsensitive)) {
            return &controller;
        }
    }
    return nullptr;
}

inline const SupportedController* findSupportedController(
        std::uint16_t vendorId, std::uint16_t productId) {
    for (const auto& controller : kSupportedControllers) {
        if (controller.usbVendorId == vendorId && controller.usbProductId == productId) {
            return &controller;
        }
    }
    return nullptr;
}

/// The first supported controller among `systemNames`, or nullptr.
inline const SupportedController* findSupportedController(const QStringList& systemNames) {
    for (const QString& name : systemNames) {
        if (const auto* pController = findSupportedController(name)) {
            return pController;
        }
    }
    return nullptr;
}

} // namespace flxxx3
