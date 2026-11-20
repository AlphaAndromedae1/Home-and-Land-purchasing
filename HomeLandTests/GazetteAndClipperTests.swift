import XCTest
@testable import HomeLand

/// Fixtures follow the structure of real Ontario Gazette pages, with made-up municipalities and properties.
final class GazetteParserTests: XCTestCase {
    private let issue = GazetteIssue(
        volume: 159,
        number: 45,
        date: nil,
        dateText: "November 7, 2026",
        url: URL(string: "https://www.ontario.ca/document/ontario-gazette-volume-159-issue-45-november-7-2026")!
    )
    private let sectionURL = URL(string: "https://www.ontario.ca/document/ontario-gazette-volume-159-issue-45-november-7-2026/sale-land-tax-arrears-public-tender")!

    private let sectionHTML = """
    <html><body>
    <div class="body-field"><h2>Sign-in Menu EN</h2><p>Site menu</p></div>
    <main>
    <h2 class="small">On this page</h2><ul><li><a href="#a">Contents</a></li></ul>
    <div class="main-content" id="toc-end"><div class="body-field">
    <h2><span class="uppercase">The Corporation of the Town of Exampleton</span></h2>
    <p><strong>Take Notice</strong> that tenders are invited for the purchase of the land(s) described below and will be received until 3:00 p.m . local time on December 2, 2026 at the Town Office.</p>
    <p><strong>Description of Land(s):</strong></p>
    <ol><li data-list-item-id="a1"><p><strong>12 Maple Street</strong>; Registration <abbr title="Property identification number">PIN</abbr> # 01234-0567 (<abbr title="Lot">LT</abbr>); LT 5 PL 100; Exampleton; Roll # 1234-010-020-03000-0000</p><p>According to the last returned assessment roll, the assessed value of the land is $187,000</p><p><strong>Minimum Tender Amount:</strong><br><strong>$38,046.61</strong></p></li>
    <li data-list-item-id="a2"><p>0 Raymo Road; PIN 01087-0393 (LT); vacant lot</p><p><strong>Minimum Tender Amount:</strong><br><strong>$8,209.42</strong></p></li></ol>
    <p>Tenders must be submitted in the prescribed form and must be accompanied by a deposit of at least 20 per cent of the tender amount.</p>
    <p>For further information regarding this sale contact:</p>
    <p>Pat Example, Treasurer<br>The Corporation of the Town of Exampleton<br>1 Main Street<br>Tel:&nbsp;<a href="tel:+15555550100">555-555-0100</a><br><a href="mailto:treasurer@example.ca">treasurer@example.ca</a></p>
    <p>(159-P900)</p>
    <p><cite><span class="uppercase">municipal act, 2001</span></cite></p>
    <h2><span class="uppercase">The Corporation of the Township of Sampleford</span></h2>
    <p><strong>Take Notice</strong> that the land(s) described below will be offered for sale by public auction at one o&rsquo;clock on the 25<sup>th</sup> day of November, 2026 at the Township Office.</p>
    <p><strong>Description of Land(s):</strong></p>
    <p>Roll No. 52 08 000 004 07150 0000; 379 Chamberlin Rd., Sampleford; PIN 73484-0525 (LT); PT LT 10 CON 1</p>
    <p>According to the last returned assessment roll, the assessed value of the land is $210,000</p>
    <p><strong>Minimum Tender Amount:</strong><br>$47,055.75</p>
    <p>Please Note: A certificate has been registered on title to the land in File 24-83 PIN 73484-0525 (LT).</p>
    <p>Except as follows, the municipality makes no representation regarding the title.</p>
    <p>(159-P901) 44 and 45</p>
    <h2><span class="uppercase">The Corporation of Norfolk County</span></h2>
    <p><strong>Take Notice</strong> that tenders are invited and will be received until 3:00 p.m. local time on December 9, 2026.</p>
    <p><strong>Description of Land(s):</strong></p>
    <ol><li><p>Roll No. 33 10 541 030 22400 0000, 1686 Highway 3, Delhi, PIN 50155-0173 ( R ), PT LT 178 CON STR Middleton</p><p>According to the last returned assessment roll, the assessed value of the land is $614,000.</p><p><strong>Minimum Tender Amount:</strong><br>$55,113.12</p></li></ol>
    <p>For further information regarding this sale contact 311 (local) or 519-255-2489</p>
    <p>(159-P902)</p>
    </div></div>
    </main>
    <footer><h2>Questions or comments</h2><p>Footer $99,999</p></footer>
    </body></html>
    """

