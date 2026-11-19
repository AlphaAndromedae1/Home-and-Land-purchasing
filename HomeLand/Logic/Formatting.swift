import Foundation

/// Reads prices typed as "450000", "$450,000", "450k" or "1.2m".
enum MoneyParser {
    static func parse(_ text: String) -> Double? {
        var cleaned = text.lowercased()
        for token in ["$", ",", " ", "\u{00A0}", "cad"] {
            cleaned = cleaned.replacingOccurrences(of: token, with: "")
        }
        var multiplier = 1.0
        if cleaned.hasSuffix("k") {
            multiplier = 1_000
            cleaned.removeLast()
        } else if cleaned.hasSuffix("m") {
            multiplier = 1_000_000
            cleaned.removeLast()
        }
        guard !cleaned.isEmpty,
              let value = Double(cleaned),
              value.isFinite,
              value >= 0,
              value < 1_000_000_000_000
        else { return nil }
        return value * multiplier
    }

    /// Text to pre-fill an editable price field.
    static func editingText(for value: Double?) -> String {
        guard let value else { return "" }
        if value == value.rounded(), abs(value) < 1_000_000_000_000 {
            return String(Int64(value))
        }
        return String(value)
    }
}

enum Fmt {
    private static let moneyFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "CAD"
        formatter.currencySymbol = "$"
        formatter.locale = Locale(identifier: "en_CA")
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        return moneyFormatter.string(from: NSNumber(value: value)) ?? "$\(Int64(value.rounded()))"
    }
}

/// Inline Markdown (bold, italics, links) for guide text.
enum Markdown {
    static func attributed(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
