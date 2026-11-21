#pragma once

// AI disclaimer: this file was written autonomously by an AI agent (Claude).
//
// DDJ-FLX10 jog screens. The mapping script builds the 128 byte HID reports of the
// screens (time, BPM, key, track reports); the app sends them to the screens' HID
// interface (Android: the own USB audio driver, which has the device open; Windows and
// other desktops: hidapi, interface 5). The waveform of the loaded track in the
// Pioneer format (PWV5: 150 entries a second, 16 bit each: low / mid / high 3 bit,
// height 5 bit) is made and uploaded (xx 36 reports) here: the script cannot read it.
// Protocol after the reverse engineering of Victor Pineda (Veezuhz),
// github.com/Veezuhz/Mixxx_FLX10_Controller_Mapping (README-SCREEN.md,
// flx10_screen_daemon.py notes); written for FLXXX3.
//
// The script talks to it with SysEx that the MIDI controller keeps from the MIDI port:
//   F0 7D 46 48 <report, 8 bit> F7          send this report to the screens
//   F0 7D 46 57 <deck> F7                   upload the waveform of the deck's track
//                                           (nothing when it is already uploaded or the
//                                           track is not analysed yet: the script asks
//                                           again every second)
//   F0 7D 46 50 <deck> <e0..e3 7 bit> F7    the playhead is at entry e (xx 36 there)

#include <QByteArray>

namespace flxxx3::jogscreen {

/// True where the app can send reports to the jog screens.
constexpr bool kAvailable =
#if defined(__ANDROID__) || defined(__HID__)
        true;
#else
        false;
#endif

/// Handles a jog screen request of the script; false if `data` is none.
bool handleRequest(const QByteArray& data);

} // namespace flxxx3::jogscreen
