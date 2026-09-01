# Datenschutz und Netzwerkzugriffe

Stand: 1. September 2026

## Lokale Daten

Der Reader speichert folgende Daten ausschließlich im Benutzerbereich des Macs:

- abgerufene Feed-Einträge und Zusammenfassungen
- Lesestatus und Archivstatus
- Markierungen, Sammlungen, Tags und Notizen
- konfigurierte Quellen
- Technologie-Watchlist und Einstellungen

Die Bibliothek liegt unter:

```text
~/Library/Application Support/SeifertSecurityReader/library.json
```

## Externe Verbindungen

Der Reader verbindet sich mit:

- den vom Benutzer aktivierten RSS- und Atom-Quellen
- dem öffentlichen CISA-KEV-Katalog
- der öffentlichen FIRST-EPSS-API

Der CISA-KEV-Katalog wird vollständig abgerufen; dabei werden keine CVE-Kennungen aus der lokalen Bibliothek an CISA übermittelt. An FIRST EPSS werden ausschließlich CVE-Kennungen übertragen, die bereits in Feed-Texten erkannt wurden. Eigene Notizen, Tags, Sammlungen und Watchlist-Begriffe werden nicht an diese Dienste gesendet.

Die jeweiligen Betreiber können technisch erforderliche Verbindungsdaten wie IP-Adresse, Zeitpunkt und User-Agent verarbeiten. Für deren Verarbeitung gelten die Datenschutzbestimmungen der jeweiligen Anbieter.

## Benachrichtigungen

macOS-Benachrichtigungen sind optional und werden erst nach Zustimmung des Benutzers aktiviert.

## Telemetrie

Der Reader enthält keine eigene Nutzungsanalyse, Werbung oder Benutzerverfolgung.

## Löschen

Zum vollständigen Löschen der lokalen Bibliothek kann die Anwendung beendet und der Ordner `~/Library/Application Support/SeifertSecurityReader/` entfernt werden. Dieser Vorgang kann nicht rückgängig gemacht werden.
