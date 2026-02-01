// VideoExporter.swift
import Foundation
import AVFoundation
import Metal

/// Export configuration
public struct VideoExportConfiguration: Sendable {
    public var resolution: Resolution
    public var frameRate: Int
    public var codec: AVVideoCodecType
    public var bitRate: Int

    public enum Resolution: Sendable {
        case hd720p   // 1280x720
        case hd1080p  // 1920x1080
        case uhd4k    // 3840x2160
        case custom(width: Int, height: Int)

        public var size: CGSize {
            switch self {
            case .hd720p: return CGSize(width: 1280, height: 720)
            case .hd1080p: return CGSize(width: 1920, height: 1080)
            case .uhd4k: return CGSize(width: 3840, height: 2160)
            case .custom(let width, let height): return CGSize(width: width, height: height)
            }
        }
    }

    public init(
        resolution: Resolution = .hd1080p,
        frameRate: Int = 30,
        codec: AVVideoCodecType = .h264,
        bitRate: Int = 10_000_000
    ) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.bitRate = bitRate
    }

    public static let hd1080p30 = VideoExportConfiguration(resolution: .hd1080p, frameRate: 30)
    public static let hd1080p60 = VideoExportConfiguration(resolution: .hd1080p, frameRate: 60)
    public static let uhd4k30 = VideoExportConfiguration(resolution: .uhd4k, frameRate: 30)
}

/// Exports animated text art to video
@MainActor
public final class VideoExporter {

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    public private(set) var isExporting: Bool = false
    public private(set) var progress: Double = 0

    public init(device: MTLDevice, commandQueue: MTLCommandQueue) {
        self.device = device
        self.commandQueue = commandQueue
    }

    /// Export animation to video file
    /// - Parameters:
    ///   - renderFrame: Closure that renders a frame at given time to the provided texture
    ///   - duration: Total animation duration
    ///   - config: Export configuration
    ///   - outputURL: Output file URL
    ///   - progressHandler: Called with progress updates (0.0 - 1.0)
    public nonisolated func export(
        renderFrame: @escaping (TimeInterval, MTLTexture) async -> Void,
        duration: TimeInterval,
        config: VideoExportConfiguration = .hd1080p30,
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

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Setup asset writer
        let writer = try AVAssetWriter(url: outputURL, fileType: .mp4)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: config.codec,
            AVVideoWidthKey: Int(config.resolution.size.width),
            AVVideoHeightKey: Int(config.resolution.size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: config.bitRate,
                AVVideoExpectedSourceFrameRateKey: config.frameRate
            ]
        ]

        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(config.resolution.size.width),
            kCVPixelBufferHeightKey as String: Int(config.resolution.size.height),
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        writer.add(input)

        guard writer.startWriting() else {
            throw ExportError.failedToStartWriting(writer.error)
        }

        writer.startSession(atSourceTime: .zero)

        // Create frame capturer
        let capturer = try FrameCapturer(
            device: device,
            width: Int(config.resolution.size.width),
            height: Int(config.resolution.size.height)
        )

        guard let renderTexture = capturer.createRenderTexture() else {
            throw ExportError.failedToCreateRenderTexture
        }

        // Render frames
        let totalFrames = Int(duration * Double(config.frameRate))
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(config.frameRate))

        for frameIndex in 0..<totalFrames {
            // Check for cancellation
            try Task.checkCancellation()

            // Wait for input to be ready
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)  // 10ms
            }

            let time = Double(frameIndex) / Double(config.frameRate)

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

            // Append to video
            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)

            // Update progress
            let currentProgress = Double(frameIndex + 1) / Double(totalFrames)
            await MainActor.run {
                progress = currentProgress
            }
            progressHandler?(currentProgress)
        }

        // Finish writing
        input.markAsFinished()

        await withCheckedContinuation { continuation in
            writer.finishWriting {
                continuation.resume()
            }
        }

        if let error = writer.error {
            throw ExportError.writingFailed(error)
        }
    }
}
