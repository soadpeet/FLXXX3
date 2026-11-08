<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# TOUCH_UI_PLAN – Touch-Oberfläche nach dem Vorbild von NauticMixxx / XDJ-RX3

**Stand:** 2026-11-06, Branch `android-midi`. **UI-1 umgesetzt (siehe `PROGRESS.md`, Etappe 9c), Entscheidungen des Inhabers: eine einzige Ansicht wie der RX3, ersetzt die alte Oberfläche, Englisch, Browse über den FLX4-Regler (Drücken öffnet/schließt die Liste).** Der Rest dieses Dokuments ist der ursprüngliche Plan. Vorlage laut Inhaber: NauticMixxx (Commit `c73631bafbc7150587cf9de0c32437531d295103`, geklont 2026-11-05).

## 1. Was NauticMixxx macht (gelesen, nicht gebaut)
- [DOKU] `README.md`, `docs/RX3-WORKFLOW-2.0-EN.md`, `docs/INFO-USB-2.0-EN.md`, `docs/UTILITY-2.0-EN.md`, Bilder `branding/readme/{performance,utility,shortcut}-2.0.png`: Das Display ist **Anzeige für den Hardware-Controller** (Encoder/Jog am Gerät), Touch und Maus bleiben möglich. Ansichten:
  - **PERFORMANCE:** Oben Zeit-/Statusleiste (REMAIN, Uhr, INFO). Links je Deck eine Karte „DECK 1/2“ mit Quelle (USB), Key, Beats. Mitte Waveforms (leer: Logo). Rechts BEAT FX (CH SELECT, BPM, QUANTIZE), ZOOM/GRID, STATUS/BEAT FX. Je Deck **Hotcue-Zeile A–H**. Unten je Deck ein Fußbereich: Deck-Nummer, Titel, A.HOT CUE / AUTO CUE, REMAIN/TIME mit großer Zeit, TEMPO-%, BPM-Kasten, QUANTIZE-Zustand, „Not Loaded.“.
  - **SOURCE** mit Reitern BROWSE, TAG LIST, PLAYLIST, SEARCH, MENU; **MENU/UTILITY** als Liste Einstellung → Wert (LOAD LOCK, QUANTIZE BEAT VALUE, HOT CUE AUTO LOAD, AUTO CUE LEVEL, PLAY MODE, Memory Cues/Loops je Deck, Mixer …) mit „BACK“-Taste.
  - **INFO:** Titel, Interpret, Album, Dauer, BPM, Key, Rating, Farbe, Genre, Hinzugefügt, Cover, Kommentar; Springen zu Genre/Interpret/Album.
- Technik dort: Qt-Widgets-/XML-Skin `skins/XDJ_RX3_Mixxx` (37 Dateien, 956 KB), **nicht QML** → kein Code übernehmbar, nur Aufbau und Bedienkonzept. Lizenz GPL v3 (Skin stammt von `pioneered-by-ntamas`); Name, Bilder und Branding von NauticMixxx gehören dem Projekt (`TRADEMARKS.md`) → **eigene Gestaltung und eigener Name**.

## 2. Unsere Ausgangslage
- Android startet die Standard-QML-Oberfläche (`res/qml/main.qml` → `MainWindow.qml`), gebaut für Desktop; auf dem S25 (≈780x360 dp im Querformat) fehlen BPM im Deck, Quantize-Anzeige, brauchbare Touch-Bedienung (Router-Seite, Bibliothek öffnet ca. 2 s, Laden nur über langes Drücken).
- Vorhandene QML-Bausteine [CODE]: `Mixxx.WaveformDisplay` (`src/qml/qmlwaveformdisplay.h`), `Mixxx.WaveformOverview`, `Mixxx.ControlProxy`, `Mixxx.PlayerManager`/`QmlPlayerProxy`/`QmlTrackProxy` (Titel, Interpret, BPM, Key …), `Mixxx.Library` mit Quellenliste (inkl. unserer `LibraryRekordboxSource`), `Mixxx.SoundManager`, Deck-Bausteine in `res/qml/Deck/` (`PlayButton`, `CueButton`, `HotcueButton`, `Loop`, `BeatJump`, `Spinny` mit BPM, `TempoColumn` mit Key). `Deck.qml` ist rollenbasiert layoutbar (`info`, `loop`, `beatjump`, `waveformOverview`, `tempo`, `play`, `cue`, `spinny`, `hotcueAndStem`, …).
- Einschränkungen aus Messungen: keine `Qt5Compat.GraphicalEffects`/`DropShadow` pro Zelle, schlanke Delegates, wenige Objekte (siehe `PROGRESS.md`, Etappe 9b: QML-Objekterzeugung dominiert die Last). Kein Qt-Drag-and-Drop auf Touch (Absturz). Bildschirm ≈ 780x360 dp (S25), Tab A11 ≈ 890x530 dp (Annahme aus 1340x800 px, nicht gemessen).

## 3. Zielbild (angelehnt an NauticMixxx, angepasst an Touch und kleines Display)
**Leitidee:** FLX4 = Bedienung, Touchscreen = Anzeige + Browser + Menü. Jede Geste, die das FLX4 schon kann (Play, Cue, Pads, Jog, Fader), bleibt dort; auf dem Touch sind sie zusätzlich antippbar, aber nicht nötig.

