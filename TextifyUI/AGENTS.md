# TextifyUI - AGENTS Knowledge Base

> SwiftUI presentation layer. MVVM, glassmorphism UI, shared components.

---

## Overview

SwiftUI-based UI module. `@_exported import TextifyKit`. 50+ files across features, services, shared components.

---

## Structure

```
TextifyUI/Sources/TextifyUI/
├── App/
│   └── AppDependencies.swift          # DI composition root
├── Features/                          # 9 feature modules (MVVM)
│   ├── Home/
│   ├── Main/
│   ├── Textify/                       # Main conversion UI
│   │   └── Components/
│   ├── ImageSelection/
│   ├── TextInput/
│   ├── Generation/
│   ├── Result/
│   ├── Settings/
│   └── History/
├── Services/                          # 8 app services
├── Shared/
│   ├── Components/                    # 13 reusable UI components
│   └── Theme/                         # AppTheme, ThemeEnvironment
├── Models/                            # UI models (HistoryEntry, AppError)
├── Utilities/
└── TextifyUI.swift                    # Module export
```

---

## Features

| Feature | Files | Purpose |
|---------|-------|---------|
| `Home` | HomeView, HomeViewModel | Entry, navigation hub |
| `Main` | MainView, MainViewModel | Main app container |
| `Textify` | TextifyView, TextifyViewModel, Components | Core conversion UI |
| `ImageSelection` | ImageSelectionView, ViewModel | Photo library / file picker |
| `TextInput` | TextInputView, ViewModel | Character palette input |
| `Generation` | GenerationView, ViewModel | Processing screen |
| `Result` | ResultView, ViewModel | Output display, actions |
| `Settings` | SettingsView, ViewModel | App preferences |
| `History` | HistoryView, HistoryViewModel, HistoryDetailView | Past conversions |

---

## Services

All services are actors or Sendable classes. Injected via `AppDependencies`.

| Service | Type | Purpose |
|---------|------|---------|
| `PhotoLibraryService` | actor | Photo library access |
| `FileImportService` | actor | File picker |
| `ClipboardService` | actor | Copy/paste |
| `ImageExportService` | actor | Save to photos |
| `HistoryService` | actor | Persistent history |
| `AppearanceService` | actor | Theme management |
| `HapticsService` | class ⚠️ | Haptic feedback (singleton) |
| `ImageValidationService` | actor | Image validation |

**⚠️ HapticsService:** Currently uses singleton pattern (`HapticsService.shared`). Migration to DI in progress.

---

## Shared Components

**Location:** `Shared/Components/`

| Component | Lines | Purpose |
|-----------|-------|---------|
| `MorphingToolbar` | 1056 | Glassmorphism toolbar with state morphing |
| `ControlBottomSheet` | 293 | Bottom sheet controls |
| `GlassCard` | - | Glassmorphism card container |
| `LoadingButton` | - | Button with loading state |
| `ValueSlider` | - | Labeled slider control |
| `ErrorBanner` | - | Error message display |
| `PreviewPanel` | - | Image/text preview |
| `HistoryCard` | - | History item display |
| `TypingEffectText` | - | Animated text reveal |
| `AnimatedGradient` | - | Background gradient |
| `FloatingToolbar` | - | Floating action bar |
| `ExpandableFloatingToolbar` | - | Expandable floating bar |
| `RetryView` | - | Error retry UI |

---

## Theme System

**Location:** `Shared/Theme/`

```swift
struct AppTheme {
    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12
}

// Glassmorphism
.background(.ultraThinMaterial)
.clipShape(RoundedRectangle(cornerRadius: 16))
```

---

## ViewModel Pattern

```swift
@Observable
@MainActor
public final class SomeViewModel {
    // State (plain var, not @Published)
    public var isLoading = false
    public var error: AppError?
    
    @ObservationIgnored
    private let service: SomeServicing
    
    init(service: SomeServicing) {
        self.service = service
    }
    
    func performAction() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await service.doWork()
        } catch {
            self.error = AppError(error)
        }
    }
}
```

---

## Navigation

**Pattern:** `NavigationStack` + `AppDestination` enum

```swift
enum AppDestination: Hashable {
    case imageSelection
    case textInput(ImageWrapper)
    case generation(ImageWrapper, String)
    case result(TextArtWrapper)
    case settings
    case history
}

// In View
NavigationStack(path: $viewModel.navigationPath) {
    HomeView()
        .navigationDestination(for: AppDestination.self) { destination in
            switch destination { ... }
        }
}
```

**Flow:** Home → ImageSelection → TextInput → Generation → Result

---

## Morphing Toolbar Pattern

**File:** `Shared/Components/MorphingToolbar.swift`

```swift
enum ToolbarState: String, CaseIterable, Sendable {
    case main, style, adjust, share
}

MorphingToolbar(state: $toolbarState) {
    // style content
} adjustContent: {
    // adjust content
} shareContent: {
    // share content
}
```

**Specs:**
- Fixed height: 76pt
- Animation: `spring(response: 0.4, dampingFraction: 0.75)`
- Asymmetric transitions
- Glassmorphism styling

---

## Error Handling

**Model:** `Models/AppError.swift`

```swift
public enum AppError: LocalizedError {
    case imageLoadFailed
    case generationFailed
    case exportFailed
    // ... (Korean messages)
}
```

**Pattern:**
```swift
do {
    try await operation()
} catch let error as AppError {
    viewModel.error = error
} catch {
    viewModel.error = .unknown
}
```

---

## Testing

**Location:** `Tests/TextifyUITests/`

```bash
cd TextifyUI && swift test
```

| Test | Focus |
|------|-------|
| TextifyViewModelTests | State transitions, debouncing |
| TextifyUITests | Module load |

### ViewModel Test Pattern
```swift
@Test("generateFinal uses debouncing")
@MainActor
func testGenerateFinalIsDebounced() async throws {
    let viewModel = TextifyViewModel(image: image, generator: mockGenerator)
    // Test async state changes
}
```

---

## Anti-Patterns (UI-Specific)

| ❌ Avoid | ✅ Correct |
|----------|------------|
| `@StateObject` | `@State` with `@Observable` VM |
| `@ObservedObject` | Direct property access |
| `DispatchQueue.main.async` | `@MainActor` |
| `HapticsService.shared` | Constructor injection |
| UIKit import (unless necessary) | SwiftUI only |

**Known Violations:**
- `HapticsService.shared` used in 9 files
- `DispatchQueue.main.async` in LoadingButton, HistoryCard, ErrorBanner, HistoryDetailView

---

## Adding New Feature

1. Create `Features/{Name}/` directory
2. Add `{Name}View.swift`:
   ```swift
   struct NewFeatureView: View {
       @State private var viewModel: NewFeatureViewModel
       init(viewModel: NewFeatureViewModel) { ... }
   }
   ```
3. Add `{Name}ViewModel.swift`:
   ```swift
   @Observable
   @MainActor
   public final class NewFeatureViewModel { ... }
   ```
4. Add factory to `AppDependencies.swift`:
   ```swift
   func makeNewFeatureViewModel() -> NewFeatureViewModel {
       NewFeatureViewModel(service: someService)
   }
   ```
5. Add `AppDestination` case if navigable
6. Add navigation from parent view

---

*See root AGENTS.md for project-wide conventions*
