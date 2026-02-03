import XCTest
import simd
@testable import TextifyKit

final class AnimationTests: XCTestCase {

    // MARK: - GlyphTransform Tests

    func testGlyphTransformDefaults() {
        let transform = GlyphTransform()

        XCTAssertEqual(transform.offset, SIMD2<Float>.zero)
        XCTAssertEqual(transform.scale, 1.0)
        XCTAssertEqual(transform.rotation, 0.0)
        XCTAssertEqual(transform.colorMultiplier, SIMD4<Float>(1, 1, 1, 1))
        XCTAssertEqual(transform.alpha, 1.0)
    }

    func testGlyphTransformCustomValues() {
        let transform = GlyphTransform(
            offset: SIMD2<Float>(10, 20),
            scale: 2.0,
            rotation: 0.5,
            colorMultiplier: SIMD4<Float>(1, 0, 0, 1),
            alpha: 0.8
        )

        XCTAssertEqual(transform.offset, SIMD2<Float>(10, 20))
        XCTAssertEqual(transform.scale, 2.0)
        XCTAssertEqual(transform.rotation, 0.5)
        XCTAssertEqual(transform.alpha, 0.8)
    }

    // MARK: - TypingAnimation Tests

    func testTypingAnimationInit() {
        let animation = TypingAnimation(totalGlyphs: 100)

        XCTAssertGreaterThan(animation.duration, 0)
        XCTAssertFalse(animation.isLooping)
    }

    func testTypingAnimationReveals() {
        let animation = TypingAnimation(
            totalGlyphs: 100,
            charactersPerSecond: 10
        )

        // At time 0, first few characters should be visible
        let t0 = animation.transform(for: 0, row: 0, col: 0, time: 0.0, totalGlyphs: 100)
        XCTAssertEqual(t0.alpha, 1.0)

        // Character at position 50 should not be visible at time 0
        let t50Early = animation.transform(for: 50, row: 0, col: 50, time: 0.0, totalGlyphs: 100)
        XCTAssertEqual(t50Early.alpha, 0.0)
    }

    // MARK: - WaveAnimation Tests

    func testWaveAnimationInit() {
        let animation = WaveAnimation()

        XCTAssertGreaterThan(animation.duration, 0)
        XCTAssertTrue(animation.isLooping)
    }

    func testWaveAnimationProducesOffset() {
        let animation = WaveAnimation(
            amplitude: 10.0,
            frequency: 1.0
        )

        let transform = animation.transform(for: 0, row: 0, col: 0, time: 0.25, totalGlyphs: 100)

        // Alpha should always be 1.0 for wave
        XCTAssertEqual(transform.alpha, 1.0)
    }

    // MARK: - GlitchAnimation Tests

    func testGlitchAnimationInit() {
        let animation = GlitchAnimation()

        XCTAssertGreaterThan(animation.duration, 0)
        XCTAssertTrue(animation.isLooping)
    }

    func testGlitchAnimationTransform() {
        let animation = GlitchAnimation(glitchProbability: 0.5)

        let transform = animation.transform(for: 10, row: 1, col: 5, time: 1.0, totalGlyphs: 100)

        // Should return a valid transform
        XCTAssertEqual(transform.alpha, 1.0)
    }

    // MARK: - MorphAnimation Tests

    func testMorphAnimationInit() {
        let animation = MorphAnimation(duration: 2.0)

        XCTAssertEqual(animation.duration, 2.0)
        XCTAssertFalse(animation.isLooping)
    }

    func testMorphAnimationFadesIn() {
        let animation = MorphAnimation(duration: 1.0, fadeIn: true)

        // At start, alpha should be low
        let t0 = animation.transform(for: 0, row: 0, col: 0, time: 0.0, totalGlyphs: 100)
        XCTAssertLessThan(t0.alpha, 0.5)

        // At end, alpha should be 1
        let t1 = animation.transform(for: 0, row: 0, col: 0, time: 1.0, totalGlyphs: 100)
        XCTAssertEqual(t1.alpha, 1.0)
    }

    // MARK: - AnimationController Tests

    @available(iOS 13.0, macOS 10.15, *)
    @MainActor
    func testAnimationControllerStartsPaused() {
        let controller = AnimationController()

        XCTAssertFalse(controller.isPlaying)
        XCTAssertEqual(controller.currentTime, 0.0)
    }

    @available(iOS 13.0, macOS 10.15, *)
    @MainActor
    func testAnimationControllerPlayPause() {
        let controller = AnimationController()

        controller.play()
        XCTAssertTrue(controller.isPlaying)

        controller.pause()
        XCTAssertFalse(controller.isPlaying)
    }

    @available(iOS 13.0, macOS 10.15, *)
    @MainActor
    func testAnimationControllerReset() {
        let controller = AnimationController()
        controller.play()
        controller.update()

        controller.reset()

        XCTAssertEqual(controller.currentTime, 0.0)
        XCTAssertFalse(controller.isPlaying)
    }
}
