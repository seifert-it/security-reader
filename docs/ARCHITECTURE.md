# Architektur

Der Reader ist eine native SwiftUI-Anwendung für macOS. Er kommt ohne externe Laufzeitbibliotheken und ohne Serverkomponente aus.

## Hauptbereiche

### Datenmodell

`Models.swift` enthält Feed-Quellen, Beiträge, Ereignisgruppen, Sammlungen und CVE-Sachinformationen. Das gespeicherte Format ist `Codable` und wird als JSON im Application-Support-Verzeichnis abgelegt.

### Feed-Abruf

`FeedClient.swift` lädt RSS- und Atom-Dokumente über `URLSession`, verarbeitet XML und normalisiert Titel, Zusammenfassungen und Veröffentlichungszeitpunkte.

### Ereignisbündelung

`NewsClusterer.swift` gruppiert Beiträge anhand gemeinsamer CVE-Kennungen und ähnlicher Titel. Die Originalmeldungen bleiben innerhalb einer Gruppe einzeln zugänglich.

### Zustandsverwaltung

`NewsStore.swift` ist der zentrale, an den Hauptthread gebundene Anwendungszustand. Dort liegen Aktualisierung, Filterung, Archivierung, Watchlist-Abgleich, Persistenz und Benachrichtigungen.

### Externe Sachinformationen

`EnrichmentClient.swift` ergänzt erkannte CVE-Kennungen mit Daten aus dem CISA-KEV-Katalog und der FIRST-EPSS-API. Diese Angaben werden mit ihrer Quelle bezeichnet und nicht als eigene, undurchsichtige Bewertung dargestellt.

### Oberfläche

`ContentView.swift`, `SettingsViews.swift` und `Theme.swift` bilden die SwiftUI-Oberfläche und das Retro-Erscheinungsbild ab.

## Datenfluss

```text
RSS/Atom-Quellen
      │
      ▼
  FeedClient ──► NewsArticle ──► NewsClusterer
                                      │
                                      ▼
                                  NewsStore
                           ┌──────────┼──────────┐
                           ▼          ▼          ▼
                        SwiftUI   library.json  Hinweise
```

## Vertrauensgrenzen

- Feed-Inhalte sind externe, nicht vertrauenswürdige Daten.
- XML-Parser lösen keine externen Entitäten auf.
- Externe Links werden an den Standardbrowser übergeben.
- Eigene Notizen und Bibliotheksdaten verlassen die Anwendung nicht.
- Der öffentliche CISA-KEV-Katalog wird abgerufen; erkannte CVE-Kennungen können zur Ergänzung an FIRST EPSS gesendet werden.
