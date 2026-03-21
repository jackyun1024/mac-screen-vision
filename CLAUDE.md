# screen-vision — 개발 가이드

## 프로젝트 개요

macOS 화면 OCR & 클릭 자동화 CLI.
Apple Vision (OCR) + ScreenCaptureKit (캡처) + cliclick (클릭).

## 문서 참조 구조

```
mac-screen-vision/
├── CLAUDE.md              ← 지금 이 파일 (개발 가이드, 작업 시 필독)
├── README.md              ← 사용자 대상 설치/사용법
├── docs/
│   └── product.md         ← 프로덕트 상세 문서 (아키텍처, 좌표계, 배포 채널)
├── action/                ← 작업 기록 (.gitignore, 로컬 전용)
├── screen-vision/         ← OpenClaw 스킬 패키지
│   ├── SKILL.md
│   └── setup.sh
└── Sources/               ← 소스 코드
```

**읽는 순서**: CLAUDE.md → docs/product.md → 소스 코드

---

## 빌드 & 테스트

```bash
# 빌드
swift build -c release

# 유닛 테스트 (Screen Recording 불필요, 빠름)
swift test --filter 'CoordinateTests|HelpersTests|ModelsTests|SearchTests'

# 통합 테스트 (Screen Recording 권한 필요)
swift test --filter IntegrationTests

# 전체
swift test

# 로컬 설치
cp .build/release/screen-vision ~/.local/bin/
```

---

## 소스 구조

```
Sources/
├── ScreenVisionLib/        # 테스트 가능한 라이브러리 (public API)
│   ├── Models.swift         # TextElement, FindResult, TapResult
│   ├── Capture.swift        # ScreenCaptureKit 캡처 (async)
│   ├── OCR.swift            # Vision OCR + convertToScreenCoords()
│   ├── Search.swift         # findMatch() — exact > partial
│   └── Helpers.swift        # parseRegion, encodeJSON, sortByPosition
└── screen-vision/           # CLI 진입점
    └── main.swift           # 인자 파싱 + 커맨드 라우팅 + semaphore bridge
```

### 핵심 함수

| 함수 | 위치 | 역할 |
|------|------|------|
| `captureTarget()` | Capture.swift | 캡처 우선순위 해결 (region > app > fullscreen) |
| `performOCR()` | OCR.swift | 이미지 → TextElement 배열 |
| `convertToScreenCoords()` | OCR.swift | Vision 정규화 좌표 → 화면 픽셀 좌표 |
| `findMatch()` | Search.swift | exact > partial 텍스트 매칭 |

### async 구조

ScreenCaptureKit이 async API → 모든 캡처/커맨드 함수가 async.
`main.swift`에서 `DispatchSemaphore` + `Task { }` 로 동기 진입점 브릿지.

---

## 주의사항

### 빌드
- `platforms: [.macOS(.v14)]` — Sonoma 이상 필수 (`SCScreenshotManager`)
- Swift 5.9+, swift-tools-version: 5.9

### 좌표 변환
- Vision boundingBox: **좌하단 원점**, 0~1 정규화
- 화면 좌표: **좌상단 원점**, 픽셀
- Retina: 이미지 크기 ≠ 화면 크기 (scaleX/Y 보정 필요)
- FP 반올림: Int 변환 시 ±1px 오차 가능 → 테스트에서 range로 검증

### Screen Recording 권한
- 없으면 `captureTarget()` → `nil` → `"Failed to capture screen"` 에러
- 통합 테스트에서 `requireGUISession()` 으로 headless 환경 skip

### cliclick 의존
- `tap` 커맨드만 사용. 경로: `/opt/homebrew/bin/cliclick`
- 없으면 tap 실패하지만 다른 커맨드는 정상 동작

---

## 배포 체크리스트

새 버전 릴리스 시:

```bash
# 1. 빌드 & 테스트
swift build -c release && swift test

# 2. 바이너리 tarball
tar -czf screen-vision-X.Y.Z-arm64-macos.tar.gz -C .build/release screen-vision

# 3. GitHub 릴리스 + 바이너리 첨부
gh release create vX.Y.Z --title "vX.Y.Z" --notes "변경내용"
gh release upload vX.Y.Z screen-vision-X.Y.Z-arm64-macos.tar.gz

# 4. Homebrew formula 업데이트 (sha256 갱신)
# ~/dev/homebrew-tap/Formula/screen-vision.rb
curl -sL <tarball-url> | shasum -a 256

# 5. ClawHub 스킬 업데이트
npx clawhub publish screen-vision --version X.Y.Z

# 6. 로컬 바이너리 업데이트
cp .build/release/screen-vision ~/.local/bin/
```

---

## 관련 프로젝트

| 프로젝트 | 레포 | 관계 |
|----------|------|------|
| Homebrew formula | `jackyun1024/homebrew-tap` | `Formula/screen-vision.rb` |
| toss-pos-sales 스킬 | `~/.claude/skills/toss-pos-sales/` | screen-vision 의존 (TV 함수) |
| screen-vision 스킬 | `~/.claude/skills/screen-vision/` | 로컬 Claude Code 스킬 |
| ClawHub | clawhub.ai | `screen-vision@1.2.0` |

---

## 향후 고려사항

- **Intel Mac 바이너리**: 현재 arm64만. universal binary 또는 x86_64 별도 빌드
- **언어 추가**: `recognitionLanguages`에 일본어, 중국어 등 추가 가능
- **macOS 13 지원**: `SCScreenshotManager` 대신 `SCStream` 사용으로 가능하나 복잡도 증가
- **다중 모니터**: 현재 `displays.first`만 사용. 모니터 선택 옵션 추가 가능
