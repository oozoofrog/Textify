// MetalTextifyView.swift
import SwiftUI
import MetalKit
import TextifyKit

/// SwiftUI wrapper for Metal-based MSDF text rendering
public struct MetalTextifyView: UIViewRepresentable {

    // MARK: - Properties

    /// The text art to render
    @Binding public var textArtPro: TextArtPro?

    /// Background color
    public var backgroundColor: Color

    /// Glyph size in points
    public var glyphSize: CGSize

    /// Transform for zoom/pan (identity = no transform)
    public var transform: CGAffineTransform

    /// Called when Metal is not available
    public var onMetalUnavailable: (() -> Void)?

    // MARK: - Initialization

    public init(
        textArtPro: Binding<TextArtPro?>,
        backgroundColor: Color = .black,
        glyphSize: CGSize = CGSize(width: 8, height: 16),
        transform: CGAffineTransform = .identity,
        onMetalUnavailable: (() -> Void)? = nil
    ) {
        self._textArtPro = textArtPro
        self.backgroundColor = backgroundColor
        self.glyphSize = glyphSize
        self.transform = transform
        self.onMetalUnavailable = onMetalUnavailable
    }

    // MARK: - UIViewRepresentable

    public func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()

        // Check Metal availability
        guard MetalContext.isAvailable else {
            onMetalUnavailable?()
            return mtkView
        }

        // Configure MTKView
        do {
            let metalContext = try MetalContext()
            mtkView.device = metalContext.device
            mtkView.delegate = context.coordinator
            mtkView.enableSetNeedsDisplay = true
            mtkView.isPaused = false
            mtkView.preferredFramesPerSecond = 60
            mtkView.colorPixelFormat = .bgra8Unorm

            // Set clear color from SwiftUI Color
            let uiColor = UIColor(backgroundColor)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            mtkView.clearColor = MTLClearColor(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))

            // Initialize coordinator with Metal context
            context.coordinator.setupRenderer(device: metalContext.device, commandQueue: metalContext.commandQueue, library: metalContext.library)

        } catch {
            print("Failed to initialize Metal: \(error)")
            onMetalUnavailable?()
        }

        return mtkView
    }

    public func updateUIView(_ mtkView: MTKView, context: Context) {
        // Update background color
        let uiColor = UIColor(backgroundColor)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        mtkView.clearColor = MTLClearColor(red: Double(red), green: Double(green), blue: Double(blue), alpha: Double(alpha))

        // Update coordinator properties
        context.coordinator.textArtPro = textArtPro
        context.coordinator.glyphSize = SIMD2<Float>(Float(glyphSize.width), Float(glyphSize.height))
        context.coordinator.transform = transform

        // Request redraw
        mtkView.setNeedsDisplay()
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    @MainActor
    public class Coordinator: NSObject, MTKViewDelegate {

        // MARK: - Properties

        var textArtPro: TextArtPro?
        var glyphSize: SIMD2<Float> = SIMD2<Float>(8, 16)
        var transform: CGAffineTransform = .identity

        private var renderer: GlyphRenderer?
        private var atlasInfo: MSDFAtlasInfo?
        private var lastTextArtHash: Int?

        // MARK: - Setup

        func setupRenderer(device: MTLDevice, commandQueue: MTLCommandQueue, library: MTLLibrary) {
            do {
                renderer = try GlyphRenderer(device: device, commandQueue: commandQueue, library: library)

                // Use placeholder atlas info for now (will be replaced with real MSDF atlas)
                atlasInfo = MSDFAtlasInfo.createASCIIPlaceholder()

            } catch {
                print("Failed to create GlyphRenderer: \(error)")
            }
        }

        // MARK: - MTKViewDelegate

        public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // Handle resize - update projection matrix
            updateProjectionMatrix(for: size)
        }

        public func draw(in view: MTKView) {
            guard let renderer = renderer,
                  let drawable = view.currentDrawable else { return }

            // Update instances if text art changed
            if let textArt = textArtPro {
                let currentHash = textArt.hashValue
                if currentHash != lastTextArtHash {
                    if let atlasInfo = atlasInfo {
                        renderer.glyphSize = glyphSize
                        renderer.updateInstances(from: textArt, atlasInfo: atlasInfo)
                    }
                    lastTextArtHash = currentHash
                }
            }

            // Update uniforms with current projection
            var uniforms = MSDFUniforms()
            uniforms.projectionMatrix = createProjectionMatrix(for: view.drawableSize)
            uniforms.time = Float(CACurrentMediaTime())
            renderer.updateUniforms(uniforms)

            // Render
            renderer.render(to: drawable, clearColor: view.clearColor)
        }

        // MARK: - Projection

        private func updateProjectionMatrix(for size: CGSize) {
            // Projection will be updated in draw()
        }

        private func createProjectionMatrix(for size: CGSize) -> simd_float4x4 {
            // Orthographic projection matrix
            let width = Float(size.width)
            let height = Float(size.height)

            // Apply transform
            let scaleX = Float(transform.a)
            let scaleY = Float(transform.d)
            let translateX = Float(transform.tx)
            let translateY = Float(transform.ty)

            // Create orthographic projection (0,0 at top-left, positive Y down)
            let left: Float = -translateX / scaleX
            let right: Float = (width - translateX) / scaleX
            let top: Float = -translateY / scaleY
            let bottom: Float = (height - translateY) / scaleY

            return orthographicProjection(left: left, right: right, bottom: bottom, top: top, near: -1, far: 1)
        }

        private func orthographicProjection(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> simd_float4x4 {
            let width = right - left
            let height = top - bottom
            let depth = far - near

            return simd_float4x4(columns: (
                SIMD4<Float>(2 / width, 0, 0, 0),
                SIMD4<Float>(0, 2 / height, 0, 0),
                SIMD4<Float>(0, 0, -2 / depth, 0),
                SIMD4<Float>(-(right + left) / width, -(top + bottom) / height, -(far + near) / depth, 1)
            ))
        }
    }
}

// MARK: - Hashable Extension for TextArtPro

extension TextArtPro: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(width)
        hasher.combine(height)
        hasher.combine(createdAt)
        // Hash first few characters for efficiency
        if let firstRow = rows.first, let firstChar = firstRow.first {
            hasher.combine(firstChar.character)
        }
    }
}

// MARK: - Preview

#if DEBUG
private struct MetalTextifyViewPreview: View {
    @State private var textArtPro: TextArtPro?

    var body: some View {
        MetalTextifyView(
            textArtPro: $textArtPro,
            backgroundColor: .black,
            glyphSize: CGSize(width: 10, height: 18)
        )
        .onAppear {
            createSampleTextArt()
        }
    }

    private func createSampleTextArt() {
        let rows: [[ColoredCharacter]] = (0..<20).map { row in
            (0..<40).map { col in
                let brightness = UInt8((row + col) * 3 % 256)
                let chars = " .:-=+*#%@"
                let charIndex = Int(brightness) * chars.count / 256
                let char = chars[chars.index(chars.startIndex, offsetBy: min(charIndex, chars.count - 1))]
                return ColoredCharacter(
                    character: char,
                    color: SIMD4<Float>(0.2, 1.0, 0.3, 1.0),  // Matrix green
                    brightness: brightness
                )
            }
        }

        textArtPro = TextArtPro(rows: rows, width: 40, height: 20)
    }
}

#Preview {
    MetalTextifyViewPreview()
}
#endif
