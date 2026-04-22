# 계획: "ctrl-b 정보" 메뉴 항목과 Apple 표준 About 패널 추가

## 배경

ctrl-b에는 앱의 버전, 제작자, 저장소 링크를 확인할 수 있는 경로가 없다. v1.0.0 출시와 오픈소스 공개를 앞두고, 상태 표시줄 메뉴에 발견하기 쉬운 "About" 항목이 필요하다. Rectangle/Maccy가 사용하는 방식과 동일하게 Apple 표준 `orderFrontStandardAboutPanel(options:)`을 그대로 활용하되 (별도 NSWindow 없음), Credits 영역에 ctrl-b의 정체성을 담는다: 앱 동작을 시각적으로 보여주는 정적 라인 한 줄, 현재 감지된 IME를 보여주는 라이브 라인 한 줄, 누적 통계, 표준 링크.

따르는 업계 관례:
- **메뉴 항목 제목은 현지화** (en/ko/ja/zh-Hans) — 사용자의 모국어 메뉴에 노출되기 때문.
- **Credits 본문은 영어 고정** — Maccy, Rectangle, PCalc 모두 동일. 4개 언어용 RTF 유지비용 대비 이득이 없음.
- 저작권 문자열은 `Info.plist`의 `NSHumanReadableCopyright` 한 줄 (영어).
- 버전/빌드 문자열은 OS가 `CFBundleShortVersionString` / `CFBundleVersion`에서 자동 렌더링 — 별도 작업 불필요.

## 변경 구조

```
+----------------------------------------------------------------------+
|  CtrlBCore (pure, testable)                                          |
|  +--------------------------------------------------------------+    |
|  | InputSourceDetector.swift  [existing]                        |    |
|  |   + isInputMethod(_:)                                        |    |
|  |                                                              |    |
|  | InputSourceDisplay.swift   [NEW]                             |    |
|  |   + struct InputSourceDisplay { flag, name, isIME }          |    |
|  |   + inputSourceDisplay(languageTag:localizedName:typeIsIME:) |    |
|  +-------------------------+------------------------------------+    |
+----------------------------|-----------------------------------------+
                             | pure function call
+----------------------------|-----------------------------------------+
|  CtrlB (app)               v                                         |
|  +--------------------------------------------------------------+    |
|  | InputSourceUtils.swift     [MODIFIED]                        |    |
|  |   + currentInputSourceDisplay() -> InputSourceDisplay        |    |
|  |     (reads TIS props, delegates to pure fn above)            |    |
|  +-------------------------+------------------------------------+    |
|                            | closure capture                         |
|  +-------------------------v------------------------------------+    |
|  | AboutPanelController.swift [NEW]                             |    |
|  |   init(stats, currentInputSource: () -> InputSourceDisplay)  |    |
|  |   @objc show()  ->  NSApp.activate + orderFrontStandardAbout |    |
|  +-------------------------^------------------------------------+    |
|                            | owned by                                |
|  +-------------------------+------------------------------------+    |
|  | StatusBarController.swift  [MODIFIED]                        |    |
|  |   - menu build logic unchanged; add one "About" item         |    |
|  |   - @objc showAbout() -> aboutPanel.show()                   |    |
|  +--------------------------------------------------------------+    |
+----------------------------------------------------------------------+
```

`AppDelegate`, `main.swift`, `EventTapManager`는 변경 없음. `StatusBarController(eventTap:stats:)` 시그니처 유지 → 기존 테스트 수정 없이 통과.

## 최종 Credits 레이아웃 (영어 고정)

```
⌃b  under  한 / 中 / あ   →   ⌃b

Currently: 🇰🇷 Korean

Remapped 1,234 times · Saved ~2 minutes

GitHub  ·  Report an issue  ·  MIT License
```

- **1행** (정적): monospace 폰트로 앱이 하는 일을 시각화한 "키캡" 데모, 가운데 정렬.
- **2행** (패널 열 때마다 재구성): `"Currently: <국기> <localizedName>"`. 비-IME 입력 소스일 때는 `"Currently: 🇺🇸 ABC — idle"`로 바뀌어, 앱이 자기가 할 일이 없음을 인식하고 있다는 점을 사용자에게 알림.
- **3행**: `StatisticsManager.remapCount`, `.timeSavedSeconds` 기반의 누적 통계. 영어로 포맷 (`NumberFormatter.localizedString(from:number:)` + `Locale(identifier: "en_US")`로 `"1,234 times"`, `timeSavedSeconds` 버킷으로 `"~N seconds"` / `"~N minutes"` / `"~N hours"`).
- **4행** (하이퍼링크, 가운데 정렬, 가운뎃점 구분자):
  - GitHub → `https://github.com/yhbyhb/ctrl-b`
  - Report an issue → `https://github.com/yhbyhb/ctrl-b/issues`
  - MIT License → `https://github.com/yhbyhb/ctrl-b/blob/main/LICENSE` (저장소 루트에 LICENSE 이미 존재)

