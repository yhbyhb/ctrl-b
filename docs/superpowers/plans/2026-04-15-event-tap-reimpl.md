# EventTapManager 리팩토링 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 한글 IME 활성 상태에서 Ctrl+알파벳 단축키가 tmux/vim 등 터미널 앱에서 동작하도록, 원본 이벤트 폐기 + 합성 이벤트 재생성 방식으로 EventTapManager를 리팩토링한다.

**Architecture:** CGEventTap 콜백에서 한글 입력 소스 + Ctrl + 알파벳 keyCode 조건을 만족하면 원본 이벤트를 폐기(return nil)하고, `CGEventSource(stateID: .hidSystemState)`로 IME 메타데이터가 없는 새 CGEvent를 생성하여 `.cghidEventTap`에 post한다. sentinel 값(`eventSourceUserData`)으로 무한루프를 방지한다.

**Tech Stack:** Swift 5.9, SPM, macOS 13+, CoreGraphics (CGEventTap), Carbon (TIS API)

**Spec:** `docs/superpowers/specs/2026-04-15-event-tap-reimpl-design.md`

---

## File Map

| 파일 | 상태 | 역할 |
|------|------|------|
| `Sources/ctrl_b_helper/InputSourceUtils.swift` | 신규 | `isKoreanInputSourceActive()` — 2단계 한글 입력 소스 감지 |
| `Sources/ctrl_b_helper/EventTapManager.swift` | 수정 | 핵심 이벤트 처리 로직 전면 교체 |
| `Sources/CtrlBHelperCore/HangulUtils.swift` | 유지 | `keyCodeToLowerASCII`를 keyCode 필터로 계속 사용 |
| `debug_simulate.swift` | 수정 | 새 로직에 맞게 시뮬레이션 스크립트 업데이트 |

---

### Task 1: InputSourceUtils.swift 생성

**Files:**
- Create: `Sources/ctrl_b_helper/InputSourceUtils.swift`

- [ ] **Step 1: 파일 생성**

```swift
import Carbon

/// 현재 활성 키보드 입력 소스가 한글인지 2단계로 판별한다.
/// 1차: kTISPropertyInputSourceLanguages 배열에 "ko" 포함 여부
/// 2차: kTISPropertyInputSourceID 문자열에 "Korean" 포함 여부 (language 배열 누락 대비)
func isKoreanInputSourceActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        return false
    }

    // 1차: language 배열
    if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
        let languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
        if languages.contains("ko") {
            return true
        }
    }

    // 2차: input source ID
    if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        if id.localizedCaseInsensitiveContains("korean") {
            return true
        }
    }

    return false
}

/// 디버그용: 현재 입력 소스 정보를 로그로 출력한다.
/// isKoreanInputSourceActive()가 false를 반환할 때 호출하여 누락 입력기를 조기에 발견한다.
func logCurrentInputSource() {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        NSLog("[DEBUG] InputSource: unable to get current input source")
        return
    }

    var id = "(unknown)"
    var name = "(unknown)"
    var languages: [String] = []

    if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
        id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    }
    if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
        name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
    }
    if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
        languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
    }

    NSLog("[DEBUG] InputSource: id=%@ name=%@ languages=%@", id, name, languages.joined(separator: ","))
}
```

- [ ] **Step 2: 빌드 확인**

Run: `swift build -c release 2>&1`
Expected: `Build complete!` (에러 없음)

- [ ] **Step 3: 커밋**

```bash
git add Sources/ctrl_b_helper/InputSourceUtils.swift
git commit -m "feat: add InputSourceUtils with 2-tier Korean detection"
```

---

### Task 2: EventTapManager 리팩토링

**Files:**
- Modify: `Sources/ctrl_b_helper/EventTapManager.swift`

- [ ] **Step 1: eventMask에 keyUp 추가, sentinel/targetModifiers 상수 추가**

`EventTapManager` 클래스 상단에 상수를 추가하고, `start()` 메서드의 eventMask를 수정한다.

