import Foundation
import SwiftUI
import TextifyKit

/// ViewModel for the result screen
@Observable
@MainActor
public final class ResultViewModel {
    public let textArt: TextArt
    private let clipboardService: ClipboardService
    private let exportService: ImageExportService
    private let historyService: HistoryService
    private let sourceImage: CGImage?
    private let sourceCharacters: String
    private let outputWidth: Int
    private let invertBrightness: Bool
    private let contrastBoost: Float

    public var isCopying = false
    public var isExporting = false
    public var showCopiedFeedback = false
    public var showSavedFeedback = false
    public var errorMessage: String?

    public init(
        textArt: TextArt,
        clipboardService: ClipboardService,
        exportService: ImageExportService,
        historyService: HistoryService,
        sourceImage: CGImage? = nil,
        sourceCharacters: String = "",
        outputWidth: Int = 80,
        invertBrightness: Bool = false,
        contrastBoost: Float = 1.0
    ) {
        self.textArt = textArt
        self.clipboardService = clipboardService
        self.exportService = exportService
        self.historyService = historyService
        self.sourceImage = sourceImage
        self.sourceCharacters = sourceCharacters
        self.outputWidth = outputWidth
        self.invertBrightness = invertBrightness
        self.contrastBoost = contrastBoost

        // Save to history on init
        Task {
            await saveToHistory()
        }
    }

    public var textArtString: String {
        textArt.asString
    }

    public var dimensions: String {
        "\(textArt.width) x \(textArt.height)"
    }

    public var characterCount: Int {
        textArt.rows.reduce(0) { $0 + $1.count }
    }

    public func copyToClipboard() {
        isCopying = true
        errorMessage = nil

        do {
            try clipboardService.copy(text: textArtString)
            showCopiedFeedback = true

            // Hide feedback after delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                showCopiedFeedback = false
            }
        } catch {
            errorMessage = "Failed to copy: \(error.localizedDescription)"
        }

        isCopying = false
    }

    public func saveAsImage() async {
        isExporting = true
        errorMessage = nil

        do {
            try await exportService.saveToPhotos(textArt: textArt)
            showSavedFeedback = true

            // Hide feedback after delay
            Task {
                try? await Task.sleep(for: .seconds(2))
                showSavedFeedback = false
            }
        } catch {
            errorMessage = "Save failed: \(error.localizedDescription)"
        }

        isExporting = false
    }

    private func saveToHistory() async {
        guard let sourceImage = sourceImage else { return }

        do {
            // Create thumbnail from source image
            let thumbnailData = try await createThumbnail(from: sourceImage)

            let entry = HistoryEntry(
                thumbnailData: thumbnailData,
                textArtRows: textArt.rows,
                width: textArt.width,
                height: textArt.height,
                sourceCharacters: sourceCharacters,
                outputWidth: outputWidth,
                invertBrightness: invertBrightness,
                contrastBoost: contrastBoost
            )

            try await historyService.add(entry)
        } catch {
            // Silently fail - history is not critical
            print("Failed to save to history: \(error)")
        }
    }

    private func createThumbnail(from image: CGImage) async throws -> Data {
        let maxSize: CGFloat = 200
        let width = CGFloat(image.width)
        let height = CGFloat(image.height)
        let scale = min(maxSize / width, maxSize / height)
        let newWidth = Int(width * scale)
        let newHeight = Int(height * scale)

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw NSError(domain: "ResultViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create thumbnail context"])
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let thumbnail = context.makeImage() else {
            throw NSError(domain: "ResultViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create thumbnail image"])
        }

        // Convert to JPEG data
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            throw NSError(domain: "ResultViewModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create image destination"])
        }

        CGImageDestinationAddImage(destination, thumbnail, [kCGImageDestinationLossyCompressionQuality: 0.8] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw NSError(domain: "ResultViewModel", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to finalize thumbnail"])
        }

        return data as Data
    }
}
