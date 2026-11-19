import Foundation

/// Canadian fixed-rate mortgage math. Canadian mortgages compound semi-annually,
/// not monthly, so the monthly rate is (1 + annual/2)^(1/6) − 1.
enum Mortgage {
    static func monthlyRate(annualPercent: Double) -> Double {
        guard annualPercent > 0 else { return 0 }
        return pow(1 + annualPercent / 200, 2.0 / 12.0) - 1
    }

    static func monthlyPayment(principal: Double, annualPercent: Double, years: Double) -> Double {
        let months = years * 12
        guard principal > 0, months > 0 else { return 0 }
        let rate = monthlyRate(annualPercent: annualPercent)
        guard rate > 0 else { return principal / months }
        return principal * rate / (1 - pow(1 + rate, -months))
    }

    /// Interest paid over the first `months` payments.
    static func interestPaid(principal: Double, annualPercent: Double, years: Double, months: Int) -> Double {
        guard principal > 0, months > 0 else { return 0 }
        let rate = monthlyRate(annualPercent: annualPercent)
        let payment = monthlyPayment(principal: principal, annualPercent: annualPercent, years: years)
        var balance = principal
        var total = 0.0
        for _ in 0..<months {
            let interest = balance * rate
            total += interest
            balance = max(0, balance - (payment - interest))
        }
        return total
    }
}

/// Works backwards from what a property is worth to the most you should pay.
enum MaxOffer {
    static let defaultPropertyTaxRate = 0.01
    static let defaultInsuranceYearly = 2_000.0
    static let defaultUtilitiesMonthly = 300.0

    struct Inputs {
        var value: Double
        var renovation: Double
        var closing: Double
        var isHome: Bool
        var inToronto: Bool
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

        var targetProfit: Double {
            value * max(targetProfitPercent, 0) / 100
        }
    }

    struct Outcome: Equatable {
        let value: Double
        let price: Double
        let landTransferTax: Double
        let closing: Double
        let renovation: Double
        let interest: Double
        let propertyTax: Double
        let insurance: Double
        let utilities: Double
        let sellingCosts: Double
        let downPayment: Double

        var carrying: Double {
            interest + propertyTax + insurance + utilities
        }

        var totalCost: Double {
            price + landTransferTax + closing + renovation + carrying + sellingCosts
        }

        var profit: Double {
            value - totalCost
        }

        /// Money you need before any sale: down payment plus everything not financed.
        var cashNeeded: Double {
            downPayment + landTransferTax + closing + renovation + carrying
        }
    }

    static func outcome(price: Double, inputs: Inputs) -> Outcome {
        let months = max(inputs.holdingMonths, 0)
        let downFraction = min(max(inputs.downPaymentPercent, 0), 100) / 100
        let loan = price * (1 - downFraction)
        let ltt = LandTransferTax.estimate(
            price: price,
            isHome: inputs.isHome,
            inToronto: inputs.inToronto,
            firstTimeBuyer: false
        ).total
        let yearFraction = Double(months) / 12
        return Outcome(
            value: inputs.value,
            price: price,
            landTransferTax: ltt,
            closing: inputs.closing,
            renovation: inputs.renovation,
            interest: Mortgage.interestPaid(
                principal: loan,
                annualPercent: inputs.interestRate,
                years: inputs.amortizationYears,
                months: months
            ),
            propertyTax: (inputs.propertyTaxYearly ?? price * defaultPropertyTaxRate) * yearFraction,
            insurance: (inputs.insuranceYearly ?? defaultInsuranceYearly) * yearFraction,
            utilities: (inputs.utilitiesMonthly ?? defaultUtilitiesMonthly) * Double(months),
            sellingCosts: inputs.resell ? inputs.value * max(inputs.sellingCostPercent, 0) / 100 : 0,
            downPayment: price * downFraction
        )
    }

    /// The highest price (rounded down to $1,000) that still reaches the profit target,
    /// or nil if the target can't be reached even at $0.
    static func maximumOffer(_ inputs: Inputs) -> Outcome? {
        guard inputs.value > 0 else { return nil }
        let target = inputs.targetProfit
        guard outcome(price: 0, inputs: inputs).profit >= target else { return nil }
        var low = 0.0
        var high = inputs.value * 2
        for _ in 0..<60 {
            let middle = (low + high) / 2
            if outcome(price: middle, inputs: inputs).profit >= target {
                low = middle
            } else {
                high = middle
            }
        }
        return outcome(price: (low / 1_000).rounded(.down) * 1_000, inputs: inputs)
    }

    static func inputs(analysis: DealAnalysis, isHome: Bool, inToronto: Bool) -> Inputs? {
        guard let estimate = DealRater.estimate(for: analysis) else { return nil }
        return Inputs(
            value: estimate.value,
            renovation: analysis.renovationCost ?? 0,
            closing: analysis.closingCosts ?? DealRater.defaultClosingCosts,
            isHome: isHome,
            inToronto: inToronto,
            resell: analysis.resell,
            holdingMonths: analysis.holdingMonths,
            interestRate: analysis.interestRate,
            downPaymentPercent: analysis.downPaymentPercent,
            amortizationYears: analysis.amortizationYears,
            propertyTaxYearly: analysis.propertyTaxYearly,
            insuranceYearly: analysis.insuranceYearly,
            utilitiesMonthly: analysis.utilitiesMonthly,
            sellingCostPercent: analysis.sellingCostPercent,
            targetProfitPercent: analysis.targetProfitPercent
        )
    }

    static func inputs(for property: Property) -> Inputs? {
        inputs(analysis: property.analysis, isHome: property.kind.usesHomeLandTransferTax, inToronto: property.isInToronto)
    }
}
