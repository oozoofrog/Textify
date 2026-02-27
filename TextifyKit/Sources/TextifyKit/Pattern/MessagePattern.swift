// MessagePattern.swift
import Foundation
import simd

/// Protocol for message patterns that overlay text on ASCII art
public protocol MessagePattern: Sendable {
    /// The message to display
    var message: String { get }

    /// Get the character to display at a given position
    /// - Parameters:
    ///   - row: Row index
    ///   - col: Column index
    ///   - brightness: Original brightness at this position (0-255)
    /// - Returns: Character to display, or nil to use original
    func character(at row: Int, col: Int, brightness: UInt8) -> Character?

    /// Get the color to use at a given position
    /// - Parameters:
    ///   - row: Row index
    ///   - col: Column index
    ///   - originalColor: Original color at this position
    /// - Returns: Color to use, or nil to use original
    func color(at row: Int, col: Int, originalColor: SIMD4<Float>) -> SIMD4<Float>?
}

/// Configuration for pattern behavior
public struct PatternConfiguration: Sendable, Equatable {
    /// The message text
    public var message: String

    /// How the message repeats
    public var repeatMode: RepeatMode

    /// Color mode for the pattern
    public var colorMode: ColorMode

    /// Brightness threshold (0-255) - pattern only shows where brightness is below this
    public var brightnessThreshold: UInt8

    /// Spacing between message repeats
    public var spacing: Int

    public enum RepeatMode: Sendable, Equatable {
        /// Repeat horizontally across each row
        case horizontal
        /// Repeat vertically down each column
        case vertical
        /// Repeat diagonally
        case diagonal
        /// Tile in a grid pattern
        case tile
    }

    public enum ColorMode: Sendable, Equatable {
        /// Keep original color
        case inherit
        /// Single solid color
        case solid(SIMD4<Float>)
        /// Gradient colors
        case gradient([SIMD4<Float>])
        /// Rainbow cycling
        case rainbow
    }

    public init(
        message: String,
        repeatMode: RepeatMode = .horizontal,
        colorMode: ColorMode = .inherit,
        brightnessThreshold: UInt8 = 128,
        spacing: Int = 1
    ) {
        self.message = message
        self.repeatMode = repeatMode
        self.colorMode = colorMode
        self.brightnessThreshold = brightnessThreshold
        self.spacing = spacing
    }
}

/// Default extension for color handling
public extension MessagePattern {
    func color(at row: Int, col: Int, originalColor: SIMD4<Float>) -> SIMD4<Float>? {
        nil  // Default: use original color
    }
}
