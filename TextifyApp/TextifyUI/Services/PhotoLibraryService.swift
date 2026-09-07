import Foundation
import CoreGraphics
import ImageIO
import PhotosUI
import SwiftUI

/// Errors that can occur during photo library operations
public enum PhotoLibraryError: Error, LocalizedError {
    case loadFailed
    case fileLoadFailed
    case invalidImageData
    case cgImageCreationFailed

    public var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "Failed to load photo from library"
        case .fileLoadFailed:
            return "Failed to read the selected image file"
        case .invalidImageData:
            return "The selected photo has invalid image data"
        case .cgImageCreationFailed:
            return "Failed to create image from photo data"
        }
    }
}

public protocol PhotoLibraryLoading: Sendable {
    func loadImage(from item: PhotosPickerItem) async throws -> CGImage
    func loadImage(fromFile url: URL) async throws -> CGImage
}

/// Service for loading local images from the photo library or Files.
public final class PhotoLibraryService: PhotoLibraryLoading {

    public init() {}

    /// Loads a CGImage with EXIF orientation applied and dimensions bounded for TextifyKit.
    /// - Parameter item: The selected photo picker item
    /// - Returns: An orientation-normalized CGImage representation of the photo
    @concurrent
    public func loadImage(from item: PhotosPickerItem) async throws -> CGImage {
        try Task.checkCancellation()
        guard let data = try await item.loadTransferable(type: Data.self) else {
            throw PhotoLibraryError.loadFailed
        }

        try Task.checkCancellation()
        let image = try createOrientationNormalizedCGImage(from: data)
        try Task.checkCancellation()
        return image
    }

    /// Reads the selected file while its security scope is held, then returns decoded pixels.
    /// Blocking file I/O and ImageIO decoding run away from the caller's actor.
    @concurrent
    public func loadImage(fromFile url: URL) async throws -> CGImage {
        try Task.checkCancellation()
        guard url.isFileURL else { throw PhotoLibraryError.fileLoadFailed }
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope { url.stopAccessingSecurityScopedResource() }
        }

        let data: Data
        do {
            // A sandbox-local file can be readable even when no security scope is needed.
            data = try Data(contentsOf: url, options: .mappedIfSafe)
        } catch {
            try Task.checkCancellation()
            if (error as? CocoaError)?.code == .userCancelled { throw CancellationError() }
            throw PhotoLibraryError.fileLoadFailed
        }
        try Task.checkCancellation()
        let image = try createOrientationNormalizedCGImage(from: data)
        try Task.checkCancellation()
        return image
    }

    /// Decodes an oriented image no larger than TextifyKit's 4096-pixel input limit.
    /// ImageIO downsamples while decoding, avoiding a full-size redraw of large photos.
    func createOrientationNormalizedCGImage(from data: Data) throws -> CGImage {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            throw PhotoLibraryError.cgImageCreationFailed
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, thumbnailOptions as CFDictionary
        ) else {
            throw PhotoLibraryError.cgImageCreationFailed
        }
        return cgImage
    }
}
