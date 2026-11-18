#pragma once

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <QString>
#include <QStringList>

/// FLXXX3: the services of the operating system that the product needs, behind one interface.
/// The product code (QML, library, status) is the same on every platform; only the
/// implementations differ: platformservices_android.cpp (JNI) and platformservices_desktop.cpp
/// (Windows, Linux).
namespace mixxx::platform {

/// Ids of the removable volumes (USB sticks), sorted. The id is the name of the volume as
/// the Rekordbox device list shows it (Android: the volume uuid, Windows: the drive "E:").
/// Safe to call from a worker thread.
QStringList removableVolumeIds();
/// Path where the files of a removable volume are reachable.
QString removableVolumePath(const QString& id);
/// Name of a removable volume as the system shows it (e.g. "BIGGO 2"), empty if unknown.
QString removableVolumeLabel(const QString& id);
/// Id of the removable volume a file lies on (also when the volume is gone), empty for files
/// on the device's own storage.
QString removableVolumeIdOfPath(const QString& filePath);
/// Path of a file inside its removable volume ("/Contents/x.mp3"), empty if the file is not on
/// a removable volume. The Rekordbox database stores the files this way.
QString removableVolumeRelativePath(const QString& filePath);

/// Root of the device's own storage, where own music folders live (the folder picker starts
/// here), and its name on the SOURCE screen.
QString internalStoragePath();
QString internalStorageName();

/// Copies of stick files in the track cache (Android only; empty elsewhere).
QStringList trackCacheBusyPaths(int recentMs);
int trackCachePendingCopies();

/// Brightness of the app's window: 0 - 1, or negative for the system brightness.
void setScreenBrightness(double value);
/// Keeps the screen on and hides the system bars while the app is in front.
void keepScreenOn();
/// Writes a line to the system log (Android logcat tag mixxx-qml), for debugging QML.
void log(const QString& text);
/// Names of the MIDI inputs the system has right now, also for devices plugged in after
/// the start (PortMidi only knows the list of its start). Windows only; *pSupported is
/// false elsewhere.
QStringList midiInputNames(bool* pSupported);
/// Closes the app.
void quitApp();
/// Gives the log files (in the folder of the log) to the user: Android offers them with the
/// share menu (mail, messenger, cloud), the desktop opens the folder in the file manager.
void shareLogFiles(const QString& logFilePath);

} // namespace mixxx::platform
