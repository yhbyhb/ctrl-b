# 플랜: "About ctrl-b" 메뉴 항목 + 커스텀 Apple 표준 About 패널 추가

## 배경 (Context)

현재 ctrl-b에는 사용자가 앱 버전·제작자·저장소 링크를 확인할 방법이 없습니다. v1.0.0 출시를 앞두고 오픈소스화가 진행되면서 "About" 진입점이 필요합니다. 이 플랜은 상태바 드롭다운 메뉴에 해당 항목을 추가합니다. Apple 표준 `orderFrontStandardAboutPanel`을 사용하며 (Rectangle/Maccy 방식 — 커스텀 NSWindow 없음), Credits 영역은 ctrl-b의 정체성을 반영하도록 구성합니다: 앱이 하는 일을 시각적으로 보여주는 정적 키캡 라인 (옵션 **E**) + 현재 감지된 IME를 실시간 표시하는 라인 (옵션 **D**) + 누적 통계 + 표준 링크.

업계 관례 (`Maccy/About.swift` 실물로 확인) 를 따릅니다:
- 메뉴 항목 제목은 **로컬라이즈**합니다 (en/ko/ja/zh-Hans). 사용자의 모국어 상태바 메뉴 안에 표시되기 때문입니다.
- Credits 본문은 **영어 전용**입니다 — Maccy·Rectangle·PCalc·Bartender 대안들이 모두 동일. 4개 언어 앱에 언어별 RTF 유지 비용은 비효율적입니다.
- Copyright는 `Info.plist`의 `NSHumanReadableCopyright` 사용 (영어 단일 문자열).
- 버전·빌드 번호는 OS가 `CFBundleShortVersionString` / `CFBundleVersion`으로 자동 렌더링 (작업 불필요).

## 최종 Credits 레이아웃 (영어 전용)

```
⌃B  under  한 / 中 / あ   →   ⌃B

Currently: 🇰🇷 Korean

Remapped 1,234 times · Saved ~2 minutes

GitHub  ·  Report an issue  ·  MIT License
```

- **1행** (정적): ctrl-b가 하는 일의 모노스페이스 "키캡" 시연. 가운데 정렬.
- **2행** (동적, 패널 열 때 갱신): `TISCopyCurrentKeyboardInputSource`에서 읽어온 `"Currently: <국기> <로컬라이즈된 입력소스명>"`. 비-IME 소스(ABC, US 등)가 활성화되어 있으면 `"Currently: 🇺🇸 ABC — idle"`로 표시해 앱이 "할 일이 없음을 인식하고 있다"는 점을 보여줌.
- **3행** (동적): `StatisticsManager.remapCount` 및 `timeSavedSeconds`에서 읽은 누적 통계, 영어 포맷 ("1,234 times", "~2 minutes"). 메뉴의 통계 라인(`time.seconds/minutes/hours` 로컬라이즈 사용)과 달리 Credits 관례에 따라 영어 유지.
- **4행** (하이퍼링크): 중점으로 구분된 3개 링크, 가운데 정렬. 링크 대상: 저장소, Issues 페이지, `https://opensource.org/licenses/MIT`.

## 메뉴 배치

"Launch at Login" 구분선과 "Quit" 사이에 삽입 — Quit과 같은 구분선 아래에 묶어 표준 macOS 패턴을 따름.

```
…
✓ Launch at Login
─────────────
About ctrl-b       ← 신규
Quit
```

별도 구분선은 추가하지 않음: About과 Quit는 "앱 수준" 액션으로 함께 그룹핑.

## 생성·수정 파일

### 신규 생성

- **`Sources/CtrlBCore/InputSourceDisplay.swift`** (신규, 순수 로직, 테스트 가능)
  - `struct InputSourceDisplay { let flag: String; let name: String; let isIME: Bool }`
  - `func inputSourceDisplay(languageTag: String?, localizedName: String?, typeIsIME: Bool) -> InputSourceDisplay`
  - 주 언어 태그 → 국기 이모지 매핑: `ko → 🇰🇷`, `ja → 🇯🇵`, `zh-Hans → 🇨🇳`, `zh-Hant → 🇹🇼`, `en → 🇺🇸` (폴백 🌐).
  - 두 입력 모두 nil이면 "Unknown"으로 폴백. `localizedName`이 있으면 그대로 사용 (예: "2벌식", "Hiragana").

