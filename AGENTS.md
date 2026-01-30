# Textify iOS App - Architecture Overview

> AI 에이전트 및 개발자를 위한 코드베이스 컨텍스트 문서

---

## Module Structure

```
TextifyApp (Xcode iOS Project)
    ↓ imports
TextifyUI (SPM Library) - 37 files
    ↓ imports (@_exported)
TextifyKit (SPM Library) - 21 files
```

**Dependency Flow:** TextifyApp → TextifyUI → TextifyKit (단방향)

---

## Architecture Pattern: MVVM + Pure DI

| 패턴 | 구현 |
|------|------|
| **State Management** | SwiftUI `@Observable` macro |
| **Dependency Injection** | Pure DI via `AppDependencies` (Composition Root) |
| **Concurrency** | Swift 6 actors + async/await |
| **Navigation** | NavigationStack + enum-based destinations |

---

## 1. TextifyKit (Core Logic)

**경로:** `/TextifyKit/Sources/TextifyKit/`

### Models
| Type | Purpose |
|------|---------|
| `TextArt` | 생성된 텍스트 아트 결과 |
| `ProcessingOptions` | 생성 파라미터 (width, contrast, invert) |
| `CharacterPalette` | 문자 팔레트 (dark→light) |
| `GrayscalePixelBuffer` | 처리된 픽셀 데이터 |

### Protocols
| Protocol | Implementation |
|----------|----------------|
| `TextArtGenerating` | `TextArtGenerator` (actor) |
| `ImageProcessing` | `ImageProcessor` (actor) |

### Services
| Service | Type | Responsibility |
|---------|------|----------------|
| `TextArtGenerator` | actor | 이미지→텍스트 변환 파이프라인 |
| `ImageProcessor` | actor | CGImage → grayscale 변환 |
| `CharacterMapper` | struct | 픽셀→문자 매핑 |

**Generation Pipeline:**
```
CGImage → ImageProcessor → GrayscalePixelBuffer → CharacterMapper → TextArt
```

---

## 2. TextifyUI (UI Layer)

**경로:** `/TextifyUI/Sources/TextifyUI/`

### Features (MVVM)
| Feature | Files | 역할 |
|---------|-------|------|
| Home | HomeView, HomeViewModel | 네비게이션 루트 |
| ImageSelection | View + ViewModel | 사진 선택 |
| TextInput | View + ViewModel | 문자 팔레트 입력 |
| Generation | View + ViewModel | 텍스트 아트 생성 |
| Result | View + ViewModel | 결과 표시/내보내기 |
| Settings | View + ViewModel | 앱 설정 |
| History | 3 Views + ViewModel | 히스토리 관리 |

### Services (8개)
| Service | 역할 |
|---------|------|
| `PhotoLibraryService` | PhotosUI 통합 |
| `FileImportService` | 파일 가져오기 |
| `ClipboardService` | 클립보드 복사 |
| `ImageExportService` | 이미지 저장 |
| `HistoryService` | JSON 기반 히스토리 (actor) |
| `AppearanceService` | 다크/라이트 모드 |
| `HapticsService` | 햅틱 피드백 |
| `ImageValidationService` | 이미지 검증 |

### Shared Components (8개)
`GlassCard`, `LoadingButton`, `ErrorBanner`, `ValueSlider`, `AnimatedGradient`, `PreviewPanel`, `HistoryCard`, `RetryView`

### App
| File | 역할 |
|------|------|
| `AppDependencies.swift` | Composition Root - 모든 서비스/VM 팩토리 |

---

## 3. TextifyApp (Entry Point)

**경로:** `/TextifyApp/TextifyApp/Sources/App/`

```swift
@main
struct TextifyApp: App {
    @State private var dependencies = AppDependencies()

    var body: some Scene {
        WindowGroup {
            HomeView(viewModel: dependencies.makeHomeViewModel())
                .environment(dependencies)
        }
    }
}
```

**파일 수:** 1개 (TextifyApp.swift만)

---

## 4. Navigation

```swift
enum AppDestination: Hashable {
    case imageSelection
    case textInput(ImageWrapper)
    case generation(ImageWrapper, String)
    case result(TextArtWrapper)
    case settings
    case history
}
```

**Flow:**
```
Home → ImageSelection → TextInput → Generation → Result
  ↓           ↑
Settings   History
```

---

## 5. Data Flow

```
User Action
    ↓
ViewModel (async method)
    ↓
Service (actor-isolated)
    ↓
TextifyKit (core processing)
    ↓
Result → @Observable state → SwiftUI re-render
```

---

## 6. Key Files

| 파일 | 역할 |
|------|------|
| `AppDependencies.swift` | DI Composition Root |
| `HomeViewModel.swift` | 네비게이션 관리 |
| `TextArtGenerator.swift` | 핵심 생성 로직 |
| `HistoryService.swift` | 히스토리 저장 |
| `AppTheme.swift` | UI 테마 상수 |

---

## 7. Development Guidelines

### 새 기능 추가
1. `Features/`에 View + ViewModel 쌍 생성
2. `AppDependencies`에 팩토리 메서드 추가
3. `AppDestination`에 케이스 추가
4. `HomeView`에 네비게이션 연결

### 새 서비스 추가
1. `Services/`에 서비스 파일 생성
2. 프로토콜 정의 (테스트 용이성)
3. `AppDependencies`에 인스턴스 추가
4. 필요한 ViewModel에 주입

### Concurrency 규칙
- **Core 로직:** `actor` 사용
- **ViewModel:** `@MainActor` + `@Observable`
- **모든 타입:** `Sendable` 준수

---

## 8. Constraints

- **iOS 26.0+** (Swift 6.2)
- **SwiftUI only** (no UIKit views)
- **Zero 3rd-party dependencies**
- **한국어 에러 메시지** (`AppError`)

---

## Quick Commands

```bash
# TextifyKit 빌드
cd TextifyKit && swift build

# TextifyUI 빌드 (iOS Simulator)
cd TextifyUI && swift build --sdk $(xcrun --sdk iphonesimulator --show-sdk-path) --triple arm64-apple-ios26.0-simulator

# TextifyApp 빌드
cd TextifyApp && xcodebuild -scheme TextifyApp -destination 'platform=iOS Simulator,name=iPhone 17' build
```
