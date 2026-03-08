import SwiftUI
import UIKit

enum AppTheme {
    // Semantic colors that adapt to color scheme
    static let background = Color(UIColor.systemBackground)
    static let secondaryBackground = Color(UIColor.secondarySystemBackground)
    static let tertiaryBackground = Color(UIColor.tertiarySystemBackground)

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
