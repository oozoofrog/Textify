import Foundation
import SwiftUI
import CoreGraphics
import OSLog
import TextifyKit

/// 팔레트 프리셋
public enum PalettePreset: String, CaseIterable, Sendable {
    case standard = "기본"
    case blocks = "블록"
    case minimal = "미니멀"
    case dense = "조밀"
    case dots = "점"
    case numbers = "숫자"
    case custom = "커스텀"

    var name: String { rawValue }

    var preview: String {
        switch self {
        case .standard:
            return "@#*-:."
        case .blocks:
            return "█▓▒░"
        case .minimal:
            return "@. @."
        case .dense:
            return "$@B%8&"
        case .dots:
            return "●◉○◌"
        case .numbers:
            return "012345"
        case .custom:
            return "Aa#?"
        }
    }

    var usesCustomInput: Bool {
        self == .custom
    }

    func resolvedCharacters(customInput: String) -> [Character] {
        switch self {
        case .standard:
            return Array("@%#*+=-:. ")
        case .blocks:
            return Array("█▓▒░ ")
        case .minimal:
            return Array("@. ")
        case .dense:
            return Array("$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. ")
        case .dots:
            return Array("●◉○◌ ")
        case .numbers:
            return Array("0123456789 ")
        case .custom:
            return Self.normalize(customInput)
        }
    }

    static func normalize(_ raw: String) -> [Character] {
        var unique: [Character] = []

        for character in raw where !character.isNewline {
            guard !unique.contains(character) else { continue }
            unique.append(character)
        }

        if unique.isEmpty {
            return Array("@%#*+=-:. ")
        }

        if !unique.contains(" ") {
            unique.append(" ")
        }

        return unique
    }
}

public enum TextifyErrorAction: Sendable, Equatable {
    case openSettings
}

/// 텍스티파이 화면 ViewModel
@Observable
@MainActor
public final class TextifyViewModel {
    public let image: CGImage

    private let generator: any TextArtGenerating
    private let clipboardService: any ClipboardServiceProtocol
    private let exportService: any ImageExportServiceProtocol
    private let historyRecorder: any TextArtHistoryRecording
    private let hapticsService: any HapticsServiceProtocol
    private let feedbackResetDelay: Duration
    private let logger = Logger(subsystem: "com.textify.app", category: "TextifyViewModel")

    public var textArt: TextArt? { completedResult?.request.textArt }
    public private(set) var isGenerating = false
    public private(set) var canRetryGeneration = false
    public var isSavingImage = false
    public var errorMessage: String?
    public var errorAction: TextifyErrorAction?
    public var copied = false
    public var showSavedFeedback = false

    public var selectedPreset: PalettePreset = .standard
    public var customCharacters: String = "TEXTIFY@#*:."
    public var outputWidth: Int = 80
    public var invertBrightness: Bool = false
    public var contrastBoost: Float = 1.0

    private let taskManager = GenerationTaskManager()
    private var generationRequestID = 0
    private var lastPersistedSignature: String?
    private var recordingSignatures: Set<String> = []
    private var completedResult: CompletedResult?

    private struct CompletedResult {
        let request: TextArtHistoryRecordRequest
        let options: ProcessingOptions
        let preset: PalettePreset
    }

    public init(
        image: CGImage,
        generator: any TextArtGenerating,
        clipboardService: any ClipboardServiceProtocol,
        exportService: any ImageExportServiceProtocol,
        historyRecorder: any TextArtHistoryRecording,
        hapticsService: any HapticsServiceProtocol,
        feedbackResetDelay: Duration = .seconds(2)
    ) {
        self.image = image
        self.generator = generator
        self.clipboardService = clipboardService
        self.exportService = exportService
        self.historyRecorder = historyRecorder
        self.hapticsService = hapticsService
        self.feedbackResetDelay = feedbackResetDelay
    }

    public var shareText: String {
        canExportResult ? (textArt?.asString ?? "") : ""
    }

    public var hasResult: Bool {
        textArt != nil
    }

