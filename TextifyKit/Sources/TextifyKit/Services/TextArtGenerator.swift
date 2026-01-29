import Foundation
import CoreGraphics

/// Actor that generates text art from images.
/// Coordinates image processing and character mapping.
public actor TextArtGenerator: TextArtGenerating {
    
    private let imageProcessor: any ImageProcessing
    private let characterMapper: CharacterMapper
    
    /// Creates a new TextArtGenerator with default dependencies.
    public init() {
        self.imageProcessor = ImageProcessor()
        self.characterMapper = CharacterMapper()
    }
    
    /// Creates a new TextArtGenerator with custom dependencies.
    /// - Parameters:
    ///   - imageProcessor: Image processor to use
    ///   - characterMapper: Character mapper to use
    public init(
        imageProcessor: any ImageProcessing,
        characterMapper: CharacterMapper = CharacterMapper()
    ) {
        self.imageProcessor = imageProcessor
        self.characterMapper = characterMapper
    }
    
    /// Generates text art from an image using the specified character palette.
    public func generate(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt {
        // Validate palette
        guard !palette.characters.isEmpty else {
            throw TextArtGenerationError.invalidPalette
        }
        
        // Process image to grayscale pixels
        let pixelBuffer: GrayscalePixelBuffer
        do {
            pixelBuffer = try await imageProcessor.grayscalePixels(
                from: image,
                scaledToWidth: options.outputWidth,
                aspectCorrection: options.aspectRatioCorrection
            )
        } catch let error as ImageProcessingError {
            throw TextArtGenerationError.imageProcessingFailed(error)
        } catch {
            throw TextArtGenerationError.generationFailed(error.localizedDescription)
        }
        
        // Map pixels to characters
        let rows = characterMapper.mapToCharacters(
            pixels: pixelBuffer,
            palette: palette,
            options: options
        )
        
        // Build source characters string
        let sourceChars = String(palette.characters)
        
        return TextArt(
            rows: rows,
            width: pixelBuffer.width,
            height: pixelBuffer.height,
            sourceCharacters: sourceChars,
            createdAt: Date()
        )
    }
}
