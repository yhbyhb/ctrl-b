# EventTapManager 리팩토링 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 한글 IME 활성 상태에서 Ctrl+알파벳 단축키가 tmux/vim 등 터미널 앱에서 동작하도록, 원본 이벤트 폐기 + 합성 이벤트 재생성 방식으로 EventTapManager를 리팩토링한다.

**Architecture:** CGEventTap 콜백에서 한글 입력 소스 + Ctrl + 알파벳 keyCode 조건을 만족하면 원본 이벤트를 폐기(return nil)하고, `CGEventSource(stateID: .hidSystemState)`로 IME 메타데이터가 없는 새 CGEvent를 생성하여 `.cghidEventTap`에 post한다. sentinel 값(`eventSourceUserData`)으로 무한루프를 방지한다.

**Tech Stack:** Swift 5.9, SPM, macOS 13+, CoreGraphics (CGEventTap), Carbon (TIS API)

**Spec:** `docs/plans/2026-04-15-event-tap-reimpl-design.md`

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
    if !isKoreanInputSourceActive() {
        // Ctrl+알파벳 keyDown인데 한글 감지 실패 → 누락 입력기 디버깅용 로그 (keyDown만, 1회)
        if type == .keyDown {
            logCurrentInputSource()
        }
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

Task 2 이전에 추가한 디버그 로그(flagDesc, charHex 등)가 남아 있으면 모두 제거한다. 다음은 **유지**:
- `handleKeyEvent` 내의 `NSLog("[DEBUG] REMAP:...")`
- `handleKeyEvent` 내의 `logCurrentInputSource()` 호출
- `start()` 내의 접근성/탭 생성 NSLog 3줄 (`Accessibility trusted`, `tapCreate`, `Event tap enabled`) — 수동 테스트 단계에서 탭 생성 실패/권한 문제를 진단하는 데 필요하므로 Task 5까지 유지

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

`debug_simulate.swift`를 다음으로 교체. 이 스크립트는 **한글 입력 소스가 활성인 상태에서 실행**하는 것을 전제로 한다. 영문 상태 테스트는 Step 2b에서 별도로 진행한다.

```swift
#!/usr/bin/env swift
// 새 이벤트 재생성 로직 검증용 시뮬레이션
// 전제: 한글 입력 소스(2벌식 등)가 활성인 상태에서 실행
import CoreGraphics
import Foundation

let sentinel: Int64 = 0x4342_4852_4D4150

// Test 1: Ctrl+b (keyDown) — 한글 활성이므로 재작성 대상
print("=== Test 1: Ctrl+b keyDown (한글 활성 → 재작성 대상) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: true) {
    event.flags = .maskControl
    var yu: UniChar = 0x3160
    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &yu)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, char=U+3160 (ㅠ)")
}
usleep(300_000)

// Test 2: Ctrl+b (keyUp) — 한글 활성이므로 재작성 대상
print("=== Test 2: Ctrl+b keyUp (한글 활성 → 재작성 대상) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: false) {
    event.flags = .maskControl
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, keyUp")
}
usleep(300_000)

// Test 3: Ctrl+Space — 알파벳 아님, 입력 소스 무관하게 항상 통과
print("=== Test 3: Ctrl+Space (비알파벳 → 항상 통과) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true) {
    event.flags = .maskControl
    var space: UniChar = 0x0020
    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &space)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=49, flags=Ctrl, char=U+0020 (space)")
}
usleep(300_000)

// Test 4: sentinel이 있는 이벤트 — 합성 이벤트, 항상 통과
print("=== Test 4: Sentinel 이벤트 (합성 → 항상 통과) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: true) {
    event.flags = .maskControl
    event.setIntegerValueField(.eventSourceUserData, value: sentinel)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, sentinel=YES")
}
usleep(300_000)

print("\n=== Done ===")
```

- [ ] **Step 2a: 한글 입력 소스 활성 상태에서 시뮬레이션 실행**

**사전 조건:** 시스템 입력 소스를 한글 2벌식으로 전환한 후 실행.

```bash
pkill -f ctrl-b-helper 2>/dev/null; sleep 1
swift build -c release 2>&1 && \
.build/release/ctrl-b-helper > /tmp/ctrl-b-debug.log 2>&1 &
APP_PID=$!; sleep 2
swift debug_simulate.swift 2>&1; sleep 1
echo "========== APP LOG (한글) =========="
cat /tmp/ctrl-b-debug.log
kill $APP_PID 2>/dev/null
```

Expected:
- Test 1: `[DEBUG] REMAP: keyCode=11 type=keyDown` (재작성 발생)
- Test 2: `[DEBUG] REMAP: keyCode=11 type=keyUp` (재작성 발생)
- Test 3: REMAP 없음 (keyCode 49는 알파벳이 아님)
- Test 4: REMAP 없음 (sentinel 매치)

- [ ] **Step 2b: 영문 입력 소스 활성 상태에서 시뮬레이션 실행**

**사전 조건:** 시스템 입력 소스를 영문 ABC로 전환한 후 실행.

```bash
pkill -f ctrl-b-helper 2>/dev/null; sleep 1
.build/release/ctrl-b-helper > /tmp/ctrl-b-debug-en.log 2>&1 &
APP_PID=$!; sleep 2
swift debug_simulate.swift 2>&1; sleep 1
echo "========== APP LOG (영문) =========="
cat /tmp/ctrl-b-debug-en.log
kill $APP_PID 2>/dev/null
```

Expected:
- Test 1, 2: REMAP 없음 (영문이므로 `isKoreanInputSourceActive()` false)
- Test 3, 4: REMAP 없음 (동일)

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

1. Ghostty + tmux + 한글 2벌식 → Ctrl+b → tmux prefix 진입? (PASS/FAIL)
2. Terminal.app + tmux + 한글 2벌식 → Ctrl+b → tmux prefix 진입? (PASS/FAIL)
3. Ghostty + tmux + 한글 2벌식 → Ctrl+C → 프로세스 종료? (PASS/FAIL)
4. Ghostty + tmux + 영문 ABC → Ctrl+b → tmux prefix 진입, 회귀 없음? (PASS/FAIL)
5. Ghostty + vim + 한글 2벌식 → Ctrl+b → page up? (PASS/FAIL)

- [ ] **Step 3: 비대상 키 테스트 (스펙 테스트 #6-8)**

6. 한글 2벌식 → Ctrl+Space → 입력 소스 전환? (PASS/FAIL)
7. 한글 2벌식 → Ctrl+화살표 → 커서 이동? (PASS/FAIL)
8. 영문 ABC → Ctrl+b → 이벤트 재작성 없음? (PASS/FAIL — 로그에 REMAP 없어야 함)

- [ ] **Step 4: 통계 테스트 (스펙 테스트 #12-13)**

12. 통계 초기화 → 한글 + Ctrl+b 3회 → 메뉴바 카운트 = 3? (PASS/FAIL — 6이면 FAIL)
13. 영문 + Ctrl+b 3회 → 카운트 변화 없음? (PASS/FAIL)

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

다음을 모두 삭제:
- `handleKeyEvent` 내의 `NSLog("[DEBUG] REMAP:...")` 줄
- `handleKeyEvent` 내의 `logCurrentInputSource()` 호출
- `start()` 내의 `NSLog("[DEBUG] Accessibility trusted:...")`, `NSLog("[DEBUG] CGEvent.tapCreate...")`, `NSLog("[DEBUG] Event tap enabled...")` 3줄

- [ ] **Step 2: InputSourceUtils에서 logCurrentInputSource() 함수 자체는 유지**

`logCurrentInputSource()` 함수 정의는 향후 수동 진단용으로 유지한다. `handleKeyEvent`에서의 호출만 Step 1에서 제거.

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
