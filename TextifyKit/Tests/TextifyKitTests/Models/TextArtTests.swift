import Testing
import Foundation
@testable import TextifyKit

@Suite("TextArt Tests")
struct TextArtTests {
    
    @Test("Initialization stores all properties")
    func testInitialization() {
        let rows = ["@@@", "...", "@@@"]
        let date = Date()
        let textArt = TextArt(
            rows: rows,
            width: 3,
            height: 3,
            sourceCharacters: "@.",
            createdAt: date
        )
        
        #expect(textArt.rows == rows)
        #expect(textArt.width == 3)
        #expect(textArt.height == 3)
        #expect(textArt.sourceCharacters == "@.")
        #expect(textArt.createdAt == date)
    }
    
    @Test("asString joins rows with newlines")
    func testAsString() {
        let textArt = TextArt(
            rows: ["ABC", "DEF", "GHI"],
            width: 3,
            height: 3,
            sourceCharacters: "ABCDEFGHI",
            createdAt: Date()
        )
        
        #expect(textArt.asString == "ABC\nDEF\nGHI")
    }
    
    @Test("Empty rows produce empty string")
    func testEmptyRows() {
        let textArt = TextArt(
            rows: [],
            width: 0,
            height: 0,
            sourceCharacters: "",
            createdAt: Date()
        )
        
        #expect(textArt.asString == "")
        #expect(textArt.rows.isEmpty)
    }
    
    @Test("Single row has no newlines")
    func testSingleRow() {
        let textArt = TextArt(
            rows: ["Hello World"],
            width: 11,
            height: 1,
            sourceCharacters: "Helo Wrd",
            createdAt: Date()
        )
        
        #expect(textArt.asString == "Hello World")
    }
    
    @Test("Equatable compares all fields")
    func testEquatable() {
        let date = Date()
        let art1 = TextArt(rows: ["@"], width: 1, height: 1, sourceCharacters: "@", createdAt: date)
        let art2 = TextArt(rows: ["@"], width: 1, height: 1, sourceCharacters: "@", createdAt: date)
        let art3 = TextArt(rows: ["."], width: 1, height: 1, sourceCharacters: ".", createdAt: date)
        
        #expect(art1 == art2)
        #expect(art1 != art3)
    }
    
    @Test("Sendable conformance allows cross-task usage")
    func testSendable() async {
        let textArt = TextArt(
            rows: ["Test"],
            width: 4,
            height: 1,
            sourceCharacters: "Test",
            createdAt: Date()
        )
        
        let task = Task {
            textArt.asString
        }
        let result = await task.value
        #expect(result == "Test")
    }
}