    private func notices() -> [GazetteNotice] {
        GazetteParser.notices(fromSectionHTML: sectionHTML, sectionURL: sectionURL, issue: issue)
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date? {
        GazetteParser.calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }

    func testFindsOnlyRealNotices() {
        XCTAssertEqual(notices().map(\.municipality), ["Exampleton", "Sampleford", "Norfolk County"])
    }

    func testTenderNoticeWithListedProperties() throws {
        let notice = try XCTUnwrap(notices().first)
        XCTAssertEqual(notice.heading, "The Corporation of the Town of Exampleton")
        XCTAssertEqual(notice.method, .tender)
        XCTAssertEqual(notice.closes, date(2026, 12, 2, 15))
        XCTAssertEqual(notice.noticeNumber, "159-P900")
        XCTAssertEqual(notice.parcels.count, 2)

        let first = notice.parcels[0]
        XCTAssertEqual(first.address, "12 Maple Street")
        XCTAssertEqual(first.pin, "01234-0567")
        XCTAssertEqual(first.rollNumber, "1234-010-020-03000-0000")
        XCTAssertEqual(first.assessedValue, 187_000)
        XCTAssertEqual(first.minimumTender, 38_046.61)
        XCTAssertEqual(notice.parcels[1].address, "0 Raymo Road")
        XCTAssertEqual(notice.parcels[1].minimumTender, 8_209.42)
        XCTAssertNil(notice.parcels[1].assessedValue)

        XCTAssertEqual(notice.contact.name, "Pat Example, Treasurer")
        XCTAssertEqual(notice.contact.phone, "555-555-0100")
        XCTAssertEqual(notice.contact.email, "treasurer@example.ca")

        XCTAssertEqual(notice.blocks.last?.text, "(159-P900)")
        XCTAssertTrue(notice.blocks.contains { $0.isListItem })
        XCTAssertTrue(notice.blocks.contains { $0.text == "Minimum Tender Amount:\n$38,046.61" })
    }

    func testAuctionNoticeWithParagraphProperties() throws {
        let notice = try XCTUnwrap(notices().dropFirst().first)
        XCTAssertEqual(notice.method, .auction)
        XCTAssertEqual(notice.closes, date(2026, 11, 25, 13))
        XCTAssertEqual(notice.parcels.count, 1, "The 'Please Note' paragraph isn't a property")
        let parcel = try XCTUnwrap(notice.parcels.first)
        XCTAssertEqual(parcel.address, "379 Chamberlin Rd.")
        XCTAssertEqual(parcel.rollNumber, "52 08 000 004 07150 0000")
        XCTAssertEqual(parcel.assessedValue, 210_000)
        XCTAssertEqual(parcel.minimumTender, 47_055.75)
        XCTAssertTrue(notice.contact.isEmpty)
        XCTAssertTrue(notice.blocks.contains { $0.text.contains("one o’clock") })
    }

    func testCommaSeparatedDescriptionAndInlineContact() throws {
        let notice = try XCTUnwrap(notices().last)
        XCTAssertEqual(notice.region, .southwest)
        XCTAssertEqual(notice.parcels.first?.address, "1686 Highway 3")
        XCTAssertEqual(notice.parcels.first?.pin, "50155-0173")
        XCTAssertEqual(notice.contact.phone, "519-255-2489")
        XCTAssertNil(notice.contact.name)
    }

    func testIssueIndex() throws {
        let html = """
        <article><h2 class="h5"><a href="/document/ontario-gazette-volume-159-issue-46-november-14-2026">Issue 46</a></h2></article>
        <article><h2 class="h5"><a href="/document/ontario-gazette-volume-159-issue-45-november-7-2026">Issue 45</a></h2></article>
        <a href="/document/ontario-gazette-volume-159-issue-45-november-7-2026">duplicate</a>
        <a href="/document/ontario-gazette-volume-159-issue-45-november-7-2026/sale-land-tax-arrears-public-tender">a section</a>
        """
        let issues = GazetteParser.issues(fromIndexHTML: html)
        XCTAssertEqual(issues.map(\.number), [46, 45])
        XCTAssertEqual(issues.first?.dateText, "November 14, 2026")
        XCTAssertEqual(issues.first?.date, date(2026, 11, 14, 0))
        XCTAssertEqual(issues.first?.url.absoluteString, "https://www.ontario.ca/document/ontario-gazette-volume-159-issue-46-november-14-2026")
        XCTAssertEqual(issues.first?.title, "Volume 159, Issue 46 (November 14, 2026)")
    }

    func testTaxSaleSectionLinks() {
        let html = """
        <a href="/document/ontario-gazette-volume-159-issue-45-november-7-2026/corporation-notices">Corporations</a>
        <a href="/document/ontario-gazette-volume-159-issue-45-november-7-2026/sale-land-tax-arrears-public-tender">Sale</a>
        <a href="http://www.ontario.ca/document/ontario-gazette-volume-159-issue-45-november-7-2026/sale-land-tax-arrears-public-tender">Same</a>
        <a href="/document/ontario-gazette-volume-159-issue-45-november-7-2026/sale-land-tax-arrears-public-tender-0">Sale 2</a>
        """
        XCTAssertEqual(GazetteParser.taxSaleSectionURLs(fromIssueHTML: html).map(\.lastPathComponent), [
            "sale-land-tax-arrears-public-tender",
            "sale-land-tax-arrears-public-tender-0",
        ])
    }

    func testClosingDates() {
        XCTAssertEqual(GazetteParser.closingDate(in: "received until 10:30 a.m. local time on January 5, 2027"), date(2027, 1, 5, 10, 30))
        XCTAssertEqual(GazetteParser.closingDate(in: "will be received until December 2, 2026"), date(2026, 12, 2, 15))
        XCTAssertNil(GazetteParser.closingDate(in: "No date here"))
    }

    func testShortNames() {
        XCTAssertEqual(GazetteParser.shortName(fromHeading: "The Municipality of City of Peterborough"), "Peterborough")
        XCTAssertEqual(GazetteParser.shortName(fromHeading: "The Municipality or Board of French River"), "French River")
        XCTAssertEqual(GazetteParser.shortName(fromHeading: "The City of Hamilton"), "Hamilton")
        XCTAssertEqual(GazetteParser.shortName(fromHeading: "THE CORPORATION OF THE TOWNSHIP OF TAY"), "Tay")
    }

    func testAddresses() {
        XCTAssertEqual(GazetteParser.address(fromDescription: "142 Barton Street East PT LT 28 PL 287 as in AB99668"), "142 Barton Street East")
        XCTAssertEqual(GazetteParser.address(fromDescription: "File #TS 22-105. Roll No.: 5307.060.042. Address: 655 Westmount Ave, Sudbury. Legal Description: Con 5"), "655 Westmount Ave")
        XCTAssertEqual(GazetteParser.address(fromDescription: "Lafferty Ave (S/S) (Vacant Land); Plan 793 Lot 429"), "Lafferty Ave")
        XCTAssertEqual(GazetteParser.address(fromDescription: "8290 Enfield PL ; Registration PIN # 01586-0672 (LT)"), "8290 Enfield PL")
        XCTAssertNil(GazetteParser.address(fromDescription: "PT LT 5 CON 2, Parts 1, 2 and 3, Plan 61R123"))
    }

    func testDeduplicationKeepsNewestIssue() throws {
        let older = try XCTUnwrap(notices().dropFirst().first)
        var newer = older
        newer.issue.number = 46
        newer.id = "newer"
        let result = GazetteParser.deduplicated([older, newer])
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.issue.number, 46)
    }

