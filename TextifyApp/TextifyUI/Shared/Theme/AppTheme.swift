import SwiftUI
import UIKit

enum AppTheme {
    // Semantic colors that adapt to color scheme
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)

    // Studio surfaces: quiet chrome around the artwork.
    static let studioBackground = Color(UIColor.systemGroupedBackground)
    static let accent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.23, green: 0.62, blue: 0.54, alpha: 1)
            : UIColor(red: 0.12, green: 0.38, blue: 0.33, alpha: 1)
    })
    static let canvasBackground = Color(red: 0.055, green: 0.10, blue: 0.105)
    static let canvasForeground = Color(red: 0.72, green: 0.91, blue: 0.80)

    // Text art specific
    static let textArtBackground = Color.black
    static let textArtForeground = Color.green

    // Typography
    static let titleFont = Font.system(.largeTitle, design: .rounded, weight: .bold)
    static let headlineFont = Font.system(.headline, design: .rounded, weight: .semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let monoFont = Font.system(.body, design: .monospaced)

    // Spacing
    static let spacing: CGFloat = 16
    static let cornerRadius: CGFloat = 16

    // Animation
    static let springAnimation = Animation.spring(response: 0.3, dampingFraction: 0.7)
}
