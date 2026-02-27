import XCTest
import simd
@testable import TextifyKit

final class TextArtProTests: XCTestCase {

    // MARK: - ColoredCharacter Tests

    func testColoredCharacterInit() {
        let color = SIMD4<Float>(1, 0, 0, 1)
        let char = ColoredCharacter(character: "A", color: color, brightness: 200)

        XCTAssertEqual(char.character, "A")
        XCTAssertEqual(char.color, color)
        XCTAssertEqual(char.brightness, 200)
    }

    func testColoredCharacterEquatable() {
        let color = SIMD4<Float>(1, 0, 0, 1)
        let char1 = ColoredCharacter(character: "A", color: color, brightness: 200)
        let char2 = ColoredCharacter(character: "A", color: color, brightness: 200)
        let char3 = ColoredCharacter(character: "B", color: color, brightness: 200)

        XCTAssertEqual(char1, char2)
        XCTAssertNotEqual(char1, char3)
    }

    // MARK: - TextArtPro Initialization Tests

    func testTextArtProInit() {
        let color = SIMD4<Float>(1, 1, 1, 1)
        let row = [
            ColoredCharacter(character: "A", color: color, brightness: 200),
            ColoredCharacter(character: "B", color: color, brightness: 150)
        ]
        let textArtPro = TextArtPro(rows: [row], width: 2, height: 1)

        XCTAssertEqual(textArtPro.width, 2)
        XCTAssertEqual(textArtPro.height, 1)
        XCTAssertEqual(textArtPro.rows.count, 1)
        XCTAssertEqual(textArtPro.rows[0].count, 2)
    }

    func testTextArtProFromTextArt() {
        let textArt = TextArt(
            rows: ["AB", "CD"],
            width: 2,
            height: 2,
            sourceCharacters: "ABCD",
            createdAt: Date()
        )

        let textArtPro = TextArtPro(from: textArt) { char, row, col, _ in
            SIMD4<Float>(Float(row), Float(col), 0, 1)
        } brightnessProvider: { row, col in
            UInt8((row + col) * 50)
        }

        XCTAssertEqual(textArtPro.width, 2)
        XCTAssertEqual(textArtPro.height, 2)
        XCTAssertEqual(textArtPro.rows[0][0].character, "A")
        XCTAssertEqual(textArtPro.rows[1][1].character, "D")
    }

    // MARK: - Dimensions Tests

    func testTextArtProDimensions() {
        let color = SIMD4<Float>(1, 1, 1, 1)
        let row1 = [
            ColoredCharacter(character: "A", color: color, brightness: 200),
            ColoredCharacter(character: "B", color: color, brightness: 200),
            ColoredCharacter(character: "C", color: color, brightness: 200)
        ]
        let row2 = [
            ColoredCharacter(character: "D", color: color, brightness: 200),
            ColoredCharacter(character: "E", color: color, brightness: 200),
            ColoredCharacter(character: "F", color: color, brightness: 200)
        ]

        let textArtPro = TextArtPro(rows: [row1, row2], width: 3, height: 2)

        XCTAssertEqual(textArtPro.width, 3)
        XCTAssertEqual(textArtPro.height, 2)
        // Total glyphs = rows * cols = 2 * 3 = 6
        XCTAssertEqual(textArtPro.rows.flatMap { $0 }.count, 6)
    }

    // MARK: - Empty TextArtPro Tests

    func testTextArtProEmptyRows() {
        let textArtPro = TextArtPro(rows: [], width: 0, height: 0)

        XCTAssertEqual(textArtPro.width, 0)
        XCTAssertEqual(textArtPro.height, 0)
        XCTAssertTrue(textArtPro.rows.isEmpty)
    }

    // MARK: - Sendable Conformance

    func testTextArtProSendable() async {
        let color = SIMD4<Float>(1, 1, 1, 1)
        let row = [ColoredCharacter(character: "A", color: color, brightness: 200)]
        let textArtPro = TextArtPro(rows: [row], width: 1, height: 1)

        let result = await Task {
            textArtPro.width
        }.value

        XCTAssertEqual(result, 1)
    }
}
