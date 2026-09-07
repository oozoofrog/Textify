import Testing
import Foundation
import CoreGraphics
import UIKit
import ImageIO
import TextifyKit
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
        exifOrientation: UInt32,
        patterned: Bool = false
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
        if patterned {
            let halfWidth = pixelWidth / 2
            let halfHeight = pixelHeight / 2
            for (index, level) in [0.1, 0.35, 0.65, 0.9].enumerated() {
                context.setFillColor(UIColor(white: level, alpha: 1).cgColor)
                context.fill(CGRect(
                    x: index % 2 * halfWidth,
                    y: index / 2 * halfHeight,
                    width: halfWidth,
                    height: halfHeight
                ))
            }
        }

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

    @Test("Orientation .up — small image dimensions unchanged")
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

    @Test("All EXIF rotations and mirrors transform image content", arguments: UInt32(1)...8)
    func testOrientationPixels(orientation: UInt32) throws {
        let baselineData = try #require(Self.createJPEGData(
            pixelWidth: 80, pixelHeight: 40, exifOrientation: 1, patterned: true
        ))
        let baseline = try quadrantBrightness(service.createOrientationNormalizedCGImage(from: baselineData))
        let data = try #require(Self.createJPEGData(
            pixelWidth: 80, pixelHeight: 40, exifOrientation: orientation, patterned: true
        ))
        let image = try service.createOrientationNormalizedCGImage(from: data)
        let actual = try quadrantBrightness(image)
        let expectedIndices = [
            [0, 1, 2, 3], [1, 0, 3, 2], [3, 2, 1, 0], [2, 3, 0, 1],
            [0, 2, 1, 3], [2, 0, 3, 1], [3, 1, 2, 0], [1, 3, 0, 2]
        ][Int(orientation) - 1]

        #expect(image.width == (orientation >= 5 ? 40 : 80))
        #expect(image.height == (orientation >= 5 ? 80 : 40))
        for index in 0..<4 {
            #expect(abs(actual[index] - baseline[expectedIndices[index]]) <= 3)
        }
    }

    @Test("Large photos are bounded and remain convertible", arguments: [UInt32(1), UInt32(6)])
    func testLargePhotoConversion(orientation: UInt32) async throws {
        let data = try #require(Self.createJPEGData(
            pixelWidth: 5000, pixelHeight: 1000, exifOrientation: orientation
        ))
        let image = try service.createOrientationNormalizedCGImage(from: data)

        #expect(max(image.width, image.height) == 4096)
        #expect(abs(Double(min(image.width, image.height)) - 4096.0 / 5) <= 1)
        #expect(orientation == 1 ? image.width > image.height : image.height > image.width)

        let result = try await TextArtGenerator().generate(
            from: image, palette: .standard, options: ProcessingOptions()
        )
        #expect(result.width == 80)
        #expect(!result.rows.isEmpty)
    }

    @Test("Photos at the decoder limit keep their size")
    func testImageAtMaximumDimension() throws {
        let data = try #require(Self.createJPEGData(
            pixelWidth: 4096, pixelHeight: 64, exifOrientation: 1
        ))
        let image = try service.createOrientationNormalizedCGImage(from: data)
        #expect(image.width == 4096)
        #expect(image.height == 64)
    }

    private func quadrantBrightness(_ image: CGImage) throws -> [Int] {
        try (0..<4).map { index in
            let sample = try #require(image.cropping(to: CGRect(
                x: (index % 2 * 2 + 1) * image.width / 4,
                y: (index / 2 * 2 + 1) * image.height / 4,
                width: 1,
                height: 1
            )))
            var pixel: UInt8 = 0
            try withUnsafeMutablePointer(to: &pixel) { pointer in
                let context = try #require(CGContext(
                    data: pointer, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 1,
                    space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue
                ))
                context.draw(sample, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            return Int(pixel)
        }
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

    @Test("A JPEG file is oriented and bounded before conversion")
    func testJPEGFile() async throws {
        let data = try #require(Self.createJPEGData(
            pixelWidth: 5000, pixelHeight: 1000, exifOrientation: 6
        ))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).jpg")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let image = try await service.loadImage(fromFile: url)
        #expect(image.height == 4096)
        #expect(abs(Double(image.width) - 4096.0 / 5) <= 1)
        let result = try await TextArtGenerator().generate(
            from: image, palette: .standard, options: ProcessingOptions()
        )
        #expect(result.width == 80)
    }

    @Test("PNG file decoding uses file contents instead of its extension")
    func testPNGFile() async throws {
        let data = try #require(Self.createJPEGData(
            pixelWidth: 20, pixelHeight: 10, exifOrientation: 1
        ))
        let image = try service.createOrientationNormalizedCGImage(from: data)
        let pngData = try #require(UIImage(cgImage: image).pngData())
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).image")
        try pngData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let loaded = try await service.loadImage(fromFile: url)
        #expect(loaded.width == 20)
        #expect(loaded.height == 10)
    }

    @Test("A non-image file reports a decoding error")
    func testInvalidFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        await #expect(throws: PhotoLibraryError.cgImageCreationFailed) {
            try await service.loadImage(fromFile: url)
        }
    }

    @Test("Missing files report a file reading error")
    func testMissingFile() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).png")
        await #expect(throws: PhotoLibraryError.fileLoadFailed) {
            try await service.loadImage(fromFile: url)
        }
    }

    @Test("File import rejects non-file URLs")
    func testRemoteURL() async throws {
        let url = try #require(URL(string: "https://example.invalid/image.png"))
        await #expect(throws: PhotoLibraryError.fileLoadFailed) {
            try await service.loadImage(fromFile: url)
        }
    }
}
