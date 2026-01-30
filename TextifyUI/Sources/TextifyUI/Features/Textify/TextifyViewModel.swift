import Foundation
import SwiftUI
import CoreGraphics
import TextifyKit

/// 팔레트 프리셋
public enum PalettePreset: String, CaseIterable, Sendable {
    case standard = "기본"
    case blocks = "블록"
    case minimal = "미니멀"
    case dense = "조밀"
    case dots = "점"
    case custom = "숫자"

    var name: String { rawValue }

    var characters: [Character] {
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
        case .custom:
            return Array("0123456789 ")
        }
    }

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
        case .custom:
            return "012345"
        }
    }
}

/// 텍스티파이 화면 ViewModel
@Observable
@MainActor
public final class TextifyViewModel {
    // Input
    public let image: CGImage
    let generator: any TextArtGenerating

    // State
    public var textArt: TextArt?
    public var isGenerating = false
    public var errorMessage: String?
    public var copied = false

    // Options
    public var selectedPreset: PalettePreset = .standard
    public var outputWidth: Int = 80
    public var invertBrightness: Bool = false
    public var fontSize: CGFloat = 8

    // Preview coordination
    private let taskManager = GenerationTaskManager()
    private let widthThrottler = Throttler(interval: .milliseconds(50))
    private let finalDebouncer = Debouncer(delay: .milliseconds(200))

    public init(image: CGImage, generator: any TextArtGenerating) {
        self.image = image
        self.generator = generator
    }

    public func selectPreset(_ preset: PalettePreset) {
        selectedPreset = preset
    }

    public var outputWidthBinding: Binding<Double> {
        Binding(
            get: { Double(self.outputWidth) },
            set: { newValue in
                self.outputWidth = Int(newValue)
                Task { await self.throttledGenerate() }
            }
        )
    }

    private func throttledGenerate() async {
        await widthThrottler.throttle { [weak self] in
            await self?.generatePreview()
        }
    }

    private func generatePreview() async {
        let characters = selectedPreset.characters
        let width = outputWidth
        let invert = invertBrightness

        await taskManager.startGeneration(priority: .utility) { [weak self] in
            guard let self else { return }
            do {
                let palette = CharacterPalette(characters: characters)
                let options = ProcessingOptions(
                    outputWidth: width,
                    invertBrightness: invert,
                    contrastBoost: 1.0
                )
                let result = try await self.generator.generate(
                    from: self.image,
                    palette: palette,
                    options: options
                )
                await MainActor.run {
                    self.textArt = result
                }
            } catch is CancellationError {
                // Cancelled, ignore
            } catch {
                // Preview failed, ignore - final will retry
            }
        }
    }

    public func generateFinal() {
        Task {
            await finalDebouncer.debounce { [weak self] in
                await self?.generate()
            }
        }
    }

    public func generate() async {
        isGenerating = true
        errorMessage = nil

        let characters = selectedPreset.characters
        let width = outputWidth
        let invert = invertBrightness

        await taskManager.startGeneration(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                let palette = CharacterPalette(characters: characters)
                let options = ProcessingOptions(
                    outputWidth: width,
                    invertBrightness: invert,
                    contrastBoost: 1.0
                )

                let result = try await self.generator.generate(
                    from: self.image,
                    palette: palette,
                    options: options
                )

                await MainActor.run {
                    self.textArt = result
                    self.isGenerating = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isGenerating = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "변환 실패: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
    }

    public func copyToClipboard() {
        guard let text = textArt?.asString else { return }
        UIPasteboard.general.string = text

        copied = true

        // 2초 후 복사 상태 리셋
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
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
}
