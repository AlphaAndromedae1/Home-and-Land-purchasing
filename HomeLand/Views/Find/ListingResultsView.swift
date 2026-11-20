import SwiftUI

enum ListingSort: String, CaseIterable, Identifiable {
    case relevance
    case priceLow
    case priceHigh
    case newest

    var id: String { rawValue }

    var name: String {
        switch self {
        case .relevance: return "Best match"
        case .priceLow: return "Price: low to high"
        case .priceHigh: return "Price: high to low"
        case .newest: return "Newest"
        }
    }
}

/// Listings found by a search, shown as cards inside the app.
struct ListingResultsView: View {
    let request: ListingSearchRequest

    @EnvironmentObject private var store: PropertyStore
    @EnvironmentObject private var searchKeys: SearchKeyStore
    @Environment(\.openURL) private var openURL

    @State private var results: [ListingResult] = []
    @State private var nextPage = 0
    @State private var moreAvailable = false
    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var sort: ListingSort = .relevance
    @State private var onlyWithPrice = false
    @State private var showOtherPages = false

    private var listings: [ListingResult] {
        results.filter { $0.isLikelyListing && !$0.details.isRental }
    }

    private var otherPageCount: Int {
        results.count - listings.count
    }

    private var visible: [ListingResult] {
        var items = (showOtherPages || request.target == .taxSales || request.target == .web) ? results : listings
        if onlyWithPrice {
            items = items.filter { $0.details.price != nil }
        }
        switch sort {
        case .relevance:
            return items
        case .priceLow:
            return items.sorted { ($0.details.price ?? .greatestFiniteMagnitude) < ($1.details.price ?? .greatestFiniteMagnitude) }
        case .priceHigh:
            return items.sorted { ($0.details.price ?? -1) > ($1.details.price ?? -1) }
        case .newest:
            return items.sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
        }
    }

    var body: some View {
        List {
            optionsSection
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    if searchKeys.hasKey {
                        Button("Try again") {
                            Task { await load(reset: results.isEmpty) }
                        }
                    } else {
                        NavigationLink("Set up listing search") {
                            SearchKeySetupView()
                        }
                    }
                    Button("Search on Google instead") {
                        openURL(request.googleFallbackURL)
                    }
                }
            }
            resultsSection
        }
        .navigationTitle(request.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !hasLoaded {
                await load(reset: true)
            }
        }
        .refreshable {
            await load(reset: true, forceRefresh: true)
        }
    }

    private var optionsSection: some View {
        Section {
            Text(request.summary)
                .font(.subheadline)
            Picker("Sort", selection: $sort) {
                ForEach(ListingSort.allCases) { sort in
                    Text(sort.name).tag(sort)
                }
            }
            Toggle("Only results with a price", isOn: $onlyWithPrice)
            if otherPageCount > 0, request.target != .taxSales, request.target != .web {
                Toggle("Show \(otherPageCount) non-listing \(otherPageCount == 1 ? "page" : "pages")", isOn: $showOtherPages)
            }
        } footer: {
            Text(request.areTermsTrimmed
                 ? "Searching your first \(ListingSearchRequest.maxTerms) keywords. Results come from Brave Search's index of public pages, so the newest listings may be missing."
                 : "Results come from Brave Search's index of public pages, so the newest listings may be missing. Tap a listing for full details.")
        }
    }

    private var resultsSection: some View {
        Section {
            ForEach(visible) { result in
                ListingCard(
                    result: result,
                    isSaved: isSaved(result),
                    open: { openURL(result.url) },
                    save: { save(result) }
                )
            }
            if hasLoaded, !isLoading, errorMessage == nil, visible.isEmpty {
                Text("Nothing matched. Try fewer keywords, another region, or turn off “past month” on the Find tab.")
                    .foregroundStyle(.secondary)
            }
            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if moreAvailable {
                Button {
                    Task { await load(reset: false) }
                } label: {
                    Label("Load more", systemImage: "arrow.down.circle")
                }
            }
        } header: {
            if hasLoaded {
                Text("\(visible.count) \(visible.count == 1 ? "result" : "results")")
            }
        }
    }

    private func isSaved(_ result: ListingResult) -> Bool {
        store.properties.contains { $0.listingURL == result.url.absoluteString }
    }

    private func save(_ result: ListingResult) {
        let details = result.details
        let kind = details.kind ?? .house
        var property = Property(
            title: details.address ?? result.title,
            municipality: details.municipality ?? "",
            region: request.region,
            saleType: details.saleType ?? request.suggestedSaleType ?? .regular,
            kind: kind,
            askingPrice: details.isRental ? nil : details.price,
            lotSize: details.acres.map { "\($0.formatted()) acres" } ?? "",
            listingURL: result.url.absoluteString,
            notes: result.snippet
        )
        if kind.sizeUnit == .acres, let acres = details.acres {
            property.analysis.size = acres
        }
        store.upsert(property)
    }

    private func load(reset: Bool, forceRefresh: Bool = false) async {
        guard let apiKey = searchKeys.apiKey else {
            errorMessage = ListingSearchError.missingKey.errorDescription
            hasLoaded = true
            return
        }
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        let page = reset ? 0 : nextPage
        do {
            let found = try await ListingSearchEngine.shared.search(request, page: page, apiKey: apiKey, forceRefresh: forceRefresh)
            if reset {
                results = []
            }
            let known = Set(results.map(\.id))
            results += found.results.filter { !known.contains($0.id) }
            nextPage = page + 1
            moreAvailable = found.moreAvailable && nextPage <= BraveSearchClient.maxPage
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        hasLoaded = true
        isLoading = false
    }
}

struct ListingCard: View {
    let result: ListingResult
    let isSaved: Bool
    let open: () -> Void
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: open) {
                HStack(alignment: .top, spacing: 12) {
                    if let thumbnail = result.thumbnailURL {
                        AsyncImage(url: thumbnail) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Color(.secondarySystemFill)
                            }
                        }
                        .frame(width: 96, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let price = result.details.price {
                            Text(Fmt.money(price) + (result.details.isRental ? "/mo" : ""))
                                .font(.headline)
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                        }
                        Text(result.details.address ?? result.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        if !result.factsText.isEmpty {
                            Text(result.factsText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(result.sourceLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if !result.snippet.isEmpty {
                Text(result.snippet)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 6) {
                if let saleType = result.details.saleType {
                    TagBadge(text: saleType.name, color: saleType.color, symbol: saleType.symbol)
                }
                if let kind = result.details.kind {
                    TagBadge(text: kind.name, color: .secondary, symbol: kind.symbol)
                }
                Spacer(minLength: 0)
                Button(action: save) {
                    Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "star.fill" : "star")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .disabled(isSaved)
            }
        }
        .padding(.vertical, 6)
    }
}

/// A search row: shows results in the app when there's a Brave key, otherwise opens Google.
struct ListingSearchLink: View {
    let request: ListingSearchRequest
    let title: String
    let subtitle: String
    let symbol: String

    @EnvironmentObject private var searchKeys: SearchKeyStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        if searchKeys.hasKey {
            NavigationLink {
                ListingResultsView(request: request)
            } label: {
                SearchRowLabel(title: title, subtitle: subtitle, symbol: symbol)
            }
        } else {
            SearchActionRow(title: title, subtitle: subtitle, symbol: symbol) {
                openURL(request.googleFallbackURL)
            }
        }
    }
}

struct SearchRowLabel: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
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
        }
    }
}
