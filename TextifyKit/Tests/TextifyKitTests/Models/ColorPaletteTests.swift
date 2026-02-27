import XCTest
import simd
@testable import TextifyKit

final class ColorPaletteTests: XCTestCase {

    // MARK: - ColorPaletteType Tests

    func testColorPaletteTypeEquatable() {
        XCTAssertEqual(ColorPaletteType.original, ColorPaletteType.original)
        XCTAssertEqual(ColorPaletteType.ega16, ColorPaletteType.ega16)
        XCTAssertEqual(ColorPaletteType.vga256, ColorPaletteType.vga256)
        XCTAssertNotEqual(ColorPaletteType.original, ColorPaletteType.ega16)
    }

    // MARK: - ColorPalette Initialization Tests

    func testPaletteInitOriginal() {
        let palette = ColorPalette(type: .original)
        XCTAssertEqual(palette.type, .original)
    }

    func testPaletteInitEGA() {
        let palette = ColorPalette(type: .ega16)
        XCTAssertEqual(palette.type, .ega16)
    }

    func testPaletteInitVGA() {
        let palette = ColorPalette(type: .vga256)
        XCTAssertEqual(palette.type, .vga256)
    }

    // MARK: - Color Mapping Tests

    func testOriginalPaletteReturnsOriginalColor() {
        let palette = ColorPalette(type: .original)
        let originalColor = SIMD4<Float>(1.0, 0.5, 0.25, 1.0)
        let result = palette.color(forBrightness: 128, originalColor: originalColor)
        XCTAssertEqual(result, originalColor)
    }

    func testOriginalPaletteReturnsWhiteDefault() {
        let palette = ColorPalette(type: .original)
        let result = palette.color(forBrightness: 128)
        XCTAssertEqual(result, SIMD4<Float>(1, 1, 1, 1))
    }

    func testEGAPaletteBrightness0() {
        let palette = ColorPalette(type: .ega16)
        let result = palette.color(forBrightness: 0)
        XCTAssertTrue(result.x >= 0 && result.x <= 1)
        XCTAssertTrue(result.y >= 0 && result.y <= 1)
        XCTAssertTrue(result.z >= 0 && result.z <= 1)
        XCTAssertEqual(result.w, 1) // Alpha should be 1
    }

    func testEGAPaletteBrightness255() {
        let palette = ColorPalette(type: .ega16)
        let result = palette.color(forBrightness: 255)
        XCTAssertTrue(result.x >= 0 && result.x <= 1)
        XCTAssertTrue(result.y >= 0 && result.y <= 1)
        XCTAssertTrue(result.z >= 0 && result.z <= 1)
        XCTAssertEqual(result.w, 1)
    }

    func testVGAPaletteValidColors() {
        let palette = ColorPalette(type: .vga256)
        for brightness in stride(from: 0, to: 256, by: 16) {
            let result = palette.color(forBrightness: UInt8(brightness))
            XCTAssertTrue(result.x >= 0 && result.x <= 1)
            XCTAssertTrue(result.y >= 0 && result.y <= 1)
            XCTAssertTrue(result.z >= 0 && result.z <= 1)
            XCTAssertEqual(result.w, 1)
        }
    }

    func testMonochromePaletteGrayscale() {
        let green = SIMD4<Float>(0, 1, 0, 1)
        let palette = ColorPalette(type: .monochrome(green))
        let result = palette.color(forBrightness: 128)
        // Result should have green tint
        XCTAssertEqual(result.w, 1)
    }

    // MARK: - Preset Palettes Tests

    func testWhitePalettePreset() {
        let palette = ColorPalette.white
        let result = palette.color(forBrightness: 255)
        XCTAssertEqual(result.w, 1)
    }

    func testGreenTerminalPreset() {
        let palette = ColorPalette.greenTerminal
        let result = palette.color(forBrightness: 200)
        // Should have higher green component
        XCTAssertGreaterThanOrEqual(result.y, result.x)
        XCTAssertGreaterThanOrEqual(result.y, result.z)
    }

    // MARK: - Custom Palette Tests

    func testCustomPaletteWithColors() {
        let colors = [
            SIMD4<Float>(1, 0, 0, 1), // Red
            SIMD4<Float>(0, 1, 0, 1), // Green
            SIMD4<Float>(0, 0, 1, 1)  // Blue
        ]
        let palette = ColorPalette(type: .custom(colors))

        // Low brightness should be closer to red
        let lowResult = palette.color(forBrightness: 0)
        XCTAssertEqual(lowResult.x, 1)

        // High brightness should be closer to blue
        let highResult = palette.color(forBrightness: 255)
        XCTAssertEqual(highResult.z, 1)
    }

    // MARK: - Gradient Palette Tests

    func testGradientPalette() {
        let colors = [
            SIMD4<Float>(0, 0, 0, 1), // Black
            SIMD4<Float>(1, 1, 1, 1)  // White
        ]
        let palette = ColorPalette(type: .gradient(colors))

        // Mid brightness should be gray
        let midResult = palette.color(forBrightness: 128)
        XCTAssertEqual(midResult.w, 1)
    }
}
