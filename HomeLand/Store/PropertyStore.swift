import Foundation

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
    }

    func setStatus(_ status: WatchStatus, for id: UUID) {
        guard let index = properties.firstIndex(where: { $0.id == id }) else { return }
        properties[index].status = status
        properties[index].dateUpdated = Date()
        save()
    }

    func toggleCheck(_ itemID: String, for id: UUID) {
        guard let index = properties.firstIndex(where: { $0.id == id }) else { return }
        if properties[index].completedChecks.contains(itemID) {
            properties[index].completedChecks.remove(itemID)
        } else {
            properties[index].completedChecks.insert(itemID)
        }
        properties[index].dateUpdated = Date()
        save()
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
        for property in incoming {
            if let index = properties.firstIndex(where: { $0.id == property.id }) {
                if property.dateUpdated >= properties[index].dateUpdated {
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
