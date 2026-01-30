# Textify - 개발 가이드

> 핵심 알고리즘 및 구현 가이드

---

## 1. 아키텍처 개요

### 1.1 모듈 구조

```
TextifyApp (iOS App)
    ↓ imports
TextifyUI (SwiftUI Layer)
    ↓ imports
TextifyKit (Core Logic)
```

### 1.2 의존성 방향

```
View → ViewModel → Service → Core
  ↑
AppDependencies (DI Container)
```

---

## 2. 핵심 알고리즘

### 2.1 이미지 → 텍스트 변환 파이프라인

```
CGImage
    ↓ (1) Resize
GrayscalePixelBuffer
    ↓ (2) Apply Options (contrast, invert)
ProcessedPixels
    ↓ (3) Map to Characters
TextArt
```

### 2.2 밝기 계산 (ITU-R BT.601)

```swift
// ImageProcessor.swift
func calculateLuminance(r: UInt8, g: UInt8, b: UInt8) -> Float {
    return 0.299 * Float(r) + 0.587 * Float(g) + 0.114 * Float(b)
}
```

### 2.3 문자 매핑

```swift
// CharacterMapper.swift
func mapToCharacter(
    luminance: Float,  // 0-255
    palette: CharacterPalette,
    options: ProcessingOptions
) -> Character {
    // 1. 대비 적용
    var adjusted = luminance
    if options.contrastBoost != 1.0 {
        adjusted = ((luminance / 255.0 - 0.5) * options.contrastBoost + 0.5) * 255.0
        adjusted = max(0, min(255, adjusted))
    }

    // 2. 반전 적용
    if options.invertBrightness {
        adjusted = 255 - adjusted
    }

    // 3. 문자 인덱스 계산
    let normalized = adjusted / 255.0
    let index = Int(normalized * Float(palette.characters.count - 1))
    return palette.characters[index]
}
```

### 2.4 종횡비 보정

```swift
// ImageProcessor.swift
func calculateOutputDimensions(
    imageWidth: Int,
    imageHeight: Int,
    targetWidth: Int,
    aspectCorrection: Float = 0.5  // 문자 높이/너비 비율
) -> (width: Int, height: Int) {
    let imageAspect = Float(imageWidth) / Float(imageHeight)
    let outputHeight = Int(Float(targetWidth) / imageAspect * aspectCorrection)
    return (targetWidth, outputHeight)
}
```

---

## 3. 고급 알고리즘 (Phase 2+)

### 3.1 Floyd-Steinberg 디더링

```swift
/// 오차 확산 디더링으로 더 부드러운 그라데이션 생성
func applyFloydSteinbergDithering(
    pixels: inout [[Float]],
    levels: Int  // 팔레트 문자 수
) {
    let width = pixels[0].count
    let height = pixels.count

    for y in 0..<height {
        for x in 0..<width {
            let oldPixel = pixels[y][x]

            // 가장 가까운 레벨로 양자화
            let step = 255.0 / Float(levels - 1)
            let newPixel = round(oldPixel / step) * step

            pixels[y][x] = newPixel

            // 오차 계산
            let error = oldPixel - newPixel

            // 오차 확산 (Floyd-Steinberg 패턴)
            if x + 1 < width {
                pixels[y][x + 1] += error * 7.0 / 16.0
            }
            if y + 1 < height {
                if x > 0 {
                    pixels[y + 1][x - 1] += error * 3.0 / 16.0
                }
                pixels[y + 1][x] += error * 5.0 / 16.0
                if x + 1 < width {
                    pixels[y + 1][x + 1] += error * 1.0 / 16.0
                }
            }
        }
    }
}
```

### 3.2 에지 검출 (Sobel)

```swift
import CoreImage

/// Sobel 필터로 에지 검출
func detectEdges(from image: CGImage) -> CGImage? {
    let ciImage = CIImage(cgImage: image)

    // Sobel 그래디언트 필터
    guard let filter = CIFilter(name: "CIEdges") else { return nil }
    filter.setValue(ciImage, forKey: kCIInputImageKey)
    filter.setValue(1.0, forKey: kCIInputIntensityKey)

    guard let output = filter.outputImage else { return nil }

    let context = CIContext()
    return context.createCGImage(output, from: output.extent)
}

/// 에지 방향에 따른 문자 선택
func edgeCharacter(gradientX: Float, gradientY: Float) -> Character {
    let angle = atan2(gradientY, gradientX)
    let degrees = angle * 180 / .pi

    switch degrees {
    case -22.5..<22.5, 157.5...180, -180..<(-157.5):
        return "-"   // 수평
    case 22.5..<67.5, -157.5..<(-112.5):
        return "/"   // 대각선
    case 67.5..<112.5, -112.5..<(-67.5):
        return "|"   // 수직
    case 112.5..<157.5, -67.5..<(-22.5):
        return "\\"  // 대각선
    default:
        return " "
    }
}
```

---

## 4. 성능 최적화

### 4.1 현재 구현 (Actor 기반)

```swift
// TextArtGenerator.swift
public actor TextArtGenerator: TextArtGenerating {
    public func generate(...) async throws -> TextArt {
        // 비동기 처리로 UI 블로킹 방지
    }
}
```

