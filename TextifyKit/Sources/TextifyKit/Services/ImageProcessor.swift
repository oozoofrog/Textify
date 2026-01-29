import Foundation
import CoreGraphics

/// Actor that processes images for text art generation.
/// Converts CGImages to grayscale pixel buffers with scaling.
public actor ImageProcessor: ImageProcessing {

    /// Maximum allowed image dimension (width or height)
    private let maxImageDimension: Int

    /// Creates a new ImageProcessor.
    /// - Parameter maxImageDimension: Maximum allowed dimension (default 4096)
    public init(maxImageDimension: Int = 4096) {
        self.maxImageDimension = maxImageDimension
    }

    /// Converts a CGImage to grayscale pixels scaled to the specified width.
    public func grayscalePixels(
        from image: CGImage,
        scaledToWidth targetWidth: Int,
        aspectCorrection: Float
    ) async throws -> GrayscalePixelBuffer {
        let sourceWidth = image.width
        let sourceHeight = image.height

        // Validate image dimensions
        guard sourceWidth > 0, sourceHeight > 0 else {
            throw ImageProcessingError.invalidImage
        }

        guard sourceWidth <= maxImageDimension, sourceHeight <= maxImageDimension else {
            throw ImageProcessingError.imageTooLarge(
                width: sourceWidth,
                height: sourceHeight,
                maxDimension: maxImageDimension
            )
        }

        // Calculate output dimensions
        let aspectRatio = Float(sourceHeight) / Float(sourceWidth)
        let outputWidth = max(1, targetWidth)
        let outputHeight = max(1, Int(Float(outputWidth) * aspectRatio * aspectCorrection))

        // Create grayscale context
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: 0, count: outputWidth * outputHeight)

        guard let context = CGContext(
            data: &pixels,
            width: outputWidth,
            height: outputHeight,
            bitsPerComponent: 8,
            bytesPerRow: outputWidth,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw ImageProcessingError.contextCreationFailed
        }

        // Draw image scaled to fit context
        let rect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
        context.interpolationQuality = .high
        context.draw(image, in: rect)

        return GrayscalePixelBuffer(
            pixels: pixels,
            width: outputWidth,
            height: outputHeight
        )
    }
}
