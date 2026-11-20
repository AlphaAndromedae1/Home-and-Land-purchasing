import SwiftUI
import UIKit

struct FindView: View {
    @EnvironmentObject private var store: PropertyStore
    @EnvironmentObject private var searchKeys: SearchKeyStore
    @Environment(\.openURL) private var openURL

    @AppStorage("find.region") private var regionID = Region.gta.rawValue
    @AppStorage("find.terms") private var termsStorage = "power of sale"
    @AppStorage("find.pastMonth") private var pastMonth = true
    @State private var showingAdd = false
    @State private var copiedKeyword: String?

    private var region: Region {
        Region(rawValue: regionID) ?? .gta
    }

    private var chosenTerms: Set<String> {
        Set(termsStorage.split(separator: "|").map(String.init))
    }

    /// Selected keywords, in the order they appear in the app.
    private var selectedTerms: [String] {
        let chosen = chosenTerms
        return Keywords.all.map(\.term).filter { chosen.contains($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                builderSection
                listingSearchSection
                taxSaleSection
                ForEach(SourceCategory.allCases) { category in
                    Section {
                        ForEach(Sources.items(in: category)) { source in
                            SourceRow(source: source)
                        }
                    } header: {
                        Label(category.title, systemImage: category.symbol)
                    } footer: {
                        Text(category.footer)
                    }
                }
            }
            .navigationTitle("Find")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("Add to watchlist", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                PropertyEditorView(property: Property(region: region))
                    .environmentObject(store)
            }
        }
    }

    // MARK: - Sections

    private var builderSection: some View {
        Section {
            Picker("Region", selection: $regionID) {
                ForEach(Region.allCases) { region in
                    Text(region.name).tag(region.rawValue)
                }
            }
            keywordGroup(title: "Distress signals", keywords: Keywords.distressed)
            keywordGroup(title: "Land", keywords: Keywords.land)
            Toggle("Only results from the past month", isOn: $pastMonth)
        } header: {
            Text("Search builder")
        } footer: {
            Text("Pick a region and keywords, then run a search below. Results match any of the keywords you pick.")
        }
    }

    private func keywordGroup(title: String, keywords: [SearchKeyword]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            FlowLayout(spacing: 8) {
                ForEach(keywords) { keyword in
                    Chip(title: keyword.term, isSelected: chosenTerms.contains(keyword.term)) {
                        toggle(keyword.term)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private static let listingTargets: [ListingSearchTarget] = [.allSites, .realtor, .houseSigma, .zolo, .kijiji]

    private func request(for target: ListingSearchTarget) -> ListingSearchRequest {
        ListingSearchRequest(target: target, terms: selectedTerms, region: region, pastMonth: pastMonth)
    }

    private var listingSearchSection: some View {
        Section {
            if !searchKeys.hasKey {
                NavigationLink {
                    SearchKeySetupView()
                } label: {
                    SearchRowLabel(
                        title: "Show listings in the app",
                        subtitle: "Set up a Brave Search key to see prices and photos here",
                        symbol: "wand.and.stars"
                    )
                }
            }
            ForEach(Self.listingTargets) { target in
                ListingSearchLink(request: request(for: target), title: target.name, subtitle: target.subtitle, symbol: target.symbol)
            }
            SearchActionRow(title: "Whole web in the browser", subtitle: "Brokerages, receivers and news on Google", symbol: "globe") {
                openURL(request(for: .web).googleFallbackURL)
            }
            SearchActionRow(
                title: "Open Realtor.ca and copy keyword",
                subtitle: copiedKeyword.map { "Copied “\($0)”. Paste it into Filters → Keywords." }
                    ?? "Copies your first keyword to paste into Filters → Keywords",
                symbol: "doc.on.clipboard"
            ) {
                if let first = selectedTerms.first {
                    UIPasteboard.general.string = first
                    copiedKeyword = first
                }
                openURL(Sources.realtor)
            }
        } header: {
            Text("Search listings in \(region.name)")
        } footer: {
            if selectedTerms.isEmpty {
                Text("Pick at least one keyword above.")
            } else if searchKeys.hasKey {
                Text("Listings show right here, with prices, photos and a Save button. Each page of results uses one search from your Brave credit.")
            } else {
                Text("Without a Brave key these open Google in the browser. Google only shows pages it has indexed, so check Realtor.ca directly for the newest listings.")
            }
        }
        .disabled(selectedTerms.isEmpty)
    }

    private var taxSaleSection: some View {
        Section {
            NavigationLink {
                TaxSaleNoticesView(region: region)
            } label: {
                SearchRowLabel(
                    title: "Tax sales from the Ontario Gazette",
                    subtitle: "Every advertised tax sale, with minimum tenders and closing dates",
                    symbol: "newspaper"
                )
            }
            ListingSearchLink(
                request: request(for: .taxSales),
                title: "Search the web for tax sale notices",
                subtitle: region == .anywhere ? "Across Ontario" : "In \(region.name)",
                symbol: "doc.text.magnifyingglass"
            )
            SearchActionRow(title: "OntarioTaxSales.ca", subtitle: "Central tax sale listings", symbol: "list.bullet.rectangle") {
                openURL(Sources.ontarioTaxSales)
            }
        } header: {
            Text("Tax sales")
        } footer: {
            Text("Gazette notices are read directly from ontario.ca and don't need a search key.")
        }
    }

    private func toggle(_ term: String) {
        var chosen = chosenTerms
        if chosen.contains(term) {
            chosen.remove(term)
        } else {
            chosen.insert(term)
        }
        termsStorage = Keywords.all.map(\.term).filter { chosen.contains($0) }.joined(separator: "|")
    }
}

struct SourceRow: View {
    let source: Source
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            openURL(source.url)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.name)
                        .foregroundStyle(.primary)
                    Text(source.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.forward.square")
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button {
                UIPasteboard.general.url = source.url
            } label: {
                Label("Copy link", systemImage: "doc.on.doc")
            }
            ShareLink(item: source.url) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}
