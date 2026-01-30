import Foundation
import CoreGraphics

/// Actor that generates text art from images.
/// Coordinates image processing and character mapping.
public actor TextArtGenerator: TextArtGenerating {

    private let imageProcessor: any ImageProcessing
    private let characterMapper: CharacterMapper

    // Caching properties
    private var cachedBuffer: GrayscalePixelBuffer?
    private var cachedSourceImageRef: ObjectIdentifier?
    private var cachedMaxWidth: Int = 0
    
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

        // Check for cancellation after expensive image processing
        try Task.checkCancellation()
        
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

    /// Prepares the cache by processing the image at maximum width.
    /// This warms the cache for subsequent width changes.
    /// - Parameters:
    ///   - image: Source image to cache
    ///   - maxWidth: Maximum output width to cache
    ///   - aspectCorrection: Aspect ratio correction factor
    public func prepareCache(
        for image: CGImage,
        maxWidth: Int,
        aspectCorrection: Float
    ) async throws {
        let imageRef = ObjectIdentifier(image as AnyObject)

        // Process image at maximum width
        let pixelBuffer = try await imageProcessor.grayscalePixels(
            from: image,
            scaledToWidth: maxWidth,
            aspectCorrection: aspectCorrection
        )

        // Check for cancellation after expensive operation
        try Task.checkCancellation()

        // Store in cache
        cachedBuffer = pixelBuffer
        cachedSourceImageRef = imageRef
        cachedMaxWidth = maxWidth
    }

    /// Generates text art using cached pixel buffer when possible.
    /// Falls back to full generation if cache is invalid.
    /// - Parameters:
    ///   - image: Source image
    ///   - palette: Character palette to use
    ///   - options: Processing options
    /// - Returns: Generated text art
    public func generateWithCache(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt {
        let imageRef = ObjectIdentifier(image as AnyObject)

        // Check if we can use cached buffer
        let pixelBuffer: GrayscalePixelBuffer
        if let cached = cachedBuffer,
           cachedSourceImageRef == imageRef,
           options.outputWidth <= cachedMaxWidth,
           options.aspectRatioCorrection == 1.0 { // Only reuse if aspect correction matches

            // Reuse cached buffer (downsampling if needed)
            if options.outputWidth == cached.width {
                pixelBuffer = cached
            } else {
                // Downsample cached buffer to requested width
                pixelBuffer = try await imageProcessor.grayscalePixels(
                    from: image,
                    scaledToWidth: options.outputWidth,
                    aspectCorrection: options.aspectRatioCorrection
                )
            }
        } else {
            // Cache miss - fall back to full generation
            return try await generate(from: image, palette: palette, options: options)
        }

        // Check for cancellation
        try Task.checkCancellation()

        // Validate palette
        guard !palette.characters.isEmpty else {
            throw TextArtGenerationError.invalidPalette
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

    /// Invalidates the cached pixel buffer.
    /// Call this when switching to a different image.
    public func invalidateCache() {
        cachedBuffer = nil
        cachedSourceImageRef = nil
        cachedMaxWidth = 0
    }
}
