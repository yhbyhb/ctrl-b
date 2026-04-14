# Plan: ctrl-b-helper macOS Menu Bar App

## Context

macOS Korean IME 활성 상태에서 Ctrl+B를 누르면, 'B' 키의 한글 자음(ㅠ, U+3160)이 Ctrl 조합과 함께 앱에 전달된다. 앱은 Ctrl+B가 아닌 Ctrl+ㅠ를 받게 되므로 vim의 `<C-b>` (page up) 등 Ctrl 단축키가 동작하지 않는다.

CGEventTap으로 앱 전달 전에 이벤트를 가로채어, Ctrl+한글 → Ctrl+영문자로 교정한다. 메뉴바 앱으로 상주하며 리매핑 횟수·절약 시간 통계를 표시한다.

---

## Event Flow

```
[keyboard HW] → CGEventTap (kCGSessionEventTap, .headInsert)
                    │
              keyDown + maskControl?
                    │
              chars = KoreanUnicode? ── No ──→ passthrough
                    │
                   Yes
                    │
              keyboardSetUnicodeString(controlChar(keyCode))
                    │
              statisticsManager.record()
                    │
                    └──→ [target app receives Ctrl+B]
```

---

## File Structure

```
ctrl-b-helper/
├── Package.swift                      # SPM manifest (macOS 13+)
├── Makefile                           # swiftc + .app bundle 생성
├── Resources/
│   └── Info.plist                     # LSUIElement=YES, bundle ID
└── Sources/
    └── ctrl_b_helper/
        ├── main.swift                 # NSApplication.shared.run()
        ├── AppDelegate.swift          # 앱 진입, Accessibility 권한 확인
        ├── EventTapManager.swift      # CGEventTap 핵심 로직
        ├── StatisticsManager.swift    # UserDefaults 통계 저장
        └── StatusBarController.swift  # NSStatusItem + NSMenu UI
```

---

## Implementation Details

### EventTapManager.swift — 핵심 로직

**탭 생성**
```swift
CGEvent.tapCreate(
    tap: .cgSessionEventTap,       // IME 처리 이후 레벨
    place: .headInsertEventTap,    // 다른 탭보다 먼저 처리
    options: .defaultTap,
    eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
    callback: eventCallback,
    userInfo: Unmanaged.passUnretained(self).toOpaque()
)
```

**한글 감지 및 교정**
```swift
// callback 내부
let flags = event.flags
guard flags.contains(.maskControl) else { return passthrough }

var chars = [UniChar](repeating: 0, count: 4)
var length = 0
event.keyboardGetUnicodeString(maxStringLength: 4, actualStringLength: &length, unicodeString: &chars)

guard length > 0, isHangul(chars[0]) else { return passthrough }

// keyCode → ASCII lowercase → Control char (e.g. 11→'b'→0x02)
let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
guard let ascii = keyCodeToLowerASCII[keyCode] else { return passthrough }

var ctrl = UniChar(ascii & 0x1F)   // Ctrl+B = 0x02
event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ctrl)

statisticsManager.recordRemap()
return Unmanaged.passRetained(event)   // 수정된 이벤트 반환
```

**한글 범위 (isHangul)**
- Hangul Jamo: 0x1100–0x11FF
- Hangul Compatibility Jamo: 0x3130–0x318F  (ㅠ = U+3160 ← 주 대상)
- Hangul Syllables: 0xAC00–0xD7A3

**keyCodeToLowerASCII dictionary** — keyCode(Int64) → UInt8
```
0→97(a), 1→115(s), 2→100(d), 3→102(f), 4→104(h), 5→103(g),
6→122(z), 7→120(x), 8→99(c), 9→118(v), 11→98(b), 12→113(q),
13→119(w), 14→101(e), 15→114(r), 16→121(y), 17→116(t),
31→111(o), 32→117(u), 34→105(i), 35→112(p), 37→108(l),
38→106(j), 40→107(k), 45→110(n), 46→109(m)
```

