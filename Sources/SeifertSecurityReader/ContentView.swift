import SwiftUI

struct ContentView: View {
    @ObservedObject var store: NewsStore
    @State private var selection: LibrarySelection? = .inbox
    @State private var selectedClusterID: String?
    @State private var query = ""
    @State private var language: LanguageFilter = .all
    @State private var showSources = false
    @State private var showWatchlist = false

    private var currentSelection: LibrarySelection { selection ?? .inbox }
    private var visibleClusters: [NewsCluster] { store.clusters(for: currentSelection, query: query, language: language) }

    var body: some View {
        NavigationSplitView {
            SidebarView(store: store, selection: $selection)
                .navigationSplitViewColumnWidth(min: 210, ideal: 245, max: 300)
        } content: {
            articleList
                .navigationSplitViewColumnWidth(min: 330, ideal: 410, max: 520)
        } detail: {
            if let cluster = store.cluster(selectedClusterID) {
                ClusterDetailView(store: store, cluster: cluster)
            } else {
                EmptyDetailView(isRefreshing: store.isRefreshing)
            }
        }
        .fontDesign(.monospaced)
        .tint(RetroTheme.teal)
        .background(RetroTheme.paper)
        .toolbar {
            ToolbarItemGroup {
                Button { Task { await store.refresh() } } label: {
                    Label(store.isRefreshing ? "Synchronisiert …" : "Jetzt aktualisieren", systemImage: store.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                }.disabled(store.isRefreshing)
                Button { showWatchlist = true } label: { Label("Meine Umgebung", systemImage: "scope") }
                Button { showSources = true } label: { Label("Quellen", systemImage: "dot.radiowaves.left.and.right") }
            }
        }
        .sheet(isPresented: $showSources) { SourcesView(store: store) }
        .sheet(isPresented: $showWatchlist) { WatchlistView(store: store) }
        .onChange(of: selectedClusterID, initial: true) { _, clusterID in
            if let clusterID { store.markClusterRead(clusterID) }
        }
        .task { await store.refresh() }
        .task(id: store.refreshMinutes) {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(store.refreshMinutes * 60))
                if !Task.isCancelled { await store.refresh() }
            }
        }
    }

    private var articleList: some View {
        VStack(spacing: 0) {
            HStack {
                Text(sectionTitle).font(.system(.headline, design: .monospaced).weight(.black)).foregroundStyle(RetroTheme.ink)
                Spacer()
                if canMarkAllRead && store.unreadCount > 0 {
                    Button { store.markInboxRead() } label: {
                        Label("ALLE ALS GELESEN", systemImage: "checkmark.circle")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                    }
                    .buttonStyle(.borderless)
                    .help("Alle Beiträge im Eingang als gelesen markieren")
                }
                Text("\(visibleClusters.count) EREIGNIS\(visibleClusters.count == 1 ? "" : "SE")").font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundStyle(RetroTheme.teal)
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            Picker("Sprache", selection: $language) {
                ForEach(LanguageFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().padding(.horizontal, 14).padding(.bottom, 10)

            if !visibleClusters.isEmpty {
                HStack(spacing: 10) {
                    Label("LAGEBILD", systemImage: "point.3.connected.trianglepath.dotted").fontWeight(.black)
                    Text("\(kevClusterCount) CISA KEV").foregroundStyle(kevClusterCount > 0 ? RetroTheme.red : .secondary)
                    Text("·")
                    Text("\(visibleSourceCount) Quellen")
                    Spacer()
                    let bundled = visibleClusters.filter { $0.articles.count > 1 }.count
                    if bundled > 0 { Text("\(bundled) gebündelt").foregroundStyle(RetroTheme.teal) }
                }
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RetroTheme.paperDark.opacity(0.75))
            }

            if visibleClusters.isEmpty {
                if currentSelection == .relevant && store.watchTerms.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "scope").font(.system(size: 38)).foregroundStyle(RetroTheme.teal)
                        Text("MEINE UMGEBUNG EINRICHTEN").font(.system(.headline, design: .monospaced).weight(.black)).foregroundStyle(RetroTheme.ink)
                        Text("Wähle eingesetzte Produkte und Plattformen. Passende Meldungen erscheinen danach automatisch hier.")
                            .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 310)
                        Button("TECHNOLOGIEN AUSWÄHLEN") { showWatchlist = true }.buttonStyle(.borderedProminent)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(query.isEmpty ? "Noch keine Signale" : "Kein Treffer", systemImage: query.isEmpty ? "antenna.radiowaves.left.and.right.slash" : "magnifyingglass", description: Text(query.isEmpty ? (currentSelection == .relevant ? "Für deine Watchlist wurden noch keine passenden Beiträge gefunden." : "Aktualisiere die Quellen oder prüfe den Quellenstatus.") : "Versuche einen anderen Suchbegriff."))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                List(visibleClusters, selection: $selectedClusterID) { cluster in
                    ClusterRow(cluster: cluster, watchMatches: store.matchedWatchTerms(in: cluster), priority: store.relevancePriority(for: cluster))
                        .tag(cluster.id)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .contextMenu {
                            Button(cluster.isArchived ? "Ereignis aus Archiv entfernen" : "Ereignis lokal archivieren") { store.toggleClusterArchive(cluster.id) }
                            Button(cluster.isFlagged ? "Markierung entfernen" : "Ereignis wichtig markieren") { store.toggleClusterFlag(cluster.id) }
                        }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(RetroTheme.paper)
        .searchable(text: $query, placement: .toolbar, prompt: "Beiträge, Tags, Notizen")
    }

    private var sectionTitle: String {
        switch currentSelection {
        case .relevant: return "MEINE UMGEBUNG"
        case .inbox: return "SECURITY-FEED"
        case .unread: return "UNGLESEN"
        case .archived: return "LOKALES ARCHIV"
        case .flagged: return "WICHTIG"
        case .collection(let value): return value.uppercased()
        case .source(let id): return store.sources.first(where: { $0.id == id })?.name.uppercased() ?? "QUELLE"
        }
    }

    private var canMarkAllRead: Bool {
        currentSelection == .inbox || currentSelection == .unread
    }

    private var kevClusterCount: Int { visibleClusters.filter { store.relevancePriority(for: $0) == .urgent }.count }
    private var visibleSourceCount: Int { Set(visibleClusters.flatMap(\.sourceNames)).count }
}

private struct SidebarView: View {
    @ObservedObject var store: NewsStore
    @Binding var selection: LibrarySelection?

    var body: some View {
        VStack(spacing: 0) {
            BrandLogo().frame(height: 104).padding(.horizontal, 22).padding(.vertical, 10)
            HStack {
                Circle().fill(store.isRefreshing ? RetroTheme.amber : RetroTheme.mint).frame(width: 8, height: 8)
                Text(store.isRefreshing ? "SCAN LÄUFT" : "SYSTEM BEREIT").font(.system(size: 10, weight: .bold, design: .monospaced))
                Spacer()
            }
            .foregroundStyle(RetroTheme.ink).padding(.horizontal, 16).padding(.bottom, 8)

            List(selection: $selection) {
                Section("BIBLIOTHEK") {
                    SidebarRow(title: "Für meine Umgebung", icon: "scope", count: store.relevantCount).tag(LibrarySelection.relevant)
                    SidebarRow(title: "Eingang", icon: "tray.full", count: store.inboxCount).tag(LibrarySelection.inbox)
                    SidebarRow(title: "Ungelesen", icon: "circlebadge.fill", count: store.unreadCount).tag(LibrarySelection.unread)
                    SidebarRow(title: "Wichtig", icon: "flag.fill", count: store.flaggedCount).tag(LibrarySelection.flagged)
                    SidebarRow(title: "Archiv", icon: "archivebox.fill", count: store.archivedCount).tag(LibrarySelection.archived)
                }
                Section("SAMMLUNGEN") {
                    ForEach(store.collections, id: \.self) { collection in
                        SidebarRow(title: collection, icon: store.collectionIcon(collection), count: store.clusters.filter { $0.articles.contains(where: { $0.collection == collection }) }.count)
                            .tag(LibrarySelection.collection(collection))
                            .help(store.collectionDescription(collection))
                    }
                }
                Section("QUELLEN") {
                    ForEach(store.sources.filter(\.isEnabled)) { source in
                        HStack(spacing: 8) {
                            Circle().fill(store.statuses[source.id]?.isError == true ? RetroTheme.red : RetroTheme.mint).frame(width: 7, height: 7)
                            Text(source.name).lineLimit(1)
                            Spacer()
                            Text(source.language.rawValue).font(.caption2).foregroundStyle(.secondary)
                        }.tag(LibrarySelection.source(source.id))
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(RetroTheme.paperDark)
    }
}

private struct SidebarRow: View {
    let title: String
    let icon: String
    let count: Int
    var body: some View {
        Label {
            HStack { Text(title); Spacer(); if count > 0 { Text("\(count)").font(.caption2).padding(.horizontal, 5).padding(.vertical, 2).background(RetroTheme.ink.opacity(0.12)) } }
        } icon: { Image(systemName: icon).foregroundStyle(RetroTheme.teal) }
    }
}

private struct ClusterRow: View {
    let cluster: NewsCluster
    let watchMatches: [String]
    let priority: RelevancePriority
    private var article: NewsArticle { cluster.representative }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Text(article.language.rawValue).font(.system(size: 9, weight: .black, design: .monospaced)).padding(.horizontal, 5).padding(.vertical, 3).background(RetroTheme.ink).foregroundStyle(RetroTheme.paper)
                Spacer()
                if cluster.articles.count > 1 {
                    Text(cluster.sourceNames.count > 1 ? "\(cluster.sourceNames.count) QUELLEN · \(cluster.articles.count) UPDATES" : "\(cluster.articles.count) UPDATES")
                        .font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(RetroTheme.teal)
                }
                if cluster.hasArchived { Image(systemName: "internaldrive.fill").foregroundStyle(RetroTheme.teal) }
                if cluster.isFlagged { Image(systemName: "flag.fill").foregroundStyle(RetroTheme.amber) }
                if cluster.hasUnread { Circle().fill(RetroTheme.teal).frame(width: 7, height: 7) }
            }
            if !watchMatches.isEmpty {
                HStack(spacing: 6) {
                    Text(priority.label).font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(priorityColor)
                    Text(watchMatches.prefix(2).joined(separator: " · ")).font(.system(size: 9, design: .monospaced)).lineLimit(1).foregroundStyle(.secondary)
                }
            }
            Text(article.title).font(.system(.body, design: .monospaced).weight(cluster.isRead ? .medium : .bold)).foregroundStyle(RetroTheme.ink).lineLimit(3)
            HStack {
                Text(cluster.sourceNames.count > 1 ? "LEITQUELLE: \(article.sourceName.uppercased())" : article.sourceName.uppercased()).lineLimit(1)
                if let cve = cluster.cveIDs.first { Text("· \(cve)").lineLimit(1) }
                Spacer()
                Text(cluster.latestPublishedAt, format: .relative(presentation: .numeric))
            }.font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
        }
        .padding(12).pixelBorder()
    }

    private var priorityColor: Color { priority == .urgent ? RetroTheme.red : RetroTheme.teal }
}

private struct ClusterDetailView: View {
    @ObservedObject var store: NewsStore
    let cluster: NewsCluster

    private var representative: NewsArticle { cluster.representative }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("// LAGEBILD · \(cluster.sourceNames.count) QUELLE\(cluster.sourceNames.count == 1 ? "" : "N") · \(cluster.articles.count) MELDUNG\(cluster.articles.count == 1 ? "" : "EN") · \(cluster.languages.map(\.rawValue).joined(separator: "+"))")
                        .font(.system(.caption, design: .monospaced).weight(.bold)).foregroundStyle(RetroTheme.teal)
                    Spacer()
                    Text(cluster.latestPublishedAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                }
                Text(representative.title).font(.system(size: 28, weight: .black, design: .monospaced)).foregroundStyle(RetroTheme.ink).textSelection(.enabled)

                if cluster.articles.count > 1 {
                    HStack(spacing: 8) {
                        Image(systemName: "point.3.connected.trianglepath.dotted").foregroundStyle(RetroTheme.teal)
                        Text("\(cluster.articles.count) Meldungen aus \(cluster.sourceNames.count) Quelle\(cluster.sourceNames.count == 1 ? "" : "n") wurden zu einem Ereignis gebündelt.")
                        Spacer()
                        Text("LEITQUELLE: \(representative.sourceName.uppercased())").fontWeight(.black)
                    }
                    .font(.system(.caption, design: .monospaced)).padding(10).pixelBorder(active: true)
                }

                if !store.matchedWatchTerms(in: cluster).isEmpty {
                    ClusterEnvironmentRelevanceView(store: store, cluster: cluster)
                }

                HStack(spacing: 10) {
                    Button { store.toggleClusterArchive(cluster.id) } label: {
                        Label(cluster.isArchived ? "EREIGNIS ARCHIVIERT" : "EREIGNIS ARCHIVIEREN", systemImage: cluster.isArchived ? "checkmark.square.fill" : "square.and.arrow.down")
                    }.buttonStyle(.borderedProminent)
                    Button { store.toggleClusterFlag(cluster.id) } label: {
                        Label(cluster.isFlagged ? "WICHTIG" : "MARKIEREN", systemImage: cluster.isFlagged ? "flag.fill" : "flag")
                    }.buttonStyle(.bordered)
                    if let url = URL(string: representative.link) {
                        Link(destination: url) { Label("LEITQUELLE ÖFFNEN", systemImage: "arrow.up.right.square") }.buttonStyle(.bordered)
                    }
                }

                GroupBox("ZUSAMMENFASSUNG DER LEITQUELLE") {
                    Text(representative.summary.isEmpty ? "Die Leitquelle liefert keine Kurzfassung. Die einzelnen Quellen und Updates stehen weiter unten." : representative.summary)
                        .frame(maxWidth: .infinity, alignment: .leading).font(.system(.body, design: .monospaced)).lineSpacing(5).textSelection(.enabled).padding(8)
                }

                GroupBox("QUELLEN & UPDATES · \(cluster.articles.count)") {
                    VStack(spacing: 0) {
                        ForEach(cluster.articles) { article in
                            SourceUpdateRow(article: article, isLead: article.id == representative.id)
                            if article.id != cluster.articles.last?.id { Divider() }
                        }
                    }.padding(6)
                }

                GroupBox("SYSTEMATISIERUNG DES EREIGNISSES") {
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledContent("Sammlung") {
                            Picker("Sammlung", selection: collectionBinding) {
                                Text("Ohne Sammlung").tag("")
                                ForEach(store.collections, id: \.self) { Text($0).tag($0) }
                            }.labelsHidden().frame(width: 230)
                        }
                        LabeledContent("Tags") {
                            TextField("z. B. CVE, Kunde A, Priorität", text: tagsBinding).textFieldStyle(.squareBorder)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("NOTIZEN ZUM EREIGNIS").font(.system(.caption, design: .monospaced).weight(.bold)).foregroundStyle(RetroTheme.teal)
                            TextEditor(text: notesBinding).font(.system(.body, design: .monospaced)).frame(minHeight: 110).scrollContentBackground(.hidden).padding(6).pixelBorder()
                        }
                    }.padding(8)
                }
            }
            .padding(28).frame(maxWidth: 860, alignment: .leading)
        }.background(RetroTheme.paper)
    }

    private var collectionBinding: Binding<String> {
        Binding(get: { store.cluster(cluster.id)?.collection ?? "" }, set: { store.setClusterCollection(cluster.id, value: $0) })
    }
    private var tagsBinding: Binding<String> {
        Binding(get: { store.cluster(cluster.id)?.tags.joined(separator: ", ") ?? "" }, set: { value in
            store.setClusterTags(cluster.id, values: value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        })
    }
    private var notesBinding: Binding<String> {
        Binding(get: { store.cluster(cluster.id)?.notes ?? "" }, set: { store.setClusterNotes(cluster.id, value: $0) })
    }
}

