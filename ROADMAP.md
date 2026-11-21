<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# ROADMAP – Vom Android-Fork zum eigenständigen Produkt für Android und Windows

**Stand:** 2026-11-11 (Plan), Fortschritt nachgetragen am 2026-11-20 (siehe „Fortschritt“). Jede Phase beginnt erst nach Freigabe des Inhabers. Dauerangaben sind grobe Schätzungen für eine Person mit KI-Unterstützung und Gerätetests durch den Inhaber.

Zugehörige Dokumente: `PROJECT_ASSESSMENT.md` (Ist-Stand), `LICENSE_AUDIT.md` (Lizenzen, Befunde L1–L8), `ARCHITECTURE_PROPOSAL.md` (Zielbild), `CPP_RUST_MIGRATION.md` (Rust), `OPENDJ_ANALYSIS.md` (Anregungen O1–O11).

---

## Fortschritt (Stand 2026-11-20)

| Phase | Stand | Erledigt | Offen |
|---|---|---|---|
| 0 Absichern | weitgehend | Build-Rezept im Repo (`docs/android-port/build/`), Abhängigkeiten für Android 10 selbst gebaut (`build-deps-api29.sh`, eigene Ports `overlay-ports/`), Build-Optionen dokumentiert, Arbeit committet und gepusht (Remote `fork`), Sicherung von `~/mixxx-android/` und des Release-Schlüssels außer Haus (Inhaber, 2026-11-20), Android-Build aus gepacktem Abhängigkeitspaket in leerem Ordner nachgebaut | Probe-Neuaufbau auf anderem Rechner (Inhaber) |
| 1 Recht/Identität | großteils | Eigene App-ID `de.biggo.flxxx3`, Name FLXXX3, eigenes Symbol (Android und Windows), `NOTICE.md`, `LICENSE_AUDIT.md`, minimaler Optionssatz (STEM, BROADCAST, VINYLCONTROL, ENGINEPRIME, LILV, MODPLUG aus), Lizenzansicht in der App (ABOUT), alle Lizenzbefunde gelöst: L1 (FFmpeg-eigener AAC-Decoder statt libfdk-aac), L2 (crate-digger-Lizenz richtiggestellt, genutzt unter LGPL-3.0), L7 (NauticMixxx-Anteile benannt, `THIRD_PARTY.txt`) | Namens- und Markenprüfung (Rechtsberatung) |
| 2 Schichten | weitgehend | CMake-Schalter `FLXXX3` (Produktverhalten), QML `Mixxx.Product.ui`, Plattformschicht `src/platform/`, `Mixxx.DeviceStatus`, Qt5-Kompatibilitätsmodul entfernt, automatische Tests (`tools/run_tests.sh`: FLX4-Mapping, Rekordbox-Import mit Demo-Export und echten Cue-Daten in `tests/flxxx3/data/rekordbox-cues`; `--all`: alle 1228 Mixxx-Tests grün, 4 bewusst übersprungen), `__ANDROID__`-Stellen geprüft (67 → 62, Rest sind Systemzugriffe), Rekordbox-Hot-Loops wie am CDJ, `CMakePresets.json` (Presets `android-api29`, `windows`, `windows-test`: ein Optionssatz für beide Plattformen) | Testdaten mit Memory Loops, Commits thematisch trennen / Korrekturen für Upstream (optional) |
| 3 Windows | fertig | Windows-Build (`tools/windows/`), FLX4 (MIDI, feste Kanäle, WASAPI 22 ms, ASIO falls Treiber, MIDI-Hotplug), Sticks und Ordner mit Rekordbox-Export, zwei Decks gemischt, eigene Einstellungen `%LOCALAPPDATA%\FLXXX3` | WASAPI exklusiv nicht möglich (FLX4 will Kanalmaske 0), Latenz mit ASIO-Treiber messen |
| 4 Beta | begonnen | Releases v0.1.0–v0.1.2, Android-Release-Signatur und Versionierung, APK 62 MB statt 259 MB, Windows-Installer (Inno Setup, `tools/windows/make_installer.sh`), ABOUT-Seite, Log und Absturzprotokoll mit SHARE LOG, CI für Tests ohne App-Build (`.github/workflows/flxxx3-tests.yml`: FLX4-Mapping, XML-Prüfung), CI-Build Windows mit Installer (`flxxx3-windows.yml`) und Android-APK (`flxxx3-android.yml`, Abhängigkeitspaket im Release `deps-android-api29-20261120`), Build ohne WSL-Shim (WSL-Sperre in `CMakeLists.txt` gilt nicht mehr für den Android-Cross-Build), Startprobe der APK in Emulatoren (Android 12, 12L, 14; 11 nur zur Information), Release-Workflow (Tag → Entwurf mit APK, Installer, Prüfsummen; `flxxx3-release.yml`) | Code-Signatur Windows (Zertifikat, Inhaber), Release-Schlüssel als GitHub-Secret (optional, Inhaber), Dauertests und Testprotokoll je Release, Tests auf echten Android-10–13-Geräten (der Emulator deckt Android 10 und 13 nicht ab und keine echten Grafiktreiber), Release v0.1.3 |


