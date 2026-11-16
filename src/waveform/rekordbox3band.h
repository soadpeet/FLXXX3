#pragma once

// AI disclaimer: this file was written autonomously by an AI agent (Claude).

#include "waveform/waveform.h"

// Android edition: marks the main waveforms that were built from the 3-band
// detail waveform (PWV7) of Rekordbox. Their low / mid / high values are the real
// band levels (0..255), not shares of the column height, and the renderer draws
// them like Rekordbox does (nested layers). The mark lives in the Waveform itself.
namespace rekordbox3band {
inline void mark(Waveform* pWaveform) {
    pWaveform->setRekordbox3Band(true);
}
inline bool isMarked(const Waveform* pWaveform) {
    return pWaveform->isRekordbox3Band();
}
} // namespace rekordbox3band
