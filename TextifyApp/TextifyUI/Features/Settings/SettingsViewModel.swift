import Foundation
import SwiftUI
import Observation

/// ViewModel for the settings screen
@Observable
@MainActor
public final class SettingsViewModel {
    private let appearanceService: AppearanceServiceProtocol
    private let historyService: any HistoryServiceProtocol
    private let photoLibrarySaveAuthorizer: any PhotoLibrarySaveAuthorizing

    /// The current appearance mode
    public var appearanceMode: AppearanceMode {
        get { appearanceService.currentMode }
        set { appearanceService.setMode(newValue) }
    }

    public private(set) var photoSaveAuthorizationStatus: PhotoLibrarySaveAuthorizationStatus = .notDetermined
    public var showClearHistoryConfirmation = false
    public var isClearingHistory = false
    public var errorMessage: String?

    public init(
        appearanceService: AppearanceServiceProtocol,
        historyService: any HistoryServiceProtocol,
        photoLibrarySaveAuthorizer: any PhotoLibrarySaveAuthorizing
    ) {
        self.appearanceService = appearanceService
        self.historyService = historyService
        self.photoLibrarySaveAuthorizer = photoLibrarySaveAuthorizer
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

    public func refreshPhotoSavePermission() async {
        photoSaveAuthorizationStatus = photoLibrarySaveAuthorizer.currentStatus()
    }

    public var photoPermissionTitle: String {
        photoSaveAuthorizationStatus.displayName
    }

    public var photoPermissionGuidance: String {
        photoSaveAuthorizationStatus.guidance
    }

    public var recommendsOpeningSettings: Bool {
        photoSaveAuthorizationStatus.recommendsOpeningSettings
    }
}
