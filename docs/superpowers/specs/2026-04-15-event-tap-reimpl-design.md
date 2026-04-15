# Design: EventTapManager 리팩토링 — 이벤트 폐기 + 재생성 방식

## 배경

macOS 한글 IME 활성 상태에서 Ctrl+키 단축키(tmux prefix 등)가 터미널에서 동작하지 않는 문제를 해결한다.

디버깅 결과, CGEvent 레벨에서는 유니코드 문자열이 이미 정상(U+0002)이지만, 터미널이 `interpretKeyEvents:` → 한글 IME를 통해 이벤트를 처리하는 과정에서 IME가 이벤트를 소비하는 것이 원인이다. 상세 분석은 `docs/research-korean-ime-ctrl-key.md` 참조.

기존 접근법(유니코드 문자열 수정)은 효과가 없으므로, **원본 이벤트를 폐기하고 IME 메타데이터가 없는 새 CGEvent를 생성**하는 방식으로 전환한다.

## 재작성 대상 범위

**모든 Ctrl+키를 재작성하지 않는다.** 한글 IME의 영향을 받는 키만 대상으로 한다:

- **대상**: `keyCodeToLowerASCII`에 등록된 26개 알파벳 키(a-z)의 keyCode만 재작성
- **비대상 (통과)**: Ctrl+Space, Ctrl+화살표, Ctrl+숫자, Ctrl+문장부호, Ctrl+Tab, Ctrl+Enter 등

한글 IME는 알파벳 키만 한글 자모로 변환하므로, 알파벳 외 키는 IME 간섭이 없어 재작성이 불필요하다. `keyCodeToLowerASCII` 딕셔너리를 대상 keyCode 필터로 재활용한다.

## 이벤트 처리 흐름

```
CGEventTap callback (keyDown / keyUp)
  │
  ├─ eventSourceUserData == sentinel? → 통과 (합성 이벤트, 무한루프 방지)
  │
  ├─ tapDisabledByTimeout / tapDisabledByUserInput? → 탭 재활성화
  │
  └─ keyDown / keyUp
       │
       ├─ 대상 modifier 포함? (현재: Ctrl)
       │    │
       │    ├─ keyCode가 알파벳 키? (keyCodeToLowerASCII에 존재)
       │    │    │
       │    │    ├─ 한글 입력 소스 활성?
       │    │    │    │
       │    │    │    ├─ YES → 원본 폐기(return nil) + 새 CGEvent 생성/post
       │    │    │    │        + 통계 기록 (keyDown일 때만)
       │    │    │    │
       │    │    │    └─ NO → 통과
       │    │    │
       │    │    └─ 알파벳 키 아님 → 통과
       │    │
       │    └─ 대상 modifier 없음 → 통과
       │
       └─ modifier 없음 → 통과
```

## 변경 파일 목록

### 수정: `Sources/ctrl_b_helper/EventTapManager.swift`

핵심 변경 대상. `handleKeyEvent` 로직을 전면 교체한다.

**eventMask 변경:**
- 기존: `keyDown` + `tapDisabled` 2종
- 신규: `keyDown` + `keyUp` + `tapDisabled` 2종 (keyUp도 동일하게 처리해야 터미널이 일관된 이벤트 쌍을 받음)

**대상 modifier 관리:**
```swift
private let targetModifiers: CGEventFlags = [.maskControl]
```
나중에 `.maskCommand`를 추가하면 Cmd+키도 처리 가능. 체크 로직:
```swift
!event.flags.intersection(targetModifiers).isEmpty
```

**대상 keyCode 필터:**
```swift
let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
guard keyCodeToLowerASCII[keyCode] != nil else {
    return Unmanaged.passRetained(event)  // 알파벳 키가 아니면 통과
}
```

**무한루프 방지:**
```swift
private static let sentinel: Int64 = 0x4342_4852_4D4150

// 콜백 진입 시:
if event.getIntegerValueField(.eventSourceUserData) == sentinel {
    return Unmanaged.passRetained(event)
}

// 합성 이벤트 생성 시:
newEvent.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)
```

