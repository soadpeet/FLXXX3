<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# TARGET_DEVICES – Zielgeräte

**Stand:** 2026-11-05, Mixxx `main` @ `bc49961fd3e5a46cd46588090c652a0d7ec44e18`.

## Galaxy S25 (SM-S931B) – Primärgerät, geprüft
- [EXPERIMENT] Android 17, arm64-v8a, Display 1080x2340 bei 480 dpi (`wm size`/`wm density`) → Querformat ≈ 780x360 dp. Mixxx-APK startet, Audio über Oboe/AAudio, FLX4 als 4-Kanal-USB-Audio – siehe `PROGRESS.md`.

## Galaxy Tab A11 (SM-X130) – Zweitgerät, **nicht geprüft**
Daten nur aus Händler-/Specseiten (Websuche 2026-11-05, nicht offiziell von Samsung bestätigt, Varianten unterscheiden sich):
- [DOKU] 8,7"-Display, 1340x800; SoC MediaTek Helio G99 (2x A76 + 6x A55), GPU Mali-G57 MC2; 4 GB/64 GB oder 8 GB/128 GB; Akku 5100 mAh; USB Type-C **2.0** mit OTG/USB-Host (mobiledokan.com, zenospecs.pages.dev; nur Listing-Angaben). Android-Version widersprüchlich (Android 15 / One UI 7 in Listings, Android-16-Seite bei einem Anbieter) → **nicht bestätigt**.
- [WAHRSCHEINLICH] Gleiche ABI (arm64-v8a) → dieselbe APK sollte installierbar sein, **wenn** das Gerät 64-Bit-Userland hat (nicht verifiziert).
- [WAHRSCHEINLICH] USB 2.0 reicht für das FLX4 (4-Kanal-Audio über Android erwiesen auf dem S25, USB-Paketgrößen entsprechen High-Speed-Audio); Ladeleistung am Hub nur ~15 W max. (Listing) → Akku-/Strombudget im Hub-Betrieb prüfen.
- [WAHRSCHEINLICH] **Deutlich schwächer als S25** (Helio G99, Mali-G57 MC2, ggf. 4 GB RAM). Risiken: GL-Waveform-Rendering (`GLESv2`), Audio-Latenz/Underruns, Thermik, App-Kaltstart, Speicher (Mixxx lief auf dem S25 mit ~790 MB RES). Hardcodiertes CPU-Pinning auf Core 4 in `portaudioenumerator.cpp:52-170` passt nicht zwingend zur Topologie des G99 [CODE + WAHRSCHEINLICH].
- [WAHRSCHEINLICH] Größeres Display 8,7": Touch-UI profitiert (größere Ziele), aber Auflösung/Dichte sind anders → Layout nicht auf S25-Maße festnageln.
- [EXPERIMENT] Testvorschlag, sobald das Tab verfügbar: gleiche APK, Wireless-Debugging koppeln, 1) Start, 2) Audio intern, 3) FLX4 via Hub (`dumpsys audio/midi`), 4) 30 min Last, Temperatur. Vorab klären: `adb shell getprop ro.product.cpu.abilist`, Android-Version, ob ein Hub mit PD das Tab versorgt.
- Hinweis: Auf dem Tablet muss ebenfalls die Rekordbox-App (falls installiert) deaktiviert werden (Absprache gilt bisher nur für das S25).

<!-- Ende KI-generierter Text -->
