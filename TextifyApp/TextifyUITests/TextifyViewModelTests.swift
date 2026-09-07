import Testing
import Foundation
import CoreGraphics
import UIKit
@testable import TextifyUI
@testable import TextifyKit

actor MockTextArtGenerator: TextArtGenerating {
    private(set) var generateCallCount = 0
    private(set) var lastGenerateTime: ContinuousClock.Instant?
    private let result: TextArt
    private let delay: Duration

    init(
        result: TextArt = TextArt(
            rows: ["@#", "*+"],
            width: 2,
            height: 2,
            sourceCharacters: "@#*+",
            createdAt: Date()
        ),
        delay: Duration = .milliseconds(50)
    ) {
        self.result = result
        self.delay = delay
    }

    func generate(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt {
        generateCallCount += 1
        lastGenerateTime = ContinuousClock.now
        try await Task.sleep(for: delay)
        return result
    }
}

actor CapturingTextArtGenerator: TextArtGenerating {
    private(set) var generateCallCount = 0
    private(set) var lastPalette: CharacterPalette?
    private(set) var lastOptions: ProcessingOptions?
    private let result: TextArt

    init(
        result: TextArt = TextArt(
            rows: ["@#", "*+"],
            width: 2,
            height: 2,
            sourceCharacters: "@#*+",
            createdAt: Date()
        )
    ) {
        self.result = result
    }

    func generate(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt {
        generateCallCount += 1
        lastPalette = palette
        lastOptions = options
        return result
    }
}

actor OptionAwareTextArtGenerator: TextArtGenerating {
    private(set) var generateCallCount = 0
    private(set) var receivedWidths: [Int] = []
    private(set) var receivedContrasts: [Float] = []
    private let slowWidths: Set<Int>
    private let slowDelay: Duration
    private let fastDelay: Duration

    init(
        slowWidths: Set<Int> = [],
        slowDelay: Duration = .milliseconds(200),
        fastDelay: Duration = .milliseconds(10)
    ) {
        self.slowWidths = slowWidths
        self.slowDelay = slowDelay
        self.fastDelay = fastDelay
    }

    func generate(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt {
        generateCallCount += 1
        receivedWidths.append(options.outputWidth)
        receivedContrasts.append(options.contrastBoost)

        let delay = slowWidths.contains(options.outputWidth) ? slowDelay : fastDelay
        try await Task.sleep(for: delay)

        let row = "\(options.outputWidth)-\(String(format: "%.1f", options.contrastBoost))"
        return TextArt(
            rows: [row],
            width: options.outputWidth,
            height: 1,
            sourceCharacters: String(palette.characters),
            createdAt: Date()
        )
    }
}

actor ErrorThrowingGenerator: TextArtGenerating {
    func generate(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt {
        throw TextArtGenerationError.generationFailed("Test error")
    }
}

final class MockClipboardService: ClipboardServiceProtocol, @unchecked Sendable {
    private(set) var copiedTexts: [String] = []

    func copy(text: String) throws {
        copiedTexts.append(text)
    }
}

actor MockImageExportService: ImageExportServiceProtocol {
    private(set) var exportCallCount = 0
    private(set) var saveCallCount = 0

    func exportAsImage(textArt: TextArt) async throws -> URL {
        exportCallCount += 1
        return FileManager.default.temporaryDirectory.appendingPathComponent("mock.png")
    }

    func saveToPhotos(textArt: TextArt) async throws {
        saveCallCount += 1
    }
}

actor FailingImageExportService: ImageExportServiceProtocol {
    private let error: Error

    init(error: Error) {
        self.error = error
    }

    func exportAsImage(textArt: TextArt) async throws -> URL {
        throw error
    }

    func saveToPhotos(textArt: TextArt) async throws {
        throw error
    }
}

actor SlowImageExportService: ImageExportServiceProtocol {
    private(set) var saveCallCount = 0
    private let delay: Duration

    init(delay: Duration = .milliseconds(150)) {
        self.delay = delay
    }

    func exportAsImage(textArt: TextArt) async throws -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("slow-export.png")
    }

    func saveToPhotos(textArt: TextArt) async throws {
        saveCallCount += 1
        try await Task.sleep(for: delay)
    }
}

actor MockHistoryService: HistoryServiceProtocol {
    private(set) var addedEntries: [HistoryEntry] = []
    private(set) var clearCallCount = 0

    func add(_ entry: HistoryEntry) async throws {
        addedEntries.append(entry)
    }

    func delete(id: UUID) async throws {
        addedEntries.removeAll { $0.id == id }
    }

    func clear() async throws {
        clearCallCount += 1
        addedEntries.removeAll()
    }

    func list() async throws -> [HistoryEntry] {
        addedEntries
    }
}

actor MockHistoryRecorder: TextArtHistoryRecording {
    private(set) var recordedRequests: [TextArtHistoryRecordRequest] = []

    func record(_ request: TextArtHistoryRecordRequest) async throws {
        recordedRequests.append(request)
    }
}

@MainActor
final class MockHapticsService: HapticsServiceProtocol {
    private(set) var successCount = 0
    private(set) var errorCount = 0

    func impact(style: HapticImpactStyle) {}
    func selection() {}

    func notification(type: HapticNotificationType) {
        switch type {
        case .success:
            successCount += 1
        case .warning:
            break
        case .error:
            errorCount += 1
        }
    }
}

extension TextifyViewModelTests {
    static func createTestImage() -> CGImage {
        let size = CGSize(width: 10, height: 10)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            fatalError("Failed to create test context")
        }
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        guard let image = context.makeImage() else {
            fatalError("Failed to create test image")
        }
        return image
    }

    @MainActor
    static func makeViewModel(
        generator: any TextArtGenerating,
        clipboard: MockClipboardService = MockClipboardService(),
        export: any ImageExportServiceProtocol = MockImageExportService(),
        historyRecorder: any TextArtHistoryRecording = MockHistoryRecorder(),
        haptics: MockHapticsService = MockHapticsService(),
        feedbackResetDelay: Duration = .milliseconds(100)
    ) -> TextifyViewModel {
        TextifyViewModel(
            image: createTestImage(),
            generator: generator,
            clipboardService: clipboard,
            exportService: export,
            historyRecorder: historyRecorder,
            hapticsService: haptics,
            feedbackResetDelay: feedbackResetDelay
        )
    }
}

@Suite("TextifyViewModel Tests")
struct TextifyViewModelTests {

    @Test("generateFinal uses debouncing - rapid calls result in single generation")
    @MainActor
    func testGenerateFinalIsDebounced() async throws {
        let mockGenerator = MockTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: mockGenerator)

        viewModel.generateFinal()
        viewModel.generateFinal()
        viewModel.generateFinal()

        try await Task.sleep(for: .milliseconds(350))

        #expect(await mockGenerator.generateCallCount == 1)
    }

    @Test("Previous generation cancelled on new request")
    @MainActor
    func testPreviousGenerationCancelled() async throws {
        let mockGenerator = MockTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: mockGenerator)

        let task1 = Task {
            await viewModel.generate()
        }

        try await Task.sleep(for: .milliseconds(10))

        let task2 = Task {
            await viewModel.generate()
        }

        await task1.value
        await task2.value

        #expect(await mockGenerator.generateCallCount >= 2)
        #expect(viewModel.textArt != nil)
    }

    @Test("Generate sets isGenerating flag correctly")
    @MainActor
    func testGenerateSetsIsGeneratingFlag() async throws {
        let mockGenerator = MockTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: mockGenerator)

        #expect(viewModel.isGenerating == false)

        let task = Task {
            await viewModel.generate()
        }

        try await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.isGenerating == true)

        await task.value

        #expect(viewModel.isGenerating == false)
        #expect(viewModel.textArt != nil)
    }

    @Test("Error during generation sets error message")
    @MainActor
    func testErrorDuringGenerationSetsErrorMessage() async throws {
        let errorGenerator = ErrorThrowingGenerator()
        let viewModel = Self.makeViewModel(generator: errorGenerator)

        await viewModel.generate()

        #expect(viewModel.textArt == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isGenerating == false)
    }

    @Test("Copy action uses clipboard service and feedback state")
    @MainActor
    func testCopyActionUsesClipboardServiceAndFeedbackState() async throws {
        let generator = MockTextArtGenerator()
        let clipboard = MockClipboardService()
        let viewModel = Self.makeViewModel(generator: generator, clipboard: clipboard)
        await viewModel.generate()

        viewModel.copyToClipboard()

        #expect(clipboard.copiedTexts == ["@#\n*+"])
        #expect(viewModel.copied == true)
    }

    @Test("Save action uses export service and feedback state")
    @MainActor
    func testSaveActionUsesExportServiceAndFeedbackState() async throws {
        let generator = MockTextArtGenerator()
        let export = MockImageExportService()
        let viewModel = Self.makeViewModel(generator: generator, export: export)
        await viewModel.generate()

        await viewModel.saveAsImage()

        #expect(await export.saveCallCount == 1)
        #expect(viewModel.showSavedFeedback == true)
    }

    @Test("Copy action persists history once for identical output")
    @MainActor
    func testCopyActionPersistsHistoryOnceForIdenticalOutput() async throws {
        let generator = MockTextArtGenerator()
        let historyRecorder = MockHistoryRecorder()
        let clipboard = MockClipboardService()
        let viewModel = Self.makeViewModel(generator: generator, clipboard: clipboard, historyRecorder: historyRecorder)

        await viewModel.generate()
        viewModel.copyToClipboard()
        viewModel.copyToClipboard()

        try await Task.sleep(for: .milliseconds(20))

        #expect(await historyRecorder.recordedRequests.count == 1)
    }

    @Test("Output width interaction commits the final width after rapid changes")
    @MainActor
    func testOutputWidthInteractionCommitsFinalWidth() async throws {
        let generator = OptionAwareTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: generator)

        viewModel.outputWidthBinding.wrappedValue = 40
        try await Task.sleep(for: .milliseconds(10))
        viewModel.outputWidthBinding.wrappedValue = 80
        try await Task.sleep(for: .milliseconds(10))
        viewModel.outputWidthBinding.wrappedValue = 120
        viewModel.handleOutputWidthEditingChanged(false)

        try await Task.sleep(for: .milliseconds(350))

        #expect(viewModel.outputWidth == 120)
        #expect(viewModel.textArt?.width == 120)
        #expect(viewModel.textArt?.asString == "120-1.0")
        #expect(await generator.receivedWidths.last == 120)
        #expect(await generator.generateCallCount >= 1)
    }

    @Test("Stale width preview does not override the latest committed result")
    @MainActor
    func testStalePreviewDoesNotOverrideCommittedGeneration() async throws {
        let generator = OptionAwareTextArtGenerator(slowWidths: [30])
        let viewModel = Self.makeViewModel(generator: generator)

        viewModel.outputWidthBinding.wrappedValue = 30
        try await Task.sleep(for: .milliseconds(80))
        viewModel.outputWidthBinding.wrappedValue = 150
        viewModel.handleOutputWidthEditingChanged(false)

        try await Task.sleep(for: .milliseconds(450))

        #expect(viewModel.outputWidth == 150)
        #expect(viewModel.textArt?.width == 150)
        #expect(viewModel.textArt?.asString == "150-1.0")
        #expect(await generator.receivedWidths.contains(30))
        #expect(await generator.receivedWidths.last == 150)
    }

    @Test("Save action ignores re-entrant requests while a save is in flight")
    @MainActor
    func testSaveActionPreventsReentrantSaves() async throws {
        let generator = MockTextArtGenerator()
        let export = SlowImageExportService()
        let viewModel = Self.makeViewModel(generator: generator, export: export)
        await viewModel.generate()

        let firstSave = Task {
            await viewModel.saveAsImage()
        }

        try await Task.sleep(for: .milliseconds(20))

        let secondSave = Task {
            await viewModel.saveAsImage()
        }

        await firstSave.value
        await secondSave.value

        #expect(await export.saveCallCount == 1)
        #expect(viewModel.isSavingImage == false)
    }

    @Test("Copy then save records history only once for the same result")
    @MainActor
    func testCopyThenSavePersistsHistoryOnce() async throws {
        let generator = MockTextArtGenerator()
        let historyRecorder = MockHistoryRecorder()
        let clipboard = MockClipboardService()
        let export = MockImageExportService()
        let viewModel = Self.makeViewModel(
            generator: generator,
            clipboard: clipboard,
            export: export,
            historyRecorder: historyRecorder
        )

        await viewModel.generate()
        viewModel.copyToClipboard()
        try await Task.sleep(for: .milliseconds(20))
        await viewModel.saveAsImage()

        #expect(await historyRecorder.recordedRequests.count == 1)
    }

    @Test("History is recorded again when the displayed option set changes")
    @MainActor
    func testHistoryPersistsAgainWhenOptionsChange() async throws {
        let generator = OptionAwareTextArtGenerator()
        let historyRecorder = MockHistoryRecorder()
        let clipboard = MockClipboardService()
        let viewModel = Self.makeViewModel(
            generator: generator,
            clipboard: clipboard,
            historyRecorder: historyRecorder
        )

        await viewModel.generate()
        viewModel.copyToClipboard()
        try await Task.sleep(for: .milliseconds(20))

        viewModel.contrastBoost = 1.5
        await viewModel.generate()
        viewModel.copyToClipboard()
        try await Task.sleep(for: .milliseconds(20))

        let recordedRequests = await historyRecorder.recordedRequests
        #expect(recordedRequests.count == 2)
        #expect(abs(recordedRequests[0].contrastBoost - 1.0) < 0.0001)
        #expect(abs(recordedRequests[1].contrastBoost - 1.5) < 0.0001)
    }

    @Test("Custom palette and contrast are forwarded to generator options")
    @MainActor
    func testCustomPaletteAndContrastAreForwarded() async throws {
        let generator = CapturingTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: generator)

        viewModel.selectPreset(.custom)
        viewModel.updateCustomCharacters("##@@..\n##")
        viewModel.contrastBoost = 1.7

        await viewModel.generate()

        let palette = await generator.lastPalette
        let options = await generator.lastOptions

        #expect(palette?.characters == Array("#@. "))
        #expect(abs((options?.contrastBoost ?? -1) - 1.7) < 0.0001)
        #expect(options?.outputWidth == viewModel.outputWidth)
    }

    @Test("Save permission denied exposes settings recovery action")
    @MainActor
    func testSavePermissionDeniedExposesSettingsRecoveryAction() async throws {
        let generator = MockTextArtGenerator()
        let export = FailingImageExportService(error: ImageExportError.permissionDenied)
        let viewModel = TextifyViewModel(
            image: Self.createTestImage(),
            generator: generator,
            clipboardService: MockClipboardService(),
            exportService: export,
            historyRecorder: MockHistoryRecorder(),
            hapticsService: MockHapticsService()
        )
        await viewModel.generate()

        await viewModel.saveAsImage()

        #expect(viewModel.errorMessage == "사진 보관함 접근이 거부되어 저장할 수 없습니다. 설정에서 사진 접근을 허용해 주세요.")
        #expect(viewModel.errorAction == .openSettings)
    }

    @Test("Save permission restricted shows non-settings error")
    @MainActor
    func testSavePermissionRestrictedShowsInlineError() async throws {
        let generator = MockTextArtGenerator()
        let export = FailingImageExportService(error: ImageExportError.permissionRestricted)
        let viewModel = TextifyViewModel(
            image: Self.createTestImage(),
            generator: generator,
            clipboardService: MockClipboardService(),
            exportService: export,
            historyRecorder: MockHistoryRecorder(),
            hapticsService: MockHapticsService()
        )
        await viewModel.generate()

        await viewModel.saveAsImage()

        #expect(viewModel.errorMessage == "이 기기에서는 사진 보관함 저장이 제한되어 있습니다.")
        #expect(viewModel.errorAction == nil)
    }
}

