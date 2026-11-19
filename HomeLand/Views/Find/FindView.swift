import SwiftUI
import UIKit

struct FindView: View {
    @EnvironmentObject private var store: PropertyStore
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

    private var listingSearchSection: some View {
        Section {
            SearchActionRow(title: "Realtor.ca listings", subtitle: "Google search of Realtor.ca listing pages", symbol: "house") {
                openURL(SearchLinks.listings(site: "realtor.ca/real-estate", terms: selectedTerms, region: region, pastMonth: pastMonth))
            }
            SearchActionRow(title: "Kijiji", subtitle: "Private sales and land ads", symbol: "tag") {
                openURL(SearchLinks.listings(site: "kijiji.ca", terms: selectedTerms, region: region, pastMonth: pastMonth))
            }
            SearchActionRow(title: "Zolo", subtitle: "MLS listings with sold history", symbol: "list.bullet") {
                openURL(SearchLinks.listings(site: "zolo.ca", terms: selectedTerms, region: region, pastMonth: pastMonth))
            }
            SearchActionRow(title: "Whole web", subtitle: "Brokerages, receivers and news", symbol: "globe") {
                openURL(SearchLinks.listings(site: nil, terms: selectedTerms, region: region, pastMonth: pastMonth))
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
            Text(selectedTerms.isEmpty
                 ? "Pick at least one keyword above."
                 : "Google only shows pages it has indexed, so check Realtor.ca directly for the newest listings.")
        }
        .disabled(selectedTerms.isEmpty)
    }

    private var taxSaleSection: some View {
        Section {
            SearchActionRow(
                title: "Tax sale notices",
                subtitle: region == .anywhere ? "Across Ontario" : "In \(region.name)",
                symbol: "doc.text.magnifyingglass"
            ) {
                openURL(SearchLinks.taxSaleNotices(region: region, pastMonth: pastMonth))
            }
            SearchActionRow(title: "Ontario Gazette notices", subtitle: "Every tax sale is advertised here", symbol: "newspaper") {
                openURL(SearchLinks.gazetteTaxSales(pastMonth: pastMonth))
            }
            SearchActionRow(title: "OntarioTaxSales.ca", subtitle: "Central tax sale listings", symbol: "list.bullet.rectangle") {
                openURL(Sources.ontarioTaxSales)
            }
        } header: {
            Text("Tax sales")
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