| Ansicht | Inhalt (Mixxx-Controls/Typen) | Priorität |
|---|---|---|
| **PERFORMANCE** | Kopfzeile (Uhrzeit, Master-Status, Quellenstatus Stick/Cache, Akku über `Mixxx.Battery`/`QmlBatteryProxy`, INFO/SOURCE-Knöpfe); pro Deck: Titel/Interpret (`QmlTrackProxy`), **BPM** (`bpm`), **Key** (`visual_key`), **Tempo-%** (`rate`, `rateRange`), Master-Tempo (`keylock`), **Quantize** (`quantize`), Sync-/Leader-Zustand (`sync_enabled`, `sync_leader`), große Zeit REMAIN/TIME (`playposition`, `duration`), Play/Cue-Zustand (`play`, `cue_indicator`), **Hotcue-Zeile A–H** (`hotcue_N_status`/`_color`/`_activate`), Loop-Zustand (`loop_enabled`, `beatloop_size`); Waveforms (`WaveformDisplay`) und Übersicht (`WaveformOverview`) | **UI-1** |
| **SOURCE/BROWSE** | Quellenliste (Rekordbox-Playlists, Lokal), große Titelzeilen (Titel, Interpret, BPM, Key, Farbe/Rating), Tippen = auswählen, Knöpfe „→ Deck 1“/„→ Deck 2“ (statt langem Drücken), Suche | **UI-2** |
| **MENU** | Liste Einstellung → Wert (Quantize je Deck, Auto Cue, Hotcue Auto Load, Play Mode, Sync-Verhalten), Status FLX4/Audio-Zuordnung, Cache/Stick-Status, Speicher-/Debug-Info; „BACK“ | **UI-3** |
| **INFO** | Titel-Metadaten wie NauticMixxx; Cover | UI-4 |

Phone-Layout (Querformat, ≈360 dp Höhe, Überschlag): Kopfzeile 24 dp, Übersicht 2×22 dp, Waveforms 2×60 dp, Deck-Fußbereich ≈100 dp, Hotcue-Zeilen 2×22 dp. Tablet: gleiche Struktur, größere Schrift/Waveforms (Größen aus dem Fenster abgeleitet, nicht fest).

## 4. Technischer Ansatz
1. **Neue QML-Oberfläche** unter `res/qml/AndroidDJ/` (Dateien: `MainWindow.qml`, `PerformanceView.qml`, `DeckPanel.qml`, `HotcueRow.qml`, `SourceView.qml`, `MenuView.qml`, …), die vorhandene Mixxx-Typen nutzt. `res/qml/` wird auf Android bereits in die APK kopiert (`copy-resource-android`) und beim Start nach `/sdcard/Mixxx/qml` gespiegelt (`qmlapplication.cpp:66-92`).
2. **Einstieg:** nur Android lädt diese Oberfläche statt der Desktop-Oberfläche (kleine Änderung in `res/qml/main.qml` oder `QmlApplication`), Desktop unverändert; zum Vergleich bleibt die alte per Schalter erreichbar.
3. **Leistung:** keine GraphicalEffects, keine pro-Zelle-Vorschauen, `Loader` für Ansichten, die gerade nicht sichtbar sind; Bibliothek-Liste mit schlanken Delegates (Messung vorher/nachher mit `simpleperf`, siehe `PROGRESS.md`, Etappe 9b).
4. **Bedienung:** Mindestgröße der Touch-Ziele ≈ 48 dp, wo Platz ist; wichtige Gesten ohne Hover (Router-Probleme aus Etappe 6b vermeiden); Back-Taste schließt Ansichten statt die App zu beenden (Qt behandelt sie sonst als „App schließen“).
5. **Abgrenzung:** keine Übernahme von Code, Bildern oder Branding von NauticMixxx; eigene Icons/Farben; Anlehnung an das Bedienkonzept ist zulässig, aber das Lizenz-/Markenthema bleibt Sache des Inhabers (keine Rechtsberatung).

## 5. Etappen und Abnahme (am Gerät)
| Etappe | Ziel | Abnahme (S25, danach Tab A11) | Abbruch/Alternative |
|---|---|---|---|
| UI-1 | PERFORMANCE-Ansicht, zwei Decks | Alle Elemente der Tabelle (BPM, Key, Tempo-%, Quantize, Sync, Zeit, Hotcues, Waveform+Übersicht) sichtbar und folgen FLX4-Bedienung; keine Ruckler beim Spielen | Layout zu eng → Elemente umschichten; Last zu hoch → Waveform vereinfachen |
| UI-2 | SOURCE/BROWSE mit Laden per Tipp | Rekordbox-Playlist öffnen, Titel antippen, „→ Deck“ lädt; Öffnen unter 0,5 s; kein Absturz beim Scrollen | Öffnen weiter zu langsam → Profil mit Aufrufgraph |
| UI-3 | MENU (Quantize, Auto Cue, Status) | Einstellungen schaltbar und wirksam; Status zeigt FLX4/Audio/Stick/Cache | – |
| UI-4 | INFO-Seite | Metadaten/Cover wie NauticMixxx | – |
| Danach | Dauertest 30 min, Galaxy Tab A11 | siehe `IMPLEMENTATION_ROADMAP.md`, Etappe 11 | – |

## 6. Offene Fragen an den Inhaber
1. Reihenfolge: UI-1 zuerst (Anzeige) oder UI-2 zuerst (Laden per Tipp)?
2. Alte Oberfläche per Schalter erhalten oder ersetzen?
3. Soll ich für die Gestaltung Screenshots der Mixxx-Oberfläche machen dürfen (nur wenn Mixxx im Vordergrund ist, kein Privates sichtbar)? Das beschleunigt das Feintuning deutlich.
4. Sprache der Oberfläche: Deutsch oder Englisch (wie Mixxx/NauticMixxx)?

<!-- Ende KI-generierter Text -->
