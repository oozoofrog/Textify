// ColorPalette.swift
import Foundation
import simd

/// Defines the type of color palette for text art rendering
/// Note: This is for COLOR mapping (brightness → color)
/// Distinct from PalettePreset which is for CHARACTER mapping (brightness → character)
public enum ColorPaletteType: Sendable, Equatable, Hashable, Codable {
    /// Use original image RGB colors
    case original

    /// Classic EGA 16-color palette
    case ega16

    /// VGA 256-color palette
    case vga256

    /// Monochrome (single color with varying intensity)
    case monochrome(SIMD4<Float>)

    /// Custom gradient colors
    case gradient([SIMD4<Float>])

    /// User-defined palette
    case custom([SIMD4<Float>])

    // Codable conformance for cases with associated values
    private enum CodingKeys: String, CodingKey {
        case type, color, colors
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "original": self = .original
        case "ega16": self = .ega16
        case "vga256": self = .vga256
        case "monochrome":
            let colorArray = try container.decode([Float].self, forKey: .color)
            self = .monochrome(SIMD4<Float>(colorArray[0], colorArray[1], colorArray[2], colorArray[3]))
        case "gradient":
            let colorsArray = try container.decode([[Float]].self, forKey: .colors)
            self = .gradient(colorsArray.map { SIMD4<Float>($0[0], $0[1], $0[2], $0[3]) })
        case "custom":
            let colorsArray = try container.decode([[Float]].self, forKey: .colors)
            self = .custom(colorsArray.map { SIMD4<Float>($0[0], $0[1], $0[2], $0[3]) })
        default:
            self = .original
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .original:
            try container.encode("original", forKey: .type)
        case .ega16:
            try container.encode("ega16", forKey: .type)
        case .vga256:
            try container.encode("vga256", forKey: .type)
        case .monochrome(let color):
            try container.encode("monochrome", forKey: .type)
            try container.encode([color.x, color.y, color.z, color.w], forKey: .color)
        case .gradient(let colors):
            try container.encode("gradient", forKey: .type)
            try container.encode(colors.map { [$0.x, $0.y, $0.z, $0.w] }, forKey: .colors)
        case .custom(let colors):
            try container.encode("custom", forKey: .type)
            try container.encode(colors.map { [$0.x, $0.y, $0.z, $0.w] }, forKey: .colors)
        }
    }
}

/// Color palette that maps brightness values to colors
public struct ColorPalette: Sendable {
    public let type: ColorPaletteType

    public init(type: ColorPaletteType) {
        self.type = type
    }

    /// Get color for a given brightness value
    /// - Parameters:
    ///   - brightness: Brightness value 0-255
    ///   - originalColor: Original color from source image (used for .original type)
    /// - Returns: RGBA color as SIMD4<Float>
    public func color(forBrightness brightness: UInt8, originalColor: SIMD4<Float>? = nil) -> SIMD4<Float> {
        switch type {
        case .original:
            return originalColor ?? SIMD4<Float>(1, 1, 1, 1)

        case .ega16:
            let index = Int(brightness) * 16 / 256
            return Self.egaColors[min(index, 15)]

        case .vga256:
            return Self.vgaColors[Int(brightness)]

        case .monochrome(let baseColor):
            let intensity = Float(brightness) / 255.0
            return SIMD4<Float>(
                baseColor.x * intensity,
                baseColor.y * intensity,
                baseColor.z * intensity,
                baseColor.w
            )

        case .gradient(let colors):
            guard colors.count >= 2 else {
                return colors.first ?? SIMD4<Float>(1, 1, 1, 1)
            }
            let t = Float(brightness) / 255.0
            let segment = t * Float(colors.count - 1)
            let index = Int(segment)
            let fraction = segment - Float(index)

            let startIndex = min(index, colors.count - 1)
            let endIndex = min(index + 1, colors.count - 1)

            return mix(colors[startIndex], colors[endIndex], t: fraction)

        case .custom(let colors):
            guard !colors.isEmpty else {
                return SIMD4<Float>(1, 1, 1, 1)
            }
            let index = Int(Float(brightness) / 255.0 * Float(colors.count - 1))
            return colors[min(index, colors.count - 1)]
        }
    }

    /// Linear interpolation between two colors
    private func mix(_ a: SIMD4<Float>, _ b: SIMD4<Float>, t: Float) -> SIMD4<Float> {
        return a * (1 - t) + b * t
    }

    // MARK: - EGA 16-Color Palette

