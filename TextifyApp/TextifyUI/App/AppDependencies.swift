import Foundation
import SwiftUI
import CoreGraphics
import TextifyKit

/// Composition root for dependency injection.
/// All services and view model factories are created here.
@MainActor
@Observable
public final class AppDependencies {
    private let textArtGenerator: TextArtGenerator

    public let photoLibraryService: PhotoLibraryService
    public let clipboardService: ClipboardService
    public let imageExportService: ImageExportService
    public let appearanceService: AppearanceService
    public let historyService: HistoryService
    public let textArtHistoryRecorder: TextArtHistoryRecorder
    public let hapticsService: HapticsService

    public init() {
        self.textArtGenerator = TextArtGenerator()
        self.photoLibraryService = PhotoLibraryService()
        self.clipboardService = ClipboardService()
        self.imageExportService = ImageExportService()
        self.appearanceService = AppearanceService()
        self.historyService = HistoryService()
        self.textArtHistoryRecorder = TextArtHistoryRecorder(historyService: historyService)
        self.hapticsService = HapticsService.shared
    }

    public func makeMainViewModel() -> MainViewModel {
        MainViewModel(photoLibraryService: photoLibraryService)
    }

    public func makeTextifyViewModel(image: CGImage) -> TextifyViewModel {
        TextifyViewModel(
            image: image,
            generator: textArtGenerator,
            clipboardService: clipboardService,
            exportService: imageExportService,
            historyRecorder: textArtHistoryRecorder,
            hapticsService: hapticsService
        )
    }

    public func makeHistoryDetailViewModel(entry: HistoryEntry) -> HistoryDetailViewModel {
        HistoryDetailViewModel(
            entry: entry,
            clipboardService: clipboardService,
            exportService: imageExportService
        )
    }

    public func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            appearanceService: appearanceService,
            historyService: historyService
        )
    }

    public func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(historyService: historyService)
    }
}
