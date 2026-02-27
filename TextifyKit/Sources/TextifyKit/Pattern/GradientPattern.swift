// GradientPattern.swift
import Foundation
import simd

/// Pattern with gradient color effects
public struct GradientPattern: MessagePattern {
    public let message: String
    public let colors: [SIMD4<Float>]
    public let direction: Direction
    public let brightnessThreshold: UInt8

    private let messageChars: [Character]

    public enum Direction: Sendable {
        case horizontal
        case vertical
        case radial
        case diagonal
    }

    public init(
        message: String,
        colors: [SIMD4<Float>],
        direction: Direction = .horizontal,
        brightnessThreshold: UInt8 = 128
    ) {
        self.message = message
        self.colors = colors
        self.direction = direction
        self.brightnessThreshold = brightnessThreshold
        self.messageChars = Array(message)
    }

    /// Preset: Love gradient (pink to red)
    public static func love(_ message: String) -> GradientPattern {
        GradientPattern(
            message: message,
            colors: [
                SIMD4<Float>(1.0, 0.4, 0.6, 1.0),  // Pink
                SIMD4<Float>(1.0, 0.2, 0.3, 1.0),  // Light Red
                SIMD4<Float>(0.9, 0.1, 0.2, 1.0),  // Red
            ],
            direction: .horizontal
        )
    }

    /// Preset: Ocean gradient (blue to cyan)
    public static func ocean(_ message: String) -> GradientPattern {
        GradientPattern(
            message: message,
            colors: [
                SIMD4<Float>(0.0, 0.2, 0.6, 1.0),  // Deep Blue
                SIMD4<Float>(0.0, 0.5, 0.8, 1.0),  // Blue
                SIMD4<Float>(0.0, 0.8, 1.0, 1.0),  // Cyan
            ],
            direction: .vertical
        )
    }

    /// Preset: Sunset gradient
    public static func sunset(_ message: String) -> GradientPattern {
        GradientPattern(
            message: message,
            colors: [
                SIMD4<Float>(1.0, 0.3, 0.1, 1.0),  // Orange
                SIMD4<Float>(1.0, 0.5, 0.2, 1.0),  // Light Orange
                SIMD4<Float>(1.0, 0.8, 0.3, 1.0),  // Yellow
            ],
            direction: .radial
        )
    }

    public func character(at row: Int, col: Int, brightness: UInt8) -> Character? {
        guard brightness <= brightnessThreshold else { return nil }
        guard !messageChars.isEmpty else { return nil }

        return messageChars[col % messageChars.count]
    }

    public func color(at row: Int, col: Int, originalColor: SIMD4<Float>) -> SIMD4<Float>? {
        guard colors.count >= 2 else { return colors.first }

        let t: Float
        switch direction {
        case .horizontal:
            t = Float(col) / 80.0
        case .vertical:
            t = Float(row) / 60.0
        case .radial:
            let centerX: Float = 40
            let centerY: Float = 30
            let dx = Float(col) - centerX
            let dy = Float(row) - centerY
            t = sqrt(dx * dx + dy * dy) / 50.0
        case .diagonal:
            t = Float(col + row) / 140.0
        }

        return interpolate(colors, t: t.truncatingRemainder(dividingBy: 1.0))
    }

    private func interpolate(_ colors: [SIMD4<Float>], t: Float) -> SIMD4<Float> {
        let segment = t * Float(colors.count - 1)
        let index = Int(segment)
        let fraction = segment - Float(index)

        let startIndex = min(index, colors.count - 1)
        let endIndex = min(index + 1, colors.count - 1)

        return colors[startIndex] * (1 - fraction) + colors[endIndex] * fraction
    }
}
