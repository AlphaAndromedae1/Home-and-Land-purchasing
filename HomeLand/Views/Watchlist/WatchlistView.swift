import SwiftUI
import UniformTypeIdentifiers

enum WatchFilter: String, CaseIterable, Identifiable {
    case open
    case all
    case closed

    var id: String { rawValue }

    var name: String {
        switch self {
        case .open: return "Active"
        case .all: return "All"
        case .closed: return "Closed"
        }
    }

    func includes(_ property: Property) -> Bool {
        switch self {
        case .open: return property.status.isOpen
        case .all: return true
        case .closed: return !property.status.isOpen
        }
    }
}

enum WatchSort: String, CaseIterable, Identifiable {
    case deadline
    case newest
    case priceLow
    case priceHigh
    case name

    var id: String { rawValue }

    var name: String {
        switch self {
        case .deadline: return "Deadline"
        case .newest: return "Newest"
        case .priceLow: return "Price: low to high"
        case .priceHigh: return "Price: high to low"
        case .name: return "Name"
        }
    }

    func areInIncreasingOrder(_ a: Property, _ b: Property) -> Bool {
        switch self {
        case .deadline:
            switch (a.deadline, b.deadline) {
            case let (first?, second?): return first < second
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return a.dateAdded > b.dateAdded
            }
        case .newest:
            return a.dateAdded > b.dateAdded
        case .priceLow:
            return (a.askingPrice ?? .greatestFiniteMagnitude) < (b.askingPrice ?? .greatestFiniteMagnitude)
        case .priceHigh:
            return (a.askingPrice ?? -1) > (b.askingPrice ?? -1)
        case .name:
            return a.displayTitle.localizedCaseInsensitiveCompare(b.displayTitle) == .orderedAscending
        }
    }
}

struct WatchlistView: View {
    @EnvironmentObject private var store: PropertyStore
    @AppStorage("watchlist.filter") private var filter: WatchFilter = .open
    @AppStorage("watchlist.sort") private var sort: WatchSort = .deadline
    @State private var searchText = ""
    @State private var showingAdd = false
    @State private var showingImporter = false
    @State private var exportFile: IdentifiedURL?
    @State private var message: String?

    private var visible: [Property] {
        let query = searchText.trimmed
        return store.properties
            .filter { filter.includes($0) }
            .filter { query.isEmpty || $0.matches(query) }
            .sorted { sort.areInIncreasingOrder($0, $1) }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Watchlist")
                .navigationDestination(for: UUID.self) { id in
                    PropertyDetailView(propertyID: id)
                }
                .toolbar { toolbarContent }
                .sheet(isPresented: $showingAdd) {
                    PropertyEditorView(property: Property())
                        .environmentObject(store)
                }
                .sheet(item: $exportFile) { file in
                    ActivityView(items: [file.url])
                }
                .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
                    importBackup(result)
                }
                .alert("Watchlist", isPresented: messageIsShown) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(message ?? "")
                }
                .onAppear { showStoreError() }
                .onReceive(store.$lastError) { _ in showStoreError() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if store.properties.isEmpty {
            EmptyWatchlistView {
                showingAdd = true
            }
        } else {
            List {
                Section {
                    Picker("Show", selection: $filter) {
                        ForEach(WatchFilter.allCases) { filter in
                            Text(filter.name).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    if visible.isEmpty {
                        Text("Nothing matches.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(visible) { property in
                        NavigationLink(value: property.id) {
                            PropertyRow(property: property)
                        }
                    }
                    .onDelete { offsets in
                        let rows = visible
                        store.delete(ids: Set(offsets.map { rows[$0].id }))
                    }
                } footer: {
                    Text("\(visible.count) of \(store.properties.count) properties")
                }
            }
            .searchable(text: $searchText, prompt: "Address, town, MLS® number or notes")
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Button {
                showingAdd = true
            } label: {
                Label("Add property", systemImage: "plus")
            }
        }
        ToolbarItem(placement: .navigationBarLeading) {
            Menu {
                Picker("Sort by", selection: $sort) {
                    ForEach(WatchSort.allCases) { sort in
                        Text(sort.name).tag(sort)
                    }
                }
                Divider()
                Button {
                    exportBackup()
                } label: {
                    Label("Export backup", systemImage: "square.and.arrow.up")
                }
                .disabled(store.properties.isEmpty)
                Button {
                    showingImporter = true
                } label: {
                    Label("Import backup", systemImage: "square.and.arrow.down")
                }
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private var messageIsShown: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }

    private func showStoreError() {
        guard let error = store.lastError else { return }
        message = error
        store.lastError = nil
    }

    private func exportBackup() {
        do {
            exportFile = IdentifiedURL(url: try store.exportBackup())
        } catch {
            message = "Couldn't export your watchlist: \(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let count = try store.importBackup(from: url)
                message = "Imported \(count) \(count == 1 ? "property" : "properties")."
            } catch {
                message = "That file isn't a Home & Land backup. \(error.localizedDescription)"
            }
        case .failure(let error):
            message = error.localizedDescription
        }
    }
}

struct EmptyWatchlistView: View {
    let addAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("No properties yet")
                .font(.title2.weight(.semibold))
            Text("Save listings you find to track deadlines, prices and a due-diligence checklist for each one.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: addAction) {
                Label("Add a property", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PropertyRow: View {
    let property: Property

    var body: some View {
        let progress = property.checklistProgress
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(property.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                Spacer(minLength: 8)
                if let price = property.askingPrice {
                    Text(Fmt.money(price))
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                }
            }
            HStack(spacing: 6) {
                TagBadge(text: property.saleType.name, color: property.saleType.color, symbol: property.saleType.symbol)
                TagBadge(text: property.status.name, color: property.status.color)
            }
            HStack(spacing: 12) {
                if !property.municipality.trimmed.isEmpty {
                    Label(property.municipality, systemImage: "mappin.and.ellipse")
                }
                Label("\(progress.done)/\(progress.total) checks", systemImage: "checklist")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let deadline = property.deadline, property.status.isOpen {
                DeadlineLabel(date: deadline)
            }
        }
        .padding(.vertical, 2)
    }
}
