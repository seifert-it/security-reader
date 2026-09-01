import SwiftUI

struct WatchlistView: View {
    @ObservedObject var store: NewsStore
    @Environment(\.dismiss) private var dismiss
    @State private var customTerm = ""

    private let presetGroups: [(String, [String])] = [
        ("APPLE & CLIENTS", ["macOS", "iOS", "Windows", "Linux"]),
        ("MICROSOFT & CLOUD", ["Microsoft 365", "Exchange", "Azure", "AWS", "Google Cloud"]),
        ("NETZWERK & SECURITY", ["Fortinet", "Cisco", "Sophos", "Palo Alto", "Check Point"]),
        ("SERVER & PLATTFORMEN", ["VMware", "Proxmox", "Docker", "Kubernetes", "WordPress"])
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(width: 760, height: 700)
        .fontDesign(.monospaced)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("MEINE UMGEBUNG")
                    .font(.system(.title2, design: .monospaced).weight(.black))
                    .foregroundStyle(RetroTheme.ink)
                Text("Relevante Meldungen automatisch erkennen und priorisieren")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(store.relevantCount) TREFFER")
                    .font(.system(.caption, design: .monospaced).weight(.black))
                    .foregroundStyle(RetroTheme.teal)
                Text("\(store.watchTerms.count) TECHNOLOGIEN")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Button("Fertig", action: close)
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .background(RetroTheme.paperDark)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1 · EINGESETZTE TECHNOLOGIEN WÄHLEN")
                        .font(.system(.caption, design: .monospaced).weight(.black))
                        .foregroundStyle(RetroTheme.teal)
                    Text("Wähle nur Produkte, die tatsächlich in deiner Umgebung vorkommen. Eine erneute Auswahl entfernt den Eintrag.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(presetGroups, id: \.0) { title, terms in
                    presetGroup(title: title, terms: terms)
                }

                customTermEntry
                activeTerms
                Divider()
                notificationSettings

                Label(
                    "Deine Watchlist bleibt lokal. Für die Ergänzung wird der CISA-KEV-Katalog abgerufen; an FIRST EPSS werden nur erkannte CVE-Nummern übermittelt.",
                    systemImage: "hand.raised.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(12)
                .pixelBorder()
            }
            .padding(22)
        }
        .background(RetroTheme.paper)
    }

    private func presetGroup(title: String, terms: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(.secondary)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(terms, id: \.self) { term in
                    WatchTermButton(term: term, isSelected: contains(term)) {
                        store.toggleWatchTerm(term)
                    }
                }
            }
        }
    }

    private var customTermEntry: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("EIGENES PRODUKT ODER HERSTELLER")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(.secondary)
            HStack {
                TextField("z. B. Synology, Veeam oder Atlassian", text: $customTerm)
                    .textFieldStyle(.squareBorder)
                    .onSubmit(addCustomTerm)
                Button("Hinzufügen", action: addCustomTerm)
                    .disabled(customTerm.trimmingCharacters(in: .whitespacesAndNewlines).count < 2)
            }
        }
    }

    @ViewBuilder
    private var activeTerms: some View {
        if !store.watchTerms.isEmpty {
            VStack(alignment: .leading, spacing: 9) {
                Text("AKTIVE WATCHLIST")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(.secondary)
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 135), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(store.watchTerms, id: \.self) { term in
                        Button { store.removeWatchTerm(term) } label: {
                            HStack {
                                Text(term).lineLimit(1)
                                Spacer()
                                Image(systemName: "xmark")
                            }
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .padding(7)
                        }
                        .buttonStyle(.plain)
                        .pixelBorder(active: true)
                        .help("Aus Watchlist entfernen")
                    }
                }
            }
        }
    }

    private var notificationSettings: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("2 · HINWEISE")
                .font(.system(.caption, design: .monospaced).weight(.black))
                .foregroundStyle(RetroTheme.teal)
            Toggle(isOn: notificationsBinding) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("macOS-Hinweise für neue Treffer").fontWeight(.bold)
                    Text("Benachrichtigt nur bei neuen Beiträgen, die zu deiner Watchlist passen.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var notificationsBinding: Binding<Bool> {
        Binding(
            get: { store.notificationsEnabled },
            set: { enabled in Task { await store.setNotificationsEnabled(enabled) } }
        )
    }

    private func contains(_ term: String) -> Bool {
        store.watchTerms.contains { $0.caseInsensitiveCompare(term) == .orderedSame }
    }

    private func addCustomTerm() {
        store.addWatchTerm(customTerm)
        customTerm = ""
    }

    private func close() {
        Task { await store.enrichRelevantCVEs() }
        dismiss()
    }
}

private struct WatchTermButton: View {
    let term: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                Text(term).lineLimit(1)
                Spacer()
            }
            .font(.system(.caption, design: .monospaced).weight(isSelected ? .bold : .medium))
            .padding(8)
        }
        .buttonStyle(.plain)
        .pixelBorder(active: isSelected)
    }
}

struct SourcesView: View {
    @ObservedObject var store: NewsStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var language: FeedLanguage = .german

    var body: some View {
        VStack(spacing: 0) {
            header
            sourceList
            sourceEditor
        }
        .frame(width: 780, height: 600)
        .background(RetroTheme.paper)
        .fontDesign(.monospaced)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text("QUELLEN-KONTROLLE")
                    .font(.system(.title2, design: .monospaced).weight(.black))
                    .foregroundStyle(RetroTheme.ink)
                Text("Fehlerhafte Quellen blockieren die übrigen Feeds nicht.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Fertig") { dismiss() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(20)
    }

    private var sourceList: some View {
        List(store.sources) { source in
            HStack(spacing: 12) {
                Toggle("", isOn: enabledBinding(for: source))
                    .labelsHidden()
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(source.name).fontWeight(.bold)
                        Text(source.language.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(source.url)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let status = store.statuses[source.id] {
                    Text(status.message)
                        .font(.caption)
                        .foregroundStyle(status.isError ? RetroTheme.red : RetroTheme.teal)
                }
                if !source.isDefault {
                    Button(role: .destructive) { store.removeSource(source.id) } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollContentBackground(.hidden)
        .background(RetroTheme.paper)
    }

    private var sourceEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EIGENE RSS/ATOM-QUELLE")
                .font(.system(.caption, design: .monospaced).weight(.black))
                .foregroundStyle(RetroTheme.teal)
            HStack {
                TextField("Name", text: $name).frame(width: 150)
                TextField("https://…", text: $url)
                Picker("Sprache", selection: $language) {
                    ForEach(FeedLanguage.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(width: 80)
                Button("Hinzufügen", action: addSource)
                    .disabled(url.isEmpty)
            }
            HStack {
                Text("AUTO-REFRESH")
                Picker("Intervall", selection: $store.refreshMinutes) {
                    Text("5 Minuten").tag(5)
                    Text("15 Minuten").tag(15)
                    Text("30 Minuten").tag(30)
                    Text("60 Minuten").tag(60)
                }
                .frame(width: 140)
                Spacer()
                Button("Standardquellen wiederherstellen") {
                    store.restoreDefaultSources()
                }
            }
            .font(.system(.caption, design: .monospaced))
        }
        .padding(20)
        .background(RetroTheme.paperDark)
    }

    private func enabledBinding(for source: FeedSource) -> Binding<Bool> {
        Binding(
            get: { store.sources.first(where: { $0.id == source.id })?.isEnabled ?? false },
            set: { store.setSourceEnabled(source.id, enabled: $0) }
        )
    }

    private func addSource() {
        store.addSource(name: name, url: url, language: language)
        name = ""
        url = ""
    }
}
