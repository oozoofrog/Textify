import Foundation

/// Maps grayscale pixel values to characters for ASCII art generation.
/// Thread-safe struct that can be used across concurrent contexts.
public struct CharacterMapper: Sendable {

    public init() {}

    /// Maps a buffer of grayscale pixels to rows of characters.
    /// - Parameters:
    ///   - pixels: The grayscale pixel buffer to map
    ///   - palette: Character palette to use for mapping
    ///   - options: Processing options including invert and contrast settings
    /// - Returns: Array of strings, each representing one row of text art
    public func mapToCharacters(
        pixels: GrayscalePixelBuffer,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) -> [String] {
        guard pixels.width > 0, pixels.height > 0 else {
            return []
        }

        var rows: [String] = []
        rows.reserveCapacity(pixels.height)

        for y in 0..<pixels.height {
            var row = ""
            row.reserveCapacity(pixels.width)

            for x in 0..<pixels.width {
                guard let pixelValue = pixels.pixel(at: x, y: y) else {
                    continue
                }

                let adjustedValue = adjustBrightness(
                    pixelValue,
                    invert: options.invertBrightness,
                    contrast: options.contrastBoost
                )

                let character = palette.character(forBrightness: adjustedValue)
                row.append(character)
            }

            rows.append(row)
        }

        return rows
    }

    // MARK: - Private Helpers

    /// Adjusts brightness value based on options.
    private func adjustBrightness(
        _ value: UInt8,
        invert: Bool,
        contrast: Float
    ) -> UInt8 {
        var adjusted = Float(value)

        // Apply contrast (around midpoint 127.5)
        if contrast != 1.0 {
            let midpoint: Float = 127.5
            adjusted = midpoint + (adjusted - midpoint) * contrast
        }

        // Clamp to valid range
        adjusted = max(0, min(255, adjusted))

        // Apply inversion
        if invert {
            adjusted = 255 - adjusted
        }

        return UInt8(adjusted)
    }
}
