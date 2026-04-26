# ADR 0001: EventTapManager Refactor — Event Discard + Recreate

## Background

Ctrl+key shortcuts (e.g., tmux prefix) fail silently in terminals when macOS Korean IME is active.

Debugging revealed that the CGEvent Unicode string is already correct (U+0002) at the CGEvent level. The real problem is that the Korean IME consumes the event at the `interpretKeyEvents:` layer during terminal key processing. See `docs/research-korean-ime-ctrl-key.md` for the full analysis.

The prior approach (modifying the Unicode string in-place) does not work. The decision was to switch to **discarding the original event and creating a new CGEvent free of IME metadata**.

## Rewrite Scope

**Not all Ctrl+key events are rewritten** — only those affected by the Korean IME:

- **Target**: Only the 26 alphabet keyCodes (a–z) registered in `keyCodeToLowerASCII`
- **Pass-through**: Ctrl+Space, Ctrl+arrow, Ctrl+number, Ctrl+punctuation, Ctrl+Tab, Ctrl+Enter, etc.

The Korean IME only converts alphabet keys to Hangul jamo, so non-alphabet keys are not subject to IME interference and do not need rewriting. The `keyCodeToLowerASCII` dictionary is reused as the target keyCode filter.

## Event Handling Flow

```
CGEventTap callback (keyDown / keyUp)
  │
  ├─ eventSourceUserData == sentinel? → pass (synthetic event, infinite loop guard)
  │
  ├─ tapDisabledByTimeout / tapDisabledByUserInput? → re-enable tap
  │
  └─ keyDown / keyUp
       │
       ├─ Contains target modifier? (currently: Ctrl)
       │    │
       │    ├─ keyCode is alphabet? (exists in keyCodeToLowerASCII)
       │    │    │
       │    │    ├─ Korean input source active?
       │    │    │    │
       │    │    │    ├─ YES → discard original (return nil) + create/post new CGEvent
       │    │    │    │        + record stats (keyDown only)
       │    │    │    │
       │    │    │    └─ NO → pass through
       │    │    │
       │    │    └─ Not an alphabet key → pass through
       │    │
       │    └─ No target modifier → pass through
       │
       └─ No modifier → pass through
```

## Files Changed

### Modified: `Sources/ctrl_b_helper/EventTapManager.swift`

Core change. The `handleKeyEvent` logic is fully replaced.

**eventMask change:**
- Before: `keyDown` + `tapDisabled` (2 types)
- After: `keyDown` + `keyUp` + `tapDisabled` (3 types — terminals need consistent keyDown/keyUp pairs)

**Target modifier:**
```swift
private let targetModifiers: CGEventFlags = [.maskControl]
```
Adding `.maskCommand` later would extend coverage to Cmd+key. Check:
```swift
!event.flags.intersection(targetModifiers).isEmpty
```

**Target keyCode filter:**
```swift
let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
guard keyCodeToLowerASCII[keyCode] != nil else {
    return Unmanaged.passRetained(event)  // not an alphabet key — pass through
}
```

**Infinite loop prevention:**
```swift
private static let sentinel: Int64 = 0x4342_4852_4D4150

// At callback entry:
if event.getIntegerValueField(.eventSourceUserData) == sentinel {
    return Unmanaged.passRetained(event)
}

// When creating synthetic event:
newEvent.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)
```

**Synthetic event creation:**
```swift
let source = CGEventSource(stateID: .hidSystemState)
let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
let isKeyDown = (type == .keyDown)

guard let newEvent = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: isKeyDown) else {
    return Unmanaged.passRetained(event)
}

newEvent.flags = event.flags  // preserve original modifiers (e.g. Ctrl+Shift)
newEvent.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)
newEvent.post(tap: .cghidEventTap)

// Record stats on keyDown only (avoid double-counting on keyUp)
if isKeyDown {
    statisticsManager.recordRemap()
}

return nil  // discard original
```

**Post location and fallback strategy:**

Posting to `.cghidEventTap` routes the event through the full pipeline, so the IME could theoretically consume the synthetic event again. Fallback tiers:

1. **Post to `.cghidEventTap`** (default). Synthetic events created with `CGEventSource(stateID: .hidSystemState)` are independent of IME composition state, so terminals are likely to process them directly. cmd-eikana (Japanese keyboard tool) uses the same approach successfully.
2. **Explicitly set control character via `keyboardSetUnicodeString` (ascii & 0x1F), then post to `.cghidEventTap`** (keyDown only; unnecessary for keyUp). The difference from (1): the event carries an explicit Unicode string, giving the terminal a direct hint to bypass IME interpretation.
3. **Fundamentally different approach**: input source switching or other techniques (outside current scope).

Tier 1 is implemented by default; tier 2 is applied if tier 1 proves insufficient. Note: posting to `.cgSessionEventTap` is not a valid fallback — our tap is already attached at `.cgSessionEventTap`, so it has no practical difference from tier 1.

