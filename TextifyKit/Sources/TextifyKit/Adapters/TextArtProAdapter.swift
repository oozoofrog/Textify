// TextArtProAdapter.swift
import Foundation
import simd
import CoreGraphics

/// Adapter that converts TextArt to TextArtPro with color and pattern support
public struct TextArtProAdapter: Sendable {

    /// Convert TextArt to TextArtPro with specified color palette
    /// - Parameters:
    ///   - textArt: Source text art
    ///   - palette: Color palette to apply
    ///   - brightnessData: Optional 2D array of brightness values from original image
    /// - Returns: TextArtPro with colors applied
    public static func convert(
        _ textArt: TextArt,
        palette: ColorPalette,
        brightnessData: [[UInt8]]? = nil
    ) -> TextArtPro {
        TextArtPro(from: textArt) { char, row, col, _ in
            let brightness = brightnessData?[safe: row]?[safe: col] ?? estimateBrightness(for: char)
            return palette.color(forBrightness: brightness)
        } brightnessProvider: { row, col in
            brightnessData?[safe: row]?[safe: col] ?? 128
        }
    }

    /// Convert TextArt to TextArtPro with a message pattern overlay
    /// - Parameters:
    ///   - textArt: Source text art
    ///   - pattern: Message pattern to apply
    ///   - palette: Color palette for base coloring
    ///   - brightnessData: Optional brightness data
    /// - Returns: TextArtPro with pattern applied
    public static func convert(
        _ textArt: TextArt,
        pattern: any MessagePattern,
        palette: ColorPalette = .white,
        brightnessData: [[UInt8]]? = nil
    ) -> TextArtPro {
        var coloredRows: [[ColoredCharacter]] = []

        for (rowIndex, row) in textArt.rows.enumerated() {
            var coloredRow: [ColoredCharacter] = []

            for (colIndex, originalChar) in row.enumerated() {
                let brightness = brightnessData?[safe: rowIndex]?[safe: colIndex] ?? estimateBrightness(for: originalChar)

                // Check if pattern provides a character
                let character: Character
                if let patternChar = pattern.character(at: rowIndex, col: colIndex, brightness: brightness) {
                    character = patternChar
                } else {
                    character = originalChar
                }

                // Get base color from palette
                let baseColor = palette.color(forBrightness: brightness)

                // Check if pattern provides a color override
                let color: SIMD4<Float>
                if let patternColor = pattern.color(at: rowIndex, col: colIndex, originalColor: baseColor) {
                    color = patternColor
                } else {
                    color = baseColor
                }

                coloredRow.append(ColoredCharacter(
                    character: character,
                    color: color,
                    brightness: brightness
                ))
            }

            coloredRows.append(coloredRow)
        }

        return TextArtPro(
            rows: coloredRows,
            width: textArt.width,
            height: textArt.height,
            createdAt: textArt.createdAt
        )
    }

    /// Convert TextArt with original image colors
    /// - Parameters:
    ///   - textArt: Source text art
    ///   - imageColors: 2D array of RGBA colors from original image
    /// - Returns: TextArtPro with original colors
    public static func convertWithOriginalColors(
        _ textArt: TextArt,
        imageColors: [[SIMD4<Float>]]
    ) -> TextArtPro {
        var coloredRows: [[ColoredCharacter]] = []

        for (rowIndex, row) in textArt.rows.enumerated() {
            var coloredRow: [ColoredCharacter] = []

            for (colIndex, char) in row.enumerated() {
                let color = imageColors[safe: rowIndex]?[safe: colIndex] ?? SIMD4<Float>(1, 1, 1, 1)
                let brightness = colorToBrightness(color)

                coloredRow.append(ColoredCharacter(
                    character: char,
                    color: color,
                    brightness: brightness
                ))
            }

            coloredRows.append(coloredRow)
        }

        return TextArtPro(
            rows: coloredRows,
            width: textArt.width,
            height: textArt.height,
            createdAt: textArt.createdAt
        )
    }

    /// Extract brightness data from a CGImage
    /// - Parameters:
    ///   - image: Source image
    ///   - width: Target width (number of columns)
    ///   - height: Target height (number of rows)
    /// - Returns: 2D array of brightness values
    public static func extractBrightness(
        from image: CGImage,
        width: Int,
        height: Int
    ) -> [[UInt8]] {
        let scaleX = CGFloat(image.width) / CGFloat(width)
        let scaleY = CGFloat(image.height) / CGFloat(height)

        // Create grayscale context
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return Array(repeating: Array(repeating: 128, count: width), count: height)
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return Array(repeating: Array(repeating: 128, count: width), count: height)
        }

        let pointer = data.bindMemory(to: UInt8.self, capacity: width * height)

        var result: [[UInt8]] = []
        for row in 0..<height {
            var rowData: [UInt8] = []
            for col in 0..<width {
                rowData.append(pointer[row * width + col])
            }
            result.append(rowData)
        }

        return result
    }

    /// Extract RGBA colors from a CGImage
    public static func extractColors(
        from image: CGImage,
        width: Int,
        height: Int
    ) -> [[SIMD4<Float>]] {
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return Array(repeating: Array(repeating: SIMD4<Float>(1, 1, 1, 1), count: width), count: height)
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else {
            return Array(repeating: Array(repeating: SIMD4<Float>(1, 1, 1, 1), count: width), count: height)
        }

        let pointer = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var result: [[SIMD4<Float>]] = []
        for row in 0..<height {
            var rowData: [SIMD4<Float>] = []
            for col in 0..<width {
                let offset = (row * width + col) * 4
                let r = Float(pointer[offset]) / 255.0
                let g = Float(pointer[offset + 1]) / 255.0
                let b = Float(pointer[offset + 2]) / 255.0
                let a = Float(pointer[offset + 3]) / 255.0
                rowData.append(SIMD4<Float>(r, g, b, a))
            }
            result.append(rowData)
        }

        return result
    }

    // MARK: - Private Helpers

    /// Estimate brightness based on character density
    private static func estimateBrightness(for char: Character) -> UInt8 {
        // Common ASCII art characters ordered by density (dark to light)
        let densityMap: [Character: UInt8] = [
            "@": 20, "#": 40, "%": 50, "&": 55, "8": 60,
            "B": 65, "M": 70, "W": 75, "*": 80, "o": 90,
            "a": 100, "h": 105, "k": 110, "b": 115, "d": 120,
            "p": 125, "q": 130, "w": 135, "m": 140, "Z": 145,
            "O": 150, "0": 155, "Q": 160, "L": 165, "C": 170,
            "J": 175, "U": 180, "Y": 185, "X": 190, "z": 195,
            "c": 200, "v": 205, "u": 210, "n": 215, "x": 220,
            "r": 225, "j": 230, "f": 235, "t": 240, "/": 242,
            "\\": 242, "|": 244, "(": 244, ")": 244, "1": 246,
            "{": 246, "}": 246, "[": 246, "]": 246, "?": 248,
            "-": 248, "_": 248, "+": 248, "~": 250, "<": 250,
            ">": 250, "i": 250, "!": 252, "l": 252, "I": 252,
            ";": 252, ":": 254, ",": 254, "\"": 254, "^": 254,
            "`": 254, "'": 254, ".": 254, " ": 255
        ]

        return densityMap[char] ?? 128
    }

    /// Convert color to brightness (luminance)
    private static func colorToBrightness(_ color: SIMD4<Float>) -> UInt8 {
        // ITU-R BT.709 luminance formula
        let luminance = 0.2126 * color.x + 0.7152 * color.y + 0.0722 * color.z
        return UInt8(min(255, max(0, luminance * 255)))
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
