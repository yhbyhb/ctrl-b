# Contributing to CtrlB

Thank you for your interest in contributing to CtrlB!

## Getting Started

### Prerequisites

- macOS 13+
- Xcode Command Line Tools or Xcode
- [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)

### Setup

```bash
git clone https://github.com/yhbyhb/CtrlB.git
cd CtrlB
make setup    # configure git hooks
```

### Build & Test

```bash
swift build -c release    # release build
swift test                # run all tests
make lint                 # SwiftLint check (--strict)
make lint-fix             # auto-fix lint issues
```

### Install locally

```bash
make app                  # build .app bundle
make install              # install to /Applications
```

After launching, grant **Accessibility permission** in:
System Settings > Privacy & Security > Accessibility > Allow CtrlB

## Project Structure

- **CtrlBCore** (`Sources/CtrlBCore/`) — Testable pure logic. No Cocoa/CoreGraphics dependencies.
- **CtrlB** (`Sources/CtrlB/`) — App executable. Uses Cocoa, CoreGraphics, Carbon, ServiceManagement.
- **CtrlBTests** (`Tests/CtrlBTests/`) — Unit tests for CtrlBCore.

## Conventions

- Code comments, UI strings, and documentation in **English**
- Korean, Japanese, and Chinese supported via `Localizable.strings`
- Commit messages in **English** using [Conventional Commits](https://www.conventionalcommits.org/)
- Update `README.md` and `CLAUDE.md` in the same PR when changing features

## Submitting Changes

1. Fork the repository
2. Create a feature branch (`feat/your-feature` or `fix/your-fix`)
3. Make your changes with tests where applicable
4. Run `swift test` and `make lint` before committing
5. Open a pull request against `main`

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
