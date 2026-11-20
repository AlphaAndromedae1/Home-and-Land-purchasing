import Foundation

// In-app listing search.
//
// Listing sites such as Realtor.ca don't offer a public data feed, and copying
// their pages breaks their terms of use. Instead the app asks Brave Search's
// API for public listing pages it has indexed, then reads the price, address
// and other details from each result's title and description.

/// Details read from a search result's title and description.
struct ListingDetails: Hashable {
    var address: String?
    var municipality: String?
    var price: Double?
    var isRental = false
    var bedrooms: Int?
    var bathrooms: Double?
    var acres: Double?
    var saleType: SaleType?
    var kind: PropertyKind?
}

struct ListingResult: Identifiable, Hashable {
    let url: URL
    let title: String
    let snippet: String
    /// Website the listing is on, e.g. "realtor.ca".
    let source: String
    /// Brave's description of when the page was published, e.g. "3 days ago".
    let age: String?
    let published: Date?
    let thumbnailURL: URL?
    let details: ListingDetails

    var id: String { url.absoluteString }

    var isLikelyListing: Bool {
        ListingParser.isLikelyListing(url)
    }

    /// "3 bd · 2 ba · 10 acres"
    var factsText: String {
        var facts: [String] = []
        if let beds = details.bedrooms { facts.append("\(beds) bd") }
        if let baths = details.bathrooms { facts.append("\(baths.formatted()) ba") }
        if let acres = details.acres { facts.append("\(acres.formatted()) \(acres == 1 ? "acre" : "acres")") }
        return facts.joined(separator: " · ")
    }

