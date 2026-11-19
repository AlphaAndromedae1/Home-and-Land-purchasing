import Foundation

/// Builds web searches. Listing sites don't offer public data feeds, so the app
/// searches their public pages through Google instead of copying their data.
enum SearchLinks {
    static func google(_ query: String, pastMonth: Bool = false) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/search"
        var items = [URLQueryItem(name: "q", value: query)]
        if pastMonth {
            items.append(URLQueryItem(name: "tbs", value: "qdr:m"))
        }
        components.queryItems = items
        return components.url ?? URL(string: "https://www.google.com")!
    }

    /// `"a"` for one term, `("a" OR "b")` for several, empty for none.
    static func anyOf(_ terms: [String]) -> String {
        let quoted = terms.map(\.trimmed).filter { !$0.isEmpty }.map { "\"\($0)\"" }
        switch quoted.count {
        case 0: return ""
        case 1: return quoted[0]
        default: return "(" + quoted.joined(separator: " OR ") + ")"
        }
    }

    static func query(site: String? = nil, terms: [String] = [], places: [String] = [], extra: String = "") -> String {
        [site.map { "site:\($0)" } ?? "", anyOf(terms), anyOf(places), extra]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func listings(site: String?, terms: [String], region: Region, pastMonth: Bool) -> URL {
        google(query(site: site, terms: terms, places: region.places), pastMonth: pastMonth)
    }

    static func taxSaleNotices(region: Region, pastMonth: Bool) -> URL {
        google(query(terms: ["sale of land for tax arrears"], places: region.places), pastMonth: pastMonth)
    }

    static func gazetteTaxSales(pastMonth: Bool) -> URL {
        google(query(site: "ontario.ca/document", terms: ["Sale of Land for Tax Arrears"]), pastMonth: pastMonth)
    }
}

enum ListingURLParser {
    /// Turns typed or pasted text into a web link, adding https:// if needed.
    static func normalizedURL(from text: String) -> URL? {
        let trimmedText = text.trimmed
        guard !trimmedText.isEmpty, !trimmedText.contains(" ") else { return nil }
        let lower = trimmedText.lowercased()
        let candidate = (lower.hasPrefix("http://") || lower.hasPrefix("https://")) ? trimmedText : "https://" + trimmedText
        guard let url = URL(string: candidate), let host = url.host, host.contains(".") else { return nil }
        return url
    }

    /// Finds the first link in shared text such as "Check this out https://…".
    static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, options: [], range: range)?.url
    }

    /// Guesses an address from an address-style slug, e.g.
    /// `realtor.ca/real-estate/27512345/123-main-street-hamilton` → "123 Main Street Hamilton".
    static func suggestedTitle(from url: URL) -> String? {
        guard let slug = url.pathComponents.last(where: { $0 != "/" }),
              slug.contains("-"),
              slug.rangeOfCharacter(from: .decimalDigits) != nil,
              slug.rangeOfCharacter(from: .letters) != nil
        else { return nil }
        let words = slug.split(separator: "-").map { word -> String in
            let text = String(word)
            return text.prefix(1).uppercased() + text.dropFirst()
        }
        return words.joined(separator: " ")
    }
}
