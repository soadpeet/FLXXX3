<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# ROADMAP – Vom Android-Fork zum eigenständigen Produkt für Android und Windows

**Stand:** 2026-11-11. Vorschlag zur Reihenfolge; **nichts davon ist begonnen.** Jede Phase beginnt erst nach Freigabe des Inhabers. Dauerangaben sind grobe Schätzungen für eine Person mit KI-Unterstützung und Gerätetests durch den Inhaber.

Zugehörige Dokumente: `PROJECT_ASSESSMENT.md` (Ist-Stand), `LICENSE_AUDIT.md` (Lizenzen, Befunde L1–L8), `ARCHITECTURE_PROPOSAL.md` (Zielbild), `CPP_RUST_MIGRATION.md` (Rust), `OPENDJ_ANALYSIS.md` (Anregungen O1–O11).

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

- Funktionslücken schließen, die beide Plattformen betreffen (BROWSE-Kategorien, MIDI-Hotplug, Ordnerfilter; siehe `CHANGES_INVENTORY.md` §3).
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
