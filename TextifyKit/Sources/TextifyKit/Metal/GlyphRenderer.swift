// GlyphRenderer.swift
import Foundation
import Metal
import MetalKit
import simd
import QuartzCore

/// Uniform buffer data for MSDF rendering
public struct MSDFUniforms {
    public var projectionMatrix: simd_float4x4
    public var unitRange: SIMD2<Float>  // pxRange / atlasSize
    public var time: Float
    public var padding: Float = 0

    public init(projectionMatrix: simd_float4x4 = matrix_identity_float4x4,
                unitRange: SIMD2<Float> = SIMD2<Float>(4.0 / 2048.0, 4.0 / 2048.0),
                time: Float = 0) {
        self.projectionMatrix = projectionMatrix
        self.unitRange = unitRange
        self.time = time
    }
}

/// Instance data for each glyph
public struct GlyphInstance {
    public var position: SIMD2<Float>      // Screen position
    public var size: SIMD2<Float>          // Glyph size in pixels
    public var texCoords: SIMD4<Float>     // left, bottom, right, top in atlas
    public var color: SIMD4<Float>         // RGBA color

    public init(position: SIMD2<Float>, size: SIMD2<Float>, texCoords: SIMD4<Float>, color: SIMD4<Float>) {
        self.position = position
        self.size = size
        self.texCoords = texCoords
        self.color = color
    }
}

/// Renders glyphs using Metal instanced rendering with MSDF
@MainActor
public final class GlyphRenderer {

    // MARK: - Properties

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let library: MTLLibrary

    private var pipelineState: MTLRenderPipelineState?
    private var quadVertexBuffer: MTLBuffer?
    private var instanceBuffer: MTLBuffer?
    private var uniformBuffer: MTLBuffer?

    private var atlasTexture: MTLTexture?

    /// Maximum number of glyphs that can be rendered
    public let maxGlyphCount: Int

    /// Current number of glyphs
    public private(set) var glyphCount: Int = 0

    /// Glyph size in points
    public var glyphSize: SIMD2<Float> = SIMD2<Float>(8, 16)

    /// Spacing between glyphs
    public var glyphSpacing: SIMD2<Float> = SIMD2<Float>(0, 0)

    // MARK: - Initialization

    public init(device: MTLDevice, commandQueue: MTLCommandQueue, library: MTLLibrary, maxGlyphCount: Int = 100_000) throws {
        self.device = device
        self.commandQueue = commandQueue
        self.library = library
        self.maxGlyphCount = maxGlyphCount

        try setupPipeline()
        try setupBuffers()
    }

    /// Convenience initializer using MetalContext
    public convenience init(maxGlyphCount: Int = 100_000) throws {
        guard let context = MetalContext.shared else {
            throw GlyphRendererError.metalContextUnavailable
        }
        try self.init(device: context.device, commandQueue: context.commandQueue, library: context.library, maxGlyphCount: maxGlyphCount)
    }

    // MARK: - Setup

    private func setupPipeline() throws {
        guard let vertexFunction = library.makeFunction(name: "msdf_vertex"),
              let fragmentFunction = library.makeFunction(name: "msdf_fragment") else {
            throw GlyphRendererError.shaderFunctionNotFound
        }

        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

        // Enable alpha blending for anti-aliased edges
        pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
        pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
        pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

        pipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    }