    func testDecodesEntities() {
        XCTAssertEqual(GazetteParser.text(fromHTML: "Smith&rsquo;s &amp; Sons&nbsp;Ltd<br>Tel:&#160;555"), "Smith’s & Sons Ltd\nTel: 555")
    }

    func testCreditMentionsCrownCopyright() throws {
        let notice = try XCTUnwrap(notices().first)
        XCTAssertTrue(notice.credit.contains("King's Printer for Ontario"))
        XCTAssertTrue(notice.credit.contains("Volume 159, Issue 45"))
    }

    func testImportingAPropertyToTheWatchlist() throws {
        let notice = try XCTUnwrap(notices().first)
        let house = GazetteImport.property(for: notice.parcels[0], in: notice)
        XCTAssertEqual(house.title, "12 Maple Street")
        XCTAssertEqual(house.saleType, .taxSale)
        XCTAssertEqual(house.kind, .house)
        XCTAssertEqual(house.askingPrice, 38_046.61)
        XCTAssertEqual(house.deadline, notice.closes)
        XCTAssertEqual(house.municipality, "Exampleton")
        XCTAssertEqual(house.listingURL, sectionURL.absoluteString)
        XCTAssertEqual(house.contacts.first?.role, .municipality)
        XCTAssertEqual(house.contacts.first?.phone, "555-555-0100")
        XCTAssertTrue(house.notes.contains("PIN: 01234-0567"))

        XCTAssertEqual(GazetteImport.property(for: notice.parcels[1], in: notice).kind, .vacantLand)
    }
}

