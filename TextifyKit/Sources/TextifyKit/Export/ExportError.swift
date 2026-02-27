// ExportError.swift
import Foundation

/// Errors that can occur during export
public enum ExportError: Error, LocalizedError {
    case failedToCreateTextureCache
    case failedToCreatePixelBufferPool
    case failedToCreatePixelBuffer
    case failedToCreateRenderTexture
    case failedToStartWriting(Error?)
    case writingFailed(Error)
    case alreadyExporting
    case cancelled
    case failedToCreateGIFDestination
    case failedToFinalizeGIF

    public var errorDescription: String? {
        switch self {
        case .failedToCreateTextureCache:
            return "Failed to create Metal texture cache"
        case .failedToCreatePixelBufferPool:
            return "Failed to create pixel buffer pool"
        case .failedToCreatePixelBuffer:
            return "Failed to create pixel buffer"
        case .failedToCreateRenderTexture:
            return "Failed to create render texture"
        case .failedToStartWriting(let error):
            return "Failed to start writing: \(error?.localizedDescription ?? "unknown")"
        case .writingFailed(let error):
            return "Writing failed: \(error.localizedDescription)"
        case .alreadyExporting:
            return "Export already in progress"
        case .cancelled:
            return "Export was cancelled"
        case .failedToCreateGIFDestination:
            return "Failed to create GIF destination"
        case .failedToFinalizeGIF:
            return "Failed to finalize GIF"
        }
    }
}
