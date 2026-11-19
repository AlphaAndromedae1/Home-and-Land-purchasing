import XCTest
@testable import HomeLand

final class DealRaterTests: XCTestCase {
    private func inputs(
        price: Double,
        value: Double,
        renovation: Double = 0,
        ratings: [Int] = [],
        risks: [RiskFactor] = [],
        saleType: SaleType = .regular
    ) -> DealRater.Inputs {
        DealRater.Inputs(
            price: price,
            estimate: ValueEstimate(value: value, method: .manual),
            renovation: renovation,
            closing: 2_500,
            isHome: true,
            inToronto: false,
            ratings: ratings,
            risks: risks,
            saleType: saleType
        )
    }

    func testPricePointsCurve() {
        XCTAssertEqual(DealRater.pricePoints(discount: -0.5), 0)
        XCTAssertEqual(DealRater.pricePoints(discount: -0.2), 0)
        XCTAssertEqual(DealRater.pricePoints(discount: -0.1), 15, accuracy: 0.001)
        XCTAssertEqual(DealRater.pricePoints(discount: 0), 30, accuracy: 0.001)
        XCTAssertEqual(DealRater.pricePoints(discount: 0.15), 45, accuracy: 0.001)
        XCTAssertEqual(DealRater.pricePoints(discount: 0.3), 60)
        XCTAssertEqual(DealRater.pricePoints(discount: 0.6), 60)
    }

    func testQualityPoints() {
        XCTAssertEqual(DealRater.qualityPoints(ratings: []), 12.5)
        XCTAssertEqual(DealRater.qualityPoints(ratings: [5, 5]), 25)
        XCTAssertEqual(DealRater.qualityPoints(ratings: [1]), 0)
        XCTAssertEqual(DealRater.qualityPoints(ratings: [3]), 12.5)
        XCTAssertEqual(DealRater.qualityPoints(ratings: [0, 9]), 12.5)
    }

    func testSlightlyUnderValueIsFair() {
        let rating = DealRater.rate(inputs(price: 470_000, value: 500_000))
        XCTAssertEqual(rating.allInCost, 478_375, accuracy: 0.01)
        XCTAssertEqual(rating.score, 62)
        XCTAssertEqual(rating.grade, .fair)
        XCTAssertTrue(rating.headline.contains("4% below"), rating.headline)
    }

    func testBigDiscountWithGoodQualityIsExcellent() {
        let rating = DealRater.rate(inputs(price: 300_000, value: 500_000, ratings: [4, 4, 5, 4]))
        XCTAssertEqual(rating.score, 95)
        XCTAssertEqual(rating.grade, .excellent)
        XCTAssertEqual(rating.grade.stars, 5)
    }

    func testOverpricedIsPoor() {
        let rating = DealRater.rate(inputs(price: 480_000, value: 400_000))
        XCTAssertEqual(rating.pricePoints, 0)
        XCTAssertEqual(rating.grade, .poor)
        XCTAssertTrue(rating.headline.contains("above"), rating.headline)
    }

    func testRisksAndSaleTypeLowerTheScore() {
        let clean = DealRater.rate(inputs(price: 470_000, value: 500_000))
        let risky = DealRater.rate(inputs(price: 470_000, value: 500_000, risks: [.noInspection, .title], saleType: .taxSale))
        XCTAssertEqual(risky.riskPoints, 6, accuracy: 0.001)
        XCTAssertEqual(clean.score - risky.score, 9)
        XCTAssertEqual(risky.riskNotes.count, 3)
    }

    func testHighestPriceForGoodDeal() throws {
        let base = inputs(price: 0, value: 500_000)
        let price = try XCTUnwrap(DealRater.highestPrice(for: base, minimumScore: DealGrade.good.minimumScore))
        var atPrice = base
        atPrice.price = price
        var above = base
        above.price = price + 1_000
        XCTAssertGreaterThanOrEqual(DealRater.rate(atPrice).score, 65)
        XCTAssertLessThan(DealRater.rate(above).score, 65)
    }

    func testNoPriceIsGoodEnoughWhenCostsExceedValue() {
        let base = inputs(price: 0, value: 50_000, renovation: 200_000)
        XCTAssertNil(DealRater.highestPrice(for: base, minimumScore: 65))
    }

