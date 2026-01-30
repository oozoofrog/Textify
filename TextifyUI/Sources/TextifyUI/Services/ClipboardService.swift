import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Errors that can occur during clipboard operations
public enum ClipboardError: Error, LocalizedError {
    case copyFailed
    case platformNotSupported

    public var errorDescription: String? {
        switch self {
        case .copyFailed:
            return "Failed to copy text to clipboard"
        case .platformNotSupported:
            return "Clipboard is not supported on this platform"
        }
    }
}

/// Service for clipboard operations
public final class ClipboardService: Sendable {

    public init() {}

    /// Copies text to the system clipboard
    /// - Parameter text: The text to copy
    public func copy(text: String) throws {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        #else
        throw ClipboardError.platformNotSupported
        #endif
    }
}
