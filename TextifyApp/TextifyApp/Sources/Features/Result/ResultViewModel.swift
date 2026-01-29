import Foundation
import SwiftUI
import TextifyKit

/// ViewModel for the result screen
@Observable
@MainActor
final class ResultViewModel {
    let textArt: TextArt
    private let clipboardService: ClipboardService
    private let exportService: ImageExportService

    var isCopying = false
    var isExporting = false
    var showCopiedFeedback = false
    var showSavedFeedback = false
    var errorMessage: String?

    init(
        textArt: TextArt,
        clipboardService: ClipboardService,
        exportService: ImageExportService
    ) {
        self.textArt = textArt
        self.clipboardService = clipboardService
        self.exportService = exportService
    }

    var textArtString: String {
        textArt.asString
    }

    var dimensions: String {
        "\(textArt.width) x \(textArt.height)"
    }

    var characterCount: Int {
        textArt.rows.reduce(0) { $0 + $1.count }
    }

    func copyToClipboard() {
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

    func saveAsImage() async {
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
}
