import Foundation

enum SourceCategory: String, CaseIterable, Identifiable {
    case listings
    case taxSales
    case insolvency
    case government
    case commercial
    case land
    case research
    case financing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listings: return "MLS & listing sites"
        case .taxSales: return "Tax sales"
        case .insolvency: return "Receiverships & insolvency"
        case .government: return "Government surplus"
        case .commercial: return "Commercial & development land"
        case .land: return "Land, farms & auctions"
        case .research: return "Due diligence"
        case .financing: return "Financing"
        }
    }

    var symbol: String {
        switch self {
        case .listings: return "house"
        case .taxSales: return "doc.text"
        case .insolvency: return "hammer"
        case .government: return "flag"
        case .commercial: return "building.2"
        case .land: return "leaf"
        case .research: return "checklist"
        case .financing: return "dollarsign.circle"
        }
    }

    var footer: String {
        switch self {
        case .listings:
            return "Power of sale homes are listed on MLS like any other home. Search the listing remarks for keywords."
        case .taxSales:
            return "Municipalities must advertise every tax sale in the Ontario Gazette. Rural townships hold the most."
        case .insolvency:
            return "Receivers post properties on their own websites, often with reports and bid deadlines."
        case .government:
            return "Public bodies and eligible non-profits usually get the first chance to buy."
        case .commercial:
            return "Big brokerages run many receivership and development land sales. Check their investment listings."
        case .land:
            return "Rural land often sells privately or by auction, not just on MLS."
        case .research:
            return "Check title, zoning, water and planning rules before you offer."
        case .financing:
            return "Local lenders are often more flexible than big banks for land and farms."
        }
    }
}

struct Source: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let url: URL
    let category: SourceCategory
}

enum Sources {
    static func items(in category: SourceCategory) -> [Source] {
        all.filter { $0.category == category }
    }

    // Links used elsewhere in the app.
    static let realtor = link("https://www.realtor.ca/")
    static let houseSigma = link("https://housesigma.com/")
    static let ontarioTaxSales = link("https://www.ontariotaxsales.ca/")
    static let onLand = link("https://www.onland.ca/")
    static let mpac = link("https://www.aboutmyproperty.ca/")

