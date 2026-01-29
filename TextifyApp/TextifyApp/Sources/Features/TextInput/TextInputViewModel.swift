import Foundation
import SwiftUI

/// ViewModel for the text input screen
@Observable
@MainActor
final class TextInputViewModel {
    private let fileService: FileImportService

    var inputText: String = ""
    var isImporting = false
    var errorMessage: String?

    /// Default character sets for quick selection
    let presetPalettes: [(name: String, characters: String)] = [
        ("Standard", " .:-=+*#%@"),
        ("Blocks", " .:oO@"),
        ("Dense", " .,:;+*?%S#@"),
        ("Binary", " #"),
        ("Custom", "")
    ]

    var selectedPresetIndex: Int = 0

    init(fileService: FileImportService) {
        self.fileService = fileService
        // Set default text from first preset
        self.inputText = presetPalettes[0].characters
    }

    func selectPreset(at index: Int) {
        selectedPresetIndex = index
        if index < presetPalettes.count - 1 {
            inputText = presetPalettes[index].characters
        }
        // Custom preset keeps current text
    }

    func importFromFile(url: URL) async {
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

    var isValidInput: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }
}
