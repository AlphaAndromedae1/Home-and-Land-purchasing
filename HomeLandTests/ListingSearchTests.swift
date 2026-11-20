import XCTest
@testable import HomeLand

final class ListingParserTests: XCTestCase {
    func testPrices() {
        XCTAssertEqual(ListingParser.price(in: "For sale: $599,900 - 3 bed")?.value, 599_900)
        XCTAssertEqual(ListingParser.price(in: "Asking $1.2M for this lot")?.value, 1_200_000)
        XCTAssertEqual(ListingParser.price(in: "Listed at $425000 firm")?.value, 425_000)
        XCTAssertEqual(ListingParser.price(in: "$350,000 mortgage available")?.value, 350_000)
        XCTAssertEqual(ListingParser.price(in: "$500 deposit, price $349,000")?.value, 349_000)
        XCTAssertNil(ListingParser.price(in: "No price here"))

        let rent = ListingParser.price(in: "Rent $2,450/month, utilities extra")
        XCTAssertEqual(rent?.value, 2_450)
        XCTAssertEqual(rent?.isRental, true)
        XCTAssertEqual(ListingParser.price(in: "$2,450/month or buy for $610,000")?.isRental, false)
    }

    func testAddressAndTown() {
        let title = "123 MAIN Street, Hamilton, Ontario L8P1A1 - 12345678 | REALTOR.ca"
        XCTAssertEqual(ListingParser.address(fromTitle: title), "123 MAIN Street, Hamilton, Ontario L8P1A1")
        XCTAssertEqual(ListingParser.municipality(fromAddress: "123 MAIN Street, Hamilton, Ontario L8P1A1"), "Hamilton")
        XCTAssertEqual(ListingParser.municipality(fromAddress: "45 King St W, TORONTO (Waterfront), Ontario"), "Toronto")
        XCTAssertNil(ListingParser.municipality(fromAddress: "123 Main Street"))

        XCTAssertEqual(ListingParser.address(fromTitle: "10 acres vacant land - Lot 5 Concession 3, Kawartha Lakes | Kijiji"),
                       "Lot 5 Concession 3, Kawartha Lakes")
        XCTAssertNil(ListingParser.address(fromTitle: "Power of sale - 3 bedroom house in Hamilton | Kijiji"))
    }

    func testCleanTitle() {
        XCTAssertEqual(ListingParser.cleanTitle("For sale: 12 Elm Rd, Barrie - REALTOR.ca"), "12 Elm Rd, Barrie")
        XCTAssertEqual(ListingParser.cleanTitle("Bungalow with garage | Houses for Sale | Kijiji"), "Bungalow with garage")
    }

    func testFactsSaleTypeAndKind() {
        let text = "Power of Sale! 3+1 bedrooms, 2 bathrooms detached house on 0.5 acres, sold as is"
        let details = ListingParser.details(title: "", text: text)
        XCTAssertEqual(details.bedrooms, 3)
        XCTAssertEqual(details.bathrooms, 2)
        XCTAssertEqual(details.acres, 0.5)
        XCTAssertEqual(details.saleType, .powerOfSale)
        XCTAssertEqual(details.kind, .house)

        XCTAssertEqual(ListingParser.saleType(in: "Court appointed receiver sale"), .receivership)
        XCTAssertEqual(ListingParser.saleType(in: "Sale of land for tax arrears"), .taxSale)
        XCTAssertEqual(ListingParser.saleType(in: "POS, bring offers"), .powerOfSale)
        XCTAssertNil(ListingParser.saleType(in: "Lovely positive home"))
        XCTAssertEqual(ListingParser.saleType(in: "Estate sale, Certificate of Appointment obtained"), .estate)

        XCTAssertEqual(ListingParser.kind(in: "Vacant land with road access"), .vacantLand)
        XCTAssertEqual(ListingParser.kind(in: "Waterfront condo apartment"), .condo)
        XCTAssertEqual(ListingParser.kind(in: "Hobby farm with barn"), .farm)
    }

    func testStripHTML() {
        XCTAssertEqual(ListingParser.stripHTML("<strong>Power</strong> of sale &amp; more&nbsp;"), "Power of sale & more")
    }

