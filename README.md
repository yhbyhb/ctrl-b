# ctrl-b

A macOS menu bar utility that fixes Ctrl+key shortcuts not working when a CJK input method (IME) is active.

> Tired of `Ctrl+b` doing nothing in tmux because Korean/Chinese/Japanese IME is on? ctrl-b fixes that.

## The Problem

When a macOS IME (e.g. Korean 2-Set, Chinese Pinyin, Japanese Hiragana) is active, Ctrl+key shortcuts like `Ctrl+b` (tmux prefix) fail silently in terminal emulators. The IME consumes the key event at the `interpretKeyEvents:` layer before the terminal can process it.

## How It Works

ctrl-b runs as a menu bar app and uses a CGEventTap to intercept keyboard events. When it detects a Ctrl+alphabet key press while an IME is active, it:

1. Consumes the original event (which carries IME metadata)
2. Creates a clean synthetic CGEvent without IME metadata
3. Posts the synthetic event, which the terminal processes correctly

**Prefix follow-up**: When `Ctrl+b` (tmux prefix) is remapped, ctrl-b also remaps the next key pressed within 1.5 seconds — so `Ctrl+b` → `c` (new window) works seamlessly too.

## Install

### Download (recommended)

1. Download `ctrl-b.app.zip` from the [latest release](https://github.com/yhbyhb/ctrl-b/releases/latest)
2. Unzip and move `ctrl-b.app` to `/Applications`
3. Launch ctrl-b

> **Note:** The release binary is currently unsigned. macOS will block it on first launch.
> To open it: **right-click → Open**, or run:
> ```bash
> xattr -cr ctrl-b.app && open ctrl-b.app
> ```

### Build from source

```bash
git clone https://github.com/yhbyhb/ctrl-b.git
cd ctrl-b
make app
make install
```

### Requirements

- macOS 13 (Ventura) or later

## Setup

After launching, grant **Accessibility permission** when prompted:

**System Settings → Privacy & Security → Accessibility → ctrl-b → toggle on**

ctrl-b detects when permission is granted and starts automatically — no restart required.

### Why Accessibility permission?

ctrl-b uses a CGEventTap to intercept and replace keyboard events at the system level. This is the only mechanism on macOS that can consume an event and post a clean synthetic one in its place — which is exactly what's needed to strip IME metadata from Ctrl+key events. Accessibility permission is required for this API.

## Usage

The app runs in the menu bar with a **⌃b** icon. Click it to:

- Toggle remapping on/off
- View remap statistics (today / cumulative)
- Reset statistics
- Toggle launch at login
- Open the About panel (version, current IME, links)

## Development

```bash
swift build -c release   # Build
swift test               # Run tests
make lint                # SwiftLint (--strict)
make lint-fix            # Auto-fix lint issues
make setup               # Set up git hooks (run once after cloning)
```

**Dev requirements:** Xcode Command Line Tools, [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

MIT — see [LICENSE](LICENSE)
