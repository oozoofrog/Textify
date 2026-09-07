# 디자인 및 기능 개선

작업일: 2026-09-07. 앞선 `PRODUCT_FOUNDATION_REVIEW.md`의 입력·생성·히스토리 안정화 이후, 사용자가 실제로 보고 조작하는 화면과 기능을 개선했다.

## 구현한 사용자 경험

### 홈

- 설명 카드 3개와 움직이는 반복 ASCII 배경을 제거하고, 제목·예시 작품·사진 선택·파일 가져오기로 정리했다.
- 홈 예시에는 예시임을 명시한다. 사용자 사진에서 생성한 결과로 제시하지 않는다.
- 사진 선택을 주 행동, 파일 이미지 가져오기를 보조 행동으로 제공한다.
- 최근 작업과 설정은 상단 툴바로 옮겼다.
- 좁은 폭에서 잘리던 사용자 정의 툴바 타이틀은 표준 내비게이션 타이틀로 수정했다.

### 텍스트 스튜디오

- 중복되던 비교 미리보기/터미널 결과 영역을 하나의 캔버스로 통합했다.
- 처음에는 전체 텍스트 아트가 화면에 맞게 보인다. 원본과 비교 모드도 같은 캔버스에서 선택한다.
- `FittedTextArt`는 실제 모노스페이스 문자열 크기를 측정해 폰트 크기를 정한다. 원본은 비율을 유지하며 잘라 채우지 않는다.
- 원본/텍스트 비교 슬라이더에는 접근성 라벨과 퍼센트 값을 제공한다.
- 전체 보기는 별도 화면이며 닫기·확대·축소·화면 맞춤 버튼과 pinch/pan을 제공한다.
- 결과 폭·줄 수·문자 수를 표시하고, 붙여넣는 곳에서 고정폭 글꼴을 쓰도록 안내한다. 문자 수는 공백을 포함하고 줄 구분자는 제외한다.
- 하단에는 텍스트 복사·공유·이미지 저장을 유지한다. 현재 옵션의 결과가 준비되기 전에는 내보내기를 제한한다.

### 스타일과 세부 조정

| 스타일 | 문자 팔레트 | 폭 | 대비 | 반전 |
|---|---|---:|---:|---|
| 클래식 | 기본 | 80 | 1.0 | 끔 |
| 선명하게 | 조밀 | 100 | 1.5 | 끔 |
| 블록 | 블록 | 80 | 1.2 | 끔 |
| 간결하게 | 미니멀 | 40 | 1.1 | 끔 |

스타일은 이미지 내용을 분석해 추천하는 기능이 아닌 고정된 시작 설정이다. 모든 옵션을 한 번에 적용하고 한 번 생성한다. 사용자가 세부 설정을 바꾸면 실제 옵션이 스타일과 일치할 때만 선택 표시를 유지한다. 기본 설정 복원은 클래식과 기본 커스텀 문자로 되돌린다.

카드 선택 표시는 체크 아이콘·윤곽선·접근성 selected trait로 제공한다. 실제 화면 검토에서 체크 아이콘이 제목 공간을 밀어내는 문제가 발견되어 카드 모서리로 옮겼다. 큰 접근성 글자 크기에서는 스타일 카드를 한 열로 배치한다.

### 파일 이미지 가져오기

`MainView.fileImporter` → `MainViewModel.loadImage(fromFile:)` → `PhotoLibraryService`로 연결한다.

- 파일 읽기와 ImageIO 디코딩은 `@concurrent` 서비스 메서드에서 실행한다.
- security scoped access는 읽기 범위 안에서 유지하고 반환한다.
- 사진/파일 모두 EXIF 방향 보정과 긴 변 4096픽셀 제한을 적용한다.
- 최신 선택 요청이 성공했을 때만 화면을 이동한다. 취소와 오래된 응답은 새 상태를 덮어쓰지 않는다.
- 지원하지 않거나 읽지 못한 파일에는 사용자 오류를 표시한다.

## 변경 파일과 역할

- `Features/Main/MainView.swift`: 새 홈 및 파일 선택 연결.
- `Features/Main/MainViewModel.swift`, `Services/PhotoLibraryService.swift`: 파일 입력과 최신 로딩 상태.
- `Features/Textify/TextifyView.swift`: 단일 캔버스, 스타일, 결과 정보, 조정 시트, 액션.
- `Models/TextArtStyle.swift`, `Features/Textify/TextifyViewModel.swift`: 스타일 적용·선택 판정·초기화·통계.
- `Components/FocusModeOverlay.swift`: 화면 맞춤 렌더링과 전체 보기.
- `Components/VisualPalettePicker.swift`, `Shared/Theme/AppTheme.swift`: 접근 가능한 팔레트 버튼과 공통 표면 색.
- `MainViewModelTests`, `PhotoLibraryServiceTests`, `TextifyViewModelTests`: 입력·상태·스타일 회귀 검증.

