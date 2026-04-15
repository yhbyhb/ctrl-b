# Project Scaffolding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ctrl-b-helper에 .editorconfig, SwiftLint, pre-commit hook, CI, README를 추가하여 기본 개발 인프라를 구축한다.

**Architecture:** 설정 파일 생성 위주의 작업. 각 Task가 독립적이며 순서대로 진행하면 이전 Task 결과물에 의존하는 구조.

**Tech Stack:** SwiftLint, GitHub Actions, POSIX sh

**Spec:** `docs/superpowers/specs/2026-04-15-project-scaffolding-design.md`

---

## File Map

| 파일 | 상태 | 역할 |
|------|------|------|
| `.editorconfig` | 신규 | 에디터 공통 포맷 설정 |
| `.swiftlint.yml` | 신규 | SwiftLint 규칙 설정 |
| `Makefile` | 수정 | `lint`, `lint-fix`, `setup` 타겟 추가 |
| `.githooks/pre-commit` | 신규 | 커밋 시 SwiftLint 자동 실행 |
| `.github/workflows/ci.yml` | 신규 | PR/push 시 build + test + lint |
| `README.md` | 신규 | 프로젝트 문서화 |

---

### Task 1: .editorconfig 생성

**Files:**
- Create: `.editorconfig`

- [ ] **Step 1: 파일 생성**

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

- [ ] **Step 2: 커밋**

```bash
git add .editorconfig
git commit -m "chore: add .editorconfig for consistent formatting"
```

---

### Task 2: SwiftLint 설정 + Makefile 타겟 추가

**Files:**
- Create: `.swiftlint.yml`
- Modify: `Makefile`

- [ ] **Step 1: `.swiftlint.yml` 생성**

```yaml
# Sources와 Tests만 검사
included:
  - Sources
  - Tests

excluded:
  - .build
  - docs

# 프로젝트 특성에 맞게 비활성화하는 규칙
disabled_rules:
  - trailing_whitespace      # .editorconfig에서 처리
  - line_length              # 긴 로그 문자열 허용

# 경고 → 오류로 승격할 규칙
opt_in_rules:
  - force_unwrapping
```

- [ ] **Step 2: Makefile에 lint, lint-fix, setup 타겟 추가**

기존 Makefile 끝에 추가:

```makefile

## SwiftLint 검사
lint:
	swiftlint lint --strict

## SwiftLint 자동 수정
lint-fix:
	swiftlint lint --fix

## 개발 환경 초기 설정 (git hooks)
setup:
	git config core.hooksPath .githooks
	@echo "✓ Git hooks configured"
```

주의: `lint:`, `lint-fix:`, `setup:` 타겟의 명령줄은 **탭**으로 들여쓰기. `.PHONY` 줄에 `lint lint-fix setup`을 추가한다.

기존 `.PHONY` 줄을 수정:

```makefile
.PHONY: build app install test clean lint lint-fix setup
```

- [ ] **Step 3: SwiftLint가 설치되어 있는지 확인 후 lint 실행**

Run: `which swiftlint && swiftlint lint --strict 2>&1`

SwiftLint가 없으면: `brew install swiftlint` 후 재실행.

Expected: 위반 사항 목록 또는 깨끗한 출력. 위반이 있으면 Step 4에서 수정.

- [ ] **Step 4: lint 위반 사항 수정**

`swiftlint lint --strict`에서 보고된 위반을 수정한다. `swiftlint lint --fix`로 자동 수정 가능한 것은 자동 수정.

수정 후 다시 실행: `swiftlint lint --strict`
Expected: 위반 없음 (exit code 0)

- [ ] **Step 5: 커밋**

```bash
git add .swiftlint.yml Makefile
git commit -m "chore: add SwiftLint config and Makefile targets"
```

lint 위반 수정이 있었다면 해당 파일도 함께 커밋:

```bash
git add .swiftlint.yml Makefile Sources/ Tests/
git commit -m "chore: add SwiftLint config and fix lint violations"
```

---

### Task 3: Git pre-commit hook

**Files:**
- Create: `.githooks/pre-commit`

- [ ] **Step 1: `.githooks/` 디렉토리 생성 및 hook 파일 생성**

```bash
mkdir -p .githooks
```

`.githooks/pre-commit` 파일 생성:

```sh
#!/bin/sh
# SwiftLint pre-commit hook
# staged된 Swift 파일만 검사 (working tree가 아닌 staged snapshot 기준)

SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$')

if [ -z "$SWIFT_FILES" ]; then
    exit 0
fi

if ! command -v swiftlint >/dev/null 2>&1; then
    echo "warning: SwiftLint not installed. Skipping lint."
    exit 0
fi

# unstaged 변경분을 임시 저장하여 staged snapshot만 검사
STASH_NAME="pre-commit-$(date +%s)"
git stash push -q --keep-index -m "$STASH_NAME"

echo "$SWIFT_FILES" | xargs swiftlint lint --strict --quiet
RESULT=$?

# unstaged 변경분 복원
STASH_LIST=$(git stash list | head -1)
case "$STASH_LIST" in
    *"$STASH_NAME"*) git stash pop -q ;;
esac

exit $RESULT
```

- [ ] **Step 2: 실행 권한 부여**

```bash
chmod +x .githooks/pre-commit
```

- [ ] **Step 3: hook 경로 설정 및 동작 확인**

```bash
git config core.hooksPath .githooks
```

테스트: 아무 Swift 파일에 공백 변경 후 커밋 시도:

```bash
echo "" >> Sources/ctrl_b_helper/main.swift
git add Sources/ctrl_b_helper/main.swift
git commit -m "test: hook check"
```

Expected: SwiftLint가 실행되고, 문제가 없으면 커밋 성공. 그 후 테스트 커밋을 되돌림:

```bash
git reset --soft HEAD~1
git checkout Sources/ctrl_b_helper/main.swift
```

- [ ] **Step 4: 커밋**

```bash
git add .githooks/pre-commit
git commit -m "chore: add SwiftLint pre-commit hook with staged snapshot check"
```

---

### Task 4: GitHub Actions CI

**Files:**
- Create: `.github/workflows/ci.yml`

- [ ] **Step 1: 디렉토리 생성 및 워크플로우 파일 생성**

```bash
mkdir -p .github/workflows
```

`.github/workflows/ci.yml` 파일 생성:

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

- [ ] **Step 2: YAML 문법 확인**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" 2>&1 || echo "YAML syntax error"
```

Expected: 에러 없음 (python3에 yaml 모듈이 없으면 `pip3 install pyyaml` 후 재실행, 또는 이 단계 건너뛰기).

- [ ] **Step 3: 커밋**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add GitHub Actions workflow for build, test, bundle, and lint"
```

---

### Task 5: README.md

**Files:**
- Create: `README.md`

- [ ] **Step 1: README.md 생성**

```markdown
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

Or download from the [Releases](../../releases) page.

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
```

- [ ] **Step 2: 커밋**

```bash
git add README.md
git commit -m "docs: add README with install, usage, and development instructions"
```
