# seifert-it Security Reader

Ein lokaler RSS- und Atom-Reader für IT-Security-Nachrichten auf macOS. Der Reader bündelt deutsch- und englischsprachige Quellen, erkennt zusammengehörige Meldungen und unterstützt ein lokales Archiv mit Sammlungen, Tags und Notizen.

Version: **1.0**

## Funktionen

- deutsch- und englischsprachige Security-Feeds
- eigene RSS- und Atom-Quellen
- automatische Aktualisierung
- Eingang, Ungelesen, Wichtig und lokales Archiv
- „Alle als gelesen“ für Eingang und Ungelesen
- Beiträge gelten beim Öffnen automatisch als gelesen
- Volltextsuche über Titel, Feed-Zusammenfassung, Quelle, Tags und Notizen
- Bündelung mehrfach gemeldeter Ereignisse
- frei konfigurierbare Technologie-Watchlist
- sachlich gekennzeichnete Informationen aus CISA KEV und FIRST EPSS
- lokale Sammlungen, Tags und Notizen
- optionale macOS-Benachrichtigungen
- keine Anmeldung und kein Cloud-Konto

## Systemvoraussetzungen

- macOS 14 oder neuer
- die bereitgestellte Version wird für Apple Silicon gebaut
- Internetzugang zum Abruf der Feeds sowie optional für CISA KEV und FIRST EPSS

## Installation

1. Das ZIP-Archiv der gewünschten Version unter **Releases** herunterladen.
2. Archiv entpacken.
3. `seifert-it Security Reader.app` in den Programme-Ordner verschieben.
4. Beim ersten Start die App gegebenenfalls per Rechtsklick und **Öffnen** starten.

Die automatisch erzeugten Builds sind ad-hoc signiert, aber nicht mit einer kostenpflichtigen Apple Developer ID signiert oder von Apple notarisiert. Für eine breit verteilte Veröffentlichung sollte ein eigener signierter und notarisierter Release-Build verwendet werden.

## Lokal entwickeln

Voraussetzung ist eine aktuelle Xcode- beziehungsweise Swift-6-Werkzeugkette.

```bash
swift build
swift test
```

Eine installierbare App wird mit folgendem Skript erzeugt:

```bash
./Scripts/build-app.sh
```

Das Ergebnis liegt anschließend unter `dist/`.

## Auf GitHub veröffentlichen

Eine kurze Anleitung für das erste Repository, den initialen Commit und den Release-Tag steht in [docs/PUBLISHING.md](docs/PUBLISHING.md). Ein Tag wie `v1.0` startet automatisch den Release-Workflow und hängt das erzeugte macOS-Archiv an den GitHub Release an.

## Daten und Netzwerkzugriffe

Archiv, Lesestatus, Watchlist, Tags und Notizen werden im lokalen Benutzerverzeichnis gespeichert. Der Reader ruft die konfigurierten RSS-/Atom-Adressen und den öffentlichen CISA-KEV-Katalog ab. Erkannte CVE-Nummern können für zusätzliche Sachinformationen an FIRST EPSS übermittelt werden. Einzelheiten stehen in [PRIVACY.md](PRIVACY.md).

## Projektstruktur

```text
AppBundle/                         Metadaten und App-Symbole
Scripts/build-app.sh              lokaler Release-Build
Sources/SeifertSecurityReader/    Anwendungscode und Logo
Tests/                            automatisierte Tests
.github/workflows/                GitHub Actions
```

Weitere technische Informationen stehen in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Mitwirken

Fehlerberichte und Verbesserungsvorschläge sind willkommen. Bitte zuerst [CONTRIBUTING.md](CONTRIBUTING.md) lesen. Sicherheitsprobleme sollten entsprechend [SECURITY.md](SECURITY.md) nicht als öffentliches Issue gemeldet werden.

## Lizenz

Für dieses Repository wurde noch keine Open-Source-Lizenz festgelegt. Sichtbarkeit auf GitHub allein gewährt keine Erlaubnis zur Weiterverwendung, Veränderung oder Weiterverteilung des Quellcodes. Vor der öffentlichen Freigabe sollte der Rechteinhaber eine passende Lizenz auswählen.

---

## English summary

seifert-it Security Reader is a local macOS RSS/Atom reader focused on German and English IT-security news. It includes feed management, event grouping, full-text search across locally stored feed data, a local archive, tags, notes, and a configurable technology watchlist. The user interface is currently German.
