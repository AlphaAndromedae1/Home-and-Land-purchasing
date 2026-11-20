import Foundation

/// What the in-app browser reads from the page the user is looking at when they tap Save.
struct ClippedPage: Equatable {
    var url: URL
    var title: String
    var ogTitle: String?
    var description: String?
    var imageURL: URL?
    /// The start of the page's visible text.
    var text: String = ""
    var structured = StructuredListing()
}

/// Listing details from the page's schema.org (JSON-LD) data, when it has any.
struct StructuredListing: Equatable {
    var price: Double?
    var streetAddress: String?
    var locality: String?
    var bedrooms: Int?
    var bathrooms: Double?
}

/// Turns the page the user chose to save into a watchlist entry.
enum PageClipper {
    /// Runs in the page; returns one JSON string with the page's title, metadata and text.
    static let script = """
    (function () {
      function meta(name) {
        var el = document.querySelector('meta[property="' + name + '"]') || document.querySelector('meta[name="' + name + '"]');
        return el ? el.getAttribute('content') : null;
      }
      var ld = [];
      document.querySelectorAll('script[type="application/ld+json"]').forEach(function (s) {
        try { ld.push(JSON.parse(s.textContent)); } catch (e) {}
      });
      var canonical = document.querySelector('link[rel="canonical"]');
      var text = document.body ? (document.body.innerText || '') : '';
      return JSON.stringify({
        url: location.href,
        canonical: canonical ? canonical.href : null,
        title: document.title || '',
        ogTitle: meta('og:title'),
        description: meta('og:description') || meta('description'),
        image: meta('og:image'),
        jsonld: ld,
        text: text.slice(0, 6000)
      });
    })();
    """

    static func page(fromJSON data: Data, fallbackURL: URL) -> ClippedPage {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return ClippedPage(url: fallbackURL, title: "")
        }
        func string(_ key: String) -> String? {
            guard let value = (object[key] as? String)?.trimmed, !value.isEmpty else { return nil }
            return value
        }
        let location = string("url").flatMap { URL(string: $0) } ?? fallbackURL
        var pageURL = location
        if let canonical = string("canonical").flatMap({ URL(string: $0) }),
           canonical.host == location.host,
           ["http", "https"].contains(canonical.scheme?.lowercased() ?? "") {
            pageURL = canonical
        }
        return ClippedPage(
            url: pageURL,
            title: string("title") ?? "",
            ogTitle: string("ogTitle"),
            description: string("description"),
            imageURL: string("image").flatMap { URL(string: $0) },
            text: (object["text"] as? String) ?? "",
            structured: structured(from: (object["jsonld"] as? [Any]) ?? [])
        )
    }

    static func structured(from items: [Any]) -> StructuredListing {
        var result = StructuredListing()

        func number(_ value: Any?) -> Double? {
            if let number = value as? NSNumber { return number.doubleValue }
            if let text = value as? String { return MoneyParser.parse(text) }
            return nil
        }

        func visit(_ value: Any, depth: Int) {
            guard depth < 12 else { return }
            if let dictionary = value as? [String: Any] {
                if result.price == nil, let price = number(dictionary["price"]), price > 0 {
                    result.price = price
                }
                if result.streetAddress == nil, let street = dictionary["streetAddress"] as? String {
                    result.streetAddress = street
                    result.locality = dictionary["addressLocality"] as? String
                }
                if result.bedrooms == nil, let beds = number(dictionary["numberOfBedrooms"] ?? dictionary["numberOfRooms"]) {
                    result.bedrooms = Int(beds)
                }
                if result.bathrooms == nil,
                   let baths = number(dictionary["numberOfBathroomsTotal"] ?? dictionary["numberOfFullBathrooms"]) {
                    result.bathrooms = baths
                }
                for child in dictionary.values {
                    visit(child, depth: depth + 1)
                }
            } else if let array = value as? [Any] {
                for child in array {
                    visit(child, depth: depth + 1)
                }
            }
        }

        for item in items {
            visit(item, depth: 0)
        }
        return result
    }

    static func details(for page: ClippedPage) -> ListingDetails {
        let headline = page.ogTitle ?? page.title
        var details = ListingParser.details(title: headline, text: [headline, page.description ?? ""].joined(separator: " "))

        // Fill gaps from the page's visible text.
        let body = ListingParser.details(title: "", text: page.text)
        if details.price == nil {
            details.price = body.price
            details.isRental = body.isRental
        }
        details.bedrooms = details.bedrooms ?? body.bedrooms
        details.bathrooms = details.bathrooms ?? body.bathrooms
        details.acres = details.acres ?? body.acres
        details.saleType = details.saleType ?? body.saleType
        details.kind = details.kind ?? body.kind

        // Structured data is the most reliable, so it wins.
        let structured = page.structured
        if let price = structured.price, price >= 10_000 {
            details.price = price
            details.isRental = false
        }
        if let street = structured.streetAddress?.trimmed, !street.isEmpty {
            let locality = structured.locality?.trimmed ?? ""
            details.address = locality.isEmpty ? street : "\(street), \(locality)"
            if !locality.isEmpty {
                details.municipality = locality
            }
        }
        if let beds = structured.bedrooms { details.bedrooms = beds }
        if let baths = structured.bathrooms { details.bathrooms = baths }
        return details
    }

    static func property(from page: ClippedPage) -> Property {
        let details = details(for: page)
        let kind = details.kind ?? .house
        let fallbackTitle = ListingParser.cleanTitle(page.ogTitle ?? page.title)
        var property = Property(
            title: details.address ?? (fallbackTitle.isEmpty ? "Saved listing" : fallbackTitle),
            municipality: details.municipality ?? "",
            region: details.municipality.flatMap { Region.matching(municipality: $0) } ?? .anywhere,
            saleType: details.saleType ?? .regular,
            kind: kind,
            askingPrice: details.isRental ? nil : details.price,
            lotSize: details.acres.map { "\($0.formatted()) acres" } ?? "",
            listingURL: page.url.absoluteString,
            notes: page.description ?? ""
        )
        if kind.sizeUnit == .acres, let acres = details.acres {
            property.analysis.size = acres
        }
        return property
    }
}
