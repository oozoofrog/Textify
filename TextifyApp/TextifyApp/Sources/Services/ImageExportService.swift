import Foundation
import CoreGraphics
import TextifyKit
#if canImport(UIKit)
import UIKit
#endif

/// Errors that can occur during image export operations
enum ImageExportError: Error, LocalizedError {
    case renderingFailed
    case saveFailed
    case platformNotSupported

    var errorDescription: String? {
        switch self {
        case .renderingFailed:
            return "Failed to render text art as image"
        case .saveFailed:
            return "Failed to save the exported image"
        case .platformNotSupported:
            return "Image export is not supported on this platform"
        }
    }
}

/// Service for exporting text art as images
final class ImageExportService: Sendable {

    init() {}

    /// Exports text art as a PNG image
    /// - Parameter textArt: The text art to export
    /// - Returns: URL of the exported image in the temporary directory
    func exportAsImage(textArt: TextArt) async throws -> URL {
        #if canImport(UIKit)
        return try await renderToImage(textArt: textArt)
        #else
        throw ImageExportError.platformNotSupported
        #endif
    }

    /// Saves text art as an image to the Photos library
    /// - Parameter textArt: The text art to save
    func saveToPhotos(textArt: TextArt) async throws {
        #if canImport(UIKit)
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
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    #endif

    #if canImport(UIKit)
    @MainActor
    private func renderToImage(textArt: TextArt) throws -> URL {
        let text = textArt.asString

        // Configure text attributes
        let font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.green,
            .backgroundColor: UIColor.black
        ]

        // Calculate size
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        // Add padding
        let paddedSize = CGSize(
            width: size.width + 20,
            height: size.height + 20
        )

        // Render to image
        let renderer = UIGraphicsImageRenderer(size: paddedSize)
        let image = renderer.image { context in
            // Fill background
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: paddedSize))

            // Draw text
            attributedString.draw(at: CGPoint(x: 10, y: 10))
        }

        // Save to temporary file
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
