# Research: macOS Korean IME + Ctrl Key Issue Analysis

## Problem Definition

On macOS, pressing Ctrl+b while the Korean IME is active causes the shortcut to fail silently in terminals (e.g., tmux).

## Debugging Findings

Debug logging was added to the CGEventTap callback to observe the actual events:

### CGEvent level is fine

```
Korean IME + Ctrl+b → keyCode=11 flags=[Ctrl] chars=[U+0002]  ← already correct
English    + Ctrl+b → keyCode=11 flags=[Ctrl] chars=[U+0002]  ← identical
Korean IME + B (no Ctrl) → keyCode=11 flags=[] chars=[U+3160]  ← ㅠ
```

- With Ctrl held, macOS already converts the event to a control character (U+0002) at the CGEvent level
- The Hangul character (ㅠ, U+3160) only appears when Ctrl is not pressed
- Therefore, modifying the Unicode string via `keyboardSetUnicodeString` is ineffective

### Where the problem actually occurs

```
CGEvent (U+0002 — correct)
  → NSEvent
    → Terminal's keyDown:
      → interpretKeyEvents:
        → Korean IME consumes the event ← problem is here
          → byte never reaches tmux
```

When the terminal emulator processes keys through `interpretKeyEvents:` with the Korean IME active, **the Korean IME consumes the Ctrl+key event in raw mode (tmux)**. The byte never reaches the application.

### Test results by environment

| Environment | Result | Implication |
|-------------|--------|-------------|
| Ghostty + `cat` + Korean + Ctrl+b | ^B printed normally | IME passes through in cooked mode |
| Ghostty + tmux + Korean + Ctrl+b | **No response** | IME consumes event in raw mode |
| Terminal.app + tmux + Korean + Ctrl+b | **Fails** | Common problem across terminal emulators |

---

## Approach Comparison

### A. Event discard + new CGEvent creation (adopted)

When Ctrl+key is detected with Korean IME active, discard the original event and inject a new CGEvent without IME metadata.

**Confidence: High**

- The new event has no IME metadata, so the terminal processes it directly instead of through `interpretKeyEvents:`
- cmd-eikana (Japanese keyboard tool) uses the same technique successfully
- Works regardless of terminal emulator

**Implementation key points:**
- Detect Korean input source via `TISCopyCurrentKeyboardInputSource` (not an `isHangul` character check)
- Use `eventSourceUserData` field (field 42) with a sentinel value to prevent infinite loops
- Post to `.cghidEventTap` (creating the tap requires root, but posting does not)
- Handle both keyDown and keyUp events

### B. Input source switching (switch to English when Ctrl is pressed)

**Confidence: Low — not adopted**

- `TISSelectInputSource` CJKV bug: for Korean/Chinese/Japanese input sources, only the menu bar icon changes; the actual switch does not happen (Karabiner-Elements issue #1602)
- Menu bar input source indicator flickers on every Ctrl keypress
- Input source switching is asynchronous — key events can arrive before the switch completes, creating a race condition
- Affects all apps, not just terminals (input source switches whenever Ctrl is pressed in a browser, etc.)

### C. CGEvent field modification

**Confidence: Low — not adopted**

- IME metadata is not stored in CGEvent integer fields
- Documented keyboard fields: keyCode (9), autorepeat (8), keyboardType (10) — no IME-related fields
- Manipulating undocumented fields risks behavior changes across macOS versions

### D. Create tap at .cghidEventTap

**Not feasible**

- Creating a tap at `.cghidEventTap` requires root privileges. Not realistic for a menu bar app.

### E. NSEvent monitor

**Not feasible**

- `NSEvent.addGlobalMonitorForEvents`: read-only; cannot modify or consume events
- `NSEvent.addLocalMonitorForEvents`: only handles the app's own events

---

## Related Issues and References

### Terminal emulators

- [Ghostty #2628](https://github.com/ghostty-org/ghostty/discussions/2628): Input method keybinds penetrate
- [Ghostty #2934](https://github.com/ghostty-org/ghostty/discussions/2934): macOS text input system and control keys
- [Ghostty #5487](https://github.com/ghostty-org/ghostty/discussions/5487): Ctrl key not working in 1.1.0 for non-US layouts
- [WezTerm #2435](https://github.com/wezterm/wezterm/pull/2435): Enable control key in macOS IME
- [Kitty #1586](https://github.com/kovidgoyal/kitty/pull/1586): Fix macOS input method
- [Kitty #4062](https://github.com/kovidgoyal/kitty/issues/4062): Chinese IME control keys displayed directly
- [iTerm2 #279](https://github.com/gnachman/iTerm2/pull/279): Use handleEvent instead of interpretKeyEvents

### Keyboard / input source tools

- [Karabiner-Elements #1602](https://github.com/pqrs-org/Karabiner-Elements/issues/1602): CJKV input source switching workaround
- [cmd-eikana](https://github.com/iMasanari/cmd-eikana): Uses CGEventTap consume+recreate approach
- [Kawa](https://github.com/hatashiro/kawa): Workaround for TISSelectInputSource CJKV bug
- [Gureum](https://github.com/gureum/gureum): Apple IME replacement — solves the root problem but is a heavy approach

### Other

- [Claude Code #29478](https://github.com/anthropics/claude-code/issues/29478): Korean IME composition buffer leaks into tmux
- [CGEventField documentation](https://developer.apple.com/documentation/coregraphics/cgeventfield)
- [tmux Modifier Keys wiki](https://github.com/tmux/tmux/wiki/Modifier-Keys)
