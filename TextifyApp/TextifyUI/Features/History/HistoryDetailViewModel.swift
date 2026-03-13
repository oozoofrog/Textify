import Foundation
import SwiftUI
import TextifyKit

@Observable
@MainActor
public final class HistoryDetailViewModel {
    public let entry: HistoryEntry

    private let clipboardService: any ClipboardServiceProtocol
    private let exportService: any ImageExportServiceProtocol
    private let feedbackResetDelay: Duration

    public var showCopyConfirmation = false
    public var isPreparingShare = false
    public var shareURL: URL?
    public var errorMessage: String?

    public init(
        entry: HistoryEntry,
        clipboardService: any ClipboardServiceProtocol,
        exportService: any ImageExportServiceProtocol,
        feedbackResetDelay: Duration = .seconds(2)
    ) {
        self.entry = entry
        self.clipboardService = clipboardService
        self.exportService = exportService
        self.feedbackResetDelay = feedbackResetDelay
    }

    public var textArtString: String {
        entry.textArtRows.joined(separator: "\n")
    }

    public var textArt: TextArt {
        TextArt(
            rows: entry.textArtRows,
            width: entry.width,
            height: entry.height,
            sourceCharacters: entry.sourceCharacters,
            createdAt: entry.createdAt
        )
    }

    public func copyToClipboard() {
        do {
            try clipboardService.copy(text: textArtString)
            showCopyConfirmation = true
            Task {
                try? await Task.sleep(for: feedbackResetDelay)
                await MainActor.run {
                    self.showCopyConfirmation = false
                }
            }
        } catch {
            errorMessage = "텍스트를 복사하지 못했습니다."
        }
    }

    public func prepareShareImage() async {
        isPreparingShare = true
        errorMessage = nil

        do {
            shareURL = try await exportService.exportAsImage(textArt: textArt)
        } catch {
            errorMessage = "이미지 공유 준비에 실패했습니다."
        }

        isPreparingShare = false
    }
}
