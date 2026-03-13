import Foundation
import Testing
@testable import TextifyUI
@testable import TextifyKit

actor HistoryDetailExportServiceMock: ImageExportServiceProtocol {
    private(set) var exportedTextArt: TextArt?
    private let resultURL: URL

    init(resultURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("history-detail-share.png")) {
        self.resultURL = resultURL
    }

    func exportAsImage(textArt: TextArt) async throws -> URL {
        exportedTextArt = textArt
        return resultURL
    }

    func saveToPhotos(textArt: TextArt) async throws {}
}

actor FailingHistoryDetailExportServiceMock: ImageExportServiceProtocol {
    func exportAsImage(textArt: TextArt) async throws -> URL {
        throw ImageExportError.saveFailed
    }

    func saveToPhotos(textArt: TextArt) async throws {}
}

@Suite("HistoryDetailViewModel Tests")
struct HistoryDetailViewModelTests {

    private static func makeEntry() -> HistoryEntry {
        HistoryEntry(
            thumbnailData: Data(),
            textArtRows: ["@@", "##"],
            width: 2,
            height: 2,
            sourceCharacters: "@#",
            createdAt: Date(timeIntervalSince1970: 1_234),
            outputWidth: 80,
            invertBrightness: false,
            contrastBoost: 1.4
        )
    }

    @Test("Copy joins text rows and exposes confirmation state")
    @MainActor
    func testCopyToClipboard() async throws {
        let clipboard = MockClipboardService()
        let export = HistoryDetailExportServiceMock()
        let viewModel = HistoryDetailViewModel(
            entry: Self.makeEntry(),
            clipboardService: clipboard,
            exportService: export,
            feedbackResetDelay: .seconds(60)
        )

        viewModel.copyToClipboard()

        #expect(clipboard.copiedTexts == ["@@\n##"])
        #expect(viewModel.showCopyConfirmation == true)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Share preparation exports text art and stores share URL")
    @MainActor
    func testPrepareShareImageSuccess() async throws {
        let clipboard = MockClipboardService()
        let export = HistoryDetailExportServiceMock()
        let viewModel = HistoryDetailViewModel(
            entry: Self.makeEntry(),
            clipboardService: clipboard,
            exportService: export
        )

        await viewModel.prepareShareImage()

        #expect(await export.exportedTextArt == viewModel.textArt)
        #expect(viewModel.shareURL?.lastPathComponent == "history-detail-share.png")
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isPreparingShare == false)
    }

    @Test("Share preparation surfaces export failures")
    @MainActor
    func testPrepareShareImageFailure() async throws {
        let clipboard = MockClipboardService()
        let export = FailingHistoryDetailExportServiceMock()
        let viewModel = HistoryDetailViewModel(
            entry: Self.makeEntry(),
            clipboardService: clipboard,
            exportService: export
        )

        await viewModel.prepareShareImage()

        #expect(viewModel.shareURL == nil)
        #expect(viewModel.errorMessage == "이미지 공유 준비에 실패했습니다.")
        #expect(viewModel.isPreparingShare == false)
    }
}
