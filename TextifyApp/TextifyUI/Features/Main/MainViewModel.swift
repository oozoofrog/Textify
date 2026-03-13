import Foundation
import SwiftUI
import PhotosUI
import CoreGraphics

/// 메인 화면 ViewModel
@Observable
@MainActor
public final class MainViewModel {
    public var selectedImage: CGImage?
    public var isLoading = false
    public var errorMessage: String?
    private let photoLibraryService: PhotoLibraryService

    public init(photoLibraryService: PhotoLibraryService) {
        self.photoLibraryService = photoLibraryService
    }

    public func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoading = true
        errorMessage = nil

        do {
            selectedImage = try await photoLibraryService.loadImage(from: item)
        } catch let error as PhotoLibraryError {
            errorMessage = message(for: error)
            selectedImage = nil
        } catch {
            errorMessage = "이미지를 불러올 수 없습니다."
            selectedImage = nil
        }

        isLoading = false
    }

    public func clearSelection() {
        selectedImage = nil
        errorMessage = nil
    }

    private func message(for error: PhotoLibraryError) -> String {
        switch error {
        case .loadFailed:
            return "사진을 불러오지 못했습니다."
        case .invalidImageData, .cgImageCreationFailed:
            return "선택한 이미지를 처리할 수 없습니다."
        }
    }
}
