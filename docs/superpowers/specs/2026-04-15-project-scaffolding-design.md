# Design: Project Scaffolding

## Goal

ctrl-b-helper 프로젝트에 소프트웨어 공학 기본 인프라를 구축한다. 1인 사이드 프로젝트에 맞게 의식(ceremony)은 최소화하고, 실수를 잡아주는 자동화에 집중한다.

## Scope

구현 순서:

1. `.editorconfig` — 에디터 공통 포맷 설정
2. SwiftLint — 코드 품질 검사 (설정 + Makefile)
3. Git pre-commit hook — 커밋 시 자동 lint
4. GitHub Actions CI — PR/push 시 build + test + lint
5. `README.md` — 프로젝트 문서화
6. Release Please — 릴리스 자동화 (마지막)

범위 밖: LICENSE (추후 결정), CONTRIBUTING.md (1인 프로젝트), PR 템플릿, branch protection.

---

## 1. .editorconfig

프로젝트 루트에 `.editorconfig` 생성.

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

Swift 표준 4-space 들여쓰기. Makefile은 탭 필수. Markdown은 trailing whitespace 유지 (줄바꿈 문법).

## 2. SwiftLint

### 설치 전제

Homebrew로 설치: `brew install swiftlint`. CI에서는 `brew install swiftlint`로 설치.

### 설정: `.swiftlint.yml`

최소 설정 — 기본 규칙을 유지하되 프로젝트에 안 맞는 것만 disable:

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
  - line_length              # 긴 NSLog/로그 문자열 허용

# 경고 → 오류로 승격할 규칙 (CI에서 빌드 실패시킬 항목)
opt_in_rules:
  - force_unwrapping
```

### Makefile 추가

기존 Makefile에 `lint` 타겟 추가:

```makefile
## SwiftLint 검사
lint:
	swiftlint lint --strict

## SwiftLint 자동 수정
lint-fix:
	swiftlint lint --fix
```

`--strict`는 경고도 에러로 처리하여 CI에서 0이 아닌 exit code를 반환.

## 3. Git pre-commit hook

### Hook 파일: `.githooks/pre-commit`

```bash
#!/bin/sh
# SwiftLint pre-commit hook
# 변경된 Swift 파일만 검사

SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$')

if [ -z "$SWIFT_FILES" ]; then
    exit 0
fi

if ! command -v swiftlint &> /dev/null; then
    echo "warning: SwiftLint not installed. Skipping lint."
    exit 0
fi

echo "$SWIFT_FILES" | xargs swiftlint lint --strict --quiet
```

변경된 Swift 파일만 검사하므로 빠르다. SwiftLint 미설치 시 경고만 출력하고 커밋 허용 (CI에서 최종 검증).

### Setup 자동화

Makefile에 `setup` 타겟 추가:

```makefile
## 개발 환경 초기 설정 (git hooks)
setup:
	git config core.hooksPath .githooks
	@echo "✓ Git hooks configured"
```

## 4. GitHub Actions CI

### 워크플로우: `.github/workflows/ci.yml`

PR과 main push 시 실행:

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

      - name: Lint
        run: |
          brew install swiftlint
          swiftlint lint --strict
```

단일 job으로 build → test → lint 순서. macOS runner에 Swift가 기본 포함.

## 5. README.md

영문 작성. 포함할 내용:

- **What**: 한 줄 설명 — macOS 한글 IME에서 Ctrl+key 단축키가 동작하지 않는 문제 해결
- **Why**: 문제 설명 (Korean IME consumes Ctrl+key events at interpretKeyEvents layer)
- **Install**: `make app && make install` 또는 Releases 페이지
- **Usage**: 접근성 권한 설정 안내, 메뉴바 아이콘 설명
- **Build**: `swift build`, `swift test`, `make lint`
- **Development Setup**: `make setup` (git hooks)

## 6. Release Please (마지막)

### 워크플로우: `.github/workflows/release-please.yml`

```yaml
name: Release Please

on:
  push:
    branches: [main]

permissions:
  contents: write
  pull-requests: write

jobs:
  release-please:
    runs-on: ubuntu-latest
    steps:
      - uses: googleapis/release-please-action@v4
        with:
          release-type: simple
```

`simple` 타입 사용 — `version.txt`와 `CHANGELOG.md`만 관리. Swift 프로젝트에 불필요한 package manager 연동 없음.

### 초기 파일

프로젝트 루트에 `version.txt` 생성: `1.0.0` (현재 Info.plist 버전과 일치).

### 동작 흐름

1. main에 `feat:` / `fix:` 커밋 push
2. Release Please가 자동으로 Release PR 생성 (CHANGELOG.md 업데이트 포함)
3. Release PR merge 시 GitHub Release + git tag 자동 생성
