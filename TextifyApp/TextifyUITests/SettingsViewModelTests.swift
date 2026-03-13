import Foundation
import Testing
@testable import TextifyUI

actor SettingsHistoryServiceMock: HistoryServiceProtocol {
    private(set) var clearCallCount = 0
    var shouldThrow = false

    func add(_ entry: HistoryEntry) async throws {}
    func delete(id: UUID) async throws {}

    func clear() async throws {
        if shouldThrow {
            throw HistoryError.saveFailed(NSError(domain: "SettingsHistoryServiceMock", code: -1))
        }
        clearCallCount += 1
    }

    func list() async throws -> [HistoryEntry] { [] }

    func setShouldThrow(_ value: Bool) {
        shouldThrow = value
    }
}

@MainActor
final class AppearanceServiceFake: AppearanceServiceProtocol {
    var currentMode: AppearanceMode = .system

    func setMode(_ mode: AppearanceMode) {
        currentMode = mode
    }
}

@Suite("SettingsViewModel Tests")
struct SettingsViewModelTests {

    @Test("Confirm clear history clears data and closes confirmation")
    @MainActor
    func testConfirmClearHistorySuccess() async throws {
        let history = SettingsHistoryServiceMock()
        let appearance = AppearanceServiceFake()
        let viewModel = SettingsViewModel(
            appearanceService: appearance,
            historyService: history
        )

        viewModel.requestClearHistory()
        await viewModel.confirmClearHistory()

        #expect(viewModel.showClearHistoryConfirmation == false)
        #expect(viewModel.errorMessage == nil)
        #expect(await history.clearCallCount == 1)
    }

    @Test("Confirm clear history surfaces error on failure")
    @MainActor
    func testConfirmClearHistoryFailure() async throws {
        let history = SettingsHistoryServiceMock()
        await history.setShouldThrow(true)
        let appearance = AppearanceServiceFake()
        let viewModel = SettingsViewModel(
            appearanceService: appearance,
            historyService: history
        )

        viewModel.requestClearHistory()
        await viewModel.confirmClearHistory()

        #expect(viewModel.errorMessage != nil)
    }
}
