import Foundation

struct ChecklistItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
}

struct ChecklistGroup: Identifiable {
    let id: String
    let title: String
    let items: [ChecklistItem]
}

/// Due-diligence checklists that adapt to the sale type and kind of property.
enum Checklist {
    static func groups(saleType: SaleType, kind: PropertyKind) -> [ChecklistGroup] {
        var groups = [ChecklistGroup(id: "core", title: "Research", items: core)]

        switch saleType {
        case .powerOfSale:
            groups.append(ChecklistGroup(id: "pos", title: "Power of sale", items: powerOfSale))
        case .taxSale:
            groups.append(ChecklistGroup(id: "tax", title: "Tax sale tender", items: taxSale))
        case .receivership:
            groups.append(ChecklistGroup(id: "rcv", title: "Receivership sale", items: receivership))
        case .estate:
            groups.append(ChecklistGroup(id: "est", title: "Estate sale", items: estate))
        case .surplus:
            groups.append(ChecklistGroup(id: "gov", title: "Government surplus", items: surplus))
        case .auction:
            groups.append(ChecklistGroup(id: "auc", title: "Auction", items: auction))
        case .regular:
            break
        }

        switch kind {
        case .house:
            groups.append(ChecklistGroup(id: "home", title: "House", items: house))
        case .condo:
            groups.append(ChecklistGroup(id: "condo", title: "Condo", items: condo))
        case .commercial:
            groups.append(ChecklistGroup(id: "com", title: "Commercial", items: commercial))
        case .vacantLand, .farm, .cottage:
            groups.append(ChecklistGroup(id: "land", title: "Land", items: land))
        case .development:
            groups.append(ChecklistGroup(id: "land", title: "Land", items: land))
            groups.append(ChecklistGroup(id: "dev", title: "Development", items: development))
        }

        return groups
    }

    static let core: [ChecklistItem] = [
        .init(id: "core.title", title: "Pull the title on OnLand",
              detail: "See the owner, mortgages, liens and easements registered on the property."),
        .init(id: "core.solds", title: "Compare recent sales nearby",
              detail: "Check sold prices on HouseSigma or MPAC to judge the price."),
        .init(id: "core.zoning", title: "Confirm zoning and official plan",
              detail: "Use the municipal or county GIS map, or call the planning department."),
        .init(id: "core.conservation", title: "Check conservation authority mapping",
              detail: "Floodplains and regulated areas can limit what you can build."),
        .init(id: "core.taxes", title: "Confirm property taxes and arrears",
              detail: "Ask the municipality for a tax certificate."),
        .init(id: "core.financing", title: "Have financing ready",
              detail: "Get pre-approved so you can make a firm offer quickly."),
        .init(id: "core.insurance", title: "Get an insurance quote",
              detail: "Vacant, older or rural properties can be hard to insure."),
        .init(id: "core.lawyer", title: "Have a lawyer review it",
              detail: "An Ontario real estate lawyer should review the offer or tender before you commit."),
    ]

    static let powerOfSale: [ChecklistItem] = [
        .init(id: "pos.schedule", title: "Read the lender's schedule",
              detail: "Expect “as is, where is”, no warranties and short deadlines."),
        .init(id: "pos.inspection", title: "Inspect before you offer",
              detail: "Lenders usually want firm offers without conditions."),
        .init(id: "pos.tenants", title: "Ask about tenants",
              detail: "A lawful tenancy continues after a power of sale."),
        .init(id: "pos.redemption", title: "Understand redemption risk",
              detail: "If the owner pays what's owed before closing, the lender can cancel your deal."),
        .init(id: "pos.offers", title: "Ask about the offer date",
              detail: "Find out whether offers are being held or other offers are registered."),
    ]

    static let taxSale: [ChecklistItem] = [
        .init(id: "tax.package", title: "Get the tender package",
              detail: "Legal description, PIN, minimum tender amount and closing time from the municipality."),
        .init(id: "tax.deposit", title: "Prepare a 20% deposit",
              detail: "Certified cheque, bank draft or money order for at least 20% of your tender."),
        .init(id: "tax.balance", title: "Line up the balance",
              detail: "The balance, land transfer tax, any HST and accumulated taxes are usually due within 14 days."),
        .init(id: "tax.access", title: "Confirm legal road access",
              detail: "Watch for landlocked lots, narrow reserves and unopened road allowances."),
        .init(id: "tax.drive", title: "Drive by the property",
              detail: "Look for occupants, buildings, debris or signs of contamination."),
        .init(id: "tax.liens", title: "Ask about interests that survive",
              detail: "Some Crown liens and easements stay with the land after a tax sale."),
        .init(id: "tax.form", title: "Submit on the prescribed form",
              detail: "Use the municipality's tender form and envelope. Late tenders are rejected."),
    ]