/// Completes only when the test releases a specific width, even after cancellation.
actor ControlledTextArtGenerator: TextArtGenerating {
    private var pending: [Int: CheckedContinuation<TextArt, Never>] = [:]
    private(set) var startedWidths: Set<Int> = []

    func generate(from image: CGImage, palette: CharacterPalette, options: ProcessingOptions) async throws -> TextArt {
        await withCheckedContinuation { continuation in
            pending[options.outputWidth] = continuation
            startedWidths.insert(options.outputWidth)
        }
    }

    func finish(width: Int) {
        pending.removeValue(forKey: width)?.resume(returning: TextArt(
            rows: [String(width)], width: width, height: 1,
            sourceCharacters: "@ ", createdAt: Date()
        ))
    }
}

actor ControlledImageExportService: ImageExportServiceProtocol {
    private(set) var savedArt: TextArt?
    private var completion: CheckedContinuation<Void, Never>?

    func exportAsImage(textArt: TextArt) async throws -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("controlled.png")
    }

    func saveToPhotos(textArt: TextArt) async throws {
        await withCheckedContinuation { continuation in
            savedArt = textArt
            completion = continuation
        }
    }

    func finish() {
        completion?.resume()
        completion = nil
    }
}

actor RetryHistoryRecorder: TextArtHistoryRecording {
    private(set) var attempts = 0
    func record(_ request: TextArtHistoryRecordRequest) async throws {
        attempts += 1
        if attempts == 1 { throw CocoaError(.fileWriteOutOfSpace) }
    }
}

