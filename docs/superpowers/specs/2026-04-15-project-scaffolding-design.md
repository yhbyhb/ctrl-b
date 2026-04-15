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

추후: LICENSE, Release Please (섹션 6은 참고용으로 유지하되 이번 구현 범위 밖).
범위 밖: CONTRIBUTING.md (1인 프로젝트), PR 템플릿, branch protection.

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

```sh
#!/bin/sh
# SwiftLint pre-commit hook
# staged된 Swift 파일만 검사

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

working tree 기반으로 lint한다. stash 기반 staged snapshot 검사는 stash pop 실패 시 unstaged 변경분 유실 위험이 있어 사용하지 않는다. partial staging과 working tree가 다른 경우 오탐 가능하나, CI에서 최종 검증하므로 실질적 위험은 낮다. POSIX sh 호환.

### Setup 자동화

Makefile에 `setup` 타겟 추가:

```makefile
## 개발 환경 초기 설정 (git hooks)
setup:
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit
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

      - name: Bundle
        run: make app

      - name: Lint
        run: |
          brew install swiftlint
          swiftlint lint --strict
```

단일 job으로 build → test → bundle → lint 순서. `make app`을 포함하여 .app 번들 패키징도 검증. macOS runner에 Swift가 기본 포함.

## 5. README.md

영문 작성. 포함할 내용:

- **What**: 한 줄 설명 — macOS 한글 IME에서 Ctrl+key 단축키가 동작하지 않는 문제 해결
- **Why**: 문제 설명 (Korean IME consumes Ctrl+key events at interpretKeyEvents layer)
- **Install**: `make app && make install`
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

`simple` 타입 사용 — `version.txt`와 `CHANGELOG.md`만 관리.

### Info.plist 버전 동기화

Release Please는 `version.txt`를 업데이트하지만, 앱의 실제 버전은 `Resources/Info.plist`의 `CFBundleShortVersionString`과 `CFBundleVersion`에 있다. 이 두 값이 어긋나면 릴리스 태그와 앱 버전이 불일치한다.

해결: Release Please의 `extra-files` 설정으로 Info.plist도 함께 업데이트:

```yaml
      - uses: googleapis/release-please-action@v4
        with:
          release-type: simple
          extra-files: |
            Resources/Info.plist
```

Info.plist 내에 Release Please가 인식할 수 있도록 버전 문자열에 `x-release-please-version` 어노테이션을 추가:

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.0</string> <!-- x-release-please-version -->
<key>CFBundleVersion</key>
<string>1</string>
```

`CFBundleShortVersionString`은 semver(예: 1.1.0), `CFBundleVersion`은 빌드 번호로 별도 관리. Release Please는 `CFBundleShortVersionString`만 업데이트한다.

### 초기 파일

프로젝트 루트에 `version.txt` 생성: `1.0.0` (현재 Info.plist의 CFBundleShortVersionString과 일치).

### 동작 흐름

1. main에 `feat:` / `fix:` 커밋 push
2. Release Please가 자동으로 Release PR 생성 (CHANGELOG.md + version.txt + Info.plist 업데이트 포함)
3. Release PR merge 시 GitHub Release + git tag 자동 생성
4. Info.plist의 CFBundleShortVersionString이 새 버전으로 동기화됨
