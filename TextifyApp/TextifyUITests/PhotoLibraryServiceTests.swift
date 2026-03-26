import Testing
import Foundation
import CoreGraphics
import UIKit
import ImageIO
@testable import TextifyUI

@Suite("PhotoLibraryService Orientation Tests")
struct PhotoLibraryServiceTests {

    private let service = PhotoLibraryService()

    /// Creates JPEG data with an explicit EXIF orientation tag using ImageIO.
    /// The raw pixel buffer has the given width×height; the EXIF tag tells
    /// decoders how to rotate the pixels for correct display.
    private static func createJPEGData(
        pixelWidth: Int,
        pixelHeight: Int,
        exifOrientation: UInt32
    ) -> Data? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setFillColor(UIColor.red.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

        guard let cgImage = context.makeImage() else { return nil }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.jpeg" as CFString,
            1,
            nil
        ) else { return nil }

        let properties: [CFString: Any] = [
            kCGImagePropertyOrientation: exifOrientation
        ]
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)

        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    // MARK: - Orientation .up (EXIF 1)

    @Test("Orientation .up — dimensions unchanged, fast path")
    func testOrientationUp() throws {
        // EXIF orientation 1 = .up (no rotation)
        let data = try #require(Self.createJPEGData(pixelWidth: 20, pixelHeight: 10, exifOrientation: 1))
        let result = try service.createOrientationNormalizedCGImage(from: data)
        #expect(result.width == 20)
        #expect(result.height == 10)
    }

    // MARK: - Orientation .right (EXIF 6, iPhone portrait)

    @Test("Orientation .right (iPhone portrait) — width and height swapped")
    func testOrientationRight() throws {
        // EXIF orientation 6 = .right (90° CW)
        // Raw pixels: 20×10 → Display: 10×20
        let data = try #require(Self.createJPEGData(pixelWidth: 20, pixelHeight: 10, exifOrientation: 6))
        let result = try service.createOrientationNormalizedCGImage(from: data)
        #expect(result.width == 10)
        #expect(result.height == 20)
    }

    // MARK: - Orientation .left (EXIF 8)

    @Test("Orientation .left — width and height swapped")
    func testOrientationLeft() throws {
        // EXIF orientation 8 = .left (90° CCW)
        // Raw pixels: 20×10 → Display: 10×20
        let data = try #require(Self.createJPEGData(pixelWidth: 20, pixelHeight: 10, exifOrientation: 8))
        let result = try service.createOrientationNormalizedCGImage(from: data)
        #expect(result.width == 10)
        #expect(result.height == 20)
    }

    // MARK: - Invalid data

    @Test("Invalid data throws cgImageCreationFailed")
    func testInvalidData() throws {
        let invalidData = Data([0x00, 0x01, 0x02, 0x03])
        #expect(throws: PhotoLibraryError.cgImageCreationFailed) {
            try service.createOrientationNormalizedCGImage(from: invalidData)
        }
    }

    // MARK: - PNG (no EXIF orientation)

    @Test("PNG data without EXIF orientation — normal operation")
    func testPNGData() throws {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = try #require(CGContext(
            data: nil,
            width: 15,
            height: 25,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(UIColor.blue.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 15, height: 25))

        let cgImage = try #require(context.makeImage())
        let uiImage = UIImage(cgImage: cgImage)
        let pngData = try #require(uiImage.pngData())

        let result = try service.createOrientationNormalizedCGImage(from: pngData)
        #expect(result.width == 15)
        #expect(result.height == 25)
    }
}
