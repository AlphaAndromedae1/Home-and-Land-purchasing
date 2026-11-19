import Foundation

enum GuideBlock: Hashable {
    case text(String)
    case bullets([String])
    case steps([String])
    case tip(String)
    case warning(String)
    /// Shown as one card per row; the first column is the card's title.
    case table(headers: [String], rows: [[String]])
    case link(title: String, url: URL)
}

struct GuideSection: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let summary: String
    let blocks: [GuideBlock]
}

/// General information about buying distressed property and land in Ontario.
/// Not legal advice: rules and rates change.
enum Guide {
    static let disclaimer = "General information, not legal or financial advice. Rules and rates change, so confirm details with an Ontario real estate lawyer."

    static var all: [GuideSection] {
        saleTypes + beforeYouBuy
    }

    static let saleTypes: [GuideSection] = [
        GuideSection(
            id: "pos",
            title: "Power of sale",
            symbol: "building.columns",
            summary: "How Ontario lenders sell homes after a mortgage default.",
            blocks: [
                .text("In Ontario, lenders almost always use **power of sale** rather than court foreclosure. The lender sells the property itself, usually through a regular agent on MLS, and keeps what it's owed. Anything left over goes to other creditors and then the owner."),
                .steps([
                    "The borrower defaults. Under the Mortgages Act the lender must wait at least **15 days** before sending a Notice of Sale.",
                    "The Notice of Sale gives at least **35 days** to pay before the lender can sell.",
                    "The lender takes possession if the property is empty and lists it, usually on MLS.",
                    "Offers come in on the lender's terms, usually with its own schedule attached.",
                    "The deal closes. The lender is required to try to get fair market value.",
                ]),
                .bullets([
                    "**Sold “as is, where is”.** The lender has never lived there and makes no promises about condition, chattels, rentals or HST.",
                    "**Firm offers preferred.** Many lenders won't accept financing or inspection conditions, so line up both before you offer.",
                    "**The owner can redeem.** If the owner pays what's owed before closing, the lender can usually cancel your deal.",
                    "**Tenants stay.** A power of sale doesn't end a lawful tenancy.",
                    "**Not automatically cheap.** In the GTA, power of sale listings often get multiple offers.",
                ]),
                .tip("Search MLS remarks for “power of sale”, “POS”, “bank sale” and “mortgagee sale”, then check the sold history on HouseSigma to judge the price."),
                .link(title: "Mortgages Act", url: URL(string: "https://www.ontario.ca/laws/statute/90m40")!),
            ]
        ),
        GuideSection(
            id: "tax",
            title: "Tax sales",
            symbol: "doc.text",
            summary: "Buying property from a municipality for unpaid property taxes.",
            blocks: [
                .text("When property taxes go unpaid for about two years, the municipality can register a **tax arrears certificate**. The owner then has one year to pay the **cancellation price**: all arrears, penalties and costs. If they don't, the municipality can sell the property under the Municipal Act."),
                .steps([
                    "The sale is advertised in the **Ontario Gazette** and a local newspaper, and usually on OntarioTaxSales.ca and the municipality's website.",
                    "Get the tender package: legal description, PIN, minimum tender amount and closing time.",
                    "Submit a sealed tender on the prescribed form with a deposit of at least **20%** of your bid, by certified cheque, bank draft or money order.",
                    "Tenders are opened in public after the deadline. The highest valid tender wins.",
                    "The winner usually has **14 days** to pay the balance, plus accumulated taxes, land transfer tax and any HST.",
                    "Other bidders get their deposits back.",
                ]),
                .bullets([
                    "The **minimum tender** is the cancellation price, sometimes only a few thousand dollars for vacant rural lots.",
                    "You **can't go inside**, and the municipality makes no promises about the land, buildings, occupants or title.",
                    "Some interests survive the sale, such as certain Crown liens and easements. Have a lawyer check.",
                    "Watch for landlocked parcels, narrow strips and lots you can't build on.",
                    "A sale can be cancelled if someone pays the cancellation price before the tender closes.",
                ]),
                .tip("Southern Ontario cities rarely hold tax sales. They're more common in rural townships, the Kawarthas, Hastings and Prince Edward counties, Grey-Bruce and Chatham-Kent."),
                .link(title: "Municipal tax sale rules (O. Reg. 181/03)", url: URL(string: "https://www.ontario.ca/laws/regulation/030181")!),
            ]
        ),
        GuideSection(
            id: "receivership",
            title: "Receivership & court-ordered sales",
            symbol: "hammer",
            summary: "Property sold by a court-appointed receiver.",
            blocks: [
                .text("When a developer, business or investor fails, the court can appoint a **receiver**, usually an accounting or advisory firm, to sell its property. Many GTA and Hamilton development projects have gone into receivership in recent years."),
                .bullets([
                    "Listings appear on the receiver's website, on MLS (“court appointed receiver”, “subject to court approval”) and through commercial brokerages.",
                    "Sales follow a **court-approved process** with bid deadlines. The winning bid still needs an approval and vesting order.",
                    "A **stalking-horse** bid may already set the minimum price.",
                    "Appraisals, environmental reports and the sale process order are often posted on the receiver's case page. Read them.",
                ]),
                .tip("Follow Insolvency Insider for new filings so you see development land before it's widely marketed."),
            ]
        ),
        GuideSection(
            id: "estate",
            title: "Estate sales",
            symbol: "person.2",
            summary: "Homes sold by an estate trustee.",
            blocks: [
                .text("Estate trustees selling a late owner's home are often motivated, and the homes often need updating."),
                .bullets([
                    "Check the trustee has a **Certificate of Appointment of Estate Trustee** (Ontario's probate), or why one isn't needed. Closing can depend on it.",
                    "Expect “as is” terms and little knowledge of the property's history.",
                    "Search remarks for “estate sale”, “estate trustee” and “Certificate of Appointment”.",
                ]),
            ]
        ),
        GuideSection(
            id: "surplus",
            title: "Government surplus",
            symbol: "flag",
            summary: "Land and buildings governments no longer need.",
            blocks: [
                .bullets([
                    "**Infrastructure Ontario** sells surplus provincial land and buildings, including leftover highway land. Public bodies and eligible non-profits get the first chance.",
                    "**CreateTO** manages the City of Toronto's real estate.",
                    "Other cities and regions list **surplus land**, including closed road allowances that are often offered to neighbours first.",
                    "**School boards** must offer surplus sites to other public bodies first, then sell on the open market, often through commercial brokers.",
                    "Federal surplus property goes through **Canada Lands Company** and occasionally **GCSurplus**.",
                ]),
            ]
        ),
        GuideSection(
            id: "compare",
            title: "Comparing sale types",
            symbol: "tablecells",
            summary: "Where each kind of sale is found and what to watch for.",
            blocks: [
                .table(
                    headers: ["Sale type", "Where", "Price", "Inspect?", "Main risk"],
                    rows: [
                        ["Power of sale", "MLS (Realtor.ca)", "Close to market value", "Yes", "“As is” and the lender's terms"],
                        ["Tax sale", "Ontario Gazette, OntarioTaxSales.ca, town websites", "Can be far below market", "Usually not", "Title, access and occupants"],
                        ["Receivership", "Receiver websites, MLS, brokerages", "Varies", "Usually yes", "Court approval can delay or cancel the deal"],
                        ["Estate sale", "MLS", "Near market, room to negotiate", "Yes", "Condition and probate delays"],
                        ["Government surplus", "Infrastructure Ontario, CreateTO, town websites", "Market value", "Usually yes", "Others may get first chance"],
                    ]
                ),
            ]
        ),
    ]

