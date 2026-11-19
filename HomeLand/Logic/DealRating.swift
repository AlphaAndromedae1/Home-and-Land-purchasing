import SwiftUI

enum DealGrade: Int, CaseIterable {
    case poor = 1
    case belowAverage
    case fair
    case good
    case excellent

    init(score: Int) {
        switch score {
        case 80...: self = .excellent
        case 65..<80: self = .good
        case 50..<65: self = .fair
        case 35..<50: self = .belowAverage
        default: self = .poor
        }
    }

    var minimumScore: Int {
        switch self {
        case .excellent: return 80
        case .good: return 65
        case .fair: return 50
        case .belowAverage: return 35
        case .poor: return 0
        }
    }

    var stars: Int { rawValue }

    var name: String {
        switch self {
        case .excellent: return "Excellent deal"
        case .good: return "Good deal"
        case .fair: return "Fair deal"
        case .belowAverage: return "Below average"
        case .poor: return "Poor deal"
        }
    }

    var shortName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .belowAverage: return "Below avg"
        case .poor: return "Poor"
        }
    }

    var color: Color {
        switch self {
        case .excellent: return .green
        case .good: return Color(red: 0.36, green: 0.66, blue: 0.18)
        case .fair: return .orange
        case .belowAverage: return Color(red: 0.90, green: 0.38, blue: 0.10)
        case .poor: return .red
        }
    }
}

/// An estimate of what a property is worth in good condition.
struct ValueEstimate: Equatable {
    enum Method: Equatable {
        case manual
        case pricePerUnit(rate: Double, count: Int)
        case medianPrice(count: Int)
    }

    let value: Double
    let method: Method

    func explanation(unit: SizeUnit) -> String {
        switch method {
        case .manual:
            return "Using the estimated value you entered."
        case let .pricePerUnit(rate, count):
            return "Median of \(count) comparable \(count == 1 ? "sale" : "sales"): \(Fmt.money(rate)) per \(unit.singular) × this property's size."
        case let .medianPrice(count):
            return "Median sold price of \(count) comparable \(count == 1 ? "sale" : "sales"). Add sizes to compare price per \(unit.singular)."
        }
    }
}

struct DealRating: Equatable {
    let score: Int
    let grade: DealGrade
    /// Out of `DealRater.maxPricePoints`.
    let pricePoints: Double
    /// Out of `DealRater.maxQualityPoints`.
    let qualityPoints: Double
    /// Out of `DealRater.maxRiskPoints`.
    let riskPoints: Double
    /// How far the all-in cost is below the estimated value (negative when above).
    let discount: Double
    let price: Double
    let allInCost: Double
    let estimate: ValueEstimate
    let ratedFactorCount: Int
    let riskNotes: [String]

    var headline: String {
        let percent = Int((abs(discount) * 100).rounded())
        if percent == 0 {
            return "All-in cost matches the estimated value"
        }
        return discount > 0
            ? "All-in cost is \(percent)% below estimated value"
            : "All-in cost is \(percent)% above estimated value"
    }
}

/// Scores how good a price is for what you get, out of 100:
/// - up to 60 points for the all-in cost (price, land transfer tax, renovation
///   and closing) compared with the estimated value,
/// - up to 25 points for the buyer's star ratings of what they get,
/// - up to 15 points for low risk, minus points for each red flag.
enum DealRater {
    static let maxPricePoints = 60.0
    static let maxQualityPoints = 25.0
    static let maxRiskPoints = 15.0
    static let defaultClosingCosts = 2_500.0

    struct Inputs {
        var price: Double
        var estimate: ValueEstimate
        var renovation: Double
        var closing: Double
        var isHome: Bool
        var inToronto: Bool
        var ratings: [Int]
        var risks: [RiskFactor]
        var saleType: SaleType
    }

    /// 0 points at 20% or more over value, 30 at exactly value, 60 at 30% or more under.
    static func pricePoints(discount: Double) -> Double {
        if discount <= -0.2 { return 0 }
        if discount < 0 { return 30 * (discount + 0.2) / 0.2 }
        if discount < 0.3 { return 30 + 30 * discount / 0.3 }
        return maxPricePoints
    }

    /// Average stars mapped to 0–25. Nothing rated counts as average.
    static func qualityPoints(ratings: [Int]) -> Double {
        let valid = ratings.filter { (1...5).contains($0) }
        guard !valid.isEmpty else { return maxQualityPoints / 2 }
        let average = Double(valid.reduce(0, +)) / Double(valid.count)
        return (average - 1) / 4 * maxQualityPoints
    }