extension TextifyViewModelTests {
    /// Polls a condition with a deadline; execution order is controlled by the test gates.
    @MainActor
    static func waitUntil(_ condition: () async -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(3)
        while !(await condition()) {
            guard ContinuousClock.now < deadline else { throw CocoaError(.coderInvalidValue) }
            await Task.yield()
        }
    }

    @Test("Leaving the workspace cancels scheduled generation synchronously")
    @MainActor
    func cancelScheduledGeneration() async throws {
        let generator = CapturingTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: generator)
        viewModel.generateFinal()
        #expect(viewModel.isGenerating)
        viewModel.cancelGeneration()
        #expect(!viewModel.isGenerating)
        try await Task.sleep(for: .milliseconds(300))
        #expect(await generator.generateCallCount == 0)
        #expect(viewModel.textArt == nil)
    }

    @Test("A late result from a generator ignoring cancellation cannot replace the latest result")
    @MainActor
    func ignoresUncooperativeStaleGeneration() async throws {
        let generator = ControlledTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: generator)
        viewModel.outputWidth = 40
        let old = Task { await viewModel.generate() }
        try await Self.waitUntil { await generator.startedWidths.contains(40) }
        viewModel.outputWidth = 120
        let latest = Task { await viewModel.generate() }
        try await Self.waitUntil { await generator.startedWidths.contains(120) }
        await generator.finish(width: 120)
        await latest.value
        await generator.finish(width: 40)
        await old.value
        #expect(viewModel.textArt?.width == 120)
        #expect(!viewModel.isGenerating)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Cancelling the parent generation task prevents result publication")
    @MainActor
    func parentCancellationReachesGeneration() async throws {
        let generator = ControlledTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: generator)
        let task = Task { await viewModel.generate() }
        try await Self.waitUntil { await generator.startedWidths.contains(80) }
        task.cancel()
        await generator.finish(width: 80)
        await task.value
        #expect(viewModel.textArt == nil)
        #expect(!viewModel.isGenerating)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Width changes publish their trailing value without an editing-end event")
    @MainActor
    func accessibilityWidthChangeCompletes() async throws {
        let generator = OptionAwareTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: generator)
        viewModel.outputWidthBinding.wrappedValue = 40
        viewModel.outputWidthBinding.wrappedValue = 90
        viewModel.outputWidthBinding.wrappedValue = 130
        try await Self.waitUntil { viewModel.textArt?.width == 130 }
        #expect(viewModel.canExportResult)
        #expect(await generator.receivedWidths.last == 130)
    }

    @Test("Stale displayed results cannot be exported under new settings")
    @MainActor
    func exportRequiresCurrentResult() async throws {
        let clipboard = MockClipboardService()
        let export = MockImageExportService()
        let viewModel = Self.makeViewModel(
            generator: CapturingTextArtGenerator(), clipboard: clipboard, export: export
        )
        await viewModel.generate()
        #expect(viewModel.canExportResult)
        viewModel.contrastBoostBinding.wrappedValue = 1.8
        #expect(!viewModel.canExportResult)
        #expect(viewModel.shareText.isEmpty)
        #expect(viewModel.optionSummary.contains("대비 1.0"))
        viewModel.copyToClipboard()
        await viewModel.saveAsImage()
        #expect(clipboard.copiedTexts.isEmpty)
        #expect(await export.saveCallCount == 0)
        viewModel.cancelGeneration()
        #expect(!viewModel.canExportResult)
    }

    @Test("An in-flight save records the exported result and its original options")
    @MainActor
    func saveHistoryUsesCapturedResult() async throws {
        let export = ControlledImageExportService()
        let history = MockHistoryRecorder()
        let viewModel = Self.makeViewModel(
            generator: OptionAwareTextArtGenerator(), export: export, historyRecorder: history
        )
        await viewModel.generate()
        let original = viewModel.textArt
        let save = Task { await viewModel.saveAsImage() }
        try await Self.waitUntil { await export.savedArt != nil }
        viewModel.outputWidth = 120
        viewModel.contrastBoost = 1.8
        viewModel.selectedPreset = .blocks
        await viewModel.generate()
        await export.finish()
        await save.value
        let request = try #require(await history.recordedRequests.first)
        #expect(request.textArt == original)
        #expect(request.outputWidth == 80)
        #expect(request.contrastBoost == 1.0)
        #expect(request.sourceCharacters == "@%#*+=-:. ")
        #expect(viewModel.textArt?.width == 120)
    }

    @Test("Copy captures history before subsequent option edits")
    @MainActor
    func copyHistoryUsesCapturedOptions() async throws {
        let history = MockHistoryRecorder()
        let viewModel = Self.makeViewModel(generator: OptionAwareTextArtGenerator(), historyRecorder: history)
        await viewModel.generate()
        viewModel.copyToClipboard()
        viewModel.contrastBoost = 1.9
        viewModel.outputWidth = 150
        try await Self.waitUntil { await history.recordedRequests.count == 1 }
        let request = try #require(await history.recordedRequests.first)
        #expect(request.outputWidth == 80)
        #expect(request.contrastBoost == 1.0)
        #expect(request.textArt.width == 80)
    }

    @Test("History failure is visible and the same result can be retried")
    @MainActor
    func historyFailureCanBeRetried() async throws {
        let history = RetryHistoryRecorder()
        let viewModel = Self.makeViewModel(generator: CapturingTextArtGenerator(), historyRecorder: history)
        await viewModel.generate()
        await viewModel.saveAsImage()
        #expect(viewModel.showSavedFeedback)
        #expect(viewModel.errorMessage?.contains("최근 작업에 기록하지 못했습니다") == true)
        await viewModel.saveAsImage()
        #expect(await history.attempts == 2)
        #expect(viewModel.errorMessage == nil)
    }
}

