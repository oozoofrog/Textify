import Foundation
import CoreGraphics
import PhotosUI
import SwiftUI

/// Errors that can occur during photo library operations
enum PhotoLibraryError: Error, LocalizedError {
    case loadFailed
    case invalidImageData
    case cgImageCreationFailed

    var errorDescription: String? {
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
final class PhotoLibraryService: Sendable {

    init() {}

    /// Loads a CGImage from a PhotosPickerItem
    /// - Parameter item: The selected photo picker item
    /// - Returns: A CGImage representation of the photo
    func loadImage(from item: PhotosPickerItem) async throws -> CGImage {
        // Load transferable data
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotoLibraryError.loadFailed
        }

        // Create CGImage from data
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
            // Try using UIImage as fallback
            #if canImport(UIKit)
            guard let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                throw PhotoLibraryError.cgImageCreationFailed
            }
            return cgImage
            #else
            throw PhotoLibraryError.cgImageCreationFailed
            #endif
        }

        return cgImage
    }
}
