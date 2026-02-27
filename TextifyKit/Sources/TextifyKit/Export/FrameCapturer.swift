// FrameCapturer.swift
import Foundation
import Metal
import MetalKit
import CoreVideo
import AVFoundation

/// Captures Metal render output to CVPixelBuffer for video export
public final class FrameCapturer: @unchecked Sendable {

    private let device: MTLDevice
    private var textureCache: CVMetalTextureCache?
    private var pixelBufferPool: CVPixelBufferPool?

    public let width: Int
    public let height: Int

    public init(device: MTLDevice, width: Int, height: Int) throws {
        self.device = device
        self.width = width
        self.height = height

        // Create texture cache
        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        guard status == kCVReturnSuccess, let textureCache = cache else {
            throw ExportError.failedToCreateTextureCache
        }
        self.textureCache = textureCache

        // Create pixel buffer pool
        try createPixelBufferPool()
    }

    private func createPixelBufferPool() throws {
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3
        ]

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]

        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(nil, poolAttributes as CFDictionary, pixelBufferAttributes as CFDictionary, &pool)

        guard status == kCVReturnSuccess, let pixelBufferPool = pool else {
            throw ExportError.failedToCreatePixelBufferPool
        }
        self.pixelBufferPool = pixelBufferPool
    }

    /// Create a new pixel buffer from the pool
    public func createPixelBuffer() throws -> CVPixelBuffer {
        guard let pool = pixelBufferPool else {
            throw ExportError.failedToCreatePixelBufferPool
        }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw ExportError.failedToCreatePixelBuffer
        }

        return buffer
    }

    /// Copy Metal texture contents to pixel buffer
    public func captureFrame(from texture: MTLTexture, to pixelBuffer: CVPixelBuffer, commandBuffer: MTLCommandBuffer) {
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else { return }

        // Create Metal texture from CVPixelBuffer
        guard let textureCache = textureCache else { return }

        var cvTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            nil,
            textureCache,
            pixelBuffer,
            nil,
            .bgra8Unorm,
            width,
            height,
            0,
            &cvTexture
        )

        guard status == kCVReturnSuccess,
              let cvTex = cvTexture,
              let destinationTexture = CVMetalTextureGetTexture(cvTex) else { return }

        // Copy texture
        blitEncoder.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
            sourceSize: MTLSize(width: width, height: height, depth: 1),
            to: destinationTexture,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )

        blitEncoder.endEncoding()
    }

    /// Create a texture for offscreen rendering
    public func createRenderTexture() -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared

        return device.makeTexture(descriptor: descriptor)
    }
}