actor RecoveringTextArtGenerator: TextArtGenerating {
    private var hasFailed = false
    func generate(from image: CGImage, palette: CharacterPalette, options: ProcessingOptions) async throws -> TextArt {
        if options.outputWidth == 120 && !hasFailed {
            hasFailed = true
            throw TextArtGenerationError.generationFailed("Transient failure")
        }
        return TextArt(rows: [String(options.outputWidth)], width: options.outputWidth,
                       height: 1, sourceCharacters: String(palette.characters), createdAt: Date())
    }
}

extension TextifyViewModelTests {
    @Test("Failed option changes preserve the previous preview and expose a retry for the same options")
    @MainActor
    func failedOptionChangeCanRetry() async throws {
        let viewModel = Self.makeViewModel(generator: RecoveringTextArtGenerator())
        await viewModel.generate()
        viewModel.outputWidth = 120
        await viewModel.generate()
        viewModel.dismissError()
        #expect(viewModel.textArt?.width == 80)
        #expect(!viewModel.canExportResult)
        #expect(viewModel.canRetryGeneration)
        await viewModel.generate()
        #expect(viewModel.textArt?.width == 120)
        #expect(viewModel.canExportResult)
        #expect(!viewModel.canRetryGeneration)
    }
}

extension TextifyViewModelTests {
    @Test("Quick styles apply a coherent option set and generate a usable result", arguments: TextArtStyle.allCases)
    @MainActor
    func quickStylesApplyAndGenerate(style: TextArtStyle) async throws {
        let generator = CapturingTextArtGenerator()
        let viewModel = Self.makeViewModel(generator: generator)
        viewModel.invertBrightness = true
        viewModel.applyStyle(style)
        #expect(viewModel.selectedStyle == style)
        #expect(viewModel.isGenerating)
        try await Self.waitUntil { viewModel.canExportResult }
        #expect(await generator.lastOptions == style.options)
        #expect(await generator.lastPalette?.characters == style.palette.resolvedCharacters(customInput: ""))
        #expect(await generator.generateCallCount == 1)
    }

