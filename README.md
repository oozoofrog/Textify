# Textify

사진 한 장을 **복사·공유 가능한 ASCII/유니코드 텍스트 그림**으로 바꾸는 iPhone 앱입니다. 이미지에서 글자를 읽어내는 OCR 기능은 제공하지 않습니다. 사진과 변환 결과는 기기 안에서 처리합니다.

## 주요 흐름

1. 사진 라이브러리 또는 파일 앱에서 이미지를 선택하면 방향을 보정하고 자동으로 첫 결과를 생성합니다.
2. 클래식·선명하게·블록·간결하게 스타일을 고르고, 팔레트·폭·대비·반전을 세부 조정합니다.
3. 화면 맞춤·원본 비교·전체 보기로 확인한 뒤 완성된 텍스트를 복사하거나 공유하고, 이미지로 사진 보관함에 저장합니다.
4. 복사·저장한 결과는 최근 작업에서 다시 확인합니다.

큰 사진은 긴 변을 최대 4096픽셀로 줄여 읽습니다. 생성 중에는 이전 결과를 미리 볼 수 있지만, 현재 옵션이 반영된 결과가 준비되어야 내보내기를 사용할 수 있습니다. 저장 도중 옵션을 바꾸어도 최근 작업에는 실제 저장을 시작한 결과와 그 옵션이 기록됩니다.

## 개발

- iOS 26 이상, Swift 6, SwiftUI
- `TextifyKit`: 픽셀 처리와 문자 매핑
- `TextifyUI`: 화면·ViewModel·사진/내보내기/히스토리 서비스
- `TextifyApp`: 앱 진입점과 의존성 구성
- 테스트는 Swift Testing 기반이며, `TextifyUITests`도 현재는 ViewModel/서비스 단위 테스트 타깃입니다.

```sh
make build-app
make test-app
```

기본 실행 대상은 `iPhone 17` Simulator입니다. 다른 대상을 쓰려면 `IOS_SIM_DESTINATION`을 지정합니다.

## 문서

- [제품 명세](docs/PRODUCT_SPEC.md)
- [개발 설계](docs/DEVELOPMENT_DESIGN.md)
- [2026-09-07 목적 분석과 개선 기록](docs/PRODUCT_FOUNDATION_REVIEW.md)
- [디자인 및 기능 개선 기록](docs/DESIGN_FUNCTION_IMPROVEMENTS.md)
- [배포 점검표](docs/APP_STORE_RELEASE_CHECKLIST.md)
