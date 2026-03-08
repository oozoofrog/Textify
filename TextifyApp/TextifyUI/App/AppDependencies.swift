import Foundation
import SwiftUI
import CoreGraphics
import TextifyKit

/// Composition root for dependency injection.
/// All services and view model factories are created here.
@MainActor
@Observable
public final class AppDependencies {
    // MARK: - TextifyKit Services

    private let textArtGenerator: TextArtGenerator

    // MARK: - App Services

    public let photoLibraryService: PhotoLibraryService
    public let fileImportService: FileImportService
    public let clipboardService: ClipboardService
    public let imageExportService: ImageExportService
    public let appearanceService: AppearanceService
    public let historyService: HistoryService
    public let hapticsService: HapticsService

    public init() {
        // TextifyKit services
        self.textArtGenerator = TextArtGenerator()

        // Platform services
        self.photoLibraryService = PhotoLibraryService()
        self.fileImportService = FileImportService()
        self.clipboardService = ClipboardService()
        self.imageExportService = ImageExportService()
        self.appearanceService = AppearanceService()
        self.historyService = HistoryService()
        self.hapticsService = HapticsService.shared
    }

    // MARK: - ViewModel Factories

    public func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel()
    }

    public func makeImageSelectionViewModel() -> ImageSelectionViewModel {
        ImageSelectionViewModel(photoService: photoLibraryService)
    }

    public func makeTextInputViewModel() -> TextInputViewModel {
        TextInputViewModel(fileService: fileImportService)
    }

    public func makeGenerationViewModel() -> GenerationViewModel {
        GenerationViewModel(generator: textArtGenerator)
    }

    public func makeResultViewModel(
        textArt: TextArt,
        sourceImage: CGImage? = nil,
        sourceCharacters: String = "",
        outputWidth: Int = 80,
        invertBrightness: Bool = false,
        contrastBoost: Float = 1.0
    ) -> ResultViewModel {
        ResultViewModel(
            textArt: textArt,
            clipboardService: clipboardService,
            exportService: imageExportService,
            historyService: historyService,
            sourceImage: sourceImage,
            sourceCharacters: sourceCharacters,
            outputWidth: outputWidth,
            invertBrightness: invertBrightness,
            contrastBoost: contrastBoost
        )
    }

    public func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(appearanceService: appearanceService)
    }

    public func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(historyService: historyService)
    }
}