    static let all: [Source] = [
        // MLS & listing sites
        Source(id: "realtor", name: "Realtor.ca",
               detail: "The main MLS site. Use Filters → Keywords for “power of sale” and save searches for alerts.",
               url: realtor, category: .listings),
        Source(id: "housesigma", name: "HouseSigma",
               detail: "Ontario sold prices, price history, and terminated or expired listings.",
               url: houseSigma, category: .listings),
        Source(id: "zolo", name: "Zolo", detail: "MLS search with sold data.",
               url: link("https://www.zolo.ca/"), category: .listings),
        Source(id: "wahi", name: "Wahi", detail: "Ontario MLS search with sold data.",
               url: link("https://wahi.com/"), category: .listings),
        Source(id: "zoocasa", name: "Zoocasa", detail: "MLS search with sold data.",
               url: link("https://www.zoocasa.com/"), category: .listings),
        Source(id: "condos", name: "Condos.ca", detail: "Toronto-area condos with price history.",
               url: link("https://condos.ca/"), category: .listings),
        Source(id: "strata", name: "Strata.ca", detail: "Toronto condo listings and building data.",
               url: link("https://strata.ca/"), category: .listings),
        Source(id: "point2", name: "Point2Homes", detail: "Listings that show rural property and land well.",
               url: link("https://www.point2homes.com/CA"), category: .listings),
        Source(id: "kijiji", name: "Kijiji", detail: "Private sales and land: Real Estate → For Sale.",
               url: link("https://www.kijiji.ca/"), category: .listings),
        Source(id: "marketplace", name: "Facebook Marketplace",
               detail: "Private sellers, especially in cottage country and rural areas.",
               url: link("https://www.facebook.com/marketplace/"), category: .listings),

        // Tax sales
        Source(id: "ontariotaxsales", name: "OntarioTaxSales.ca",
               detail: "Central listing many municipalities use for tax sale ads.",
               url: ontarioTaxSales, category: .taxSales),
        Source(id: "gazette", name: "Ontario Gazette tax sale notices",
               detail: "Every tax sale must be advertised here. Opens a Google search of the past month's notices.",
               url: SearchLinks.gazetteTaxSales(pastMonth: true), category: .taxSales),
        Source(id: "ottawa-tax", name: "City of Ottawa tax sales",
               detail: "Ottawa's own tax sale listings.",
               url: link("https://ottawa.ca/en/property-tax-sales"), category: .taxSales),
        Source(id: "tax-rules", name: "Municipal tax sale rules (O. Reg. 181/03)",
               detail: "The regulation that sets out how tenders and auctions work.",
               url: link("https://www.ontario.ca/laws/regulation/030181"), category: .taxSales),

        // Receiverships & insolvency
        Source(id: "insolvencyinsider", name: "Insolvency Insider",
               detail: "Reports new receiverships and bankruptcies as they're filed.",
               url: link("https://insolvencyinsider.ca/"), category: .insolvency),
        Source(id: "spergel", name: "msi Spergel", detail: "Ontario-focused insolvency firm.",
               url: link("https://www.spergel.ca/"), category: .insolvency),
        Source(id: "ksv", name: "KSV Advisory", detail: "Frequent court-appointed receiver for GTA developments.",
               url: link("https://www.ksvadvisory.com/"), category: .insolvency),
        Source(id: "mnp", name: "MNP", detail: "Insolvency and receivership engagements.",
               url: link("https://www.mnp.ca/"), category: .insolvency),
        Source(id: "bdo", name: "BDO Canada", detail: "Insolvency and receivership engagements.",
               url: link("https://www.bdo.ca/"), category: .insolvency),
        Source(id: "grantthornton", name: "Grant Thornton", detail: "Insolvency and receivership engagements.",
               url: link("https://www.grantthornton.ca/"), category: .insolvency),
        Source(id: "fti", name: "FTI Consulting", detail: "Court-appointed receiver and monitor.",
               url: link("https://www.fticonsulting.com/"), category: .insolvency),
        Source(id: "deloitte", name: "Deloitte insolvencies", detail: "Case pages with court documents and sale processes.",
               url: link("https://www.insolvencies.deloitte.ca/"), category: .insolvency),

        // Government surplus
        Source(id: "io", name: "Infrastructure Ontario properties for sale",
               detail: "Surplus provincial land and buildings, including leftover highway land.",
               url: link("https://propertiesforsale.infrastructureontario.ca/"), category: .government),
        Source(id: "createto", name: "CreateTO", detail: "The City of Toronto's real estate agency.",
               url: link("https://createto.ca/"), category: .government),
        Source(id: "clc", name: "Canada Lands Company", detail: "Surplus federal land.",
               url: link("https://www.clc-sic.ca/"), category: .government),
        Source(id: "gcsurplus", name: "GCSurplus", detail: "Federal surplus sales, with real estate now and then.",
               url: link("https://www.gcsurplus.ca/"), category: .government),
        Source(id: "school-surplus", name: "Surplus school sites",
               detail: "School boards must offer surplus sites to public bodies first, then sell them. Opens a Google search.",
               url: SearchLinks.google(SearchLinks.query(terms: ["surplus property", "surplus school"], extra: "school board Ontario for sale")),
               category: .government),

        // Commercial & development land
        Source(id: "cbre", name: "CBRE", detail: "Investment and land sales, including receiverships.",
               url: link("https://www.cbre.ca/"), category: .commercial),
        Source(id: "colliers", name: "Colliers", detail: "Investment and land sales.",
               url: link("https://www.collierscanada.com/"), category: .commercial),
        Source(id: "avisonyoung", name: "Avison Young", detail: "Investment and land sales.",
               url: link("https://www.avisonyoung.ca/"), category: .commercial),
        Source(id: "cushman", name: "Cushman & Wakefield", detail: "Investment and land sales.",
               url: link("https://www.cushmanwakefield.com/en/canada"), category: .commercial),
        Source(id: "jll", name: "JLL", detail: "Investment and land sales.",
               url: link("https://www.jll.ca/"), category: .commercial),
        Source(id: "spacelist", name: "Spacelist", detail: "Commercial property for sale and lease.",
               url: link("https://www.spacelist.ca/"), category: .commercial),

        // Land, farms & auctions
        Source(id: "ontariofarmer", name: "Ontario Farmer",
               detail: "Farm paper with farm real estate and auction sale bills.",
               url: link("https://ontariofarmer.com/"), category: .land),
        Source(id: "farm-auctions", name: "Farm real estate auctions",
               detail: "Recent auction notices for Ontario farms. Opens a Google search.",
               url: SearchLinks.google(SearchLinks.query(terms: ["real estate auction"], extra: "farm Ontario"), pastMonth: true),
               category: .land),
        Source(id: "kijiji-land", name: "Kijiji land for sale",
               detail: "Recent land ads on Kijiji. Opens a Google search.",
               url: SearchLinks.google(SearchLinks.query(site: "kijiji.ca", terms: ["land for sale"], extra: "Ontario"), pastMonth: true),
               category: .land),

        // Due diligence
        Source(id: "onland", name: "OnLand",
               detail: "Ontario's land registry: owner, mortgages and liens for a small fee.",
               url: onLand, category: .research),
        Source(id: "mpac", name: "MPAC AboutMyProperty",
               detail: "Assessed values and comparable sales.",
               url: mpac, category: .research),
        Source(id: "wells", name: "Ontario well records map",
               detail: "Depth and yield of wells near a rural property.",
               url: link("https://www.ontario.ca/page/map-well-records"), category: .research),
        Source(id: "conservation", name: "Conservation Ontario",
               detail: "Find the conservation authority for a property and its regulation maps.",
               url: link("https://conservationontario.ca/"), category: .research),
        Source(id: "nec", name: "Niagara Escarpment Commission",
               detail: "Development control rules along the escarpment.",
               url: link("https://escarpment.org/"), category: .research),
        Source(id: "greenbelt", name: "Greenbelt and Oak Ridges Moraine maps",
               detail: "Provincial plans that restrict building and severances. Opens a Google search.",
               url: SearchLinks.google(SearchLinks.query(site: "ontario.ca", terms: ["Greenbelt Plan", "Oak Ridges Moraine"], extra: "map")),
               category: .research),
        Source(id: "ag-atlas", name: "Agricultural Information Atlas",
               detail: "Ontario's farmland and soil map. Opens a Google search.",
               url: SearchLinks.google(SearchLinks.query(terms: ["Agricultural Information Atlas"], extra: "Ontario")),
               category: .research),
        Source(id: "mortgages-act", name: "Mortgages Act",
               detail: "Ontario's power of sale rules.",
               url: link("https://www.ontario.ca/laws/statute/90m40"), category: .research),
        Source(id: "ltt", name: "Ontario land transfer tax",
               detail: "Official rates, refunds and exemptions.",
               url: link("https://www.ontario.ca/document/land-transfer-tax"), category: .research),
        Source(id: "mltt", name: "Toronto municipal land transfer tax",
               detail: "Toronto's own land transfer tax and rebates.",
               url: link("https://www.toronto.ca/services-payments/property-taxes-utilities/municipal-land-transfer-tax-mltt/"),
               category: .research),

        // Financing
        Source(id: "fcc", name: "Farm Credit Canada", detail: "Farm and agricultural land loans.",
               url: link("https://www.fcc-fac.ca/"), category: .financing),
        Source(id: "libro", name: "Libro Credit Union", detail: "Southwestern Ontario credit union.",
               url: link("https://www.libro.ca/"), category: .financing),
        Source(id: "meridian", name: "Meridian Credit Union", detail: "Ontario credit union.",
               url: link("https://www.meridiancu.ca/"), category: .financing),
    ]

    private static func link(_ string: String) -> URL {
        guard let url = URL(string: string) else {
            preconditionFailure("Invalid source URL: \(string)")
        }
        return url
    }
}