    public var canExportResult: Bool {
        guard let completedResult, !isGenerating else { return false }
        return completedResult.options == currentOptions
            && completedResult.request.sourceCharacters == String(resolvedCharacters)
    }

    public var optionSummary: String {
        guard let completedResult else { return isGenerating ? "생성 중…" : "결과 없음" }
        let options = completedResult.options
        let invertLabel = options.invertBrightness ? "반전 On" : "반전 Off"
        let contrast = String(format: "%.1f", options.contrastBoost)
        return "\(completedResult.preset.name) · 폭 \(options.outputWidth) · 대비 \(contrast) · \(invertLabel)"
    }

    public var contrastDisplayText: String {
        String(format: "%.1f", contrastBoost)
    }

    public var selectedStyle: TextArtStyle? {
        TextArtStyle.allCases.first {
            $0.palette == selectedPreset && $0.options == currentOptions
        }
    }

    public var resultStatistics: String {
        guard let textArt else { return "결과를 준비하고 있어요" }
        let characters = textArt.rows.reduce(0) { $0 + $1.count }
        return "\(textArt.width)자 × \(textArt.height)줄 · 총 \(characters.formatted())자"
    }

    public func applyStyle(_ style: TextArtStyle) {
        selectedPreset = style.palette
        let options = style.options
        outputWidth = options.outputWidth
        invertBrightness = options.invertBrightness
        contrastBoost = options.contrastBoost
        hapticsService.selection()
        startGeneration()
    }

    public func resetOptions() {
        customCharacters = "TEXTIFY@#*:."
        applyStyle(.classic)
    }

    public func selectPreset(_ preset: PalettePreset) {
        selectedPreset = preset
    }

    public func updateCustomCharacters(_ newValue: String) {
        let filtered = newValue.filter { !$0.isNewline }
        customCharacters = String(filtered.prefix(24))
    }

    public var outputWidthBinding: Binding<Double> {
        Binding(
            get: { Double(self.outputWidth) },
            set: { newValue in
                self.handleOutputWidthValueChange(newValue)
            }
        )
    }

    public var invertBrightnessBinding: Binding<Bool> {
        Binding(
            get: { self.invertBrightness },
            set: { newValue in
                self.invertBrightness = newValue
                self.generateFinal()
            }
        )
    }

    public var contrastBoostBinding: Binding<Double> {
        Binding(
            get: { Double(self.contrastBoost) },
            set: { newValue in
                self.contrastBoost = Float(newValue)
                self.generateFinal()
            }
        )
    }

    public var customCharactersBinding: Binding<String> {
        Binding(
            get: { self.customCharacters },
            set: { newValue in
                self.updateCustomCharacters(newValue)
                if self.selectedPreset.usesCustomInput {
                    self.generateFinal()
                }
            }
        )
    }

    public func cancelGeneration() {
        generationRequestID += 1
        taskManager.cancel()
        isGenerating = false
        canRetryGeneration = false
    }

    func handleOutputWidthEditingChanged(_ isEditing: Bool) {
        guard !isEditing else { return }
        startGeneration()
    }

    public func dismissError() {
        errorMessage = nil
        errorAction = nil
    }

    public func generateFinal() {
        startGeneration(delay: .milliseconds(200))
    }

    public func generate() async {
        guard !Task.isCancelled else { return }
        let task = startGeneration()
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }

