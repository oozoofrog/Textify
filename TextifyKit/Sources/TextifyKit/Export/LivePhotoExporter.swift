//
//  LivePhotoExporter.swift
//  TextifyKit
//
//  Created for Metal TextifyProEngine
//

import Foundation
import Photos
import AVFoundation
import Metal

#if canImport(UIKit)
import UIKit
#endif

/// Exports animated TextArt as Live Photo (still image + video)
@available(iOS 13.0, macOS 10.15, *)
@MainActor
public final class LivePhotoExporter {

    // MARK: - Types

    public struct Configuration: Sendable {
        public var stillImageTime: TimeInterval
        public var videoDuration: TimeInterval
        public var resolution: VideoExportConfiguration.Resolution
        public var frameRate: Int

        public init(
            stillImageTime: TimeInterval = 0.0,
            videoDuration: TimeInterval = 3.0,
            resolution: VideoExportConfiguration.Resolution = .hd1080p,
            frameRate: Int = 30
        ) {
            self.stillImageTime = stillImageTime
            self.videoDuration = videoDuration
            self.resolution = resolution
            self.frameRate = frameRate
        }

        public static let standard = Configuration()

        public static let highQuality = Configuration(
            videoDuration: 3.0,
            resolution: .uhd4k,
            frameRate: 30
        )
    }

    public struct LivePhotoResources: Sendable {
        public let imageURL: URL
        public let videoURL: URL
        public let identifier: String

        public init(imageURL: URL, videoURL: URL, identifier: String) {
            self.imageURL = imageURL
            self.videoURL = videoURL
            self.identifier = identifier
        }
    }

    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let configuration: Configuration

    // MARK: - Initialization

    public init(
        device: MTLDevice,
        commandQueue: MTLCommandQueue,
        configuration: Configuration = .standard
    ) {
        self.device = device
        self.commandQueue = commandQueue
        self.configuration = configuration
    }

    public convenience init?(configuration: Configuration = .standard) {
        guard let context = MetalContext.shared else { return nil }
        self.init(
            device: context.device,
            commandQueue: context.commandQueue,
            configuration: configuration
        )
    }

    // MARK: - Public Methods

