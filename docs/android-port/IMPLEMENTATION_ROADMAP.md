<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# IMPLEMENTATION_ROADMAP

**Stand:** `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`, 2026-11-05. Nichts davon ohne ausdrückliche Freigabe.

| Etappe | Ziel | Abnahme (Gerät/Build) | Abbruch/Alternative |
|---|---|---|---|
| 1a | Unveränderten Mixxx als Android-APK bauen (`source tools/android_buildenv.sh setup`, cmake mit CI-Flags, `build.yml:180-197`) | APK entsteht, signiert | Build scheitert (Qt/NDK/Buildenv) → CI-Artefakt der Upstream-Pipeline als Referenz nutzen |
| 1b | Eigener Branch: `-DSTEM=OFF`, Analyse-Defaults aus | APK baut, Stem-Controls fehlen ohne Fehler | FFmpeg-Abhängigkeit macht `STEM=OFF` unmöglich → Stems unsichtbar lassen |
| 2 | Start auf dem S25 (Querformat, Storage-Permission) | UI sichtbar, kein Crash | QML-Startpfad instabil → `--developer`-Gate/Assets-Kopie (`qmlapplication.cpp:66-137`) prüfen |
| 3 | Android-Audio: Ton über Phone | Deck spielt, Underruns zählen | Oboe/Exclusive-Fehler → Parameter lockern |
| 4 | FLX4 per USB-MIDI erkennen | Android-MIDI sieht FLX4; Mixxx-Backend (neu) liest CCs | Backend zu aufwendig → libusb-MIDI-Prototyp |
| 5 | FLX4 als Audiointerface erkennen | `AudioDeviceInfo` mit Kanalzahl | Nur 2 Kanäle → Etappe 6 anpassen |
| 6 | Master/Kopfhörer getrennt | Kanal 1-2 / 3-4 hörbar getrennt | Kein Mehrkanal → Master FLX4, Cue Phone/anderes Gerät |
| 7 | Rekordbox-Stick lesen (Playlists, Grid, Cues; Waveform-Quelle klären) | Stick unter `/storage/<id>`, Track mit Grid+Cues geladen | Zugriff verwehrt → SAF-Konzept; `.DAT`-only-Fix |
| 8 | Zwei Decks mit Audio + getrenntes Vorhören | Beide Decks, Cue getrennt | Latenz/Underruns → Puffer, Last |
| 9 | Touch-Oberfläche (QML) | Bedienbar im Querformat (Jog-Ersatz, Pads, Fader) | Zu aufwendig → LateNightQML anpassen |
| 10 | FLX4 vollständig (LEDs, SysEx, Jog) | Alle Pads/LEDs wie Desktop | LED-Rückkanal fehlt → Funktionsumfang reduzieren |
| 11 | Performance/Stabilität | 60+ min Betrieb, Temperatur, Akku (PD) | Throttling → Rendering/Waveform vereinfachen |

<!-- Ende KI-generierter Text -->
