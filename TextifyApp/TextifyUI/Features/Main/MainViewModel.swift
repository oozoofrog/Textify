import Foundation
import SwiftUI
import PhotosUI
import CoreGraphics

/// 메인 화면 ViewModel
@Observable
@MainActor
public final class MainViewModel {
    public private(set) var selectedImage: CGImage?
    public private(set) var isLoading = false
    public var errorMessage: String?
    private let photoLibraryService: any PhotoLibraryLoading
    private var loadRequestID = UUID()
    private var loadingTask: Task<CGImage, Error>?

    public init(photoLibraryService: any PhotoLibraryLoading) {
        self.photoLibraryService = photoLibraryService
    }

    /// Returns true only when this request published the current selection.
    @discardableResult
    public func loadImage(from item: PhotosPickerItem?) async -> Bool {
        guard let item else { return false }
        let service = photoLibraryService
        return await loadImage { try await service.loadImage(from: item) }
    }

    @discardableResult
    public func loadImage(fromFile url: URL) async -> Bool {
        let service = photoLibraryService
        return await loadImage { try await service.loadImage(fromFile: url) }
    }

    private func loadImage(
        operation: @escaping @Sendable () async throws -> CGImage
    ) async -> Bool {
        guard !Task.isCancelled else { return false }
        loadingTask?.cancel()
        let requestID = UUID()
        loadRequestID = requestID
        isLoading = true
        errorMessage = nil
        selectedImage = nil
        let task = Task { try await operation() }
        loadingTask = task
        defer {
            if requestID == loadRequestID {
                isLoading = false
                loadingTask = nil
            }
        }

        do {
            let image = try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            try Task.checkCancellation()
            guard requestID == loadRequestID else { return false }
            selectedImage = image
            return true
        } catch {
            guard requestID == loadRequestID else { return false }
            guard !Task.isCancelled,
                  !(error is CancellationError),
                  (error as? CocoaError)?.code != .userCancelled else { return false }
            errorMessage = (error as? PhotoLibraryError).map(message(for:))
                ?? "이미지를 불러올 수 없습니다."
            return false
        }
    }

    public func clearSelection() {
        loadRequestID = UUID()
        loadingTask?.cancel()
        loadingTask = nil
        isLoading = false
        selectedImage = nil
        errorMessage = nil
    }

    private func message(for error: PhotoLibraryError) -> String {
        switch error {
        case .loadFailed:
            return "사진을 불러오지 못했습니다."
        case .fileLoadFailed:
            return "파일을 읽지 못했습니다. 파일 위치와 접근 권한을 확인해 주세요."
        case .invalidImageData, .cgImageCreationFailed:
            return "선택한 이미지를 처리할 수 없습니다."
        }
    }
}
