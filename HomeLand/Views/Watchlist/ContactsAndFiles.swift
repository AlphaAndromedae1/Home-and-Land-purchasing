import SwiftUI

struct ContactRow: View {
    let contact: PropertyContact
    let edit: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 14) {
            Button(action: edit) {
                HStack(spacing: 12) {
                    Image(systemName: contact.role.symbol)
                        .foregroundStyle(.tint)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(contact.displayName)
                            .foregroundStyle(.primary)
                        Text(contact.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)

            if let url = contact.phoneURL {
                actionButton(symbol: "phone.fill", label: "Call") { openURL(url) }
            }
            if let url = contact.smsURL {
                actionButton(symbol: "message.fill", label: "Text") { openURL(url) }
            }
            if let url = contact.emailURL {
                actionButton(symbol: "envelope.fill", label: "Email") { openURL(url) }
            }
        }
    }

    private func actionButton(symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.12), in: Circle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("\(label) \(contact.displayName)")
    }
}

struct ContactEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var contact: PropertyContact
    @State private var confirmingDelete = false
    let isNew: Bool
    let onSave: (PropertyContact) -> Void
    let onDelete: () -> Void

    init(contact: PropertyContact, isNew: Bool, onSave: @escaping (PropertyContact) -> Void, onDelete: @escaping () -> Void) {
        _contact = State(initialValue: contact)
        self.isNew = isNew
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Role", selection: $contact.role) {
                        ForEach(ContactRole.allCases) { role in
                            Text(role.name).tag(role)
                        }
                    }
                    TextField("Name", text: $contact.name)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                    TextField("Company or office", text: $contact.company)
                        .textContentType(.organizationName)
                        .textInputAutocapitalization(.words)
                }
                Section {
                    TextField("Phone", text: $contact.phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField("Email", text: $contact.email)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section("Notes") {
                    TextEditor(text: $contact.notes)
                        .frame(minHeight: 80)
                }
                if !isNew {
                    Section {
                        Button("Delete contact", role: .destructive) {
                            confirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Add contact" : "Edit contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = contact
                        saved.name = saved.name.trimmed
                        saved.company = saved.company.trimmed
                        saved.phone = saved.phone.trimmed
                        saved.email = saved.email.trimmed
                        onSave(saved)
                        dismiss()
                    }
                    .disabled(contact.isEmpty)
                }
            }
            .confirmationDialog("Delete this contact?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
        }
    }
}

/// A square photo preview loaded from disk.
struct AttachmentThumbnail: View {
    let url: URL
    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemFill)
            .frame(height: 88)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(Rectangle())
            .task(id: url) {
                image = ImageProcessing.thumbnail(at: url, maxPixelSize: 320)
            }
    }
}
