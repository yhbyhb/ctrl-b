# ctrl-b

[![CI](https://github.com/yhbyhb/ctrl-b/actions/workflows/ci.yml/badge.svg)](https://github.com/yhbyhb/ctrl-b/actions/workflows/ci.yml)

한글 IME 사용 중 터미널에서 Ctrl+키 단축키가 동작하지 않는 문제를 해결하는 macOS 메뉴바 유틸리티입니다.

> tmux에서 `Ctrl+b`가 한글 입력기 때문에 먹히지 않아서 불편하셨나요? ctrl-b가 해결해 드립니다.

[English](README.md) | [中文](README.zh.md)

## 문제

macOS에서 한글/중문/일문 등 CJK IME(입력기)가 활성화된 상태로 터미널을 사용하면, `Ctrl+b`(tmux 프리픽스) 같은 Ctrl+알파벳 단축키가 조용히 무시됩니다. IME가 `interpretKeyEvents:` 레이어에서 키 이벤트를 가로채기 때문에 터미널이 해당 이벤트를 받지 못합니다.

## 작동 원리

ctrl-b는 메뉴바 앱으로 실행되며, CGEventTap을 이용해 키보드 이벤트를 가로챕니다. IME가 활성화된 상태에서 Ctrl+알파벳 키 입력이 감지되면:

1. 원본 이벤트(IME 메타데이터 포함)를 소비합니다.
2. IME 메타데이터가 없는 깨끗한 CGEvent를 새로 만듭니다.
3. 새 이벤트를 전송하면 터미널이 정상적으로 처리합니다.

**프리픽스 후속 키 지원**: `Ctrl+b`(tmux 프리픽스)가 리매핑된 후, 1.5초 이내에 입력되는 다음 키도 함께 리매핑합니다. 덕분에 `Ctrl+b` → `n`(새 창) 같은 조합도 끊김 없이 동작합니다.

## 지원하는 입력기

`TISTypeKeyboardInputMode`로 등록된 모든 macOS 입력기를 지원합니다. 언어를 별도로 판별하지 않아 모든 CJK 입력기와 호환됩니다:

- **한국어**: 두벌식, 세벌식
- **중국어**: 병음(간체), 주음/보포모포(번체), 창힐, 오필 등
- **일본어**: 히라가나, 가타카나
- **베트남어**: Telex, VNI 등
- **기타**: IME 모드 기반의 모든 macOS 입력 소스

ABC, AZERTY, QWERTY 같은 일반 키보드 레이아웃에는 영향을 주지 않습니다. IME가 활성화된 경우에만 동작합니다.

## 스크린샷

<p align="center">
  <img src="docs/screenshots/menu.png" width="300" alt="ctrl-b 메뉴" />
  &nbsp;&nbsp;&nbsp;
  <img src="docs/screenshots/about.png" width="300" alt="ctrl-b 정보 패널" />
</p>

## 설치

### 다운로드 (권장)

1. [최신 릴리스](https://github.com/yhbyhb/ctrl-b/releases/latest)에서 `ctrl-b.app.zip`을 다운로드합니다.
2. 압축을 풀고 `ctrl-b.app`을 `/Applications`로 이동합니다.
3. ctrl-b를 실행합니다.

> **참고:** 현재 배포된 바이너리는 서명이 없어 첫 실행 시 macOS가 차단할 수 있습니다.
> 실행 방법: **우클릭 → 열기**, 또는 터미널에서 아래 명령어를 실행하세요:
> ```bash
> xattr -cr ctrl-b.app && open ctrl-b.app
> ```

### 소스에서 빌드

```bash
git clone https://github.com/yhbyhb/ctrl-b.git
cd ctrl-b
make app
make install
```

### 시스템 요구사항

- macOS 13 (Ventura) 이상

## 초기 설정

실행 후 **손쉬운 사용(Accessibility) 권한**을 허용합니다:

**시스템 설정 → 개인 정보 보호 및 보안 → 손쉬운 사용 → ctrl-b → 켜기**

권한이 허용되면 ctrl-b가 자동으로 시작됩니다. 재시작이 필요 없습니다.

### 왜 손쉬운 사용 권한이 필요한가요?

ctrl-b는 CGEventTap을 사용해 시스템 레벨에서 키보드 이벤트를 가로채고 교체합니다. 이벤트를 소비하면서 IME 메타데이터가 없는 깨끗한 이벤트를 새로 전송하려면 이 API가 유일한 수단이며, 손쉬운 사용 권한이 필요합니다.

## 사용법

메뉴바의 **⌃b** 아이콘을 클릭하면:

- 리매핑 켜기/끄기 토글
- 리매핑 통계 확인 (오늘 / 누적)
- 통계 초기화
- 로그인 시 자동 시작 토글
- 업데이트 확인
- 정보 패널 열기 (버전, 현재 입력기, 보안 키보드 입력 상태, 링크)

## 개발

```bash
swift build -c release   # 빌드
swift test               # 테스트 실행
make lint                # SwiftLint (--strict)
make lint-fix            # lint 문제 자동 수정
make setup               # git hook 설정 (클론 후 최초 1회)
```

**개발 환경:** Xcode Command Line Tools, [SwiftLint](https://github.com/realm/SwiftLint) (`brew install swiftlint`)

기여 방법은 [CONTRIBUTING.md](CONTRIBUTING.md)를 참고하세요.

## 후원

ctrl-b는 무료이며 여가 시간에 개발하고 있습니다. 도움이 되셨다면 후원으로 유지보수를 응원해 주세요: [GitHub Sponsors](https://github.com/sponsors/yhbyhb) · [Ko-fi](https://ko-fi.com/yhbyhb)

## 라이선스

MIT — [LICENSE](LICENSE) 참고
