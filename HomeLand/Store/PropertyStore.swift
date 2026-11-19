import Foundation
import UniformTypeIdentifiers

enum StoreError: LocalizedError {
    case propertyNotFound

    var errorDescription: String? {
        "That property no longer exists."
    }
}

/// Keeps the watchlist in memory and saves it as JSON in the app's Documents folder.
final class PropertyStore: ObservableObject {
    @Published private(set) var properties: [Property] = []
    /// A problem to show the user, such as a save failure.
    @Published var lastError: String?

    let fileURL: URL

    static var defaultFileURL: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("watchlist.json")
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(fileURL: URL = PropertyStore.defaultFileURL) {
        self.fileURL = fileURL
        load()
    }

    // MARK: - Reading

    func property(id: UUID) -> Property? {
        properties.first { $0.id == id }
    }

    // MARK: - Changes

    func upsert(_ property: Property) {
        var updated = property
        updated.dateUpdated = Date()
        if let index = properties.firstIndex(where: { $0.id == property.id }) {
            properties[index] = updated
        } else {
            properties.insert(updated, at: 0)
        }
        save()
    }

    func delete(ids: Set<UUID>) {
        properties.removeAll { ids.contains($0.id) }
        save()
        for id in ids {
            try? FileManager.default.removeItem(at: attachmentsFolder(for: id))
        }
    }

    /// Changes one property in place and saves.
    func update(_ id: UUID, _ change: (inout Property) -> Void) {
        guard let index = properties.firstIndex(where: { $0.id == id }) else { return }
        change(&properties[index])
        properties[index].dateUpdated = Date()
        save()
    }

    func setStatus(_ status: WatchStatus, for id: UUID) {
        update(id) { $0.status = status }
    }

    func toggleCheck(_ itemID: String, for id: UUID) {
        update(id) { property in
            if property.completedChecks.contains(itemID) {
                property.completedChecks.remove(itemID)
            } else {
                property.completedChecks.insert(itemID)
            }
        }
    }

    // MARK: - Attachments

    var attachmentsDirectory: URL {
        fileURL.deletingLastPathComponent().appendingPathComponent("Attachments", isDirectory: true)
    }

    func attachmentsFolder(for propertyID: UUID) -> URL {
        attachmentsDirectory.appendingPathComponent(propertyID.uuidString, isDirectory: true)
    }

    func fileURL(for attachment: Attachment, in propertyID: UUID) -> URL {
        attachmentsFolder(for: propertyID).appendingPathComponent(attachment.fileName)
    }

    @discardableResult
    func addAttachment(data: Data, name: String, fileExtension: String, kind: AttachmentKind, to propertyID: UUID) throws -> Attachment {
        guard property(id: propertyID) != nil else { throw StoreError.propertyNotFound }
        let folder = attachmentsFolder(for: propertyID)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let ext = fileExtension.isEmpty ? "dat" : fileExtension.lowercased()
        let attachment = Attachment(kind: kind, fileName: "\(UUID().uuidString).\(ext)", name: name)
        try data.write(to: folder.appendingPathComponent(attachment.fileName), options: .atomic)
        update(propertyID) { $0.attachments.append(attachment) }
        return attachment
    }

    /// Copies a picked file into the property's folder. Images are filed as photos.
    @discardableResult
    func importAttachment(from url: URL, to propertyID: UUID) throws -> Attachment {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        let ext = url.pathExtension.lowercased()
        let isImage = UTType(filenameExtension: ext)?.conforms(to: .image) ?? false
        return try addAttachment(
            data: data,
            name: url.lastPathComponent,
            fileExtension: ext,
            kind: isImage ? .photo : .document,
            to: propertyID
        )
    }

    func removeAttachment(_ attachmentID: UUID, from propertyID: UUID) {
        guard let attachment = property(id: propertyID)?.attachments.first(where: { $0.id == attachmentID }) else { return }
        try? FileManager.default.removeItem(at: fileURL(for: attachment, in: propertyID))
        update(propertyID) { property in
            property.attachments.removeAll { $0.id == attachmentID }
        }
    }

    // MARK: - Backup

    /// Writes the watchlist to a temporary file that can be shared or saved to Files.
    func exportBackup() throws -> URL {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let name = "HomeLand-watchlist-\(formatter.string(from: Date())).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try Self.encoder.encode(properties).write(to: url, options: .atomic)
        return url
    }

    /// Merges a backup into the watchlist. Matching properties are replaced
    /// when the backup's copy is at least as recent. Returns how many properties were read.
    @discardableResult
    func importBackup(from url: URL) throws -> Int {
        let data = try Data(contentsOf: url)
        let incoming = try Self.decoder.decode([Property].self, from: data)
        for var property in incoming {
            // Backups don't contain files, so only keep attachments that exist on this device.
            let propertyID = property.id
            property.attachments = property.attachments.filter {
                FileManager.default.fileExists(atPath: fileURL(for: $0, in: propertyID).path)
            }
            if let index = properties.firstIndex(where: { $0.id == property.id }) {
                if property.dateUpdated >= properties[index].dateUpdated {
                    let incomingIDs = Set(property.attachments.map(\.id))
                    property.attachments += properties[index].attachments.filter { !incomingIDs.contains($0.id) }
                    properties[index] = property
                }
            } else {
                properties.append(property)
            }
        }
        save()
        return incoming.count
    }

    // MARK: - Persistence

    func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            properties = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            properties = try Self.decoder.decode([Property].self, from: data)
        } catch {
            preserveUnreadableFile()
            properties = []
            lastError = "Your saved watchlist couldn't be read. A copy was kept in the app's files and a new list was started."
        }
    }

    private func save() {
        do {
            let data = try Self.encoder.encode(properties)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            lastError = "Couldn't save your watchlist: \(error.localizedDescription)"
        }
    }

    /// Moves a file that couldn't be decoded aside so the next save doesn't overwrite it.
    private func preserveUnreadableFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        let baseName = fileURL.deletingPathExtension().lastPathComponent
        let backup = fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(baseName)-unreadable-\(stamp).json")
        try? FileManager.default.moveItem(at: fileURL, to: backup)
    }
}
