import Foundation

enum SizeUnit: String {
    case squareFeet
    case acres

    var label: String {
        switch self {
        case .squareFeet: return "sq ft"
        case .acres: return "acres"
        }
    }

    var singular: String {
        switch self {
        case .squareFeet: return "sq ft"
        case .acres: return "acre"
        }
    }
}

extension PropertyKind {
    /// How "what you get" is measured: floor area for buildings, acres for land.
    var sizeUnit: SizeUnit {
        switch self {
        case .vacantLand, .farm, .development: return .acres
        case .house, .condo, .cottage, .commercial: return .squareFeet
        }
    }
}

/// Things the buyer rates from 1 to 5 stars.
enum QualityFactor: String, CaseIterable, Identifiable {
    case location
    case condition
    case land
    case potential

    var id: String { rawValue }

    var name: String {
        switch self {
        case .location: return "Location"
        case .condition: return "Condition"
        case .land: return "Lot & land"
        case .potential: return "Potential"
        }
    }

    var detail: String {
        switch self {
        case .location: return "Neighbourhood, commute, schools and services"
        case .condition: return "Structure, roof, systems and finishes"
        case .land: return "Size, shape, frontage, privacy, views and water"
        case .potential: return "Extra units, severance, additions or rezoning"
        }
    }
}

/// Red flags that lower a deal's score.
enum RiskFactor: String, CaseIterable, Identifiable {
    case noInspection
    case occupants
    case title
    case access
    case environment
    case majorRepairs

    static let pointsEach = 3.0

    var id: String { rawValue }

    var name: String {
        switch self {
        case .noInspection: return "Can't inspect inside"
        case .occupants: return "Tenants or occupants"
        case .title: return "Title, lien or easement concerns"
        case .access: return "Road access or zoning concerns"
        case .environment: return "Flood, erosion or contamination risk"
        case .majorRepairs: return "Major repairs suspected"
        }
    }
}

/// A recent sale of a similar property, used to estimate value.
struct ComparableSale: Identifiable, Codable, Hashable {
    var id: UUID
    var address: String
    var soldPrice: Double
    /// Square feet or acres, matching the property's `sizeUnit`.
    var size: Double?
    var soldDate: Date?

    init(id: UUID = UUID(), address: String = "", soldPrice: Double = 0, size: Double? = nil, soldDate: Date? = nil) {
        self.id = id
        self.address = address
        self.soldPrice = soldPrice
        self.size = size
        self.soldDate = soldDate
    }

    private enum CodingKeys: String, CodingKey {
        case id, address, soldPrice, size, soldDate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        soldPrice = (try? c.decodeIfPresent(Double.self, forKey: .soldPrice)) ?? 0
        size = try? c.decodeIfPresent(Double.self, forKey: .size)
        soldDate = try? c.decodeIfPresent(Date.self, forKey: .soldDate)
    }
}

/// Everything the user enters to rate a deal and work out a maximum offer.
struct DealAnalysis: Codable, Hashable {
    // Value
    /// What the property is worth in good condition (after repairs). Overrides comparables.
    var estimatedValue: Double?
    /// Square feet or acres, matching the property's `sizeUnit`.
    var size: Double?
    var comparables: [ComparableSale]

    // Costs
    var renovationCost: Double?
    /// Legal, inspection, title insurance and other closing costs.
    var closingCosts: Double?

    // Rating
    /// `QualityFactor.rawValue` → 1...5 stars.
    var ratings: [String: Int]
    /// `RiskFactor.rawValue`s that apply.
    var risks: Set<String>

    // Plan and financing
    var resell: Bool
    var holdingMonths: Int
    var interestRate: Double
    var downPaymentPercent: Double
    var amortizationYears: Double
    var propertyTaxYearly: Double?
    var insuranceYearly: Double?
    var utilitiesMonthly: Double?
    var sellingCostPercent: Double
    var targetProfitPercent: Double

