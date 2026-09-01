import Foundation

enum NewsClusterer {
    private struct WorkingGroup {
        let anchorID: String
        var articles: [NewsArticle]
        var cves: Set<String>
        var fingerprints: [Set<String>]
    }

    static func build(from articles: [NewsArticle]) -> [NewsCluster] {
        var groups: [WorkingGroup] = []
        for article in articles.sorted(by: { $0.publishedAt < $1.publishedAt }) {
            let cves = Set(article.cveIDs)
            let fingerprint = titleFingerprint(article.title)
            let cveMatches = groups.indices.filter { !cves.isEmpty && groups[$0].cves == cves }

            if let first = cveMatches.first {
                groups[first].articles.append(article)
                groups[first].cves.formUnion(cves)
                groups[first].fingerprints.append(fingerprint)
                continue
            }

            var bestIndex: Int?
            var bestScore = 0.0
            for index in groups.indices {
                guard cves.isEmpty, groups[index].cves.isEmpty else { continue }
                guard let newest = groups[index].articles.map(\.publishedAt).max(), abs(article.publishedAt.timeIntervalSince(newest)) < 3 * 24 * 60 * 60 else { continue }
                let score = groups[index].fingerprints.map { similarity(fingerprint, $0) }.max() ?? 0
                let sameSourceOnly = groups[index].articles.allSatisfy { $0.sourceID == article.sourceID }
                let threshold = sameSourceOnly ? 0.82 : 0.52
                if score >= threshold && score > bestScore {
                    bestScore = score
                    bestIndex = index
                }
            }

            if let index = bestIndex {
                groups[index].articles.append(article)
                groups[index].cves.formUnion(cves)
                groups[index].fingerprints.append(fingerprint)
            } else {
                groups.append(WorkingGroup(anchorID: article.id, articles: [article], cves: cves, fingerprints: [fingerprint]))
            }
        }

        return groups.map { group in
            let id = group.cves.isEmpty ? "event:\(group.anchorID)" : "cve:\(group.cves.sorted().joined(separator: "+"))"
            return NewsCluster(id: id, articles: group.articles.sorted { $0.publishedAt > $1.publishedAt })
        }.sorted { $0.latestPublishedAt > $1.latestPublishedAt }
    }

    private static func similarity(_ left: Set<String>, _ right: Set<String>) -> Double {
        guard left.count >= 3, right.count >= 3 else { return 0 }
        let intersection = left.intersection(right).count
        guard intersection >= 2 else { return 0 }
        return Double(intersection) / Double(left.union(right).count)
    }

    private static func titleFingerprint(_ title: String) -> Set<String> {
        let replacements = [
            "schwachstellen": "vuln", "schwachstelle": "vuln", "sicherheitslücke": "vuln", "sicherheitslücken": "vuln",
            "vulnerability": "vuln", "vulnerabilities": "vuln", "critical": "kritisch", "kritische": "kritisch",
            "angriffe": "attack", "angriff": "attack", "attacks": "attack", "attackers": "attacker", "angreifer": "attacker",
            "ermöglicht": "allows", "ermöglichen": "allows", "ausgenutzt": "exploited", "exploitation": "exploited"
        ]
        let stopWords: Set<String> = [
            "der", "die", "das", "den", "dem", "des", "ein", "eine", "einer", "eines", "und", "oder", "mit", "für", "von", "vor", "auf", "aus", "bei", "nach", "über", "durch", "sich", "mehrere", "neue", "new", "the", "and", "for", "from", "with", "into", "this", "that", "security", "update", "updates", "alert", "warnung", "news",
            "cisa", "known", "exploited", "catalog", "adds", "added", "vuln", "one", "two", "three", "four", "five", "six", "multiple"
        ]
        let raw = title.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { $0.count >= 3 }
        return Set(raw.compactMap { token in
            let normalized = replacements[token] ?? token
            return stopWords.contains(normalized) ? nil : normalized
        })
    }
}
