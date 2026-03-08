import Foundation
import CoreGraphics

/// Errors that can occur during text art generation.
public enum TextArtGenerationError: Error, Sendable {
    /// The character palette is empty or invalid
    case invalidPalette
    /// The source image could not be processed
    case imageProcessingFailed(ImageProcessingError)
    /// Generation was cancelled
    case cancelled
    /// An unexpected error occurred
    case generationFailed(String)
}

/// Protocol defining text art generation operations.
/// Implementations must be Sendable for use with Swift Concurrency.
public protocol TextArtGenerating: Sendable {
    /// Generates text art from an image using the specified character palette.
    /// - Parameters:
    ///   - image: The source image to convert
    ///   - palette: Characters to use for the art, ordered dark to light
    ///   - options: Processing options controlling output size and adjustments
    /// - Returns: The generated text art
    /// - Throws: TextArtGenerationError if generation fails
    func generate(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt
}