```swift
final class EventTapManager {
    private static let sentinel: Int64 = 0x4342_4852_4D4150
    private let targetModifiers: CGEventFlags = [.maskControl]

    private let statisticsManager: StatisticsManager
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    // ... isEnabled은 유지
```

`start()` 내 eventMask를 교체:

```swift
let eventMask: CGEventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.keyUp.rawValue) |
    (1 << CGEventType.tapDisabledByTimeout.rawValue) |
    (1 << CGEventType.tapDisabledByUserInput.rawValue)
```

- [ ] **Step 2: handleKeyEvent를 handleKeyEvent(_:type:)으로 교체**

기존 `handleKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent>?` 전체를 삭제하고 다음으로 교체:

```swift
fileprivate func handleKeyEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
    // 합성 이벤트는 통과 (무한루프 방지)
    if event.getIntegerValueField(.eventSourceUserData) == Self.sentinel {
        return Unmanaged.passRetained(event)
    }

    // 대상 modifier 체크 (현재: Ctrl)
    guard !event.flags.intersection(targetModifiers).isEmpty else {
        return Unmanaged.passRetained(event)
    }

    // 대상 keyCode 체크 (a-z 알파벳 키만)
    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    guard keyCodeToLowerASCII[keyCode] != nil else {
        return Unmanaged.passRetained(event)
    }

    // 한글 입력 소스 체크
    guard isKoreanInputSourceActive() else {
        return Unmanaged.passRetained(event)
    }

    // 원본 폐기 + 합성 이벤트 생성
    guard let source = CGEventSource(stateID: .hidSystemState),
          let newEvent = CGEvent(keyboardEventSource: source,
                                 virtualKey: CGKeyCode(keyCode),
                                 keyDown: type == .keyDown) else {
        return Unmanaged.passRetained(event)
    }

    newEvent.flags = event.flags
    newEvent.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)

    NSLog("[DEBUG] REMAP: keyCode=%d type=%@ flags=0x%llX → synthetic event posted",
          keyCode,
          type == .keyDown ? "keyDown" : "keyUp",
          event.flags.rawValue)

    newEvent.post(tap: .cghidEventTap)

    // 통계는 keyDown에서만 기록
    if type == .keyDown {
        statisticsManager.recordRemap()
    }

    return nil  // 원본 폐기
}
```

- [ ] **Step 3: tapCallback에서 keyUp 처리 추가, handleKeyEvent 호출부 수정**

파일 하단의 `tapCallback` 함수를 교체:

```swift
private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        manager.handleTapDisabled()
        return Unmanaged.passRetained(event)
    case .keyDown, .keyUp:
        return manager.handleKeyEvent(event, type: type)
    default:
        return Unmanaged.passRetained(event)
    }
}
```

- [ ] **Step 4: 디버그 전용 NSLog 중 이전 디버그 로그 제거**

Task 2 이전에 추가한 디버그 로그(flagDesc, charHex 등)가 남아 있으면 모두 제거한다. `handleKeyEvent` 내의 `NSLog("[DEBUG] REMAP:...")`만 남긴다.

`start()` 내의 접근성/탭 생성 NSLog 3줄도 제거한다:
- `[DEBUG] Accessibility trusted:`
- `[DEBUG] CGEvent.tapCreate`
- `[DEBUG] Event tap enabled`

- [ ] **Step 5: 빌드 확인**

Run: `swift build -c release 2>&1`
Expected: `Build complete!`

- [ ] **Step 6: 기존 유닛 테스트 통과 확인**

Run: `swift test 2>&1`
Expected: 47개 테스트 전부 통과 (Core 로직 변경 없음)

- [ ] **Step 7: 커밋**

```bash
git add Sources/ctrl_b_helper/EventTapManager.swift
git commit -m "feat: rewrite EventTapManager to consume+recreate events for Korean IME fix"
```

---

### Task 3: 시뮬레이션 스크립트 업데이트 및 동작 확인

