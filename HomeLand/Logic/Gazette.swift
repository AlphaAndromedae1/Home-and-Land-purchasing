import Foundation

// Tax sale notices from the Ontario Gazette on ontario.ca.
//
// ontario.ca content may be reproduced for non-commercial purposes if credit is
// given, Crown copyright is acknowledged and the content isn't changed. The app
// shows each notice's text as published, with a credit line and a link back.

struct GazetteIssue: Codable, Hashable {
    var volume: Int
    var number: Int
    var date: Date?
    /// e.g. "November 7, 2026"
    var dateText: String
    var url: URL

    var title: String {
        "Volume \(volume), Issue \(number)" + (dateText.isEmpty ? "" : " (\(dateText))")
    }

    var year: Int? {
        date.map { GazetteParser.calendar.component(.year, from: $0) }
    }
}

enum TaxSaleMethod: String, Codable {
    case tender
    case auction

    var name: String {
        switch self {
        case .tender: return "Public tender"
        case .auction: return "Public auction"
        }
    }
}

/// One paragraph of a notice, as published.
struct NoticeBlock: Codable, Hashable {
    var text: String
    var isListItem: Bool
}

/// One property offered in a tax sale notice.
struct TaxSaleParcel: Identifiable, Codable, Hashable {
    var id: String
    var description: String
    var address: String?
    var minimumTender: Double?
    var assessedValue: Double?
    var pin: String?
    var rollNumber: String?
}

struct GazetteContact: Codable, Hashable {
    var name: String?
    var phone: String?
    var email: String?

    var isEmpty: Bool {
        name == nil && phone == nil && email == nil
    }
}

/// One municipality's tax sale notice.
struct GazetteNotice: Identifiable, Codable, Hashable {
    var id: String
    var issue: GazetteIssue
    var sectionURL: URL
    /// The heading as published, e.g. "The Corporation of the City of Windsor".
    var heading: String
    /// Short name, e.g. "Windsor".
    var municipality: String
    var method: TaxSaleMethod
    /// Tender closing time, or the auction time.
    var closes: Date?
    /// The Gazette's notice number, e.g. "159-P387".
    var noticeNumber: String?
    var parcels: [TaxSaleParcel]
    var blocks: [NoticeBlock]
    var contact: GazetteContact

    var region: Region? {
        Region.matching(municipality: municipality)
    }

    var lowestMinimum: Double? {
        parcels.compactMap(\.minimumTender).min()
    }

    func isClosed(now: Date = Date()) -> Bool {
        closes.map { $0 < now } ?? false
    }

    var credit: String {
        let year = issue.year.map { ", \($0)" } ?? ""
        return "Source: Ontario Gazette, \(issue.title). © King's Printer for Ontario\(year). Reproduced without changes for non-commercial use."
    }
}