### Funktionslücken (Abgleich mit dem Code, 2026-11-20)

Ersetzt die Liste in `docs/android-port/CHANGES_INVENTORY.md` §3 (Stand 2026-11-08).

| Bereich | Stand | Was fehlt |
|---|---|---|
| BROWSE | erledigt | Kategorien TRACK, ARTIST, ALBUM, GENRE, KEY, BPM, STARS, HISTORY, dazu TRACK FILTER, SORT, Buchstabensprung, INFO; PLAYLIST, SEARCH, TAG LIST in der Kopfleiste; FOLDER (Ordner des Sticks bzw. der Tablet-Ordner durchblättern, Suchfilter `infolder:`, 2026-11-20, am Gerät noch zu testen) |
| SOURCE | erledigt | Ordner-Schalter OFF/ACTIVE filtert die Liste pro Ordner |
| Beat FX | erledigt | alle zehn: DELAY, ECHO, PING PONG, SPIRAL, HELIX, REVERB, FLANGER, PHASER, TRANS, FILTER (mit Tempo) |
| Beat FX: Bänder LOW/MID/HI | offen | Weiche bei 250 Hz / 2,5 kHz, 12 dB/Oktave, Bänder ergeben zusammen wieder genau das Original (keiner der zehn Effekte hat eine eigene Laufzeit). Pioneer veröffentlicht für FX FREQUENCY weder Frequenzen noch Steilheit (Handbücher DJM-900NXS2, DJM-750MK2, DJM-V10 geprüft); möglich: steilere Weiche (24 dB/Oktave) nach Gehör oder Messung an einem echten DJM |
| Audio-Einstellungen | teils | MASTER LIMITER (ADVANCED SETTINGS > AUDIO, Standard an, ab -0,3 dBFS, ohne Latenz, `src/engine/enginelimiter.*`, 2026-11-20); MASTER HEADROOM bleibt als feste Absenkung. Offen: USB-Puffer und Samplerate wirken erst nach Neustart (so beschriftet) |
| MIDI-Hotplug | erledigt | Android und Windows (FLX4 ab- und anstecken) |
| Stick ziehen im Betrieb | teils, **Test geplant** | Android: geladene Titel laufen aus dem Cache weiter; offen: Zeitfenster bis die Kopie fertig ist (Ziehen beendet dann die App), Analyse liest evtl. noch vom Stick. Windows: kein Cache, Verhalten unbekannt. Test (mit dem Inhaber, Tablet und Windows): Log zeigt Kopierende und offene Stick-Dateien; ziehen (a) 10 s nach dem Laden, (b) sofort nach dem Laden, (c) bei einem Titel ohne Rekordbox-Analyse, (d) bei offener Bibliothek, dann wieder einstecken; danach Lücken schließen (Laden wartet auf die Kopie bzw. Cache auch unter Windows) |
| Memory Loops | ungeprüft | Import und CUE/LOOP CALL eingebaut, aber nie mit echten Daten getestet (keine auf dem Stick des Inhabers) |
| MASTER wie Pioneer | erledigt (2026-11-21), am Gerät zu testen | Der erste Deck mit Titel wird MASTER, weiteres Laden verschiebt ihn nicht mehr; er wechselt nur, wenn der MASTER nicht spielt (zu einem Deck, das startet, oder beim Stoppen zu einem spielenden), ein ausgeworfener MASTER gibt an ein spielendes bzw. geladenes Deck ab |
| Gespeicherte Loops in der Waveform | erledigt (2026-11-21) | Hot Loops / Memory Loops nur noch als schmaler Farbbalken oben (wie Pioneer), statt halbtransparent über die ganze Höhe; der laufende Loop bleibt orange (`waveformrendermark.cpp`, `#ifdef FLXXX3`) |
| Zoom über FLX4 | ungeprüft | Hänger bei starkem Zoomen: ob er ganz weg ist, ist nicht belegt |
| Windows-Waveform | ungeprüft | die große Waveform (Rekordbox 3-Band) war zeitweise unsichtbar, danach nicht mehr nachstellbar |
| Abstürze bei Testern (v0.1.0) | offen | Freeze auf Snapdragon 865, Absturz auf Xiaomi Pad 5 (beide Adreno 6xx); Logs fehlen. Die Startprobe in den Emulatoren besteht, zeigt aber keine Grafiktreiber-Fehler |
| FLX4 ON/OFF-LED | offen | Werte durch Probieren ermittelt, keine Herstellerangabe |
| DDJ-FLX10 (für v0.1.3) | In Arbeit (2026-11-21): BACK und Kopfhörer am Tablet bestätigt | Erkennung über `src/controllers/supportedcontrollers.h`; Mapping aus Mixxx-PR 16539 (Zim, Veezuhz; GPL), MASTER/HEADPHONES LEVEL dem Gerät überlassen (MASTER HEADROOM bleibt); Ton über den eigenen USB-Treiber: UAC2, High Speed, 44,1 kHz, Freischalt-Befehle, Takt über Android vorab, **impliziter Feedback** (Eingangsstrom läuft mit, Ausgang folgt seiner Paketgröße); BROWSE-Regler: Drücken = LOAD des Decks (öffnet die Bibliothek auch in der XDJ-Ansicht, in SOURCE öffnet es die Quelle), SHIFT + Drücken = SOURCE, SHIFT + Drehen = Liste in 10er-Schritten; BACK schließt das offene Menü (`[AndroidDJ] back`, eine Taste: ein einfaches Control lässt sich nicht per MIDI setzen); Kopfhörer wie rekordbox: MASTER CUE aus = nur die Kanäle mit CUE, MASTER CUE an = MIXING mischt CUE und Master; EQ und TRIM ohne die falsche Option „selectknob“ (sprangen auf Maximum: zu laut); Color FX (6 Tasten) und Beat FX (Wahlschalter, ON/OFF mit Nachklingen, BEAT </>) wie vorgeschlagen eingebaut; MIDI-Mitschrift zum Nachsehen (`adb shell setprop debug.flxxx3.midilog 1`, logcat `mixxx-midi-in`). Offen: (a) beide BROWSE-Regler senden beim Drehen dasselbe (`B6 40`): getrennt zoomen links/rechts nicht möglich, (b) Aussetzer im Log prüfen (Knackser?), (c) FLXXX3-Verhalten des FLX4-Skripts (JOGWHEEL-Menü, Faderkurve, Backspin, Vinyl Start/Stop, Doppel-LOAD, MASTER per BEAT SYNC), (d) Color FX / Beat FX (Vorschlag unten), (e) Jog-Displays nur Zeit/BPM, (f) Windows mit Pioneer-ASIO testen, (g) FLX4 mit dem geänderten Treiber gegenprüfen |
| Vier Decks | erste Fassung (2026-11-21), am Gerät zu testen | UTILITY > DECKS 2 / 4. XDJ-Ansicht: vier Waveforms untereinander (1–4), Deck-Panels 2 × 2 (1 2 / 3 4), Hotcues (60 % hoch) über jedem Deck-Panel, Waveforms niedriger (20 % statt 27 % der Höhe je Paar). CDJ-Ansicht: je Deck ein Viertel (1 oben links, 2 oben rechts, 3 unten links, 4 unten rechts), Teile verkleinert. MASTER, SYNC, QUANTIZE, AUTO CUE, KEY und Zoom kennen vier Decks; FLX10-Mapping liest die Deckzahl beim Start (nach dem Umschalten die App neu starten). Offen: Seitenknöpfe (FILTER/JOGWHEEL…) in der CDJ-Ansicht mit 4 Decks zu klein, Feinschliff der Größen am Tablet, Beat FX CH SELECT 3/4, FLX4 bleibt bei 2 Decks |
| FLX10: Color FX / Beat FX | Vorschlag, mit dem Inhaber abzustimmen | **Color FX:** die sechs Tasten SPACE, DUB ECHO, CRUSH, PITCH, NOISE, FILTER wählen den Color FX der App direkt (`[AndroidDJ] color_fx`) und schalten ihn ein; dieselbe Taste noch einmal schaltet aus (wie am DJM). PITCH gibt es in der App nicht: vorerst SWEEP, später ein eigener PITCH. Der COLOR-Regler jedes Kanals bleibt der Regler des Effekts. Taste leuchtet = gewählt. **Beat FX:** der Wahlschalter (14 Stellungen; laut Veezuhz LOW CUT ECHO, ECHO, MT DELAY, SPIRAL, REVERB, TRANS, ENIGMA JET, FLANGER, PHASER, STRETCH, SLIP ROLL, ROLL, MOBIUS …, am Gerät abzulesen) wählt den Beat FX der App nach Namen: ECHO, SPIRAL, REVERB, TRANS, FLANGER, PHASER direkt, MT DELAY → DELAY, LOW CUT ECHO → ECHO (mit Tiefensperre), ENIGMA JET → FLANGER, MOBIUS → HELIX, STRETCH / SLIP ROLL / ROLL → vorerst ohne Wirkung (später eigene Effekte); PING PONG und FILTER der App bleiben über den Bildschirm wählbar; BEAT </> = Taktlänge, LEVEL/DEPTH, ON/OFF und CH SELECT (1–4, MASTER) wie die Beat-FX-Funktionen des FLX4-Skripts (Nachklingen, Anzeige in der App) |


