import SwiftUI

/// Loads Gazette tax sale notices and keeps a copy for six hours.
@MainActor
final class TaxSaleNoticesModel: ObservableObject {
    @Published private(set) var notices: [GazetteNotice] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    static let issueCount = 6
    static let staleAfter: TimeInterval = 6 * 60 * 60

    private struct Cache: Codable {
        let date: Date
        let notices: [GazetteNotice]
    }

    private let cacheURL: URL

    init(cacheURL: URL? = nil) {
        self.cacheURL = cacheURL ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("gazette-tax-sales.json")
        loadCache()
    }

    func refreshIfStale() async {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < Self.staleAfter, !notices.isEmpty {
            return
        }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let fresh = try await GazetteClient().recentNotices(issueCount: Self.issueCount)
            notices = fresh
            lastUpdated = Date()
            saveCache()
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
        isLoading = false
    }

    private func loadCache() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: cacheURL),
              let cache = try? decoder.decode(Cache.self, from: data)
        else { return }
        notices = cache.notices
        lastUpdated = cache.date
    }

    private func saveCache() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let lastUpdated, let data = try? encoder.encode(Cache(date: lastUpdated, notices: notices)) else { return }
        try? data.write(to: cacheURL, options: .atomic)
    }
}

/// Tax sales advertised in the Ontario Gazette, read straight from ontario.ca.
struct TaxSaleNoticesView: View {
    @StateObject private var model = TaxSaleNoticesModel()
    @State private var area: String
    @State private var hideClosed = true
    @State private var searchText = ""

    private static let allArea = "all"
    private static let southernArea = "southern"

    init(region: Region? = nil) {
        let initial: String
        switch region {
        case .none: initial = Self.southernArea
        case .some(.anywhere): initial = Self.allArea
        case let .some(region): initial = region.rawValue
        }
        _area = State(initialValue: initial)
    }

    private var visible: [GazetteNotice] {
        let now = Date()
        let query = searchText.trimmed
        return model.notices
            .filter { !hideClosed || !$0.isClosed(now: now) }
            .filter { isInArea($0) }
            .filter { notice in
                query.isEmpty
                    || notice.heading.localizedCaseInsensitiveContains(query)
                    || notice.parcels.contains { $0.description.localizedCaseInsensitiveContains(query) }
            }
            .sorted { ($0.closes ?? .distantFuture) < ($1.closes ?? .distantFuture) }
    }

    private func isInArea(_ notice: GazetteNotice) -> Bool {
        switch area {
        case Self.allArea: return true
        case Self.southernArea: return notice.region != nil
        default: return notice.region?.rawValue == area
        }
    }

    var body: some View {
        List {
            Section {
                Picker("Area", selection: $area) {
                    Text("All of Ontario").tag(Self.allArea)
                    Text("Southern Ontario").tag(Self.southernArea)
                    ForEach(Region.southernRegions) { region in
                        Text(region.name).tag(region.rawValue)
                    }
                }
                Toggle("Hide closed sales", isOn: $hideClosed)
            } footer: {
                if let lastUpdated = model.lastUpdated {
                    Text("From the last \(TaxSaleNoticesModel.issueCount) weekly issues. Updated \(lastUpdated.formatted(date: .abbreviated, time: .shortened)). Pull down to refresh.")
                }
            }

            if let errorMessage = model.errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Button("Try again") {
                        Task { await model.refresh() }
                    }
                }
            }

