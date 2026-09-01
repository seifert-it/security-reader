import Foundation
import SwiftUI
import UserNotifications

@MainActor
final class NewsStore: ObservableObject {
    @Published var articles: [NewsArticle] = []
    @Published private(set) var clusters: [NewsCluster] = []
    @Published var sources: [FeedSource] = FeedSource.defaults
    @Published var statuses: [UUID: FeedStatus] = [:]
    @Published var isRefreshing = false
    @Published var lastUpdated: Date?
    @Published var refreshMinutes = 15
    @Published var watchTerms: [String] = ["macOS"]
    @Published var notificationsEnabled = false
    @Published var vulnerabilityInsights: [String: VulnerabilityInsight] = [:]
    @Published var lastEnrichment: Date?

    let collections = SecurityCollection.allCases.map(\.rawValue)

    func collectionIcon(_ collection: String) -> String {
        SecurityCollection(rawValue: collection)?.systemImage ?? "folder"
    }

    func collectionDescription(_ collection: String) -> String {
        SecurityCollection(rawValue: collection)?.explanation ?? collection
    }

    init() {
        load()
        rebuildClusters()
    }

    var inboxCount: Int { clusters.filter(\.hasUnarchived).count }
    var unreadCount: Int { clusters.filter { $0.hasUnarchived && $0.hasUnread }.count }
    var archivedCount: Int { clusters.filter(\.hasArchived).count }
    var flaggedCount: Int { clusters.filter(\.isFlagged).count }
    var relevantCount: Int { clusters.filter { $0.hasUnarchived && !matchedWatchTerms(in: $0).isEmpty }.count }

    func clusters(for selection: LibrarySelection, query: String, language: LanguageFilter) -> [NewsCluster] {
        clusters.filter { cluster in
            let selectionMatch: Bool
            switch selection {
            case .relevant: selectionMatch = cluster.hasUnarchived && !matchedWatchTerms(in: cluster).isEmpty
            case .inbox: selectionMatch = cluster.hasUnarchived
            case .unread: selectionMatch = cluster.hasUnarchived && cluster.hasUnread
            case .archived: selectionMatch = cluster.hasArchived
            case .flagged: selectionMatch = cluster.isFlagged
            case .collection(let value): selectionMatch = cluster.articles.contains { $0.collection == value }
            case .source(let id): selectionMatch = cluster.articles.contains { $0.sourceID == id && !$0.isArchived }
            }
            let languageMatch = language == .all || cluster.languages.contains(language == .german ? .german : .english)
            return selectionMatch && languageMatch && cluster.matches(query)
        }.sorted {
            if selection == .relevant {
                let left = relevancePriority(for: $0)
                let right = relevancePriority(for: $1)
                if left != right { return left > right }
                let leftEPSS = maximumEPSS(for: $0)
                let rightEPSS = maximumEPSS(for: $1)
                if leftEPSS != rightEPSS { return leftEPSS > rightEPSS }
            }
            return $0.latestPublishedAt > $1.latestPublishedAt
        }
    }

    func cluster(_ id: String?) -> NewsCluster? {
        guard let id else { return nil }
        return clusters.first { $0.id == id }
    }

    func matchedWatchTerms(in article: NewsArticle) -> [String] {
        let haystack = (article.title + " " + article.summary).lowercased()
        return watchTerms.filter { term in
            aliases(for: term).contains { containsToken($0.lowercased(), in: haystack) }
        }
    }

    func matchedWatchTerms(in cluster: NewsCluster) -> [String] {
        Array(Set(cluster.articles.flatMap { matchedWatchTerms(in: $0) })).sorted()
    }

    func relevancePriority(for cluster: NewsCluster) -> RelevancePriority {
        let clusterInsights = cluster.cveIDs.compactMap { vulnerabilityInsights[$0] }
        if clusterInsights.contains(where: \.isKnownExploited) { return .urgent }
        return .relevant
    }

    func maximumEPSS(for cluster: NewsCluster) -> Double {
        cluster.cveIDs.compactMap { vulnerabilityInsights[$0]?.epssScore }.max() ?? 0
    }

    func insight(for cve: String) -> VulnerabilityInsight? { vulnerabilityInsights[cve.uppercased()] }

    func addWatchTerm(_ value: String) {
        let term = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard term.count >= 2, !watchTerms.contains(where: { $0.caseInsensitiveCompare(term) == .orderedSame }) else { return }
        watchTerms.append(term)
        save()
    }

    func removeWatchTerm(_ value: String) {
        watchTerms.removeAll { $0.caseInsensitiveCompare(value) == .orderedSame }
        save()
    }