**Files:**
- Modify: `debug_simulate.swift`

- [ ] **Step 1: 시뮬레이션 스크립트를 새 로직에 맞게 업데이트**

`debug_simulate.swift`를 다음으로 교체:

```swift
#!/usr/bin/env swift
// 새 이벤트 재생성 로직 검증용 시뮬레이션
import CoreGraphics
import Foundation

let sentinel: Int64 = 0x4342_4852_4D4150

// Test 1: 한글 IME Ctrl+B (keyDown) — 재작성 대상
print("=== Test 1: Ctrl+ㅠ (keyDown, 재작성 대상) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: true) {
    event.flags = .maskControl
    var yu: UniChar = 0x3160
    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &yu)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, char=U+3160 (ㅠ)")
}
usleep(300_000)

// Test 2: 한글 IME Ctrl+B (keyUp) — 재작성 대상
print("=== Test 2: Ctrl+ㅠ (keyUp, 재작성 대상) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: false) {
    event.flags = .maskControl
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, keyUp")
}
usleep(300_000)

// Test 3: 영문 Ctrl+B — 재작성 안 함 (한글 아님)
print("=== Test 3: Ctrl+B (영문, 통과) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: true) {
    event.flags = .maskControl
    var ctrlB: UniChar = 0x0002
    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ctrlB)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, char=U+0002")
}
usleep(300_000)

// Test 4: Ctrl+Space — 알파벳 아님, 통과
print("=== Test 4: Ctrl+Space (비대상, 통과) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true) {
    event.flags = .maskControl
    var space: UniChar = 0x0020
    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &space)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=49, flags=Ctrl, char=U+0020 (space)")
}
usleep(300_000)

// Test 5: sentinel이 있는 이벤트 — 합성 이벤트, 통과
print("=== Test 5: Sentinel 이벤트 (합성, 통과) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: true) {
    event.flags = .maskControl
    event.setIntegerValueField(.eventSourceUserData, value: sentinel)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, sentinel=YES")
}
usleep(300_000)

print("\n=== Done ===")
```

- [ ] **Step 2: 앱 실행 + 시뮬레이션 실행 + 로그 확인**

```bash
# 기존 프로세스 정리
pkill -f ctrl-b-helper 2>/dev/null; sleep 1

# 빌드 + 실행
swift build -c release 2>&1 && \
.build/release/ctrl-b-helper > /tmp/ctrl-b-debug.log 2>&1 &
APP_PID=$!; sleep 2

# 시뮬레이션
swift debug_simulate.swift 2>&1; sleep 1

# 로그 확인
echo "========== APP LOG =========="
cat /tmp/ctrl-b-debug.log

# 정리
kill $APP_PID 2>/dev/null
```

Expected 로그 패턴:
- Test 1: `[DEBUG] REMAP: keyCode=11 type=keyDown` (재작성 발생) — **단, 한글 IME가 활성일 때만. 영문이면 통과**
- Test 2: `[DEBUG] REMAP: keyCode=11 type=keyUp` (동일 조건)
- Test 3: 재작성 없음 (영문이므로 `isKoreanInputSourceActive()` false)
- Test 4: 재작성 없음 (keyCode 49는 `keyCodeToLowerASCII`에 없음)
- Test 5: 재작성 없음 (sentinel 매치로 통과)

**참고:** 시뮬레이션은 현재 시스템의 실제 입력 소스 상태에 따라 결과가 달라진다. 한글 IME 활성 상태에서 실행해야 Test 1, 2에서 REMAP 로그가 나온다.

- [ ] **Step 3: 커밋**

```bash
git add debug_simulate.swift
git commit -m "test: update simulation script for new consume+recreate logic"
```

---

### Task 4: 수동 테스트 실행

**Files:** 없음 (수동 확인)

앱을 `.app` 번들로 빌드하여 실제 환경에서 테스트한다.

- [ ] **Step 1: .app 번들 빌드 및 실행**

```bash
make app && open ctrl-b-helper.app
```

