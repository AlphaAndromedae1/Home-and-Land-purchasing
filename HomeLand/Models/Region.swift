import Foundation

/// Parts of Southern Ontario the app knows about, plus a catch-all.
enum Region: String, Codable, CaseIterable, Identifiable {
    case gta
    case hamiltonNiagara
    case waterlooWellington
    case southwest
    case eastOfGTA
    case georgianBay
    case eastern
    case anywhere

    var id: String { rawValue }

    var name: String {
        switch self {
        case .gta: return "GTA"
        case .hamiltonNiagara: return "Hamilton & Niagara"
        case .waterlooWellington: return "Waterloo, Wellington & Brant"
        case .southwest: return "Southwestern Ontario"
        case .eastOfGTA: return "Kawarthas, Northumberland & Quinte"
        case .georgianBay: return "Simcoe, Georgian Bay & Grey-Bruce"
        case .eastern: return "Ottawa & Eastern Ontario"
        case .anywhere: return "Anywhere in Ontario"
        }
    }

    var subtitle: String {
        switch self {
        case .gta: return "Toronto, Peel, York, Durham and Halton"
        case .hamiltonNiagara: return "Hamilton, Burlington, Niagara and Haldimand"
        case .waterlooWellington: return "Kitchener-Waterloo, Cambridge, Guelph and Brantford"
        case .southwest: return "London, Windsor-Essex, Chatham-Kent, Sarnia and Norfolk"
        case .eastOfGTA: return "Peterborough, Kawartha Lakes, Cobourg, Belleville and Prince Edward County"
        case .georgianBay: return "Barrie, Orillia, Collingwood, Owen Sound and the Bruce"
        case .eastern: return "Ottawa, Kingston, Brockville, Cornwall and Lanark"
        case .anywhere: return "No location filter"
        }
    }

    /// Towns, cities and counties used to narrow web searches.
    var places: [String] {
        switch self {
        case .gta:
            return ["Toronto", "Mississauga", "Brampton", "Vaughan", "Markham", "Oakville", "Oshawa", "Pickering"]
        case .hamiltonNiagara:
            return ["Hamilton", "Burlington", "St. Catharines", "Niagara Falls", "Welland", "Grimsby", "Fort Erie", "Haldimand"]
        case .waterlooWellington:
            return ["Kitchener", "Waterloo", "Cambridge", "Guelph", "Brantford", "Wellington County", "Woolwich"]
        case .southwest:
            return ["London", "Windsor", "Chatham-Kent", "Sarnia", "Woodstock", "Stratford", "Norfolk County", "Leamington"]
        case .eastOfGTA:
            return ["Peterborough", "Kawartha Lakes", "Cobourg", "Belleville", "Prince Edward County", "Quinte West", "Hastings County", "Trent Hills"]
        case .georgianBay:
            return ["Barrie", "Orillia", "Collingwood", "Owen Sound", "Midland", "Wasaga Beach", "Grey County", "Bruce County"]
        case .eastern:
            return ["Ottawa", "Kingston", "Brockville", "Cornwall", "Perth", "Smiths Falls", "Lanark", "Prescott-Russell"]
        case .anywhere:
            return []
        }
    }

    var overview: String {
        switch self {
        case .gta:
            return "The most power of sale listings in Ontario, especially investor-owned condos and pre-construction contracts being resold (assignments). Tax sales are rare and prices are high, so expect competition."
        case .hamiltonNiagara:
            return "Older housing stock, estate sales and homes needing work. Smaller Niagara towns hold tax sales now and then."
        case .waterlooWellington:
            return "High-demand cities surrounded by farmland. Rural Waterloo, Wellington and Perth counties have farm real estate auctions."
        case .southwest:
            return "Lower prices, lots of farmland, and more regular tax sales in rural municipalities such as Chatham-Kent."
        case .eastOfGTA:
            return "Southern Ontario's best area for cheap rural lots, cottage land and tax sales."
        case .georgianBay:
            return "Cottage country and recreational land with strong weekend-buyer demand."
        case .eastern:
            return "The Ottawa and Kingston markets, with affordable rural land in between."
        case .anywhere:
            return "Searches cover all of Ontario."
        }
    }

    var tips: [String] {
        switch self {
        case .gta:
            return [
                "Watch condo power of sales and **assignments** in Toronto, Mississauga and Vaughan.",
                "Follow new receiverships for **development land** before it's widely marketed.",
                "Toronto charges its **own land transfer tax** on top of Ontario's.",
                "Toronto taxes homes left **vacant**, so plan renovation timelines carefully.",
            ]
        case .hamiltonNiagara:
            return [
                "Search “estate sale”, “contractor special” and “needs TLC”.",
                "Hamilton has had several developer **receiverships**.",
                "**Niagara Escarpment** rules apply along the escarpment, so check before buying land.",
            ]
        case .waterlooWellington:
            return [
                "Watch for **farm auction** sale bills and Ontario Farmer listings.",
                "The Grand River Conservation Authority regulates much of this area.",
                "Severances on **prime farmland** are very hard to get.",
            ]
        case .southwest:
            return [
                "Libro Credit Union and Farm Credit Canada are worth calling for land and farm loans.",
                "Check **municipal drains** and tile drainage on farmland.",
                "Lake Erie and Lake Huron shoreline lots may be in **flood or erosion hazard** areas.",
            ]
        case .eastOfGTA:
            return [
                "Kawartha Lakes, Hastings County townships and Prince Edward County often advertise **tax sales**.",
                "Many lots are on **seasonal or private roads**, so confirm year-round access.",
                "Waterfront lots need **septic and shoreline** approvals.",
            ]
        case .georgianBay:
            return [
                "Check **Niagara Escarpment** rules around Collingwood, the Blue Mountains and the Bruce Peninsula.",
                "Seasonal roads and **water-access-only** lots are common.",
                "Grey and Bruce townships hold occasional tax sales.",
            ]
        case .eastern:
            return [
                "Ottawa posts its **tax sales** on its website.",
                "Ottawa charges a **vacant unit tax** on empty homes.",
                "Lanark and Leeds-Grenville have lots of **rural acreage**.",
            ]
        case .anywhere:
            return []
        }
    }

    /// Regions shown in the guide (everything except the catch-all).
    static var southernRegions: [Region] {
        allCases.filter { $0 != .anywhere }
    }
}
