import Foundation

/// A palette of characters used for ASCII art generation.
/// Characters are ordered from darkest (most dense) to lightest (least dense).
public struct CharacterPalette: Sendable, Equatable {
    /// Characters ordered from darkest to lightest
    public let characters: [Character]
    
    /// Standard ASCII art palette from dark to light
    public static let standard = CharacterPalette(
        characters: Array("@%#*+=-:. ")
    )
    
    /// Creates a custom palette from a string.
    /// Duplicate characters are removed, preserving first occurrence order.
    /// Empty strings result in a single space character.
    /// - Parameter text: String of characters to use, darkest first
    /// - Returns: A new CharacterPalette
    public static func custom(_ text: String) -> CharacterPalette {
        var seen = Set<Character>()
        var uniqueChars: [Character] = []
        
        for char in text {
            if !seen.contains(char) {
                seen.insert(char)
                uniqueChars.append(char)
            }
        }
        
        if uniqueChars.isEmpty {
            uniqueChars = [" "]
        }
        
        return CharacterPalette(characters: uniqueChars)
    }
    
    /// Creates a palette with the given characters.
    /// - Parameter characters: Array of characters, darkest first
    public init(characters: [Character]) {
        self.characters = characters.isEmpty ? [" "] : characters
    }
    
    /// Returns the appropriate character for a given brightness value.
    /// - Parameter brightness: Grayscale value from 0 (black) to 255 (white)
    /// - Returns: The character corresponding to this brightness level
    public func character(forBrightness brightness: UInt8) -> Character {
        guard characters.count > 1 else {
            return characters[0]
        }
        
        // Map brightness (0-255) to character index
        // brightness 0 = darkest character (index 0)
        // brightness 255 = lightest character (last index)
        let normalized = Float(brightness) / 255.0
        let index = Int(normalized * Float(characters.count - 1))
        let clampedIndex = min(max(index, 0), characters.count - 1)
        
        return characters[clampedIndex]
    }
}