문서와 프로젝트 파일도 정렬했다. 기존 서명 설정은 유지했다. 사진 저장의 녹색 문자/검정 배경은 기존 출력 포맷이며, 이번 스튜디오 배경색 변경이 내보내기 테마 선택 기능을 추가한 것은 아니다.

## 자동 검증

- 전체 `make test-app`: **TextifyKit 50개 + TextifyUI 62개 = 112개 통과**. 매개변수 테스트는 각 선언 안에서 여러 입력을 실행한다.
- 새 검증: 파일 성공/오류/방향/해상도, 사진/파일 요청 역전, 취소, 스타일 4종, 세부 편집 후 선택 해제, 기본값 복원, 결과 통계.
- Swift Intelligence: 기존 화면 파일 진단 `[]`. `swift_diagnostics(workspace_path: TextifyApp, xcode_scheme: TextifyApp)`가 새 `TextifyUI/Models/TextArtStyle.swift`와 `TextifyUITests/MainViewModelTests.swift`에 대해 `Xcode BSP build settings do not include <file>. Add its scheme to SWIFT_INTELLIGENCE_XCODE_SCHEME or pass xcode_scheme.` 오류를 반환했지만 프로젝트 연결 후 `xcode_scheme: TextifyApp,TextifyUI`로 스타일 모델과 MainViewModelTests 모두 진단 `[]`를 확인했다.
- 수정 후 전체 `make test-app`도 112개 통과. 최종 `make build-app` 성공 후 iPhone 17 Pro Simulator에 설치/실행했다.
- 사진 선택 라벨의 MainActor 접근 경고는 `isLoading` 값을 MainActor에서 읽어 캡처하는 방식으로 해결했다. 최종 앱 빌드에서 해당 Swift 경고가 사라졌으며, AppIntents 미사용에 따른 메타데이터 추출 안내만 남았다.
- `git diff --check`: 통과.

## Simulator 검증

iPhone 17 Pro Simulator(iOS 27)의 실제 화면과 접근성 계층을 사용했다. 검증 입력은 산과 해를 그린 합성 PNG이며 사용자 사진은 사용하지 않았다.

- 기준 홈에서 CTA가 y710.7pt에 있었고 장식 ASCII 18개가 접근성 StaticText로 노출되어 있었다.
- 개선 홈은 한 페이지로 표시되고 사진 CTA 시작 위치가 y621.3pt로 올라왔다. 반복 장식의 접근성 노이즈도 제거했다.
- 최종 Astra 읽기 전용 소스 검토에서 추가 기능/상태 회귀를 발견하지 못했다.
- 사진 선택 → 자동 생성, 선명하게/간결하게 스타일 적용, 결과 폭·대비 변경을 확인했다.
- 원본/비교 모드와 비교 비율 50→81%, 전체 보기 확대→맞춤→닫기를 확인했다.
- 세부 조정 반전 → 기본 복원에서 폭80/대비1/반전끔으로 돌아오는 것을 확인했다.
- 파일 가져오기 → Files의 나의 iPhone → 합성 `Textify-Landscape.png` 선택 → 80×30 결과 자동생성을 확인했다.
- 수정 빌드에서 홈 타이틀 잘림 해소, 선택된 스타일 카드의 제목/설명 한 줄 유지, 확대 버튼 대비 개선을 확인했다.
- 최종 밝은 홈·밝은 스튜디오·어두운 스튜디오를 캡처했고 파일 선택 창 취소도 확인했다.
- 파일 선택기 취소 후 홈 복귀와 재선택 후 자동생성도 확인했다.
- 큰 글자/가로 화면 검증 시작 전 Simulator가 예기치 않게 Shutdown 상태로 바뀌었다. 부팅 재시도 후에도 `Target device has invalid screen scale. Make sure your machine can access the remote device.` 오류가 발생해 두 조건의 런타임 검증은 완료하지 못했다. 기본 기능 및 Light/Dark 화면 검증과 구분한다. 표시 설정의 원래 light/large 복원도 확인하지 못했다. 마지막 확인은 dark/large/portrait이며, 이후 큰 글자 요청 완료 여부는 불명확하다. 검증용 대기 프로세스를 정리하고 Device Interaction 세션은 종료했다.
- 복사 후 피드백과 Simulator 클립보드 2429자를 확인했다. 이는 80×30 문자와 줄바꿈29개의 합이다.

## 범위와 한계

실기기에서 iCloud/외부 Files provider 파일 다운로드, HEIF/HDR 표시 품질, 사진 저장 권한의 모든 분기, 실제 VoiceOver 읽기 경험과 시간·메모리 성능 측정은 완료하지 않았다. `TextifyUITests` 타깃은 ViewModel/서비스 단위 테스트이며, 이번 화면 검증은 별도의 Simulator 상호작용이다. 커밋·푸시·실기기 설치·배포는 수행하지 않았다.
