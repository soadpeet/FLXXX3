<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# FLXXX3 – Projektidentität

## Was FLXXX3 ist

Ein DJ-Player für Android mit eigener Touch-Oberfläche im Stil eines Standalone-Players (eine Ansicht, zwei Decks), gedacht für den Betrieb mit dem Pioneer DDJ-FLX4 und Rekordbox-USB-Sticks. Langfristiges Ziel: ein eigenständiges Produkt für **Android und Windows** mit möglichst gemeinsamer Codebasis.

Technische Grundlage ist ein Fork von Mixxx (C++, Qt 6, QML). Herkunft und Lizenzen: `NOTICE.md`. Der Name „Mixxx“ bezeichnet das Upstream-Projekt; FLXXX3 ist davon unabhängig.

## Stand der Identität

| Merkmal | Heute | Geplant |
|---|---|---|
| Anwendungsname (sichtbar) | **FLXXX3** (Manifest `android:label`, Startbild) | unverändert; Namens- und Markenprüfung vor Veröffentlichung (`LICENSE_AUDIT.md` L6) |
| Android-Paket-ID | **`de.biggo.flxxx3`** (seit 2026-11-11; vorher `org.mixxx` von Mixxx geerbt) | unverändert. Die Umstellung macht die App für Android zu einer neuen Anwendung: Daten und die USB-Berechtigung beginnen neu, die alte App `org.mixxx` bleibt daneben installiert, bis sie manuell entfernt wird |
| Interner Datenordner/Profil | von Mixxx geerbt (`VersionStore::applicationName`) | bleibt vorerst, damit Profile erhalten bleiben |
| Effekt-IDs `org.mixxx.effects.*` | Mixxx-intern | bleiben (gespeicherte Effektketten) |
| Versionsnummer | Mixxx-Version (2.7-alpha), Manifest `1`/`1.0` | eigenes Schema, siehe `docs/android-port/build/RELEASE.md` |

## Projektstruktur (Überblick)

```
src/                    C++ (Mixxx-Kern + FLXXX3-Ergänzungen)
res/qml/AndroidDJ/      Produktoberfläche (FLXXX3)
packaging/android/      Manifest, Java-Helfer, Icons (FLXXX3)
docs/android-port/      Projektgedächtnis, Analysen, Build-Rezept
docs/android-port/build Build-Rezept zum Nachbauen
NOTICE.md               Herkunft und Lizenzhinweise
LICENSE, COPYING        Lizenztexte (Mixxx, unverändert)
```

Welche Dateien zu Mixxx-Kern, Produktlogik oder Android-Plattform gehören: `docs/android-port/ARCHITECTURE_MAP.md`.

## Dokumente

| Zweck | Datei |
|---|---|
| Ist-Aufnahme | `PROJECT_ASSESSMENT.md` |
| Zielarchitektur | `ARCHITECTURE_PROPOSAL.md` |
| Lizenzprüfung | `LICENSE_AUDIT.md` |
| Rust-Bewertung | `CPP_RUST_MIGRATION.md` |
| Vergleich OpenDJ | `OPENDJ_ANALYSIS.md` |
| Fahrplan | `ROADMAP.md` |
| Build nachbauen | `docs/android-port/build/README.md` |
| Release-Konzept | `docs/android-port/build/RELEASE.md` |
| Änderungsliste, Fortschritt | `docs/android-port/CHANGES_INVENTORY.md`, `PROGRESS.md` |
| Arbeitsregeln | `AGENTS.md`, `docs/android-port/CLAUDE.md` |

## Regeln der Zusammenarbeit (Kurzfassung aus `AGENTS.md`)

Commits und Pushes nur nach Bestätigung des Inhabers; keine Pull Requests oder Issues durch den KI-Agenten; KI-Texte mit Disclaimer am Anfang und Ende.

<!-- Ende KI-generierter Text -->
