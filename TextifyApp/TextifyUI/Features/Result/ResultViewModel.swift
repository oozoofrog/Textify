import Foundation
import SwiftUI
import TextifyKit

/// ViewModel for the result screen
@Observable
@MainActor
public final class ResultViewModel {
    public let textArt: TextArt
    private let clipboardService: any ClipboardServiceProtocol
    private let exportService: any ImageExportServiceProtocol
    private let historyRecorder: any TextArtHistoryRecording
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
        clipboardService: any ClipboardServiceProtocol,
        exportService: any ImageExportServiceProtocol,
        historyRecorder: any TextArtHistoryRecording,
        sourceImage: CGImage? = nil,
        sourceCharacters: String = "",
        outputWidth: Int = 80,
        invertBrightness: Bool = false,
        contrastBoost: Float = 1.0
    ) {
        self.textArt = textArt
        self.clipboardService = clipboardService
        self.exportService = exportService
        self.historyRecorder = historyRecorder
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
            let request = TextArtHistoryRecordRequest(
                sourceImage: sourceImage,
                textArt: textArt,
                sourceCharacters: sourceCharacters,
                outputWidth: outputWidth,
                invertBrightness: invertBrightness,
                contrastBoost: contrastBoost
            )
            try await historyRecorder.record(request)
        } catch {
            // Silently fail - history is not critical
            print("Failed to save to history: \(error)")
        }
    }
}
