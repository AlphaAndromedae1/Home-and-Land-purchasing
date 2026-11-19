import Foundation

struct TaxBracket {
    /// Upper limit of this bracket; `nil` means no limit.
    let upTo: Double?
    let rate: Double
}

/// Ontario and City of Toronto land transfer tax estimates.
///
/// Rates are marginal, like income tax brackets. Confirm current rates with a
/// lawyer before relying on them.
enum LandTransferTax {
    /// Ontario rates for land with one or two single-family residences.
    static let ontarioHome: [TaxBracket] = [
        TaxBracket(upTo: 55_000, rate: 0.005),
        TaxBracket(upTo: 250_000, rate: 0.01),
        TaxBracket(upTo: 400_000, rate: 0.015),
        TaxBracket(upTo: 2_000_000, rate: 0.02),
        TaxBracket(upTo: nil, rate: 0.025),
    ]

    /// Ontario rates for everything else, such as vacant land and commercial property.
    static let ontarioOther: [TaxBracket] = [
        TaxBracket(upTo: 55_000, rate: 0.005),
        TaxBracket(upTo: 250_000, rate: 0.01),
        TaxBracket(upTo: 400_000, rate: 0.015),
        TaxBracket(upTo: nil, rate: 0.02),
    ]

    /// Toronto municipal rates for land with one or two single-family residences.
    static let torontoHome: [TaxBracket] = [
        TaxBracket(upTo: 55_000, rate: 0.005),
        TaxBracket(upTo: 250_000, rate: 0.01),
        TaxBracket(upTo: 400_000, rate: 0.015),
        TaxBracket(upTo: 2_000_000, rate: 0.02),
        TaxBracket(upTo: 3_000_000, rate: 0.025),
        TaxBracket(upTo: 4_000_000, rate: 0.035),
        TaxBracket(upTo: 5_000_000, rate: 0.045),
        TaxBracket(upTo: 10_000_000, rate: 0.055),
        TaxBracket(upTo: 20_000_000, rate: 0.065),
        TaxBracket(upTo: nil, rate: 0.075),
    ]

    /// Toronto municipal rates for other property.
    static let torontoOther: [TaxBracket] = [
        TaxBracket(upTo: 55_000, rate: 0.005),
        TaxBracket(upTo: 250_000, rate: 0.01),
        TaxBracket(upTo: 400_000, rate: 0.015),
        TaxBracket(upTo: 40_000_000, rate: 0.02),
        TaxBracket(upTo: nil, rate: 0.01),
    ]

    static let ontarioFirstTimeRefundMax: Double = 4_000
    static let torontoFirstTimeRebateMax: Double = 4_475

    struct Estimate: Equatable {
        var ontario: Double
        var ontarioRefund: Double
        var toronto: Double
        var torontoRebate: Double

        var total: Double {
            ontario - ontarioRefund + toronto - torontoRebate
        }
    }

    static func tax(on price: Double, brackets: [TaxBracket]) -> Double {
        guard price > 0 else { return 0 }
        var total = 0.0
        var lower = 0.0
        for bracket in brackets {
            guard price > lower else { break }
            let upper = bracket.upTo ?? .greatestFiniteMagnitude
            total += (min(price, upper) - lower) * bracket.rate
            lower = upper
        }
        return (total * 100).rounded() / 100
    }

    static func estimate(price: Double, isHome: Bool, inToronto: Bool, firstTimeBuyer: Bool) -> Estimate {
        let ontario = tax(on: price, brackets: isHome ? ontarioHome : ontarioOther)
        let ontarioRefund = (isHome && firstTimeBuyer) ? min(ontario, ontarioFirstTimeRefundMax) : 0
        let toronto = inToronto ? tax(on: price, brackets: isHome ? torontoHome : torontoOther) : 0
        let torontoRebate = (inToronto && isHome && firstTimeBuyer) ? min(toronto, torontoFirstTimeRebateMax) : 0
        return Estimate(ontario: ontario, ontarioRefund: ontarioRefund, toronto: toronto, torontoRebate: torontoRebate)
    }
}

/// Ontario tax sale tender math.
enum TaxSaleTender {
    static let depositRate = 0.20
    static let hstRate = 0.13

    struct Breakdown: Equatable {
        var tender: Double
        var deposit: Double
        var balance: Double
        var landTransferTax: Double
        var hst: Double
        var isBelowMinimum: Bool

        /// Everything due to the municipality and the province, before legal fees.
        var totalDue: Double {
            tender + landTransferTax + hst
        }
    }

    static func breakdown(tender: Double, minimum: Double?, isHome: Bool, hstApplies: Bool) -> Breakdown {
        let deposit = (tender * depositRate * 100).rounded() / 100
        let ltt = LandTransferTax.estimate(price: tender, isHome: isHome, inToronto: false, firstTimeBuyer: false).total
        let hst = hstApplies ? (tender * hstRate * 100).rounded() / 100 : 0
        let isBelow = minimum.map { tender < $0 } ?? false
        return Breakdown(
            tender: tender,
            deposit: deposit,
            balance: tender - deposit,
            landTransferTax: ltt,
            hst: hst,
            isBelowMinimum: isBelow
        )
    }
}
