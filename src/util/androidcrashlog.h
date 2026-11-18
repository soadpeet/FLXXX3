#pragma once

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <QString>

namespace mixxx {
namespace androidcrashlog {

/// Android: users cannot read the app's private storage or logcat. The log file
/// and this crash report go to the app's folder on the shared storage
/// (Android/data/<package>/files/Documents), which every file manager shows.

/// Folder for the log file and the crash report; empty if it cannot be written.
QString logFolder();

/// Writes device, Android version, chip and the time to the log (warning level, so it
/// is always written) and installs the crash handler. On a crash (SIGSEGV, SIGABRT,
/// SIGBUS, SIGILL, SIGFPE) the handler appends the signal and a backtrace (library and
/// offset of every frame, readable with llvm-symbolizer) to crash.txt in the folder,
/// then lets Android handle the crash as before.
void install(const QString& folder);

} // namespace androidcrashlog
} // namespace mixxx