    /// Export Live Photo resources (image + video with matching identifiers)
    /// - Parameters:
    ///   - renderFrame: Closure that renders a frame at given time to the provided texture
    ///   - outputDirectory: Directory to save the resources
    ///   - progress: Progress callback (0.0 to 1.0)
    /// - Returns: LivePhotoResources containing paths and identifier
    public func exportResources(
        renderFrame: @escaping @Sendable (TimeInterval, MTLTexture) async -> Void,
        outputDirectory: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> LivePhotoResources {
        // Generate unique identifier for Live Photo pairing
        let identifier = UUID().uuidString

        let imageURL = outputDirectory.appendingPathComponent("live_photo_\(identifier).jpg")
        let videoURL = outputDirectory.appendingPathComponent("live_photo_\(identifier).mov")

        // Create directories if needed
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

        // Step 1: Export video (70% of progress)
        let videoExporter = VideoExporter(device: device, commandQueue: commandQueue)
        let videoConfig = VideoExportConfiguration(
            resolution: configuration.resolution,
            frameRate: configuration.frameRate
        )

        try await videoExporter.export(
            renderFrame: renderFrame,
            duration: configuration.videoDuration,
            config: videoConfig,
            to: videoURL,
            progressHandler: { videoProgress in
                progress(videoProgress * 0.7)
            }
        )

        // Step 2: Add Live Photo metadata to video
        try await addLivePhotoMetadata(to: videoURL, identifier: identifier)
        progress(0.8)

        // Step 3: Capture still image at specified time
        try await captureStillImage(
            renderFrame: renderFrame,
            at: configuration.stillImageTime,
            to: imageURL,
            identifier: identifier
        )
        progress(0.95)

        // Step 4: Add Live Photo metadata to image
        try addLivePhotoMetadataToImage(at: imageURL, identifier: identifier)
        progress(1.0)

        return LivePhotoResources(
            imageURL: imageURL,
            videoURL: videoURL,
            identifier: identifier
        )
    }

    /// Save Live Photo to Photos library
    /// - Parameter resources: The exported Live Photo resources
    public func saveToPhotosLibrary(resources: LivePhotoResources) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()

            let options = PHAssetResourceCreationOptions()
            options.shouldMoveFile = false

            // Add paired image and video
            request.addResource(with: .photo, fileURL: resources.imageURL, options: options)
            request.addResource(with: .pairedVideo, fileURL: resources.videoURL, options: options)
        }
    }

    // MARK: - Private Methods

    private nonisolated func addLivePhotoMetadata(to videoURL: URL, identifier: String) async throws {
        let asset = AVURLAsset(url: videoURL)

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw ExportError.failedToStartWriting(nil)
        }

        // Create temporary URL for the modified video
        let tempURL = videoURL.deletingLastPathComponent()
            .appendingPathComponent("temp_\(UUID().uuidString).mov")

        exportSession.outputURL = tempURL
        exportSession.outputFileType = .mov

        // Add Live Photo metadata
        let metadataItem = AVMutableMetadataItem()
        metadataItem.key = "com.apple.quicktime.content.identifier" as NSString
        metadataItem.keySpace = .quickTimeMetadata
        metadataItem.value = identifier as NSString
        metadataItem.dataType = kCMMetadataBaseDataType_UTF8 as String

        let stillTimeItem = AVMutableMetadataItem()
        stillTimeItem.key = "com.apple.quicktime.still-image-time" as NSString
        stillTimeItem.keySpace = .quickTimeMetadata
        stillTimeItem.value = 0 as NSNumber
        stillTimeItem.dataType = kCMMetadataBaseDataType_SInt8 as String

        exportSession.metadata = [metadataItem, stillTimeItem]

        await exportSession.export()

        if let error = exportSession.error {
            throw ExportError.writingFailed(error)
        }

        // Replace original with modified
        try FileManager.default.removeItem(at: videoURL)
        try FileManager.default.moveItem(at: tempURL, to: videoURL)
    }

    private func captureStillImage(
        renderFrame: @escaping @Sendable (TimeInterval, MTLTexture) async -> Void,
        at time: TimeInterval,
        to imageURL: URL,
        identifier: String
    ) async throws {
        let width = Int(configuration.resolution.size.width)
        let height = Int(configuration.resolution.size.height)

        // Create texture for rendering
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.renderTarget, .shaderRead]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw ExportError.failedToCreateRenderTexture
        }

        // Render frame at specified time
        await renderFrame(time, texture)

        // Wait for GPU to complete
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw ExportError.failedToCreatePixelBuffer
        }

        commandBuffer.commit()

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
        }

        // Convert texture to image and save as JPEG
        #if canImport(UIKit)
        let image = try textureToImage(texture, width: width, height: height)
        guard let jpegData = image.jpegData(compressionQuality: 0.95) else {
            throw ExportError.failedToCreatePixelBuffer
        }
        try jpegData.write(to: imageURL)
        #else
        // macOS fallback - save as PNG using CGImage
        try saveTextureAsPNG(texture, width: width, height: height, to: imageURL)
        #endif
    }

    #if !canImport(UIKit)
    private func saveTextureAsPNG(_ texture: MTLTexture, width: Int, height: Int, to url: URL) throws {
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: width, height: height, depth: 1)
            ),
            mipmapLevel: 0
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let cgImage = context.makeImage(),
        let destination = CGImageDestinationCreateWithURL(url as CFURL, kUTTypePNG, 1, nil) else {
            throw ExportError.failedToCreatePixelBuffer
        }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.failedToCreatePixelBuffer
        }
    }
    #endif

    #if canImport(UIKit)
    private func textureToImage(_ texture: MTLTexture, width: Int, height: Int) throws -> UIImage {
        let bytesPerRow = width * 4

        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegion(
                origin: MTLOrigin(x: 0, y: 0, z: 0),
                size: MTLSize(width: width, height: height, depth: 1)
            ),
            mipmapLevel: 0
        )

        // Convert BGRA to RGBA
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let b = pixelData[i]
            let r = pixelData[i + 2]
            pixelData[i] = r
            pixelData[i + 2] = b
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ExportError.failedToCreatePixelBuffer
        }

        guard let cgImage = context.makeImage() else {
            throw ExportError.failedToCreatePixelBuffer
        }

        return UIImage(cgImage: cgImage)
    }
    #endif

    private nonisolated func addLivePhotoMetadataToImage(at imageURL: URL, identifier: String) throws {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let imageType = CGImageSourceGetType(imageSource),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ExportError.failedToCreatePixelBuffer
        }

        // Get existing metadata
        var metadata = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] ?? [:]

        // Add Live Photo identifier to Maker Apple metadata
        var makerApple = metadata[kCGImagePropertyMakerAppleDictionary as String] as? [String: Any] ?? [:]
        makerApple["17"] = identifier // Live Photo asset identifier key
        metadata[kCGImagePropertyMakerAppleDictionary as String] = makerApple

        // Write image with updated metadata
        guard let destination = CGImageDestinationCreateWithURL(
            imageURL as CFURL,
            imageType,
            1,
            nil
        ) else {
            throw ExportError.failedToCreatePixelBuffer
        }

        CGImageDestinationAddImage(destination, cgImage, metadata as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            throw ExportError.failedToCreatePixelBuffer
        }
    }
}
