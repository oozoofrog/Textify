import Foundation

/// Errors that can occur during file import operations
enum FileImportError: Error, LocalizedError {
    case accessDenied
    case readFailed
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Access to the file was denied"
        case .readFailed:
            return "Failed to read the file contents"
        case .invalidEncoding:
            return "The file contains invalid text encoding"
        }
    }
}

/// Service for importing text from files
final class FileImportService: Sendable {

    init() {}

    /// Loads text content from a file URL
    /// - Parameter url: The URL of the text file to load
    /// - Returns: The text content of the file
    func loadText(from url: URL) async throws -> String {
        // Start accessing security-scoped resource
        let didStartAccessing = url.startAccessingSecurityScopedResource()

        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)

            // Try UTF-8 first, then other encodings
            if let text = String(data: data, encoding: .utf8) {
                return text
            } else if let text = String(data: data, encoding: .ascii) {
                return text
            } else if let text = String(data: data, encoding: .isoLatin1) {
                return text
            } else {
                throw FileImportError.invalidEncoding
            }
        } catch let error as FileImportError {
            throw error
        } catch {
            throw FileImportError.readFailed
        }
    }
}
