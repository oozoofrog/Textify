import Foundation
import CoreGraphics
import PhotosUI
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Errors that can occur during photo library operations
public enum PhotoLibraryError: Error, LocalizedError {
    case loadFailed
    case invalidImageData
    case cgImageCreationFailed

    public var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Failed to load photo from library"
        case .invalidImageData:
            return "The selected photo has invalid image data"
        case .cgImageCreationFailed:
            return "Failed to create image from photo data"
        }
    }
}

/// Service for accessing the photo library
public final class PhotoLibraryService: Sendable {

    public init() {}

    /// Loads a CGImage from a PhotosPickerItem with EXIF orientation applied.
    /// - Parameter item: The selected photo picker item
    /// - Returns: An orientation-normalized CGImage representation of the photo
    public func loadImage(from item: PhotosPickerItem) async throws -> CGImage {
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotoLibraryError.loadFailed
        }

        #if canImport(UIKit)
        return try createOrientationNormalizedCGImage(from: data)
        #else
        guard let dataProvider = CGDataProvider(data: data as CFData),
              let cgImage = CGImage(
                jpegDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) ?? CGImage(
                pngDataProviderSource: dataProvider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
              ) else {
            throw PhotoLibraryError.cgImageCreationFailed
        }
        return cgImage
        #endif
    }

    #if canImport(UIKit)
    /// Creates a CGImage from data with EXIF orientation baked into the pixels.
    ///
    /// `UIImage(data:)` reads EXIF orientation but `uiImage.cgImage` returns
    /// raw un-rotated pixels. This method draws the UIImage into a new bitmap
    /// context so the orientation transform is applied to the actual pixel data.
    func createOrientationNormalizedCGImage(from data: Data) throws -> CGImage {
        guard let uiImage = UIImage(data: data) else {
            throw PhotoLibraryError.cgImageCreationFailed
        }

        // Fast path: orientation is already correct
        if uiImage.imageOrientation == .up {
            guard let cgImage = uiImage.cgImage else {
                throw PhotoLibraryError.cgImageCreationFailed
            }
            return cgImage
        }

        // Redraw to bake in the orientation transform.
        // Force scale 1.0 so the resulting CGImage has 1:1 pixel dimensions.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        let renderer = UIGraphicsImageRenderer(size: uiImage.size, format: format)
        let normalized = renderer.image { _ in
            uiImage.draw(at: .zero)
        }

        guard let cgImage = normalized.cgImage else {
            throw PhotoLibraryError.cgImageCreationFailed
        }
        return cgImage
    }
    #endif
}
