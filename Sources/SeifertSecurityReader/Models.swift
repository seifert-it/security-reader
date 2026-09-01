import Foundation

enum FeedLanguage: String, Codable, CaseIterable, Identifiable, Sendable {
    case german = "DE"
    case english = "EN"

    var id: String { rawValue }
    var label: String { self == .german ? "Deutsch" : "English" }
}

struct FeedSource: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var url: String
    var language: FeedLanguage
    var isEnabled: Bool
    var isDefault: Bool

    static let defaults: [FeedSource] = [
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000001")!, name: "heise Security", url: "https://www.heise.de/security/rss/news-atom.xml", language: .german, isEnabled: true, isDefault: true),
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000002")!, name: "Golem Security", url: "https://rss.golem.de/rss.php?feed=RSS2.0&ms=security", language: .german, isEnabled: true, isDefault: true),
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000003")!, name: "CERT-Bund Warnungen", url: "https://wid.cert-bund.de/content/public/securityAdvisory/rss", language: .german, isEnabled: true, isDefault: true),
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000004")!, name: "CISA Advisories", url: "https://www.cisa.gov/cybersecurity-advisories/all.xml", language: .english, isEnabled: true, isDefault: true),
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000005")!, name: "Krebs on Security", url: "https://krebsonsecurity.com/feed/", language: .english, isEnabled: true, isDefault: true),
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000006")!, name: "BleepingComputer", url: "https://www.bleepingcomputer.com/feed/", language: .english, isEnabled: true, isDefault: true),
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000007")!, name: "The Hacker News", url: "https://feeds.feedburner.com/TheHackersNews", language: .english, isEnabled: true, isDefault: true),
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000008")!, name: "Microsoft Security", url: "https://www.microsoft.com/en-us/security/blog/feed/", language: .english, isEnabled: true, isDefault: true),
        FeedSource(id: UUID(uuidString: "11000000-0000-0000-0000-000000000009")!, name: "Google Security", url: "https://blog.google/security/rss/", language: .english, isEnabled: true, isDefault: true)
    ]
}

struct NewsArticle: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var title: String
    var link: String
    var summary: String
    var publishedAt: Date
    var sourceID: UUID
    var sourceName: String
    var language: FeedLanguage
    var isRead: Bool = false
    var isArchived: Bool = false
    var isFlagged: Bool = false
    var tags: [String] = []
    var collection: String = ""
    var notes: String = ""

    func matches(_ query: String) -> Bool {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return true }

        return [title, summary, sourceName, tags.joined(separator: " "), notes]
            .joined(separator: " ")
            .localizedCaseInsensitiveContains(term)
    }
}

enum SecurityCollection: String, CaseIterable, Identifiable {
    case governance = "Governance, Risiko & Compliance"
    case vulnerabilities = "Schwachstellen & Patches"
    case protection = "Schutz, Identität & Datenschutz"
    case monitoring = "Monitoring & Bedrohungslage"
    case incidents = "Vorfälle & Incident Response"
    case resilience = "Resilienz & Wiederherstellung"
    case awareness = "Wissen & Awareness"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .governance: "building.columns"
        case .vulnerabilities: "wrench.and.screwdriver"
        case .protection: "lock.shield"
        case .monitoring: "waveform.path.ecg"
        case .incidents: "exclamationmark.triangle"
        case .resilience: "arrow.counterclockwise.circle"
        case .awareness: "book.closed"
        }
    }

    var explanation: String {
        switch self {
        case .governance: "Richtlinien, Regulierung, Lieferketten- und Geschäftsrisiken"
        case .vulnerabilities: "CVE, Sicherheitsupdates, Priorisierung und Behebung"
        case .protection: "Prävention, Zugriffsschutz, IAM und Schutz sensibler Daten"
        case .monitoring: "Threat Intelligence, Erkennung, Indicators of Compromise und Lagebilder"
        case .incidents: "Aktive Angriffe, Eindämmung, Analyse und Kommunikation"
        case .resilience: "Backups, Wiederanlauf, Business Continuity und Lessons Learned"
        case .awareness: "Hintergrundwissen, Forschung, Schulung und Sensibilisierung"
        }
    }
}

struct FeedStatus: Identifiable, Sendable {
    var id: UUID { sourceID }
    let sourceID: UUID
    let message: String
    let isError: Bool
}

struct StoredLibrary: Codable {
    var articles: [NewsArticle]
    var sources: [FeedSource]
    var refreshMinutes: Int
    var watchTerms: [String]?
    var notificationsEnabled: Bool?
    var vulnerabilityInsights: [String: VulnerabilityInsight]?
    var lastEnrichment: Date?
}

