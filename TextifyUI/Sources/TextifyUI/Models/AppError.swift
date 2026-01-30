import Foundation

public enum AppError: LocalizedError, Sendable {
    case imageLoad(underlying: Error?)
    case generation(underlying: Error?)
    case export(underlying: Error?)
    case clipboard
    case fileAccess
    case timeout
    case validation(String)

    public var errorDescription: String? {
        switch self {
        case .imageLoad(let underlying):
            if let error = underlying {
                return "이미지 로드 실패: \(error.localizedDescription)"
            }
            return "이미지를 로드할 수 없습니다"
        case .generation(let underlying):
            if let error = underlying {
                return "텍스트 아트 생성 실패: \(error.localizedDescription)"
            }
            return "텍스트 아트를 생성할 수 없습니다"
        case .export(let underlying):
            if let error = underlying {
                return "내보내기 실패: \(error.localizedDescription)"
            }
            return "파일을 내보낼 수 없습니다"
        case .clipboard:
            return "클립보드 복사 실패"
        case .fileAccess:
            return "파일 접근 권한이 없습니다"
        case .timeout:
            return "작업 시간이 초과되었습니다"
        case .validation(let message):
            return "입력값 검증 실패: \(message)"
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .imageLoad:
            return "다른 이미지를 선택해보세요. 지원되는 형식: PNG, JPEG, HEIC"
        case .generation:
            return "설정을 조정하거나 다시 시도해보세요"
        case .export:
            return "저장 위치를 확인하고 다시 시도해보세요"
        case .clipboard:
            return "클립보드 권한을 확인하고 다시 시도해보세요"
        case .fileAccess:
            return "설정에서 파일 접근 권한을 허용해주세요"
        case .timeout:
            return "네트워크 연결을 확인하거나 나중에 다시 시도해보세요"
        case .validation:
            return "입력값을 확인하고 다시 시도해보세요"
        }
    }

    public var isRetryable: Bool {
        switch self {
        case .imageLoad, .generation, .export, .clipboard, .timeout:
            return true
        case .fileAccess, .validation:
            return false
        }
    }
}
