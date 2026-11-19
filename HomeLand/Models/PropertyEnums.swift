import SwiftUI

enum SaleType: String, Codable, CaseIterable, Identifiable {
    case powerOfSale
    case taxSale
    case receivership
    case estate
    case surplus
    case auction
    case regular

    var id: String { rawValue }

    var name: String {
        switch self {
        case .powerOfSale: return "Power of sale"
        case .taxSale: return "Tax sale"
        case .receivership: return "Receivership"
        case .estate: return "Estate sale"
        case .surplus: return "Government surplus"
        case .auction: return "Auction"
        case .regular: return "Regular listing"
        }
    }

    var symbol: String {
        switch self {
        case .powerOfSale: return "building.columns"
        case .taxSale: return "doc.text"
        case .receivership: return "hammer"
        case .estate: return "person.2"
        case .surplus: return "flag"
        case .auction: return "megaphone"
        case .regular: return "house"
        }
    }

    var color: Color {
        switch self {
        case .powerOfSale: return .red
        case .taxSale: return .orange
        case .receivership: return .purple
        case .estate: return .teal
        case .surplus: return .indigo
        case .auction: return .pink
        case .regular: return .gray
        }
    }
}

enum PropertyKind: String, Codable, CaseIterable, Identifiable {
    case house
    case condo
    case vacantLand
    case farm
    case cottage
    case commercial
    case development

    var id: String { rawValue }

    var name: String {
        switch self {
        case .house: return "House"
        case .condo: return "Condo or townhouse"
        case .vacantLand: return "Vacant land"
        case .farm: return "Farm or acreage"
        case .cottage: return "Cottage or recreational"
        case .commercial: return "Commercial"
        case .development: return "Development land"
        }
    }

    var symbol: String {
        switch self {
        case .house: return "house"
        case .condo: return "building.2"
        case .vacantLand: return "map"
        case .farm: return "leaf"
        case .cottage: return "water.waves"
        case .commercial: return "storefront"
        case .development: return "hammer"
        }
    }

    /// Property you'd mainly buy for the land: road, septic and planning checks apply.
    var isLand: Bool {
        switch self {
        case .vacantLand, .farm, .cottage, .development: return true
        case .house, .condo, .commercial: return false
        }
    }

    /// Whether Ontario's top 2.5% land transfer tax bracket (for land with one
    /// or two single-family homes) is likely to apply.
    var usesHomeLandTransferTax: Bool {
        switch self {
        case .house, .condo, .cottage, .farm: return true
        case .vacantLand, .commercial, .development: return false
        }
    }
}

enum WatchStatus: String, Codable, CaseIterable, Identifiable {
    case watching
    case researching
    case viewing
    case offerMade
    case won
    case lost
    case passed

    var id: String { rawValue }

    var name: String {
        switch self {
        case .watching: return "Watching"
        case .researching: return "Researching"
        case .viewing: return "Viewing booked"
        case .offerMade: return "Offer or bid in"
        case .won: return "Won"
        case .lost: return "Lost"
        case .passed: return "Passed"
        }
    }

    var isOpen: Bool {
        switch self {
        case .won, .lost, .passed: return false
        case .watching, .researching, .viewing, .offerMade: return true
        }
    }

    var color: Color {
        switch self {
        case .watching: return .blue
        case .researching: return .teal
        case .viewing: return .indigo
        case .offerMade: return .orange
        case .won: return .green
        case .lost, .passed: return .gray
        }
    }
}
