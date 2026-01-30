import Foundation
import SwiftUI
import CoreGraphics
import TextifyKit

/// ViewModel for the generation screen
@Observable
@MainActor
public final class GenerationViewModel {
    private let generator: TextArtGenerator

    public var isGenerating = false
    public var progress: Double = 0.0
    public var errorMessage: String?
    public var generatedTextArt: TextArt?

    // Generation options
    public var outputWidth: Int = 80
    public var invertBrightness: Bool = false
    public var contrastBoost: Float = 1.0

    public init(generator: TextArtGenerator) {
        self.generator = generator
    }

    public func generate(from image: CGImage, characters: String) async {
        isGenerating = true
        progress = 0.0
        errorMessage = nil
        generatedTextArt = nil

        // Simulate progress updates
        progress = 0.2

        do {
            let palette = CharacterPalette(characters: Array(characters))
            let options = ProcessingOptions(
                outputWidth: outputWidth,
                invertBrightness: invertBrightness,
                contrastBoost: contrastBoost
            )

            progress = 0.5

            let textArt = try await generator.generate(
                from: image,
                palette: palette,
                options: options
            )

            progress = 1.0
            generatedTextArt = textArt

        } catch {
            errorMessage = "Generation failed: \(error.localizedDescription)"
        }

        isGenerating = false
    }

    public func reset() {
        isGenerating = false
        progress = 0.0
        errorMessage = nil
        generatedTextArt = nil
    }
}
