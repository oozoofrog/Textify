import Foundation

/// Errors that can occur during history operations
public enum HistoryError: Error, LocalizedError {
    case saveFailed(Error)
    case loadFailed(Error)
    case maxEntriesExceeded

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save history: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load history: \(error.localizedDescription)"
        case .maxEntriesExceeded:
            return "Maximum number of history entries exceeded"
        }
    }
}

/// Protocol for history service operations
public protocol HistoryServiceProtocol: Sendable {
    func add(_ entry: HistoryEntry) async throws
    func delete(id: UUID) async throws
    func clear() async throws
    func list() async throws -> [HistoryEntry]
}

/// Actor-based service for managing text generation history
public actor HistoryService: HistoryServiceProtocol {
    private let maxEntries = 50
    private let fileManager = FileManager.default
    private let historyFileName = "history.json"

    private var entries: [HistoryEntry] = []
    private var isLoaded = false

    public init() {}

    /// Adds a new history entry
    /// - Parameter entry: The entry to add
    /// - Throws: HistoryError if save fails
    public func add(_ entry: HistoryEntry) async throws {
        try await loadIfNeeded()

        // Add new entry at the beginning
        entries.insert(entry, at: 0)

        // Enforce FIFO eviction if max entries exceeded
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        try await save()
    }

    /// Deletes a history entry by ID
    /// - Parameter id: The ID of the entry to delete
    /// - Throws: HistoryError if save fails
    public func delete(id: UUID) async throws {
        try await loadIfNeeded()
        entries.removeAll { $0.id == id }
        try await save()
    }

    /// Clears all history entries
    /// - Throws: HistoryError if save fails
    public func clear() async throws {
        entries.removeAll()
        try await save()
    }

    /// Lists all history entries
    /// - Returns: Array of history entries, newest first
    /// - Throws: HistoryError if load fails
    public func list() async throws -> [HistoryEntry] {
        try await loadIfNeeded()
        return entries
    }

    // MARK: - Private Methods

    private func loadIfNeeded() async throws {
        guard !isLoaded else { return }
        try await load()
        isLoaded = true
    }

    private func load() async throws {
        let fileURL = try historyFileURL()

        guard fileManager.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            entries = try JSONDecoder().decode([HistoryEntry].self, from: data)
        } catch {
            throw HistoryError.loadFailed(error)
        }
    }

    private func save() async throws {
        let fileURL = try historyFileURL()

        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw HistoryError.saveFailed(error)
        }
    }

    private func historyFileURL() throws -> URL {
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return documentsDirectory.appendingPathComponent(historyFileName)
    }
}