final class RegionMatchingTests: XCTestCase {
    func testMatchesKnownMunicipalities() {
        XCTAssertEqual(Region.matching(municipality: "Peterborough"), .eastOfGTA)
        XCTAssertEqual(Region.matching(municipality: "Norfolk County"), .southwest)
        XCTAssertEqual(Region.matching(municipality: "Lasalle"), .southwest)
        XCTAssertEqual(Region.matching(municipality: "Brudenell, Lyndoch and Raglan"), .eastern)
        XCTAssertEqual(Region.matching(municipality: "Perth"), .eastern)
        XCTAssertEqual(Region.matching(municipality: "Hamilton"), .hamiltonNiagara)
        XCTAssertEqual(Region.matching(municipality: "Scarborough"), .gta)
        XCTAssertNil(Region.matching(municipality: "Nipigon"))
        XCTAssertNil(Region.matching(municipality: ""))
    }
}

final class PageClipperTests: XCTestCase {
    private let fallback = URL(string: "https://www.realtor.ca/real-estate/1/fallback")!

    func testStructuredDataWins() throws {
        let json = """
        {
          "url": "https://www.realtor.ca/real-estate/1/12-elm-street-barrie?utm_source=x",
          "canonical": "https://www.realtor.ca/real-estate/1/12-elm-street-barrie",
          "title": "12 Elm Street, Barrie | REALTOR.ca",
          "ogTitle": "For sale: 12 Elm Street, Barrie, Ontario L4M1A1",
          "description": "Power of sale! 3 bedroom bungalow on a big lot. $549,900",
          "image": "https://cdn.example.ca/1.jpg",
          "jsonld": [{ "@type": "Product", "offers": { "price": "649900", "priceCurrency": "CAD" },
                       "address": { "streetAddress": "12 Elm Street", "addressLocality": "Barrie" } }],
          "text": "Mortgage calculator $2,300/month"
        }
        """
        let page = PageClipper.page(fromJSON: Data(json.utf8), fallbackURL: fallback)
        XCTAssertEqual(page.url.absoluteString, "https://www.realtor.ca/real-estate/1/12-elm-street-barrie")
        XCTAssertEqual(page.structured.price, 649_900)

        let property = PageClipper.property(from: page)
        XCTAssertEqual(property.title, "12 Elm Street, Barrie")
        XCTAssertEqual(property.municipality, "Barrie")
        XCTAssertEqual(property.region, .georgianBay)
        XCTAssertEqual(property.askingPrice, 649_900)
        XCTAssertEqual(property.saleType, .powerOfSale)
        XCTAssertEqual(property.kind, .house)
        XCTAssertEqual(property.listingURL, page.url.absoluteString)
        XCTAssertEqual(PageClipper.details(for: page).bedrooms, 3)
    }

    func testFallsBackToTitleAndDescription() {
        let json = """
        {
          "url": "https://www.kijiji.ca/v-land-for-sale/kawartha-lakes/10-acres/1712345678",
          "canonical": "https://elsewhere.example.com/page",
          "title": "10 acres vacant land - Lot 5 Concession 3, Kawartha Lakes | Kijiji",
          "description": "Vacant land, 10 acres. $125,000",
          "jsonld": [],
          "text": ""
        }
        """
        let page = PageClipper.page(fromJSON: Data(json.utf8), fallbackURL: fallback)
        XCTAssertEqual(page.url.host, "www.kijiji.ca", "A canonical link on another site is ignored")
        let property = PageClipper.property(from: page)
        XCTAssertEqual(property.title, "Lot 5 Concession 3, Kawartha Lakes")
        XCTAssertEqual(property.region, .eastOfGTA)
        XCTAssertEqual(property.askingPrice, 125_000)
        XCTAssertEqual(property.kind, .vacantLand)
        XCTAssertEqual(property.analysis.size, 10)
    }

    func testUnreadablePageStillSaves() {
        let page = PageClipper.page(fromJSON: Data("nope".utf8), fallbackURL: fallback)
        XCTAssertEqual(page.url, fallback)
        XCTAssertEqual(PageClipper.property(from: page).title, "Saved listing")
    }
}