    func testListingPageDetection() {
        func url(_ text: String) -> URL { URL(string: text)! }
        XCTAssertTrue(ListingParser.isLikelyListing(url("https://www.realtor.ca/real-estate/27512345/123-main-street-hamilton")))
        XCTAssertFalse(ListingParser.isLikelyListing(url("https://www.realtor.ca/on/hamilton/real-estate")))
        XCTAssertTrue(ListingParser.isLikelyListing(url("https://www.kijiji.ca/v-land-for-sale/ottawa/10-acres/1712345678")))
        XCTAssertFalse(ListingParser.isLikelyListing(url("https://www.kijiji.ca/b-land-for-sale/ottawa/c641")))
        XCTAssertTrue(ListingParser.isLikelyListing(url("https://housesigma.com/on/toronto-real-estate/1-main-st/home/abc123/")))
        XCTAssertTrue(ListingParser.isLikelyListing(url("https://www.zolo.ca/toronto-real-estate/123-main-st")))
        XCTAssertFalse(ListingParser.isLikelyListing(url("https://www.zolo.ca/toronto-real-estate")))
        XCTAssertTrue(ListingParser.isLikelyListing(url("https://www.example-brokerage.ca/listing/9")))
    }
}

final class BraveSearchClientTests: XCTestCase {
    private let sample = """
    {
      "type": "search",
      "query": { "original": "power of sale hamilton", "more_results_available": true },
      "web": {
        "type": "search",
        "results": [
          {
            "title": "123 MAIN Street, Hamilton, Ontario L8P1A1 - 12345678 | REALTOR.ca",
            "url": "https://www.realtor.ca/real-estate/27512345/123-main-street-hamilton",
            "description": "For sale: $599,900 - Power of sale! 3+1 bedrooms, 2 bathrooms detached house sold as is.",
            "age": "3 days ago",
            "page_age": "2026-11-17T08:00:00",
            "thumbnail": { "src": "https://imgs.search.brave.com/abc", "original": "https://cdn.example.ca/x.jpg" },
            "meta_url": { "scheme": "https", "netloc": "realtor.ca", "hostname": "www.realtor.ca", "path": "› real-estate" },
            "extra_snippets": ["Lot size 30 x 100 ft"]
          },
          {
            "title": "Hamilton Real Estate | Houses for Sale | REALTOR.ca",
            "url": "https://www.realtor.ca/on/hamilton/real-estate",
            "description": "Search Hamilton homes"
          },
          { "title": "Not a web page", "url": "ftp://example.com/x" },
          {
            "title": "10 acres vacant land - Lot 5 Concession 3, Kawartha Lakes | Kijiji",
            "url": "https://www.kijiji.ca/v-land-for-sale/kawartha-lakes/10-acres/1712345678",
            "description": "<strong>Vacant land</strong> 10.5 acres $125,000 &amp; road access"
          }
        ]
      }
    }
    """

    func testParsesResults() throws {
        let page = try BraveSearchClient.parse(Data(sample.utf8))
        XCTAssertTrue(page.moreAvailable)
        XCTAssertEqual(page.results.count, 3)

        let house = page.results[0]
        XCTAssertEqual(house.source, "realtor.ca")
        XCTAssertEqual(house.details.price, 599_900)
        XCTAssertEqual(house.details.address, "123 MAIN Street, Hamilton, Ontario L8P1A1")
        XCTAssertEqual(house.details.municipality, "Hamilton")
        XCTAssertEqual(house.details.bedrooms, 3)
        XCTAssertEqual(house.details.saleType, .powerOfSale)
        XCTAssertEqual(house.thumbnailURL?.host, "imgs.search.brave.com")
        XCTAssertNotNil(house.published)
        XCTAssertEqual(house.sourceLine, "realtor.ca · 3 days ago")
        XCTAssertTrue(house.isLikelyListing)

        XCTAssertFalse(page.results[1].isLikelyListing)

        let land = page.results[2]
        XCTAssertEqual(land.details.price, 125_000)
        XCTAssertEqual(land.details.kind, .vacantLand)
        XCTAssertEqual(land.details.address, "Lot 5 Concession 3, Kawartha Lakes")
        XCTAssertEqual(land.snippet, "Vacant land 10.5 acres $125,000 & road access")
    }

    func testEmptyAndBadResponses() throws {
        let empty = try BraveSearchClient.parse(Data("{}".utf8))
        XCTAssertTrue(empty.results.isEmpty)
        XCTAssertFalse(empty.moreAvailable)
        XCTAssertThrowsError(try BraveSearchClient.parse(Data("not json".utf8))) { error in
            XCTAssertEqual(error as? ListingSearchError, .unreadableResponse)
        }
    }