private struct ClusterEnvironmentRelevanceView: View {
    @ObservedObject var store: NewsStore
    let cluster: NewsCluster
    private var matches: [String] { store.matchedWatchTerms(in: cluster) }
    private var priority: RelevancePriority { store.relevancePriority(for: cluster) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("MEINE UMGEBUNG", systemImage: "scope").font(.system(.caption, design: .monospaced).weight(.black))
                Spacer()
                Text(priority.label).font(.system(.caption2, design: .monospaced).weight(.black)).foregroundStyle(priorityColor)
            }
            HStack(spacing: 6) {
                ForEach(matches, id: \.self) { term in
                    Text(term).font(.system(.caption2, design: .monospaced).weight(.bold)).padding(.horizontal, 7).padding(.vertical, 4).background(RetroTheme.mint.opacity(0.26)).overlay(Rectangle().stroke(RetroTheme.teal.opacity(0.5)))
                }
            }
            if cluster.cveIDs.isEmpty {
                Text("Dieses Ereignis passt zu deiner Watchlist. In den gebündelten Feedtexten wurde keine CVE-Nummer gefunden.").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(cluster.cveIDs, id: \.self) { cve in CVEInsightRow(cve: cve, insight: store.insight(for: cve)) }
            }
        }
        .padding(14).background(priorityColor.opacity(0.08)).overlay(Rectangle().stroke(priorityColor, lineWidth: 2))
    }

    private var priorityColor: Color { priority == .urgent ? RetroTheme.red : RetroTheme.teal }
}