Credits 영역은 하나의 `NSMutableAttributedString`으로 조립:
- 전체 가운데 정렬 paragraph style.
- 1~3행은 label color, 구분 가운뎃점은 secondary label color, 각 하이퍼링크 구간에 `.link` 속성.
- 1행만 `NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)`, 나머지는 `NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)`.

## 메뉴 배치

로그인 시 자동 실행 항목 뒤의 기존 구분선(`StatusBarController.swift:69`)과 종료(Quit) 사이에 삽입. About과 Quit가 같은 구분선 아래에 "앱 레벨" 동작으로 묶이는 표준 macOS 패턴.

```
...
[ Launch at Login ]
-------------------
[ About ctrl-b   ]   <- NEW
[ Quit           ]
```

(UI 언어에 따라 실제 표시는 `ctrl-b 정보` / `ctrl-b について` / `关于 ctrl-b` 등으로 현지화됨.)

새 구분선은 추가하지 않음.

## 신규 파일

### `Sources/CtrlBCore/InputSourceDisplay.swift` (신규, 순수 로직)

```swift
public struct InputSourceDisplay: Equatable {
    public let flag: String
    public let name: String
    public let isIME: Bool
    public init(flag: String, name: String, isIME: Bool) { ... }
}

/// TIS primary language tag + localized name을 표시용 필드로 매핑한다.
/// - languageTag: kTISPropertyInputSourceLanguages의 첫 요소 (예: "ko", "ja", "zh-Hans")
/// - localizedName: kTISPropertyLocalizedName (예: "2벌식", "Hiragana")
/// - typeIsIME: isInputMethod(kTISPropertyInputSourceType) 결과
public func inputSourceDisplay(
    languageTag: String?,
    localizedName: String?,
    typeIsIME: Bool
) -> InputSourceDisplay
```

태그 → 국기 매핑 (`zh-Hans-CN` 같은 값도 걸리도록 prefix match):
- `ko*` → 🇰🇷
- `ja*` → 🇯🇵
- `zh-Hant*` → 🇹🇼  (`zh*`보다 먼저 검사)
- `zh*` → 🇨🇳
- `en*` → 🇺🇸
- 그 외 → 🌐

이름 폴백: `localizedName`이 있으면 그대로 사용, 없으면 `"Unknown"`.

### `Sources/CtrlB/AboutPanelController.swift` (신규)

```swift
final class AboutPanelController: NSObject {
    private let stats: StatisticsManager
    private let currentInputSource: () -> InputSourceDisplay

    init(stats: StatisticsManager,
         currentInputSource: @escaping () -> InputSourceDisplay) { ... }

    @objc func show(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)  // LSUIElement=true라 Dock이 없으므로 필수
        NSApp.orderFrontStandardAboutPanel(options: [.credits: buildCredits()])
    }

    private func buildCredits() -> NSAttributedString { ... }
}
```

`buildCredits()`는 Maccy의 `About.swift`와 같은 패턴(`NSMutableAttributedString + addAttribute(.link, value:, range:)`)으로 4개 행을 조립.

### `Tests/CtrlBTests/InputSourceDisplayTests.swift` (신규)

순수 매핑 함수 검증:
- `"ko"` + "2벌식" + IME → 🇰🇷, "2벌식", isIME true
- `"ja"` + "Hiragana" + IME → 🇯🇵
- `"zh-Hans"` + "拼音" + IME → 🇨🇳
- `"zh-Hant"` + "注音" + IME → 🇹🇼
- `"en"` + "ABC" + non-IME → 🇺🇸, isIME false
- `nil` + `nil` + false → 🌐 + "Unknown" + isIME false
- 알 수 없는 태그(`"fr"`) → 🌐 폴백, localized name은 그대로 보존

## 수정 파일

### `Sources/CtrlB/InputSourceUtils.swift`

함수 하나 추가. 이미 파일 내 10–17번, 21–42번 줄에서 사용 중인 `TISCopyCurrentKeyboardInputSource` + `Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue()` 패턴을 그대로 재사용. `typeIsIME` 판정은 `CtrlBCore.isInputMethod(_:)` 재사용.

```swift
func currentInputSourceDisplay() -> InputSourceDisplay {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        return inputSourceDisplay(languageTag: nil, localizedName: nil, typeIsIME: false)
    }

    let typeString: String = {
        guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else { return "" }
        return Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String
    }()
    let langTag: String? = {
        guard let p = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages),
              let arr = Unmanaged<CFArray>.fromOpaque(p).takeUnretainedValue() as? [String]
        else { return nil }
        return arr.first
    }()
    let name: String? = {
        guard let p = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else { return nil }
        return (Unmanaged<CFString>.fromOpaque(p).takeUnretainedValue() as String)
    }()

    return inputSourceDisplay(languageTag: langTag, localizedName: name,
                              typeIsIME: isInputMethod(typeString))
}
```

### `Sources/CtrlB/StatusBarController.swift`

세 군데 수정 (모두 소규모):

