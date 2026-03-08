import Testing
@testable import TextifyKit

@Suite("GrayscalePixelBuffer Tests")
struct GrayscalePixelBufferTests {

    @Test("Initialization stores correct dimensions")
    func testInitialization() {
        let pixels: [UInt8] = [0, 128, 255, 64]
        let buffer = GrayscalePixelBuffer(pixels: pixels, width: 2, height: 2)

        #expect(buffer.width == 2)
        #expect(buffer.height == 2)
        #expect(buffer.pixels.count == 4)
    }

    @Test("Pixel access returns correct values")
    func testPixelAccess() {
        let pixels: [UInt8] = [0, 50, 100, 150, 200, 250]
        let buffer = GrayscalePixelBuffer(pixels: pixels, width: 3, height: 2)

        #expect(buffer.pixel(at: 0, y: 0) == 0)
        #expect(buffer.pixel(at: 2, y: 0) == 100)
        #expect(buffer.pixel(at: 0, y: 1) == 150)
        #expect(buffer.pixel(at: 2, y: 1) == 250)
    }

    @Test("Out of bounds returns nil")
    func testOutOfBounds() {
        let buffer = GrayscalePixelBuffer(pixels: [0, 1, 2, 3], width: 2, height: 2)

        #expect(buffer.pixel(at: 5, y: 0) == nil)
        #expect(buffer.pixel(at: 0, y: 5) == nil)
        #expect(buffer.pixel(at: -1, y: 0) == nil)
    }

    @Test("Empty buffer has zero dimensions")
    func testEmptyBuffer() {
        let buffer = GrayscalePixelBuffer(pixels: [], width: 0, height: 0)

        #expect(buffer.width == 0)
        #expect(buffer.height == 0)
        #expect(buffer.pixels.isEmpty)
    }

    @Test("Sendable conformance")
    func testSendable() async {
        let buffer = GrayscalePixelBuffer(pixels: [1, 2, 3, 4], width: 2, height: 2)

        let task = Task {
            buffer.width
        }
        let result = await task.value
        #expect(result == 2)
    }

    @Test("Equatable conformance")
    func testEquatable() {
        let buffer1 = GrayscalePixelBuffer(pixels: [1, 2, 3, 4], width: 2, height: 2)
        let buffer2 = GrayscalePixelBuffer(pixels: [1, 2, 3, 4], width: 2, height: 2)
        let buffer3 = GrayscalePixelBuffer(pixels: [1, 2, 3, 5], width: 2, height: 2)

        #expect(buffer1 == buffer2)
        #expect(buffer1 != buffer3)
    }
}
