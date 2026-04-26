# ADR 0002: Prefix Follow-up Key Remap

## Problem

With Korean IME active, after the tmux prefix (`Ctrl+b`) the command key (`n`, `c`, `p`, etc.) is delivered as a Korean jamo character (`ㅜ`, `ㅊ`, `ㅔ`, etc.), so tmux cannot recognize the command. Symbol keys like `[` are unaffected by the IME and work normally.

## Solution

Immediately after a Ctrl+b remap, also remap the next **modifier-free alphabet keyDown** within **1.5 seconds** from Korean to the corresponding ASCII character.

## Target Prefix Key

- Currently: **Ctrl+b only** (keyCode 11)
- Managed via a `prefixKeyCode` property for future configurability

## Event Flow

```
Ctrl+b keyDown remap fires
  → pendingFollowUp = true
  → start 1.5s timer (DispatchWorkItem)

Next keyDown arrives
  ├─ pendingFollowUp == false → normal logic (unchanged)
  │
  └─ pendingFollowUp == true
       ├─ no modifier + alphabet key (in keyCodeToLowerASCII) + Korean IME
       │    → discard original + create/post synthetic event (same consume+recreate technique)
       │    → recordRemap()
       │
       ├─ anything else (symbol, Enter, Esc, key with modifier, etc.)
       │    → pass through (no event modification)
       │
       └─ regardless of key: pendingFollowUp = false, cancel timer

Timer fires (1.5s)
  → pendingFollowUp = false

keyUp events
  → pendingFollowUp flag unaffected
```

## Files Changed

### Modified: `Sources/ctrl_b_helper/EventTapManager.swift`

**New state:**
```swift
private let prefixKeyCode: Int64 = 11  // Ctrl+b (configurable in the future)
private var pendingFollowUp = false
private var followUpTimer: DispatchWorkItem?
private let followUpTimeout: TimeInterval = 1.5
```

**handleKeyEvent changes:**

1. After the existing Ctrl+alphabet remap logic, if the keyCode matches `prefixKeyCode` and it is a keyDown: set the follow-up flag and start the timer.

2. At method entry, if `pendingFollowUp` is true and it is a keyDown, enter the follow-up branch:
   - no modifier + alphabet key + Korean IME → consume+recreate (with sentinel) + **set explicit ASCII via `keyboardSetUnicodeString`**
   - condition not met → pass through
   - in either case: reset flag + cancel timer

**Why follow-up remapping requires `keyboardSetUnicodeString` but Ctrl+key does not:**
Spike tests (`spike_followup.swift`) confirmed:
- Synthetic event with keyCode only → Korean IME still converts to ㅜ (FAIL)
- Synthetic event with keyCode + `keyboardSetUnicodeString('n')` → English n delivered (PASS)

Ctrl+key events have a modifier, so the IME already treats them as control characters and the explicit Unicode string is unnecessary. Bare alphabet keys without a modifier are converted to Hangul by the IME, so the explicit string is required.

Use `keyCodeToLowerASCII` to map keyCode → ASCII, then set as `UniChar`. Apply to keyDown only; keyUp does not need it (confirmed in spike tests).

Set the sentinel on synthetic events to prevent infinite loops. Call `recordRemap()` on keyDown only.

**Follow-up check runs before Ctrl+key check.** Order:
1. Sentinel check (infinite loop guard)
2. Follow-up check (`pendingFollowUp == true && keyDown`)
3. Ctrl+alphabet check (existing logic)

Rationale: follow-up keys have no modifier so they do not reach the Ctrl check anyway. In the Ctrl+b → Ctrl+b case (prefix cancel + retry), the second Ctrl+b has a modifier and fails the follow-up condition (no modifier required), so it passes through to the Ctrl+key logic correctly.

### Unchanged

- `Sources/ctrl_b_helper/InputSourceUtils.swift`
- `Sources/CtrlBHelperCore/HangulUtils.swift`
- `Sources/CtrlBHelperCore/StatisticsManager.swift`
- `Sources/ctrl_b_helper/StatusBarController.swift`

## Timeout Rationale

- Proficient tmux users: command key within 100–500 ms after prefix
- Slow/hesitant users: within 1 second
- 1.5 s: covers 99%+ of cases while minimizing false positives (more conservative than Karabiner-Elements' `to_if_alone_timeout` of 1000 ms)
- False positive impact: one English character instead of one Hangul character — correctable with a single Backspace

## Safety Mechanisms

1. **Modifier keys excluded** — Ctrl+b followed by Ctrl+C is a new shortcut, not a follow-up. A key with a modifier fails the follow-up condition and passes through to the Ctrl+key logic.
2. **Single-shot consumption** — any keyDown resets `pendingFollowUp` to false. No leakage into subsequent input.
3. **1.5 s auto-expiry** — Hangul typed well after a Ctrl+b is unaffected.
4. **keyUp handling** — follow-up remaps keyDown only; keyUp passes through as-is. Spike tests confirmed that setting `keyboardSetUnicodeString` on keyDown only (not keyUp) works correctly. tmux processes prefix commands on keyDown, so mismatched keyUp has no practical effect. The `pendingFollowUp` flag is only checked/consumed on keyDown, so keyUp naturally passes through.

## Test Plan

### Manual tests — core behavior

| # | Environment | Input | Expected | PASS Criteria |
|---|-------------|-------|----------|---------------|
| 1 | Ghostty + tmux + Korean | Ctrl+b → n | next-window fires | Window switches |
| 2 | Ghostty + tmux + Korean | Ctrl+b → c | new-window fires | New window created |
| 3 | Ghostty + tmux + Korean | Ctrl+b → p | previous-window fires | Window switches |
| 4 | Ghostty + tmux + Korean | Ctrl+b → [ | copy mode entered | Scrolling works (symbol, pre-existing behavior) |
| 5 | Ghostty + tmux + Korean | Ctrl+b → d | detach | Detached from tmux session |

### Manual tests — edge cases

| # | Input | Expected |
|---|-------|----------|
| 6 | Korean + Ctrl+b → (wait 2 s) → Hangul | Hangul typed normally (no remap) |
| 7 | Korean + Ctrl+b → Enter | Enter passes through; follow-up reset |
| 8 | Korean + Ctrl+b → Ctrl+b (retry) | Follow-up reset on first Ctrl+b (modifier → condition fail); second Ctrl+b processed normally |
| 9 | English + Ctrl+b → n | Existing behavior (no remap needed; no interference) |
| 10 | Korean + Ctrl+C → Hangul | Hangul typed normally (Ctrl+C is not a prefix; no follow-up) |

### Manual tests — statistics

| # | Input | Expected |
|---|-------|----------|
| 11 | Korean + Ctrl+b → n | Count +2 (Ctrl+b once + follow-up n once) |