**이벤트 탭 비활성화 복구**  
`kCGEventTapDisabledByTimeout` / `kCGEventTapDisabledByUserInput` 수신 시 `CGEvent.tapEnable(tap:enable:true)` 재호출.

### StatisticsManager.swift

```swift
// UserDefaults keys
"remapCount" : Int
"timeSaved"  : Double  // seconds, 리맵 1회 = 0.5초 절약 가정

func recordRemap() {
    DispatchQueue.main.async { ... +1 count, +0.5s ... }
}

var formattedTimeSaved: String  // 60초 미만→"N.Ns", 미만 1시간→"N.Nm", 이상→"N.Nh"
```

### StatusBarController.swift

- 버튼 타이틀: `"⌃B"` (고정 텍스트, 심플)
- 메뉴 항목 (매번 갱신):
  ```
  Ctrl+ㅠ → Ctrl+B 리매핑       (disabled header)
  ─────────────────────────────
  리매핑 횟수: 42회              (disabled)
  절약한 시간: 21.0초            (disabled)
  ─────────────────────────────
  통계 초기화                    (action)
  ─────────────────────────────
  종료                  ⌘Q     (action)
  ```
- 메뉴 열릴 때마다(`menuWillOpen`) 통계 갱신 (Timer 불필요)

### AppDelegate.swift

```swift
func applicationDidFinishLaunching(_:) {
    NSApp.setActivationPolicy(.accessory)   // Dock 아이콘 숨김

    // Accessibility 권한 확인
    let trusted = AXIsProcessTrustedWithOptions(
        [kAXTrustedCheckOptionPrompt: true] as CFDictionary
    )
    if !trusted {
        showAccessibilityAlert()   // System Settings 안내 alert
    }

    // 컴포넌트 초기화
    let stats = StatisticsManager()
    let eventTap = EventTapManager(statisticsManager: stats)
    statusBarController = StatusBarController(eventTap: eventTap, stats: stats)
    eventTap.start()
}
```

### Info.plist (필수 키)

```xml
LSUIElement = true          <!-- Dock 숨김 -->
CFBundleExecutable = ctrl-b-helper
CFBundleIdentifier = com.user.ctrl-b-helper
CFBundlePackageType = APPL
NSPrincipalClass = NSApplication
NSHighResolutionCapable = true
```

### Makefile (macOS에서 실행)

```makefile
build:
    swiftc -O -target arm64-apple-macos13.0 \
        Sources/ctrl_b_helper/*.swift \
        -framework Cocoa -o ctrl-b-helper-bin
    mkdir -p ctrl-b-helper.app/Contents/MacOS
    cp ctrl-b-helper-bin ctrl-b-helper.app/Contents/MacOS/ctrl-b-helper
    cp Resources/Info.plist ctrl-b-helper.app/Contents/Info.plist

install: build
    cp -r ctrl-b-helper.app /Applications/
```

---

## Accessibility Permission Flow

1. 앱 최초 실행 시 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` 호출
   - macOS가 자동으로 "접근성 허용" 다이얼로그 표시
2. 권한 미부여 시 NSAlert로 System Settings > Privacy & Security > Accessibility 안내
3. CGEventTap 생성 실패 시에도 동일 안내 (탭은 접근성 없으면 생성 불가)

---

## Verification

```bash
# macOS에서 빌드
make build

# 앱 실행 후:
# 1. 메뉴바에 ⌃B 아이콘 확인
# 2. System Settings > Accessibility에 ctrl-b-helper 추가 허용
# 3. 한글 IME 켠 상태에서 vim/터미널에서 Ctrl+B 입력
# 4. vim page-up 동작 확인
# 5. 메뉴바 클릭 → "리매핑 횟수: 1회" 표시 확인
# 6. 통계 초기화 → 횟수 0 확인
```