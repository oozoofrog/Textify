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
    private let error: Error

    init(error: Error = ImageExportError.saveFailed) {
        self.error = error
    }

    func exportAsImage(textArt: TextArt) async throws -> URL {
        throw error
    }

    func saveToPhotos(textArt: TextArt) async throws {}
}

actor SlowHistoryDetailExportServiceMock: ImageExportServiceProtocol {
    private(set) var exportCallCount = 0
    private let delay: Duration

    init(delay: Duration = .milliseconds(150)) {
        self.delay = delay
    }

    func exportAsImage(textArt: TextArt) async throws -> URL {
        exportCallCount += 1
        try await Task.sleep(for: delay)
        return FileManager.default.temporaryDirectory.appendingPathComponent("history-detail-share.png")
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
        #expect(viewModel.errorMessage == "공유용 이미지를 준비하지 못했습니다.")
        #expect(viewModel.isPreparingShare == false)
    }

    @Test("Share preparation rendering failure uses the shared export presentation")
    @MainActor
    func testPrepareShareImageRenderingFailure() async throws {
        let clipboard = MockClipboardService()
        let export = FailingHistoryDetailExportServiceMock(error: ImageExportError.renderingFailed)
        let viewModel = HistoryDetailViewModel(
            entry: Self.makeEntry(),
            clipboardService: clipboard,
            exportService: export
        )

        await viewModel.prepareShareImage()

        #expect(viewModel.shareURL == nil)
        #expect(viewModel.errorMessage == "공유용 이미지를 만드는 데 실패했습니다.")
        #expect(viewModel.isPreparingShare == false)
    }

    @Test("Share preparation ignores re-entrant requests while export is in flight")
    @MainActor
    func testPrepareShareImagePreventsReentry() async throws {
        let clipboard = MockClipboardService()
        let export = SlowHistoryDetailExportServiceMock()
        let viewModel = HistoryDetailViewModel(
            entry: Self.makeEntry(),
            clipboardService: clipboard,
            exportService: export
        )

        let firstTask = Task {
            await viewModel.prepareShareImage()
        }

        try await Task.sleep(for: .milliseconds(20))

        let secondTask = Task {
            await viewModel.prepareShareImage()
        }

        await firstTask.value
        await secondTask.value

        #expect(await export.exportCallCount == 1)
        #expect(viewModel.shareURL?.lastPathComponent == "history-detail-share.png")
        #expect(viewModel.isPreparingShare == false)
    }
}
