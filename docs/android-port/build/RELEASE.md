<!-- KI-Disclaimer: Dieser Text wurde autonom von einem KI-Agenten (Claude) erzeugt. -->
# Release

## Ablauf über GitHub (seit 2026-11-20)

1. `packaging/android/AndroidManifest.xml`: `versionName` auf die neue Version, `versionCode` um eins erhöhen.
2. Release-Text `packaging/release-notes/v<version>.md` (englisch) schreiben.
3. Beides committen und pushen, dann `git tag v<version>` und `git push fork v<version>`.
4. Der Workflow `.github/workflows/flxxx3-release.yml` prüft Tag und `versionName`, baut die APK (mit Release-Schlüssel, danach Startprobe in Android 11–13) und den Windows-Installer und legt einen **Entwurf** des GitHub-Releases mit `SHA256SUMS.txt` an.
5. Inhaber prüft den Entwurf und veröffentlicht ihn.

Voraussetzung: die Repository-Secrets `FLXXX3_KEYSTORE_B64` (Inhalt von `flxxx3-release.jks`, base64) und `FLXXX3_KEYSTORE_PASS` (Inhalt von `flxxx3-release.pass`), Alias `flxxx3`. Ohne sie bricht der Release-Workflow ab; normale Pushes signieren dann mit einem Schlüssel nur für den Lauf.

Lokal geht es weiter wie bisher (`../build-install.sh`, `tools/windows/make_installer.sh`, Ablage in `Releases/`).

# Release-Konzept (Entwurf vom 2026-11-11, überholt)

Ziel: Von der Debug-signierten Entwicklungs-APK zu nachvollziehbaren Release-Ständen. Hier steht nur das Konzept; am Build hat sich dadurch nichts geändert.

## Ist-Zustand (geprüft 2026-11-11)

- Gradle-Variante `release`, aber unsigniert gebaut (`android-build-release-unsigned.apk`), dann per `zipalign` und `apksigner` mit dem **Debug-Schlüssel** (`debug.keystore`, Alias `mixxxdebug`) signiert (`../build-install.sh`).
- Manifest: `versionCode=1`, `versionName=1.0` fest (`packaging/android/AndroidManifest.xml:5-6`); CMake setzt `QT_ANDROID_VERSION_NAME` aus der Mixxx-Version (`CMakeLists.txt:2398`). Welcher Wert im APK landet, wurde nicht geprüft.
- Keine Release-Schlüsselverwaltung, kein Versionsschema, keine Prüfsummen.

## Vorschlag

| Thema | Vorschlag |
|---|---|
| Versionsschema | `MAJOR.MINOR.PATCH` für FLXXX3, getrennt von der Mixxx-Version; Basisstand von Mixxx im Release-Text nennen |
| `versionCode` | fortlaufende ganze Zahl, nie zurücksetzen |
| Schlüssel | eigener Release-Schlüssel, **außerhalb des Repos** und mit Sicherung; Pfad und Passwort nur per Umgebungsvariable (`KEYSTORE`, `KEYSTORE_PASS`, `KEYSTORE_ALIAS` in `../build-install.sh`) |
| Debug- und Release-Schlüssel | verschieden; Wechsel erfordert Deinstallation der alten App (Signatur) |
| Artefakte | APK plus SHA-256-Datei; Ablage in `Releases/` (in `.gitignore`) |
| Quelltext-Bezug | Release = Git-Tag; die Release-Notiz nennt Tag, Commit, Mixxx-Basis und `NOTICE.md` |
| Entfernen vor Release | `profileable` im Manifest (laut `CLAUDE.md` bereits entfernt, prüfen), Debug-Argumente `--developer --log-level debug` (`CMakeLists.txt:2403`) |
| Paket-ID | erst nach Bestätigung der neuen ID umstellen (ändert die App-Identität) |

## Vor dem ersten öffentlichen Release zu klären

`LICENSE_AUDIT.md` L1 (fdk-aac), L2 (EPL-Angabe), L4 (Lizenzansicht in der App), L5 (Paketname), L6 (Name/Marken).

<!-- Ende KI-generierter Text -->
