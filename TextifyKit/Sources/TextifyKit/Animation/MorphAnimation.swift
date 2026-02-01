// MorphAnimation.swift
import Foundation
import simd

/// Morphing animation between states
public struct MorphAnimation: TextAnimation {
    public let duration: TimeInterval
    public let isLooping: Bool

    /// Stagger delay between glyphs
    public let staggerDelay: TimeInterval

    /// Whether to fade in or out
    public let fadeIn: Bool

    /// Scale effect during morph
    public let scaleEffect: Float

    public init(
        duration: TimeInterval = 2.0,
        staggerDelay: TimeInterval = 0.02,
        fadeIn: Bool = true,
        scaleEffect: Float = 0.5,
        isLooping: Bool = false
    ) {
        self.duration = duration
        self.staggerDelay = staggerDelay
        self.fadeIn = fadeIn
        self.scaleEffect = scaleEffect
        self.isLooping = isLooping
    }

    public func transform(
        for glyphIndex: Int,
        row: Int,
        col: Int,
        time: TimeInterval,
        totalGlyphs: Int
    ) -> GlyphTransform {
        let glyphDelay = Double(glyphIndex) * staggerDelay
        let glyphTime = max(0, time - glyphDelay)
        let glyphDuration = duration - Double(totalGlyphs) * staggerDelay

        let progress = Float(min(glyphTime / max(glyphDuration, 0.001), 1.0))

        // Ease in-out curve
        let easedProgress = easeInOut(progress)

        let alpha: Float
        let scale: Float

        if fadeIn {
            alpha = easedProgress
            scale = scaleEffect + (1.0 - scaleEffect) * easedProgress
        } else {
            alpha = 1.0 - easedProgress
            scale = 1.0 - (1.0 - scaleEffect) * easedProgress
        }

        return GlyphTransform(scale: scale, alpha: alpha)
    }

    private func easeInOut(_ t: Float) -> Float {
        if t < 0.5 {
            return 2 * t * t
        } else {
            return 1 - pow(-2 * t + 2, 2) / 2
        }
    }
}
