// TypingAnimation.swift
import Foundation
import simd

/// Typewriter-style reveal animation
public struct TypingAnimation: TextAnimation {
    public let duration: TimeInterval
    public let isLooping: Bool

    /// Characters revealed per second
    public let charactersPerSecond: Double

    /// Cursor blink interval
    public let cursorBlinkInterval: TimeInterval

    /// Direction of typing
    public let direction: Direction

    public enum Direction: Sendable {
        case leftToRight
        case topToBottom
        case diagonal
    }

    public init(
        totalGlyphs: Int,
        charactersPerSecond: Double = 50,
        cursorBlinkInterval: TimeInterval = 0.5,
        direction: Direction = .leftToRight,
        isLooping: Bool = false
    ) {
        self.charactersPerSecond = charactersPerSecond
        self.cursorBlinkInterval = cursorBlinkInterval
        self.direction = direction
        self.isLooping = isLooping
        self.duration = Double(totalGlyphs) / charactersPerSecond + 0.5  // Extra time for cursor
    }

    public func transform(
        for glyphIndex: Int,
        row: Int,
        col: Int,
        time: TimeInterval,
        totalGlyphs: Int
    ) -> GlyphTransform {
        let revealedCount = Int(time * charactersPerSecond)

        // Calculate glyph order based on direction
        let orderIndex: Int
        switch direction {
        case .leftToRight:
            orderIndex = glyphIndex
        case .topToBottom:
            // Reorder: column-first
            let width = totalGlyphs > 0 ? (glyphIndex / max(row + 1, 1)) : 0
            orderIndex = col * (totalGlyphs / max(width, 1)) + row
        case .diagonal:
            orderIndex = row + col
        }

        if orderIndex < revealedCount {
            // Fully visible
            return .identity
        } else if orderIndex == revealedCount {
            // Cursor position - blink effect
            let blinkPhase = time.truncatingRemainder(dividingBy: cursorBlinkInterval * 2)
            let cursorVisible = blinkPhase < cursorBlinkInterval
            return GlyphTransform(alpha: cursorVisible ? 1.0 : 0.3)
        } else {
            // Not yet revealed
            return GlyphTransform(alpha: 0.0)
        }
    }
}