---

## Leitentscheidungen (vorab vom Inhaber zu bestätigen)

| # | Entscheidung | Empfehlung |
|---|---|---|
| E1 | Lizenzmodell | Eigenständiges **GPL-Produkt** (Quelltext offen); Closed Source wäre eine Neuentwicklung |
| E2 | Technische Basis | **Mixxx-Fork (C++/Qt/QML)** behalten und schichten |
| E3 | Oberfläche | **Qt Quick**, eine Produktoberfläche für beide Plattformen |
| E4 | Rust | **nicht jetzt**; höchstens ein Pilot nach Phase 3 |
| E5 | OpenDJ | Ideenquelle, keine Basis; Neubewertung in etwa sechs Monaten |
| E6 | Produktname und Auftritt | vor Veröffentlichung marken- und designrechtlich prüfen lassen |

---

## Phase 0 – Absichern (≈ 1–2 Wochen)

Ziel: Der funktionierende Android-Stand kann nicht mehr verloren gehen.

- Build-Rezept ins Repo übernehmen: Kopien von `env.sh`, `uname`-Shim, tatsächlicher Konfigurationsaufruf, Versionsliste der Werkzeuge (`PROJECT_ASSESSMENT.md` §6.3).
- Widerspruch der Build-Optionen klären (Doku sagt STEM/BROADCAST/… aus, Cache sagt an).
- Uncommittete Änderungen sichern (Commit/Push jeweils mit Freigabe), SVG-Problem prüfen.
- Sicherung von `~/mixxx-android/` und Keystore außerhalb des Rechners.
- `docs/android-port/CHANGES_INVENTORY.md` um USB-Audio und neue FX-Dateien ergänzen.

