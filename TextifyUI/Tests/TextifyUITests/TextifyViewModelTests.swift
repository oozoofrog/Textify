import Testing
import CoreGraphics
import UIKit
@testable import TextifyUI
@testable import TextifyKit

// MARK: - Mock Generator for testing

/// Actor-based mock implementation of TextArtGenerating for testing
actor MockTextArtGenerator: TextArtGenerating {
    private(set) var generateCallCount = 0
    private(set) var lastGenerateTime: ContinuousClock.Instant?

    func generate(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt {
        generateCallCount += 1
        lastGenerateTime = ContinuousClock.now

        // Simulate some processing time
        try await Task.sleep(for: .milliseconds(50))

        return TextArt(
            rows: ["@#", "*+"],  // [String] not [[String]]
            width: 2,
            height: 2,
            sourceCharacters: String(palette.characters),
            createdAt: Date()
        )
    }

    func reset() {
        generateCallCount = 0
        lastGenerateTime = nil
    }
}

// MARK: - Test Helpers

extension TextifyViewModelTests {
    /// Creates a simple test image
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
        return context.makeImage()!
    }
}

// MARK: - ViewModel Tests

@Suite("TextifyViewModel Performance Tests")
struct TextifyViewModelTests {

    @Test("generateFinal uses debouncing - rapid calls result in single generation")
    @MainActor
    func testGenerateFinalIsDebounced() async throws {
        let mockGenerator = MockTextArtGenerator()
        let image = Self.createTestImage()
        let viewModel = TextifyViewModel(image: image, generator: mockGenerator)

        // Call generateFinal rapidly 3 times
        viewModel.generateFinal()
        viewModel.generateFinal()
        viewModel.generateFinal()

        // Wait for debounce delay (200ms) + buffer
        try await Task.sleep(for: .milliseconds(350))

        // Should only have called generate once due to debouncing
        #expect(await mockGenerator.generateCallCount == 1)
    }

    @Test("Previous generation cancelled on new request")
    @MainActor
    func testPreviousGenerationCancelled() async throws {
        let mockGenerator = MockTextArtGenerator()
        let image = Self.createTestImage()
        let viewModel = TextifyViewModel(image: image, generator: mockGenerator)

        // Start first generation
        let task1 = Task {
            await viewModel.generate()
        }

        // Give it a moment to start
        try await Task.sleep(for: .milliseconds(10))

        // Start second generation (should cancel first)
        let task2 = Task {
            await viewModel.generate()
        }

        // Wait for both to complete
        await task1.value
        await task2.value

        // Second generation should have completed
        // At least 2 calls should have been initiated
        #expect(await mockGenerator.generateCallCount >= 2)
        #expect(viewModel.textArt != nil)
    }

    @Test("Generate sets isGenerating flag correctly")
    @MainActor
    func testGenerateSetsIsGeneratingFlag() async throws {
        let mockGenerator = MockTextArtGenerator()
        let image = Self.createTestImage()
        let viewModel = TextifyViewModel(image: image, generator: mockGenerator)

        #expect(viewModel.isGenerating == false)

        let task = Task {
            await viewModel.generate()
        }

        // Should be generating while task runs
        try await Task.sleep(for: .milliseconds(10))
        #expect(viewModel.isGenerating == true)

        // Wait for completion
        await task.value

        // Should be done
        #expect(viewModel.isGenerating == false)
        #expect(viewModel.textArt != nil)
    }

    @Test("Error during generation sets error message")
    @MainActor
    func testErrorDuringGenerationSetsErrorMessage() async throws {
        // Create a generator that throws an error
        let errorGenerator = ErrorThrowingGenerator()
        let image = Self.createTestImage()
        let viewModel = TextifyViewModel(image: image, generator: errorGenerator)

        await viewModel.generate()

        #expect(viewModel.textArt == nil)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.isGenerating == false)
    }
}

// MARK: - Error Generator for Testing

actor ErrorThrowingGenerator: TextArtGenerating {
    func generate(
        from image: CGImage,
        palette: CharacterPalette,
        options: ProcessingOptions
    ) async throws -> TextArt {
        throw TextArtGenerationError.generationFailed("Test error")
    }
}

// MARK: - PaletteButton Tests

/// Data model for PaletteButton state (to be implemented)
struct PaletteButtonData: Equatable {
    let preset: PalettePreset
    let isSelected: Bool
}

@Suite("PaletteButton Tests")
struct PaletteButtonTests {

    @Test("PaletteButton with same preset and isSelected are equal")
    func testPaletteButtonEquatable() {
        let button1 = PaletteButtonData(preset: .standard, isSelected: true)
        let button2 = PaletteButtonData(preset: .standard, isSelected: true)

        #expect(button1 == button2)
    }

    @Test("PaletteButton with different isSelected are not equal")
    func testPaletteButtonNotEqualDifferentSelected() {
        let button1 = PaletteButtonData(preset: .standard, isSelected: true)
        let button2 = PaletteButtonData(preset: .standard, isSelected: false)

        #expect(button1 != button2)
    }

    @Test("PaletteButton with different preset are not equal")
    func testPaletteButtonNotEqualDifferentPreset() {
        let button1 = PaletteButtonData(preset: .standard, isSelected: true)
        let button2 = PaletteButtonData(preset: .blocks, isSelected: true)

        #expect(button1 != button2)
    }
}
