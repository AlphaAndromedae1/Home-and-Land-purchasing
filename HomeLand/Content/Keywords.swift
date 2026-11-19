import Foundation

struct SearchKeyword: Identifiable, Hashable {
    let term: String
    let meaning: String

    var id: String { term }
}

/// Words that show up in listing remarks for distressed sales and land.
enum Keywords {
    static let distressed: [SearchKeyword] = [
        SearchKeyword(term: "power of sale", meaning: "The lender is selling after a mortgage default."),
        SearchKeyword(term: "POS", meaning: "Short form of power of sale in listing remarks."),
        SearchKeyword(term: "bank sale", meaning: "Often means a power of sale."),
        SearchKeyword(term: "mortgagee sale", meaning: "The lender (mortgagee) is the seller."),
        SearchKeyword(term: "sold as is", meaning: "No warranties. Common with lenders, estates and receivers."),
        SearchKeyword(term: "court appointed receiver", meaning: "A receiver is selling under a court order."),
        SearchKeyword(term: "subject to court approval", meaning: "The court must approve the sale before closing."),
        SearchKeyword(term: "estate sale", meaning: "An estate trustee is selling. Often motivated."),
        SearchKeyword(term: "estate trustee", meaning: "Another way estate sales are described."),
        SearchKeyword(term: "Certificate of Appointment", meaning: "Ontario's probate document. Signals an estate sale."),
        SearchKeyword(term: "contractor special", meaning: "Needs major work. Priced for renovators."),
        SearchKeyword(term: "handyman special", meaning: "Needs work. Priced for renovators."),
        SearchKeyword(term: "needs TLC", meaning: "Needs updating."),
        SearchKeyword(term: "bring an offer", meaning: "The seller is open to lower offers."),
        SearchKeyword(term: "motivated seller", meaning: "The seller wants a quick sale."),
        SearchKeyword(term: "assignment", meaning: "Resale of a pre-construction contract. Some are distressed."),
    ]

    static let land: [SearchKeyword] = [
        SearchKeyword(term: "vacant land", meaning: "Land with no house."),
        SearchKeyword(term: "building lot", meaning: "A lot meant for building a home."),
        SearchKeyword(term: "severance", meaning: "The lot can be, or was, split from a larger parcel."),
        SearchKeyword(term: "acreage", meaning: "Larger rural parcels."),
        SearchKeyword(term: "hobby farm", meaning: "Small farm with a house."),
        SearchKeyword(term: "development land", meaning: "Land for building several homes or more."),
        SearchKeyword(term: "draft plan approved", meaning: "A subdivision plan has draft approval."),
    ]

    static var all: [SearchKeyword] {
        distressed + land
    }
}
