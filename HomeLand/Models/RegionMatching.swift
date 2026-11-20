import Foundation

extension Region {
    /// More towns, townships and counties in each region, used to place a
    /// municipality (from a listing or Gazette notice) in a region.
    var otherMunicipalities: [String] {
        switch self {
        case .gta:
            return ["Caledon", "Richmond Hill", "Newmarket", "Aurora", "King", "Whitchurch-Stouffville", "East Gwillimbury",
                    "Georgina", "Milton", "Halton Hills", "Whitby", "Ajax", "Clarington", "Uxbridge", "Scugog", "Brock",
                    "Durham", "Peel", "York", "Halton", "Scarborough", "Etobicoke", "North York", "East York"]
        case .hamiltonNiagara:
            return ["Port Colborne", "Thorold", "Lincoln", "Pelham", "Wainfleet", "West Lincoln", "Niagara-on-the-Lake",
                    "Niagara", "Haldimand County"]
        case .waterlooWellington:
            return ["Brant", "Wilmot", "Wellesley", "North Dumfries", "Centre Wellington", "Wellington North", "Mapleton",
                    "Minto", "Erin", "Guelph/Eramosa", "Puslinch", "Wellington", "Waterloo Region"]
        case .southwest:
            return ["Norfolk", "Essex", "Kingsville", "Lakeshore", "Tecumseh", "LaSalle", "Amherstburg", "Tillsonburg",
                    "Ingersoll", "St. Thomas", "Elgin", "Middlesex", "Strathroy-Caradoc", "Lambton", "Petrolia",
                    "Plympton-Wyoming", "Huron", "Goderich", "St. Marys", "Oxford", "Norwich", "Zorra",
                    "Aylmer", "Bayham", "Central Elgin", "Southwold", "Dutton/Dunwich", "West Elgin", "Malahide",
                    "Bluewater", "Huron East", "South Huron", "Morris-Turnberry", "Howick", "North Huron",
                    "Ashfield-Colborne-Wawanosh", "Central Huron", "Warwick", "Lambton Shores", "Brooke-Alvinston",
                    "Dawn-Euphemia", "Enniskillen", "St. Clair", "Pelee", "West Perth", "North Perth", "Perth East",
                    "Perth South", "Southwest Middlesex", "Middlesex Centre", "Thames Centre", "Adelaide Metcalfe",
                    "Lucan Biddulph", "North Middlesex", "East Zorra-Tavistock", "South-West Oxford", "Blandford-Blenheim"]
        case .eastOfGTA:
            return ["Port Hope", "Prince Edward", "Hastings", "Brighton", "Cramahe", "Alnwick/Haldimand", "Selwyn",
                    "Cavan Monaghan", "Otonabee-South Monaghan", "Asphodel-Norwood", "Douro-Dummer",
                    "Havelock-Belmont-Methuen", "North Kawartha", "Trent Lakes", "Centre Hastings", "Tweed", "Madoc",
                    "Marmora and Lake", "Stirling-Rawdon", "Tyendinaga", "Deseronto", "Bancroft", "Hastings Highlands",
                    "Carlow/Mayo", "Faraday", "Limerick", "Wollaston", "Tudor and Cashel", "Greater Napanee",
                    "Stone Mills", "Loyalist", "Addington Highlands", "Lennox and Addington", "Northumberland",
                    "Haliburton", "Dysart", "Dysart et al", "Minden Hills", "Highlands East", "Algonquin Highlands"]
        case .georgianBay:
            return ["Innisfil", "Bradford West Gwillimbury", "New Tecumseth", "Essa", "Springwater", "Oro-Medonte",
                    "Severn", "Tay", "Tiny", "Penetanguishene", "Ramara", "Clearview", "Adjala-Tosorontio",
                    "The Blue Mountains", "Blue Mountains", "Meaford", "Georgian Bluffs", "Chatsworth", "West Grey",
                    "Southgate", "Grey Highlands", "Hanover", "Saugeen Shores", "Kincardine", "South Bruce Peninsula",
                    "Northern Bruce Peninsula", "Arran-Elderslie", "Brockton", "Huron-Kinloss", "South Bruce", "Grey",
                    "Bruce", "Simcoe", "Dufferin", "Orangeville", "Shelburne", "Mono", "Mulmur", "Melancthon",
                    "Amaranth", "Grand Valley", "East Garafraxa", "Gravenhurst", "Bracebridge", "Huntsville",
                    "Muskoka Lakes", "Lake of Bays", "Georgian Bay", "Muskoka"]
        case .eastern:
            return ["Prescott", "Russell", "Hawkesbury", "Clarence-Rockland", "Casselman", "Alfred and Plantagenet",
                    "Champlain", "East Hawkesbury", "The Nation", "Gananoque", "Elizabethtown-Kitley", "Rideau Lakes",
                    "Westport", "Merrickville-Wolford", "North Grenville", "Edwardsburgh/Cardinal", "Augusta",
                    "Front of Yonge", "Athens", "Leeds and the Thousand Islands", "Leeds and Grenville",
                    "Mississippi Mills", "Carleton Place", "Beckwith", "Drummond/North Elmsley", "Tay Valley",
                    "Montague", "Lanark Highlands", "South Frontenac", "Central Frontenac", "North Frontenac",
                    "Frontenac Islands", "Frontenac", "Stormont, Dundas and Glengarry", "South Dundas", "North Dundas",
                    "South Stormont", "North Stormont", "North Glengarry", "South Glengarry", "Renfrew", "Arnprior",
                    "Pembroke", "Petawawa", "Laurentian Valley", "Whitewater Region", "Madawaska Valley",
                    "Bonnechere Valley", "Killaloe, Hagarty and Richards", "Greater Madawaska", "McNab/Braeside",
                    "Horton", "Admaston/Bromley", "Brudenell, Lyndoch and Raglan", "North Algona Wilberforce",
                    "Head, Clara and Maria", "Deep River", "Laurentian Hills"]
        case .anywhere:
            return []
        }
    }

    /// The Southern Ontario region a town belongs to, if the app knows it.
    static func matching(municipality: String) -> Region? {
        let name = normalizedPlace(municipality)
        guard !name.isEmpty else { return nil }
        for region in southernRegions {
            for candidate in region.places + region.otherMunicipalities {
                let place = normalizedPlace(candidate)
                if name == place || name.hasPrefix(place + ",") || name.hasPrefix(place + " (") {
                    return region
                }
            }
        }
        return nil
    }

    private static func normalizedPlace(_ text: String) -> String {
        var name = text.lowercased().trimmed
        if name.hasSuffix(" county") {
            name = String(name.dropLast(" county".count))
        }
        if name.hasPrefix("saint ") {
            name = "st. " + name.dropFirst("saint ".count)
        }
        return name
    }
}