또는 터미널에서 직접 실행 (로그 확인용):

```bash
.build/release/ctrl-b-helper 2>&1 | tee /tmp/ctrl-b-manual-test.log
```

- [ ] **Step 2: 핵심 동작 테스트 (스펙 테스트 #1-5)**

다음을 순서대로 실행하고 결과를 기록:

1. Ghostty + tmux + 한글 2벌식 → Ctrl+B → tmux prefix 진입? (PASS/FAIL)
2. Terminal.app + tmux + 한글 2벌식 → Ctrl+B → tmux prefix 진입? (PASS/FAIL)
3. Ghostty + tmux + 한글 2벌식 → Ctrl+C → 프로세스 종료? (PASS/FAIL)
4. Ghostty + tmux + 영문 ABC → Ctrl+B → tmux prefix 진입, 회귀 없음? (PASS/FAIL)
5. Ghostty + vim + 한글 2벌식 → Ctrl+B → page up? (PASS/FAIL)

- [ ] **Step 3: 비대상 키 테스트 (스펙 테스트 #6-8)**

6. 한글 2벌식 → Ctrl+Space → 입력 소스 전환? (PASS/FAIL)
7. 한글 2벌식 → Ctrl+화살표 → 커서 이동? (PASS/FAIL)
8. 영문 ABC → Ctrl+B → 이벤트 재작성 없음? (PASS/FAIL — 로그에 REMAP 없어야 함)

- [ ] **Step 4: 통계 테스트 (스펙 테스트 #12-13)**

12. 통계 초기화 → 한글 + Ctrl+B 3회 → 메뉴바 카운트 = 3? (PASS/FAIL — 6이면 FAIL)
13. 영문 + Ctrl+B 3회 → 카운트 변화 없음? (PASS/FAIL)

- [ ] **Step 5: 테스트 FAIL 시 대응**

- 핵심 동작 FAIL (합성 이벤트가 여전히 IME에 소비됨): 폴백 2번 적용 — `handleKeyEvent`에서 keyDown일 때 합성 이벤트에 `keyboardSetUnicodeString`으로 명시적 제어문자 설정 추가:

```swift
// handleKeyEvent 내, newEvent.post 직전에 추가 (keyDown만):
if type == .keyDown, let ascii = keyCodeToLowerASCII[keyCode] {
    var ctrl = UniChar(ascii & 0x1F)
    newEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ctrl)
}
```

- 통계 2배 집계: `recordRemap()` 호출이 keyDown 분기 안에 있는지 확인
- 한글 감지 실패: `/tmp/ctrl-b-debug.log`에서 `InputSource:` 로그로 입력 소스 ID/이름 확인

---

### Task 5: 디버그 로그 정리 및 최종 커밋

**Files:**
- Modify: `Sources/ctrl_b_helper/EventTapManager.swift`
- Modify: `Sources/ctrl_b_helper/InputSourceUtils.swift`

**주의:** 수동 테스트를 모두 PASS한 후에만 이 Task를 실행한다.

- [ ] **Step 1: EventTapManager에서 디버그 NSLog 제거**

`handleKeyEvent` 내의 `NSLog("[DEBUG] REMAP:...")` 줄을 삭제한다.

- [ ] **Step 2: InputSourceUtils에서 logCurrentInputSource() 함수는 유지**

`logCurrentInputSource()`는 향후 진단용으로 유지한다. 단, `handleKeyEvent`에서 호출하는 부분이 있다면 제거한다 (매 키 입력마다 호출되면 성능 문제).

- [ ] **Step 3: 빌드 + 테스트 최종 확인**

```bash
swift build -c release 2>&1 && swift test 2>&1
```

Expected: 빌드 성공, 47개 테스트 통과

- [ ] **Step 4: 최종 커밋**

```bash
git add Sources/ctrl_b_helper/EventTapManager.swift Sources/ctrl_b_helper/InputSourceUtils.swift
git commit -m "chore: remove debug logging from EventTapManager"
```
