import Foundation
import SwiftUI
import Observation

/// ViewModel for the settings screen
@Observable
@MainActor
public final class SettingsViewModel {
    private let appearanceService: AppearanceServiceProtocol
    private let historyService: any HistoryServiceProtocol

    /// The current appearance mode
    public var appearanceMode: AppearanceMode {
        get { appearanceService.currentMode }
        set { appearanceService.setMode(newValue) }
    }

    public var showClearHistoryConfirmation = false
    public var isClearingHistory = false
    public var errorMessage: String?

    public init(
        appearanceService: AppearanceServiceProtocol,
        historyService: any HistoryServiceProtocol
    ) {
        self.appearanceService = appearanceService
        self.historyService = historyService
    }

    public func requestClearHistory() {
        showClearHistoryConfirmation = true
    }

    public func confirmClearHistory() async {
        isClearingHistory = true
        errorMessage = nil

        do {
            try await historyService.clear()
            showClearHistoryConfirmation = false
        } catch {
            errorMessage = "히스토리를 삭제하지 못했습니다."
        }

        isClearingHistory = false
    }

    public func cancelClearHistory() {
        showClearHistoryConfirmation = false
    }
}
