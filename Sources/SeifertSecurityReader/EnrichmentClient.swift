import Foundation

private struct KEVCatalog: Decodable, Sendable {
    let vulnerabilities: [KEVRecord]
}

private struct KEVRecord: Decodable, Sendable {
    let cveID: String
    let vendorProject: String?
    let product: String?
    let requiredAction: String?
    let knownRansomwareCampaignUse: String?
}

private struct EPSSResponse: Decodable, Sendable {
    let data: [EPSSRecord]
}

private struct EPSSRecord: Decodable, Sendable {
    let cve: String
    let epss: String
    let percentile: String
}

enum EnrichmentClient {
    static func enrich(cves: [String]) async -> [String: VulnerabilityInsight] {
        let normalized = Array(Set(cves.map { $0.uppercased() })).sorted()
        guard !normalized.isEmpty else { return [:] }

        var result = Dictionary(uniqueKeysWithValues: normalized.map { ($0, VulnerabilityInsight(cveID: $0)) })
        if let kev = try? await fetchKEV(matching: Set(normalized)) {
            for (cve, record) in kev {
                result[cve]?.isKnownExploited = true
                result[cve]?.vendor = record.vendorProject
                result[cve]?.product = record.product
                result[cve]?.requiredAction = record.requiredAction
                result[cve]?.ransomwareUse = record.knownRansomwareCampaignUse
            }
        }
        if let epss = try? await fetchEPSS(cves: normalized) {
            for record in epss {
                let cve = record.cve.uppercased()
                result[cve]?.epssScore = Double(record.epss)
                result[cve]?.epssPercentile = Double(record.percentile)
            }
        }
        return result
    }

    private static func fetchKEV(matching cves: Set<String>) async throws -> [String: KEVRecord] {
        let url = URL(string: "https://www.cisa.gov/sites/default/files/feeds/known_exploited_vulnerabilities.json")!
        let data = try await fetch(url)
        let catalog = try JSONDecoder().decode(KEVCatalog.self, from: data)
        return Dictionary(uniqueKeysWithValues: catalog.vulnerabilities.compactMap { record in
            let cve = record.cveID.uppercased()
            return cves.contains(cve) ? (cve, record) : nil
        })
    }

    private static func fetchEPSS(cves: [String]) async throws -> [EPSSRecord] {
        var records: [EPSSRecord] = []
        for start in stride(from: 0, to: cves.count, by: 40) {
            let end = min(start + 40, cves.count)
            var components = URLComponents(string: "https://api.first.org/data/v1/epss")!
            components.queryItems = [URLQueryItem(name: "cve", value: cves[start..<end].joined(separator: ","))]
            guard let url = components.url else { continue }
            let data = try await fetch(url)
            records.append(contentsOf: try JSONDecoder().decode(EPSSResponse.self, from: data).data)
        }
        return records
    }

    private static func fetch(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 25)
        request.setValue("SeifertSecurityReader/1.0 (macOS)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) { throw URLError(.badServerResponse) }
        return data
    }
}