private struct SourceUpdateRow: View {
    let article: NewsArticle
    let isLead: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 7) {
                Text(article.sourceName.uppercased()).fontWeight(.black)
                Text(article.language.rawValue).font(.caption2).foregroundStyle(.secondary)
                if isLead { Text("LEITQUELLE").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(RetroTheme.teal) }
                Spacer()
                Text(article.publishedAt.formatted(date: .abbreviated, time: .shortened)).foregroundStyle(.secondary)
                if let url = URL(string: article.link) { Link("ÖFFNEN ↗", destination: url).fontWeight(.bold) }
            }.font(.system(.caption, design: .monospaced))
            Text(article.title).font(.system(.body, design: .monospaced).weight(.bold)).foregroundStyle(RetroTheme.ink).textSelection(.enabled)
            if !article.summary.isEmpty { Text(article.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
        }.padding(.vertical, 10)
    }
}

private struct CVEInsightRow: View {
    let cve: String
    let insight: VulnerabilityInsight?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(cve).font(.system(.caption, design: .monospaced).weight(.black)).textSelection(.enabled)
                if insight?.isKnownExploited == true {
                    Text("AKTIV AUSGENUTZT · CISA KEV").font(.system(size: 9, weight: .black, design: .monospaced)).foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 3).background(RetroTheme.red)
                }
                if let score = insight?.epssScore {
                    Text("EPSS \(score.formatted(.percent.precision(.fractionLength(1))))").font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundStyle(score >= 0.10 ? RetroTheme.amber : RetroTheme.teal)
                        .help("Geschätzte Wahrscheinlichkeit einer Ausnutzung in den nächsten 30 Tagen")
                }
                Spacer()
            }
            if let vendor = insight?.vendor, let product = insight?.product {
                Text("\(vendor) · \(product)").font(.caption).foregroundStyle(.secondary)
            }
            if let action = insight?.requiredAction, insight?.isKnownExploited == true {
                Text("Empfohlene Maßnahme: \(action)").font(.caption).foregroundStyle(RetroTheme.ink)
            } else if insight == nil {
                Text("Risikobewertung wird beim nächsten Abgleich ergänzt.").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(9).background(RetroTheme.paper.opacity(0.65)).overlay(Rectangle().stroke(RetroTheme.ink.opacity(0.16)))
    }
}

private struct EmptyDetailView: View {
    let isRefreshing: Bool
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: isRefreshing ? "dot.radiowaves.left.and.right" : "shield.lefthalf.filled").font(.system(size: 52)).foregroundStyle(RetroTheme.teal)
            Text(isRefreshing ? "SECURITY-SIGNALE WERDEN EINGELESEN" : "BEITRAG AUSWÄHLEN").font(.system(.title2, design: .monospaced).weight(.black)).foregroundStyle(RetroTheme.ink)
            Text("Deutsch + English · lokales Archiv · keine Cloud").font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(RetroTheme.paper)
    }
}
