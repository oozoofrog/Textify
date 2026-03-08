import Foundation

/// Configuration options for text art generation.
public struct ProcessingOptions: Sendable, Equatable {
    /// Number of characters wide the output should be.
    /// Clamped to range 10...500. Default is 80.
    public let outputWidth: Int

    /// Aspect ratio correction factor for monospace characters.
    /// Typically 0.5 because characters are taller than wide.
    /// Clamped to range 0.1...1.0. Default is 0.5.
    public let aspectRatioCorrection: Float

    /// Whether to invert brightness mapping.
    /// When true, dark areas become light characters and vice versa.
    public let invertBrightness: Bool

    /// Contrast enhancement factor.
    /// 1.0 = no change, <1.0 = less contrast, >1.0 = more contrast.
    /// Clamped to range 0.0...2.0. Default is 1.0.
    public let contrastBoost: Float

    /// Creates processing options with the specified parameters.
    /// Values are automatically clamped to valid ranges.
    /// - Parameters:
    ///   - outputWidth: Characters wide (10-500, default 80)
    ///   - aspectRatioCorrection: Height adjustment factor (0.1-1.0, default 0.5)
    ///   - invertBrightness: Invert dark/light mapping (default false)
    ///   - contrastBoost: Contrast factor (0.0-2.0, default 1.0)
    public init(
        outputWidth: Int = 80,
        aspectRatioCorrection: Float = 0.5,
        invertBrightness: Bool = false,
        contrastBoost: Float = 1.0
    ) {
        self.outputWidth = Self.clampWidth(outputWidth)
        self.aspectRatioCorrection = Self.clampAspectRatio(aspectRatioCorrection)
        self.invertBrightness = invertBrightness
        self.contrastBoost = Self.clampContrast(contrastBoost)
    }

    // MARK: - Private Helpers

    private static func clampWidth(_ width: Int) -> Int {
        min(max(width, 10), 500)
    }

    private static func clampAspectRatio(_ ratio: Float) -> Float {
        min(max(ratio, 0.1), 1.0)
    }

    private static func clampContrast(_ contrast: Float) -> Float {
        min(max(contrast, 0.0), 2.0)
    }
}