**Fertig, wenn:** ein Neuaufbau des Build-Ordners nach Anleitung dieselbe APK-Funktion ergibt (Test durch Inhaber am Gerät).
**Risiko:** gering. Der bestehende Build-Ordner bleibt unberührt; der Probe-Neuaufbau läuft in einem zweiten Ordner.

## Phase 1 – Rechtliche Hygiene und Produktidentität (≈ 2–3 Wochen, teils parallel)

- L1 (fdk-aac) und L2 (EPL-Angabe) klären; L7 (NauticMixxx-Bezug) gegenprüfen.
- Minimalen Optionssatz festlegen (ohne VINYLCONTROL, BROADCAST, ENGINEPRIME, LILV, MODPLUG, STEM) und Wirkung auf APK-Größe und Funktion testen.
- `NOTICE`/Drittlizenzen-Verzeichnis und Lizenzansicht in der App entwerfen; Quelltext-Angebot je Release festlegen.
- Eigene Anwendungs-ID, Name, Symbol, Abgrenzungstext zu Mixxx und AlphaTheta (nach Namensprüfung).
- Fachliche Beratung zu GPL-Pflichten und Marken einholen.

**Fertig, wenn:** eine APK existiert, die mit vollständigen Hinweisen weitergegeben werden dürfte.
**Risiko:** mittel (L1/L2 können Umbauten an Dekodern oder Parser auslösen).

## Phase 2 – Schichten einziehen (≈ 4–8 Wochen)

- Produktverhalten von `__ANDROID__` auf Konfigurationsschalter umstellen (Quantize/Startpunkt, Bibliotheks-Abschaltungen, Waveform-Varianten), in kleinen, einzeln getesteten Schritten.
- Plattformdienste als Schnittstellen herausziehen: Datenträger, Datei-Cache, Systemfunktionen, Audio-Routen (`ARCHITECTURE_PROPOSAL.md` §4).
- Änderungen in thematische Commits/Branches trennen (Gruppen A–O); allgemeine Korrekturen für Upstream vorbereiten (Einreichung durch den Inhaber).
- `CMakePresets.json` für Android.
- Erste automatische Tests auf dem Entwicklungsrechner für Bausteine ohne Hardware (Rekordbox-Import mit Beispieldaten, MIDI-Parser).

