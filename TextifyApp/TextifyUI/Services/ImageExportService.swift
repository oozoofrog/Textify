import Foundation
import CoreGraphics
import TextifyKit
#if canImport(UIKit)
import UIKit
#endif

/// Protocol for image export operations.
public protocol ImageExportServiceProtocol: Sendable {
    func exportAsImage(textArt: TextArt) async throws -> URL
    func saveToPhotos(textArt: TextArt) async throws
}

/// Errors that can occur during image export operations
public enum ImageExportError: Error, LocalizedError, Equatable {
    case renderingFailed
    case saveFailed
    case platformNotSupported
    case permissionDenied
    case permissionRestricted

    public var errorDescription: String? {
        switch self {
        case .renderingFailed:
            return "Failed to render text art as image"
        case .saveFailed:
            return "Failed to save the exported image"
        case .platformNotSupported:
            return "Image export is not supported on this platform"
        case .permissionDenied:
            return "Photo library access is denied"
        case .permissionRestricted:
            return "Photo library access is restricted"
        }
    }
}

/// Service for exporting text art as images
public final class ImageExportService: ImageExportServiceProtocol, Sendable {
    private let saveAuthorizationService: PhotoLibrarySaveAuthorizationService

    public init(
        saveAuthorizationService: PhotoLibrarySaveAuthorizationService = PhotoLibrarySaveAuthorizationService()
    ) {
        self.saveAuthorizationService = saveAuthorizationService
    }

    /// Exports text art as a PNG image
    /// - Parameter textArt: The text art to export
    /// - Returns: URL of the exported image in the temporary directory
    public func exportAsImage(textArt: TextArt) async throws -> URL {
        #if canImport(UIKit)
        return try await renderToImage(textArt: textArt)
        #else
        throw ImageExportError.platformNotSupported
        #endif
    }

    /// Saves text art as an image to the Photos library
    /// - Parameter textArt: The text art to save
    public func saveToPhotos(textArt: TextArt) async throws {
        #if canImport(UIKit)
        try await saveAuthorizationService.ensureAuthorized()
        let url = try await renderToImage(textArt: textArt)
        let data = try Data(contentsOf: url)
        guard let image = UIImage(data: data) else {
            throw ImageExportError.renderingFailed
        }
        try await saveImageToPhotos(image)
        #else
        throw ImageExportError.platformNotSupported
        #endif
    }

    #if canImport(UIKit)
    @MainActor
    private func saveImageToPhotos(_ image: UIImage) async throws {
        let saver = PhotoLibrarySaveOperation()
        try await saver.save(image)
    }

    @MainActor
    private final class PhotoLibrarySaveOperation: NSObject {
        private var continuation: CheckedContinuation<Void, Error>?

        func save(_ image: UIImage) async throws {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                UIImageWriteToSavedPhotosAlbum(
                    image,
                    self,
                    #selector(handleSaveResult(_:didFinishSavingWithError:contextInfo:)),
                    nil
                )
            }
        }

        @objc
        private func handleSaveResult(
            _ image: UIImage,
            didFinishSavingWithError error: Error?,
            contextInfo: UnsafeMutableRawPointer?
        ) {
            if let error {
                continuation?.resume(throwing: error)
            } else {
                continuation?.resume(returning: ())
            }
            continuation = nil
        }
    }
    #endif

    #if canImport(UIKit)
    @MainActor
    private func renderToImage(textArt: TextArt) throws -> URL {
        let text = textArt.asString

        let font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.green,
            .backgroundColor: UIColor.black
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        let paddedSize = CGSize(
            width: size.width + 20,
            height: size.height + 20
        )

        let renderer = UIGraphicsImageRenderer(size: paddedSize)
        let image = renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: paddedSize))
            attributedString.draw(at: CGPoint(x: 10, y: 10))
        }

        guard let data = image.pngData() else {
            throw ImageExportError.renderingFailed
        }

        let tempDir = FileManager.default.temporaryDirectory
        let filename = "textify-\(UUID().uuidString).png"
        let fileURL = tempDir.appendingPathComponent(filename)

        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            throw ImageExportError.saveFailed
        }
    }
    #endif
}