    /// Classic EGA 16-color palette
    public static let egaColors: [SIMD4<Float>] = [
        SIMD4<Float>(0.000, 0.000, 0.000, 1),  // 0: Black
        SIMD4<Float>(0.000, 0.000, 0.667, 1),  // 1: Blue
        SIMD4<Float>(0.000, 0.667, 0.000, 1),  // 2: Green
        SIMD4<Float>(0.000, 0.667, 0.667, 1),  // 3: Cyan
        SIMD4<Float>(0.667, 0.000, 0.000, 1),  // 4: Red
        SIMD4<Float>(0.667, 0.000, 0.667, 1),  // 5: Magenta
        SIMD4<Float>(0.667, 0.333, 0.000, 1),  // 6: Brown
        SIMD4<Float>(0.667, 0.667, 0.667, 1),  // 7: Light Gray
        SIMD4<Float>(0.333, 0.333, 0.333, 1),  // 8: Dark Gray
        SIMD4<Float>(0.333, 0.333, 1.000, 1),  // 9: Light Blue
        SIMD4<Float>(0.333, 1.000, 0.333, 1),  // 10: Light Green
        SIMD4<Float>(0.333, 1.000, 1.000, 1),  // 11: Light Cyan
        SIMD4<Float>(1.000, 0.333, 0.333, 1),  // 12: Light Red
        SIMD4<Float>(1.000, 0.333, 1.000, 1),  // 13: Light Magenta
        SIMD4<Float>(1.000, 1.000, 0.333, 1),  // 14: Yellow
        SIMD4<Float>(1.000, 1.000, 1.000, 1),  // 15: White
    ]

    // MARK: - VGA 256-Color Palette

    /// VGA 256-color palette (6-7-6 RGB levels approximation)
    public static let vgaColors: [SIMD4<Float>] = {
        var colors: [SIMD4<Float>] = []
        colors.reserveCapacity(256)

        for i in 0..<256 {
            // Standard VGA palette approximation
            // Uses 6 levels for R and B, 7 levels for G
            let r = Float((i >> 5) & 0x7) / 7.0
            let g = Float((i >> 2) & 0x7) / 7.0
            let b = Float(i & 0x3) / 3.0
            colors.append(SIMD4<Float>(r, g, b, 1))
        }

        return colors
    }()
}

// MARK: - Preset Palettes

public extension ColorPalette {
    /// Default white text
    static let white = ColorPalette(type: .monochrome(SIMD4<Float>(1, 1, 1, 1)))

    /// Classic green terminal
    static let greenTerminal = ColorPalette(type: .monochrome(SIMD4<Float>(0.2, 1.0, 0.3, 1)))

    /// Amber terminal
    static let amberTerminal = ColorPalette(type: .monochrome(SIMD4<Float>(1.0, 0.75, 0.0, 1)))

    /// Classic EGA
    static let ega = ColorPalette(type: .ega16)

    /// VGA 256 colors
    static let vga = ColorPalette(type: .vga256)

    /// Original image colors
    static let original = ColorPalette(type: .original)

    /// Rainbow gradient
    static let rainbow = ColorPalette(type: .gradient([
        SIMD4<Float>(1.0, 0.0, 0.0, 1),  // Red
        SIMD4<Float>(1.0, 0.5, 0.0, 1),  // Orange
        SIMD4<Float>(1.0, 1.0, 0.0, 1),  // Yellow
        SIMD4<Float>(0.0, 1.0, 0.0, 1),  // Green
        SIMD4<Float>(0.0, 0.0, 1.0, 1),  // Blue
        SIMD4<Float>(0.5, 0.0, 1.0, 1),  // Indigo
        SIMD4<Float>(1.0, 0.0, 1.0, 1),  // Violet
    ]))

    /// Synthwave/Cyberpunk gradient
    static let synthwave = ColorPalette(type: .gradient([
        SIMD4<Float>(0.0, 0.0, 0.2, 1),   // Dark blue
        SIMD4<Float>(0.5, 0.0, 0.5, 1),   // Purple
        SIMD4<Float>(1.0, 0.0, 0.5, 1),   // Magenta
        SIMD4<Float>(1.0, 0.4, 0.8, 1),   // Pink
        SIMD4<Float>(0.0, 1.0, 1.0, 1),   // Cyan
    ]))

    /// Matrix green
    static let matrix = ColorPalette(type: .gradient([
        SIMD4<Float>(0.0, 0.1, 0.0, 1),   // Dark green
        SIMD4<Float>(0.0, 0.5, 0.0, 1),   // Medium green
        SIMD4<Float>(0.0, 1.0, 0.0, 1),   // Bright green
        SIMD4<Float>(0.7, 1.0, 0.7, 1),   // Light green
    ]))
}
