import SwiftUI
import Observation

@MainActor
@Observable
public final class HistoryViewModel {
    private let historyService: HistoryServiceProtocol

    public var entries: [HistoryEntry] = []
    public var isLoading = false
    public var error: AppError?
    public var showDeleteConfirmation = false

    public init(historyService: HistoryServiceProtocol) {
        self.historyService = historyService
    }

    public func loadHistory() async {
        isLoading = true
        error = nil

        do {
            entries = try await historyService.list()
        } catch {
            self.error = .generation(underlying: error)
        }

        isLoading = false
    }

    public func deleteEntry(_ entry: HistoryEntry) async {
        do {
            try await historyService.delete(id: entry.id)
            entries.removeAll { $0.id == entry.id }
        } catch {
            self.error = .generation(underlying: error)
        }
    }

    public func clearAll() async {
        do {
            try await historyService.clear()
            entries.removeAll()
            showDeleteConfirmation = false
        } catch {
            self.error = .generation(underlying: error)
        }
    }
}