            Section {
                ForEach(visible) { notice in
                    NavigationLink {
                        TaxSaleNoticeDetailView(notice: notice)
                    } label: {
                        TaxSaleNoticeRow(notice: notice)
                    }
                }
                if model.isLoading {
                    HStack {
                        Spacer()
                        ProgressView("Reading the Ontario Gazette…")
                        Spacer()
                    }
                } else if visible.isEmpty, model.lastUpdated != nil {
                    Text(area == Self.allArea
                         ? "No open tax sales in recent issues."
                         : "No open tax sales here in recent issues. Try All of Ontario.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                if !model.notices.isEmpty {
                    Text("\(visible.count) \(visible.count == 1 ? "sale" : "sales")")
                }
            }

            Section {
                Text("Notices come from the Ontario Gazette on ontario.ca. © King's Printer for Ontario. Reproduced without changes for non-commercial use. Always confirm details with the municipality before you bid.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Gazette tax sales")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Town or address")
        .task {
            await model.refreshIfStale()
        }
        .refreshable {
            await model.refresh()
        }
    }
}

struct TaxSaleNoticeRow: View {
    let notice: GazetteNotice

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(notice.municipality)
                .font(.headline)
            HStack(spacing: 6) {
                TagBadge(text: notice.method.name, color: .orange, symbol: "doc.text")
                if let region = notice.region {
                    Text(region.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Text(summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if let closes = notice.closes {
                DeadlineLabel(date: closes)
            }
        }
        .padding(.vertical, 2)
    }

    private var summary: String {
        let count = notice.parcels.count
        var parts = [count == 0 ? "See notice" : "\(count) \(count == 1 ? "property" : "properties")"]
        if let lowest = notice.lowestMinimum {
            parts.append(count == 1 ? "minimum \(Fmt.money(lowest))" : "minimums from \(Fmt.money(lowest))")
        }
        return parts.joined(separator: " · ")
    }
}

struct TaxSaleNoticeDetailView: View {
    let notice: GazetteNotice

    @EnvironmentObject private var store: PropertyStore
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                Text(notice.heading)
                    .font(.headline)
                InfoRow(label: "Sale", value: notice.method.name)
                if let closes = notice.closes {
                    InfoRow(label: notice.method == .auction ? "Auction" : "Tenders close",
                            value: closes.formatted(date: .abbreviated, time: .shortened))
                    if !notice.isClosed() {
                        DeadlineLabel(date: closes)
                    }
                }
                if let region = notice.region {
                    InfoRow(label: "Region", value: region.name)
                }
                InfoRow(label: "Gazette", value: notice.issue.title)
                Button {
                    openURL(notice.sectionURL)
                } label: {
                    Label("View on ontario.ca", systemImage: "arrow.up.forward.square")
                }
            }

            Section {
                if notice.parcels.isEmpty {
                    Text("The app couldn't pick out the individual properties. They're listed in the notice below.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(notice.parcels.enumerated()), id: \.element.id) { index, parcel in
                    ParcelRow(
                        parcel: parcel,
                        number: index + 1,
                        isSaved: isSaved(parcel),
                        save: { store.upsert(GazetteImport.property(for: parcel, in: notice)) }
                    )
                }
            } header: {
                Text("Properties")
            } footer: {
                Text("Saving adds the property to your watchlist with the minimum tender as the price, the closing date as the deadline (so reminders work) and the municipal contact.")
            }

            if !notice.contact.isEmpty {
                Section("Contact") {
                    if let name = notice.contact.name {
                        Text(name)
                    }
                    if let phone = notice.contact.phone,
                       let url = URL(string: "tel:" + phone.filter { "0123456789+".contains($0) }) {
                        Button {
                            openURL(url)
                        } label: {
                            Label(phone, systemImage: "phone")
                        }
                    }
                    if let email = notice.contact.email, let url = URL(string: "mailto:\(email)") {
                        Button {
                            openURL(url)
                        } label: {
                            Label(email, systemImage: "envelope")
                        }
                    }
                }
            }

            Section {
                ForEach(Array(notice.blocks.enumerated()), id: \.offset) { _, block in
                    Text(block.text)
                        .font(.callout)
                        .padding(.leading, block.isListItem ? 14 : 0)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Notice as published")
            } footer: {
                Text(notice.credit)
            }
        }
        .navigationTitle(notice.municipality)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func isSaved(_ parcel: TaxSaleParcel) -> Bool {
        let title = GazetteImport.title(for: parcel, in: notice)
        return store.properties.contains {
            $0.listingURL == notice.sectionURL.absoluteString && $0.title == title && $0.askingPrice == parcel.minimumTender
        }
    }
}

struct ParcelRow: View {
    let parcel: TaxSaleParcel
    let number: Int
    let isSaved: Bool
    let save: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(parcel.address ?? "Property \(number)")
                    .font(.headline)
                Spacer(minLength: 8)
                if let minimum = parcel.minimumTender {
                    Text(Fmt.money(minimum))
                        .font(.headline)
                        .monospacedDigit()
                }
            }
            Text(parcel.description)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(4)
            HStack(spacing: 12) {
                if let assessed = parcel.assessedValue {
                    Text("Assessed \(Fmt.money(assessed))")
                }
                if let pin = parcel.pin {
                    Text("PIN \(pin)")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack {
                Text("Minimum tender")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(action: save) {
                    Label(isSaved ? "Saved" : "Save to watchlist", systemImage: isSaved ? "star.fill" : "star")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .disabled(isSaved)
            }
        }
        .padding(.vertical, 4)
    }
}
