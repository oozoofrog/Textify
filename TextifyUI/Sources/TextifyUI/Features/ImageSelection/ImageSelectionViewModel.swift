import Foundation
import SwiftUI
import CoreGraphics
import PhotosUI

/// ViewModel for the image selection screen
@Observable
@MainActor
public final class ImageSelectionViewModel {
    private let photoService: PhotoLibraryService

    public var selectedPhotoItem: PhotosPickerItem?
    public var selectedImage: CGImage?
    public var isLoading = false
    public var errorMessage: String?

    public init(photoService: PhotoLibraryService) {
        self.photoService = photoService
    }

    public func loadImage(from item: PhotosPickerItem?) async {
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

    public func clearSelection() {
        selectedPhotoItem = nil
        selectedImage = nil
        errorMessage = nil
    }
}