enum GazetteParser {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Toronto") ?? .current
        return calendar
    }()

    private static let monthNumbers = [
        "january": 1, "february": 2, "march": 3, "april": 4, "may": 5, "june": 6,
        "july": 7, "august": 8, "september": 9, "october": 10, "november": 11, "december": 12,
    ]
    private static let monthPattern = "January|February|March|April|May|June|July|August|September|October|November|December"

    // MARK: Index and issue pages

    /// Issues listed on the Gazette index page, newest first.
    static func issues(fromIndexHTML html: String, baseURL: URL = GazetteClient.baseURL) -> [GazetteIssue] {
        let pattern = #"href="(/document/ontario-gazette-volume-(\d+)-issue-(\d+)-([a-z]+)-(\d{1,2})-(\d{4}))""#
        var seen = Set<String>()
        var issues: [GazetteIssue] = []
        for groups in allMatches(pattern, in: html) {
            guard let path = groups[1], seen.insert(path).inserted,
                  let volume = groups[2].flatMap({ Int($0) }),
                  let number = groups[3].flatMap({ Int($0) }),
                  let monthName = groups[4],
                  let day = groups[5].flatMap({ Int($0) }),
                  let year = groups[6].flatMap({ Int($0) }),
                  let url = URL(string: path, relativeTo: baseURL)?.absoluteURL
            else { continue }
            let month = monthNumbers[monthName] ?? 0
            issues.append(GazetteIssue(
                volume: volume,
                number: number,
                date: month > 0 ? calendar.date(from: DateComponents(year: year, month: month, day: day)) : nil,
                dateText: month > 0 ? "\(monthName.capitalized) \(day), \(year)" : "",
                url: url
            ))
        }
        return issues
    }

    /// Links to an issue's tax sale sections ("sale-land-tax-arrears-…").
    static func taxSaleSectionURLs(fromIssueHTML html: String, baseURL: URL = GazetteClient.baseURL) -> [URL] {
        let pattern = #"href="(?:https?://(?:www\.)?ontario\.ca)?(/document/ontario-gazette-volume-[^"/#?]+/sale-land[^"#?]*)""#
        var seen = Set<String>()
        return allMatches(pattern, in: html).compactMap { groups in
            guard let path = groups[1], seen.insert(path).inserted else { return nil }
            return URL(string: path, relativeTo: baseURL)?.absoluteURL
        }
    }

    // MARK: Notices

    static func notices(fromSectionHTML html: String, sectionURL: URL, issue: GazetteIssue) -> [GazetteNotice] {
        let parts = mainContent(of: html).components(separatedBy: "<h2")
        var notices: [GazetteNotice] = []
        for (index, part) in parts.dropFirst().enumerated() {
            guard let headingEnd = part.range(of: "</h2>", options: .caseInsensitive) else { continue }
            var headingHTML = String(part[..<headingEnd.lowerBound])
            if let tagEnd = headingHTML.firstIndex(of: ">") {
                headingHTML = String(headingHTML[headingHTML.index(after: tagEnd)...])
            }
            let heading = text(fromHTML: headingHTML).replacingOccurrences(of: "\n", with: " ")
            let lowerHeading = heading.lowercased()
            guard !heading.isEmpty,
                  !["on this page", "contents", "questions or comments"].contains(where: { lowerHeading.hasPrefix($0) })
            else { continue }

            let content = parseContent(String(part[headingEnd.upperBound...]))
            guard !content.blocks.isEmpty else { continue }

            let takeNotice = content.topLevel.first { $0.lowercased().contains("take notice") } ?? content.topLevel.first ?? ""
            let noticeNumber = content.blocks.lazy.compactMap { firstGroup(#"^\((\d{3}-P\d+)\)"#, in: $0.text) }.first
            let id = "\(issue.volume)-\(issue.number)-" + (noticeNumber ?? "\(sectionURL.lastPathComponent)-\(index)")
            let noticeParcels = parcels(items: content.items, topLevel: content.topLevel, noticeID: id)
            // Skip headings that aren't notices, such as site menus.
            guard takeNotice.lowercased().contains("take notice") || noticeNumber != nil || !noticeParcels.isEmpty else { continue }

            notices.append(GazetteNotice(
                id: id,
                issue: issue,
                sectionURL: sectionURL,
                heading: heading,
                municipality: shortName(fromHeading: heading),
                method: takeNotice.lowercased().contains("public auction") ? .auction : .tender,
                closes: closingDate(in: takeNotice),
                noticeNumber: noticeNumber,
                parcels: noticeParcels,
                blocks: content.blocks,
                contact: contact(in: content.topLevel)
            ))
        }
        return notices
    }

    /// Keeps the newest copy of notices that ran in more than one issue.
    static func deduplicated(_ notices: [GazetteNotice]) -> [GazetteNotice] {
        var bestByKey: [String: GazetteNotice] = [:]
        var order: [String] = []
        for notice in notices {
            let key = notice.noticeNumber ?? notice.id
            if let existing = bestByKey[key] {
                if (notice.issue.volume, notice.issue.number) > (existing.issue.volume, existing.issue.number) {
                    bestByKey[key] = notice
                }
            } else {
                bestByKey[key] = notice
                order.append(key)
            }
        }
        return order.compactMap { bestByKey[$0] }
    }

    /// "The Corporation of the Township of Nipigon" → "Nipigon".
    static func shortName(fromHeading heading: String) -> String {
        var name = heading.trimmed
        for prefix in ["the corporation of the ", "the corporation of ", "the municipality or board of ", "the "]
        where name.lowercased().hasPrefix(prefix) {
            name = String(name.dropFirst(prefix.count))
            break
        }
        let kinds = [
            "united townships of ", "united counties of ", "regional municipality of ", "township of ",
            "town of ", "city of ", "municipality of ", "county of ", "village of ", "district of ",
        ]
        // Some headings stack them, e.g. "Municipality of City of Peterborough".
        while let kind = kinds.first(where: { name.lowercased().hasPrefix($0) }) {
            name = String(name.dropFirst(kind.count))
        }
        name = name.trimmed
        if name == name.uppercased() {
            name = name.capitalized
        }
        return name.isEmpty ? heading.trimmed : name
    }

    /// The tender closing or auction date and time in a "Take Notice" paragraph.
    static func closingDate(in text: String) -> Date? {
        var year = 0, month = 0, day = 0
        if let groups = firstMatch("(\(monthPattern))\\s+(\\d{1,2})(?:st|nd|rd|th)?,?\\s+(\\d{4})", in: text),
           let monthName = groups[1], let dayText = groups[2], let yearText = groups[3] {
            month = monthNumbers[monthName.lowercased()] ?? 0
            day = Int(dayText) ?? 0
            year = Int(yearText) ?? 0
        } else if let groups = firstMatch("(\\d{1,2})\\s*(?:st|nd|rd|th)?\\s+day\\s+of\\s+(\(monthPattern)),?\\s+(\\d{4})", in: text),
                  let dayText = groups[1], let monthName = groups[2], let yearText = groups[3] {
            month = monthNumbers[monthName.lowercased()] ?? 0
            day = Int(dayText) ?? 0
            year = Int(yearText) ?? 0
        }
        guard year > 0, month > 0, day > 0 else { return nil }

        var hour = 15
        var minute = 0
        if let groups = firstMatch(#"(\d{1,2})(?::(\d{2}))?\s*([ap])\.?\s*m\b"#, in: text),
           let hourText = groups[1], let parsedHour = Int(hourText), (1...12).contains(parsedHour) {
            let isPM = groups[3]?.lowercased() == "p"
            hour = parsedHour % 12 + (isPM ? 12 : 0)
            minute = groups[2].flatMap { Int($0) } ?? 0
        } else if let groups = firstMatch(#"\b(one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve)\s+o['’]\s?clock"#, in: text),
                  let word = groups[1]?.lowercased() {
            let words = ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven", "twelve"]
            let parsedHour = (words.firstIndex(of: word) ?? 2) + 1
            hour = parsedHour < 8 ? parsedHour + 12 : parsedHour
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))
    }

    // MARK: Parcels

    static func parcels(items: [[String]], topLevel: [String], noticeID: String) -> [TaxSaleParcel] {
        var groups = items.filter { item in item.contains { $0.lowercased().contains("minimum tender") } }
        if groups.isEmpty {
            groups = paragraphGroups(topLevel)
            // Notes that mention a PIN ("Please Note: …") aren't properties of their own.
            let priced = groups.filter { group in group.contains { $0.lowercased().contains("minimum tender") } }
            if !priced.isEmpty { groups = priced }
        }
        return groups.enumerated().compactMap { index, paragraphs in
            parcel(from: paragraphs, id: "\(noticeID)-\(index)")
        }
    }

    /// Groups property paragraphs that follow "Description of Land(s):" when they aren't in a list.
    private static func paragraphGroups(_ paragraphs: [String]) -> [[String]] {
        guard let start = paragraphs.firstIndex(where: { $0.lowercased().hasPrefix("description of land") }) else { return [] }
        var groups: [[String]] = []
        var current: [String] = []
        let header = paragraphs[start]
        if let colon = header.firstIndex(of: ":") {
            let rest = String(header[header.index(after: colon)...]).trimmed
            if rest.count > 20 { current = [rest] }
        }
        for text in paragraphs[(start + 1)...] {
            let lower = text.lowercased()
            if lower.hasPrefix("minimum tender") {
                current.append(text)
                groups.append(current)
                current = []
            } else if lower.contains("assessed value"), !current.isEmpty {
                current.append(text)
            } else if looksLikeParcel(text) {
                // A second description paragraph continues the current property.
                current.append(text)
            } else if !groups.isEmpty || !current.isEmpty {
                break
            }
        }
        if !current.isEmpty { groups.append(current) }
        return groups
    }

    private static func looksLikeParcel(_ text: String) -> Bool {
        text.range(of: #"\b(PIN|Roll|LT|PT|PCL|CON|Lot|Plan|Part|Block|BLK|Concession)\b"#, options: .regularExpression) != nil
            || text.range(of: #"^\d+[A-Za-z]?\s+[A-Za-z]"#, options: .regularExpression) != nil
    }

    private static func parcel(from paragraphs: [String], id: String) -> TaxSaleParcel? {
        let description = paragraphs.filter { paragraph in
            let lower = paragraph.lowercased()
            return !lower.contains("minimum tender") && !lower.contains("assessed value")
        }.joined(separator: " ")
        let minimum = paragraphs.first { $0.lowercased().contains("minimum tender") }.flatMap { firstMoney(in: $0) }
        let assessed = paragraphs.first { $0.lowercased().contains("assessed value") }.flatMap { firstMoney(in: $0) }
        guard !description.isEmpty || minimum != nil else { return nil }
        return TaxSaleParcel(
            id: id,
            description: description,
            address: address(fromDescription: description),
            minimumTender: minimum,
            assessedValue: assessed,
            pin: firstMatch(#"PIN\s*#?\s*(\d{5})\s*-\s*(\d{4})"#, in: description).flatMap { groups in
                guard let first = groups[1], let second = groups[2] else { return nil }
                return "\(first)-\(second)"
            },
            rollNumber: firstGroup(#"Roll\s*(?:No\.?|Number|#)?\s*:?\s*#?\s*(\d[\d\s-]{8,}\d)"#, in: description)
                .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
        )
    }

    /// A street address like "379 Chamberlin Rd." from a legal description.
    static func address(fromDescription description: String) -> String? {
        if let labelled = firstGroup(#"Address:\s*([^,;]+)"#, in: description) {
            let address = cleanAddress(labelled)
            if !address.isEmpty { return address }
        }
        let pieces = description.components(separatedBy: CharacterSet(charactersIn: ";,")).map { cleanAddress($0) }
        let numbered = #"^\d+[A-Za-z]?(?:-\d+)?\s+(?!(?:and|to|of|&)\b)[A-Za-z][A-Za-z.'-]*"#
        if let street = pieces.first(where: { piece in
            piece.count <= 60
                && piece.range(of: numbered, options: [.regularExpression, .caseInsensitive]) != nil
                && piece.range(of: #"\d{5}-\d{4}"#, options: .regularExpression) == nil
        }) {
            return street
        }
        // Unnumbered lots, e.g. "Lafferty Ave (S/S) (Vacant Land)".
        let named = #"^[A-Za-z][A-Za-z'.-]*(?:\s+[A-Za-z][A-Za-z'.-]*){0,3}\s+(Ave|Avenue|St|Street|Rd|Road|Dr|Drive|Cres|Crescent|Crt|Court|Line|Highway|Hwy|Trail|Lane|Ln|Way|Blvd|Boulevard|Place|Sideroad|Parkway|Terrace|Circle)\.?$"#
        return pieces.first { $0.range(of: named, options: [.regularExpression, .caseInsensitive]) != nil }
    }

    /// Cuts the legal description and notes off an address piece.
    private static func cleanAddress(_ text: String) -> String {
        var address = text.trimmed
        let legal = #"\s+(?:(?:(?:PT|PTS|PART|PARTS)\s+)?(?:LT|LOT|PL|PLAN|PCL|CON|BLK|BLOCK|PT|PTS)\s+\d|(?:PIN|Legal|Roll|Registration|Being)\b)"#
        if let range = address.range(of: legal, options: [.regularExpression, .caseInsensitive]) {
            address = String(address[..<range.lowerBound])
        }
        address = address.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
        return address.trimmed
    }

    private static func contact(in paragraphs: [String]) -> GazetteContact {
        guard let index = paragraphs.firstIndex(where: { $0.lowercased().contains("for further information") }) else {
            return GazetteContact()
        }
        let candidates = [paragraphs[index]] + (index + 1 < paragraphs.count ? [paragraphs[index + 1]] : [])
        let combined = candidates.joined(separator: "\n")
        let block = candidates.first { $0.contains("\n") } ?? ""
        let lines = block.components(separatedBy: "\n").map(\.trimmed).filter { !$0.isEmpty }
        let name = lines.first { line in
            let lower = line.lowercased()
            return !lower.contains("for further information") && !line.contains("@")
                && !lower.hasPrefix("tel") && !lower.hasPrefix("phone") && !lower.hasPrefix("www")
                && line.range(of: #"^\(\d{3}-P\d+\)"#, options: .regularExpression) == nil
        }
        return GazetteContact(
            name: name,
            phone: firstGroup(#"(\(?\d{3}\)?[\s.-]?\d{3}[\s.-]\d{4})"#, in: combined),
            email: firstGroup(#"([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})"#, in: combined)
        )
    }

    // MARK: HTML helpers

    /// The page's article body, without site navigation and footer.
    static func mainContent(of html: String) -> String {
        var content = Substring(html)
        for marker in ["id=\"toc-end\"", "class=\"main-content\""] {
            if let start = content.range(of: marker) {
                content = content[start.upperBound...]
                break
            }
        }
        for marker in ["</main>", "Questions or comments"] {
            if let end = content.range(of: marker) {
                content = content[..<end.lowerBound]
                break
            }
        }
        return String(content)
    }

    private struct ParsedContent {
        var blocks: [NoticeBlock] = []
        var items: [[String]] = []
        var topLevel: [String] = []
    }

    /// Paragraphs and list items in order, stopping after the notice number.
    private static func parseContent(_ html: String) -> ParsedContent {
        var result = ParsedContent()
        // Swap each <li>…</li> for a marker so top-level paragraphs and list items stay in order.
        var itemHTML: [String] = []
        let marked = replaceMatches(#"<li\b[^>]*>(.*?)</li>"#, in: html) { groups in
            itemHTML.append(groups[1] ?? "")
            return "\u{1}LI\(itemHTML.count - 1)\u{1}"
        }
        for groups in allMatches(#"\x{01}LI(\d+)\x{01}|<p\b[^>]*>(.*?)</p>"#, in: marked) {
            if let indexText = groups[1], let index = Int(indexText), index < itemHTML.count {
                var paragraphs = allMatches(#"<p\b[^>]*>(.*?)</p>"#, in: itemHTML[index]).compactMap { $0[1] }.map { text(fromHTML: $0) }
                if paragraphs.isEmpty { paragraphs = [text(fromHTML: itemHTML[index])] }
                paragraphs = paragraphs.filter { !$0.isEmpty }
                guard !paragraphs.isEmpty else { continue }
                result.items.append(paragraphs)
                result.blocks += paragraphs.map { NoticeBlock(text: $0, isListItem: true) }
            } else if let inner = groups[2] {
                let paragraph = text(fromHTML: inner)
                guard !paragraph.isEmpty else { continue }
                result.topLevel.append(paragraph)
                result.blocks.append(NoticeBlock(text: paragraph, isListItem: false))
                if paragraph.range(of: #"^\(\d{3}-P\d+\)"#, options: .regularExpression) != nil {
                    break
                }
            }
        }
        return result
    }

    /// Plain text from an HTML fragment: <br> becomes a new line, tags are removed and entities decoded.
    static func text(fromHTML html: String) -> String {
        var text = html.replacingOccurrences(of: #"<br\s*/?>"#, with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        text = decodeEntities(text)
        return text.components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"[ \t\x{00A0}\r]+"#, with: " ", options: .regularExpression).trimmed }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    static func decodeEntities(_ text: String) -> String {
        guard text.contains("&") else { return text }
        var result = replaceMatches(#"&#(x?)([0-9a-fA-F]+);"#, in: text) { groups in
            let isHex = groups[1] == "x"
            guard let digits = groups[2],
                  let code = UInt32(digits, radix: isHex ? 16 : 10),
                  let scalar = Unicode.Scalar(code)
            else { return "" }
            return String(Character(scalar))
        }
        let named = [
            "&nbsp;": " ", "&rsquo;": "’", "&lsquo;": "‘", "&rdquo;": "”", "&ldquo;": "“", "&ndash;": "–",
            "&mdash;": "—", "&hellip;": "…", "&quot;": "\"", "&apos;": "'", "&lt;": "<", "&gt;": ">",
            "&eacute;": "é", "&egrave;": "è", "&agrave;": "à", "&ccedil;": "ç", "&ocirc;": "ô", "&ecirc;": "ê",
            "&acirc;": "â", "&icirc;": "î", "&ucirc;": "û", "&euml;": "ë", "&iuml;": "ï", "&deg;": "°",
            "&frac12;": "½", "&frac14;": "¼", "&frac34;": "¾", "&sup2;": "²", "&shy;": "",
        ]
        for (entity, character) in named {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        return result.replacingOccurrences(of: "&amp;", with: "&")
    }

    static func firstMoney(in text: String) -> Double? {
        firstGroup(#"\$\s?(\d{1,3}(?:,\d{3})+(?:\.\d{1,2})?|\d+(?:\.\d{1,2})?)"#, in: text)
            .flatMap { Double($0.replacingOccurrences(of: ",", with: "")) }
    }

    // MARK: Regex helpers

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
    }

    private static func groups(of match: NSTextCheckingResult, in text: String) -> [String?] {
        (0..<match.numberOfRanges).map { index in
            let range = match.range(at: index)
            guard range.location != NSNotFound, let swiftRange = Range(range, in: text) else { return nil }
            return String(text[swiftRange])
        }
    }

    static func allMatches(_ pattern: String, in text: String) -> [[String?]] {
        guard let regex = regex(pattern) else { return [] }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).map { groups(of: $0, in: text) }
    }

    static func firstMatch(_ pattern: String, in text: String) -> [String?]? {
        guard let regex = regex(pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
        else { return nil }
        return groups(of: match, in: text)
    }

    static func firstGroup(_ pattern: String, in text: String) -> String? {
        firstMatch(pattern, in: text)?[1]?.trimmed
    }

    private static func replaceMatches(_ pattern: String, in text: String, with transform: ([String?]) -> String) -> String {
        guard let regex = regex(pattern) else { return text }
        var result = ""
        var cursor = text.startIndex
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text) else { continue }
            result += text[cursor..<range.lowerBound]
            result += transform(groups(of: match, in: text))
            cursor = range.upperBound
        }
        result += text[cursor...]
        return result
    }
}

enum GazetteError: LocalizedError {
    case noIssues
    case badResponse(Int)
    case network

    var errorDescription: String? {
        switch self {
        case .noIssues: return "Couldn't find any Gazette issues on ontario.ca. The page layout may have changed."
        case let .badResponse(code): return "ontario.ca returned an error (code \(code)). Try again later."
        case .network: return "Couldn't reach ontario.ca. Check your internet connection."
        }
    }
}

struct GazetteClient {
    static let baseURL = URL(string: "https://www.ontario.ca")!
    static let indexURL = URL(string: "https://www.ontario.ca/search/ontario-gazette")!

    var session: URLSession = .shared

    func html(at url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        let reply: (Data, URLResponse)
        do {
            reply = try await session.data(for: request)
        } catch {
            throw GazetteError.network
        }
        let (data, response) = reply
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw GazetteError.badResponse(status) }
        return String(decoding: data, as: UTF8.self)
    }

    /// Tax sale notices from the newest `issueCount` issues, one request at a time.
    func recentNotices(issueCount: Int) async throws -> [GazetteNotice] {
        let issues = GazetteParser.issues(fromIndexHTML: try await html(at: Self.indexURL)).prefix(issueCount)
        guard !issues.isEmpty else { throw GazetteError.noIssues }
        var notices: [GazetteNotice] = []
        for issue in issues {
            guard let issueHTML = try? await html(at: issue.url) else { continue }
            for section in GazetteParser.taxSaleSectionURLs(fromIssueHTML: issueHTML) {
                guard let sectionHTML = try? await html(at: section) else { continue }
                notices += GazetteParser.notices(fromSectionHTML: sectionHTML, sectionURL: section, issue: issue)
            }
        }
        return GazetteParser.deduplicated(notices)
    }
}

/// Turns a tax sale property into a watchlist entry.
enum GazetteImport {
    static func title(for parcel: TaxSaleParcel, in notice: GazetteNotice) -> String {
        parcel.address ?? "\(notice.municipality) tax sale property"
    }

    static func property(for parcel: TaxSaleParcel, in notice: GazetteNotice) -> Property {
        let isVacant = parcel.address == nil || parcel.address?.hasPrefix("0 ") == true
        let kind = ListingParser.kind(in: parcel.description) ?? (isVacant ? .vacantLand : .house)

        var notes = [parcel.description]
        if let assessed = parcel.assessedValue { notes.append("Assessed value: \(Fmt.money(assessed))") }
        if let pin = parcel.pin { notes.append("PIN: \(pin)") }
        if let roll = parcel.rollNumber { notes.append("Roll number: \(roll)") }
        notes.append("\(notice.method.name). Source: Ontario Gazette, \(notice.issue.title)"
                     + (notice.noticeNumber.map { ", notice \($0)" } ?? "") + ".")

        var contacts: [PropertyContact] = []
        if !notice.contact.isEmpty {
            contacts.append(PropertyContact(
                role: .municipality,
                name: notice.contact.name ?? "",
                company: notice.heading,
                phone: notice.contact.phone ?? "",
                email: notice.contact.email ?? ""
            ))
        }

        return Property(
            title: title(for: parcel, in: notice),
            municipality: notice.municipality,
            region: notice.region ?? .anywhere,
            saleType: .taxSale,
            kind: kind,
            askingPrice: parcel.minimumTender,
            listingURL: notice.sectionURL.absoluteString,
            deadline: notice.closes,
            notes: notes.joined(separator: "\n"),
            contacts: contacts
        )
    }
}
