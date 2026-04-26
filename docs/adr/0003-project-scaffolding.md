# Design: Project Scaffolding

## Goal

Establish software engineering infrastructure for the ctrl-b project. Minimize ceremony appropriate for a solo side project; focus on automation that catches mistakes.

## Scope

Implementation order:

1. `.editorconfig` — shared editor formatting settings
2. SwiftLint — code quality checks (config + Makefile)
3. Git pre-commit hook — automatic lint on commit
4. GitHub Actions CI — build + test + lint on PR/push
5. `README.md` — project documentation

Deferred: LICENSE, Release Please (Section 6 is kept as a reference but is out of scope for this implementation).
Out of scope: CONTRIBUTING.md (solo project), PR templates, branch protection.

---

## 1. .editorconfig

Create `.editorconfig` at the project root.

```ini
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[Makefile]
indent_style = tab

[*.md]
trim_trailing_whitespace = false
```

Swift standard 4-space indentation. Makefiles require tabs. Markdown preserves trailing whitespace (line-break syntax).

## 2. SwiftLint

### Prerequisites

Install via Homebrew: `brew install swiftlint`. CI installs it the same way.

### Config: `.swiftlint.yml`

Minimal config — keep default rules; disable only what doesn't fit the project:

```yaml
# Lint only Sources and Tests
included:
  - Sources
  - Tests

excluded:
  - .build
  - docs

# Rules disabled for project-specific reasons
disabled_rules:
  - trailing_whitespace      # handled by .editorconfig
  - line_length              # allow long NSLog/log strings

# Rules promoted from warning to error (cause CI failure)
opt_in_rules:
  - force_unwrapping
```

### Makefile targets

```makefile
## Run SwiftLint
lint:
	swiftlint lint --strict

## Auto-fix SwiftLint violations
lint-fix:
	swiftlint lint --fix
```

`--strict` treats warnings as errors, returning a non-zero exit code in CI.

## 3. Git pre-commit hook

### Hook file: `.githooks/pre-commit`

```sh
#!/bin/sh
# SwiftLint pre-commit hook
# Only checks staged Swift files

SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$')

if [ -z "$SWIFT_FILES" ]; then
    exit 0
fi

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "warning: SwiftLint not installed. Skipping lint."
    exit 0
fi

echo "$SWIFT_FILES" | xargs swiftlint lint --strict --quiet
```

Lints against the working tree rather than a staged snapshot. The stash-based approach (staged-only snapshot) risks losing unstaged changes if `git stash pop` fails. When partial staging causes the working tree to differ from the staged state, false positives are possible — but CI provides the final verification, so the practical risk is low. POSIX sh compatible.

### Setup automation

Add a `setup` target to the Makefile:

```makefile
## Initial dev environment setup (git hooks)
setup:
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit
	@echo "✓ Git hooks configured"
```

## 4. GitHub Actions CI

### Workflow: `.github/workflows/ci.yml`

Runs on PR and push to main:

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: swift build -c release

      - name: Test
        run: swift test

      - name: Bundle
        run: make app

      - name: Lint
        run: |
          brew install swiftlint
          swiftlint lint --strict
```

Single job: build → test → bundle → lint. Including `make app` verifies the `.app` bundle packaging step. Swift is pre-installed on macOS runners.

## 5. README.md

Written in English. Content:

- **What**: One-line description — fixes Ctrl+key shortcuts that fail in terminals when macOS CJK IME is active
- **Why**: Problem explanation (Korean/Chinese/Japanese IME consumes Ctrl+key events at the interpretKeyEvents layer)
- **Install**: `make app && make install`
- **Usage**: Accessibility permission setup, menu bar icon description
- **Build**: `swift build`, `swift test`, `make lint`
- **Development Setup**: `make setup` (git hooks)

## 6. Release Please (deferred — out of scope)

Notes for future implementation:

- Use `googleapis/release-please-action@v4`
- v4 advanced config (`extra-files`, etc.) must be set via `release-please-config.json` / `.release-please-manifest.json`, not workflow inputs
- Required permissions: `contents: write`, `pull-requests: write`, `issues: write`
- Need a strategy to keep `CFBundleShortVersionString` in Info.plist in sync with `version.txt`
- Rewrite detailed design from official docs at implementation time: https://github.com/googleapis/release-please-action