    /// Points every sale of this type loses for risks that come with it.
    static func saleTypePenalty(_ saleType: SaleType) -> Double {
        switch saleType {
        case .taxSale: return 3
        case .powerOfSale, .receivership, .auction: return 1
        case .estate, .surplus, .regular: return 0
        }
    }

    static func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    static func estimate(for analysis: DealAnalysis) -> ValueEstimate? {
        if let manual = analysis.estimatedValue, manual > 0 {
            return ValueEstimate(value: manual, method: .manual)
        }
        let sales = analysis.comparables.filter { $0.soldPrice > 0 }
        guard !sales.isEmpty else { return nil }
        if let size = analysis.size, size > 0 {
            let rates = sales.compactMap { sale -> Double? in
                guard let saleSize = sale.size, saleSize > 0 else { return nil }
                return sale.soldPrice / saleSize
            }
            if !rates.isEmpty {
                let rate = median(rates)
                return ValueEstimate(value: rate * size, method: .pricePerUnit(rate: rate, count: rates.count))
            }
        }
        return ValueEstimate(value: median(sales.map(\.soldPrice)), method: .medianPrice(count: sales.count))
    }

    static func rate(_ inputs: Inputs) -> DealRating {
        let landTransferTax = LandTransferTax.estimate(
            price: inputs.price,
            isHome: inputs.isHome,
            inToronto: inputs.inToronto,
            firstTimeBuyer: false
        ).total
        let allIn = inputs.price + landTransferTax + inputs.renovation + inputs.closing
        let value = inputs.estimate.value
        let discount = value > 0 ? (value - allIn) / value : -1

        let price = pricePoints(discount: discount)
        let quality = qualityPoints(ratings: inputs.ratings)

        var notes: [String] = []
        let typePenalty = saleTypePenalty(inputs.saleType)
        if typePenalty > 0 {
            notes.append("\(inputs.saleType.name): −\(Int(typePenalty))")
        }
        for risk in inputs.risks {
            notes.append("\(risk.name): −\(Int(RiskFactor.pointsEach))")
        }
        let penalty = typePenalty + Double(inputs.risks.count) * RiskFactor.pointsEach
        let risk = max(0, maxRiskPoints - penalty)

        let score = min(100, max(0, Int((price + quality + risk).rounded())))
        return DealRating(
            score: score,
            grade: DealGrade(score: score),
            pricePoints: price,
            qualityPoints: quality,
            riskPoints: risk,
            discount: discount,
            price: inputs.price,
            allInCost: allIn,
            estimate: inputs.estimate,
            ratedFactorCount: inputs.ratings.filter { (1...5).contains($0) }.count,
            riskNotes: notes
        )
    }

    /// Inputs for a saved property, rated at `price` or else the asking price (or the user's maximum).
    static func inputs(for property: Property, price: Double? = nil) -> Inputs? {
        let analysis = property.analysis
        guard let estimate = estimate(for: analysis),
              let price = price ?? property.askingPrice ?? property.maxPrice,
              price > 0
        else { return nil }
        return Inputs(
            price: price,
            estimate: estimate,
            renovation: analysis.renovationCost ?? 0,
            closing: analysis.closingCosts ?? defaultClosingCosts,
            isHome: property.kind.usesHomeLandTransferTax,
            inToronto: property.isInToronto,
            ratings: analysis.ratedStars,
            risks: analysis.activeRisks,
            saleType: property.saleType
        )
    }

    static func rate(_ property: Property, price: Double? = nil) -> DealRating? {
        inputs(for: property, price: price).map { rate($0) }
    }

    /// The highest price (rounded down to $1,000) that still earns `minimumScore`,
    /// or nil if even a free property wouldn't.
    static func highestPrice(for inputs: Inputs, minimumScore: Int) -> Double? {
        var probe = inputs
        probe.price = 0
        guard rate(probe).score >= minimumScore else { return nil }
        var low = 0.0
        var high = max(inputs.estimate.value * 2, 1_000)
        for _ in 0..<60 {
            let middle = (low + high) / 2
            probe.price = middle
            if rate(probe).score >= minimumScore {
                low = middle
            } else {
                high = middle
            }
        }
        return (low / 1_000).rounded(.down) * 1_000
    }

    /// Why a property can't be rated yet.
    static func missingInfoMessage(for property: Property) -> String {
        let hasPrice = (property.askingPrice ?? property.maxPrice ?? 0) > 0
        let hasValue = estimate(for: property.analysis) != nil
        switch (hasPrice, hasValue) {
        case (false, false): return "Add an asking price, then an estimated value or comparable sales, to rate this deal."
        case (false, true): return "Add an asking price (tap Edit) to rate this deal."
        default: return "Add an estimated value or comparable sales to rate this deal."
        }
    }
}
