// MaskPattern.swift
import Foundation
import simd

/// Pattern that uses brightness as a mask
public struct MaskPattern: MessagePattern {
    public let message: String
    public let maskMode: MaskMode
    public let threshold: UInt8
    public let color: SIMD4<Float>?
    public let invertMask: Bool

    private let messageChars: [Character]

    public enum MaskMode: Sendable {
        /// Show message where brightness is below threshold
        case dark
        /// Show message where brightness is above threshold
        case light
        /// Show message at edges (high contrast areas)
        case edges
    }

    public init(
        message: String,
        maskMode: MaskMode = .dark,
        threshold: UInt8 = 128,
        color: SIMD4<Float>? = nil,
        invertMask: Bool = false
    ) {
        self.message = message
        self.maskMode = maskMode
        self.threshold = threshold
        self.color = color
        self.invertMask = invertMask
        self.messageChars = Array(message)
    }

    public func character(at row: Int, col: Int, brightness: UInt8) -> Character? {
        guard !messageChars.isEmpty else { return nil }

        let shouldShow: Bool
        switch maskMode {
        case .dark:
            shouldShow = brightness <= threshold
        case .light:
            shouldShow = brightness >= threshold
        case .edges:
            // Edges mode would need neighbor info, simplified here
            shouldShow = brightness > 50 && brightness < 200
        }

        let finalShow = invertMask ? !shouldShow : shouldShow
        guard finalShow else { return nil }

        return messageChars[col % messageChars.count]
    }

    public func color(at row: Int, col: Int, originalColor: SIMD4<Float>) -> SIMD4<Float>? {
        color
    }
}

// MARK: - Pattern Factory

/// Factory for creating common patterns
public struct PatternFactory {

    /// Create an "I Love You" pattern
    public static func iLoveYou(name: String = "You") -> RepeatPattern {
        let config = PatternConfiguration(
            message: "I ❤ \(name) ",
            repeatMode: .horizontal,
            colorMode: .gradient([
                SIMD4<Float>(1.0, 0.3, 0.5, 1.0),
                SIMD4<Float>(1.0, 0.5, 0.7, 1.0)
            ]),
            brightnessThreshold: 150
        )
        return RepeatPattern(config: config)
    }

    /// Create a name pattern
    public static func name(_ name: String, color: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1)) -> RepeatPattern {
        let config = PatternConfiguration(
            message: name + " ",
            repeatMode: .diagonal,
            colorMode: .solid(color)
        )
        return RepeatPattern(config: config)
    }

    /// Create a rainbow text pattern
    public static func rainbow(_ message: String) -> RepeatPattern {
        let config = PatternConfiguration(
            message: message + " ",
            repeatMode: .horizontal,
            colorMode: .rainbow
        )
        return RepeatPattern(config: config)
    }

    /// Create a Matrix-style pattern
    public static func matrix() -> RepeatPattern {
        let config = PatternConfiguration(
            message: "01",
            repeatMode: .vertical,
            colorMode: .solid(SIMD4<Float>(0.2, 1.0, 0.3, 1.0)),
            brightnessThreshold: 200
        )
        return RepeatPattern(config: config)
    }
}
