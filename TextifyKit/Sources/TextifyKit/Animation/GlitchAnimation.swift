// GlitchAnimation.swift
import Foundation
import simd

/// Digital glitch effect animation
public struct GlitchAnimation: TextAnimation {
    public let duration: TimeInterval
    public let isLooping: Bool = true

    /// Probability of a row being glitched (0.0-1.0)
    public let glitchProbability: Float

    /// Maximum horizontal offset for glitch
    public let maxOffset: Float

    /// Color channel separation amount
    public let colorSeparation: Float

    /// Seed for deterministic randomness
    private let seed: UInt64

    public init(
        glitchProbability: Float = 0.1,
        maxOffset: Float = 20.0,
        colorSeparation: Float = 3.0,
        duration: TimeInterval = 5.0,
        seed: UInt64 = 12345
    ) {
        self.glitchProbability = glitchProbability
        self.maxOffset = maxOffset
        self.colorSeparation = colorSeparation
        self.duration = duration
        self.seed = seed
    }

    public func transform(
        for glyphIndex: Int,
        row: Int,
        col: Int,
        time: TimeInterval,
        totalGlyphs: Int
    ) -> GlyphTransform {
        // Use deterministic pseudo-random based on time and position
        let timeSlot = Int(time * 10)
        let hash = hashCombine(seed, UInt64(row), UInt64(timeSlot))
        let random = Float(hash % 1000) / 1000.0

        if random < glitchProbability {
            // This row is glitched
            let offsetHash = hashCombine(hash, UInt64(col))
            let offset = (Float(offsetHash % 1000) / 500.0 - 1.0) * maxOffset

            // Color channel shift
            let colorShift = (Float(offsetHash % 100) / 50.0 - 1.0) * colorSeparation

            return GlyphTransform(
                offset: SIMD2<Float>(offset, 0),
                colorMultiplier: SIMD4<Float>(1.0 + colorShift * 0.1, 1.0, 1.0 - colorShift * 0.1, 1.0)
            )
        }

        return .identity
    }

    private func hashCombine(_ values: UInt64...) -> UInt64 {
        var hash: UInt64 = 0
        for value in values {
            hash ^= value &+ 0x9e3779b97f4a7c15 &+ (hash << 6) &+ (hash >> 2)
        }
        return hash
    }
}
