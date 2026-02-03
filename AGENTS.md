# Textify iOS - AGENTS Knowledge Base

> Swift 6.2 + SwiftUI + MVVM. 이미지→텍스트 아트 변환 iOS 앱.

---

## Quick Reference

| Module | Path | Purpose |
|--------|------|---------|
| **TextifyKit** | `TextifyKit/` | Core engine (actor-based, Metal, zero deps) |
| **TextifyUI** | `TextifyUI/` | SwiftUI layer (@_exported TextifyKit) |
| **TextifyApp** | `TextifyApp/` | Xcode app entry (1 file) |

**Build:**
```bash
# Full app build
cd TextifyApp && xcodebuild -scheme TextifyApp -destination 'platform=iOS Simulator,name=iPhone 17' build

# Test TextifyKit
cd TextifyApp && xcodebuild -scheme TextifyKit -destination 'platform=iOS Simulator,name=iPhone 17' test
```

**Docs:**
- `docs/PRODUCT_SPEC.md` - 제품 기획서
- `docs/DESIGN_SYSTEM.md` - 디자인 시스템
- `docs/DEVELOPMENT_GUIDE.md` - 알고리즘/아키텍처

---

## Architecture

```
TextifyApp (Xcode)
    ↓ imports
TextifyUI (SPM, 50 files)
    ↓ @_exported import TextifyKit
TextifyKit (SPM, 32 files, zero deps)
```

| Layer | Pattern | Key Tech |
|-------|---------|----------|
| **State** | `@Observable` macro | SwiftUI native |
| **DI** | Pure DI | `AppDependencies` (Composition Root) |
| **Concurrency** | Swift 6 actors | `@MainActor` VM, `actor` services |
| **Navigation** | Enum-based | `NavigationStack` + `AppDestination` |

---

## Module Boundaries

### TextifyKit (Core)
- **Models:** TextArt, ProcessingOptions, CharacterPalette, GrayscalePixelBuffer
- **Protocols:** TextArtGenerating, ImageProcessing (Sendable)
- **Services:** TextArtGenerator (actor), ImageProcessor (actor), CharacterMapper
- **Pipeline:** `CGImage → ImageProcessor → GrayscalePixelBuffer → CharacterMapper → TextArt`
- **Tests:** 13 files (Models/, Services/, Mocks/)

### TextifyUI (Presentation)
- **App/:** AppDependencies.swift (DI composition root)
- **Features/ (9):** Home, Main, Textify, ImageSelection, TextInput, Generation, Result, Settings, History
- **Services/ (8):** PhotoLibrary, FileImport, Clipboard, ImageExport, History (actor), Appearance, Haptics, ImageValidation
- **Shared/Components/ (13):** MorphingToolbar (1056L), GlassCard, etc.
- **Shared/Theme/:** AppTheme, ThemeEnvironment

---

## Patterns

### ViewModel
```swift
@Observable
@MainActor
public final class SomeViewModel {
    @ObservationIgnored
    private let service: SomeServicing
    
    init(service: SomeServicing) { ... }  // Constructor injection
}
```

### Service
```swift
public protocol SomeServicing: Sendable {
    func doWork() async throws
}

public actor SomeService: SomeServicing { ... }
```

### View
```swift
struct SomeView: View {
    @State private var viewModel: SomeViewModel
    
    init(viewModel: SomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }
}
```

### Navigation
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

---

## Anti-Patterns (DO NOT)

| ❌ Forbidden | Reason | ✅ Correct |
|-------------|--------|----------|
| `HapticsService.shared` | Singleton breaks DI | Constructor inject |
| `@StateObject` | Deprecated iOS 17+ | `@State` with `@Observable` VM |
| `@ObservedObject` | Deprecated iOS 17+ | Direct property access |
| `@Published` in `@Observable` | Redundant | Plain `var` |
| `DispatchQueue.main.async` | Legacy GCD | `@MainActor` |
| `DispatchQueue.global().async` | Legacy GCD | `Task { }` |
| `Task.detached { }` | Context loss | `Task { }` |
| `nonisolated(unsafe)` | Unsafe | Proper isolation |
| `@unchecked Sendable` | Compiler bypass | Make truly Sendable |
| `class` for services | Thread-unsafe | `actor` |
| `UIKit import` | Project rule | SwiftUI only |

**Known Violations:**
- `HapticsService.shared` used in 9 files (migration in progress)
- `@unchecked Sendable` in FrameCapturer, MockImageProcessor
- `@Published` in TransformState, TextAnimation (legacy)
- `DispatchQueue.main.async` in 4 UI components

