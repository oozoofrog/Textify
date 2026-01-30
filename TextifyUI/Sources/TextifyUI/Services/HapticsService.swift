import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Haptic feedback impact styles
public enum HapticImpactStyle: Sendable {
    case light
    case medium
    case heavy
    case soft
    case rigid
}

/// Haptic feedback notification types
public enum HapticNotificationType: Sendable {
    case success
    case warning
    case error
}

/// Protocol for haptics service operations
@MainActor
public protocol HapticsServiceProtocol {
    func impact(style: HapticImpactStyle)
    func selection()
    func notification(type: HapticNotificationType)
}

/// Singleton service for providing haptic feedback
@MainActor
public final class HapticsService: HapticsServiceProtocol {
    public static let shared = HapticsService()

    #if canImport(UIKit)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let softGenerator = UIImpactFeedbackGenerator(style: .soft)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    #endif

    private init() {
        #if canImport(UIKit)
        // Prepare generators for reduced latency
        lightGenerator.prepare()
        mediumGenerator.prepare()
        heavyGenerator.prepare()
        softGenerator.prepare()
        rigidGenerator.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
        #endif
    }

    /// Triggers an impact haptic feedback
    /// - Parameter style: The impact style
    public func impact(style: HapticImpactStyle) {
        #if canImport(UIKit)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:
            generator = lightGenerator
        case .medium:
            generator = mediumGenerator
        case .heavy:
            generator = heavyGenerator
        case .soft:
            generator = softGenerator
        case .rigid:
            generator = rigidGenerator
        }
        generator.impactOccurred()
        generator.prepare()
        #endif
    }

    /// Triggers a selection haptic feedback
    public func selection() {
        #if canImport(UIKit)
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
        #endif
    }

    /// Triggers a notification haptic feedback
    /// - Parameter type: The notification type
    public func notification(type: HapticNotificationType) {
        #if canImport(UIKit)
        let feedbackType: UINotificationFeedbackGenerator.FeedbackType
        switch type {
        case .success:
            feedbackType = .success
        case .warning:
            feedbackType = .warning
        case .error:
            feedbackType = .error
        }
        notificationGenerator.notificationOccurred(feedbackType)
        notificationGenerator.prepare()
        #endif
    }
}