    static let receivership: [ChecklistItem] = [
        .init(id: "rcv.process", title: "Read the sale process order",
              detail: "Bid deadlines, deposits and any stalking-horse bid are on the receiver's case page."),
        .init(id: "rcv.dataroom", title: "Review the data room",
              detail: "Appraisals, environmental and building reports are often available after you sign an NDA."),
        .init(id: "rcv.approval", title: "Plan for court approval",
              detail: "Closing needs an approval and vesting order from the court, which can take weeks."),
    ]

    static let estate: [ChecklistItem] = [
        .init(id: "est.probate", title: "Confirm the trustee's authority",
              detail: "Ask whether there's a Certificate of Appointment of Estate Trustee, or why one isn't needed."),
        .init(id: "est.condition", title: "Budget for updates",
              detail: "Estate homes often need repairs, and the trustee may know little about the property."),
    ]

    static let surplus: [ChecklistItem] = [
        .init(id: "gov.eligibility", title: "Check who gets first chance",
              detail: "Public bodies and eligible non-profits may be offered surplus property first."),
        .init(id: "gov.process", title: "Follow the sale process",
              detail: "Note the bid format, deposit and closing deadlines."),
        .init(id: "gov.reports", title: "Ask for reports",
              detail: "Environmental, survey and heritage information may be available."),
    ]

    static let auction: [ChecklistItem] = [
        .init(id: "auc.terms", title: "Read the auction terms",
              detail: "Deposit, buyer's premium, closing date and whether there's a reserve price."),
        .init(id: "auc.register", title: "Register to bid",
              detail: "Some auctions need proof of funds before bidding."),
        .init(id: "auc.limit", title: "Set your walk-away price",
              detail: "Decide your maximum, including closing costs, before the auction starts."),
    ]

    static let house: [ChecklistItem] = [
        .init(id: "home.units", title: "Check additional unit potential",
              detail: "On most lots with town water and sewer, Ontario allows up to three units. Confirm local zoning."),
        .init(id: "home.vacancy", title: "Plan for vacant home taxes",
              detail: "Some cities, including Toronto and Ottawa, tax homes left empty during long renovations."),
    ]

    static let condo: [ChecklistItem] = [
        .init(id: "condo.status", title: "Review the status certificate",
              detail: "Have your lawyer check for special assessments, lawsuits and the reserve fund."),
        .init(id: "home.vacancy", title: "Plan for vacant home taxes",
              detail: "Some cities, including Toronto and Ottawa, tax homes left empty."),
    ]

    static let commercial: [ChecklistItem] = [
        .init(id: "com.environmental", title: "Order a Phase I environmental assessment",
              detail: "Lenders usually require one for commercial property."),
        .init(id: "com.leases", title: "Review leases and rent roll",
              detail: "Existing tenants and lease terms carry over to you."),
        .init(id: "com.hst", title: "Confirm HST treatment",
              detail: "HST usually applies to commercial property. Ask your lawyer or accountant."),
    ]

    static let land: [ChecklistItem] = [
        .init(id: "land.road", title: "Confirm year-round road access",
              detail: "A municipally maintained road, not a seasonal, private or unopened road allowance."),
        .init(id: "land.septic", title: "Check septic feasibility",
              detail: "Ask the building department or septic authority what approval needs."),
        .init(id: "land.well", title: "Check well and water",
              detail: "Look up nearby well depths and yields on Ontario's well records map."),
        .init(id: "land.plans", title: "Check Greenbelt, Oak Ridges Moraine and Escarpment rules",
              detail: "Provincial plans can heavily restrict building and severances."),
        .init(id: "land.farmland", title: "Check for prime farmland",
              detail: "Severances are very hard to get on prime agricultural land."),
        .init(id: "land.build", title: "Confirm you can build",
              detail: "Ask planning staff whether a home can be built on the lot."),
        .init(id: "land.hst", title: "Ask whether HST applies",
              detail: "HST can apply to vacant land, especially when the seller is a business."),
        .init(id: "land.down", title: "Plan a bigger down payment",
              detail: "Vacant land often needs 25–50% down, and mortgage insurance doesn't cover it."),
    ]

    static let development: [ChecklistItem] = [
        .init(id: "dev.approvals", title: "Check planning approvals",
              detail: "Draft plan, site plan and zoning approvals, and when they expire."),
        .init(id: "dev.servicing", title: "Confirm servicing capacity",
              detail: "Water and sewer allocation can limit how many units you can build."),
        .init(id: "dev.charges", title: "Estimate development charges",
              detail: "Municipal and regional charges can add a lot per unit."),
    ]
}