**합성 이벤트 생성:**
```swift
let source = CGEventSource(stateID: .hidSystemState)
let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
let isKeyDown = (type == .keyDown)

guard let newEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isKeyDown) else {
    return Unmanaged.passRetained(event)
}

newEvent.flags = event.flags  // 원본 modifier 보존 (Ctrl+Shift 등)
newEvent.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)
newEvent.post(tap: .cghidEventTap)

// 통계는 keyDown에서만 기록 (keyUp에서 중복 집계 방지)
if isKeyDown {
    statisticsManager.recordRemap()
}

return nil  // 원본 폐기
```

**post 위치와 폴백 전략:**

합성 이벤트를 `.cghidEventTap`에 post하면 이벤트가 전체 파이프라인을 거치므로 IME가 다시 소비할 가능성이 있다. 폴백 단계:

1. **`.cghidEventTap`에 post** (기본값). 합성 이벤트는 `CGEventSource(stateID: .hidSystemState)`로 생성되어 IME composition 상태와 무관하므로, 터미널이 직접 처리할 가능성이 높다. cmd-eikana(일본어 키보드 도구)가 동일 방식으로 동작 중.
2. **합성 이벤트에 `keyboardSetUnicodeString`으로 명시적 제어문자(ascii & 0x1F)를 설정하여 `.cghidEventTap`에 post** (keyDown에만 적용, keyUp에는 불필요). 1번과의 차이: 이벤트에 유니코드 문자열이 명시되므로 터미널이 IME를 거치지 않고 직접 해석할 단서가 추가됨.
3. **근본적으로 다른 접근이 필요한 경우**: 입력 소스 전환 방식 등 별도 설계 필요 (현재 스펙 범위 밖).

기본값으로 1번을 구현하되, 2번은 테스트 후 필요 시 적용. 참고: `.cgSessionEventTap`에 post하는 것은 우리 탭이 이미 `.cgSessionEventTap`에 걸려 있어 1번과 실질적 차이가 없으므로 폴백으로 유효하지 않다.

**기존 로직 제거:**
- `isHangul()` 체크 기반 분기 제거
- `keyCodeToLowerASCII` 기반 유니코드 변환 제거 (단, keyCode 필터로는 계속 사용)
- 디버그 `NSLog`는 개발 중 유지, 완료 후 제거

### 신규: `Sources/ctrl_b_helper/InputSourceUtils.swift`

한글 입력 소스 감지 유틸리티. Carbon 프레임워크(`TIS*` API)에 의존하므로 **메인 앱 타겟**에 배치한다. (Core 타겟은 시스템 API 의존 없는 순수 로직 원칙 유지)

```swift
import Carbon

func isKoreanInputSourceActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        return false
    }

    // 1차: language 배열에서 "ko" 확인
    if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
        let languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
        if languages.contains("ko") {
            return true
        }
    }

    // 2차: input source ID에 "Korean" 포함 여부 (language 배열이 비어있는 입력기 대비)
    if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        if id.localizedCaseInsensitiveContains("korean") {
            return true
        }
    }

    return false
}
```

**감지 전략 (2단계):**
1. `kTISPropertyInputSourceLanguages` 배열에 `"ko"` 포함 여부 — Apple IME 및 대부분의 서드파티 커버
2. `kTISPropertyInputSourceID` 문자열에 `"Korean"` 포함 여부 — language 배열이 비어있거나 누락된 입력기 대비

`isKoreanInputSourceActive()`가 `false`를 반환하면 핵심 기능이 꺼지므로, **개발 중 Ctrl+알파벳 이벤트에서 이 함수가 false를 반환할 때 입력 소스 ID/language를 NSLog로 출력**하여 누락되는 입력기를 조기에 발견한다.

### 유지: `Sources/CtrlBHelperCore/HangulUtils.swift`

`isHangul()`, `keyCodeToLowerASCII`는 새 로직에서 직접 리매핑에 사용하지 않지만 제거하지 않는다.
- `keyCodeToLowerASCII`는 대상 keyCode 필터로 재활용
- 코드 크기가 작고 테스트 3개 파일이 이를 참조
- 향후 통계/진단용으로 활용 가능

### 유지: `Sources/CtrlBHelperCore/StatisticsManager.swift`

변경 없음. `recordRemap()`은 새 로직에서도 호출되나, **keyDown에서만 호출**한다 (keyUp에서 중복 집계 방지).

### 유지: `Sources/ctrl_b_helper/StatusBarController.swift`

변경 없음.

## 알려진 리스크