    func testEstimateFromPricePerSquareFoot() throws {
        var analysis = DealAnalysis(size: 1_800)
        analysis.comparables = [
            ComparableSale(soldPrice: 600_000, size: 2_000),
            ComparableSale(soldPrice: 650_000, size: 2_500),
            ComparableSale(soldPrice: 700_000, size: 2_000),
        ]
        let estimate = try XCTUnwrap(DealRater.estimate(for: analysis))
        XCTAssertEqual(estimate.value, 540_000, accuracy: 0.01)
        XCTAssertEqual(estimate.method, .pricePerUnit(rate: 300, count: 3))
    }

    func testEstimateFallsBackToMedianPrice() {
        var analysis = DealAnalysis()
        analysis.comparables = [
            ComparableSale(soldPrice: 600_000),
            ComparableSale(soldPrice: 700_000),
            ComparableSale(soldPrice: 650_000),
            ComparableSale(soldPrice: 0),
        ]
        XCTAssertEqual(DealRater.estimate(for: analysis)?.value, 650_000)
        XCTAssertEqual(DealRater.estimate(for: analysis)?.method, .medianPrice(count: 3))
    }

    func testManualValueWins() {
        var analysis = DealAnalysis(estimatedValue: 800_000)
        analysis.comparables = [ComparableSale(soldPrice: 600_000)]
        XCTAssertEqual(DealRater.estimate(for: analysis)?.value, 800_000)
        XCTAssertEqual(DealRater.estimate(for: analysis)?.method, .manual)
    }

    func testEvenMedian() {
        XCTAssertEqual(DealRater.median([4, 1, 3, 2]), 2.5)
        XCTAssertEqual(DealRater.median([]), 0)
    }

    func testRatingAPropertyUsesItsAnalysis() {
        var property = Property(saleType: .powerOfSale, kind: .house, askingPrice: 470_000)
        XCTAssertNil(DealRater.rate(property))
        property.analysis.estimatedValue = 500_000
        XCTAssertEqual(DealRater.rate(property)?.score, 61)
        property.analysis.setRating(5, for: .location)
        property.analysis.setRisk(.occupants, true)
        XCTAssertEqual(DealRater.rate(property)?.ratedFactorCount, 1)
        XCTAssertEqual(DealRater.rate(property)?.riskPoints ?? -1, 11, accuracy: 0.001)
    }

    func testGradeBoundaries() {
        XCTAssertEqual(DealGrade(score: 80), .excellent)
        XCTAssertEqual(DealGrade(score: 79), .good)
        XCTAssertEqual(DealGrade(score: 65), .good)
        XCTAssertEqual(DealGrade(score: 50), .fair)
        XCTAssertEqual(DealGrade(score: 35), .belowAverage)
        XCTAssertEqual(DealGrade(score: 34), .poor)
    }
}

final class FinancingTests: XCTestCase {
    private func inputs(resell: Bool = true, value: Double = 600_000, renovation: Double = 50_000) -> MaxOffer.Inputs {
        MaxOffer.Inputs(
            value: value,
            renovation: renovation,
            closing: 2_500,
            isHome: true,
            inToronto: false,
            resell: resell,
            holdingMonths: 6,
            interestRate: 6,
            downPaymentPercent: 20,
            amortizationYears: 25,
            propertyTaxYearly: nil,
            insuranceYearly: nil,
            utilitiesMonthly: nil,
            sellingCostPercent: 5,
            targetProfitPercent: 10
        )
    }

    func testCanadianMortgagePayment() {
        XCTAssertEqual(Mortgage.monthlyPayment(principal: 400_000, annualPercent: 5, years: 25), 2_326.42, accuracy: 0.01)
        XCTAssertEqual(Mortgage.monthlyPayment(principal: 500_000, annualPercent: 4.5, years: 30), 2_521.08, accuracy: 0.01)
    }

    func testInterestInFirstYear() {
        XCTAssertEqual(Mortgage.interestPaid(principal: 400_000, annualPercent: 5, years: 25, months: 12), 19_608.01, accuracy: 0.05)
    }

    func testZeroRate() {
        XCTAssertEqual(Mortgage.monthlyPayment(principal: 120_000, annualPercent: 0, years: 10), 1_000, accuracy: 0.001)
        XCTAssertEqual(Mortgage.interestPaid(principal: 120_000, annualPercent: 0, years: 10, months: 12), 0)
    }

    func testMaximumOfferHitsTarget() throws {
        let inputs = inputs()
        let best = try XCTUnwrap(MaxOffer.maximumOffer(inputs))
        XCTAssertGreaterThanOrEqual(best.profit, inputs.targetProfit - 0.01)
        XCTAssertLessThan(MaxOffer.outcome(price: best.price + 1_000, inputs: inputs).profit, inputs.targetProfit)
        XCTAssertEqual(best.price.truncatingRemainder(dividingBy: 1_000), 0)
        XCTAssertEqual(best.sellingCosts, 30_000, accuracy: 0.01)
        XCTAssertGreaterThan(best.price, 400_000)
        XCTAssertLessThan(best.price, 460_000)
    }

