// WaveAnimation.swift
import Foundation
import simd

/// Sine wave animation effect
public struct WaveAnimation: TextAnimation {
    public let duration: TimeInterval
    public let isLooping: Bool = true

    /// Wave amplitude in pixels
    public let amplitude: Float

    /// Wave frequency (waves per row)
    public let frequency: Float

    /// Wave speed (cycles per second)
    public let speed: Float

    /// Whether to animate color along with position
    public let animateColor: Bool

    public init(
        amplitude: Float = 5.0,
        frequency: Float = 0.2,
        speed: Float = 2.0,
        animateColor: Bool = false,
        duration: TimeInterval = 10.0
    ) {
        self.amplitude = amplitude
        self.frequency = frequency
        self.speed = speed
        self.animateColor = animateColor
        self.duration = duration
    }

    public func transform(
        for glyphIndex: Int,
        row: Int,
        col: Int,
        time: TimeInterval,
        totalGlyphs: Int
    ) -> GlyphTransform {
        let phase = Float(col) * frequency + Float(time) * speed
        let yOffset = sin(phase * .pi * 2) * amplitude

        var transform = GlyphTransform(offset: SIMD2<Float>(0, yOffset))

        if animateColor {
            // Rainbow color shift based on phase
            let hue = (phase / 10.0).truncatingRemainder(dividingBy: 1.0)
            transform.colorMultiplier = hueToRGB(hue)
        }

        return transform
    }

    private func hueToRGB(_ hue: Float) -> SIMD4<Float> {
        let h = hue * 6.0
        let x = 1.0 - abs(h.truncatingRemainder(dividingBy: 2.0) - 1.0)

        let rgb: SIMD3<Float>
        switch Int(h) {
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
