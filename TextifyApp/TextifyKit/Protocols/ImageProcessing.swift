import Foundation
import CoreGraphics

/// Errors that can occur during image processing.
public enum ImageProcessingError: Error, Sendable {
    /// The provided image data is invalid or cannot be processed
    case invalidImage
    /// The image dimensions exceed maximum allowed size
    case imageTooLarge(width: Int, height: Int, maxDimension: Int)
    /// Failed to create graphics context for processing
    case contextCreationFailed
    /// An unexpected error occurred during processing
    case processingFailed(String)
}

/// Protocol defining image processing operations for text art generation.
/// Implementations must be Sendable for use with Swift Concurrency.
public protocol ImageProcessing: Sendable {
    /// Converts a CGImage to grayscale pixels scaled to the specified width.
    /// - Parameters:
    ///   - image: The source image to process
    ///   - width: Target width in pixels for the output
    ///   - aspectCorrection: Factor to adjust height (typically 0.5 for monospace characters)
    /// - Returns: A buffer containing grayscale pixel values
    /// - Throws: ImageProcessingError if processing fails
    func grayscalePixels(
        from image: CGImage,
        scaledToWidth width: Int,
        aspectCorrection: Float
    ) async throws -> GrayscalePixelBuffer
}
