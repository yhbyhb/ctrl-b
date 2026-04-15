# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Does

macOS 한글 IME 활성 상태에서 Ctrl+알파벳 단축키(tmux prefix 등)가 터미널에서 동작하지 않는 문제를 해결하는 메뉴바 상주 앱. CGEventTap으로 키 이벤트를 가로채, 원본 이벤트를 폐기하고 IME 메타데이터가 없는 합성 이벤트를 생성하여 주입한다.

## Build & Test Commands

```bash
swift build -c release    # 릴리스 빌드
swift test                # 전체 테스트 실행
swift test --filter StatisticsManagerTests           # 특정 테스트 클래스 실행
swift test --filter StatisticsManagerTests/test_record_incrementsCount  # 단일 테스트
make app                  # .app 번들 생성 (.build/release → ctrl-b-helper.app)
make install              # /Applications에 설치
make lint                 # SwiftLint 검사 (--strict)
make lint-fix             # SwiftLint 자동 수정
make setup                # 개발 환경 초기 설정 (git hooks)
```

## Architecture

두 개의 SPM 타겟으로 분리:

- **CtrlBHelperCore** (`Sources/CtrlBHelperCore/`) — 테스트 가능한 순수 로직. Cocoa/CoreGraphics 의존 없음.
  - `isHangul()`: UniChar → 한글 여부 (Jamo, Compatibility Jamo, Syllables 3개 범위)
  - `keyCodeToLowerASCII`: macOS 물리 keyCode(Int64) → ASCII 소문자(UInt8) 딕셔너리
  - `StatisticsManager`: UserDefaults 기반 리매핑 횟수/절약시간 집계 (DI로 테스트 가능)

- **ctrl-b-helper** (`Sources/ctrl_b_helper/`) — 앱 실행 파일. Cocoa, CoreGraphics, Carbon, ServiceManagement 프레임워크 사용.
  - `EventTapManager`: CGEventTap 콜백에서 한글 IME + Ctrl + 알파벳 keyCode 조건 시 원본 이벤트 폐기(return nil) + `CGEventSource(stateID: .hidSystemState)`로 합성 이벤트 생성/post. `eventSourceUserData` sentinel 값으로 무한루프 방지.
  - `InputSourceUtils`: `TISCopyCurrentKeyboardInputSource` 기반 한글 입력 소스 감지 (language 배열 + input source ID 2단계). 디버그용 `logCurrentInputSource()` 포함.
  - `StatusBarController`: NSMenuDelegate로 메뉴 열릴 때마다 통계 갱신 (Timer 불필요)
  - `LaunchAtLoginManager`: SMAppService (macOS 13+) 기반

## Key Design Decisions

- **이벤트 consume + recreate**: CGEvent 콜백에서 원본 이벤트를 폐기(return nil)하고, `CGEventSource(stateID: .hidSystemState)`로 IME 메타데이터가 없는 합성 이벤트를 생성하여 `.cghidEventTap`에 post. 유니코드 문자열 수정(in-place) 방식은 CGEvent 레벨에서 이미 정상(U+0002)이라 효과 없음 — 문제는 `interpretKeyEvents:` 레이어에서 한글 IME가 이벤트를 소비하는 것.
- **sentinel 기반 무한루프 방지**: 합성 이벤트에 `eventSourceUserData` 필드(0x4342_4852_4D4150)를 설정하여 자체 이벤트를 재처리하지 않음.
- **대상 범위 제한**: `keyCodeToLowerASCII`에 등록된 a-z 26개 keyCode만 리매핑. Ctrl+Space, Ctrl+화살표 등은 통과.
- **Core 분리**: CGEvent 등 시스템 API에 의존하는 코드는 테스트 불가능하므로, 순수 로직(한글 판별, keyCode 매핑, 통계)만 Core로 분리해 유닛 테스트 커버.
- **StatisticsManager DI**: `UserDefaults`를 생성자 주입받아 테스트에서 격리된 suite 사용.
- **LSUIElement=true**: Dock 아이콘 숨김, 메뉴바 전용 앱.
- **os.Logger**: `com.yhbyhb.ctrl-b-helper` 서브시스템으로 구조화된 로깅. Console.app에서 카테고리별 필터링 가능.

## Language

UI 문자열과 코드 주석은 한국어로 작성.
