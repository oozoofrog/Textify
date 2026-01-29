import Foundation
import SwiftUI
import CoreGraphics
import PhotosUI

/// ViewModel for the image selection screen
@Observable
@MainActor
final class ImageSelectionViewModel {
    private let photoService: PhotoLibraryService

    var selectedPhotoItem: PhotosPickerItem?
    var selectedImage: CGImage?
    var isLoading = false
    var errorMessage: String?

    init(photoService: PhotoLibraryService) {
        self.photoService = photoService
    }

    func loadImage(from item: PhotosPickerItem?) async {
        guard let item else {
            selectedImage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            selectedImage = try await photoService.loadImage(from: item)
        } catch {
            errorMessage = "Failed to load image: \(error.localizedDescription)"
            selectedImage = nil
        }

        isLoading = false
    }

    func clearSelection() {
        selectedPhotoItem = nil
        selectedImage = nil
        errorMessage = nil
    }
}