struct VulnerabilityInsight: Codable, Hashable, Sendable {
    let cveID: String
    var isKnownExploited: Bool = false
    var epssScore: Double?
    var epssPercentile: Double?
    var vendor: String?
    var product: String?
    var requiredAction: String?
    var ransomwareUse: String?
}

struct NewsCluster: Identifiable, Sendable {
    let id: String
    let articles: [NewsArticle]

    var latestPublishedAt: Date { articles.map(\.publishedAt).max() ?? .distantPast }
    var earliestPublishedAt: Date { articles.map(\.publishedAt).min() ?? .distantPast }
    var sourceNames: [String] { Array(Set(articles.map(\.sourceName))).sorted() }
    var cveIDs: [String] { Array(Set(articles.flatMap(\.cveIDs))).sorted() }
    var languages: [FeedLanguage] { Array(Set(articles.map(\.language))).sorted { $0.rawValue < $1.rawValue } }
    var isRead: Bool { articles.allSatisfy(\.isRead) }
    var hasUnread: Bool { articles.contains { !$0.isRead } }
    var isArchived: Bool { articles.allSatisfy(\.isArchived) }
    var hasArchived: Bool { articles.contains { $0.isArchived } }
    var hasUnarchived: Bool { articles.contains { !$0.isArchived } }
    var isFlagged: Bool { articles.contains { $0.isFlagged } }
    var collection: String { articles.first(where: { !$0.collection.isEmpty })?.collection ?? "" }
    var notes: String { articles.first(where: { !$0.notes.isEmpty })?.notes ?? "" }
    var tags: [String] { Array(Set(articles.flatMap(\.tags))).sorted() }
    func matches(_ query: String) -> Bool { articles.contains { $0.matches(query) } }
    var representative: NewsArticle {
        let latest = articles.max(by: { $0.publishedAt < $1.publishedAt })!
        let official = articles
            .filter { sourceRank($0.sourceName) <= 1 && latest.publishedAt.timeIntervalSince($0.publishedAt) < 3 * 24 * 60 * 60 }
            .sorted { left, right in
                let leftRank = sourceRank(left.sourceName)
                let rightRank = sourceRank(right.sourceName)
                return leftRank == rightRank ? left.publishedAt > right.publishedAt : leftRank < rightRank
            }.first
        return official ?? latest
    }

    private func sourceRank(_ name: String) -> Int {
        let value = name.lowercased()
        if value.contains("cisa") || value.contains("cert-bund") { return 0 }
        if value.contains("microsoft security") || value.contains("google security") { return 1 }
        if value.contains("heise") || value.contains("golem") { return 3 }
        return 5
    }
}

enum RelevancePriority: Int, Comparable {
    case relevant = 1
    case urgent = 2

    static func < (lhs: RelevancePriority, rhs: RelevancePriority) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .urgent: return "CISA KEV"
        case .relevant: return "WATCHLIST-TREFFER"
        }
    }
}

enum LibrarySelection: Hashable {
    case relevant
    case inbox
    case unread
    case archived
    case flagged
    case collection(String)
    case source(UUID)
}

enum LanguageFilter: String, CaseIterable, Identifiable {
    case all = "ALLE"
    case german = "DE"
    case english = "EN"
    var id: String { rawValue }
}

extension NewsArticle {
    var cveIDs: [String] {
        let value = title + " " + summary
        guard let expression = try? NSRegularExpression(pattern: #"(?i)\bCVE-\d{4}-\d{4,7}\b"#) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        let matches = expression.matches(in: value, range: range).compactMap { match -> String? in
            guard let range = Range(match.range, in: value) else { return nil }
            return String(value[range]).uppercased()
        }
        return Array(Set(matches)).sorted()
    }

    static func suggestedTags(_ text: String) -> [String] {
        let value = text.lowercased()
        let taxonomy: [(String, [String])] = [
            ("Ransomware", ["ransomware", "erpressungstrojaner"]),
            ("Schwachstelle", ["schwachstelle", "vulnerability", "cve-", "exploit", "zero-day"]),
            ("Malware", ["malware", "trojan", "botnet", "spyware"]),
            ("Phishing", ["phishing", "social engineering"]),
            ("Cloud", ["cloud", "azure", "aws", "microsoft 365", "google cloud"]),
            ("Apple", ["apple", "macos", "ios", "iphone"]),
            ("Datenschutz", ["datenleck", "data leak", "privacy", "datenschutz", "breach"]),
            ("Supply Chain", ["supply chain", "lieferkette"])
        ]
        return taxonomy.compactMap { tag, terms in terms.contains(where: value.contains) ? tag : nil }
    }
}
