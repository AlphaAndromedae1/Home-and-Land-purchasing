import EventKit
import PhotosUI
import QuickLook
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PropertyDetailView: View {
    @EnvironmentObject private var store: PropertyStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    let propertyID: UUID

    @State private var showingEditor = false
    @State private var editingContact: PropertyContact?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var showingCamera = false
    @State private var showingDocumentPicker = false
    @State private var previewURL: URL?
    @State private var calendarRequest: CalendarRequest?
    @State private var message: String?

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
            dealSection(property)
            linksSection(property)
            contactsSection(property)
            attachmentsSection(property)
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
        .sheet(item: $editingContact) { contact in
            ContactEditorView(
                contact: contact,
                isNew: !(store.property(id: propertyID)?.contacts.contains { $0.id == contact.id } ?? false),
                onSave: { saveContact($0) },
                onDelete: { deleteContact(contact.id) }
            )
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(contentTypes: [.pdf, .image, .content]) { urls in
                importDocuments(urls)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $calendarRequest) { request in
            CalendarEventEditor(request: request) {
                calendarRequest = nil
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                if let image {
                    savePhoto(image)
                }
            }
            .ignoresSafeArea()
        }
        .quickLookPreview($previewURL, in: attachmentURLs(for: property))
        .onChange(of: photoItems) { items in
            importPhotos(items)
        }
        .alert("Home & Land", isPresented: messageIsShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    // MARK: - Sections

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
                Button {
                    addToCalendar(property, deadline: deadline)
                } label: {
                    Label("Add deadline to Calendar", systemImage: "calendar.badge.plus")
                }
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

    private func dealSection(_ property: Property) -> some View {
        Section {
            if let rating = DealRater.rate(property) {
                DealScoreCard(rating: rating, showsBreakdown: false)
            } else {
                Text(DealRater.missingInfoMessage(for: property))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            if let best = MaxOffer.inputs(for: property).flatMap({ MaxOffer.maximumOffer($0) }) {
                AmountRow(label: "Maximum offer for your target", amount: best.price)
            }
            NavigationLink {
                DealAnalysisView(property: property)
            } label: {
                Label("Rate this deal & work out a max offer", systemImage: "gauge")
            }
        } header: {
            Text("Deal rating")
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

    private func contactsSection(_ property: Property) -> some View {
        Section {
            ForEach(property.contacts) { contact in
                ContactRow(contact: contact) {
                    editingContact = contact
                }
            }
            .onDelete { offsets in
                let ids = Set(offsets.map { property.contacts[$0].id })
                store.update(property.id) { item in
                    item.contacts.removeAll { ids.contains($0.id) }
                }
            }
            Button {
                editingContact = PropertyContact(role: ContactRole.suggested(for: property.saleType))
            } label: {
                Label("Add contact", systemImage: "person.badge.plus")
            }
        } header: {
            Text("Contacts")
        }
    }

    private func attachmentsSection(_ property: Property) -> some View {
        let photos = property.attachments.filter { $0.kind == .photo }
        let documents = property.attachments.filter { $0.kind == .document }
        return Section {
            if !photos.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(photos) { photo in
                        let url = store.fileURL(for: photo, in: property.id)
                        AttachmentThumbnail(url: url)
                            .onTapGesture { previewURL = url }
                            .contextMenu {
                                ShareLink(item: url) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                                Button(role: .destructive) {
                                    store.removeAttachment(photo.id, from: property.id)
                                } label: {
                                    Label("Delete photo", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.vertical, 6)
            }
            ForEach(documents) { document in
                let url = store.fileURL(for: document, in: property.id)
                Button {
                    previewURL = url
                } label: {
                    Label(document.name, systemImage: "doc.text")
                }
                .contextMenu {
                    ShareLink(item: url) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        store.removeAttachment(document.id, from: property.id)
                    } label: {
                        Label("Delete document", systemImage: "trash")
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    store.removeAttachment(documents[index].id, from: property.id)
                }
            }
            PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                Label("Add photos", systemImage: "photo.on.rectangle")
            }
            if CameraPicker.isAvailable {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take a photo", systemImage: "camera")
                }
            }
            Button {
                showingDocumentPicker = true
            } label: {
                Label("Add a document", systemImage: "doc.badge.plus")
            }
        } header: {
            Text("Photos & documents")
        } footer: {
            Text("Tap to view. Touch and hold to share or delete. Files stay on this iPhone and aren't included in backups.")
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

    // MARK: - Actions

    private var messageIsShown: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
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

    private func attachmentURLs(for property: Property) -> [URL] {
        property.attachments.map { store.fileURL(for: $0, in: property.id) }
    }

    private func saveContact(_ contact: PropertyContact) {
        store.update(propertyID) { property in
            if let index = property.contacts.firstIndex(where: { $0.id == contact.id }) {
                property.contacts[index] = contact
            } else {
                property.contacts.append(contact)
            }
        }
    }

    private func deleteContact(_ id: UUID) {
        store.update(propertyID) { property in
            property.contacts.removeAll { $0.id == id }
        }
    }

    private func importPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var failed = 0
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data),
                      let jpeg = ImageProcessing.jpegData(from: image)
                else {
                    failed += 1
                    continue
                }
                do {
                    try store.addAttachment(data: jpeg, name: photoName(), fileExtension: "jpg", kind: .photo, to: propertyID)
                } catch {
                    failed += 1
                }
            }
            photoItems = []
            if failed > 0 {
                message = failed == 1 ? "One photo couldn't be added." : "\(failed) photos couldn't be added."
            }
        }
    }

    private func savePhoto(_ image: UIImage) {
        guard let jpeg = ImageProcessing.jpegData(from: image) else {
            message = "That photo couldn't be saved."
            return
        }
        do {
            try store.addAttachment(data: jpeg, name: photoName(), fileExtension: "jpg", kind: .photo, to: propertyID)
        } catch {
            message = "That photo couldn't be saved. \(error.localizedDescription)"
        }
    }

    private func importDocuments(_ urls: [URL]) {
        var failed: [String] = []
        for url in urls {
            do {
                try store.importAttachment(from: url, to: propertyID)
            } catch {
                failed.append(url.lastPathComponent)
            }
        }
        if !failed.isEmpty {
            message = "Couldn't add: \(failed.joined(separator: ", "))"
        }
    }

    private func photoName() -> String {
        "Photo \(Date().formatted(date: .abbreviated, time: .shortened))"
    }

    private func addToCalendar(_ property: Property, deadline: Date) {
        let eventStore = EKEventStore()
        if #available(iOS 17.0, *) {
            // iOS 17+ shows the event editor without needing calendar access.
            calendarRequest = CalendarRequest(
                eventStore: eventStore,
                event: CalendarEvents.event(for: property, deadline: deadline, in: eventStore)
            )
        } else {
            Task {
                let granted = (try? await eventStore.requestAccess(to: .event)) ?? false
                if granted {
                    calendarRequest = CalendarRequest(
                        eventStore: eventStore,
                        event: CalendarEvents.event(for: property, deadline: deadline, in: eventStore)
                    )
                } else {
                    message = "To add deadlines, allow Home & Land in Settings → Privacy & Security → Calendars."
                }
            }
        }
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
                Text("Land transfer tax")
            } footer: {
                Text("Estimate only. First-time buyer refunds, HST and legal fees aren't included. The deal analysis includes renovation, closing and carrying costs.")
            }
        }
    }
}
