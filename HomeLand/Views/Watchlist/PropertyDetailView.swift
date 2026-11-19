import SwiftUI

struct PropertyDetailView: View {
    @EnvironmentObject private var store: PropertyStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let propertyID: UUID
    @State private var showingEditor = false

    var body: some View {
        if let property = store.property(id: propertyID) {
            details(for: property)
        } else {
            Text("This property was deleted.")
                .foregroundStyle(.secondary)
                .task {
                    // Leave the screen once the editor sheet has finished closing.
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    dismiss()
                }
        }
    }

    private func details(for property: Property) -> some View {
        List {
            summarySection(property)
            linksSection(property)
            CostEstimateSection(property: property)
            ForEach(property.checklistGroups) { group in
                checklistSection(group, property: property)
            }
            if !property.notes.trimmed.isEmpty {
                Section("Notes") {
                    Text(property.notes)
                        .textSelection(.enabled)
                }
            }
        }
        .navigationTitle(property.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditor = true
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            PropertyEditorView(property: property)
                .environmentObject(store)
        }
    }

    private func summarySection(_ property: Property) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(property.displayTitle)
                    .font(.title3.weight(.semibold))
                HStack(spacing: 6) {
                    TagBadge(text: property.saleType.name, color: property.saleType.color, symbol: property.saleType.symbol)
                    TagBadge(text: property.kind.name, color: .secondary, symbol: property.kind.symbol)
                }
                if let deadline = property.deadline, property.status.isOpen {
                    DeadlineLabel(date: deadline)
                }
            }
            .padding(.vertical, 4)

            Picker("Status", selection: statusBinding(for: property)) {
                ForEach(WatchStatus.allCases) { status in
                    Text(status.name).tag(status)
                }
            }

            if let price = property.askingPrice {
                InfoRow(label: property.saleType == .taxSale ? "Minimum tender" : "Asking price", value: Fmt.money(price))
            }
            if let maxPrice = property.maxPrice {
                InfoRow(label: "Your maximum", value: Fmt.money(maxPrice))
            }
            if let deadline = property.deadline {
                InfoRow(label: "Deadline", value: deadline.formatted(date: .abbreviated, time: .shortened))
            }
            InfoRow(label: "Location", value: locationText(for: property))
            if !property.lotSize.trimmed.isEmpty {
                InfoRow(label: "Lot size", value: property.lotSize)
            }
            if !property.mlsNumber.trimmed.isEmpty {
                InfoRow(label: "MLS® number", value: property.mlsNumber)
            }
            InfoRow(label: "Added", value: property.dateAdded.formatted(date: .abbreviated, time: .omitted))
        }
    }

    private func linksSection(_ property: Property) -> some View {
        Section("Look it up") {
            if let url = property.listingLink {
                Button {
                    openURL(url)
                } label: {
                    Label("Open listing", systemImage: "safari")
                }
                ShareLink(item: url) {
                    Label("Share listing", systemImage: "square.and.arrow.up")
                }
            }
            Button {
                openURL(SearchLinks.google(property.webSearchQuery))
            } label: {
                Label("Search the web for this address", systemImage: "magnifyingglass")
            }
            Button {
                openURL(Sources.onLand)
            } label: {
                Label("Title search on OnLand", systemImage: "doc.text.magnifyingglass")
            }
            Button {
                openURL(Sources.mpac)
            } label: {
                Label("Assessment on MPAC AboutMyProperty", systemImage: "building.columns")
            }
            Button {
                openURL(Sources.houseSigma)
            } label: {
                Label("Sold prices on HouseSigma", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
    }

    private func checklistSection(_ group: ChecklistGroup, property: Property) -> some View {
        let done = group.items.filter { property.completedChecks.contains($0.id) }.count
        return Section {
            ForEach(group.items) { item in
                ChecklistRow(item: item, isDone: property.completedChecks.contains(item.id)) {
                    store.toggleCheck(item.id, for: property.id)
                }
            }
        } header: {
            HStack {
                Text(group.title)
                Spacer()
                Text("\(done)/\(group.items.count)")
            }
        }
    }

    private func statusBinding(for property: Property) -> Binding<WatchStatus> {
        Binding(
            get: { store.property(id: property.id)?.status ?? property.status },
            set: { store.setStatus($0, for: property.id) }
        )
    }

    private func locationText(for property: Property) -> String {
        [property.municipality.trimmed, property.region.name]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct ChecklistRow: View {
    let item: ChecklistItem
    let isDone: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isDone ? Color.green : Color.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .foregroundStyle(.primary)
                    Text(item.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isDone ? .isSelected : [])
    }
}

struct CostEstimateSection: View {
    let property: Property

    var body: some View {
        if let price = property.priceForEstimates, price > 0 {
            let estimate = LandTransferTax.estimate(
                price: price,
                isHome: property.kind.usesHomeLandTransferTax,
                inToronto: property.isInToronto,
                firstTimeBuyer: false
            )
            Section {
                AmountRow(label: property.maxPrice != nil ? "Your maximum" : "Asking price", amount: price)
                AmountRow(label: "Ontario land transfer tax", amount: estimate.ontario)
                if estimate.toronto > 0 {
                    AmountRow(label: "Toronto land transfer tax", amount: estimate.toronto)
                }
                if property.saleType == .taxSale {
                    AmountRow(label: "Tender deposit (20%)", amount: price * TaxSaleTender.depositRate)
                }
                AmountRow(label: "Price + land transfer tax", amount: price + estimate.total, emphasized: true)
            } header: {
                Text("Cost estimate")
            } footer: {
                Text("Estimate only. First-time buyer refunds, HST and legal fees aren't included. Use the Tools tab for more detail.")
            }
        }
    }
}
