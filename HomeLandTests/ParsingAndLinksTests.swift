import XCTest
@testable import HomeLand

final class MoneyParserTests: XCTestCase {
    func testParsesCommonFormats() {
        XCTAssertEqual(MoneyParser.parse("450000"), 450_000)
        XCTAssertEqual(MoneyParser.parse("$450,000"), 450_000)
        XCTAssertEqual(MoneyParser.parse(" 450k "), 450_000)
        XCTAssertEqual(MoneyParser.parse("1.2M"), 1_200_000)
        XCTAssertEqual(MoneyParser.parse("CAD 99,999.50"), 99_999.5)
    }

    func testRejectsNonsense() {
        XCTAssertNil(MoneyParser.parse(""))
        XCTAssertNil(MoneyParser.parse("abc"))
        XCTAssertNil(MoneyParser.parse("-5"))
        XCTAssertNil(MoneyParser.parse("k"))
    }

    func testEditingText() {
        XCTAssertEqual(MoneyParser.editingText(for: nil), "")
        XCTAssertEqual(MoneyParser.editingText(for: 450_000), "450000")
        XCTAssertEqual(MoneyParser.editingText(for: 12.5), "12.5")
    }
}

final class SearchLinksTests: XCTestCase {
    private func queryItems(of url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    func testListingSearchCombinesSiteTermsAndPlaces() {
        let url = SearchLinks.listings(
            site: "realtor.ca/real-estate",
            terms: ["power of sale", "bank sale"],
            region: .hamiltonNiagara,
            pastMonth: true
        )
        let items = queryItems(of: url)
        XCTAssertEqual(url.host, "www.google.com")
        XCTAssertEqual(items["tbs"], "qdr:m")
        let query = items["q"] ?? ""
        XCTAssertTrue(query.hasPrefix("site:realtor.ca/real-estate (\"power of sale\" OR \"bank sale\") (\"Hamilton\" OR "), query)
        XCTAssertTrue(query.contains("\"St. Catharines\""), query)
    }

    func testSingleTermIsNotGrouped() {
        XCTAssertEqual(SearchLinks.anyOf(["power of sale"]), "\"power of sale\"")
        XCTAssertEqual(SearchLinks.anyOf(["  "]), "")
    }

    func testAnywhereAddsNoPlaces() {
        let url = SearchLinks.listings(site: nil, terms: ["vacant land"], region: .anywhere, pastMonth: false)
        let items = queryItems(of: url)
        XCTAssertEqual(items["q"], "\"vacant land\"")
        XCTAssertNil(items["tbs"])
    }
}

final class ListingURLParserTests: XCTestCase {
    func testSuggestsTitleFromAddressSlug() {
        let url = URL(string: "https://www.realtor.ca/real-estate/27512345/123-main-street-hamilton")!
        XCTAssertEqual(ListingURLParser.suggestedTitle(from: url), "123 Main Street Hamilton")
    }

    func testNoTitleWithoutAddressSlug() {
        let url = URL(string: "https://www.kijiji.ca/v-land-for-sale/ottawa/1712345678")!
        XCTAssertNil(ListingURLParser.suggestedTitle(from: url))
    }

    func testNormalizesBareDomains() {
        XCTAssertEqual(
            ListingURLParser.normalizedURL(from: " realtor.ca/real-estate/1 ")?.absoluteString,
            "https://realtor.ca/real-estate/1"
        )
    }

    func testRejectsPlainText() {
        XCTAssertNil(ListingURLParser.normalizedURL(from: "not a link"))
        XCTAssertNil(ListingURLParser.normalizedURL(from: "hello"))
        XCTAssertNil(ListingURLParser.normalizedURL(from: ""))
    }

    func testFindsLinkInSharedText() {
        let url = ListingURLParser.firstURL(in: "Look at this one https://www.realtor.ca/real-estate/1/abc wow")
        XCTAssertEqual(url?.host, "www.realtor.ca")
    }
}