**Removed logic:**
- `isHangul()` check-based branching
- Unicode conversion via `keyCodeToLowerASCII` (retained as keyCode filter only)
- Debug `NSLog` calls (removed after development)

### New: `Sources/ctrl_b_helper/InputSourceUtils.swift`

Korean input source detection utility. Depends on the Carbon framework (`TIS*` APIs), so it lives in the **main app target** (not CtrlBCore, which must remain free of system API dependencies).

```swift
import Carbon

func isKoreanInputSourceActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        return false
    }

    // Step 1: check "ko" in language array
    if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
        let languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
        if languages.contains("ko") {
            return true
        }
    }

    // Step 2: check "Korean" in input source ID (for IMEs with empty language arrays)
    if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        if id.localizedCaseInsensitiveContains("korean") {
            return true
        }
    }

    return false
}
```

**Two-step detection:**
1. `kTISPropertyInputSourceLanguages` array contains `"ko"` — covers Apple IME and most third-party IMEs
2. `kTISPropertyInputSourceID` string contains `"Korean"` — fallback for IMEs with empty or missing language arrays

When `isKoreanInputSourceActive()` returns false, the core feature is disabled. During development, log the input source ID, localizedName, and language array whenever the function returns false on a Ctrl+alphabet event — this catches undetected IMEs early.

### Unchanged: `Sources/CtrlBHelperCore/HangulUtils.swift`

`isHangul()` and `keyCodeToLowerASCII` are not used directly for remapping in the new logic, but are kept:
- `keyCodeToLowerASCII` is reused as the target keyCode filter
- Small code size; 3 test files reference it
- Potentially useful for diagnostics or future statistics

### Unchanged: `Sources/CtrlBHelperCore/StatisticsManager.swift`

No changes. `recordRemap()` is called from the new logic on keyDown only (not keyUp, to avoid double-counting).

### Unchanged: `Sources/ctrl_b_helper/StatusBarController.swift`

No changes.

## Known Risks

### Synthetic event may still be consumed by IME

The Korean IME is still active when the synthetic event is posted. It could consume the event again at `interpretKeyEvents:`. However:
- Synthetic events from `CGEventSource(stateID: .hidSystemState)` are independent of IME composition state
- cmd-eikana (Japanese keyboard tool) uses the same approach and works correctly
- If this fails, fallback tier 2 (explicit Unicode string) is available

### Interaction with other event tap apps

Posting to `.cghidEventTap` means apps like Karabiner-Elements may intercept the synthetic event. The sentinel value is only recognized by ctrl-b; other apps treat the event as a normal keypress.

### IME detection coverage gaps

The two-step detection may still miss some third-party IMEs. Collect missed cases via debug logging during development and add them to the detection logic when found.

## Test Plan

### Build and unit tests

- `swift build -c release` succeeds
- `swift test` — all tests pass (Core logic unchanged)

### Manual tests — core behavior

Each item is judged **PASS/FAIL**. Any FAIL blocks release.

| # | Environment | Input | Expected | PASS Criteria |
|---|-------------|-------|----------|---------------|
| 1 | Ghostty + tmux + Korean 2-Set | Ctrl+b | tmux enters prefix mode | Status bar color changes or follow-up key works |
| 2 | Terminal.app + tmux + Korean 2-Set | Ctrl+b | tmux enters prefix mode | Same |
| 3 | Ghostty + tmux + Korean 2-Set | Ctrl+A or Ctrl+C | Shortcut works | Process exits or expected behavior |
| 4 | Ghostty + tmux + English ABC | Ctrl+b | tmux enters prefix mode | No regression from original behavior |
| 5 | Ghostty + vim + Korean 2-Set | Ctrl+b (page up) | Page scrolls up | Screen scrolls up |

### Manual tests — non-target keys (no interference)

| # | Environment | Input | Expected |
|---|-------------|-------|----------|
| 6 | Korean 2-Set | Ctrl+Space | Input source switches normally |
| 7 | Korean 2-Set | Ctrl+arrow | Cursor moves word by word (app-dependent) |
| 8 | English ABC | Ctrl+b | No change in behavior (app does not rewrite event) |

### Manual tests — edge cases

| # | Input | Expected |
|---|-------|----------|
| 9 | Korean + Ctrl+Shift+key | Modifier preserved; combination works |
| 10 | Korean + Ctrl+b held (autorepeat) | Repeated events handled correctly; no hang or crash |
| 11 | Korean + Ctrl+b rapid tapping | All events processed; no dropped events |

### Manual tests — statistics

| # | Input | Expected |
|---|-------|----------|
| 12 | Korean + Ctrl+b × 3 | Menu bar "today" count increases by exactly 3 (not 6 — keyDown only) |
| 13 | English + Ctrl+b × 3 | Count unchanged (no rewriting under English layout) |

### Debug logging

During development, log via `NSLog`:
- On rewrite: keyCode, original flags, post location
- When `isKoreanInputSourceActive()` returns false: current input source ID, localizedName, language array (to detect missed IMEs early — localizedName helps identify the IME)
