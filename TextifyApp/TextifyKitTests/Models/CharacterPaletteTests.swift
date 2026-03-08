import Testing
@testable import TextifyKit

@Suite("CharacterPalette Tests")
struct CharacterPaletteTests {
    
    @Test("Standard palette has correct character ordering")
    func testStandardPalette() {
        let palette = CharacterPalette.standard
        
        // Standard palette: darkest to lightest
        #expect(palette.characters.first == "@")
        #expect(palette.characters.last == " ")
        #expect(palette.characters.count == 10)
    }
    
    @Test("Custom palette from string")
    func testCustomPalette() {
        let palette = CharacterPalette.custom("ABC")
        
        #expect(palette.characters == ["A", "B", "C"])
        #expect(palette.characters.count == 3)
    }
    
    @Test("Custom palette removes duplicates preserving order")
    func testDuplicateRemoval() {
        let palette = CharacterPalette.custom("AABBC")
        
        #expect(palette.characters == ["A", "B", "C"])
    }
    
    @Test("Empty string creates single space palette")
    func testEmptyString() {
        let palette = CharacterPalette.custom("")
        
        #expect(palette.characters == [" "])
    }
    
    @Test("Character for brightness 0 returns darkest")
    func testDarkestBrightness() {
        let palette = CharacterPalette.custom("@. ")
        
        #expect(palette.character(forBrightness: 0) == "@")
    }
    
    @Test("Character for brightness 255 returns lightest")
    func testLightestBrightness() {
        let palette = CharacterPalette.custom("@. ")
        
        #expect(palette.character(forBrightness: 255) == " ")
    }
    
    @Test("Character for mid brightness returns middle character")
    func testMidBrightness() {
        let palette = CharacterPalette.custom("@. ")
        
        // Mid-range should return middle character
        let char = palette.character(forBrightness: 128)
        #expect(char == ".")
    }
    
    @Test("Single character palette always returns that character")
    func testSingleCharacterPalette() {
        let palette = CharacterPalette.custom("X")
        
        #expect(palette.character(forBrightness: 0) == "X")
        #expect(palette.character(forBrightness: 128) == "X")
        #expect(palette.character(forBrightness: 255) == "X")
    }
    
    @Test("Unicode characters supported")
    func testUnicodeCharacters() {
        let palette = CharacterPalette.custom("█▓▒░ ")
        
        #expect(palette.characters.count == 5)
        #expect(palette.character(forBrightness: 0) == "█")
        #expect(palette.character(forBrightness: 255) == " ")
    }
    
    @Test("Sendable conformance")
    func testSendable() async {
        let palette = CharacterPalette.standard
        
        let task = Task {
            palette.characters.count
        }
        let result = await task.value
        #expect(result == 10)
    }
    
    @Test("Equatable conformance")
    func testEquatable() {
        let palette1 = CharacterPalette.custom("ABC")
        let palette2 = CharacterPalette.custom("ABC")
        let palette3 = CharacterPalette.custom("XYZ")
        
        #expect(palette1 == palette2)
        #expect(palette1 != palette3)
    }
}
