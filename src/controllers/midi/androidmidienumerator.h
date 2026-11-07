#pragma once

#include <QJniObject>
#include <QList>

#include "controllers/midi/midienumerator.h"

/// Discovers USB MIDI controllers through android.media.midi (via
/// org.mixxx.MidiHelper) and exposes them as AndroidMidiController.
class AndroidMidiEnumerator : public MidiEnumerator {
    Q_OBJECT
  public:
    AndroidMidiEnumerator();
    ~AndroidMidiEnumerator() override;

    QList<Controller*> queryDevices() override;

  private:
    void deleteDevices();

    QJniObject m_helper;
    QList<Controller*> m_devices;
};
