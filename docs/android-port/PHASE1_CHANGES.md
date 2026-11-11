<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# PHASE1_CHANGES – Änderungen der Phase 1 (2026-11-11)

Grundlage: `ROADMAP.md` Phase 0/1, Freigabe des Inhabers vom 2026-11-11 für die Schritte 0, 1, 2, 4, 5 und (mit Paket-ID `de.biggo.flxxx3`) 3. Nichts davon ist committet.

## Geänderte und neue Dateien

| Schritt | Datei | Art |
|---|---|---|
| 0 | `docs/android-port/build/{README.md,build-options.md,configure.sh,env.sh.example,uname-shim}` | neu |
| 1 | `NOTICE.md`, `docs/PROJECT.md` | neu |
| 4 | `docs/android-port/build-install.sh` | geändert: Variablen überschreibbar, Standardwerte gleich |
| 4 | `docs/android-port/build/RELEASE.md` | neu (Konzept) |
| 5 | `docs/android-port/ARCHITECTURE_MAP.md` | neu (nur Zuordnung) |
| 3 | `packaging/android/src/org/mixxx/*.java` → `packaging/android/src/de/biggo/flxxx3/*.java` | verschoben (`git mv`), `package`-Zeile und Intent-Actions angepasst |
| 3 | `packaging/android/AndroidManifest.xml` | `package`, Activity-Name |
| 3 | `CMakeLists.txt` | `ANDROID_PACKAGE_NAME`, `QT_ANDROID_PACKAGE_NAME`, ein Kommentar |
| 3 | `src/controllers/android.cpp`, `src/controllers/midi/androidmidi{enumerator.cpp,enumerator.h,controller.h}`, `src/soundio/androidusbaudio.cpp` | JNI-Klassennamen `org/mixxx/…` → `de/biggo/flxxx3/…`, Intent-Action, Meldungstexte |
| 3 | `src/library/rekordbox/rekordboxfeature.cpp:1081`, `src/soundio/soundmanagerconfig.cpp:470` | Pfad der Entwicklerdateien `/sdcard/Android/data/<paket>/files/…` |
| 2 | – | keine Änderung nötig (Mixxx-Logo im Startbild ist auf Android ausgeblendet) |

Bewusst unverändert: `LICENSE`, `COPYING`, Dateikopfzeilen, Effekt-IDs `org.mixxx.effects.*`, Linux-/Flatpak-IDs `org.mixxx.Mixxx*`, Testcode, Daten-/Profilname von Mixxx.

## Auswirkung für den Anwender

Die App mit neuer ID ist für Android eine **andere App**. Bibliothek, Einstellungen, Stick-Cache und die dauerhaft erteilte USB-Berechtigung für den FLX4 müssen neu eingerichtet werden. Die alte App `org.mixxx` bleibt installiert, bis sie manuell deinstalliert wird. Entwicklerdateien (`wf3_order`, `audio_usb_idx`) müssen unter `/sdcard/Android/data/de.biggo.flxxx3/files/` neu angelegt werden.

## Prüfungen

| Prüfung | Ergebnis |
|---|---|
| Build vor Schritt 3 (nur Skript/Doku geändert), `--no-install` | ok, 2 min 18 s, APK bitgleich zur gesicherten |
| Build nach Schritt 3, `--no-install` | ok, Exit 0, 26 min 55 s (Vollbuild, weil sich ein Compilerflag für alle Dateien ändert) |
| `aapt`: Paket / Label / Activity | `de.biggo.flxxx3` / `FLXXX3` / `de.biggo.flxxx3.MainActivity` |
| `apksigner verify` | ok (Debug-Schlüssel) |
| `classes.dex` | enthält `de/biggo/flxxx3/{MainActivity,MidiHelper,UsbAudioHelper,UsbPermission}`, keine `org/mixxx`-Klassen |
| `libmixxx_arm64-v8a.so` | enthält `de/biggo/flxxx3/{MidiHelper,UsbAudioHelper,UsbPermission}` und `de.biggo.flxxx3.permissions.USB_PERMISSION`, keine alten Namen |
| Installation auf Galaxy Tab A11 (SM-X130, Android 16), `adb install -r` | ok; beide Pakete (`de.biggo.flxxx3`, `org.mixxx`) vorhanden |
| Start, 25 s | Activity im Vordergrund, Prozess läuft, keine `FATAL`/`AndroidRuntime`/`ClassNotFound`/`NoSuchMethod`/`JNI DETECTED`-Meldung im Logcat |

## Nicht geprüft

Funktionen am Gerät: MIDI mit dem FLX4, USB-Audio, Rekordbox-Stick, Waveform, Bedienung der Oberfläche; Verhalten bei der USB-Berechtigungsabfrage unter dem neuen Namen; Test auf dem Galaxy S25. Eine Warnung aus Qt-Code (`QtActivityDelegate.initMembers`, „Invalid resource ID“) steht im Logcat; ob sie schon in der alten App vorkam, wurde nicht verglichen. `configure.sh` ist nicht gegen einen frischen Build-Ordner gelaufen.

<!-- Ende KI-generierter Text -->
