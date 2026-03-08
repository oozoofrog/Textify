import Foundation
import CoreGraphics
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Errors that can occur during image validation
enum ImageValidationError: Error, LocalizedError {
    case dimensionTooLarge(width: Int, height: Int, maxDimension: Int)
    case fileSizeTooLarge(size: Int, maxSize: Int)
    case invalidImage
    case downscaleFailed

    var errorDescription: String? {
        switch self {
        case .dimensionTooLarge(let width, let height, let maxDimension):
            return "Image dimensions (\(width)x\(height)) exceed maximum allowed dimension of \(maxDimension)px"
        case .fileSizeTooLarge(let size, let maxSize):
            let sizeMB = Double(size) / 1_048_576
            let maxSizeMB = Double(maxSize) / 1_048_576
            return String(format: "Image file size (%.2f MB) exceeds maximum of %.2f MB", sizeMB, maxSizeMB)
        case .invalidImage:
            return "Invalid or corrupted image"
        case .downscaleFailed:
            return "Failed to downscale image"
        }
    }
}

/// Protocol for image validation service operations
protocol ImageValidationServiceProtocol: Sendable {
    func validate(_ image: CGImage) async throws
    func downscaleIfNeeded(_ image: CGImage, maxDimension: Int) async throws -> CGImage
}

/// Service for validating and processing images
final class ImageValidationService: ImageValidationServiceProtocol, Sendable {
    private let maxDimension = 4096
    private let maxFileSize = 20 * 1024 * 1024 // 20MB in bytes

    init() {}

    /// Validates an image against size and dimension constraints
    /// - Parameter image: The image to validate
    /// - Throws: ImageValidationError if validation fails
    func validate(_ image: CGImage) async throws {
        let width = image.width
        let height = image.height

        // Check dimensions
        if width > maxDimension || height > maxDimension {
            throw ImageValidationError.dimensionTooLarge(
                width: width,
                height: height,
                maxDimension: maxDimension
            )
        }

        // Estimate file size (rough calculation: width * height * 4 bytes per pixel)
        let estimatedSize = width * height * 4
        if estimatedSize > maxFileSize {
            throw ImageValidationError.fileSizeTooLarge(
                size: estimatedSize,
                maxSize: maxFileSize
            )
        }
    }

    /// Downscales an image if it exceeds the maximum dimension
    /// - Parameters:
    ///   - image: The image to downscale
    ///   - maxDimension: The maximum dimension (width or height)
    /// - Returns: The downscaled image, or the original if no downscaling is needed
    /// - Throws: ImageValidationError if downscaling fails
    func downscaleIfNeeded(_ image: CGImage, maxDimension: Int) async throws -> CGImage {
        let width = image.width
        let height = image.height

        // Check if downscaling is needed
        guard width > maxDimension || height > maxDimension else {
            return image
        }

        // Calculate new dimensions maintaining aspect ratio
        let scale: CGFloat
        if width > height {
            scale = CGFloat(maxDimension) / CGFloat(width)
        } else {
            scale = CGFloat(maxDimension) / CGFloat(height)
        }

        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)

        // Create downscaled image
        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) else {
            throw ImageValidationError.downscaleFailed
        }

        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw ImageValidationError.downscaleFailed
        }

        // Set high quality interpolation
        context.interpolationQuality = .high

        // Draw the image scaled
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        // Get the downscaled image
        guard let downscaledImage = context.makeImage() else {
            throw ImageValidationError.downscaleFailed
        }

        return downscaledImage
    }
}
