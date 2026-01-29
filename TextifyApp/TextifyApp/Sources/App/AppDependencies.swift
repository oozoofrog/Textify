import Foundation
import SwiftUI
import CoreGraphics
import TextifyKit

/// Composition root for dependency injection.
/// All services and view model factories are created here.
@Observable
final class AppDependencies: Sendable {
    // MARK: - TextifyKit Services

    private let textArtGenerator: TextArtGenerator

    // MARK: - App Services

    let photoLibraryService: PhotoLibraryService
    let fileImportService: FileImportService
    let clipboardService: ClipboardService
    let imageExportService: ImageExportService

    init() {
        // TextifyKit services
        self.textArtGenerator = TextArtGenerator()

        // Platform services
        self.photoLibraryService = PhotoLibraryService()
        self.fileImportService = FileImportService()
        self.clipboardService = ClipboardService()
        self.imageExportService = ImageExportService()
    }

    // MARK: - ViewModel Factories

    @MainActor
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel()
    }

    @MainActor
    func makeImageSelectionViewModel() -> ImageSelectionViewModel {
        ImageSelectionViewModel(photoService: photoLibraryService)
    }

    @MainActor
    func makeTextInputViewModel() -> TextInputViewModel {
        TextInputViewModel(fileService: fileImportService)
    }

    @MainActor
    func makeGenerationViewModel() -> GenerationViewModel {
        GenerationViewModel(generator: textArtGenerator)
    }

    @MainActor
    func makeResultViewModel(textArt: TextArt) -> ResultViewModel {
        ResultViewModel(
            textArt: textArt,
            clipboardService: clipboardService,
            exportService: imageExportService
        )
    }
}