### 4.2 Metal 셰이더 (Phase 3)

```swift
// 대용량 이미지/실시간 처리 시
import Metal

class MetalImageProcessor {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    let pipeline: MTLComputePipelineState

    func processImage(_ texture: MTLTexture) -> MTLTexture {
        // GPU에서 병렬 처리
        // 25-40x 성능 향상 가능
    }
}
```

### 4.3 성능 목표

| 이미지 크기 | CPU (현재) | GPU (Phase 3) |
|------------|-----------|---------------|
| 640x480 | ~50ms | ~2ms |
| 1920x1080 | ~300ms | ~10ms |
| 4K | ~1000ms | ~30ms |

---

## 5. 데이터 모델

### 5.1 TextArt

```swift
public struct TextArt: Sendable, Codable, Hashable {
    public let rows: [[Character]]
    public let width: Int
    public let height: Int
    public let sourceCharacters: String
    public let createdAt: Date

    public var asString: String {
        rows.map { String($0) }.joined(separator: "\n")
    }
}
```

### 5.2 ProcessingOptions

```swift
public struct ProcessingOptions: Sendable, Codable, Hashable {
    public let outputWidth: Int          // 20-200
    public let invertBrightness: Bool    // 다크모드용
    public let contrastBoost: Float      // 0.5-2.0
    public let aspectRatioCorrection: Float  // ~0.5

    public static let `default` = ProcessingOptions(
        outputWidth: 80,
        invertBrightness: false,
        contrastBoost: 1.0,
        aspectRatioCorrection: 0.5
    )
}
```

### 5.3 CharacterPalette

```swift
public struct CharacterPalette: Sendable, Codable, Hashable {
    public let characters: [Character]  // 어두움 → 밝음 순서

    public static let standard = CharacterPalette(
        characters: Array("@%#*+=-:. ")
    )

    public static let extended = CharacterPalette(
        characters: Array("$@B%8&WM#*oahkbdpqwmZO0QLCJUYXzcvunxrjft/\\|()1{}[]?-_+~<>i!lI;:,\"^`'. ")
    )

    public static let blocks = CharacterPalette(
        characters: Array("█▓▒░ ")
    )
}
```

---

## 6. 테스트 전략

### 6.1 단위 테스트

```swift
import Testing

@Test("밝기 계산 정확성")
func testLuminanceCalculation() {
    // 흰색
    #expect(calculateLuminance(r: 255, g: 255, b: 255) == 255.0)

    // 검정색
    #expect(calculateLuminance(r: 0, g: 0, b: 0) == 0.0)

    // 순수 녹색 (G 가중치 가장 높음)
    let greenLum = calculateLuminance(r: 0, g: 255, b: 0)
    #expect(greenLum > 100)  // 0.587 * 255 ≈ 149.7
}

@Test("문자 매핑 경계값")
func testCharacterMappingBoundaries() {
    let palette = CharacterPalette.standard

    // 가장 어두운 값 → 첫 문자
    let darkChar = mapToCharacter(luminance: 0, palette: palette, options: .default)
    #expect(darkChar == "@")

    // 가장 밝은 값 → 마지막 문자
    let lightChar = mapToCharacter(luminance: 255, palette: palette, options: .default)
    #expect(lightChar == " ")
}
```

### 6.2 통합 테스트

```swift
@Test("전체 변환 파이프라인")
func testFullPipeline() async throws {
    let generator = TextArtGenerator()
    let testImage = createTestImage(width: 100, height: 100)

    let result = try await generator.generate(
        from: testImage,
        palette: .standard,
        options: .default
    )

    #expect(result.width == 80)  // 기본 출력 폭
    #expect(result.height > 0)
    #expect(!result.rows.isEmpty)
}
```

---

## 7. 빌드 및 배포

### 7.1 빌드 명령어

```bash
# TextifyKit 빌드 및 테스트
cd TextifyKit
swift build
swift test

# TextifyUI 빌드 (iOS Simulator)
cd TextifyUI
swift build --sdk $(xcrun --sdk iphonesimulator --show-sdk-path) \
            --triple arm64-apple-ios26.0-simulator

# TextifyApp 빌드
cd TextifyApp
xcodebuild -scheme TextifyApp \
           -destination 'platform=iOS Simulator,name=iPhone 17' \
           build
```

### 7.2 CI/CD 체크리스트

- [ ] TextifyKit 테스트 통과
- [ ] TextifyUI 빌드 성공
- [ ] TextifyApp 빌드 성공
- [ ] SwiftLint 경고 없음
- [ ] 메모리 누수 없음 (Instruments)

---

## 8. 참고 자료

### 8.1 알고리즘 연구
- `.omc/research/ascii-art-algorithms.md` - 상세 알고리즘 연구

### 8.2 학술 논문
- Xu et al. "Structure-based ASCII Art" (SIGGRAPH 2010)
- Coumar et al. "Evaluating ML Approaches for ASCII Art" (arXiv 2025)

### 8.3 오픈소스 참고
- https://github.com/ijoshsmith/swift-ascii-art
- https://github.com/nickswalker/ASCIIfy

---

*Version: 1.0 | Last Updated: 2026-01-30*