    func toggleWatchTerm(_ value: String) {
        if watchTerms.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) { removeWatchTerm(value) }
        else { addWatchTerm(value) }
    }

    func setNotificationsEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
            notificationsEnabled = granted
        } else {
            notificationsEnabled = false
        }
        save()
    }

    func markClusterRead(_ id: String) {
        mutateCluster(id) { $0.isRead = true }
    }

    func toggleClusterArchive(_ id: String) {
        guard let cluster = cluster(id) else { return }
        let target = !cluster.isArchived
        mutateCluster(id) { $0.isArchived = target; if target { $0.isRead = true } }
    }

    func toggleClusterFlag(_ id: String) {
        guard let cluster = cluster(id) else { return }
        let target = !cluster.isFlagged
        mutateCluster(id) { $0.isFlagged = target }
    }

    func setClusterCollection(_ id: String, value: String) { mutateCluster(id) { $0.collection = value } }
    func setClusterTags(_ id: String, values: [String]) { mutateCluster(id) { $0.tags = values } }
    func setClusterNotes(_ id: String, value: String) { mutateCluster(id) { $0.notes = value } }

    func markInboxRead() {
        var changed = false
        for index in articles.indices where !articles[index].isArchived && !articles[index].isRead {
            articles[index].isRead = true
            changed = true
        }
        if changed { rebuildClusters(); save() }
    }
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let existingIDs = Set(articles.map(\.id))
        var received: [NewsArticle] = []
        for source in sources where source.isEnabled {
            do {
                let fetched = try await FeedClient.fetch(source)
                received.append(contentsOf: fetched)
                statuses[source.id] = FeedStatus(sourceID: source.id, message: "\(fetched.count) Beiträge", isError: false)
            } catch {
                statuses[source.id] = FeedStatus(sourceID: source.id, message: "Quelle nicht erreichbar", isError: true)
            }
        }
        merge(received)
        await enrichRelevantCVEs()
        let newRelevant = clusters.filter { cluster in
            cluster.hasUnarchived && !matchedWatchTerms(in: cluster).isEmpty && cluster.articles.contains { !existingIDs.contains($0.id) }
        }
        if notificationsEnabled && !newRelevant.isEmpty { sendNotification(for: newRelevant) }
        lastUpdated = Date()
        save()
    }

    func enrichRelevantCVEs(force: Bool = false) async {
        let relevantClusters = clusters.filter { $0.hasUnarchived && !matchedWatchTerms(in: $0).isEmpty }
        let allCVEs = Array(Set(relevantClusters.flatMap(\.cveIDs))).sorted()
        guard !allCVEs.isEmpty else { return }
        let stale = lastEnrichment.map { Date().timeIntervalSince($0) > 6 * 60 * 60 } ?? true
        let unknown = allCVEs.filter { vulnerabilityInsights[$0] == nil }
        guard force || stale || !unknown.isEmpty else { return }
        let requested = Array((force || stale ? allCVEs : unknown).prefix(120))
        let enriched = await EnrichmentClient.enrich(cves: requested)
        vulnerabilityInsights.merge(enriched) { _, new in new }
        lastEnrichment = Date()
        save()
    }

    func addSource(name: String, url: String, language: FeedLanguage) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard URL(string: trimmed)?.scheme?.hasPrefix("http") == true else { return }
        sources.append(FeedSource(id: UUID(), name: name.isEmpty ? URL(string: trimmed)?.host ?? "Eigene Quelle" : name, url: trimmed, language: language, isEnabled: true, isDefault: false))
        save()
    }

    func removeSource(_ id: UUID) {
        sources.removeAll { $0.id == id }
        save()
    }

    func setSourceEnabled(_ id: UUID, enabled: Bool) {
        guard let index = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[index].isEnabled = enabled
        save()
    }

    func restoreDefaultSources() {
        for source in FeedSource.defaults where !sources.contains(where: { $0.url == source.url }) { sources.append(source) }
        save()
    }

    private func merge(_ incoming: [NewsArticle]) {
        var existing = Dictionary(uniqueKeysWithValues: articles.map { ($0.id, $0) })
        for var item in incoming {
            if let saved = existing[item.id] {
                item.isRead = saved.isRead
                item.isArchived = saved.isArchived
                item.isFlagged = saved.isFlagged
                item.tags = saved.tags.isEmpty ? item.tags : saved.tags
                item.collection = saved.collection
                item.notes = saved.notes
            }
            existing[item.id] = item
        }
        let archived = existing.values.filter(\.isArchived)
        let current = existing.values.filter { !$0.isArchived }.sorted { $0.publishedAt > $1.publishedAt }.prefix(700)
        articles = (Array(current) + archived).sorted { $0.publishedAt > $1.publishedAt }
        rebuildClusters()
    }

    private var libraryURL: URL? {
        let manager = FileManager.default
        guard let base = manager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let folder = base.appendingPathComponent("SeifertSecurityReader", isDirectory: true)
        try? manager.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("library.json")
    }

    private func load() {
        guard let url = libraryURL, let data = try? Data(contentsOf: url), let library = try? JSONDecoder().decode(StoredLibrary.self, from: data) else { return }
        let collectionMigration = [
            "Incident Response": "Vorfälle & Incident Response",
            "Kundenrelevant": "Governance, Risiko & Compliance",
            "Patch-Planung": "Schwachstellen & Patches",
            "Recherche": "Wissen & Awareness",
            "Compliance": "Governance, Risiko & Compliance"
        ]
        articles = library.articles.map { stored in
            var migrated = stored
            if let replacement = collectionMigration[stored.collection] { migrated.collection = replacement }
            return migrated
        }
        sources = library.sources.map { stored in
            guard let current = FeedSource.defaults.first(where: { $0.id == stored.id }) else { return stored }
            var migrated = current
            migrated.isEnabled = stored.isEnabled
            return migrated
        }
        for source in FeedSource.defaults where !sources.contains(where: { $0.id == source.id }) { sources.append(source) }
        refreshMinutes = library.refreshMinutes
        watchTerms = library.watchTerms ?? ["macOS"]
        notificationsEnabled = library.notificationsEnabled ?? false
        vulnerabilityInsights = library.vulnerabilityInsights ?? [:]
        lastEnrichment = library.lastEnrichment
    }

    private func save() {
        guard let url = libraryURL else { return }
        let library = StoredLibrary(
            articles: articles,
            sources: sources,
            refreshMinutes: refreshMinutes,
            watchTerms: watchTerms,
            notificationsEnabled: notificationsEnabled,
            vulnerabilityInsights: vulnerabilityInsights,
            lastEnrichment: lastEnrichment
        )
        guard let data = try? JSONEncoder().encode(library) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func aliases(for term: String) -> [String] {
        switch term.lowercased() {
        case "macos": return ["macOS", "Mac OS", "OS X"]
        case "ios": return ["iOS", "iPhone", "iPadOS"]
        case "microsoft 365": return ["Microsoft 365", "Office 365", "M365"]
        case "windows": return ["Windows", "Microsoft Windows"]
        case "exchange": return ["Exchange Server", "Microsoft Exchange"]
        case "fortinet": return ["Fortinet", "FortiGate", "FortiOS"]
        case "vmware": return ["VMware", "vCenter", "ESXi"]
        case "sophos": return ["Sophos", "Sophos Firewall", "Sophos XG"]
        case "cisco": return ["Cisco", "IOS XE", "Cisco ASA"]
        case "linux": return ["Linux", "Ubuntu", "Debian", "Red Hat", "RHEL"]
        case "kubernetes": return ["Kubernetes", "K8s"]
        default: return [term]
        }
    }

    private func containsToken(_ needle: String, in haystack: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: needle)
        guard let expression = try? NSRegularExpression(pattern: "(^|[^a-z0-9])\(escaped)([^a-z0-9]|$)", options: [.caseInsensitive]) else { return haystack.contains(needle) }
        let range = NSRange(haystack.startIndex..., in: haystack)
        return expression.firstMatch(in: haystack, range: range) != nil
    }

    private func sendNotification(for newClusters: [NewsCluster]) {
        let sorted = newClusters.sorted {
            let left = relevancePriority(for: $0)
            let right = relevancePriority(for: $1)
            return left == right ? $0.latestPublishedAt > $1.latestPublishedAt : left > right
        }
        guard let first = sorted.first else { return }
        let content = UNMutableNotificationContent()
        content.title = sorted.count == 1 ? "Neue relevante Security-Meldung" : "\(sorted.count) neue relevante Security-Meldungen"
        let prefix = relevancePriority(for: first) == .urgent ? "CISA KEV: " : ""
        content.body = prefix + first.representative.title
        content.sound = .default
        let request = UNNotificationRequest(identifier: "seifert-it-\(first.id)", content: content, trigger: nil)
        Task { try? await UNUserNotificationCenter.current().add(request) }
    }

    private func mutateCluster(_ id: String, change: (inout NewsArticle) -> Void) {
        guard let cluster = cluster(id) else { return }
        let articleIDs = Set(cluster.articles.map(\.id))
        for index in articles.indices where articleIDs.contains(articles[index].id) { change(&articles[index]) }
        rebuildClusters()
        save()
    }

    private func rebuildClusters() {
        clusters = NewsClusterer.build(from: articles)
    }
}
