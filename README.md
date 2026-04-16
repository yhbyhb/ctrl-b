# CtrlB

A macOS menu bar utility that fixes Ctrl+key shortcuts not working when an input method (IME) is active.

## The Problem

When a macOS IME (e.g. Korean 2-Set, Chinese Pinyin, Japanese Hiragana) is active, Ctrl+key shortcuts like `Ctrl+b` (tmux prefix) fail silently in terminal emulators. The IME consumes the key event at the `interpretKeyEvents:` layer before the terminal can process it.

## How It Works

CtrlB runs as a menu bar app and uses a CGEventTap to intercept keyboard events. When it detects a Ctrl+alphabet key press while an IME is active, it:

1. Consumes the original event (which carries IME metadata)
2. Creates a clean synthetic CGEvent without IME metadata
3. Posts the synthetic event, which the terminal processes correctly

### Prefix Follow-Up

For tmux users: when CtrlB remaps `Ctrl+b` (the tmux prefix key), it also remaps the next key press within 1.5 seconds. This allows commands like `Ctrl+b` → `c` (new window) to work seamlessly with an IME active.

## Install

```bash
# Build and install to /Applications
make app
make install
```

After launching, grant **Accessibility permission** when prompted:
System Settings > Privacy & Security > Accessibility > Allow CtrlB

CtrlB detects when permission is granted and starts working automatically — no restart required.

## Usage

The app runs in the menu bar with a **⌃b** icon. Click it to:

- Toggle remapping on/off
- View remap statistics (today / total)
- Reset statistics
- Toggle launch at login

## Development

```bash
# Build
swift build -c release

# Run tests
swift test

# Lint
make lint

# Auto-fix lint issues
make lint-fix

# Set up git hooks (run once after cloning)
make setup
```

### Requirements

- macOS 13+
- Xcode Command Line Tools or Xcode
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)
