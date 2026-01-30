# Textify - 디자인 시스템

> iOS 앱 UI/UX 가이드라인

---

## 1. 디자인 원칙

### 1.1 핵심 가치

| 원칙 | 설명 |
|------|------|
| **명확성** | 각 화면의 목적이 즉시 이해됨 |
| **효율성** | 최소한의 탭으로 목표 달성 |
| **일관성** | 동일한 패턴과 컴포넌트 재사용 |
| **피드백** | 모든 액션에 즉각적 반응 |

### 1.2 디자인 톤

```
레트로 + 모던 = 네오-레트로

- ASCII art의 클래식한 감성
- 현대적인 iOS 디자인 언어
- 글래스모피즘 효과
- 부드러운 애니메이션
```

---

## 2. 컬러 시스템

### 2.1 라이트 모드

| 용도 | 색상 | HEX |
|------|------|-----|
| Background | White | `#FFFFFF` |
| Surface | Light Gray | `#F5F5F7` |
| Primary | Blue | `#007AFF` |
| Secondary | Purple | `#AF52DE` |
| Text Primary | Black | `#000000` |
| Text Secondary | Gray | `#8E8E93` |

### 2.2 다크 모드

| 용도 | 색상 | HEX |
|------|------|-----|
| Background | Black | `#000000` |
| Surface | Dark Gray | `#1C1C1E` |
| Primary | Blue | `#0A84FF` |
| Secondary | Purple | `#BF5AF2` |
| Text Primary | White | `#FFFFFF` |
| Text Secondary | Gray | `#8E8E93` |

### 2.3 SwiftUI 구현

```swift
extension Color {
    static let textifyPrimary = Color("Primary")
    static let textifySecondary = Color("Secondary")
    static let textifySurface = Color("Surface")
}

// AppTheme.swift
struct AppTheme {
    static let cornerRadius: CGFloat = 16
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12
}
```

---

## 3. 타이포그래피

### 3.1 폰트 스케일

| 용도 | 스타일 | 크기 |
|------|--------|------|
| Large Title | Bold | 34pt |
| Title | Bold | 28pt |
| Headline | Semibold | 17pt |
| Body | Regular | 17pt |
| Callout | Regular | 16pt |
| Caption | Regular | 12pt |

### 3.2 모노스페이스 (결과 표시용)

```swift
// 텍스트 아트 결과 표시
Font.system(.body, design: .monospaced)

// 또는 커스텀
Font.custom("Menlo", size: 12)
```

---

## 4. 컴포넌트 라이브러리

### 4.1 GlassCard

글래스모피즘 효과의 카드 컨테이너

```swift
struct GlassCard<Content: View>: View {
    let content: Content

    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
```

### 4.2 LoadingButton

로딩 상태를 표시하는 버튼

```swift
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
            } else {
                Text(title)
            }
        }
        .disabled(isLoading)
    }
}
```

### 4.3 ValueSlider

값을 조절하는 슬라이더 (폭, 대비 등)

```swift
struct ValueSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading) {
            Text("\(title): \(Int(value))")
            Slider(value: $value, in: range)
        }
    }
}
```

### 4.4 ErrorBanner

에러 메시지 표시 배너

```swift
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
            Spacer()
            Button("닫기", action: onDismiss)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}
```

---

## 5. 아이콘

### 5.1 SF Symbols 사용

| 용도 | 아이콘 |
|------|--------|
| 새 프로젝트 | `plus.circle.fill` |
| 히스토리 | `clock.arrow.circlepath` |
| 설정 | `gearshape.fill` |
| 복사 | `doc.on.doc` |
| 저장 | `square.and.arrow.down` |
| 공유 | `square.and.arrow.up` |
| 사진 | `photo.on.rectangle` |
| 파일 | `folder` |

### 5.2 앱 아이콘

```
1024x1024 마스터 아이콘
├── 배경: 그라데이션 (Primary → Secondary)
├── 심볼: 모노스페이스 "Aa" 또는 ASCII art 패턴
└── 스타일: iOS 18 디자인 언어
```

---

## 6. 애니메이션

### 6.1 표준 타이밍

| 유형 | 지속시간 | 이징 |
|------|----------|------|
| 빠른 피드백 | 0.15s | easeOut |
| 표준 전환 | 0.3s | easeInOut |
| 강조 애니메이션 | 0.5s | spring |

### 6.2 애니메이션 패턴

```swift
// 버튼 탭 피드백
withAnimation(.easeOut(duration: 0.15)) {
    scale = 0.95
}

// 화면 전환
withAnimation(.easeInOut(duration: 0.3)) {
    isPresented = true
}

// 결과 표시
withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
    showResult = true
}
```

---

## 7. 레이아웃

### 7.1 Safe Area

```swift
// 항상 safe area 존중
.padding()
.safeAreaInset(edge: .bottom) {
    // 하단 액션 버튼
}
```

### 7.2 스페이싱 시스템

```swift
enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
}
```

### 7.3 그리드

```swift
// 2열 그리드 (히스토리 등)
LazyVGrid(columns: [
    GridItem(.flexible()),
    GridItem(.flexible())
], spacing: 16) {
    // items
}
```

---

## 8. 접근성

### 8.1 VoiceOver

```swift
// 이미지에 설명 추가
Image(uiImage: image)
    .accessibilityLabel("선택한 원본 이미지")

// 버튼에 힌트 추가
Button("복사") { ... }
    .accessibilityHint("텍스트 아트를 클립보드에 복사합니다")
```

### 8.2 Dynamic Type

```swift
// 텍스트 크기 대응
Text("제목")
    .font(.headline)
    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
```

### 8.3 최소 탭 영역

```swift
// 44x44pt 최소 크기 보장
Button { ... }
    .frame(minWidth: 44, minHeight: 44)
```

---

## 9. 화면별 디자인

### 9.1 홈 화면

```
┌─────────────────────────────────────┐
│  Textify                    ⚙️      │
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │      + 새 프로젝트 시작      │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  최근 히스토리                       │
│  ┌─────────┐ ┌─────────┐          │
│  │ 썸네일1  │ │ 썸네일2  │          │
│  └─────────┘ └─────────┘          │
│                                     │
└─────────────────────────────────────┘
```

### 9.2 결과 화면

```
┌─────────────────────────────────────┐
│  ← 결과                              │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ @@@@@@@@@@@@@@@@@@@@@@@@@@ │   │
│  │ @@@@@@#####@@@@@@#####@@@@ │   │
│  │ @@@@@#.....#@@@@#.....#@@@ │   │
│  │ ...                       │   │
│  │ (스크롤 가능)               │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐     │
│  │복사│ │저장│ │공유│ │재생성│     │
│  └────┘ └────┘ └────┘ └────┘     │
└─────────────────────────────────────┘
```

---

*Version: 1.0 | Last Updated: 2026-01-30*
