// RepeatPattern.swift
import Foundation
import simd

/// Pattern that repeats a message across the text art
public struct RepeatPattern: MessagePattern {
    public let message: String
    public let config: PatternConfiguration

    private let messageChars: [Character]

    public init(config: PatternConfiguration) {
        self.message = config.message
        self.config = config
        self.messageChars = Array(config.message)
    }

    public init(message: String, repeatMode: PatternConfiguration.RepeatMode = .horizontal) {
        self.init(config: PatternConfiguration(message: message, repeatMode: repeatMode))
    }

    public func character(at row: Int, col: Int, brightness: UInt8) -> Character? {
        // Only show pattern where brightness is below threshold
        guard brightness <= config.brightnessThreshold else {
            return nil
        }

        guard !messageChars.isEmpty else { return nil }

        let effectiveLength = messageChars.count + config.spacing

        let index: Int
        switch config.repeatMode {
        case .horizontal:
            index = col % effectiveLength
        case .vertical:
            index = row % effectiveLength
        case .diagonal:
            index = (row + col) % effectiveLength
        case .tile:
            let tileRow = row / effectiveLength
            let tileCol = col % effectiveLength
            index = (tileRow + tileCol) % effectiveLength
        }

        // Return space for spacing positions
        if index >= messageChars.count {
            return " "
        }

        return messageChars[index]
    }

    public func color(at row: Int, col: Int, originalColor: SIMD4<Float>) -> SIMD4<Float>? {
        switch config.colorMode {
        case .inherit:
            return nil
        case .solid(let color):
            return color
        case .gradient(let colors):
            guard colors.count >= 2 else { return colors.first }
            let t = Float(col) / 80.0  // Assume ~80 columns
            return interpolateGradient(colors, t: t)
        case .rainbow:
            let hue = Float(col + row) / 100.0
            return hueToRGB(hue.truncatingRemainder(dividingBy: 1.0))
        }
    }

    private func interpolateGradient(_ colors: [SIMD4<Float>], t: Float) -> SIMD4<Float> {
        let clampedT = max(0, min(1, t))
        let segment = clampedT * Float(colors.count - 1)
        let index = Int(segment)
        let fraction = segment - Float(index)

        let startIndex = min(index, colors.count - 1)
        let endIndex = min(index + 1, colors.count - 1)

        return colors[startIndex] * (1 - fraction) + colors[endIndex] * fraction
    }

    private func hueToRGB(_ hue: Float) -> SIMD4<Float> {
        let h = hue * 6.0
        let x = 1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0)

        let rgb: SIMD3<Float>
        switch Int(h) % 6 {
        case 0: rgb = SIMD3<Float>(1, x, 0)
        case 1: rgb = SIMD3<Float>(x, 1, 0)
        case 2: rgb = SIMD3<Float>(0, 1, x)
        case 3: rgb = SIMD3<Float>(0, x, 1)
        case 4: rgb = SIMD3<Float>(x, 0, 1)
        default: rgb = SIMD3<Float>(1, 0, x)
        }

        return SIMD4<Float>(rgb.x, rgb.y, rgb.z, 1.0)
    }
}
