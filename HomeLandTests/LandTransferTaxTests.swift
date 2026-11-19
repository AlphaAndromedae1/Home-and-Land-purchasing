import XCTest
@testable import HomeLand

final class LandTransferTaxTests: XCTestCase {
    func testOntarioHomeAt500k() {
        let estimate = LandTransferTax.estimate(price: 500_000, isHome: true, inToronto: false, firstTimeBuyer: false)
        XCTAssertEqual(estimate.ontario, 6_475, accuracy: 0.01)
        XCTAssertEqual(estimate.toronto, 0)
        XCTAssertEqual(estimate.total, 6_475, accuracy: 0.01)
    }

    func testOntarioHomeAt1M() {
        let estimate = LandTransferTax.estimate(price: 1_000_000, isHome: true, inToronto: false, firstTimeBuyer: false)
        XCTAssertEqual(estimate.ontario, 16_475, accuracy: 0.01)
    }

    func testTopOntarioBracketOnlyAppliesToHomes() {
        let home = LandTransferTax.estimate(price: 2_500_000, isHome: true, inToronto: false, firstTimeBuyer: false)
        let land = LandTransferTax.estimate(price: 2_500_000, isHome: false, inToronto: false, firstTimeBuyer: false)
        XCTAssertEqual(home.ontario, 48_975, accuracy: 0.01)
        XCTAssertEqual(land.ontario, 46_475, accuracy: 0.01)
    }

    func testTorontoLuxuryBrackets() {
        let estimate = LandTransferTax.estimate(price: 3_500_000, isHome: true, inToronto: true, firstTimeBuyer: false)
        XCTAssertEqual(estimate.ontario, 73_975, accuracy: 0.01)
        XCTAssertEqual(estimate.toronto, 78_975, accuracy: 0.01)
        XCTAssertEqual(estimate.total, 152_950, accuracy: 0.01)
    }

    func testFirstTimeBuyerRefundsAreCapped() {
        let estimate = LandTransferTax.estimate(price: 500_000, isHome: true, inToronto: true, firstTimeBuyer: true)
        XCTAssertEqual(estimate.ontarioRefund, 4_000, accuracy: 0.01)
        XCTAssertEqual(estimate.torontoRebate, 4_475, accuracy: 0.01)
        XCTAssertEqual(estimate.total, 4_475, accuracy: 0.01)
    }

    func testFirstTimeRefundNeverExceedsTax() {
        let estimate = LandTransferTax.estimate(price: 300_000, isHome: true, inToronto: false, firstTimeBuyer: true)
        XCTAssertEqual(estimate.ontario, 2_975, accuracy: 0.01)
        XCTAssertEqual(estimate.ontarioRefund, 2_975, accuracy: 0.01)
        XCTAssertEqual(estimate.total, 0, accuracy: 0.01)
    }

    func testNoFirstTimeRefundForLand() {
        let estimate = LandTransferTax.estimate(price: 200_000, isHome: false, inToronto: false, firstTimeBuyer: true)
        XCTAssertEqual(estimate.ontarioRefund, 0)
        XCTAssertEqual(estimate.total, estimate.ontario)
    }

    func testZeroPriceHasNoTax() {
        XCTAssertEqual(LandTransferTax.estimate(price: 0, isHome: true, inToronto: true, firstTimeBuyer: false).total, 0)
    }

    func testTaxSaleTenderBreakdown() {
        let breakdown = TaxSaleTender.breakdown(tender: 50_000, minimum: 12_000, isHome: false, hstApplies: true)
        XCTAssertEqual(breakdown.deposit, 10_000, accuracy: 0.01)
        XCTAssertEqual(breakdown.balance, 40_000, accuracy: 0.01)
        XCTAssertEqual(breakdown.landTransferTax, 250, accuracy: 0.01)
        XCTAssertEqual(breakdown.hst, 6_500, accuracy: 0.01)
        XCTAssertEqual(breakdown.totalDue, 56_750, accuracy: 0.01)
        XCTAssertFalse(breakdown.isBelowMinimum)
    }

    func testTenderBelowMinimumIsFlagged() {
        let breakdown = TaxSaleTender.breakdown(tender: 9_000, minimum: 12_000, isHome: false, hstApplies: false)
        XCTAssertTrue(breakdown.isBelowMinimum)
        XCTAssertEqual(breakdown.hst, 0)
    }
}
