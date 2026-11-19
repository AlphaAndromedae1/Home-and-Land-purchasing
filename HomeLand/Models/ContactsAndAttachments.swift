import Foundation

enum ContactRole: String, Codable, CaseIterable, Identifiable {
    case listingAgent
    case buyerAgent
    case lawyer
    case receiver
    case municipality
    case lender
    case inspector
    case contractor
    case other

    var id: String { rawValue }

    var name: String {
        switch self {
        case .listingAgent: return "Listing agent"
        case .buyerAgent: return "My agent"
        case .lawyer: return "Lawyer"
        case .receiver: return "Receiver or trustee"
        case .municipality: return "Municipal clerk or treasurer"
        case .lender: return "Lender or mortgage broker"
        case .inspector: return "Inspector"
        case .contractor: return "Contractor"
        case .other: return "Other"
        }
    }

    var symbol: String {
        switch self {
        case .listingAgent: return "house"
        case .buyerAgent: return "person"
        case .lawyer: return "building.columns"
        case .receiver: return "hammer"
        case .municipality: return "building.2"
        case .lender: return "dollarsign.circle"
        case .inspector: return "magnifyingglass"
        case .contractor: return "wrench.and.screwdriver"
        case .other: return "person.crop.circle"
        }
    }

    /// The contact you most likely deal with for a sale type.
    static func suggested(for saleType: SaleType) -> ContactRole {
        switch saleType {
        case .taxSale: return .municipality
        case .receivership: return .receiver
        case .powerOfSale, .estate, .regular: return .listingAgent
        case .surplus, .auction: return .other
        }
    }
}

struct PropertyContact: Identifiable, Codable, Hashable {
    var id: UUID
    var role: ContactRole
    var name: String
    var company: String
    var phone: String
    var email: String
    var notes: String

    init(
        id: UUID = UUID(),
        role: ContactRole = .listingAgent,
        name: String = "",
        company: String = "",
        phone: String = "",
        email: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.role = role
        self.name = name
        self.company = company
        self.phone = phone
        self.email = email
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, role, name, company, phone, email, notes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        role = (try? c.decodeIfPresent(ContactRole.self, forKey: .role)) ?? .other
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? ""
        company = (try? c.decodeIfPresent(String.self, forKey: .company)) ?? ""
        phone = (try? c.decodeIfPresent(String.self, forKey: .phone)) ?? ""
        email = (try? c.decodeIfPresent(String.self, forKey: .email)) ?? ""
        notes = (try? c.decodeIfPresent(String.self, forKey: .notes)) ?? ""
    }

    var isEmpty: Bool {
        [name, company, phone, email].allSatisfy { $0.trimmed.isEmpty }
    }

    var displayName: String {
        if !name.trimmed.isEmpty { return name.trimmed }
        if !company.trimmed.isEmpty { return company.trimmed }
        return role.name
    }

    var subtitle: String {
        var parts = [role.name]
        if !name.trimmed.isEmpty, !company.trimmed.isEmpty {
            parts.append(company.trimmed)
        }
        return parts.joined(separator: " · ")
    }

    private var dialableDigits: String? {
        let digits = phone.filter { "0123456789+".contains($0) }
        return digits.filter(\.isNumber).count >= 7 ? digits : nil
    }

    var phoneURL: URL? {
        dialableDigits.flatMap { URL(string: "tel:\($0)") }
    }

    var smsURL: URL? {
        dialableDigits.flatMap { URL(string: "sms:\($0)") }
    }

    var emailURL: URL? {
        let address = email.trimmed
        guard address.contains("@"), !address.contains(" ") else { return nil }
        return URL(string: "mailto:\(address)")
    }
}

enum AttachmentKind: String, Codable {
    case photo
    case document
}

/// A photo or document stored in the app's Documents/Attachments/<property id>/ folder.
struct Attachment: Identifiable, Codable, Hashable {
    var id: UUID
    var kind: AttachmentKind
    /// Name of the file on disk.
    var fileName: String
    /// Name shown to the user.
    var name: String
    var dateAdded: Date

    init(id: UUID = UUID(), kind: AttachmentKind, fileName: String, name: String, dateAdded: Date = Date()) {
        self.id = id
        self.kind = kind
        self.fileName = fileName
        self.name = name
        self.dateAdded = dateAdded
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, fileName, name, dateAdded
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        kind = (try? c.decodeIfPresent(AttachmentKind.self, forKey: .kind)) ?? .document
        fileName = (try? c.decodeIfPresent(String.self, forKey: .fileName)) ?? ""
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "File"
        dateAdded = (try? c.decodeIfPresent(Date.self, forKey: .dateAdded)) ?? Date()
    }
}
