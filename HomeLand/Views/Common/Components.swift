import SwiftUI

/// Lays out views left to right, wrapping onto new rows as needed.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(maxWidth: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrange(maxWidth: bounds.width, subviews: subviews).origins
        for (index, origin) in origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(maxWidth: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widest: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: widest, height: y + rowHeight), origins)
    }
}

/// A selectable keyword pill.
struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? Color.accentColor : Color(.secondarySystemFill), in: Capsule())
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A small coloured label, e.g. a sale type.
struct TagBadge: View {
    let text: String
    let color: Color
    var symbol: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol)
            }
            Text(text)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundStyle(color)
        .background(color.opacity(0.15), in: Capsule())
    }
}

/// A label and value on one row.
struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// A money amount on one row, for calculators.
struct AmountRow: View {
    let label: String
    let amount: Double
    var emphasized = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 12)
            Text(Fmt.money(amount))
                .monospacedDigit()
        }
        .font(emphasized ? .headline : .body)
    }
}

/// A tappable row that runs a search or opens a page.
struct SearchActionRow: View {
    let title: String
    let subtitle: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
    }
}

/// A tinted box for tips and warnings.
struct Callout: View {
    let text: String
    let symbol: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(Markdown.attributed(text))
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// A number entry row that edits an optional Double. Accepts "450000", "$450,000" or "450k".
struct NumberField: View {
    let title: String
    @Binding var value: Double?
    var placeholder: String = ""
    var suffix: String? = nil

    @State private var text = ""
    @State private var didLoad = false

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            TextField(placeholder, text: $text)
                .keyboardType(.numbersAndPunctuation)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 140)
            if let suffix {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            text = MoneyParser.editingText(for: value)
        }
        .onChange(of: text) { newText in
            let parsed = MoneyParser.parse(newText)
            if parsed != value {
                value = parsed
            }
        }
    }
}

extension Binding where Value == Double {
    /// Lets `NumberField` edit a non-optional number; clearing the field sets `fallback`.
    func optional(fallback: Double = 0) -> Binding<Double?> {
        Binding<Double?>(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 ?? fallback }
        )
    }
}

/// Five tappable stars. Tapping the current rating clears it.
struct StarRatingPicker: View {
    let title: String
    let detail: String
    @Binding var rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    ForEach(1...5, id: \.self) { star in
                        Button {
                            rating = rating == star ? 0 : star
                        } label: {
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundStyle(star <= rating ? Color.orange : Color.secondary)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(star) of 5 stars")
                    }
                }
            }
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

/// Read-only stars.
struct StarsView: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= count ? "star.fill" : "star")
            }
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) out of 5 stars")
    }
}

/// A circular score out of 100.
struct ScoreRing: View {
    let score: Int
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 7)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
    }
}

/// One part of a score, as a labelled bar.
struct ScoreBar: View {
    let label: String
    let points: Double
    let maximum: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(points.rounded())) / \(Int(maximum))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            ProgressView(value: min(max(points, 0), maximum), total: maximum)
                .tint(color)
        }
    }
}

/// Days left until a deadline, coloured by urgency.
struct DeadlineLabel: View {
    let date: Date

    var body: some View {
        let days = Self.daysUntil(date)
        Label(Self.text(days: days, date: date), systemImage: "clock")
            .font(.caption.weight(.medium))
            .foregroundStyle(days < 0 ? Color.secondary : (days <= 3 ? Color.red : Color.orange))
    }

    static func daysUntil(_ date: Date, now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    static func text(days: Int, date: Date) -> String {
        let when = date.formatted(date: .abbreviated, time: .shortened)
        switch days {
        case ..<0: return "Deadline passed · \(when)"
        case 0: return "Deadline today · \(when)"
        case 1: return "Deadline tomorrow · \(when)"
        default: return "Deadline in \(days) days · \(when)"
        }
    }
}
