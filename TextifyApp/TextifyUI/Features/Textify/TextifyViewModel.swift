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

    public var textArt: TextArt?
    public var isGenerating = false
    public var isSavingImage = false
    public var errorMessage: String?
    public var copied = false
    public var showSavedFeedback = false
    public var shouldAnimateNextResult = false

    public var selectedPreset: PalettePreset = .standard
    public var customCharacters: String = "TEXTIFY@#*:."
    public var outputWidth: Int = 80
    public var invertBrightness: Bool = false
    public var contrastBoost: Float = 1.0
    public var fontSize: CGFloat = 8

    private let taskManager = GenerationTaskManager()
    private let widthThrottler = Throttler(interval: .milliseconds(50))
    private let finalDebouncer = Debouncer(delay: .milliseconds(200))
    private var generationRequestID = 0
    private var lastPersistedSignature: String?

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
        textArt?.asString ?? ""
    }

    public var hasResult: Bool {
        textArt != nil
    }

    public var optionSummary: String {
        let invertLabel = invertBrightness ? "반전 On" : "반전 Off"
        return "\(selectedPreset.name) · 폭 \(outputWidth) · 대비 \(contrastDisplayText) · \(invertLabel)"
    }

    public var contrastDisplayText: String {
        String(format: "%.1f", contrastBoost)
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
                self.outputWidth = Int(newValue)
                Task {
                    await self.throttledGenerate()
                }
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

    public var fontSizeBinding: Binding<Double> {
        Binding(
            get: { Double(self.fontSize) },
            set: { newValue in
                self.fontSize = CGFloat(newValue)
            }
        )
    }

    public func cancelGeneration() {
        taskManager.cancel()
    }

    public func generateFinal() {
        Task {
            await finalDebouncer.debounce { [weak self] in
                await self?.generate()
            }
        }
    }

    public func generate() async {
        generationRequestID += 1
        let requestID = generationRequestID

        isGenerating = true
        errorMessage = nil

        let characters = resolvedCharacters
        let width = outputWidth
        let invert = invertBrightness
        let contrastBoost = self.contrastBoost
        let image = self.image
        let generator = self.generator
        let logger = self.logger

        let task = taskManager.startGeneration(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let palette = CharacterPalette(characters: characters)
                let options = ProcessingOptions(
                    outputWidth: width,
                    invertBrightness: invert,
                    contrastBoost: contrastBoost
                )

                let result = try await generator.generate(
                    from: image,
                    palette: palette,
                    options: options
                )

                try Task.checkCancellation()

                await MainActor.run {
                    guard requestID == self.generationRequestID else { return }
                    self.textArt = result
                    self.isGenerating = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard requestID == self.generationRequestID else { return }
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    guard requestID == self.generationRequestID else { return }
                    self.errorMessage = "변환에 실패했습니다. 다시 시도해 주세요."
                    self.isGenerating = false
                }
                logger.error("Text art generation failed: \(String(describing: error), privacy: .public)")
            }
        }

        await task.value
    }

    public func generateWithAnimation() async {
        shouldAnimateNextResult = true
        await generate()
    }

    public func copyToClipboard() {
        guard let text = textArt?.asString else { return }

        do {
            try clipboardService.copy(text: text)
            copied = true
            hapticsService.notification(type: .success)
            Task {
                await self.persistHistoryIfNeededIfPossible()
            }
            resetCopiedFeedback()
        } catch {
            errorMessage = "결과를 복사하지 못했습니다."
            hapticsService.notification(type: .error)
            logger.error("Copy to clipboard failed: \(String(describing: error), privacy: .public)")
        }
    }

    public func saveAsImage() async {
        guard let textArt else { return }

        isSavingImage = true
        errorMessage = nil

        do {
            try await exportService.saveToPhotos(textArt: textArt)
            await persistHistoryIfNeededIfPossible()
            showSavedFeedback = true
            hapticsService.notification(type: .success)
            resetSavedFeedback()
        } catch {
            errorMessage = "이미지 저장에 실패했습니다."
            hapticsService.notification(type: .error)
            logger.error("Save image failed: \(String(describing: error), privacy: .public)")
        }

        isSavingImage = false
    }

    public func increaseFontSize() {
        if fontSize < 20 {
            fontSize += 2
        }
    }

    public func decreaseFontSize() {
        if fontSize > 4 {
            fontSize -= 2
        }
    }

    private var resolvedCharacters: [Character] {
        selectedPreset.resolvedCharacters(customInput: customCharacters)
    }

    private func throttledGenerate() async {
        await widthThrottler.throttle { [weak self] in
            await self?.generatePreview()
        }
    }

    private func generatePreview() async {
        let characters = resolvedCharacters
        let width = outputWidth
        let invert = invertBrightness
        let contrastBoost = self.contrastBoost
        let image = self.image
        let generator = self.generator
        let logger = self.logger

        taskManager.startGeneration(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let palette = CharacterPalette(characters: characters)
                let options = ProcessingOptions(
                    outputWidth: width,
                    invertBrightness: invert,
                    contrastBoost: contrastBoost
                )
                let result = try await generator.generate(
                    from: image,
                    palette: palette,
                    options: options
                )
                try Task.checkCancellation()

                await MainActor.run {
                    self.textArt = result
                    self.errorMessage = nil
                }
            } catch is CancellationError {
                // Ignore stale previews.
            } catch {
                logger.error("Preview generation failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    private func persistHistoryIfNeededIfPossible() async {
        guard let textArt else { return }
        await persistHistoryIfNeeded(for: textArt)
    }

    private func persistHistoryIfNeeded(for textArt: TextArt) async {
        let request = makeHistoryRecordRequest(for: textArt)
        let signature = request.deduplicationKey

        guard signature != lastPersistedSignature else { return }
        lastPersistedSignature = signature

        do {
            try await historyRecorder.record(request)
        } catch {
            lastPersistedSignature = nil
            logger.error("History persistence failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func makeHistoryRecordRequest(for textArt: TextArt) -> TextArtHistoryRecordRequest {
        TextArtHistoryRecordRequest(
            sourceImage: image,
            textArt: textArt,
            sourceCharacters: String(resolvedCharacters),
            outputWidth: outputWidth,
            invertBrightness: invertBrightness,
            contrastBoost: contrastBoost
        )
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
}