---

## Adding Features

### New Feature
1. `TextifyUI/Sources/TextifyUI/Features/{Name}/` 디렉토리 생성
2. `{Name}View.swift` + `{Name}ViewModel.swift` 생성
3. `AppDependencies.swift`에 factory method 추가
4. `AppDestination`에 case 추가 (if navigable)
5. `HomeView`에 navigation 연결

### New Service
1. `TextifyUI/Sources/TextifyUI/Services/{Name}Service.swift` 생성
2. Protocol 정의 (`{Name}Servicing: Sendable`)
3. `AppDependencies`에 인스턴스 추가
4. 필요한 ViewModel에 주입

### New Model (TextifyKit)
1. `TextifyKit/Sources/TextifyKit/Models/`에 추가
2. `Sendable` 준수 확인
3. Tests 추가

---

## Testing

```bash
# TextifyKit tests
cd TextifyApp && xcodebuild -scheme TextifyKit -destination 'platform=iOS Simulator,name=iPhone 17' test

# Full test
cd TextifyApp && xcodebuild -scheme TextifyApp -destination 'platform=iOS Simulator,name=iPhone 17' test
```

| Layer | Target | Focus |
|-------|--------|-------|
| TextifyKit | 80%+ | Models, Services |
| TextifyUI VM | 70%+ | State transitions |
| TextifyUI Services | 60%+ | Happy path + edges |
| Views | Snapshot | Visual regression |

### Test Pattern (Swift Testing)
```swift
import Testing

@Test("Generation success")
func testGeneration() async throws {
    let mock = MockImageProcessor()
    mock.stubbedResult = GrayscalePixelBuffer(...)
    
    let generator = TextArtGenerator(imageProcessor: mock)
    let result = try await generator.generate(...)
    
    #expect(result.width == expectedWidth)
}
```

---

## Code Review Checklist

- [ ] `@Observable` (not `ObservableObject`)
- [ ] `@MainActor` on ViewModels
- [ ] `Sendable` for cross-actor types
- [ ] Protocol abstraction for services
- [ ] Factory method in `AppDependencies`
- [ ] Error handling + user feedback
- [ ] Tests included
- [ ] No singleton `.shared` usage

---

## Constraints

- **iOS 26.0+** (Swift 6.2)
- **SwiftUI only** (no UIKit)
- **Zero 3rd-party dependencies**
- **한국어 에러 메시지** (`AppError`)
- **xcodebuild only** (root has no Package.swift)

---

## Build System

**Hybrid SPM + Xcode:**
- `TextifyKit/Package.swift` - Core SPM package
- `TextifyUI/Package.swift` - UI SPM package (depends on TextifyKit)
- `TextifyApp/project.yml` - XcodeGen spec (generates .xcodeproj)

**Key Files:**
| Purpose | Path |
|---------|------|
| DI Root | `TextifyUI/Sources/TextifyUI/App/AppDependencies.swift` |
| Navigation | `TextifyUI/Sources/TextifyUI/Features/Home/HomeViewModel.swift` |
| Generation Engine | `TextifyKit/Sources/TextifyKit/Services/TextArtGenerator.swift` |
| History | `TextifyUI/Sources/TextifyUI/Services/HistoryService.swift` |
| Theme | `TextifyUI/Sources/TextifyUI/Shared/Theme/AppTheme.swift` |
| Main UI | `TextifyUI/Sources/TextifyUI/Features/Textify/TextifyView.swift` |
| Main VM | `TextifyUI/Sources/TextifyUI/Features/Textify/TextifyViewModel.swift` |

---

## UI Patterns

### Morphing Toolbar
**Pattern:** Inline transformation (no overlays/popups)

```swift
enum ToolbarState: String, CaseIterable, Sendable {
    case main, style, adjust, share
}

MorphingToolbar(state: $toolbarState) {
    styleContent
} adjustContent: {
    adjustContent
} shareContent: {
    shareContent
}
```

**Animation Spec:**
```swift
Animation.spring(response: 0.4, dampingFraction: 0.75)

.transition(.asymmetric(
    insertion: .scale(scale: 1.05).combined(with: .opacity),
    removal: .scale(scale: 0.95).combined(with: .opacity)
))
```

**Design Tokens:**
- Fixed height: 76pt (prevents layout jumps)
- Glassmorphism: ultra-thin material + 20% white border + shadow
- Back button: 90pt fixed width for layout stability

---

*Generated: 2026-02-02 | See subdir AGENTS.md for module details*
