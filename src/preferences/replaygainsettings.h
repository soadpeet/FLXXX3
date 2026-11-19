#pragma once

#include "preferences/usersettings.h"
#include "track/replaygain.h"
#include "track/track_decl.h"

class ReplayGainSettings {
  public:
    ReplayGainSettings(UserSettingsPointer pConfig);

    int getInitialReplayGainBoost() const;
    void setInitialReplayGainBoost(int value);
    int getInitialDefaultBoost() const;
    void setInitialDefaultBoost(int value);
    bool getReplayGainEnabled() const;
    void setReplayGainEnabled(bool value);
    bool getReplayGainAnalyzerEnabled() const;
    void setReplayGainAnalyzerEnabled(bool value);
    int getReplayGainAnalyzerVersion() const;
    void setReplayGainAnalyzerVersion(int value);
    bool getReplayGainReanalyze() const;
    void setReplayGainReanalyze(bool value);

    bool isAnalyzerEnabled(int version) const;
    bool isAnalyzerDisabled(int version, TrackPointer tio) const;

    // The gain factor a deck applies for the ReplayGain of its track (0 = no value).
    // FLXXX3 (AUTO GAIN): to -14 LUFS instead of the -18 LUFS of ReplayGain 2.0, but
    // never so loud that the loudest sample would clip.
    static double deckRatio(const mixxx::ReplayGain& replayGain);

  private:
    // Pointer to config object
    UserSettingsPointer m_pConfig;
};
