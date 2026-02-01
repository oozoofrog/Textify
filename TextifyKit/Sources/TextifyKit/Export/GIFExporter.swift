// GIFExporter.swift
import Foundation
import ImageIO
import Metal
import CoreVideo
import UniformTypeIdentifiers

/// Exports animated text art to GIF
@available(iOS 14.0, macOS 11.0, *)
@MainActor
public final class GIFExporter {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue

    public private(set) var isExporting: Bool = false
    public private(set) var progress: Double = 0

    public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
    }

    /// Export animation to GIF file
    public nonisolated func export(
        renderFrame: @escaping (TimeInterval, MTLTexture) async -> Void,
        duration: TimeInterval,
        frameRate: Int = 15,
        width: Int = 480,
        height: Int = 320,
        to outputURL: URL,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws {
        await MainActor.run {
            guard !isExporting else {
                return
            }
            isExporting = true
            progress = 0
        }

        if await isExporting == false {
            throw ExportError.alreadyExporting
        }

        defer {
            Task { @MainActor in
                isExporting = false
            }
        }

        // Create frame capturer
        let capturer = try FrameCapturer(device: device, width: width, height: height)
        guard let renderTexture = capturer.createRenderTexture() else {
            throw ExportError.failedToCreateRenderTexture
        }

        // Create GIF destination
        guard let destination = CGImageDestinationCreateWithURL(
            outputURL as CFURL,
            UTType.gif.identifier as CFString,
            0,
            nil
        ) else {
            throw ExportError.failedToCreateGIFDestination
        }

        // Set GIF properties
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: 0  // Loop forever
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        // Frame properties
        let frameDelay = 1.0 / Double(frameRate)
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay
            ]
        ]

        // Render and add frames
        let totalFrames = Int(duration * Double(frameRate))

        for frameIndex in 0..<totalFrames {
            try Task.checkCancellation()

            let time = Double(frameIndex) / Double(frameRate)

            // Render frame
            await renderFrame(time, renderTexture)

            // Capture to pixel buffer
            let pixelBuffer = try capturer.createPixelBuffer()

            if let commandBuffer = commandQueue.makeCommandBuffer() {
                capturer.captureFrame(from: renderTexture, to: pixelBuffer, commandBuffer: commandBuffer)
                commandBuffer.commit()

                // Use addScheduledHandler to wait for completion without blocking
                await withCheckedContinuation { continuation in
                    commandBuffer.addCompletedHandler { _ in
                        continuation.resume()
                    }
                }
            }

            // Convert to CGImage
            if let cgImage = createCGImage(from: pixelBuffer) {
                CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
            }

            // Update progress
            let currentProgress = Double(frameIndex + 1) / Double(totalFrames)
            await MainActor.run {
                progress = currentProgress
            }
            progressHandler?(currentProgress)
        }

        // Finalize GIF
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.failedToFinalizeGIF
        }
    }

    private nonisolated func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        let colorSpace = CGColorSpaceCreateDeviceRGB()

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        ) else { return nil }

        return context.makeImage()
    }
}
