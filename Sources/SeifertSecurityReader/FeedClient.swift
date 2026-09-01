import Foundation

private struct ParsedItem: Sendable {
    var title = ""
    var link = ""
    var summary = ""
    var date = ""
    var identifier = ""
}

private final class XMLFeedParser: NSObject, XMLParserDelegate {
    private var items: [ParsedItem] = []
    private var current: ParsedItem?
    private var element = ""
    private var buffer = ""

    func parse(_ data: Data) -> [ParsedItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.shouldResolveExternalEntities = false
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased()
        if name == "item" || name == "entry" { current = ParsedItem() }
        guard current != nil else { return }
        element = name
        buffer = ""
        if name == "link", let href = attributeDict["href"], !href.isEmpty { current?.link = href }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard current != nil else { return }
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard current != nil, let string = String(data: CDATABlock, encoding: .utf8) else { return }
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = elementName.lowercased()
        guard current != nil else { return }
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "title": current?.title += value
        case "link": if current?.link.isEmpty == true { current?.link = value }
        case "description", "summary", "content", "content:encoded": if (current?.summary.count ?? 0) < value.count { current?.summary = value }
        case "pubdate", "published", "updated", "dc:date": if current?.date.isEmpty == true { current?.date = value }
        case "guid", "id": current?.identifier = value
        case "item", "entry":
            if let item = current, !item.title.isEmpty, !item.link.isEmpty { items.append(item) }
            current = nil
        default: break
        }
        buffer = ""
    }
}

enum FeedClient {
    static func fetch(_ source: FeedSource) async throws -> [NewsArticle] {
        guard let url = URL(string: source.url) else { throw URLError(.badURL) }
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 20)
        request.setValue("SeifertSecurityReader/1.0 (macOS RSS Reader)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/atom+xml, application/rss+xml, application/xml, text/xml, */*", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let parsed = XMLFeedParser().parse(data)
        guard !parsed.isEmpty else { throw URLError(.cannotParseResponse) }

        return parsed.prefix(80).map { item in
            let cleanTitle = cleanHTML(item.title)
            let cleanSummary = cleanHTML(item.summary)
            let suggestedTags = NewsArticle.suggestedTags(cleanTitle + " " + cleanSummary)
            let identity = item.identifier.isEmpty ? item.link : item.identifier
            return NewsArticle(
                id: stableID(source.id.uuidString + identity),
                title: cleanTitle,
                link: item.link,
                summary: cleanSummary,
                publishedAt: parseDate(item.date) ?? Date(),
                sourceID: source.id,
                sourceName: source.name,
                language: source.language,
                tags: suggestedTags
            )
        }
    }

    private static func parseDate(_ value: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: value) { return date }
        let formats = [
            "EEE, dd MMM yyyy HH:mm:ss Z", "EEE, d MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm Z", "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss.SSSZ", "yyyy-MM-dd HH:mm:ss"
        ]
        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static func cleanHTML(_ value: String) -> String {
        var result = value.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        let entities = ["&amp;": "&", "&quot;": "\"", "&#39;": "'", "&apos;": "'", "&lt;": "<", "&gt;": ">", "&nbsp;": " "]
        for (entity, replacement) in entities { result = result.replacingOccurrences(of: entity, with: replacement) }
        return result.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func stableID(_ value: String) -> String {
        var hash: UInt64 = 1469598103934665603
        for byte in value.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
        return String(hash, radix: 16)
    }
}