### 합성 이벤트도 IME에 소비될 가능성

한글 IME가 여전히 활성 상태이므로, 합성 이벤트가 `interpretKeyEvents:`를 통해 처리될 때 IME가 다시 소비할 수 있다. 다만:
- 합성 이벤트는 `CGEventSource(stateID: .hidSystemState)`로 생성되어 IME composition 상태와 무관
- cmd-eikana(일본어 키보드 도구)가 동일한 방식으로 성공적으로 동작 중
- 실패 시 폴백 2번(명시적 제어문자 설정)으로 대응

### 다른 이벤트 탭과의 상호작용

`.cghidEventTap`에 post하면 Karabiner-Elements 등 다른 이벤트 탭 앱이 합성 이벤트를 가로챌 수 있다. sentinel 값은 우리 앱에서만 인식하므로 다른 앱에서는 일반 키 이벤트로 처리됨.

### 한글 입력 소스 감지 누락 가능성

language/ID 2단계 감지로도 커버되지 않는 입력기가 있을 수 있다. 개발 중 디버그 로깅으로 누락 사례를 수집하고, 발견 시 감지 로직에 추가한다.

## 테스트 계획

### 빌드 및 유닛 테스트

- `swift build -c release` 성공
- `swift test` — 47개 테스트 통과 (Core 로직 변경 없음)

### 수동 테스트 — 핵심 동작

각 항목은 **PASS/FAIL로 판정**한다. 하나라도 FAIL이면 릴리스하지 않는다.

| # | 환경 | 조작 | 기대 결과 | PASS 기준 |
|---|------|------|-----------|-----------|
| 1 | Ghostty + tmux + 한글 2벌식 | Ctrl+B | tmux prefix 모드 진입 | 하단 status bar 색상 변경 또는 prefix 후속키 동작 |
| 2 | Terminal.app + tmux + 한글 2벌식 | Ctrl+B | tmux prefix 모드 진입 | 동일 |
| 3 | Ghostty + tmux + 한글 2벌식 | Ctrl+A (tmux prefix가 Ctrl+A인 경우) 또는 Ctrl+C | 해당 단축키 동작 | 프로세스 종료 등 정상 반응 |
| 4 | Ghostty + tmux + 영문 ABC | Ctrl+B | tmux prefix 모드 진입 | 기존과 동일하게 동작 (회귀 없음) |
| 5 | Ghostty + vim + 한글 2벌식 | Ctrl+B (page up) | 페이지 위로 이동 | 화면 스크롤 확인 |

### 수동 테스트 — 비대상 키 (간섭 없음 확인)

| # | 환경 | 조작 | 기대 결과 |
|---|------|------|-----------|
| 6 | 한글 2벌식 | Ctrl+Space | 입력 소스 전환 정상 동작 |
| 7 | 한글 2벌식 | Ctrl+화살표 | 커서 단어 단위 이동 (앱에 따라 다름) |
| 8 | 영문 ABC | Ctrl+B | 동작 변화 없음 (앱이 이벤트를 재작성하지 않음) |

### 수동 테스트 — 엣지 케이스

| # | 조작 | 기대 결과 |
|---|------|-----------|
| 9 | 한글 + Ctrl+Shift+키 | modifier 보존, 해당 조합 동작 |
| 10 | 한글 + Ctrl+B 길게 누르기 (autorepeat) | 반복 이벤트 정상 처리, 앱 행이나 크래시 없음 |
| 11 | 한글 + Ctrl+B 연타 (빠르게) | 모든 이벤트 처리, 누락 없음 |

### 수동 테스트 — 통계

| # | 조작 | 기대 결과 |
|---|------|-----------|
| 12 | 한글 + Ctrl+B 3회 | 메뉴바 > 오늘 카운트 정확히 3 증가 (6이 아닌 3 — keyDown만 집계) |
| 13 | 영문 + Ctrl+B 3회 | 카운트 변화 없음 (영문에서는 재작성 안 함) |

### 디버그 로깅

개발 중 `NSLog`로 다음을 출력:
- 재작성 발생 시: keyCode, 원본 flags, post 위치
- `isKoreanInputSourceActive()`가 false 반환 시: 현재 input source ID, localizedName, language 배열 (감지 누락 조기 발견 — localizedName이 있으면 누락 입력기 식별이 더 쉬움)
