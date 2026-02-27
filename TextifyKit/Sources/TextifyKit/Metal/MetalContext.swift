// MetalContext.swift
import Metal
import MetalKit

/// Central Metal context for MSDF text rendering
/// Manages device, command queue, and shader library
@MainActor
public final class MetalContext: Sendable {

    /// Shared instance - initialized lazily on first access
    public static let shared: MetalContext? = {
        try? MetalContext()
    }()

    public let device: MTLDevice
    public let commandQueue: MTLCommandQueue
    public let library: MTLLibrary

    /// Create a new Metal context
    /// - Throws: MetalContextError if initialization fails
    public init() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw MetalContextError.metalNotSupported
        }
        self.device = device

        guard let commandQueue = device.makeCommandQueue() else {
            throw MetalContextError.commandQueueCreationFailed
        }
        self.commandQueue = commandQueue

        // CRITICAL: SPM packages cannot use makeDefaultLibrary()
        // Must compile shaders from source string at runtime
        self.library = try device.makeLibrary(source: MetalShaderSource.msdfShaders, options: nil)
    }

    /// Check if Metal is available on this device
    nonisolated public static var isAvailable: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }
}

/// Errors that can occur during Metal context initialization
public enum MetalContextError: Error, LocalizedError {
    case metalNotSupported
    case commandQueueCreationFailed
    case shaderCompilationFailed(Error)

    public var errorDescription: String? {
        switch self {
        case .metalNotSupported:
            return "Metal is not supported on this device"
        case .commandQueueCreationFailed:
            return "Failed to create Metal command queue"
        case .shaderCompilationFailed(let underlyingError):
            return "Failed to compile Metal shaders: \(underlyingError.localizedDescription)"
        }
    }
}
