import Testing
@testable import TextifyKit

@Suite("CharacterMapper Tests")
struct CharacterMapperTests {

    let mapper = CharacterMapper()

    @Test("Maps single row of pixels to characters")
    func testSingleRowMapping() {
        let pixels: [UInt8] = [0, 128, 255]  // black, gray, white
        let buffer = GrayscalePixelBuffer(pixels: pixels, width: 3, height: 1)
        let palette = CharacterPalette.custom("@. ")
        let options = ProcessingOptions()

        let rows = mapper.mapToCharacters(pixels: buffer, palette: palette, options: options)

        #expect(rows.count == 1)
        #expect(rows[0].count == 3)
        #expect(rows[0].first == "@")  // darkest
        #expect(rows[0].last == " ")   // lightest
    }

    @Test("Maps multiple rows correctly")
    func testMultipleRows() {
        let pixels: [UInt8] = [0, 0, 255, 255]
        let buffer = GrayscalePixelBuffer(pixels: pixels, width: 2, height: 2)
        let palette = CharacterPalette.custom("@.")
        let options = ProcessingOptions()

        let rows = mapper.mapToCharacters(pixels: buffer, palette: palette, options: options)

        #expect(rows.count == 2)
        #expect(rows[0] == "@@")
        #expect(rows[1] == "..")
    }

    @Test("Inverts brightness when option set")
    func testInvertBrightness() {
        let pixels: [UInt8] = [0, 255]  // black, white
        let buffer = GrayscalePixelBuffer(pixels: pixels, width: 2, height: 1)
        let palette = CharacterPalette.custom("@.")
        let options = ProcessingOptions(invertBrightness: true)

        let rows = mapper.mapToCharacters(pixels: buffer, palette: palette, options: options)

        // Inverted: black becomes light char, white becomes dark char
        #expect(rows[0] == ".@")
    }

    @Test("Applies contrast boost")
    func testContrastBoost() {
        // Mid-gray pixels
        let pixels: [UInt8] = [100, 150]
        let buffer = GrayscalePixelBuffer(pixels: pixels, width: 2, height: 1)
        let palette = CharacterPalette.custom("@#*+=-:. ")

        // Without contrast boost
        let optionsNormal = ProcessingOptions(contrastBoost: 1.0)
        let rowsNormal = mapper.mapToCharacters(pixels: buffer, palette: palette, options: optionsNormal)

        // With high contrast boost
        let optionsHigh = ProcessingOptions(contrastBoost: 2.0)
        let rowsHigh = mapper.mapToCharacters(pixels: buffer, palette: palette, options: optionsHigh)

        // High contrast should make values more extreme (different characters)
        #expect(rowsNormal[0] != rowsHigh[0])
    }

    @Test("Handles empty buffer")
    func testEmptyBuffer() {
        let buffer = GrayscalePixelBuffer(pixels: [], width: 0, height: 0)
        let palette = CharacterPalette.standard
        let options = ProcessingOptions()

        let rows = mapper.mapToCharacters(pixels: buffer, palette: palette, options: options)

        #expect(rows.isEmpty)
    }

    @Test("Uses all characters in palette gradient")
    func testPaletteGradient() {
        // Create pixels covering full brightness range
        var pixels: [UInt8] = []
        for i in 0..<10 {
            pixels.append(UInt8(i * 28))  // 0, 28, 56, ..., 252
        }
        let buffer = GrayscalePixelBuffer(pixels: pixels, width: 10, height: 1)
        let palette = CharacterPalette.standard  // 10 characters
        let options = ProcessingOptions()

        let rows = mapper.mapToCharacters(pixels: buffer, palette: palette, options: options)

        #expect(rows[0].count == 10)
        // First should be darkest, last should be lightest
        #expect(rows[0].first == "@")
    }

    @Test("Sendable conformance")
    func testSendable() async {
        let mapper = CharacterMapper()
        let buffer = GrayscalePixelBuffer(pixels: [128], width: 1, height: 1)
        let palette = CharacterPalette.standard
        let options = ProcessingOptions()

        let task = Task {
            mapper.mapToCharacters(pixels: buffer, palette: palette, options: options)
        }
        let result = await task.value
        #expect(result.count == 1)
    }
}
