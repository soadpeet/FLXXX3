#pragma once

#include <QJniObject>
#include <QList>

#include "controllers/midi/midienumerator.h"

/// Discovers USB MIDI controllers through android.media.midi (via
/// de.biggo.flxxx3.MidiHelper) and exposes them as AndroidMidiController.
class AndroidMidiEnumerator : public MidiEnumerator {
    Q_OBJECT
  public:
    AndroidMidiEnumerator();
    ~AndroidMidiEnumerator() override;

    QList<Controller*> queryDevices() override;

    /// Quick look at the MIDI devices that Android lists right now (one line per
    /// device); used to notice plugging and unplugging of the controller.
    QString deviceListing();

  private:
    void deleteDevices();

    QJniObject m_helper;
    QList<Controller*> m_devices;
};