    private func setupBuffers() throws {
        // Quad vertices (unit square, will be scaled by instance data)
        let quadVertices: [SIMD2<Float>] = [
            SIMD2<Float>(0, 0),  // bottom-left
            SIMD2<Float>(1, 0),  // bottom-right
            SIMD2<Float>(0, 1),  // top-left
            SIMD2<Float>(1, 0),  // bottom-right
            SIMD2<Float>(1, 1),  // top-right
            SIMD2<Float>(0, 1),  // top-left
        ]

        quadVertexBuffer = device.makeBuffer(
            bytes: quadVertices,
            length: MemoryLayout<SIMD2<Float>>.stride * quadVertices.count,
            options: .storageModeShared
        )

        // Instance buffer (pre-allocated for maxGlyphCount)
        let instanceBufferSize = MemoryLayout<GlyphInstance>.stride * maxGlyphCount
        instanceBuffer = device.makeBuffer(length: instanceBufferSize, options: .storageModeShared)

        // Uniform buffer
        uniformBuffer = device.makeBuffer(length: MemoryLayout<MSDFUniforms>.stride, options: .storageModeShared)

        guard quadVertexBuffer != nil, instanceBuffer != nil, uniformBuffer != nil else {
            throw GlyphRendererError.bufferCreationFailed
        }
    }

    // MARK: - Atlas Management

    /// Load MSDF atlas texture from a file
    public func loadAtlas(from url: URL) throws {
        let textureLoader = MTKTextureLoader(device: device)
        atlasTexture = try textureLoader.newTexture(URL: url, options: [
            .textureUsage: MTLTextureUsage.shaderRead.rawValue,
            .textureStorageMode: MTLStorageMode.private.rawValue,
            .generateMipmaps: true
        ])
    }

