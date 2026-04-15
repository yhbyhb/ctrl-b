# Design: EventTapManager 리팩토링 — 이벤트 폐기 + 재생성 방식

## 배경

macOS 한글 IME 활성 상태에서 Ctrl+키 단축키(tmux prefix 등)가 터미널에서 동작하지 않는 문제를 해결한다.

디버깅 결과, CGEvent 레벨에서는 유니코드 문자열이 이미 정상(U+0002)이지만, 터미널이 `interpretKeyEvents:` → 한글 IME를 통해 이벤트를 처리하는 과정에서 IME가 이벤트를 소비하는 것이 원인이다. 상세 분석은 `docs/research-korean-ime-ctrl-key.md` 참조.

기존 접근법(유니코드 문자열 수정)은 효과가 없으므로, **원본 이벤트를 폐기하고 IME 메타데이터가 없는 새 CGEvent를 생성**하는 방식으로 전환한다.

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
       │    ├─ 한글 입력 소스 활성?
       │    │    │
       │    │    ├─ YES → 원본 폐기(return nil) + 새 CGEvent 생성/post
       │    │    │
       │    │    └─ NO → 통과
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

return nil  // 원본 폐기
```

**post 위치 폴백 전략:**

합성 이벤트를 `.cghidEventTap`에 post하면 이벤트가 전체 파이프라인을 거치므로 IME가 다시 소비할 가능성이 있다. 이 경우 단계적으로 대응:

1. `.cghidEventTap`에 post (기본값 — 가장 자연스러운 이벤트 흐름)
2. 안 되면 `.cgSessionEventTap`으로 변경 (IME 이후 단계에 삽입)
3. 최종 폴백: `keyboardSetUnicodeString`으로 명시적 제어문자(ascii & 0x1F)도 함께 설정

기본값으로 1번을 구현하되, 2/3번은 테스트 후 필요 시 적용.

**기존 로직 제거:**
- `isHangul()` 체크 기반 분기 제거
- `keyCodeToLowerASCII` 기반 유니코드 변환 제거
- 디버그 `NSLog`는 개발 중 유지, 완료 후 제거

### 신규: `Sources/ctrl_b_helper/InputSourceUtils.swift`

한글 입력 소스 감지 유틸리티. Carbon 프레임워크(`TIS*` API)에 의존하므로 **메인 앱 타겟**에 배치한다. (Core 타겟은 시스템 API 의존 없는 순수 로직 원칙 유지)

```swift
import Carbon

func isKoreanInputSourceActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else {
        return false
    }
    let languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
    return languages.contains("ko")
}
```

`kTISPropertyInputSourceLanguages`에서 `"ko"`를 확인하면 Apple 기본 한글 IME(2벌식, 3벌식, 390 등)뿐 아니라 구름 입력기 같은 서드파티 한글 IME도 커버된다.

### 유지: `Sources/CtrlBHelperCore/HangulUtils.swift`

`isHangul()`, `keyCodeToLowerASCII`는 새 로직에서 사용하지 않지만 제거하지 않는다.
- 코드 크기가 작고 테스트 3개 파일이 이를 참조
- 향후 통계/진단용으로 활용 가능
- `EventTapManager`에서의 import/사용만 제거

### 유지: `Sources/CtrlBHelperCore/StatisticsManager.swift`

변경 없음. `recordRemap()`은 새 로직에서도 동일하게 호출.

### 유지: `Sources/ctrl_b_helper/StatusBarController.swift`

변경 없음.

## 알려진 리스크

### 합성 이벤트도 IME에 소비될 가능성

한글 IME가 여전히 활성 상태이므로, 합성 이벤트가 `interpretKeyEvents:`를 통해 처리될 때 IME가 다시 소비할 수 있다. 다만:
- 합성 이벤트는 `CGEventSource(stateID: .hidSystemState)`로 생성되어 IME composition 상태와 무관
- cmd-eikana(일본어 키보드 도구)가 동일한 방식으로 성공적으로 동작 중
- 실패 시 post 위치 폴백 전략으로 대응

### 다른 이벤트 탭과의 상호작용

`.cghidEventTap`에 post하면 Karabiner-Elements 등 다른 이벤트 탭 앱이 합성 이벤트를 가로챌 수 있다. sentinel 값은 우리 앱에서만 인식하므로 다른 앱에서는 일반 키 이벤트로 처리됨. 문제 발생 시 `.cgSessionEventTap`으로 전환.

## 테스트 계획

1. **빌드 확인**: `swift build -c release` 성공
2. **기존 테스트**: `swift test` — 47개 테스트 통과 (Core 로직 변경 없음)
3. **수동 테스트 — 기본 동작**:
   - Ghostty + tmux + 한글 IME → Ctrl+B로 tmux prefix 동작 확인
   - Terminal.app + tmux + 한글 IME → 동일 확인
4. **수동 테스트 — 엣지 케이스**:
   - 영문 IME에서 Ctrl+B → 기존과 동일하게 동작 (간섭 없음)
   - Ctrl+Shift+키 → modifier 보존 확인
   - Ctrl 길게 누르기 (autorepeat) → 반복 이벤트 정상 처리
   - Ctrl+Space (입력 소스 전환) → 정상 동작
5. **수동 테스트 — 통계**: 리매핑 발생 시 메뉴바 통계 카운트 증가 확인
6. **시뮬레이션 스크립트**: `debug_simulate.swift` 업데이트하여 자동 검증
