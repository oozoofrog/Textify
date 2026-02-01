// TextArtPro.swift
import Foundation
import simd

/// Represents a single character with color information for Metal rendering
public struct ColoredCharacter: Sendable, Equatable, Hashable {
    /// The character to display
    public let character: Character

    /// RGBA color (normalized 0-1 range)
    public let color: SIMD4<Float>

    /// Original brightness value from source image (0-255)
    public let brightness: UInt8

    public init(character: Character, color: SIMD4<Float>, brightness: UInt8 = 128) {
        self.character = character
        self.color = color
        self.brightness = brightness
    }

    /// Create with RGB values (0-255 range)
    public init(character: Character, r: UInt8, g: UInt8, b: UInt8, a: UInt8 = 255, brightness: UInt8 = 128) {
        self.character = character
        self.color = SIMD4<Float>(
            Float(r) / 255.0,
            Float(g) / 255.0,
            Float(b) / 255.0,
            Float(a) / 255.0
        )
        self.brightness = brightness
    }

    /// White color constant
    public static func white(_ character: Character, brightness: UInt8 = 128) -> ColoredCharacter {
        ColoredCharacter(character: character, color: SIMD4<Float>(1, 1, 1, 1), brightness: brightness)
    }
}

/// Extended TextArt with per-character color information for Metal MSDF rendering
public struct TextArtPro: Sendable, Equatable {
    /// 2D array of colored characters [row][column]
    public let rows: [[ColoredCharacter]]

    /// Number of characters per row
    public let width: Int

    /// Number of rows
    public let height: Int

    /// When this text art was created
    public let createdAt: Date

    /// Source image dimensions (for aspect ratio preservation)
    public let sourceWidth: Int?
    public let sourceHeight: Int?

    /// Total number of glyphs
    public var glyphCount: Int {
        width * height
    }

    /// Creates a new TextArtPro instance
    public init(
        rows: [[ColoredCharacter]],
        width: Int,
        height: Int,
        createdAt: Date = Date(),
        sourceWidth: Int? = nil,
        sourceHeight: Int? = nil
    ) {
        self.rows = rows
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.sourceWidth = sourceWidth
        self.sourceHeight = sourceHeight
    }

    /// Convert to plain string (loses color information)
    public var asString: String {
        rows.map { row in
            String(row.map { $0.character })
        }.joined(separator: "\n")
    }

    /// Get character at specific position
    public func character(at row: Int, col: Int) -> ColoredCharacter? {
        guard row >= 0, row < height, col >= 0, col < width else {
            return nil
        }
        return rows[row][col]
    }

    /// Create from existing TextArt with a color mapping function
    /// - Parameters:
    ///   - rows: Array of strings from TextArt
    ///   - width: Width of the text art
    ///   - height: Height of the text art
    ///   - createdAt: Creation date
    ///   - colorMapper: Function that maps (character, row, col, brightness) to color
    ///   - brightnessProvider: Optional function to provide brightness at each position
    public init(
        fromRows rows: [String],
        width: Int,
        height: Int,
        createdAt: Date,
        colorMapper: (Character, Int, Int, UInt8) -> SIMD4<Float>,
        brightnessProvider: ((Int, Int) -> UInt8)? = nil
    ) {
        var coloredRows: [[ColoredCharacter]] = []

        for (rowIndex, row) in rows.enumerated() {
            var coloredRow: [ColoredCharacter] = []
            for (colIndex, char) in row.enumerated() {
                let brightness = brightnessProvider?(rowIndex, colIndex) ?? 128
                let color = colorMapper(char, rowIndex, colIndex, brightness)
                coloredRow.append(ColoredCharacter(
                    character: char,
                    color: color,
                    brightness: brightness
                ))
            }
            coloredRows.append(coloredRow)
        }

        self.rows = coloredRows
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.sourceWidth = nil
        self.sourceHeight = nil
    }

    /// Create with uniform white color from string rows
    public static func fromRows(_ rows: [String], width: Int, height: Int, createdAt: Date = Date()) -> TextArtPro {
        TextArtPro(fromRows: rows, width: width, height: height, createdAt: createdAt) { _, _, _, _ in
            SIMD4<Float>(1, 1, 1, 1)
        }
    }
}

// MARK: - Convenience Extensions

public extension TextArtPro {
    /// Iterate over all glyphs with their positions
    func enumerateGlyphs(_ body: (Int, Int, ColoredCharacter) -> Void) {
        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, glyph) in row.enumerated() {
                body(rowIndex, colIndex, glyph)
            }
        }
    }

    /// Map all glyphs to a new TextArtPro
    func mapGlyphs(_ transform: (Int, Int, ColoredCharacter) -> ColoredCharacter) -> TextArtPro {
        var newRows: [[ColoredCharacter]] = []
        for (rowIndex, row) in rows.enumerated() {
            var newRow: [ColoredCharacter] = []
            for (colIndex, glyph) in row.enumerated() {
                newRow.append(transform(rowIndex, colIndex, glyph))
            }
            newRows.append(newRow)
        }
        return TextArtPro(
            rows: newRows,
            width: width,
            height: height,
            createdAt: createdAt,
            sourceWidth: sourceWidth,
            sourceHeight: sourceHeight
        )
    }
}

// MARK: - TextArt Conversion Extension

public extension TextArtPro {
    /// Create TextArtPro from TextArt with a color mapper
    init(
        from textArt: TextArt,
        colorMapper: (Character, Int, Int, UInt8) -> SIMD4<Float>,
        brightnessProvider: ((Int, Int) -> UInt8)? = nil
    ) {
        self.init(
            fromRows: textArt.rows,
            width: textArt.width,
            height: textArt.height,
            createdAt: textArt.createdAt,
            colorMapper: colorMapper,
            brightnessProvider: brightnessProvider
        )
    }

    /// Create with uniform white color from TextArt
    static func fromTextArt(_ textArt: TextArt) -> TextArtPro {
        TextArtPro(from: textArt) { _, _, _, _ in
            SIMD4<Float>(1, 1, 1, 1)
        }
    }
}