    /// Load MSDF atlas texture from data
    public func loadAtlas(from data: Data, width: Int, height: Int) throws {
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: true
        )
        textureDescriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: textureDescriptor) else {
            throw GlyphRendererError.textureCreationFailed
        }

        let region = MTLRegion(origin: MTLOrigin(x: 0, y: 0, z: 0),
                               size: MTLSize(width: width, height: height, depth: 1))

        data.withUnsafeBytes { ptr in
            texture.replace(region: region, mipmapLevel: 0, withBytes: ptr.baseAddress!, bytesPerRow: width * 4)
        }

        atlasTexture = texture
    }

    // MARK: - Instance Data Updates

    /// Update instance data from TextArtPro
    public func updateInstances(from textArt: TextArtPro, atlasInfo: MSDFAtlasInfo, origin: SIMD2<Float> = .zero) {
        guard let buffer = instanceBuffer else { return }

        let pointer = buffer.contents().bindMemory(to: GlyphInstance.self, capacity: maxGlyphCount)
        var instanceCount = 0

        let effectiveGlyphSize = glyphSize + glyphSpacing

        textArt.enumerateGlyphs { row, col, coloredChar in
            guard instanceCount < maxGlyphCount else { return }

            // Get glyph info from atlas
            guard let glyphInfo = atlasInfo.glyph(for: coloredChar.character) else { return }

            // Calculate position
            let x = origin.x + Float(col) * effectiveGlyphSize.x
            let y = origin.y + Float(row) * effectiveGlyphSize.y

            // Create instance
            pointer[instanceCount] = GlyphInstance(
                position: SIMD2<Float>(x, y),
                size: glyphSize,
                texCoords: glyphInfo.texCoords,
                color: coloredChar.color
            )

            instanceCount += 1
        }

        glyphCount = instanceCount
    }

    /// Update uniforms for rendering
    public func updateUniforms(_ uniforms: MSDFUniforms) {
        guard let buffer = uniformBuffer else { return }
        var mutableUniforms = uniforms
        memcpy(buffer.contents(), &mutableUniforms, MemoryLayout<MSDFUniforms>.stride)
    }

    // MARK: - Rendering

    /// Encode render commands to a command buffer
    public func encode(to commandBuffer: MTLCommandBuffer, renderPassDescriptor: MTLRenderPassDescriptor) {
        guard let pipelineState = pipelineState,
              let quadVertexBuffer = quadVertexBuffer,
              let instanceBuffer = instanceBuffer,
              let uniformBuffer = uniformBuffer,
              glyphCount > 0 else { return }

        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }

        renderEncoder.setRenderPipelineState(pipelineState)

        // Set vertex buffers
        renderEncoder.setVertexBuffer(quadVertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(instanceBuffer, offset: 0, index: 1)
        renderEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 2)

        // Set fragment buffers and textures
        renderEncoder.setFragmentBuffer(uniformBuffer, offset: 0, index: 2)
        if let atlas = atlasTexture {
            renderEncoder.setFragmentTexture(atlas, index: 0)
        }

        // Draw instanced quads
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6, instanceCount: glyphCount)

        renderEncoder.endEncoding()
    }

    /// Render to a drawable
    public func render(to drawable: CAMetalDrawable, clearColor: MTLClearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)) {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.texture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = clearColor

        encode(to: commandBuffer, renderPassDescriptor: renderPassDescriptor)

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// MARK: - MSDF Atlas Info

/// Information about glyphs in the MSDF atlas
public struct MSDFAtlasInfo: Sendable {
    public struct GlyphInfo: Sendable {
        public let unicode: UInt32
        public let texCoords: SIMD4<Float>  // left, bottom, right, top (normalized 0-1)
        public let advance: Float
        public let planeBounds: SIMD4<Float>  // left, bottom, right, top

        public init(unicode: UInt32, texCoords: SIMD4<Float>, advance: Float, planeBounds: SIMD4<Float>) {
            self.unicode = unicode
            self.texCoords = texCoords
            self.advance = advance
            self.planeBounds = planeBounds
        }
    }

    public let atlasWidth: Int
    public let atlasHeight: Int
    public let distanceRange: Float
    public let glyphs: [UInt32: GlyphInfo]

    public init(atlasWidth: Int, atlasHeight: Int, distanceRange: Float, glyphs: [UInt32: GlyphInfo]) {
        self.atlasWidth = atlasWidth
        self.atlasHeight = atlasHeight
        self.distanceRange = distanceRange
        self.glyphs = glyphs
    }

    /// Get glyph info for a character
    public func glyph(for character: Character) -> GlyphInfo? {
        guard let scalar = character.unicodeScalars.first else { return nil }
        return glyphs[scalar.value]
    }

    /// Create a simple ASCII atlas info (placeholder for testing)
    public static func createASCIIPlaceholder(atlasWidth: Int = 2048, atlasHeight: Int = 2048, glyphSize: Int = 64) -> MSDFAtlasInfo {
        let glyphsPerRow = atlasWidth / glyphSize
        var glyphs: [UInt32: GlyphInfo] = [:]

        // Create placeholder entries for ASCII printable characters (32-126)
        for i in 32...126 {
            let index = i - 32
            let row = index / glyphsPerRow
            let col = index % glyphsPerRow

            let left = Float(col * glyphSize) / Float(atlasWidth)
            let bottom = Float(row * glyphSize) / Float(atlasHeight)
            let right = Float((col + 1) * glyphSize) / Float(atlasWidth)
            let top = Float((row + 1) * glyphSize) / Float(atlasHeight)

            glyphs[UInt32(i)] = GlyphInfo(
                unicode: UInt32(i),
                texCoords: SIMD4<Float>(left, bottom, right, top),
                advance: 0.6,
                planeBounds: SIMD4<Float>(0, 0, 0.6, 1.0)
            )
        }

        return MSDFAtlasInfo(
            atlasWidth: atlasWidth,
            atlasHeight: atlasHeight,
            distanceRange: 4.0,
            glyphs: glyphs
        )
    }
}

// MARK: - Errors

public enum GlyphRendererError: Error, LocalizedError {
    case metalContextUnavailable
    case shaderFunctionNotFound
    case bufferCreationFailed
    case textureCreationFailed
    case pipelineCreationFailed

    public var errorDescription: String? {
        switch self {
        case .metalContextUnavailable:
            return "Metal context is not available"
        case .shaderFunctionNotFound:
            return "Required shader functions not found in library"
        case .bufferCreationFailed:
            return "Failed to create Metal buffers"
        case .textureCreationFailed:
            return "Failed to create Metal texture"
        case .pipelineCreationFailed:
            return "Failed to create render pipeline state"
        }
    }
}
