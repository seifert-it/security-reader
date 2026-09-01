import XCTest
@testable import SeifertSecurityReader

final class ReaderTests: XCTestCase {
    func testSearchUsesTitleSummarySourceTagsAndNotes() {
        var article = makeArticle(title: "Sicherheitsupdate", summary: "Ein Update ist verfügbar")
        article.tags = ["Exchange"]
        article.notes = "Für den Monatsbericht"

        XCTAssertTrue(article.matches("sicherheitsupdate"))
        XCTAssertTrue(article.matches("verfügbar"))
        XCTAssertTrue(article.matches("exchange"))
        XCTAssertTrue(article.matches("monatsbericht"))
        XCTAssertFalse(article.matches("fortinet"))
    }

    func testArticlesWithTheSameCVEAreGrouped() {
        let first = makeArticle(
            id: "first",
            title: "CVE-2026-12345 wird aktiv ausgenutzt",
            summary: "Erste Quelle"
        )
        let second = makeArticle(
            id: "second",
            title: "Patch für CVE-2026-12345 verfügbar",
            summary: "Zweite Quelle",
            sourceID: UUID(),
            sourceName: "Zweite Quelle"
        )

        let clusters = NewsClusterer.build(from: [first, second])

        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].articles.count, 2)
        XCTAssertEqual(clusters[0].cveIDs, ["CVE-2026-12345"])
    }

    private func makeArticle(
        id: String = "article",
        title: String,
        summary: String,
        sourceID: UUID = UUID(uuidString: "22000000-0000-0000-0000-000000000001")!,
        sourceName: String = "Testquelle"
    ) -> NewsArticle {
        NewsArticle(
            id: id,
            title: title,
            link: "https://example.com/\(id)",
            summary: summary,
            publishedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceID: sourceID,
            sourceName: sourceName,
            language: .german
        )
    }
}