**Fertig, wenn:** die Android-App unverändert funktioniert (Gerätetest) und die Zahl der `__ANDROID__`-Stellen außerhalb der Plattformordner deutlich gesunken ist.
**Risiko:** mittel bis hoch für den laufenden Build; deshalb kleine Schritte und Gerätetest nach jedem.

## Phase 3 – Windows-Machbarkeit (≈ 3–6 Wochen)

- Unverändertes Mixxx (gleicher Stand, QML an) unter Windows bauen und starten.
- Produktoberfläche unter Windows laden (Fenster, Maus, Tastatur), Layout-Varianten.
- FLX4 unter Windows: MIDI über PortMidi, Audio 4 Kanäle über WASAPI-Exklusiv und ASIO, Latenz messen.
- Rekordbox-Stick unter Windows (vorhandener Upstream-Zweig `rekordboxfeature.cpp:219`), Waveform-Import, Cache.
- Renderer prüfen (OpenGL/Direct3D über Qt).

**Fertig, wenn:** ein Titel vom Rekordbox-Stick auf zwei Decks mit FLX4 unter Windows gemischt werden kann.
**Entscheidungspunkt:** Trägt die gemeinsame Oberfläche auf dem Desktop? Wenn nein: Layout-Varianten ausbauen, nicht die Technik wechseln.

## Phase 4 – Gemeinsame Beta (≈ 6–10 Wochen)

- Funktionslücken schließen, die beide Plattformen betreffen (aktuelle Liste oben unter „Funktionslücken“; BROWSE-Kategorien, MIDI-Hotplug und Ordnerfilter sind erledigt).
- Windows-Installer und Code-Signatur; Android-Release-Signatur und Versionierung.
- Reproduzierbarer Build ohne WSL-Shim (VM/Container mit echtem Linux-Kernel) und CI für beide Ziele.
- Dauertests (Last, Wärme, Akku, Stick ziehen), Testprotokoll je Release.
- Hilfe-/Über-Seite mit Lizenzen und Quelltext-Verweis.

**Fertig, wenn:** je eine signierte Beta für Android und Windows aus demselben Commit entsteht.

## Phase 5 – Optionaler Rust-Pilot (≈ 4–6 Wochen, nur nach Entscheidung E4)

- Rekordbox-Leser als Bibliothek mit C-Schnittstelle, Erfolgs- und Abbruchkriterien wie in `CPP_RUST_MIGRATION.md` §5.

## Phase 6 – Verstetigung (laufend)

- Auf Mixxx 2.7 stabil umziehen, danach Aktualisierung in festen Abständen.
- Upstream-Beiträge für allgemeine Korrekturen.
- OpenDJ neu bewerten; Anregungen O1–O7 nach Bedarf einplanen.
- Erst hier über größere Themen entscheiden (weitere Controller, Tablet-Layouts, Begleit-App).

---

## Zeitbild (grob)

| Monat | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| Phase 0 | ■ | | | | | | |
| Phase 1 | ■ | ■ | | | | | |
| Phase 2 | | ■ | ■ | | | | |
| Phase 3 | | | ■ | ■ | | | |
| Phase 4 | | | | ■ | ■ | ■ | |
| Phase 5 (optional) | | | | | | ■ | ■ |

Gesamt bis zur gemeinsamen Beta: etwa **5–6 Monate**, mit breiter Unsicherheit (Gerätetests, Lizenzklärung, Windows-Überraschungen).

---

## Größte Risiken über alle Phasen

1. **Verlust oder Bruch der Build-Umgebung** vor Abschluss von Phase 0.
2. **Lizenzbefunde L1/L2** erzwingen technische Änderungen.
3. **Namens-/Markenkonflikt** kurz vor Veröffentlichung (deshalb E6 früh).
4. **Umbau in Phase 2** verschlechtert das Verhalten am Gerät unbemerkt (fehlende automatische Tests).
5. **Upstream-Alpha** ändert Schnittstellen, auf denen die Produktoberfläche aufsetzt.

---

## Was als Nächstes freizugeben wäre

Vorschlag: zuerst nur **Phase 0** freigeben. Sie verändert kein Verhalten der App und ist die Voraussetzung für alles Weitere. Parallel kann der Inhaber die Leitentscheidungen E1–E6 treffen und die Rechtsberatung anstoßen.

<!-- Ende KI-generierter Text -->
