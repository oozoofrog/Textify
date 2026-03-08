import Foundation
import SwiftUI

/// Appearance mode options
public enum AppearanceMode: String, Codable, Sendable, CaseIterable {
    case system
    case light
    case dark

    public var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Protocol for appearance service operations
@MainActor
public protocol AppearanceServiceProtocol {
    var currentMode: AppearanceMode { get }
    func setMode(_ mode: AppearanceMode)
}

/// Observable service for managing app appearance settings
@MainActor
@Observable
public final class AppearanceService: AppearanceServiceProtocol {
    private let userDefaults = UserDefaults.standard
    private let appearanceModeKey = "com.textify.appearanceMode"

    /// The current appearance mode
    public private(set) var currentMode: AppearanceMode {
        didSet {
            saveMode()
        }
    }

    public init() {
        // Load saved mode or default to system
        if let savedModeString = userDefaults.string(forKey: appearanceModeKey),
           let savedMode = AppearanceMode(rawValue: savedModeString) {
            self.currentMode = savedMode
        } else {
            self.currentMode = .system
        }
    }

    /// Sets the appearance mode
    /// - Parameter mode: The new appearance mode
    public func setMode(_ mode: AppearanceMode) {
        currentMode = mode
    }

    // MARK: - Private Methods

    private func saveMode() {
        userDefaults.set(currentMode.rawValue, forKey: appearanceModeKey)
    }
}
