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

**IMPORTANT: 이 프로젝트는 반드시 xcodebuild로 빌드해야 합니다. 루트에 Package.swift가 없습니다.**

```bash
# 전체 앱 빌드 (권장)
cd /Volumes/eyedisk/develop/oozoofrog/Textify/TextifyApp && xcodebuild -scheme TextifyApp -destination 'platform=iOS Simulator,name=iPhone 17' build

# 테스트 실행 (TextifyKit)
cd /Volumes/eyedisk/develop/oozoofrog/Textify/TextifyApp && xcodebuild -scheme TextifyApp -destination 'platform=iOS Simulator,name=iPhone 17' test

# 빌드 에러만 확인 (빠름)
cd /Volumes/eyedisk/develop/oozoofrog/Textify/TextifyApp && xcodebuild -scheme TextifyApp -destination 'platform=iOS Simulator,name=iPhone 17' build 2>&1 | grep -E "(error:|warning:)" | head -20
```

### 빌드 시스템 주의사항
- **swift build 사용 금지**: 루트에 Package.swift 없음
- **xcodebuild 필수**: TextifyApp.xcodeproj 사용
- SPM 패키지(TextifyKit, TextifyUI)는 Xcode 프로젝트에서 로컬 패키지로 참조됨

---

## 9. Swift 6 Anti-Pattern Checklist

### ❌ 사용 금지 패턴

| 패턴 | 문제 | 대안 |
|------|------|------|
| `@StateObject` | iOS 17+ deprecated | `@State` with `@Observable` |
| `@ObservedObject` | iOS 17+ deprecated | Direct property access |
| `@Published` in `@Observable` | 중복, 불필요 | Plain `var` |
| `DispatchQueue.main.async` | Legacy GCD | `@MainActor` |
| `DispatchQueue.global().async` | Legacy GCD | `Task { }` |
| `semaphore.wait()` | Blocking | Actor isolation |
| `Task.detached { }` | Context 손실 | `Task { }` |
| `nonisolated(unsafe)` | 안전하지 않음 | Proper isolation |
| `@unchecked Sendable` | 컴파일러 우회 | Make truly Sendable |
| Singleton `shared` | 테스트 어려움 | DI via Composition Root |

### ✅ 사용 권장 패턴

| 상황 | 권장 패턴 |
|------|----------|
| ViewModel 상태 | `@Observable @MainActor final class` |
| View-owned state | `@State private var vm = ViewModel()` |
| Passed state | Direct property (no wrapper) |
| Environment DI | `@Environment(AppDependencies.self)` |
| Shared mutable state | `actor` |
| Background work | `Task { await ... }` |
| Main thread work | `@MainActor` or `MainActor.run { }` |
| Value types | `struct` (auto-Sendable) |

### Concurrency Decision Tree

```
데이터 공유 필요?
├─ No → 일반 async/await
└─ Yes → 여러 Task에서 접근?
         ├─ No → 단일 Task 내 처리
         └─ Yes → 가변 상태?
                  ├─ No → Struct (자동 Sendable)
                  └─ Yes → Actor 사용
                           └─ UI 관련? → @MainActor
```

---

## 10. Testing Guidelines

### Test Structure

```
TextifyKit/Tests/TextifyKitTests/
├── Models/
│   ├── CharacterPaletteTests.swift
│   ├── GrayscalePixelBufferTests.swift
│   ├── ProcessingOptionsTests.swift
│   └── TextArtTests.swift
├── Services/
│   ├── CharacterMapperTests.swift
│   ├── ImageProcessorTests.swift
│   └── TextArtGeneratorTests.swift
└── Mocks/
    └── MockImageProcessor.swift
```

### Swift Testing Framework (권장)

```swift
import Testing

@Test("TextArt 생성 성공")
func testTextArtGeneration() async throws {
    let generator = TextArtGenerator(imageProcessor: MockImageProcessor())
    let palette = CharacterPalette(characters: ["@", "#", " "])
    let options = ProcessingOptions(outputWidth: 40)

    let result = try await generator.generate(
        from: mockImage,
        palette: palette,
        options: options
    )

    #expect(result.width == 40)
    #expect(!result.rows.isEmpty)
}

@Test("잘못된 팔레트 에러", .tags(.validation))
func testInvalidPalette() async {
    let generator = TextArtGenerator()
    let emptyPalette = CharacterPalette(characters: [])

    await #expect(throws: TextArtGenerationError.invalidPalette) {
        try await generator.generate(
            from: mockImage,
            palette: emptyPalette,
            options: .default
        )
    }
}
```

### Test Doubles Strategy

| Type | 용도 | 예시 |
|------|------|------|
| **Fake** | 실제 구현의 간단한 버전 | `FakeHistoryService` (in-memory) |
| **Mock** | Protocol 기반 대체 | `MockImageProcessor` |
| **Stub** | 고정 반환값 | `StubPhotoLibrary` |

### Mock 작성 패턴

```swift
// Protocol 정의 (TextifyKit)
public protocol ImageProcessing: Sendable {
    func grayscalePixels(from: CGImage, ...) async throws -> GrayscalePixelBuffer
}

// Mock 구현 (Tests)
final class MockImageProcessor: ImageProcessing, @unchecked Sendable {
    var stubbedResult: GrayscalePixelBuffer?
    var shouldThrow: ImageProcessingError?

    func grayscalePixels(from: CGImage, ...) async throws -> GrayscalePixelBuffer {
        if let error = shouldThrow { throw error }
        return stubbedResult ?? GrayscalePixelBuffer(width: 10, height: 10, pixels: [])
    }
}
```

### ViewModel 테스트 패턴

```swift
@Test("Generation 성공 시 상태 업데이트")
@MainActor
func testGenerationSuccess() async {
    let mockGenerator = MockTextArtGenerator()
    mockGenerator.stubbedResult = TextArt.mock

    let viewModel = GenerationViewModel(generator: mockGenerator)

    await viewModel.generate(from: mockImage, characters: "@# ")

    #expect(viewModel.isGenerating == false)
    #expect(viewModel.generatedTextArt != nil)
    #expect(viewModel.errorMessage == nil)
}
```

### Test Coverage Goals

| Layer | Target | Focus |
|-------|--------|-------|
| TextifyKit | 80%+ | Models, Services |
| TextifyUI ViewModels | 70%+ | State transitions, error handling |
| TextifyUI Services | 60%+ | Happy path + edge cases |
| Views | Snapshot only | Visual regression |

---

## 11. Code Review Checklist

### PR 리뷰 시 확인 사항

- [ ] `@Observable` 사용 (not `ObservableObject`)
- [ ] ViewModel은 `@MainActor` 적용
- [ ] Actor 경계 넘는 타입은 `Sendable`
- [ ] 새 Service는 Protocol 추상화
- [ ] 새 ViewModel Factory는 `AppDependencies`에 추가
- [ ] 에러 처리 및 사용자 피드백
- [ ] 테스트 추가됨