    @discardableResult
    private func startGeneration(delay: Duration = .zero) -> Task<Void, Never> {
        generationRequestID += 1
        let requestID = generationRequestID
        let options = currentOptions
        let palette = CharacterPalette(characters: resolvedCharacters)
        let preset = selectedPreset
        isGenerating = true
        canRetryGeneration = false
        copied = false
        showSavedFeedback = false
        dismissError()

        return taskManager.startGeneration { [weak self] in
            do {
                // The same owned task covers both the scheduled delay and conversion.
                try await Task.sleep(for: delay)
                try Task.checkCancellation()
                guard let self else { return }
                let result = try await self.generator.generate(
                    from: self.image, palette: palette, options: options
                )
                try Task.checkCancellation()
                guard requestID == self.generationRequestID else { return }
                self.completedResult = CompletedResult(
                    request: TextArtHistoryRecordRequest(
                        sourceImage: self.image,
                        textArt: result,
                        sourceCharacters: String(palette.characters),
                        outputWidth: options.outputWidth,
                        invertBrightness: options.invertBrightness,
                        contrastBoost: options.contrastBoost
                    ),
                    options: options,
                    preset: preset
                )
                self.isGenerating = false
            } catch {
                guard let self, requestID == self.generationRequestID else { return }
                self.isGenerating = false
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self.canRetryGeneration = true
                self.presentError("변환에 실패했습니다. 다시 시도해 주세요.")
                self.logger.error("Text art generation failed: \(String(describing: error), privacy: .private)")
            }
        }
    }

    public func copyToClipboard() {
        guard canExportResult, let request = completedResult?.request else { return }
        let text = request.textArt.asString

        do {
            try clipboardService.copy(text: text)
            copied = true
            hapticsService.notification(type: .success)
            Task {
                await self.persistHistoryIfNeeded(request)
            }
            resetCopiedFeedback()
        } catch {
            presentError("결과를 복사하지 못했습니다.")
            hapticsService.notification(type: .error)
            logger.error("Copy to clipboard failed: \(String(describing: error), privacy: .public)")
        }
    }

    public func saveAsImage() async {
        guard canExportResult, let request = completedResult?.request, !isSavingImage else { return }

        isSavingImage = true
        dismissError()

        do {
            try await exportService.saveToPhotos(textArt: request.textArt)
            await persistHistoryIfNeeded(request)
            showSavedFeedback = true
            hapticsService.notification(type: .success)
            resetSavedFeedback()
        } catch {
            let presentation = makeImageExportPresentation(for: error, context: .save)
            presentError(
                presentation.message,
                action: presentation.suggestsOpeningSettings ? .openSettings : nil
            )
            hapticsService.notification(type: .error)
            logger.error("Save image failed: \(String(describing: error), privacy: .public)")
        }

        isSavingImage = false
    }

    private var resolvedCharacters: [Character] {
        selectedPreset.resolvedCharacters(customInput: customCharacters)
    }

    private var currentOptions: ProcessingOptions {
        ProcessingOptions(
            outputWidth: outputWidth,
            invertBrightness: invertBrightness,
            contrastBoost: contrastBoost
        )
    }

    private func handleOutputWidthValueChange(_ newValue: Double) {
        guard newValue.isFinite else { return }
        outputWidth = Int(min(max(newValue, 10), 500))
        // A trailing update also handles accessibility changes without an editing-end event.
        startGeneration(delay: .milliseconds(50))
    }

    private func persistHistoryIfNeeded(_ request: TextArtHistoryRecordRequest) async {
        let signature = request.deduplicationKey
        guard signature != lastPersistedSignature,
              recordingSignatures.insert(signature).inserted else { return }
        defer { recordingSignatures.remove(signature) }

        do {
            try await historyRecorder.record(request)
            lastPersistedSignature = signature
        } catch {
            presentError("결과는 내보냈지만 최근 작업에 기록하지 못했습니다. 복사 또는 저장을 다시 하면 기록을 재시도합니다.")
            logger.error("History persistence failed: \(String(describing: error), privacy: .private)")
        }
    }

    private func resetCopiedFeedback() {
        Task {
            try? await Task.sleep(for: feedbackResetDelay)
            await MainActor.run {
                self.copied = false
            }
        }
    }

    private func resetSavedFeedback() {
        Task {
            try? await Task.sleep(for: feedbackResetDelay)
            await MainActor.run {
                self.showSavedFeedback = false
            }
        }
    }

    private func presentError(_ message: String, action: TextifyErrorAction? = nil) {
        errorMessage = message
        errorAction = action
    }

}