    static let beforeYouBuy: [GuideSection] = [
        GuideSection(
            id: "diligence",
            title: "Due diligence tools",
            symbol: "checklist",
            summary: "What to check before you offer or bid.",
            blocks: [
                .bullets([
                    "**OnLand**: Ontario's land registry. Pull the parcel register to see the owner, mortgages and liens.",
                    "**MPAC AboutMyProperty**: assessed values and comparable sales.",
                    "**Municipal or county GIS maps**: zoning and lot lines.",
                    "**Conservation authority maps**: floodplains and regulated areas can make part of a lot unbuildable.",
                    "**Greenbelt, Oak Ridges Moraine and Niagara Escarpment maps**: heavy limits on building and severing lots.",
                    "**Agricultural Information Atlas**: on prime farmland, severances are very hard to get.",
                    "**Ontario well records map**: well depths and quality near rural land.",
                ]),
                .tip("Each property in your watchlist has a checklist that adapts to its sale type."),
            ]
        ),
        GuideSection(
            id: "value",
            title: "Ways to add value",
            symbol: "plus.square.on.square",
            summary: "Ways an ordinary property can be worth more.",
            blocks: [
                .bullets([
                    "**Up to three units per lot.** On most urban lots with town water and sewer, Ontario allows up to three homes, such as a house, a basement unit and a garden suite. Confirm local zoning and building rules.",
                    "**Severances.** Splitting off a new lot needs consent from the local committee of adjustment or land division committee. Very hard on prime farmland and in the Greenbelt.",
                    "**Minor variances and rezoning.** Small changes to setbacks or lot coverage can make a renovation or addition possible.",
                ]),
            ]
        ),
        GuideSection(
            id: "costs",
            title: "Financing & costs",
            symbol: "dollarsign.circle",
            summary: "Lining up money and budgeting for closing.",
            blocks: [
                .bullets([
                    "**Get pre-approved before you bid.** Power of sale lenders and tax sales expect firm, fast money.",
                    "**Vacant land usually needs 25–50% down.** Mortgage insurance doesn't cover it.",
                    "**Try local lenders for land and farms**: credit unions such as Libro and Meridian, and Farm Credit Canada.",
                    "**Land transfer tax**: Ontario's, plus Toronto's own inside the city. First-time buyers can get refunds of up to $4,000 (Ontario) and $4,475 (Toronto).",
                    "**HST** can apply to new homes, vacant land sold by a business, and commercial property.",
                    "**Vacant home taxes**: some cities, including Toronto and Ottawa, tax homes left empty.",
                    "**Non-resident speculation tax**: 25% across Ontario for buyers who aren't citizens or permanent residents.",
                    "Also budget for legal fees, title insurance, an inspection and an appraisal.",
                ]),
                .tip("The Tools tab estimates land transfer tax and cash to close."),
            ]
        ),
        GuideSection(
            id: "scams",
            title: "Avoiding scams",
            symbol: "exclamationmark.shield",
            summary: "Common traps with distressed property.",
            blocks: [
                .bullets([
                    "Don't pay for **“secret foreclosure lists”**. Most recycle old or public listings.",
                    "Before sending a deposit, **confirm the lawyer's trust account details by phone**, using a number you looked up yourself.",
                    "Tax sales are run by the municipality. Nobody can sell you a guaranteed tax sale property.",
                    "Be careful with people selling **assignments** of contracts they don't own or can't transfer.",
                ]),
                .warning("Never wire money because of an email that changes payment instructions."),
            ]
        ),
    ]
}
