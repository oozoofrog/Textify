// TextAnimation.swift
import Foundation
import QuartzCore
import simd

/// Transform applied to individual glyphs during animation
public struct GlyphTransform: Sendable, Equatable {
    /// Position offset from base position
    public var offset: SIMD2<Float>

    /// Scale factor (1.0 = normal)
    public var scale: Float

    /// Rotation in radians
    public var rotation: Float

    /// Color multiplier (applied to base color)
    public var colorMultiplier: SIMD4<Float>

    /// Alpha multiplier (0.0 = invisible, 1.0 = fully visible)
    public var alpha: Float

    public static let identity = GlyphTransform(
        offset: .zero,
        scale: 1.0,
        rotation: 0.0,
        colorMultiplier: SIMD4<Float>(1, 1, 1, 1),
        alpha: 1.0
    )

    public init(
        offset: SIMD2<Float> = .zero,
        scale: Float = 1.0,
        rotation: Float = 0.0,
        colorMultiplier: SIMD4<Float> = SIMD4<Float>(1, 1, 1, 1),
        alpha: Float = 1.0
    ) {
        self.offset = offset
        self.scale = scale
        self.rotation = rotation
        self.colorMultiplier = colorMultiplier
        self.alpha = alpha
    }
}

/// Protocol for text animations
public protocol TextAnimation: Sendable {
    /// Total duration of one animation cycle
    var duration: TimeInterval { get }

    /// Whether the animation loops
    var isLooping: Bool { get }

    /// Calculate transform for a specific glyph at a given time
    /// - Parameters:
    ///   - glyphIndex: Linear index of the glyph
    ///   - row: Row position
    ///   - col: Column position
    ///   - time: Current time in seconds
    ///   - totalGlyphs: Total number of glyphs
    /// - Returns: Transform to apply to this glyph
    func transform(
        for glyphIndex: Int,
        row: Int,
        col: Int,
        time: TimeInterval,
        totalGlyphs: Int
    ) -> GlyphTransform
}

/// Animation state manager
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public final class AnimationController: ObservableObject {
    @Published public private(set) var currentTime: TimeInterval = 0
    @Published public private(set) var isPlaying: Bool = false

    public var animation: (any TextAnimation)?
    private var startTime: TimeInterval = 0

    public init() {}

    public func play() {
        isPlaying = true
        startTime = CACurrentMediaTime() - currentTime
    }

    public func pause() {
        isPlaying = false
    }

    public func reset() {
        currentTime = 0
        startTime = CACurrentMediaTime()
    }

    public func update() {
        guard isPlaying, let animation = animation else { return }

        let elapsed = CACurrentMediaTime() - startTime

        if animation.isLooping {
            currentTime = elapsed.truncatingRemainder(dividingBy: animation.duration)
        } else {
            currentTime = min(elapsed, animation.duration)
            if currentTime >= animation.duration {
                isPlaying = false
            }
        }
    }
}
