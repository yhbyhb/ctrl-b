# ctrl-b-helper

A macOS menu bar utility that fixes Ctrl+key shortcuts not working when Korean IME is active.

## The Problem

When macOS Korean IME (e.g. 2-Set Korean) is active, Ctrl+key shortcuts like `Ctrl+B` (tmux prefix) fail silently in terminal emulators. The Korean IME consumes the key event at the `interpretKeyEvents:` layer before the terminal can process it.

## How It Works

ctrl-b-helper runs as a menu bar app and uses a CGEventTap to intercept keyboard events. When it detects a Ctrl+alphabet key press while Korean IME is active, it:

1. Consumes the original event (which carries IME metadata)
2. Creates a clean synthetic CGEvent without IME metadata
3. Posts the synthetic event, which the terminal processes correctly

## Install

```bash
# Build and install to /Applications
make app
make install
```

After launching, grant **Accessibility permission** when prompted:
System Settings > Privacy & Security > Accessibility > Allow ctrl-b-helper

## Usage

The app runs in the menu bar with a **⌃B** icon. Click it to:

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