- **`Sources/CtrlB/AboutPanelController.swift`** (신규)
  - `final class AboutPanelController`, `init(stats: StatisticsManager, currentInputSource: @escaping () -> InputSourceDisplay)`.
  - `NSMutableAttributedString`을 조립 (`Maccy/About.swift` 패턴 차용): 가운데 정렬, 크롬(chrome)은 secondary label 색상, 통계·IME 라인은 label 색상, GitHub/Issues/MIT에 `.link` 속성.
  - 키캡 시연 라인만 모노스페이스 시스템 폰트 사용, 나머지는 `NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)`.
  - `@objc func show(_ sender: Any?)`:
    1. `NSApp.activate(ignoringOtherApps: true)` — LSUIElement 에이전트 앱에서 패널을 전면으로 끌어올리기 위해 필수.
    2. `NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])`.
  - `StatusBarController`에는 `#selector(AboutPanelController.show(_:))`로 노출 — target은 `StatusBarController`가 아닌 controller 인스턴스.

- **`Tests/CtrlBTests/InputSourceDisplayTests.swift`** (신규)
  - 4개 케이스: 한국어 IME, 일본어 IME, 간체 중국어 IME, 영어 비-IME. 그리고 nil 입력 폴백.

### 수정

- **`Sources/CtrlB/InputSourceUtils.swift`**
  - `func currentInputSourceDisplay() -> InputSourceDisplay` 추가. 기존에 이미 사용 중인 `TISCopyCurrentKeyboardInputSource`에서 `kTISPropertyInputSourceLanguages[0]`, `kTISPropertyLocalizedName`, `kTISPropertyInputSourceType`를 꺼내 CtrlBCore의 순수 로직 함수에 위임. `typeIsIME` 판단에는 CtrlBCore의 기존 `isInputMethod(_:)` 재사용.

- **`Sources/CtrlB/StatusBarController.swift`**
  - 저장 프로퍼티 `private let aboutPanel: AboutPanelController` 추가.
  - `init(eventTap:stats:)`에 `AboutPanelController` 생성 로직 포함. 간단한 구성: 주입받은 `stats`와 `currentInputSourceDisplay()`를 호출하는 클로저로 `init` 내에서 인라인 생성.
  - `buildMenu(_:)`에서 `quit` 항목 바로 위에 한 줄 추가:
    ```swift
    let aboutItem = NSMenuItem(title: localized("menu.about"),
                               action: #selector(AboutPanelController.show(_:)),
                               keyEquivalent: "")
    aboutItem.target = aboutPanel
    menu.addItem(aboutItem)
    ```
    (기존 `action(_:_:)` 헬퍼는 재사용 불가 — 그 헬퍼는 `self`를 타겟으로 지정하는데 About은 `AboutPanelController` 인스턴스를 타겟으로 해야 함.)

- **`Sources/CtrlB/main.swift`** (또는 `StatusBarController`가 생성되는 곳) — `StatusBarController.init` 내부에서 `AboutPanelController`를 직접 생성하므로 외부 변경 불필요. 구현 중 재확인.

- **`Sources/CtrlB/Resources/en.lproj/Localizable.strings`**
  - 추가: `"menu.about" = "About ctrl-b";`

- **`Sources/CtrlB/Resources/ko.lproj/Localizable.strings`**
  - 추가: `"menu.about" = "ctrl-b 정보";`

- **`Sources/CtrlB/Resources/ja.lproj/Localizable.strings`**
  - 추가: `"menu.about" = "ctrl-b について";`

