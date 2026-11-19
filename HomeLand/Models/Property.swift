import Foundation

/// A property the user is tracking on their watchlist.
struct Property: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var municipality: String
    var region: Region
    var saleType: SaleType
    var kind: PropertyKind
    var status: WatchStatus
    /// Asking price, or the minimum tender for a tax sale.
    var askingPrice: Double?
    /// The most the user is willing to pay.
    var maxPrice: Double?
    var lotSize: String
    var listingURL: String
    var mlsNumber: String
    /// Offer date, tender closing or auction date.
    var deadline: Date?
    var notes: String
    /// IDs of finished checklist items (see `Checklist`).
    var completedChecks: Set<String>
    var contacts: [PropertyContact]
    var attachments: [Attachment]
    var analysis: DealAnalysis
    var dateAdded: Date
    var dateUpdated: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        municipality: String = "",
        region: Region = .gta,
        saleType: SaleType = .powerOfSale,
        kind: PropertyKind = .house,
        status: WatchStatus = .watching,
        askingPrice: Double? = nil,
        maxPrice: Double? = nil,
        lotSize: String = "",
        listingURL: String = "",
        mlsNumber: String = "",
        deadline: Date? = nil,
        notes: String = "",
        completedChecks: Set<String> = [],
        contacts: [PropertyContact] = [],
        attachments: [Attachment] = [],
        analysis: DealAnalysis = DealAnalysis(),
        dateAdded: Date = Date(),
        dateUpdated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.municipality = municipality
        self.region = region
        self.saleType = saleType
        self.kind = kind
        self.status = status
        self.askingPrice = askingPrice
        self.maxPrice = maxPrice
        self.lotSize = lotSize
        self.listingURL = listingURL
        self.mlsNumber = mlsNumber
        self.deadline = deadline
        self.notes = notes
        self.completedChecks = completedChecks
        self.contacts = contacts
        self.attachments = attachments
        self.analysis = analysis
        self.dateAdded = dateAdded
        self.dateUpdated = dateUpdated
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, municipality, region, saleType, kind, status, askingPrice, maxPrice
        case lotSize, listingURL, mlsNumber, deadline, notes, completedChecks
        case contacts, attachments, analysis, dateAdded, dateUpdated
    }

    /// Decodes leniently so older, newer or hand-edited backups still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        title = (try? c.decodeIfPresent(String.self, forKey: .title)) ?? ""
        municipality = (try? c.decodeIfPresent(String.self, forKey: .municipality)) ?? ""
        region = (try? c.decodeIfPresent(Region.self, forKey: .region)) ?? .anywhere
        saleType = (try? c.decodeIfPresent(SaleType.self, forKey: .saleType)) ?? .regular
        kind = (try? c.decodeIfPresent(PropertyKind.self, forKey: .kind)) ?? .house
        status = (try? c.decodeIfPresent(WatchStatus.self, forKey: .status)) ?? .watching
        askingPrice = try? c.decodeIfPresent(Double.self, forKey: .askingPrice)
        maxPrice = try? c.decodeIfPresent(Double.self, forKey: .maxPrice)
        lotSize = (try? c.decodeIfPresent(String.self, forKey: .lotSize)) ?? ""
        listingURL = (try? c.decodeIfPresent(String.self, forKey: .listingURL)) ?? ""
        mlsNumber = (try? c.decodeIfPresent(String.self, forKey: .mlsNumber)) ?? ""
        deadline = try? c.decodeIfPresent(Date.self, forKey: .deadline)
        notes = (try? c.decodeIfPresent(String.self, forKey: .notes)) ?? ""
        completedChecks = (try? c.decodeIfPresent(Set<String>.self, forKey: .completedChecks)) ?? []
        contacts = (try? c.decodeIfPresent([PropertyContact].self, forKey: .contacts)) ?? []
        attachments = (try? c.decodeIfPresent([Attachment].self, forKey: .attachments)) ?? []
        analysis = (try? c.decodeIfPresent(DealAnalysis.self, forKey: .analysis)) ?? DealAnalysis()
        dateAdded = (try? c.decodeIfPresent(Date.self, forKey: .dateAdded)) ?? Date()
        dateUpdated = (try? c.decodeIfPresent(Date.self, forKey: .dateUpdated)) ?? dateAdded
    }
}

extension Property {
    var displayTitle: String {
        let trimmedTitle = title.trimmed
        return trimmedTitle.isEmpty ? "Untitled property" : trimmedTitle
    }

    var listingLink: URL? {
        ListingURLParser.normalizedURL(from: listingURL)
    }

    var checklistGroups: [ChecklistGroup] {
        Checklist.groups(saleType: saleType, kind: kind)
    }

    /// Checklist progress, counting only items that apply to the current sale type and property kind.
    var checklistProgress: (done: Int, total: Int) {
        let ids = checklistGroups.flatMap { $0.items.map(\.id) }
        let done = ids.filter { completedChecks.contains($0) }.count
        return (done, ids.count)
    }

    /// The price used for cost estimates: the user's maximum if set, otherwise the asking price.
    var priceForEstimates: Double? {
        maxPrice ?? askingPrice
    }

    var isInToronto: Bool {
        let place = municipality.lowercased()
        return ["toronto", "scarborough", "etobicoke", "north york", "east york"].contains { place.contains($0) }
    }

    /// A web search for this property's address.
    var webSearchQuery: String {
        let parts = [title.trimmed, municipality.trimmed].filter { !$0.isEmpty }
        return parts.isEmpty ? "Ontario property" : "\"\(parts[0])\"" + (parts.count > 1 ? " \(parts[1]) Ontario" : " Ontario")
    }

    func matches(_ query: String) -> Bool {
        let fields = [title, municipality, notes, mlsNumber, lotSize, region.name, saleType.name, kind.name]
            + contacts.flatMap { [$0.name, $0.company] }
        return fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
