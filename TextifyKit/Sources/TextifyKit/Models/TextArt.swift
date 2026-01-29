import Foundation

/// Represents generated ASCII/text art from an image.
/// Contains the text rows and metadata about the generation.
public struct TextArt: Sendable, Equatable {
    /// The rows of text art, each string representing one line
    public let rows: [String]
    
    /// Number of characters per row
    public let width: Int
    
    /// Number of rows
    public let height: Int
    
    /// The characters that were used to generate this art
    public let sourceCharacters: String
    
    /// When this text art was created
    public let createdAt: Date
    
    /// Creates a new TextArt instance.
    /// - Parameters:
    ///   - rows: Array of strings, each representing one line of text art
    ///   - width: Number of characters per row
    ///   - height: Number of rows
    ///   - sourceCharacters: The character palette used for generation
    ///   - createdAt: Creation timestamp
    public init(
        rows: [String],
        width: Int,
        height: Int,
        sourceCharacters: String,
        createdAt: Date
    ) {
        self.rows = rows
        self.width = width
        self.height = height
        self.sourceCharacters = sourceCharacters
        self.createdAt = createdAt
    }
    
    /// The complete text art as a single string with newline separators.
    public var asString: String {
        rows.joined(separator: "\n")
    }
}
