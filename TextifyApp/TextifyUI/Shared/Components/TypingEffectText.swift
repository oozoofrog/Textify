import SwiftUI

/// A text view that reveals characters progressively with a typewriter effect.
///
/// Displays text character-by-character when animation is enabled, or shows the full text instantly when disabled.
/// Ideal for ASCII art and monospaced content with adjustable reveal speed.
public struct TypingEffectText: View {
    // MARK: - Properties

    /// The full text to display
    let text: String

    /// Speed of character reveal (characters per second)
    let charactersPerSecond: Double

    /// Whether to animate the typing effect
    let shouldAnimate: Bool

    /// Number of characters currently visible
    @State private var visibleCharacters: Int = 0

    /// Animation task for cancellation
    @State private var animationTask: Task<Void, Never>?

    // MARK: - Initialization

    /// Creates a typing effect text view
    /// - Parameters:
    ///   - text: The text to display
    ///   - charactersPerSecond: Speed of reveal (default: 500 for ASCII art)
    ///   - shouldAnimate: Whether to animate or show instantly (default: true)
    public init(
        text: String,
        charactersPerSecond: Double = 500,
        shouldAnimate: Bool = true
    ) {
        self.text = text
        self.charactersPerSecond = charactersPerSecond
        self.shouldAnimate = shouldAnimate
    }

    // MARK: - Body

    public var body: some View {
        Text(displayedText)
            .font(.system(.body, design: .monospaced, weight: .regular))
            .onAppear {
                startTypingAnimation()
            }
            .onDisappear {
                cancelAnimation()
            }
            .onChange(of: text) { _, _ in
                restartAnimation()
            }
            .onChange(of: shouldAnimate) { _, _ in
                restartAnimation()
            }
    }

    // MARK: - Computed Properties

    /// The portion of text currently visible
    private var displayedText: String {
        if !shouldAnimate {
            return text
        }

        let endIndex = text.index(
            text.startIndex,
            offsetBy: min(visibleCharacters, text.count),
            limitedBy: text.endIndex
        ) ?? text.endIndex

        return String(text[..<endIndex])
    }

    // MARK: - Animation Control

    /// Starts the typing animation
    private func startTypingAnimation() {
        guard shouldAnimate else {
            visibleCharacters = text.count
            return
        }

        visibleCharacters = 0

        let delayPerCharacter = 1.0 / charactersPerSecond

        animationTask = Task { @MainActor in
            for index in 0..<text.count {
                guard !Task.isCancelled else { break }

                try? await Task.sleep(for: .seconds(delayPerCharacter))

                guard !Task.isCancelled else { break }
                visibleCharacters = index + 1
            }
        }
    }

    /// Cancels the current animation
    private func cancelAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }

    /// Restarts the animation from the beginning
    private func restartAnimation() {
        cancelAnimation()
        startTypingAnimation()
    }
}

// MARK: - Preview

#Preview("Typing Effect - Fast") {
    TypingEffectText(
        text: "Hello, World!",
        charactersPerSecond: 20,
        shouldAnimate: true
    )
    .padding()
}

#Preview("Typing Effect - ASCII Art") {
    TypingEffectText(
        text: """
        ╔═══════════════╗
        ║   TEXTIFY    ║
        ╚═══════════════╝
        """,
        charactersPerSecond: 500,
        shouldAnimate: true
    )
    .padding()
}

#Preview("No Animation") {
    TypingEffectText(
        text: "Instant reveal",
        shouldAnimate: false
    )
    .padding()
}
