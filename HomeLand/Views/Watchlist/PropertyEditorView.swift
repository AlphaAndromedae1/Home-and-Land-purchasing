import SwiftUI

struct PropertyEditorView: View {
    @EnvironmentObject private var store: PropertyStore
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Property
    @State private var priceText: String
    @State private var maxPriceText: String
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var confirmingDelete = false

    init(property: Property) {
        _draft = State(initialValue: property)
        _priceText = State(initialValue: MoneyParser.editingText(for: property.askingPrice))
        _maxPriceText = State(initialValue: MoneyParser.editingText(for: property.maxPrice))
        _hasDeadline = State(initialValue: property.deadline != nil)
        let twoWeeksOut = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
        _deadline = State(initialValue: property.deadline ?? twoWeeksOut)
    }

    private var isNew: Bool {
        store.property(id: draft.id) == nil
    }

    private var canSave: Bool {
        !draft.title.trimmed.isEmpty || !draft.listingURL.trimmed.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                propertySection
                saleSection
                listingSection
                Section("Notes") {
                    TextEditor(text: $draft.notes)
                        .frame(minHeight: 120)
                }
                if !isNew {
                    Section {
                        Button("Delete property", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add property" : "Edit property")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .confirmationDialog("Delete this property?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(ids: [draft.id])
                    dismiss()
                }
            }
        }
    }

    private var propertySection: some View {
        Section("Property") {
            TextField("Address or nickname", text: $draft.title)
                .textInputAutocapitalization(.words)
            TextField("Town or city", text: $draft.municipality)
                .textInputAutocapitalization(.words)
            Picker("Region", selection: $draft.region) {
                ForEach(Region.allCases) { region in
                    Text(region.name).tag(region)
                }
            }
            Picker("Type", selection: $draft.kind) {
                ForEach(PropertyKind.allCases) { kind in
                    Text(kind.name).tag(kind)
                }
            }
            TextField("Lot size (e.g. 50 × 120 ft or 10 acres)", text: $draft.lotSize)
        }
    }

    private var saleSection: some View {
        Section {
            Picker("Sale type", selection: $draft.saleType) {
                ForEach(SaleType.allCases) { saleType in
                    Text(saleType.name).tag(saleType)
                }
            }
            Picker("Status", selection: $draft.status) {
                ForEach(WatchStatus.allCases) { status in
                    Text(status.name).tag(status)
                }
            }
            TextField(draft.saleType == .taxSale ? "Minimum tender" : "Asking price", text: $priceText)
                .keyboardType(.numbersAndPunctuation)
            TextField("Your maximum price", text: $maxPriceText)
                .keyboardType(.numbersAndPunctuation)
            Toggle(draft.saleType == .taxSale ? "Tender deadline" : "Offer deadline", isOn: $hasDeadline.animation())
            if hasDeadline {
                DatePicker("Deadline", selection: $deadline)
            }
        } header: {
            Text("Sale")
        } footer: {
            Text("Prices can be typed as 450000, $450,000 or 450k.")
        }
    }

    private var listingSection: some View {
        Section {
            TextField("Listing link", text: $draft.listingURL)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            PasteButton(payloadType: String.self) { strings in
                guard let text = strings.first else { return }
                Task { @MainActor in
                    applyPastedLink(text)
                }
            }
            TextField("MLS® number", text: $draft.mlsNumber)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
        } header: {
            Text("Listing")
        } footer: {
            Text("Copy a listing's link in Safari or the Realtor.ca app, then tap Paste. If the link includes the address, it fills in the name for you.")
        }
    }

    private func applyPastedLink(_ text: String) {
        guard let url = ListingURLParser.firstURL(in: text) ?? ListingURLParser.normalizedURL(from: text) else {
            draft.listingURL = text.trimmed
            return
        }
        draft.listingURL = url.absoluteString
        if draft.title.trimmed.isEmpty, let suggestion = ListingURLParser.suggestedTitle(from: url) {
            draft.title = suggestion
        }
    }

    private func save() {
        var property = draft
        property.title = property.title.trimmed
        property.municipality = property.municipality.trimmed
        property.listingURL = property.listingURL.trimmed
        property.mlsNumber = property.mlsNumber.trimmed
        property.askingPrice = MoneyParser.parse(priceText)
        property.maxPrice = MoneyParser.parse(maxPriceText)
        property.deadline = hasDeadline ? deadline : nil
        if property.title.isEmpty,
           let url = property.listingLink,
           let suggestion = ListingURLParser.suggestedTitle(from: url) {
            property.title = suggestion
        }
        store.upsert(property)
        dismiss()
    }
}
