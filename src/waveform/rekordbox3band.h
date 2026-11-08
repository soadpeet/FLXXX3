#pragma once

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include <mutex>
#include <unordered_set>

class Waveform;

// Android edition: marks the main waveforms that were built from the 3-band
// detail waveform (PWV7) of Rekordbox. Their low / mid / high values are the real
// band levels (0..255), not shares of the column height, and the renderer draws
// them like Rekordbox does (nested layers).
namespace rekordbox3band {
inline std::mutex& mutex() {
    static std::mutex m;
    return m;
}
inline std::unordered_set<const Waveform*>& set() {
    static std::unordered_set<const Waveform*> s;
    return s;
}
inline void mark(const Waveform* pWaveform) {
    std::lock_guard<std::mutex> lock(mutex());
    if (set().size() > 64) {
        set().clear();
    }
    set().insert(pWaveform);
}
inline bool isMarked(const Waveform* pWaveform) {
    std::lock_guard<std::mutex> lock(mutex());
    return set().count(pWaveform) > 0;
}
} // namespace rekordbox3band
