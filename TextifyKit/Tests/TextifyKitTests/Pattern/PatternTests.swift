import XCTest
import simd
@testable import TextifyKit

final class PatternTests: XCTestCase {

    // MARK: - RepeatPattern Tests

    func testRepeatPatternHorizontal() {
        let pattern = RepeatPattern(message: "ABC", repeatMode: .horizontal)

        // Pattern should return message characters cyclically
        let char0 = pattern.character(at: 0, col: 0, brightness: 100)
        let char1 = pattern.character(at: 0, col: 1, brightness: 100)
        let char2 = pattern.character(at: 0, col: 2, brightness: 100)
        let char3 = pattern.character(at: 0, col: 3, brightness: 100)

        XCTAssertEqual(char0, "A")
        XCTAssertEqual(char1, "B")
        XCTAssertEqual(char2, "C")
        XCTAssertEqual(char3, "A") // Wraps around
    }

    func testRepeatPatternVertical() {
        let pattern = RepeatPattern(message: "XY", repeatMode: .vertical)

        let char0 = pattern.character(at: 0, col: 0, brightness: 100)
        let char1 = pattern.character(at: 1, col: 0, brightness: 100)
        let char2 = pattern.character(at: 2, col: 0, brightness: 100)

        XCTAssertEqual(char0, "X")
        XCTAssertEqual(char1, "Y")
        XCTAssertEqual(char2, "X") // Wraps around
    }

    func testRepeatPatternMessage() {
        let pattern = RepeatPattern(message: "HELLO")
        XCTAssertEqual(pattern.message, "HELLO")
    }

    // MARK: - GradientPattern Tests

    func testGradientPatternHorizontal() {
        let pattern = GradientPattern(
            message: "HELLO",
            colors: [
                SIMD4<Float>(1, 0, 0, 1),
                SIMD4<Float>(0, 0, 1, 1)
            ],
            direction: .horizontal
        )

        XCTAssertEqual(pattern.message, "HELLO")
    }

    func testGradientPatternLovePreset() {
        let pattern = GradientPattern.love("LOVE")
        XCTAssertEqual(pattern.message, "LOVE")
    }

    func testGradientPatternOceanPreset() {
        let pattern = GradientPattern.ocean("OCEAN")
        XCTAssertEqual(pattern.message, "OCEAN")
    }

    func testGradientPatternSunsetPreset() {
        let pattern = GradientPattern.sunset("SUNSET")
        XCTAssertEqual(pattern.message, "SUNSET")
    }

    // MARK: - MaskPattern Tests

    func testMaskPatternInit() {
        let pattern = MaskPattern(message: "MASK")
        XCTAssertEqual(pattern.message, "MASK")
    }

    // MARK: - PatternFactory Tests

    func testPatternFactoryILoveYou() {
        let pattern = PatternFactory.iLoveYou(name: "Alice")
        XCTAssertTrue(pattern.message.contains("Alice"))
    }

    func testPatternFactoryName() {
        let pattern = PatternFactory.name("Test")
        XCTAssertTrue(pattern.message.contains("Test"))
    }

    func testPatternFactoryRainbow() {
        let pattern = PatternFactory.rainbow("RAINBOW")
        XCTAssertTrue(pattern.message.contains("RAINBOW"))
    }

    func testPatternFactoryMatrix() {
        let pattern = PatternFactory.matrix()
        XCTAssertTrue(pattern.message.contains("0") || pattern.message.contains("1"))
    }

    // MARK: - PatternConfiguration Tests

    func testPatternConfigurationInit() {
        let config = PatternConfiguration(
            message: "TEST",
            repeatMode: .diagonal,
            colorMode: .rainbow
        )

        XCTAssertEqual(config.message, "TEST")
        XCTAssertEqual(config.repeatMode, .diagonal)
    }

    func testPatternConfigurationRepeatModes() {
        let horizontal = PatternConfiguration.RepeatMode.horizontal
        let vertical = PatternConfiguration.RepeatMode.vertical
        let diagonal = PatternConfiguration.RepeatMode.diagonal
        let tile = PatternConfiguration.RepeatMode.tile

        XCTAssertNotEqual(horizontal, vertical)
        XCTAssertNotEqual(diagonal, tile)
    }
}
