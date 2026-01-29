import Foundation
import SwiftUI
import CoreGraphics
import TextifyKit

/// ViewModel for the generation screen
@Observable
@MainActor
final class GenerationViewModel {
    private let generator: TextArtGenerator

    var isGenerating = false
    var progress: Double = 0.0
    var errorMessage: String?
    var generatedTextArt: TextArt?

    // Generation options
    var outputWidth: Int = 80
    var invertBrightness: Bool = false
    var contrastBoost: Float = 1.0

    init(generator: TextArtGenerator) {
        self.generator = generator
    }

    func generate(from image: CGImage, characters: String) async {
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

    func reset() {
        isGenerating = false
        progress = 0.0
        errorMessage = nil
        generatedTextArt = nil
    }
}
