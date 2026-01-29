import Foundation
import CoreGraphics
@testable import TextifyKit

/// Mock implementation of ImageProcessing for testing.
/// Allows configuring return values and tracking method calls.
final class MockImageProcessor: ImageProcessing, @unchecked Sendable {
    // MARK: - Call Tracking

    private(set) var grayscalePixelsCallCount = 0
    private(set) var lastWidth: Int?
    private(set) var lastAspectCorrection: Float?

    // MARK: - Stubbed Returns

    var stubbedResult: GrayscalePixelBuffer?
    var stubbedError: ImageProcessingError?

    // MARK: - ImageProcessing

    func grayscalePixels(
        from image: CGImage,
        scaledToWidth width: Int,
        aspectCorrection: Float
    ) async throws -> GrayscalePixelBuffer {
        grayscalePixelsCallCount += 1
        lastWidth = width
        lastAspectCorrection = aspectCorrection

        if let error = stubbedError {
            throw error
        }

        if let result = stubbedResult {
            return result
        }

        // Default: return a simple buffer based on width
        let height = Int(Float(width) * aspectCorrection)
        let pixels = [UInt8](repeating: 128, count: width * height)
        return GrayscalePixelBuffer(pixels: pixels, width: width, height: height)
    }

    // MARK: - Test Helpers

    func reset() {
        grayscalePixelsCallCount = 0
        lastWidth = nil
        lastAspectCorrection = nil
        stubbedResult = nil
        stubbedError = nil
    }
}
