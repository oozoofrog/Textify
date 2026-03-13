# Textify 개발 설계 문서

- 작성일: 2026-03-13
- 범위: Textify MVP 재설계 기준의 아키텍처, 책임 분리, DI, 테스트 전략, 구현 순서

---

## 1. 아키텍처 목표

Textify는 **오프라인 ASCII 텍스트 아트 생성 앱**이며, 이번 단계에서는 다음 구조를 유지한다.

- **App**: 앱 진입점
- **TextifyUI**: View / ViewModel / 앱 서비스 / Composition Root
- **TextifyKit**: 이미지 → 텍스트 아트 변환 코어

---

## 2. 책임 분리 원칙

### 2.1 View
책임:
- 상태 렌더링
- 사용자 입력 전달
- 시트/네비게이션 표시

금지:
- `UIPasteboard`, 사진 저장, 히스토리 파일 저장 같은 시스템 직접 호출
- 텍스트 아트 생성 알고리즘 보유

### 2.2 ViewModel
책임:
- 화면 상태 전이 관리
- 서비스와 코어 호출 조정
- UI용 메시지/피드백 상태 제공

금지:
- 렌더링 세부 구현
- 파일 시스템/Photos 직접 호출

### 2.3 Service / Repository 경계
이번 단계의 핵심 서비스:
- `PhotoLibraryService`
- `ClipboardService`
- `ImageExportService`
- `HistoryService`
- `AppearanceService`
- `HapticsService`

역할:
- 플랫폼/시스템 프레임워크 접근 캡슐화
- ViewModel에서 직접 UIKit/Photos 접근 제거

### 2.4 Core Engine
- `TextArtGenerator`
- `ImageProcessor`
- `CharacterMapper`
- `CharacterPalette`
- `ProcessingOptions`
- `TextArt`

역할:
- 이미지 픽셀 처리
- 팔레트 매핑
- 결과 텍스트 생성

---

## 3. Pure DI 구조

### Composition Root
`AppDependencies`가 모든 concrete type 생성 책임을 가진다.

예상 의존성 그래프:

- `TextifyApp`
  - `AppDependencies`
    - `TextArtGenerator`
    - `PhotoLibraryService`
    - `ClipboardService`
    - `ImageExportService`
    - `HistoryService`
    - `AppearanceService`
    - `HapticsService`

### ViewModel Factory
- `makeMainViewModel()`
- `makeTextifyViewModel(image:)`
- `makeHistoryViewModel()`
- `makeSettingsViewModel()`

---

## 4. 화면별 설계

## 4.1 MainView / MainViewModel

### 역할
- 사진 선택 진입
- 히스토리/설정 시트 오픈
- 사진 로딩 완료 후 작업공간으로 이동

### 상태
- `selectedImage`
- `isLoading`
- `errorMessage`

### 의존성
- `PhotoLibraryService`

---

## 4.2 TextifyView / TextifyViewModel

### 역할
- 초기 생성
- 옵션 변경 반영
- 복사/저장/공유/포커스 모드 지원
- 히스토리 저장 트리거

### 상태
- `textArt`
- `isGenerating`
- `errorMessage`
- `copied`
- `showSavedFeedback`
- `selectedPreset`
- `outputWidth`
- `invertBrightness`
- `fontSize`

### 의존성
- `TextArtGenerating`
- `ClipboardServiceProtocol`
- `ImageExportServiceProtocol`
- `HistoryServiceProtocol`
- `HapticsServiceProtocol`

### 동시성 규칙
- `@MainActor` ViewModel 유지
- 생성 요청은 `GenerationTaskManager`로 최신 요청만 유효하게 유지
- 폭 변경은 throttle
- 최종 재생성은 debounce
- stale request 방지를 위해 request id 유지

---

## 4.3 HistoryView / HistoryViewModel

### 역할
- 최근 결과 표시
- 항목 삭제
- 전체 삭제

### 의존성
- `HistoryServiceProtocol`

---

## 4.4 SettingsView / SettingsViewModel

### 역할
- 외형 모드 변경
- 히스토리 삭제

### 의존성
- `AppearanceServiceProtocol`
- `HistoryServiceProtocol`

---

## 5. 테스트 전략 (TDD)

### 5.1 유지할 기존 테스트
- `TextifyKitTests` 전반
- `TextifyViewModel` debounce/cancellation/generation 상태 테스트

### 5.2 추가 테스트
- 복사 액션이 클립보드 서비스 호출 및 피드백 상태 반영
- 저장 액션이 export 서비스 호출 및 피드백 상태 반영
- 성공한 생성 결과가 중복 없이 히스토리에 저장
- 설정의 히스토리 삭제 동작

### 5.3 테스트 원칙
- Swift Testing 사용
- mock/fake 기반
- 시간 의존 로직은 짧은 delay 주입으로 제어
- 구현 디테일보다 상태 전이/행동을 검증

---

## 6. 구현 시퀀스

1. 문서 정렬
2. DI 및 버전 정책 정리
3. `TextifyViewModel` 서비스 주입 리팩터링
4. `MainView`/`TextifyView` UI 재구성
5. `SettingsViewModel` 히스토리 삭제 연결
6. 테스트 보강
7. `xcodegen generate` 후 빌드/테스트 검증

---

## 7. 검증 기준

### 필수
- `xcodegen generate`
- `make test-app`
- `make build-app`

### 수동 확인
- 사진 선택 → 작업공간 이동
- 생성 성공/실패
- 옵션 변경 반영
- 복사/저장 피드백
- 히스토리 추가/삭제/전체 삭제

---

## 8. 이번 단계의 의도적 비범위

- 네트워크 계층 도입
- LocalRepository 전면 리네이밍
- 미연결 실험 플로우 전부 제거
- `TextifyKit` 알고리즘 자체 대개편

이번 단계는 **제품 정의와 핵심 UX를 다시 잠그고, 현행 코어 위에서 안전하게 MVP를 다듬는 것**에 집중한다.

