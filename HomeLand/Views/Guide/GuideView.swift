import SwiftUI
import UIKit

struct GuideView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Ways to buy") {
                    ForEach(Guide.saleTypes) { section in
                        NavigationLink {
                            GuideSectionView(section: section)
                        } label: {
                            GuideRowLabel(title: section.title, subtitle: section.summary, symbol: section.symbol)
                        }
                    }
                }
                Section("Southern Ontario regions") {
                    ForEach(Region.southernRegions) { region in
                        NavigationLink {
                            RegionDetailView(region: region)
                        } label: {
                            GuideRowLabel(title: region.name, subtitle: region.subtitle, symbol: "map")
                        }
                    }
                }
                Section("Before you buy") {
                    ForEach(Guide.beforeYouBuy) { section in
                        NavigationLink {
                            GuideSectionView(section: section)
                        } label: {
                            GuideRowLabel(title: section.title, subtitle: section.summary, symbol: section.symbol)
                        }
                    }
                    NavigationLink {
                        KeywordsView()
                    } label: {
                        GuideRowLabel(title: "Search keywords", subtitle: "Words that flag distressed sales and land", symbol: "textformat.abc")
                    }
                }
                Section {
                    Text(Guide.disclaimer)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Ontario Guide")
        }
    }
}

struct GuideRowLabel: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct GuideSectionView: View {
    let section: GuideSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(section.summary)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                ForEach(Array(section.blocks.enumerated()), id: \.offset) { _, block in
                    GuideBlockView(block: block)
                }
                Text(Guide.disclaimer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 700, alignment: .leading)
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(section.title)
    }
}

struct GuideBlockView: View {
    let block: GuideBlock
    @Environment(\.openURL) private var openURL

    var body: some View {
        switch block {
        case .text(let text):
            Text(Markdown.attributed(text))
                .fixedSize(horizontal: false, vertical: true)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(Markdown.attributed(item))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .steps(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(index + 1).")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Text(Markdown.attributed(item))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        case .tip(let text):
            Callout(text: text, symbol: "lightbulb", color: .blue)
        case .warning(let text):
            Callout(text: text, symbol: "exclamationmark.triangle", color: .orange)
        case .table(let headers, let rows):
            GuideTableView(headers: headers, rows: rows)
        case .link(let title, let url):
            Button {
                openURL(url)
            } label: {
                Label(title, systemImage: "arrow.up.forward.square")
            }
        }
    }
}

/// Shows a table as one card per row, which reads well on a phone.
struct GuideTableView: View {
    let headers: [String]
    let rows: [[String]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 6) {
                    Text(row.first ?? "")
                        .font(.headline)
                    ForEach(Array(zip(headers.dropFirst(), row.dropFirst()).enumerated()), id: \.offset) { _, pair in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(pair.0)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(pair.1)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

struct RegionDetailView: View {
    let region: Region
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Text(region.overview)
            }
            Section("What to watch for") {
                ForEach(region.tips, id: \.self) { tip in
                    Text(Markdown.attributed(tip))
                }
            }
            Section("Towns and counties") {
                FlowLayout(spacing: 8) {
                    ForEach(region.places, id: \.self) { place in
                        TagBadge(text: place, color: .accentColor)
                    }
                }
                .padding(.vertical, 4)
            }
            Section {
                SearchActionRow(title: "Power of sale listings", subtitle: "Realtor.ca pages from the past month", symbol: "building.columns") {
                    openURL(SearchLinks.listings(site: "realtor.ca/real-estate", terms: ["power of sale", "bank sale", "mortgagee sale"], region: region, pastMonth: true))
                }
                SearchActionRow(title: "Estate sales and fixer-uppers", subtitle: "Realtor.ca pages from the past month", symbol: "hammer") {
                    openURL(SearchLinks.listings(site: "realtor.ca/real-estate", terms: ["estate sale", "contractor special", "handyman special", "needs TLC"], region: region, pastMonth: true))
                }
                SearchActionRow(title: "Vacant land and lots", subtitle: "Realtor.ca pages from the past month", symbol: "map") {
                    openURL(SearchLinks.listings(site: "realtor.ca/real-estate", terms: ["vacant land", "building lot", "acreage"], region: region, pastMonth: true))
                }
                SearchActionRow(title: "Tax sale notices", subtitle: "“Sale of land for tax arrears”", symbol: "doc.text.magnifyingglass") {
                    openURL(SearchLinks.taxSaleNotices(region: region, pastMonth: false))
                }
            } header: {
                Text("Quick searches")
            } footer: {
                Text("Searches run through Google, so the newest listings may not show yet.")
            }
        }
        .navigationTitle(region.name)
    }
}

struct KeywordsView: View {
    @State private var copied: String?

    var body: some View {
        List {
            Section {
                ForEach(Keywords.distressed) { keyword in
                    row(keyword)
                }
            } header: {
                Text("Signs of a motivated or distressed seller")
            } footer: {
                Text("Tap a keyword to copy it, then paste it into a listing site's keyword search.")
            }
            Section("Land and development") {
                ForEach(Keywords.land) { keyword in
                    row(keyword)
                }
            }
        }
        .navigationTitle("Search keywords")
    }

    private func row(_ keyword: SearchKeyword) -> some View {
        Button {
            UIPasteboard.general.string = keyword.term
            copied = keyword.term
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("“\(keyword.term)”")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(keyword.meaning)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: copied == keyword.term ? "checkmark" : "doc.on.doc")
                    .foregroundStyle(.tint)
            }
            .contentShape(Rectangle())
        }
    }
}
