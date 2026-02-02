# TextifyKit - AGENTS Knowledge Base

> Core engine module. 이미지→텍스트 아트 변환 알고리즘, Metal 가속, 애니메이션.

---

## Overview

Zero-dependency core library. Actor-based concurrency, Metal GPU acceleration, text art generation pipeline.

---

## Structure

```
TextifyKit/Sources/TextifyKit/
├── Models/              # Data models (Sendable, Codable)
├── Services/            # Actor-based business logic
├── Protocols/           # Service abstractions (Sendable)
├── Metal/               # GPU acceleration (Metal shaders)
├── Animation/           # Text animation effects
├── Pattern/             # Pattern generators (repeat, gradient, etc.)
├── Export/              # Output formats (GIF, video, live photo)
├── Adapters/            # Model adapters
└── TextifyKit.swift     # Module export
```

---

## Key Components

### Models
| Model | Purpose |
|-------|---------|
| `TextArt` | Generated ASCII art result (rows, width, height) |
| `TextArtPro` | Pro version with metadata |
| `ProcessingOptions` | Conversion settings (width, contrast, invert) |
| `CharacterPalette` | Character set for mapping |
| `GrayscalePixelBuffer` | Processed pixel data |
| `ColorPalette` | Color extraction |

### Services (Actors)
| Service | Responsibility |
|---------|----------------|
| `TextArtGenerator` | Main orchestration, caching |
| `ImageProcessor` | CGImage → GrayscalePixelBuffer |
| `CharacterMapper` | Luminance → Character mapping |

### Protocols
```swift
public protocol TextArtGenerating: Sendable {
    func generate(from image: CGImage, palette: CharacterPalette, options: ProcessingOptions) async throws -> TextArt
}

public protocol ImageProcessing: Sendable {
    func grayscalePixels(from image: CGImage, maxWidth: Int, aspectCorrection: Float) async throws -> GrayscalePixelBuffer
}
```

---

## Pipeline

```
CGImage
    ↓ (1) ImageProcessor.grayscalePixels()
GrayscalePixelBuffer
    ↓ (2) Apply ProcessingOptions (contrast, invert)
Processed Pixels
    ↓ (3) CharacterMapper.mapToCharacter()
TextArt
```

### Brightness Calculation (ITU-R BT.601)
```swift
func calculateLuminance(r: UInt8, g: UInt8, b: UInt8) -> Float {
    return 0.299 * Float(r) + 0.587 * Float(g) + 0.114 * Float(b)
}
```

### Character Mapping
```swift
func mapToCharacter(luminance: Float, palette: CharacterPalette, options: ProcessingOptions) -> Character {
    // 1. Apply contrast
    // 2. Apply invert if needed
    // 3. Map to palette index
    let normalized = adjusted / 255.0
    let index = Int(normalized * Float(palette.characters.count - 1))
    return palette.characters[index]
}
```

---

## Metal Acceleration

**Location:** `Metal/` directory

| File | Purpose |
|------|---------|
| `MetalContext.swift` | Device/context management |
| `MetalShaderSource.swift` | Shader source strings |
| `GlyphRenderer.swift` | GPU glyph rendering |
| `TransformState.swift` | Transform state management |

**Critical Note:** SPM packages cannot use `makeDefaultLibrary()`. Shaders compiled from source strings at runtime.

---

## Animation System

**Location:** `Animation/` directory

| Animation | Effect |
|-----------|--------|
| `TypingAnimation` | Character-by-character reveal |
| `WaveAnimation` | Sine wave distortion |
| `MorphAnimation` | Shape morphing |
| `GlitchAnimation` | Digital glitch effects |

---

## Export Formats

**Location:** `Export/` directory

| Exporter | Output |
|----------|--------|
| `GIFExporter` | Animated GIF |
| `VideoExporter` | Video file |
| `LivePhotoExporter` | iOS Live Photo |
| `FrameCapturer` | Frame sequence |

---

## Testing

**Location:** `Tests/TextifyKitTests/`

```bash
cd TextifyKit && swift test
```

| Test Category | Files |
|---------------|-------|
| Models | TextArt, CharacterPalette, GrayscalePixelBuffer, etc. |
| Services | TextArtGenerator, ImageProcessor, CharacterMapper |
| Mocks | MockImageProcessor |

### Mock Pattern
```swift
final class MockImageProcessor: ImageProcessing, @unchecked Sendable {
    private(set) var grayscalePixelsCallCount = 0
    var stubbedResult: GrayscalePixelBuffer?
    var stubbedError: ImageProcessingError?
    
    func reset() { ... }
}
```

---

## Anti-Patterns (Kit-Specific)

| ❌ Avoid | ✅ Correct |
|----------|------------|
| `class` for stateful services | `actor` |
| Synchronous image processing | `async` actor methods |
| Direct CGImage manipulation | Use ImageProcessor protocol |
| Hardcoded palette strings | Use CharacterPalette presets |

---

## Performance Targets

| Image Size | Target Time |
|------------|-------------|
| 640x480 | < 50ms |
| 1920x1080 | < 300ms |
| 4K | < 1000ms |

**Optimization:** Metal GPU acceleration for 25-40x performance gain.

---

*See root AGENTS.md for project-wide conventions*
