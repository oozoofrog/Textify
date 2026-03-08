import Foundation
import SwiftUI

/// ViewModel for the text input screen
@Observable
@MainActor
public final class TextInputViewModel {
    private let fileService: FileImportService

    public var inputText: String = ""
    public var isImporting = false
    public var errorMessage: String?

    /// Default character sets for quick selection
    public let presetPalettes: [(name: String, characters: String)] = [
        ("Standard", " .:-=+*#%@"),
        ("Blocks", " .:oO@"),
        ("Dense", " .,:;+*?%S#@"),
        ("Binary", " #"),
        ("Custom", "")
    ]

    public var selectedPresetIndex: Int = 0

    public init(fileService: FileImportService) {
        self.fileService = fileService
        // Set default text from first preset
        self.inputText = presetPalettes[0].characters
    }

    public func selectPreset(at index: Int) {
        selectedPresetIndex = index
        if index < presetPalettes.count - 1 {
            inputText = presetPalettes[index].characters
        }
        // Custom preset keeps current text
    }

    public func importFromFile(url: URL) async {
        isImporting = true
        errorMessage = nil

        do {
            inputText = try await fileService.loadText(from: url)
            selectedPresetIndex = presetPalettes.count - 1 // Switch to custom
        } catch {
            errorMessage = "Failed to import: \(error.localizedDescription)"
        }

        isImporting = false
    }

    public var isValidInput: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
