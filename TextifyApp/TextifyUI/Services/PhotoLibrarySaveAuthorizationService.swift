import Foundation
#if canImport(Photos)
import Photos
#endif

/// Authorization states relevant to saving generated images to Photos.
public enum PhotoLibrarySaveAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case limited

    public var displayName: String {
        switch self {
        case .notDetermined:
            return "확인 전"
        case .restricted:
            return "제한됨"
        case .denied:
            return "거부됨"
        case .authorized:
            return "허용됨"
        case .limited:
            return "일부 허용"
        }
    }

    public var guidance: String {
        switch self {
        case .notDetermined:
            return "저장 버튼을 누를 때 사진 저장 권한을 요청합니다."
        case .restricted:
            return "이 기기에서는 사진 저장 권한이 제한되어 결과 이미지를 저장할 수 없습니다."
        case .denied:
            return "설정에서 사진 접근을 허용해야 결과 이미지를 저장할 수 있습니다."
        case .authorized:
            return "생성한 ASCII 결과 이미지를 사진 앱에 저장할 수 있습니다."
        case .limited:
            return "현재 권한으로 저장은 가능하지만, 사진 접근 범위는 제한될 수 있습니다."
        }
    }

    public var recommendsOpeningSettings: Bool {
        self == .denied
    }
}

/// OS-facing boundary for reading/requesting add-only photo library authorization.
public protocol PhotoLibrarySaveAuthorizing: Sendable {
    func currentStatus() -> PhotoLibrarySaveAuthorizationStatus
    func requestAuthorization() async -> PhotoLibrarySaveAuthorizationStatus
}

/// Real Photos framework adapter for photo-library save authorization.
public struct PhotoLibraryAuthorizationService: PhotoLibrarySaveAuthorizing, Sendable {
    public init() {}

    public func currentStatus() -> PhotoLibrarySaveAuthorizationStatus {
        #if canImport(Photos)
        return map(status: PHPhotoLibrary.authorizationStatus(for: .addOnly))
        #else
        return .restricted
        #endif
    }

    public func requestAuthorization() async -> PhotoLibrarySaveAuthorizationStatus {
        #if canImport(Photos)
        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: map(status: status))
            }
        }
        #else
        return .restricted
        #endif
    }

    #if canImport(Photos)
    private func map(status: PHAuthorizationStatus) -> PhotoLibrarySaveAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        @unknown default:
            return .restricted
        }
    }
    #endif
}

/// Permission gate used before saving a generated image to Photos.
public final class PhotoLibrarySaveAuthorizationService: Sendable {
    private let authorizer: any PhotoLibrarySaveAuthorizing

    public convenience init() {
        self.init(authorizer: PhotoLibraryAuthorizationService())
    }

    public init(authorizer: any PhotoLibrarySaveAuthorizing) {
        self.authorizer = authorizer
    }

    public func ensureAuthorized() async throws {
        let initialStatus = authorizer.currentStatus()
        let resolvedStatus: PhotoLibrarySaveAuthorizationStatus

        switch initialStatus {
        case .notDetermined:
            resolvedStatus = await authorizer.requestAuthorization()
        case .authorized, .limited, .restricted, .denied:
            resolvedStatus = initialStatus
        }

        switch resolvedStatus {
        case .authorized, .limited:
            return
        case .denied, .notDetermined:
            throw ImageExportError.permissionDenied
        case .restricted:
            throw ImageExportError.permissionRestricted
        }
    }
}
