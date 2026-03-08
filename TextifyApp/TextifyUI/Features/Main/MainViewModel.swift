import Foundation
import SwiftUI
import PhotosUI
import CoreGraphics
import TextifyKit

/// 메인 화면 ViewModel
@Observable
@MainActor
public final class MainViewModel {
    public var selectedImage: CGImage?
    public var isLoading = false
    public var errorMessage: String?

    let generator: TextArtGenerator

    public init(generator: TextArtGenerator) {
        self.generator = generator
    }

    public func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }

        isLoading = true
        errorMessage = nil

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ImageError.loadFailed
            }

            guard let uiImage = UIImage(data: data),
                  let cgImage = uiImage.cgImage else {
                throw ImageError.invalidFormat
            }

            selectedImage = cgImage
        } catch {
            errorMessage = "이미지를 불러올 수 없습니다: \(error.localizedDescription)"
            selectedImage = nil
        }

        isLoading = false
    }

    public func clearSelection() {
        selectedImage = nil
        errorMessage = nil
    }
}

enum ImageError: LocalizedError {
    case loadFailed
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .loadFailed:
            return "이미지를 불러오는데 실패했습니다"
        case .invalidFormat:
            return "지원하지 않는 이미지 형식입니다"
        }
    }
}