    init(
        estimatedValue: Double? = nil,
        size: Double? = nil,
        comparables: [ComparableSale] = [],
        renovationCost: Double? = nil,
        closingCosts: Double? = nil,
        ratings: [String: Int] = [:],
        risks: Set<String> = [],
        resell: Bool = false,
        holdingMonths: Int = 6,
        interestRate: Double = 5,
        downPaymentPercent: Double = 20,
        amortizationYears: Double = 25,
        propertyTaxYearly: Double? = nil,
        insuranceYearly: Double? = nil,
        utilitiesMonthly: Double? = nil,
        sellingCostPercent: Double = 5,
        targetProfitPercent: Double = 15
    ) {
        self.estimatedValue = estimatedValue
        self.size = size
        self.comparables = comparables
        self.renovationCost = renovationCost
        self.closingCosts = closingCosts
        self.ratings = ratings
        self.risks = risks
        self.resell = resell
        self.holdingMonths = holdingMonths
        self.interestRate = interestRate
        self.downPaymentPercent = downPaymentPercent
        self.amortizationYears = amortizationYears
        self.propertyTaxYearly = propertyTaxYearly
        self.insuranceYearly = insuranceYearly
        self.utilitiesMonthly = utilitiesMonthly
        self.sellingCostPercent = sellingCostPercent
        self.targetProfitPercent = targetProfitPercent
    }

    private enum CodingKeys: String, CodingKey {
        case estimatedValue, size, comparables, renovationCost, closingCosts, ratings, risks
        case resell, holdingMonths, interestRate, downPaymentPercent, amortizationYears
        case propertyTaxYearly, insuranceYearly, utilitiesMonthly, sellingCostPercent, targetProfitPercent
    }

    init(from decoder: Decoder) throws {
        let defaults = DealAnalysis()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        estimatedValue = try? c.decodeIfPresent(Double.self, forKey: .estimatedValue)
        size = try? c.decodeIfPresent(Double.self, forKey: .size)
        comparables = (try? c.decodeIfPresent([ComparableSale].self, forKey: .comparables)) ?? []
        renovationCost = try? c.decodeIfPresent(Double.self, forKey: .renovationCost)
        closingCosts = try? c.decodeIfPresent(Double.self, forKey: .closingCosts)
        ratings = (try? c.decodeIfPresent([String: Int].self, forKey: .ratings)) ?? [:]
        risks = (try? c.decodeIfPresent(Set<String>.self, forKey: .risks)) ?? []
        resell = (try? c.decodeIfPresent(Bool.self, forKey: .resell)) ?? defaults.resell
        holdingMonths = (try? c.decodeIfPresent(Int.self, forKey: .holdingMonths)) ?? defaults.holdingMonths
        interestRate = (try? c.decodeIfPresent(Double.self, forKey: .interestRate)) ?? defaults.interestRate
        downPaymentPercent = (try? c.decodeIfPresent(Double.self, forKey: .downPaymentPercent)) ?? defaults.downPaymentPercent
        amortizationYears = (try? c.decodeIfPresent(Double.self, forKey: .amortizationYears)) ?? defaults.amortizationYears
        propertyTaxYearly = try? c.decodeIfPresent(Double.self, forKey: .propertyTaxYearly)
        insuranceYearly = try? c.decodeIfPresent(Double.self, forKey: .insuranceYearly)
        utilitiesMonthly = try? c.decodeIfPresent(Double.self, forKey: .utilitiesMonthly)
        sellingCostPercent = (try? c.decodeIfPresent(Double.self, forKey: .sellingCostPercent)) ?? defaults.sellingCostPercent
        targetProfitPercent = (try? c.decodeIfPresent(Double.self, forKey: .targetProfitPercent)) ?? defaults.targetProfitPercent
    }

    func rating(for factor: QualityFactor) -> Int {
        ratings[factor.rawValue] ?? 0
    }

    mutating func setRating(_ stars: Int, for factor: QualityFactor) {
        ratings[factor.rawValue] = (1...5).contains(stars) ? stars : nil
    }

    func hasRisk(_ risk: RiskFactor) -> Bool {
        risks.contains(risk.rawValue)
    }

    mutating func setRisk(_ risk: RiskFactor, _ isOn: Bool) {
        if isOn {
            risks.insert(risk.rawValue)
        } else {
            risks.remove(risk.rawValue)
        }
    }

    var ratedStars: [Int] {
        QualityFactor.allCases.map { rating(for: $0) }.filter { $0 > 0 }
    }

    var activeRisks: [RiskFactor] {
        RiskFactor.allCases.filter { hasRisk($0) }
    }
}