    var sourceLine: String {
        [source, age].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

enum ListingParser {
    private static let siteNames = ["realtor.ca", "kijiji", "zolo", "housesigma", "point2"]

    static func details(title: String, text: String) -> ListingDetails {
        var details = ListingDetails()
        details.address = address(fromTitle: title)
        details.municipality = details.address.flatMap { municipality(fromAddress: $0) }
        if let price = price(in: text) {
            details.price = price.value
            details.isRental = price.isRental
        }
        details.bedrooms = firstNumber(#"(\d{1,2})(?:\s*\+\s*\d{1,2})?\s*(?:bed(?:room)?s?|bd|br)\b"#, in: text).map { Int($0) }
        details.bathrooms = firstNumber(#"(\d{1,2}(?:\.\d)?)\s*(?:bath(?:room)?s?|ba)\b"#, in: text)
        details.acres = firstNumber(#"(\d{1,4}(?:,\d{3})?(?:\.\d{1,3})?)\s*\+?\s*(?:acres?|ac)\b"#, in: text)
        details.saleType = saleType(in: text)
        details.kind = kind(in: text)
        return details
    }

    /// Removes HTML tags and the common character entities.
    static func stripHTML(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = [
            "&amp;": "&", "&quot;": "\"", "&#39;": "'", "&#x27;": "'", "&apos;": "'",
            "&lt;": "<", "&gt;": ">", "&nbsp;": " ",
        ]
        for (entity, character) in entities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result.trimmed
    }

    /// The title without the site name or a "For sale:" prefix.
    static func cleanTitle(_ title: String) -> String {
        let plain = stripHTML(title)
        let firstPart = plain.components(separatedBy: " | ").first ?? plain
        let parts = firstPart.components(separatedBy: " - ").filter { part in
            !siteNames.contains { part.lowercased().contains($0) }
        }
        var cleaned = parts.joined(separator: " - ").trimmed
        for prefix in ["for sale:", "for sale -"] where cleaned.lowercased().hasPrefix(prefix) {
            cleaned = String(cleaned.dropFirst(prefix.count)).trimmed
            break
        }
        return cleaned.isEmpty ? plain : cleaned
    }

    /// A street address from the title, if it has one.
    static func address(fromTitle title: String) -> String? {
        let segments = cleanTitle(title).components(separatedBy: " - ").map(\.trimmed)
        return segments.first { segment in
            guard let first = segment.first else { return false }
            let lower = segment.lowercased()
            if first.isNumber {
                let isFacts = lower.range(of: #"^\d+(\+\d+)?\s*(bed|bath|br|bd|ac|acre|sq)"#, options: .regularExpression) != nil
                return !isFacts && segment.contains(" ") && segment.rangeOfCharacter(from: .letters) != nil
            }
            return ["lot ", "part lot", "pt lot", "concession"].contains { lower.hasPrefix($0) }
        }
    }

    /// The town from an address like "123 Main St, Hamilton, Ontario L8P1A1".
    static func municipality(fromAddress address: String) -> String? {
        let parts = address.components(separatedBy: ",").map(\.trimmed)
        guard parts.count >= 2 else { return nil }
        var town = parts[1]
        if let bracket = town.firstIndex(of: "(") {
            town = String(town[..<bracket]).trimmed
        }
        let lower = town.lowercased()
        guard !town.isEmpty, lower != "ontario", lower != "on" else { return nil }
        if town == town.uppercased() {
            town = town.capitalized
        }
        return town
    }

    /// The first sale price in the text (at least $10,000), or a monthly rent.
    static func price(in text: String) -> (value: Double, isRental: Bool)? {
        let pattern = #"\$\s?(\d{1,3}(?:,\d{3})+|\d+(?:\.\d+)?)\s?(million|m|k)?\b(\s*(?:/\s*mo(?:nth)?|per\s+month|a\s+month|monthly))?"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        var rent: Double?
        for match in regex.matches(in: text, range: range) {
            guard let number = group(1, of: match, in: text),
                  var value = Double(number.replacingOccurrences(of: ",", with: ""))
            else { continue }
            switch group(2, of: match, in: text)?.lowercased() ?? "" {
            case "m", "million": value *= 1_000_000
            case "k": value *= 1_000
            default: break
            }
            if group(3, of: match, in: text) != nil {
                if rent == nil, value >= 100 { rent = value }
            } else if value >= 10_000, value < 1_000_000_000 {
                return (value, false)
            }
        }
        if let rent {
            return (rent, true)
        }
        return nil
    }

    static func saleType(in text: String) -> SaleType? {
        let lower = text.lowercased()
        if ["court appointed", "court-appointed", "receivership", "subject to court approval"].contains(where: { lower.contains($0) }) {
            return .receivership
        }
        if lower.contains("tax arrears") || lower.contains("tax sale") {
            return .taxSale
        }
        if ["power of sale", "bank sale", "mortgagee sale"].contains(where: { lower.contains($0) })
            || text.range(of: #"\bPOS\b"#, options: .regularExpression) != nil {
            return .powerOfSale
        }
        if ["estate sale", "estate trustee", "certificate of appointment"].contains(where: { lower.contains($0) }) {
            return .estate
        }
        if lower.contains("auction") {
            return .auction
        }
        return nil
    }

    static func kind(in text: String) -> PropertyKind? {
        let lower = text.lowercased()
        func has(_ words: [String]) -> Bool { words.contains(where: { lower.contains($0) }) }
        if has(["vacant land", "building lot", "vacant lot"]) { return .vacantLand }
        if has(["development land", "draft plan", "development site"]) { return .development }
        if has(["farm"]) { return .farm }
        if has(["condo", "apartment", "townhouse", "town house"]) { return .condo }
        if has(["cottage", "waterfront"]) { return .cottage }
        if has(["commercial", "industrial", "retail"]) { return .commercial }
        if has(["house", "bungalow", "detached", "bedroom"]) { return .house }
        return nil
    }

    /// Whether a URL is a single listing rather than a search, map or blog page.
    static func isLikelyListing(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        if host.hasSuffix("realtor.ca") { return path.hasPrefix("/real-estate/") }
        if host.hasSuffix("kijiji.ca") { return path.hasPrefix("/v-") }
        if host.hasSuffix("housesigma.com") { return path.contains("/home/") }
        if host.hasSuffix("zolo.ca") {
            let parts = path.split(separator: "/")
            return parts.count >= 2 && parts[0].hasSuffix("real-estate") && !path.contains("/blog")
        }
        return true
    }

    static func parseDate(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        if let date = ISO8601DateFormatter().date(from: text) {
            return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: text)
    }

    private static func firstNumber(_ pattern: String, in text: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let number = group(1, of: match, in: text)
        else { return nil }
        return Double(number.replacingOccurrences(of: ",", with: ""))
    }

    private static func group(_ index: Int, of match: NSTextCheckingResult, in text: String) -> String? {
        let range = match.range(at: index)
        guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
        return String(text[swiftRange])
    }
}

// MARK: - Requests

enum ListingSearchTarget: String, CaseIterable, Identifiable {
    case allSites
    case realtor
    case houseSigma
    case zolo
    case kijiji
    case web
    case taxSales

    var id: String { rawValue }

    var name: String {
        switch self {
        case .allSites: return "All listing sites"
        case .realtor: return "Realtor.ca"
        case .houseSigma: return "HouseSigma"
        case .zolo: return "Zolo"
        case .kijiji: return "Kijiji"
        case .web: return "Whole web"
        case .taxSales: return "Tax sale notices"
        }
    }

    var subtitle: String {
        switch self {
        case .allSites: return "Realtor.ca, HouseSigma, Zolo and Kijiji together"
        case .realtor: return "MLS listings"
        case .houseSigma: return "MLS listings with sold history"
        case .zolo: return "MLS listings"
        case .kijiji: return "Private sales and land"
        case .web: return "Brokerages, receivers and news"
        case .taxSales: return "“Sale of land for tax arrears”"
        }
    }

    var symbol: String {
        switch self {
        case .allSites: return "square.stack.3d.up"
        case .realtor: return "house"
        case .houseSigma: return "chart.line.uptrend.xyaxis"
        case .zolo: return "list.bullet"
        case .kijiji: return "tag"
        case .web: return "globe"
        case .taxSales: return "doc.text.magnifyingglass"
        }
    }

    var sites: [String] {
        switch self {
        case .allSites: return ["realtor.ca", "housesigma.com", "zolo.ca", "kijiji.ca"]
        case .realtor: return ["realtor.ca"]
        case .houseSigma: return ["housesigma.com"]
        case .zolo: return ["zolo.ca"]
        case .kijiji: return ["kijiji.ca"]
        case .web, .taxSales: return []
        }
    }
}

struct ListingSearchRequest: Hashable, Identifiable {
    /// Keeps queries under Brave's length limits.
    static let maxTerms = 4
    static let maxPlaces = 6

    var target: ListingSearchTarget
    var terms: [String]
    var region: Region
    var pastMonth: Bool

    var id: String { "\(query)|\(freshness ?? "")" }

    var effectiveTerms: [String] {
        target == .taxSales ? ["sale of land for tax arrears"] : Array(terms.prefix(Self.maxTerms))
    }

    var areTermsTrimmed: Bool {
        target != .taxSales && terms.count > Self.maxTerms
    }

    var places: [String] {
        Array(region.places.prefix(Self.maxPlaces))
    }

    var query: String {
        let sites = target.sites
        let siteFilter: String
        switch sites.count {
        case 0: siteFilter = ""
        case 1: siteFilter = "site:\(sites[0])"
        default: siteFilter = "(" + sites.map { "site:\($0)" }.joined(separator: " OR ") + ")"
        }
        return [siteFilter, SearchLinks.anyOf(effectiveTerms), SearchLinks.anyOf(places)]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Brave's "past month" filter.
    var freshness: String? {
        pastMonth ? "pm" : nil
    }

    var title: String {
        target.name
    }

    var summary: String {
        ([region.name] + effectiveTerms).joined(separator: " · ")
    }

    /// The sale type the search was looking for, used when saving a result.
    var suggestedSaleType: SaleType? {
        target == .taxSales ? .taxSale : ListingParser.saleType(in: terms.joined(separator: " "))
    }

    /// The same search on Google, for when there's no Brave key.
    var googleFallbackURL: URL {
        SearchLinks.google(query, pastMonth: pastMonth)
    }
}

struct ListingSearchPage {
    let results: [ListingResult]
    let moreAvailable: Bool
}

enum ListingSearchError: LocalizedError, Equatable {
    case missingKey
    case invalidKey
    case outOfCredit
    case rateLimited
    case network
    case unreadableResponse
    case badResponse(Int)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "Add a Brave Search API key in Tools → Listing search to see listings here."
        case .invalidKey:
            return "Brave didn't accept your API key. Check it in Tools → Listing search."
        case .outOfCredit:
            return "Your Brave Search credit has run out for this month. Check your plan in the Brave dashboard."
        case .rateLimited:
            return "Brave says you've reached your search limit or are searching too fast. Wait a moment and try again."
        case .network:
            return "Couldn't reach Brave Search. Check your internet connection."
        case .unreadableResponse:
            return "Brave Search sent back something the app couldn't read. Try again later."
        case let .badResponse(code):
            return "Brave Search returned an error (code \(code)). Try again later."
        }
    }
}

// MARK: - Brave Search API

struct BraveSearchClient {
    static let endpoint = URL(string: "https://api.search.brave.com/res/v1/web/search")!
    static let pageSize = 20
    /// Brave allows result pages 0 through 9.
    static let maxPage = 9

    let apiKey: String
    var session: URLSession = .shared

    static func makeRequest(query: String, freshness: String?, page: Int, apiKey: String, extraSnippets: Bool) -> URLRequest {
        var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(pageSize)),
            URLQueryItem(name: "offset", value: String(min(max(page, 0), maxPage))),
            URLQueryItem(name: "country", value: "CA"),
            URLQueryItem(name: "search_lang", value: "en"),
            URLQueryItem(name: "result_filter", value: "web"),
            URLQueryItem(name: "text_decorations", value: "false"),
        ]
        if extraSnippets {
            items.append(URLQueryItem(name: "extra_snippets", value: "true"))
        }
        if let freshness {
            items.append(URLQueryItem(name: "freshness", value: freshness))
        }
        components.queryItems = items
        var request = URLRequest(url: components.url!)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")
        request.timeoutInterval = 20
        return request
    }

    func search(query: String, freshness: String?, page: Int) async throws -> ListingSearchPage {
        do {
            return try await perform(query: query, freshness: freshness, page: page, extraSnippets: true)
        } catch ListingSearchError.badResponse(let code) where code == 400 || code == 422 {
            // Some plans don't include extra snippets; try once without them.
            return try await perform(query: query, freshness: freshness, page: page, extraSnippets: false)
        }
    }

    private func perform(query: String, freshness: String?, page: Int, extraSnippets: Bool) async throws -> ListingSearchPage {
        let request = Self.makeRequest(query: query, freshness: freshness, page: page, apiKey: apiKey, extraSnippets: extraSnippets)
        let reply: (Data, URLResponse)
        do {
            reply = try await session.data(for: request)
        } catch {
            throw ListingSearchError.network
        }
        let (data, response) = reply
        guard let http = response as? HTTPURLResponse else {
            throw ListingSearchError.unreadableResponse
        }
        switch http.statusCode {
        case 200: return try Self.parse(data)
        case 401, 403: throw ListingSearchError.invalidKey
        case 402: throw ListingSearchError.outOfCredit
        case 429: throw ListingSearchError.rateLimited
        default: throw ListingSearchError.badResponse(http.statusCode)
        }
    }

    static func parse(_ data: Data) throws -> ListingSearchPage {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let response = try? decoder.decode(BraveResponse.self, from: data) else {
            throw ListingSearchError.unreadableResponse
        }
        let results = (response.web?.results ?? []).compactMap { makeResult($0) }
        return ListingSearchPage(results: results, moreAvailable: response.query?.moreResultsAvailable ?? false)
    }

    private static func makeResult(_ result: BraveResponse.Result) -> ListingResult? {
        guard let link = result.url,
              let url = URL(string: link),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else { return nil }
        let title = ListingParser.stripHTML(result.title ?? "")
        let description = ListingParser.stripHTML(result.description ?? "")
        let extras = (result.extraSnippets ?? []).map { ListingParser.stripHTML($0) }
        let text = ([title, description] + extras).joined(separator: " ")
        var host = (result.metaUrl?.hostname ?? url.host ?? "").lowercased()
        if host.hasPrefix("www.") {
            host.removeFirst(4)
        }
        return ListingResult(
            url: url,
            title: ListingParser.cleanTitle(title),
            snippet: description,
            source: host,
            age: result.age,
            published: ListingParser.parseDate(result.pageAge),
            thumbnailURL: result.thumbnail?.src.flatMap { URL(string: $0) },
            details: ListingParser.details(title: title, text: text)
        )
    }
}

/// The parts of Brave's web search response the app uses.
struct BraveResponse: Decodable {
    struct Query: Decodable {
        let moreResultsAvailable: Bool?
    }

    struct Web: Decodable {
        let results: [Result]?
    }

    struct Result: Decodable {
        let title: String?
        let url: String?
        let description: String?
        let age: String?
        let pageAge: String?
        let extraSnippets: [String]?
        let thumbnail: Thumbnail?
        let metaUrl: MetaURL?
    }

    struct Thumbnail: Decodable {
        let src: String?
    }

    struct MetaURL: Decodable {
        let hostname: String?
    }

    let query: Query?
    let web: Web?
}

/// Runs searches and keeps results for 30 minutes so repeat searches don't use credit.
actor ListingSearchEngine {
    static let shared = ListingSearchEngine()

    private struct CachedPage {
        let date: Date
        let page: ListingSearchPage
    }

    private var cache: [String: CachedPage] = [:]
    private let lifetime: TimeInterval = 30 * 60

    func search(_ request: ListingSearchRequest, page: Int, apiKey: String, forceRefresh: Bool = false) async throws -> ListingSearchPage {
        let key = "\(request.id)#\(page)"
        if !forceRefresh, let cached = cache[key], Date().timeIntervalSince(cached.date) < lifetime {
            return cached.page
        }
        let result = try await BraveSearchClient(apiKey: apiKey)
            .search(query: request.query, freshness: request.freshness, page: page)
        cache[key] = CachedPage(date: Date(), page: result)
        ListingSearchUsage.record()
        return result
    }
}

/// Counts searches sent to Brave this month, so the user can watch their credit.
enum ListingSearchUsage {
    static func key(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM"
        return "listingSearch.usage.\(formatter.string(from: date))"
    }

    static func count(now: Date = Date(), defaults: UserDefaults = .standard) -> Int {
        defaults.integer(forKey: key(for: now))
    }

    static func record(now: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(count(now: now, defaults: defaults) + 1, forKey: key(for: now))
    }
}
