import XCTest
@testable import HomeLand

final class PropertyStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private var fileURL: URL {
        directory.appendingPathComponent("watchlist.json")
    }

    private func makeStore() -> PropertyStore {
        PropertyStore(fileURL: fileURL)
    }

    func testSavesAndReloads() {
        let deadline = Date(timeIntervalSince1970: 1_800_000_000)
        let store = makeStore()
        store.upsert(Property(title: "123 Main St", municipality: "Hamilton", saleType: .powerOfSale, askingPrice: 650_000, deadline: deadline))

        let reloaded = makeStore()
        XCTAssertEqual(reloaded.properties.count, 1)
        XCTAssertEqual(reloaded.properties.first?.title, "123 Main St")
        XCTAssertEqual(reloaded.properties.first?.askingPrice, 650_000)
        XCTAssertEqual(reloaded.properties.first?.deadline, deadline)
    }

    func testNewPropertiesGoFirstAndUpdatesReplace() {
        let store = makeStore()
        var first = Property(title: "First")
        store.upsert(first)
        store.upsert(Property(title: "Second"))
        XCTAssertEqual(store.properties.map(\.title), ["Second", "First"])

        first.title = "First, edited"
        store.upsert(first)
        XCTAssertEqual(store.properties.count, 2)
        XCTAssertEqual(store.property(id: first.id)?.title, "First, edited")
    }

    func testToggleCheckAndStatus() {
        let store = makeStore()
        let property = Property(title: "Lot 5")
        store.upsert(property)

        store.toggleCheck("core.title", for: property.id)
        XCTAssertEqual(store.property(id: property.id)?.completedChecks, ["core.title"])
        store.toggleCheck("core.title", for: property.id)
        XCTAssertEqual(store.property(id: property.id)?.completedChecks, [])

        store.setStatus(.offerMade, for: property.id)
        XCTAssertEqual(makeStore().property(id: property.id)?.status, .offerMade)
    }

    func testDelete() {
        let store = makeStore()
        let property = Property(title: "Gone")
        store.upsert(property)
        store.delete(ids: [property.id])
        XCTAssertTrue(makeStore().properties.isEmpty)
    }

    func testDecodesBackupsWithMissingOrUnknownFields() throws {
        let json = #"[{"title":"Lot 5","saleType":"taxSale","kind":"somethingNew","futureField":true}]"#
        try Data(json.utf8).write(to: fileURL)

        let store = makeStore()
        XCTAssertEqual(store.properties.count, 1)
        XCTAssertEqual(store.properties.first?.title, "Lot 5")
        XCTAssertEqual(store.properties.first?.saleType, .taxSale)
        XCTAssertEqual(store.properties.first?.kind, .house)
        XCTAssertEqual(store.properties.first?.status, .watching)
        XCTAssertNil(store.lastError)
    }

    func testUnreadableFileIsKeptAside() throws {
        try Data("not json".utf8).write(to: fileURL)

        let store = makeStore()
        XCTAssertTrue(store.properties.isEmpty)
        XCTAssertNotNil(store.lastError)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("watchlist-unreadable-") }, "\(files)")
    }

    func testImportMergesByID() throws {
        let store = makeStore()
        var existing = Property(title: "Old title")
        store.upsert(existing)

        existing.title = "New title"
        existing.dateUpdated = Date().addingTimeInterval(3_600)
        let added = Property(title: "Brand new")
        let backupURL = directory.appendingPathComponent("backup.json")
        try PropertyStore.encoder.encode([existing, added]).write(to: backupURL)

        let count = try store.importBackup(from: backupURL)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(store.properties.count, 2)
        XCTAssertEqual(store.property(id: existing.id)?.title, "New title")
        XCTAssertNotNil(store.property(id: added.id))
    }

    func testExportRoundTrips() throws {
        let store = makeStore()
        store.upsert(Property(title: "Exported", notes: "Back up often"))
        let url = try store.exportBackup()
        defer { try? FileManager.default.removeItem(at: url) }

        let other = PropertyStore(fileURL: directory.appendingPathComponent("other.json"))
        try other.importBackup(from: url)
        XCTAssertEqual(other.properties.first?.notes, "Back up often")
    }
}

final class ChecklistTests: XCTestCase {
    private func ids(_ saleType: SaleType, _ kind: PropertyKind) -> [String] {
        Checklist.groups(saleType: saleType, kind: kind).flatMap { $0.items.map(\.id) }
    }

    func testTaxSaleLandChecklist() {
        let items = ids(.taxSale, .vacantLand)
        XCTAssertTrue(items.contains("tax.deposit"))
        XCTAssertTrue(items.contains("land.road"))
        XCTAssertFalse(items.contains("pos.tenants"))
    }

    func testItemIDsAreUniqueForEveryCombination() {
        for saleType in SaleType.allCases {
            for kind in PropertyKind.allCases {
                let items = ids(saleType, kind)
                XCTAssertEqual(items.count, Set(items).count, "Duplicate checklist IDs for \(saleType) / \(kind)")
            }
        }
    }

    func testProgressIgnoresChecksThatNoLongerApply() {
        var property = Property(saleType: .powerOfSale, kind: .house)
        property.completedChecks = ["core.title", "tax.deposit"]
        XCTAssertEqual(property.checklistProgress.done, 1)
        XCTAssertEqual(property.checklistProgress.total, ids(.powerOfSale, .house).count)
    }

    func testTorontoDetection() {
        XCTAssertTrue(Property(municipality: "Toronto").isInToronto)
        XCTAssertTrue(Property(municipality: "Scarborough").isInToronto)
        XCTAssertFalse(Property(municipality: "Mississauga").isInToronto)
    }
}

final class ContentTests: XCTestCase {
    func testSourceIDsAreUnique() {
        let ids = Sources.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testSourcesUseHTTPS() {
        for source in Sources.all {
            XCTAssertEqual(source.url.scheme, "https", source.name)
            XCTAssertNotNil(source.url.host, source.name)
        }
    }

    func testEveryCategoryHasSources() {
        for category in SourceCategory.allCases {
            XCTAssertFalse(Sources.items(in: category).isEmpty, category.title)
        }
    }

    func testGuideSectionIDsAreUnique() {
        let ids = Guide.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testRegionsHaveContent() {
        for region in Region.southernRegions {
            XCTAssertFalse(region.places.isEmpty, region.name)
            XCTAssertFalse(region.tips.isEmpty, region.name)
        }
    }

    func testKeywordsAreUnique() {
        let terms = Keywords.all.map(\.term)
        XCTAssertEqual(terms.count, Set(terms).count)
    }
}