    @Test("Manual edits clear the style selection and reset restores every generation option")
    @MainActor
    func manualStyleAndReset() async throws {
        let viewModel = Self.makeViewModel(generator: CapturingTextArtGenerator())
        viewModel.applyStyle(.crisp)
        try await Self.waitUntil { viewModel.canExportResult }
        viewModel.contrastBoost = 1.9
        #expect(viewModel.selectedStyle == nil)
        viewModel.selectedPreset = .custom
        viewModel.customCharacters = "ABCD"
        viewModel.outputWidth = 140
        viewModel.invertBrightness = true
        viewModel.resetOptions()
        try await Self.waitUntil { viewModel.canExportResult }
        #expect(viewModel.selectedStyle == .classic)
        #expect(viewModel.outputWidth == 80)
        #expect(viewModel.contrastBoost == 1)
        #expect(!viewModel.invertBrightness)
        #expect(viewModel.customCharacters == "TEXTIFY@#*:.")
    }

    @Test("Result statistics count content including spaces but exclude line separators")
    @MainActor
    func resultStatisticsUseActualContent() async throws {
        let result = TextArt(rows: ["@ ", "░░"], width: 2, height: 2, sourceCharacters: "@░ ", createdAt: Date())
        let viewModel = Self.makeViewModel(generator: CapturingTextArtGenerator(result: result))
        await viewModel.generate()
        #expect(viewModel.resultStatistics == "2자 × 2줄 · 총 4자")
    }
}