    func testRequest() throws {
        let request = BraveSearchClient.makeRequest(query: "site:realtor.ca \"power of sale\"", freshness: "pm", page: 12, apiKey: "KEY", extraSnippets: true)
        let url = try XCTUnwrap(request.url)
        let items = Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(url.host, "api.search.brave.com")
        XCTAssertEqual(items["q"], "site:realtor.ca \"power of sale\"")
        XCTAssertEqual(items["offset"], "9")
        XCTAssertEqual(items["count"], "20")
        XCTAssertEqual(items["country"], "CA")
        XCTAssertEqual(items["freshness"], "pm")
        XCTAssertEqual(items["extra_snippets"], "true")
        XCTAssertEqual(request.value(forHTTPHeaderField: "X-Subscription-Token"), "KEY")
    }
}

final class ListingSearchRequestTests: XCTestCase {
    func testAllSitesQuery() {
        let request = ListingSearchRequest(target: .allSites, terms: ["power of sale", "bank sale"], region: .hamiltonNiagara, pastMonth: true)
        XCTAssertEqual(
            request.query,
            #"(site:realtor.ca OR site:housesigma.com OR site:zolo.ca OR site:kijiji.ca) ("power of sale" OR "bank sale") ("Hamilton" OR "Burlington" OR "St. Catharines" OR "Niagara Falls" OR "Welland" OR "Grimsby")"#
        )
        XCTAssertEqual(request.freshness, "pm")
        XCTAssertEqual(request.suggestedSaleType, .powerOfSale)
        XCTAssertFalse(request.areTermsTrimmed)
    }

    func testKeywordsAreCapped() {
        let terms = ["power of sale", "POS", "bank sale", "mortgagee sale", "sold as is", "estate sale"]
        let request = ListingSearchRequest(target: .realtor, terms: terms, region: .anywhere, pastMonth: false)
        XCTAssertEqual(request.effectiveTerms.count, ListingSearchRequest.maxTerms)
        XCTAssertTrue(request.areTermsTrimmed)
        XCTAssertNil(request.freshness)
        XCTAssertTrue(request.query.hasPrefix("site:realtor.ca ("))
    }

    func testTaxSaleSearch() {
        let request = ListingSearchRequest(target: .taxSales, terms: ["vacant land"], region: .eastOfGTA, pastMonth: false)
        XCTAssertEqual(request.effectiveTerms, ["sale of land for tax arrears"])
        XCTAssertTrue(request.query.hasPrefix("\"sale of land for tax arrears\" (\"Peterborough\""))
        XCTAssertEqual(request.suggestedSaleType, .taxSale)
        XCTAssertEqual(request.googleFallbackURL.host, "www.google.com")
    }
}

final class SearchKeyStoreTests: XCTestCase {
    private final class MemoryStorage: SecretStorage {
        var value: String?
        func read() -> String? { value }
        func write(_ value: String) -> Bool { self.value = value; return true }
        func delete() { value = nil }
    }

    func testSaveReadAndRemove() {
        let storage = MemoryStorage()
        let keys = SearchKeyStore(storage: storage)
        XCTAssertFalse(keys.hasKey)
        XCTAssertFalse(keys.save("   "))

        XCTAssertTrue(keys.save("  abc123  "))
        XCTAssertEqual(keys.apiKey, "abc123")
        XCTAssertEqual(storage.value, "abc123")
        XCTAssertEqual(SearchKeyStore(storage: storage).apiKey, "abc123")

        keys.remove()
        XCTAssertNil(keys.apiKey)
        XCTAssertNil(storage.value)
    }

    func testUsageIsCountedPerMonth() throws {
        let suite = "usage-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let november = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 12)))
        let december = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 5, hour: 12)))

        XCTAssertEqual(ListingSearchUsage.count(now: november, defaults: defaults), 0)
        ListingSearchUsage.record(now: november, defaults: defaults)
        ListingSearchUsage.record(now: november, defaults: defaults)
        XCTAssertEqual(ListingSearchUsage.count(now: november, defaults: defaults), 2)
        XCTAssertEqual(ListingSearchUsage.count(now: december, defaults: defaults), 0)
    }
}
