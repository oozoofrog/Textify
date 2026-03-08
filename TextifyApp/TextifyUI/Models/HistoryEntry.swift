import Foundation

public struct HistoryEntry: Codable, Identifiable, Sendable, Hashable {
    public let id: UUID
    public let thumbnailData: Data          // JPEG, max 200x200
    public let textArtRows: [String]
    public let width: Int
    public let height: Int
    public let sourceCharacters: String
    public let createdAt: Date
    public let outputWidth: Int
    public let invertBrightness: Bool
    public let contrastBoost: Float

    public init(
        id: UUID = UUID(),
        thumbnailData: Data,
        textArtRows: [String],
        width: Int,
        height: Int,
        sourceCharacters: String,
        createdAt: Date = Date(),
        outputWidth: Int,
        invertBrightness: Bool,
        contrastBoost: Float
    ) {
        self.id = id
        self.thumbnailData = thumbnailData
        self.textArtRows = textArtRows
        self.width = width
        self.height = height
        self.sourceCharacters = sourceCharacters
        self.createdAt = createdAt
        self.outputWidth = outputWidth
        self.invertBrightness = invertBrightness
        self.contrastBoost = contrastBoost
    }
}
