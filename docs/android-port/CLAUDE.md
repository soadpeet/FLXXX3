<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# CLAUDE.md – MIXXX Android Edition (Projektgedächtnis)

Im Repo-Root liegt bereits `AGENTS.md` → diese Datei liegt hier. Stand: 2026-11-06.

## Ziel und System
Android-App „MIXXX Android Edition“: reiner Player mit eigener Touch-Oberfläche (Vorbild XDJ-RX3 / NauticMixxx), Musik, Beatgrid, BPM, Key, Cues und Waveform aus einem Rekordbox-USB-Export. Zielsystem: Galaxy S25 (SM-S931B, Querformat), später Galaxy Tab A11 (SM-X130, ungeprüft), DDJ-FLX4, USB-C-Hub mit PD, Rekordbox-Stick (exFAT, Hybrid-Export). Dev: Windows 11 + WSL2 + Ubuntu 24.04.

## Entscheidungen des Inhabers
Stems raus; Analyse nur für Nicht-Rekordbox-Titel (bleibt an); **eine einzige Ansicht wie der RX3**, ersetzt die alte Oberfläche; Oberfläche **Englisch**; Rekordbox-Waveform behalten (etwas gröber als analysiert); Quantize wie Rekordbox (Phasenabgleich zum anderen Deck nur bei Sync); Screenshots erlaubt (nur wenn Mixxx im Vordergrund, danach löschen); neue APK nach dem Bauen signieren und per adb installieren (nicht mehr automatisch nach Downloads kopieren, seit 2026-11-06); Rekordbox-Android-App während der Arbeit per adb deaktiviert, am Ende wieder aktiviert (**zuletzt 2026-11-06 aktiviert**).

## Regeln
Commit und Push nur nach ausdrücklicher Bestätigung des Inhabers für genau diesen Commit bzw. Push (lokale Ausnahme in AGENTS.md, seit 2026-11-08); der Agent fragt an sinnvollen Stellen selbst danach; nie PR/Issue durch den Agenten; KI-Text mit Disclaimer; nichts erfinden, Hardware nie „bewiesen“; Labels [CODE]/[DOKU]/[WAHRSCHEINLICH]/[EXPERIMENT]/[NICHT UNTERSTÜTZT]; Quelländerungen und Systemänderungen am Telefon nur mit Freigabe. `pkill -f` nie mit dem Skriptnamen in der eigenen Kommandozeile.

## Stand (Details: `PROGRESS.md`, Änderungsliste: `CHANGES_INVENTORY.md`)
Alles läuft auf dem S25: Build (WSL-Sperre per `uname`-Shim umgangen), Audio (Oboe/AAudio, Main→Kanal 1/2, PFL→3/4 des FLX4 fest beim Start), **eigenes Android-MIDI-Backend** (MidiManager + AMidi, FLX4-Mapping auto-aktiv), Rekordbox-Stick (`/mnt/media_rw/<uuid>`, Titel, Beatgrid, Cues, Sync, **Waveform aus ANLZ**), Track-Cache (Kopie im Hintergrund, Stick ziehen beendet die App nicht mehr), Quantize-Änderung, Stems aus (`-DSTEM=OFF`, `track.h`-Mini-Fix), Touch-Oberfläche UI-1 (`res/qml/AndroidDJ/`, Browse-Overlay über den FLX4-Regler).
Alles **uncommittet** im Branch `android-midi` (Basis `bc49961fd3`), Sicherung: `~/mixxx-android/backup/2026-11-06/` (Patch, neue Dateien, Docs, Schlüssel, Skripte).

## Offen / nächste Schritte
1. UI-Feinschliff: Overlay kürzen (Deck-Köpfe sichtbar), Platzhalter „PreviewDeck“ entfernen, größere Zeilen; Zeit REMAIN/ELAPSED umschaltbar; Statusleiste (FLX4/USB/Cache/Akku); Quantize antippbar; CUE/PLAY-Anzeige.
2. Dauertest 30 min (Last, Wärme, Akku) mit neuer Oberfläche; Galaxy Tab A11 testen.
3. Standard-Musikordner `/sdcard/Music` (1535 Titel) lässt sich nicht entfernen (`removeSource` NotFound); Bibliothek-Öffnen-Pause der alten Oberfläche ist durch die neue Ansicht größtenteils überholt.
4. Lücken: Cache-Fenster vor Kopierende, Analyse-Thread vom Stick, kein MIDI-Hotplug (Start-Wartezeit bis 6 s), Dateisystem-Dirty-Flag nach hartem Ziehen (Schreibschutz-Stick empfohlen).
5. Aufräumen vor Commits: Diagnose (`mixxx-midi`/`mixxx-cache` behalten, Rest entfernt), `profileable` im Manifest vor Release raus, Branches nach Gruppen A–I trennen (`CHANGES_INVENTORY.md`).

## Build- und Test-Ablauf (Kurz)
Quellcode liegt auf `/mnt/x/Dev/FLXXX3` (Windows: `X:\Dev\FLXXX3`), Build-Ordner `~/mixxx-android/build-flxxx3` (ab 2026-11-09). Kurzform: `bash docs/android-port/build-install.sh` (Passwort Standard `android`, `--no-install` nur bauen+signieren). Manuell: `source ~/mixxx-android/env.sh; export PATH=$HOME/mixxx-android/shim:$PATH; cd ~/mixxx-android/build-flxxx3; cmake --build . --target apk -j28` → zipalign + `apksigner` (Keystore `~/mixxx-android/debug.keystore`, Alias `mixxxdebug`) → `adb install -r` (Kopie nach Windows-Downloads nur noch auf Wunsch, seit 2026-11-06) (WLAN-Debugging, Port jeweils vom Nutzer). Telefon muss entsperrt sein, sonst startet die App nicht. QML-`console.*` erscheint nicht im `logcat`.

## Dokumente
`PROJECT_OVERVIEW`, `ANDROID_BUILD_ANALYSIS`, `AUDIO_ARCHITECTURE`, `USB_MIDI_ANALYSIS`, `FLX4_COMPATIBILITY`, `REKORDBOX_USB_ANALYSIS`, `DEPENDENCIES`, `SCOPE_REDUCTION`, `RISKS`, `IMPLEMENTATION_ROADMAP`, `MIDI_BACKEND_PLAN`, `NAUTICMIXXX_ANALYSIS`, `TARGET_DEVICES`, `TOUCH_UI_PLAN`, `CHANGES_INVENTORY`, `PROGRESS` (alle in `docs/android-port/`).
