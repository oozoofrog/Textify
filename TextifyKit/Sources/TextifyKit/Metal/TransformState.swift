// TransformState.swift
import Foundation
import simd

/// Manages transform state for zoom/pan interactions
/// Thread-safe and optimized for real-time updates
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public final class TransformState: ObservableObject, Sendable {

    // MARK: - Published Properties

    /// Current scale factor (1.0 = 100%)
    @Published public private(set) var scale: Float = 1.0

    /// Current translation offset
    @Published public private(set) var translation: SIMD2<Float> = .zero

    // MARK: - Configuration

    /// Minimum allowed scale
    public var minScale: Float = 0.1

    /// Maximum allowed scale
    public var maxScale: Float = 100.0

    /// Content size for bounds calculation
    public var contentSize: SIMD2<Float> = .zero

    /// Viewport size for bounds calculation
    public var viewportSize: SIMD2<Float> = .zero

    // MARK: - Gesture State

    private var gestureStartScale: Float = 1.0
    private var gestureStartTranslation: SIMD2<Float> = .zero
    private var pinchAnchor: SIMD2<Float> = .zero

    // MARK: - Animation State

    private var targetScale: Float = 1.0
    private var targetTranslation: SIMD2<Float> = .zero
    private var isAnimating: Bool = false

    // MARK: - Initialization

    public init(scale: Float = 1.0, translation: SIMD2<Float> = .zero) {
        self.scale = scale
        self.translation = translation
        self.targetScale = scale
        self.targetTranslation = translation
    }

    // MARK: - Transform Matrix

    /// Get the current transform as a 4x4 matrix for Metal rendering
    public var transformMatrix: simd_float4x4 {
        let scaleMatrix = simd_float4x4(diagonal: SIMD4<Float>(scale, scale, 1, 1))
        let translationMatrix = simd_float4x4(columns: (
            SIMD4<Float>(1, 0, 0, 0),
            SIMD4<Float>(0, 1, 0, 0),
            SIMD4<Float>(0, 0, 1, 0),
            SIMD4<Float>(translation.x, translation.y, 0, 1)
        ))
        return translationMatrix * scaleMatrix
    }

    /// Get the current transform as CGAffineTransform for UIKit/SwiftUI
    public var affineTransform: CGAffineTransform {
        CGAffineTransform(translationX: CGFloat(translation.x), y: CGFloat(translation.y))
            .scaledBy(x: CGFloat(scale), y: CGFloat(scale))
    }

    // MARK: - Gesture Handling

    /// Begin a pinch gesture
    /// - Parameter anchor: The anchor point in view coordinates
    public func beginPinch(anchor: SIMD2<Float>) {
        gestureStartScale = scale
        gestureStartTranslation = translation
        pinchAnchor = anchor
        isAnimating = false
    }

    /// Update during a pinch gesture
    /// - Parameters:
    ///   - magnification: The magnification factor (1.0 = no change)
    ///   - anchor: Current anchor point
    public func updatePinch(magnification: Float, anchor: SIMD2<Float>) {
        // Calculate new scale with clamping
        let newScale = clamp(gestureStartScale * magnification, min: minScale, max: maxScale)

        // Calculate translation to keep anchor point fixed
        let scaleDelta = newScale / scale
        let anchorOffset = anchor - translation
        let newTranslation = anchor - anchorOffset * scaleDelta

        scale = newScale
        translation = clampTranslation(newTranslation)
    }

    /// End a pinch gesture with optional velocity for momentum
    /// - Parameter velocity: Scale velocity for momentum animation
    public func endPinch(velocity: Float = 0) {
        // Apply bounce-back if outside bounds
        if scale < 1.0 {
            animateTo(scale: 1.0, translation: .zero)
        } else if scale > maxScale {
            animateTo(scale: maxScale, translation: translation)
        }
    }

    /// Begin a pan gesture
    public func beginPan() {
        gestureStartTranslation = translation
        isAnimating = false
    }

    /// Update during a pan gesture
    /// - Parameter delta: Translation delta
    public func updatePan(delta: SIMD2<Float>) {
        let newTranslation = gestureStartTranslation + delta
        translation = clampTranslation(newTranslation, allowBounce: true)
    }

    /// End a pan gesture with velocity for inertial scrolling
    /// - Parameter velocity: Velocity in points per second
    public func endPan(velocity: SIMD2<Float>) {
        // Apply inertial scrolling (simplified - full implementation would use display link)
        let decelerationRate: Float = 0.95
        let targetOffset = translation + velocity * 0.3 * decelerationRate
        let clampedTarget = clampTranslation(targetOffset)

        if clampedTarget != translation {
            animateTo(scale: scale, translation: clampedTarget)
        }
    }

    /// Handle double-tap zoom
    /// - Parameter location: Tap location in view coordinates
    public func doubleTap(at location: SIMD2<Float>) {
        if scale > 1.5 {
            // Zoom out to fit
            animateTo(scale: 1.0, translation: .zero)
        } else {
            // Zoom in to 2x centered on tap
            let newScale: Float = 2.0
            let newTranslation = location - (location - translation) * (newScale / scale)
            animateTo(scale: newScale, translation: clampTranslation(newTranslation))
        }
    }

    // MARK: - Animation

    /// Animate to a target transform
    public func animateTo(scale: Float, translation: SIMD2<Float>, duration: TimeInterval = 0.25) {
        targetScale = clamp(scale, min: minScale, max: maxScale)
        targetTranslation = clampTranslation(translation)
        isAnimating = true

        // Animation will be driven by the view's update loop
        // This just sets the targets
    }

    /// Update animation (call each frame)
    /// - Parameter deltaTime: Time since last update
    /// - Returns: True if animation is still in progress
    @discardableResult
    public func updateAnimation(deltaTime: TimeInterval) -> Bool {
        guard isAnimating else { return false }

        let t = Float(min(deltaTime * 10, 1.0))  // Smooth interpolation factor

        scale = mix(scale, targetScale, t: t)
        translation = mix(translation, targetTranslation, t: t)

        // Check if animation is complete
        let scaleComplete = abs(scale - targetScale) < 0.001
        let translationComplete = length(translation - targetTranslation) < 0.1

        if scaleComplete && translationComplete {
            scale = targetScale
            translation = targetTranslation
            isAnimating = false
        }

        return isAnimating
    }

    /// Reset to identity transform
    public func reset() {
        scale = 1.0
        translation = .zero
        targetScale = 1.0
        targetTranslation = .zero
        isAnimating = false
    }

    // MARK: - Helpers

    private func clamp(_ value: Float, min minVal: Float, max maxVal: Float) -> Float {
        Swift.min(Swift.max(value, minVal), maxVal)
    }

    private func mix(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * t
    }

    private func mix(_ a: SIMD2<Float>, _ b: SIMD2<Float>, t: Float) -> SIMD2<Float> {
        a + (b - a) * t
    }

    private func clampTranslation(_ t: SIMD2<Float>, allowBounce: Bool = false) -> SIMD2<Float> {
        guard contentSize.x > 0 && viewportSize.x > 0 else { return t }

        let scaledContent = contentSize * scale

        // Calculate bounds
        let minX = viewportSize.x - scaledContent.x
        let minY = viewportSize.y - scaledContent.y
        let maxX: Float = 0
        let maxY: Float = 0

        if allowBounce {
            // Allow 20% overshoot for rubber band effect
            let bounceX = scaledContent.x * 0.2
            let bounceY = scaledContent.y * 0.2
            return SIMD2<Float>(
                clamp(t.x, min: minX - bounceX, max: maxX + bounceX),
                clamp(t.y, min: minY - bounceY, max: maxY + bounceY)
            )
        } else {
            return SIMD2<Float>(
                clamp(t.x, min: minX, max: maxX),
                clamp(t.y, min: minY, max: maxY)
            )
        }
    }
}
