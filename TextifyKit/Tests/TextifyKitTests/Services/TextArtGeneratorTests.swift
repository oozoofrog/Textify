import Testing
import Foundation
import CoreGraphics
@testable import TextifyKit

@Suite("TextArtGenerator Tests")
struct TextArtGeneratorTests {
    
    // Helper to create a test CGImage
    func createTestImage(width: Int, height: Int, grayscaleValue: UInt8) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        var pixels = [UInt8](repeating: grayscaleValue, count: width * height)
        
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return nil
        }
        
        return context.makeImage()
    }
    
    @Test("Generates text art with correct dimensions")
    func testGeneratesWithDimensions() async throws {
        let mockProcessor = MockImageProcessor()
        let testBuffer = GrayscalePixelBuffer(
            pixels: [UInt8](repeating: 128, count: 40 * 20),
            width: 40,
            height: 20
        )
        mockProcessor.stubbedResult = testBuffer
        
        let generator = TextArtGenerator(imageProcessor: mockProcessor)
        
        guard let image = createTestImage(width: 100, height: 100, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }
        
        let options = ProcessingOptions(outputWidth: 40)
        let palette = CharacterPalette.standard
        
        let result = try await generator.generate(from: image, palette: palette, options: options)
        
        #expect(result.width == 40)
        #expect(result.height == 20)
        #expect(result.rows.count == 20)
        #expect(result.rows.first?.count == 40)
    }
    
    @Test("Uses provided palette")
    func testUsesPalette() async throws {
        let mockProcessor = MockImageProcessor()
        // Black pixel -> should use darkest character
        let testBuffer = GrayscalePixelBuffer(pixels: [0], width: 1, height: 1)
        mockProcessor.stubbedResult = testBuffer
        
        let generator = TextArtGenerator(imageProcessor: mockProcessor)
        
        guard let image = createTestImage(width: 10, height: 10, grayscaleValue: 0) else {
            Issue.record("Failed to create test image")
            return
        }
        
        let palette = CharacterPalette.custom("XYZ")  // X is darkest
        let options = ProcessingOptions(outputWidth: 1)
        
        let result = try await generator.generate(from: image, palette: palette, options: options)
        
        #expect(result.rows[0] == "X")
        #expect(result.sourceCharacters == "XYZ")
    }
    
    @Test("Passes options to processor")
    func testPassesOptions() async throws {
        let mockProcessor = MockImageProcessor()
        let generator = TextArtGenerator(imageProcessor: mockProcessor)
        
        guard let image = createTestImage(width: 100, height: 100, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }
        
        let options = ProcessingOptions(outputWidth: 60, aspectRatioCorrection: 0.4)
        let palette = CharacterPalette.standard
        
        _ = try await generator.generate(from: image, palette: palette, options: options)
        
        #expect(mockProcessor.lastWidth == 60)
        #expect(mockProcessor.lastAspectCorrection == 0.4)
    }
    
    @Test("Propagates processor errors")
    func testPropagatesErrors() async throws {
        let mockProcessor = MockImageProcessor()
        mockProcessor.stubbedError = .invalidImage
        
        let generator = TextArtGenerator(imageProcessor: mockProcessor)
        
        guard let image = createTestImage(width: 10, height: 10, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }
        
        let options = ProcessingOptions()
        let palette = CharacterPalette.standard
        
        await #expect(throws: TextArtGenerationError.self) {
            try await generator.generate(from: image, palette: palette, options: options)
        }
    }
    
    @Test("Records creation timestamp")
    func testRecordsTimestamp() async throws {
        let mockProcessor = MockImageProcessor()
        let generator = TextArtGenerator(imageProcessor: mockProcessor)
        
        guard let image = createTestImage(width: 10, height: 10, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }
        
        let beforeGeneration = Date()
        let result = try await generator.generate(
            from: image,
            palette: CharacterPalette.standard,
            options: ProcessingOptions()
        )
        let afterGeneration = Date()
        
        #expect(result.createdAt >= beforeGeneration)
        #expect(result.createdAt <= afterGeneration)
    }
    
    @Test("Thread safety with concurrent generation")
    func testConcurrentGeneration() async throws {
        let processor = ImageProcessor()
        let generator = TextArtGenerator(imageProcessor: processor)
        
        guard let image = createTestImage(width: 50, height: 50, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }
        
        let palette = CharacterPalette.standard
        
        async let result1 = generator.generate(from: image, palette: palette, options: ProcessingOptions(outputWidth: 20))
        async let result2 = generator.generate(from: image, palette: palette, options: ProcessingOptions(outputWidth: 30))
        
        let results = try await [result1, result2]
        
        #expect(results[0].width == 20)
        #expect(results[1].width == 30)
    }
}