- **`Sources/CtrlB/Resources/zh-Hans.lproj/Localizable.strings`**
  - 추가: `"menu.about" = "关于 ctrl-b";`

- **`Resources/Info.plist`**
  - 추가: `<key>NSHumanReadableCopyright</key><string>© 2026 HanByul Yang. MIT License.</string>`
  - Makefile의 `make app` 단계가 이 파일을 복사함을 확인 완료 — Makefile 변경 불필요.

## 재사용할 기존 코드

- `InputSourceUtils.isInputMethodActive()` 패턴 — 신규 `currentInputSourceDisplay()`는 10–17, 21–42행에서 이미 쓰는 `TISCopyCurrentKeyboardInputSource` → `Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue()` 관용구를 그대로 따름.
- `CtrlBCore.isInputMethod(_:)` — 매핑 함수의 `typeIsIME` bool 세팅에 그대로 재사용.
- `StatisticsManager.remapCount` / `.timeSavedSeconds` — `StatusBarController`가 이미 사용 중. 새 접근자 불필요.
- `Bundle.module` 로컬라이제이션 조회 — `StatusBarController.swift:41`의 패턴 사용.
- `NSAttributedString` 하이퍼링크 패턴 — `Maccy/About.swift` (MIT 라이선스 레퍼런스) 방식 차용: `NSMutableAttributedString` + `addAttribute(.link, value:, range:)`.

## 검증 (Verification)

엔드투엔드 수동 테스트:

1. `make lint` — 통과 필수 (SwiftLint `force_unwrapping` 옵트인, `!` 사용 금지).
2. `swift test --filter InputSourceDisplayTests` — 로캘→국기 매핑 유닛 테스트.
3. `swift test` — 전체 스위트 통과.
4. `swift build -c release && make app` — `ctrl-b.app` 생성.
5. `ctrl-b.app` 실행 → 메뉴바 `⌃b` 아이콘 클릭 → "About ctrl-b"가 "Quit" 바로 위에 표시되는지 확인.
6. "About ctrl-b" 클릭:
   - Apple 표준 패널이 **다른 창보다 전면**에 뜸 (`NSApp.activate` 검증).
   - 앱 아이콘, "ctrl-b", "Version 1.0.0 (1)" 표시.
   - Credits 영역이 설계대로 4개 라인을 가운데 정렬로 렌더링.
   - ⌃Space로 입력 소스를 한국어로 변경 → 패널 닫고 다시 열기 → "Currently:" 라인이 `🇰🇷 한국어`(또는 macOS가 반환하는 localized name)로 갱신.
   - 일본어·간체 중국어 IME 반복.
   - ABC/US 키보드 선택 시 → `🇺🇸 ABC — idle` (또는 동등 표현) 표시.
   - "GitHub", "Report an issue", "MIT License" 클릭 시 기본 브라우저 열림.
   - 하단에 "© 2026 HanByul Yang. MIT License." 저작권 표시.
7. macOS UI 언어 변경 (Settings → Language & Region → ko/ja/zh-Hans) 후 재실행 → 메뉴 항목 제목이 각 언어("ctrl-b 정보" / "ctrl-b について" / "关于 ctrl-b")로 로컬라이즈되고, 패널 Credits 본문은 영어 유지됨을 확인.

## 범위 외 (Out of scope)

- 저장소 루트에 `LICENSE` 파일 생성 — MEMORY에 별도 예정으로 기록됨 ("next: LICENSE + Release Please"). Credits의 "MIT License" 링크는 임시로 `https://opensource.org/licenses/MIT`를 가리키고, LICENSE가 추가되면 후속 PR에서 저장소 자체 `LICENSE` URL로 교체.
- 버전 번호 클릭 이스터에그 (옵션 G / 트로피).
- 커스텀 NSPanel 기반 About (Maccy 2.x 스타일) — 표준 패널로 이미 모든 요구사항을 충족하므로 불필요.
- Credits 본문·`NSHumanReadableCopyright`의 로컬라이제이션 — 업계 관례에 따라 의도적 미적용.
