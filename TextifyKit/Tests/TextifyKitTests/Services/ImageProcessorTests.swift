import Testing
import CoreGraphics
@testable import TextifyKit

@Suite("ImageProcessor Tests")
struct ImageProcessorTests {

    let processor = ImageProcessor()

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

    @Test("Processes image to correct dimensions")
    func testProcessToDimensions() async throws {
        guard let image = createTestImage(width: 100, height: 100, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }

        let buffer = try await processor.grayscalePixels(
            from: image,
            scaledToWidth: 50,
            aspectCorrection: 0.5
        )

        #expect(buffer.width == 50)
        #expect(buffer.height == 25)  // 50 * 0.5 aspect
    }

    @Test("Returns grayscale values")
    func testGrayscaleValues() async throws {
        guard let image = createTestImage(width: 10, height: 10, grayscaleValue: 200) else {
            Issue.record("Failed to create test image")
            return
        }

        let buffer = try await processor.grayscalePixels(
            from: image,
            scaledToWidth: 10,
            aspectCorrection: 1.0
        )

        // All pixels should be close to 200 (may vary due to scaling)
        let avgValue = buffer.pixels.reduce(0, { $0 + Int($1) }) / buffer.pixels.count
        #expect(avgValue > 150)
        #expect(avgValue < 250)
    }

    @Test("Handles small output width")
    func testSmallOutputWidth() async throws {
        guard let image = createTestImage(width: 100, height: 100, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }

        let buffer = try await processor.grayscalePixels(
            from: image,
            scaledToWidth: 10,
            aspectCorrection: 0.5
        )

        #expect(buffer.width == 10)
        #expect(buffer.height == 5)
    }

    @Test("Handles non-square images")
    func testNonSquareImage() async throws {
        guard let image = createTestImage(width: 200, height: 100, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }

        let buffer = try await processor.grayscalePixels(
            from: image,
            scaledToWidth: 80,
            aspectCorrection: 0.5
        )

        #expect(buffer.width == 80)
        // Height should be (100/200) * 80 * 0.5 = 20
        #expect(buffer.height == 20)
    }

    @Test("Actor provides thread safety")
    func testConcurrentAccess() async throws {
        guard let image = createTestImage(width: 50, height: 50, grayscaleValue: 128) else {
            Issue.record("Failed to create test image")
            return
        }

        // Run multiple concurrent processing tasks
        async let buffer1 = processor.grayscalePixels(from: image, scaledToWidth: 20, aspectCorrection: 0.5)
        async let buffer2 = processor.grayscalePixels(from: image, scaledToWidth: 30, aspectCorrection: 0.5)
        async let buffer3 = processor.grayscalePixels(from: image, scaledToWidth: 25, aspectCorrection: 0.5)

        let results = try await [buffer1, buffer2, buffer3]

        #expect(results[0].width == 20)
        #expect(results[1].width == 30)
        #expect(results[2].width == 25)
    }
}
