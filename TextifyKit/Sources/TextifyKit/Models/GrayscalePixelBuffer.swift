import Foundation

/// A buffer containing grayscale pixel data from a processed image.
/// Each pixel is represented as a UInt8 value (0 = black, 255 = white).
public struct GrayscalePixelBuffer: Sendable, Equatable {
    /// Raw grayscale pixel values in row-major order
    public let pixels: [UInt8]

    /// Width of the image in pixels
    public let width: Int

    /// Height of the image in pixels
    public let height: Int

    /// Creates a new grayscale pixel buffer.
    /// - Parameters:
    ///   - pixels: Array of grayscale values in row-major order
    ///   - width: Width of the image
    ///   - height: Height of the image
    public init(pixels: [UInt8], width: Int, height: Int) {
        self.pixels = pixels
        self.width = width
        self.height = height
    }

    /// Returns the grayscale value at the specified coordinates.
    /// - Parameters:
    ///   - x: X coordinate (column)
    ///   - y: Y coordinate (row)
    /// - Returns: The grayscale value (0-255) or nil if out of bounds
    public func pixel(at x: Int, y: Int) -> UInt8? {
        guard x >= 0, x < width, y >= 0, y < height else {
            return nil
        }
        let index = y * width + x
        guard index < pixels.count else {
            return nil
        }
        return pixels[index]
    }
}
