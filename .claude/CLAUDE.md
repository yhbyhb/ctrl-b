# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Does

A menu-bar-resident macOS app that fixes the issue where Ctrl+alphabet shortcuts (e.g., tmux prefix) fail to work in terminals when a CJK IME (Korean, Chinese, Japanese, etc.) is active. It intercepts key events via CGEventTap, discards the original event, and injects a newly synthesized event that is free of IME metadata.

## Build & Test Commands

```bash
swift build -c release    # Release build
swift test                # Run all tests
swift test --filter StatisticsManagerTests           # Run a specific test class
swift test --filter StatisticsManagerTests/test_record_incrementsCount  # Run a single test
make app                  # Create .app bundle (.build/release -> ctrl-b.app)
make install              # Install to /Applications
make lint                 # Run SwiftLint (--strict)
make lint-fix             # Auto-fix SwiftLint violations
make setup                # Initial dev environment setup (git hooks)
```

## Architecture

Split into two SPM targets:

- **CtrlBCore** (`Sources/CtrlBCore/`) — Pure, testable logic with no Cocoa/CoreGraphics dependencies.
  - `isHangul()`: Determines whether a UniChar is Korean (covers Jamo, Compatibility Jamo, and Syllables ranges)
  - `keyCodeToLowerASCII`: Dictionary mapping macOS physical keyCode (Int64) to lowercase ASCII (UInt8)
  - `StatisticsManager`: Tracks remap count and estimated time saved using UserDefaults (supports DI for testing)
  - `inputSourceDisplay()`: Maps a TIS language tag + localized name into a flag-emoji/display-name struct for the About panel. Prefix-based matching with `zh-Hant*` checked before `zh*`.
  - `isInputMethod()`: Pure check for `TISTypeKeyboardInputMode` source type.

- **CtrlB** (`Sources/CtrlB/`) — App executable. Uses Cocoa, CoreGraphics, Carbon, and ServiceManagement frameworks.
  - `AppDelegate`: App initialization using factory-closure DI for all dependencies (enabling full unit test coverage). Handles Accessibility permission detection (via DistributedNotificationCenter `com.apple.accessibility.api` + 3-second polling fallback) and auto-starts the event tap when permission is granted.
  - `EventTapManager`: In the CGEventTap callback, when IME + Ctrl + alphabet keyCode conditions are met, discards the original event (return nil) and creates/posts a synthetic event via `CGEventSource(stateID: .hidSystemState)`. Uses an `eventSourceUserData` sentinel value to prevent infinite loops. After remapping a prefix key (Ctrl+b), also remaps follow-up keys pressed within 1.5 seconds.
  - `EventTapEngine`: Wraps CGEventTap creation/lifecycle; implements `EventTapEngineControlling` and is injected into `EventTapManager` for testability.
  - `AppRuntimeSupport`: Defines protocols (`EventTapControlling`, `AccessibilityPermissionObserving`, `RepeatingTask`) and concrete implementations (`AccessibilityPermissionObserver`, `TimerRepeatingTask`) used for DI throughout.
  - `AccessibilityPermissionController`: Implements `AccessibilityPermissionControlling` for `AXIsProcessTrusted` checks; injected into `EventTapManager` and `AppDelegate`.
  - `StatusMenuModel`: Value-type model — `EventTapState` enum, `StatusMenuModel` struct, `StatusMenuModelBuilder` for state-to-menu-model mapping.
  - `InputSourceUtils`: Detects IME input sources based on `TISCopyCurrentKeyboardInputSource` (`kTISTypeKeyboardInputMode` check). Includes `logCurrentInputSource()` for debugging.
  - `StatusBarController`: Uses NSMenuDelegate to refresh statistics each time the menu opens (no Timer needed). Uses `lazy var` for `NSStatusBar.system` to defer init and prevent crashes in headless CI.
  - `Localization`: `Strings` enum wrapping `NSLocalizedString` for compile-time key safety.
  - `LaunchAtLoginManager`: Based on SMAppService (macOS 13+)
  - `AboutPanelController`: Builds a custom Credits `NSAttributedString` (keycap demo, live IME indicator, lifetime stats, project links) and shows Apple's standard About panel via `orderFrontStandardAboutPanel`. Credits body is English-only; only the menu item title is localized.

## Key Design Decisions

- **Event consume + recreate**: The CGEvent callback discards the original event (return nil) and posts a new synthetic event via `CGEventSource(stateID: .hidSystemState)` to `.cghidEventTap`, free of IME metadata. In-place Unicode string modification does not work because the CGEvent already contains the correct value (U+0002) — the actual problem is that the Korean IME consumes the event at the `interpretKeyEvents:` layer.
- **Sentinel-based infinite loop prevention**: Synthetic events are tagged with an `eventSourceUserData` field (0x4342_4852_4D4150) so the tap does not reprocess its own events.
- **Scoped remapping**: Only the 26 a-z keyCodes registered in `keyCodeToLowerASCII` are remapped. Ctrl+Space, Ctrl+arrow keys, etc. pass through unchanged.
- **Core separation**: Code that depends on system APIs like CGEvent cannot be unit-tested, so pure logic (Hangul detection, keyCode mapping, statistics) is extracted into Core. CtrlB target files are tested via protocol DI mocks.
- **DI throughout**: Protocol-based DI (and factory closures in `AppDelegate`) spans the entire app — `EventTapManager`, `StatusBarController`, and `AppDelegate` all have unit tests via mock implementations of their protocol dependencies.
- **StatisticsManager DI**: `UserDefaults` is injected via the initializer, allowing tests to use an isolated suite.
- **Lazy NSStatusBar init**: `StatusBarController` uses `lazy var statusItem` to defer `NSStatusBar.system` access, preventing crashes when tests run in a headless (no-window-server) environment.
- **LSUIElement=true**: Hides the Dock icon; the app runs as a menu-bar-only app.
- **os.Logger**: Structured logging under the `com.yhbyhb.ctrl-b` subsystem. Supports per-category filtering in Console.app.

## Conventions

- UI strings, code comments, and documentation are written in English.
- Korean is supported as a localization target (planned).
- Commit messages in English (conventional commits).
- Update README.md and CLAUDE.md in the same PR when changing features.

## Planning documents

Architecture decisions live in `docs/adr/` as numbered ADRs (`NNNN-topic.md`). These are the only planning docs checked into the repo — they record the *why* behind key design choices and are useful for contributors.

AI planning artifacts (`*-claude.md`, `*-ultraplan.md`, `*-comparison.md`) are gitignored — keep them local only.

Use GitHub Issues for bug reports, feature requests, and roadmap tracking.
