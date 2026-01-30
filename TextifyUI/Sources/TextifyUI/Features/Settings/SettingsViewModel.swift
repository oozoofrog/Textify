import Foundation
import SwiftUI
import Observation

/// ViewModel for the settings screen
@Observable
@MainActor
public final class SettingsViewModel {
    private let appearanceService: AppearanceServiceProtocol

    /// The current appearance mode
    public var appearanceMode: AppearanceMode {
        get { appearanceService.currentMode }
        set { appearanceService.setMode(newValue) }
    }

    /// Whether to show the clear history confirmation dialog
    public var showClearHistoryConfirmation = false

    /// Initializes the settings view model
    /// - Parameter appearanceService: Service for managing appearance settings
    public init(appearanceService: AppearanceServiceProtocol) {
        self.appearanceService = appearanceService
    }

    /// Shows the clear history confirmation dialog
    public func requestClearHistory() {
        showClearHistoryConfirmation = true
    }

    /// Clears the app history
    public func confirmClearHistory() {
        // TODO: Implement history clearing when HistoryService is available
        showClearHistoryConfirmation = false
    }

    /// Cancels the clear history operation
    public func cancelClearHistory() {
        showClearHistoryConfirmation = false
    }
}