    func testKeepingSkipsSellingCostsAndAllowsAHigherOffer() throws {
        let resell = try XCTUnwrap(MaxOffer.maximumOffer(inputs(resell: true)))
        let keep = try XCTUnwrap(MaxOffer.maximumOffer(inputs(resell: false)))
        XCTAssertEqual(keep.sellingCosts, 0)
        XCTAssertGreaterThan(keep.price, resell.price)
    }

    func testImpossibleTargetHasNoMaximumOffer() {
        XCTAssertNil(MaxOffer.maximumOffer(inputs(value: 100_000, renovation: 200_000)))
    }

    func testCashNeededIncludesDownPaymentAndCosts() {
        let outcome = MaxOffer.outcome(price: 400_000, inputs: inputs())
        XCTAssertEqual(outcome.downPayment, 80_000, accuracy: 0.01)
        XCTAssertEqual(outcome.cashNeeded, 80_000 + outcome.landTransferTax + 2_500 + 50_000 + outcome.carrying, accuracy: 0.01)
        XCTAssertEqual(outcome.propertyTax, 2_000, accuracy: 0.01)
        XCTAssertEqual(outcome.insurance, 1_000, accuracy: 0.01)
        XCTAssertEqual(outcome.utilities, 1_800, accuracy: 0.01)
    }
}

final class DeadlineReminderTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testRemindersBeforeDeadline() {
        let property = Property(title: "Lot 5", saleType: .taxSale, deadline: date(2026, 1, 20, 15))
        let reminders = DeadlineReminders.reminders(for: [property], now: date(2026, 1, 1, 12), calendar: calendar)
        XCTAssertEqual(reminders.map(\.date), [
            date(2026, 1, 13, 9),
            date(2026, 1, 17, 9),
            date(2026, 1, 19, 9),
            date(2026, 1, 20, 13),
        ])
        XCTAssertEqual(reminders.first?.title, "Tender closes in 7 days")
        XCTAssertEqual(reminders[2].title, "Tender closes tomorrow")
        XCTAssertEqual(reminders.last?.title, "Tender closes in 2 hours")
        XCTAssertEqual(Set(reminders.map(\.id)).count, 4)
        XCTAssertTrue(reminders.allSatisfy { $0.id.hasPrefix(DeadlineReminders.identifierPrefix) })
    }

    func testSkipsPastTimesClosedPropertiesAndMissingDeadlines() {
        let soon = Property(title: "Soon", deadline: date(2026, 1, 3, 15))
        let closed = Property(title: "Closed", status: .passed, deadline: date(2026, 1, 20, 15))
        let past = Property(title: "Past", deadline: date(2025, 12, 1, 15))
        let none = Property(title: "None")
        let reminders = DeadlineReminders.reminders(for: [soon, closed, past, none], now: date(2026, 1, 1, 12), calendar: calendar)
        XCTAssertEqual(reminders.map(\.date), [date(2026, 1, 2, 9), date(2026, 1, 3, 13)])
        XCTAssertEqual(reminders.first?.title, "Offer deadline tomorrow")
    }
}

final class ContactTests: XCTestCase {
    func testPhoneAndEmailLinks() {
        let contact = PropertyContact(name: "Pat", phone: "(416) 555-0199", email: " pat@example.com ")
        XCTAssertEqual(contact.phoneURL?.absoluteString, "tel:4165550199")
        XCTAssertEqual(contact.smsURL?.absoluteString, "sms:4165550199")
        XCTAssertEqual(contact.emailURL?.absoluteString, "mailto:pat@example.com")
    }

    func testIncompleteDetailsGiveNoLinks() {
        let contact = PropertyContact(phone: "123", email: "not an email")
        XCTAssertNil(contact.phoneURL)
        XCTAssertNil(contact.emailURL)
        XCTAssertTrue(PropertyContact().isEmpty)
    }

    func testDisplayNames() {
        XCTAssertEqual(PropertyContact(role: .lawyer).displayName, "Lawyer")
        XCTAssertEqual(PropertyContact(role: .receiver, company: "KSV").displayName, "KSV")
        XCTAssertEqual(PropertyContact(role: .lawyer, name: "Pat", company: "Smith LLP").subtitle, "Lawyer · Smith LLP")
        XCTAssertEqual(ContactRole.suggested(for: .taxSale), .municipality)
    }
}