1. **저장 프로퍼티 추가**. `init` 내부에서 생성해 public `init(eventTap:stats:)` 시그니처를 유지 → **테스트 변경 없음**:
   ```swift
   private let aboutPanel: AboutPanelController
   ```
   `init`에서 `self.stats = stats` 바로 뒤:
   ```swift
   self.aboutPanel = AboutPanelController(stats: stats,
                                           currentInputSource: currentInputSourceDisplay)
   ```

2. **메뉴 항목 추가**. `buildMenu(_:)`의 맨 끝, 기존 Quit 항목 직전(현 69~72줄 사이)에:
   ```swift
   menu.addItem(action(localized("menu.about"), #selector(showAbout)))
   ```
   기존 `action(_:_:)` 헬퍼가 `self`를 target으로 설정하므로, target 별도 지정 없이 그대로 재사용 가능.

3. **전달 액션 추가**. "Actions" 섹션에:
   ```swift
   @objc private func showAbout() {
       aboutPanel.show(nil)
   }
   ```

### `Sources/CtrlB/Resources/{en,ko,ja,zh-Hans}.lproj/Localizable.strings`

각 파일의 기존 섹션 스타일에 맞춰 메뉴 제목 한 줄 추가:
- en: `"menu.about" = "About ctrl-b";`
- ko: `"menu.about" = "ctrl-b 정보";`
- ja: `"menu.about" = "ctrl-b について";`
- zh-Hans: `"menu.about" = "关于 ctrl-b";`

### `Resources/Info.plist`

닫는 `</dict>` 직전에 한 쌍 추가:
```xml
<key>NSHumanReadableCopyright</key>
<string>© 2026 HanByul Yang. MIT License.</string>
```
Makefile의 `app` 타깃이 이 파일을 이미 복사하고 있으므로(19번 줄) Makefile은 수정 불필요.

## 재사용하는 기존 코드

- `CtrlBCore.isInputMethod(_:)` — `typeIsIME` 판정에 그대로 재사용.
- `InputSourceUtils.swift` 10–42번 줄의 TIS 속성 읽기 패턴 — 신규 `currentInputSourceDisplay()`에서 동일하게 복제.
- `StatusBarController.action(_:_:)` 헬퍼 (106번 줄) — About 메뉴 항목 구성에 재사용. target/selector 신규 배선 불필요.
- `StatisticsManager.remapCount` / `.timeSavedSeconds` — `StatusBarController.swift:58`에서 이미 읽고 있음. Credits 통계 라인에 재사용.
- `Bundle.module` + `NSLocalizedString` 패턴 (`StatusBarController.swift:41`) — 메뉴 제목에 재사용 (Credits 본문은 의도적으로 미현지화).

## 검증

1. `make lint` — 통과해야 함 (SwiftLint `force_unwrapping` opt-in, `!` 사용 금지).
2. `swift test --filter InputSourceDisplayTests` — 로케일→국기 매핑 단위 테스트.
3. `swift test` — 전체 스위트 통과 (기존 테스트 수정 없음 확인).
4. `swift build -c release && make app` — `ctrl-b.app` 생성.
5. `ctrl-b.app` 실행 후 메뉴 바 `⌃b` 아이콘 클릭 → "ctrl-b 정보"(또는 현재 언어) 항목이 "종료" 바로 위에 있는지 확인.
6. "ctrl-b 정보" 클릭:
   - Apple 표준 패널이 **다른 창보다 앞으로** 뜸 (`NSApp.activate` 확인).
   - 앱 아이콘, "ctrl-b", "Version 1.0.0 (1)", 저작권 "© 2026 HanByul Yang. MIT License." 표시.
   - Credits 영역이 설계대로 4행으로, 가운데 정렬로 렌더링.
   - ⌃Space로 한국어 입력 소스로 전환 → 패널 닫고 다시 열기 → "Currently:" 행이 `🇰🇷 2벌식`(혹은 macOS가 반환하는 localized name)으로 갱신.
   - 일본어, 중국어 간체 IME에 대해서도 반복.
   - ABC/US 키보드 선택 시 → `🇺🇸 ABC — idle` 표시.
   - "GitHub", "Report an issue", "MIT License" 각각 기본 브라우저로 예상 URL을 여는지 확인.
7. macOS UI 언어를 변경(System Settings → 언어 및 지역 → ko/ja/zh-Hans)하고 재실행 → **메뉴 항목** 제목은 현지화(`ctrl-b 정보` / `ctrl-b について` / `关于 ctrl-b`)되고, 패널 Credits 본문은 영어 유지되는지 확인.

## 범위 외

- 버전 번호 클릭 이스터 에그 / 트로피.
- 커스텀 NSPanel 기반 About (Maccy 2.x 스타일) — 표준 패널로 모든 요구 충족, 불필요.
- Credits 본문 또는 `NSHumanReadableCopyright`의 현지화 — 업계 관례 따라 의도적으로 미수행.
- README.md 업데이트 — 본 변경은 메뉴 항목 한 줄로 사용자 가시 동작이 크게 바뀌지 않으므로, v1.0.0 릴리즈 노트로 대체.