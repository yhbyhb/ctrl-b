# ctrl-b-helper 구현 플랜

## Context

macOS에서 한글 2벌식 IME 활성 상태로 tmux prefix `Ctrl+b`를 누르면  
터미널이 `\x02` 대신 `Ctrl+ㅠ`를 수신해 tmux prefix가 동작하지 않는 문제.

**목표:** 다른 Mac에도 배포 가능한 메뉴바 앱으로 제작.

---

## 언어 선택: Python vs Swift

| 항목 | Python + rumps | **Swift (권장)** |
|------|--------------|-----------------|
| 배포 | PyInstaller 필요, 번들 ~80MB | .app 번들, ~수 MB |
| 의존성 | pip, Python 런타임 포함 필요 | 없음 (macOS 기본 프레임워크) |
| 메뉴바 앱 | rumps 라이브러리 필요 | NSStatusItem 네이티브 |
| 서명/배포 | 복잡 | App Store 또는 Notarization 표준 |
| 개발 | 쉬움 | 약간 더 복잡하지만 표준 경로 |

→ **Swift** 선택. 네이티브 .app 번들로 빌드, 다른 Mac에 드래그앤드롭으로 설치 가능.

---

## 앱 구성

### Xcode 프로젝트 구조
```
ctrl-b-helper/
├── CtrlBHelper.xcodeproj
└── CtrlBHelper/
    ├── App/
    │   ├── CtrlBHelperApp.swift      # @main, NSApplicationDelegate
    │   └── AppDelegate.swift         # 메뉴바 설정, 앱 생명주기
    ├── Core/
    │   ├── KeyRemapper.swift         # CGEventTap 핵심 로직
    │   └── RemapTable.swift          # 리매핑 테이블 (확장 가능)
    ├── Stats/
    │   └── StatsStore.swift          # 리매핑 횟수·절약 시간 집계/영구 저장
    ├── UI/
    │   └── StatusBarController.swift # NSStatusItem, 메뉴 구성
    └── Resources/
        └── Assets.xcassets           # 메뉴바 아이콘
```

---

## 핵심 로직

### RemapTable.swift
```swift
let remapTable: [Character: CGKeyCode] = [
    "\u{3160}": 11,  // ㅠ → b (Ctrl+b = tmux prefix)
    "\u{1172}": 11,  // ᅲ → b (Hangul Jamo 분해형)
]
```

### KeyRemapper.swift — CGEventTap 흐름
```
CGEventTap 콜백 (kCGAnnotatedSessionEventTap, kCGHeadInsertEventTap)
  └─ keyDown 이벤트?         NO → pass through
  └─ Ctrl modifier 있음?     NO → pass through
  └─ CGEventKeyboardGetUnicodeString 로 Unicode 추출
  └─ remapTable에 해당 문자? NO → pass through
  └─ YES:
       ① CGEventCreateKeyboardEvent(nil, targetKeyCode, true)
       ② 원본 modifier flags 복사
       ③ CGEventPost(.annotatedSessionEventTap, newEvent)  ← IME 우회 주입
       ④ return nil  ← 원본 이벤트 폐기 (무한루프 없음: 'b'는 remapTable 미해당)
```

### StatusBarController.swift — 메뉴바 UI
```
메뉴바 아이콘: "한/B" 또는 SF Symbol
메뉴 항목:
  ✓ 활성화됨 (토글)
  ──────────
  오늘: 42회 리매핑 · 절약 시간 ~2분 6초
  누계: 1,234회 · ~1시간 1분
  ──────────
  로그인 시 자동 실행 (LaunchAgent 등록/해제)
  ──────────
  종료
```

### StatsStore.swift — 통계 저장
- `UserDefaults`에 **누계 리매핑 횟수** 영구 저장
- 세션 시작 시간 기록 → 오늘 횟수 계산
- **절약 시간 추정**: 리매핑 1회 = 입력기 전환(~3초) + 재입력(~0.5초) = **3.5초** 절약
  - 값은 상수로 분리해 나중에 조정 가능
- 메뉴 열 때마다 실시간 갱신

---

## 권한 처리

- `CGEventTap` 수정 모드는 **Accessibility(손쉬운 사용)** 권한 필요
- 권한 없을 시: 알림 다이얼로그 + 시스템 설정 자동 오픈
- `Info.plist`에 `NSAppleEventsUsageDescription` 추가

---

## 빌드 & 배포

- Xcode에서 **Archive** → `.app` export
- 다른 Mac에 복사 시: 처음 실행 시 Accessibility 권한만 부여하면 동작
- (선택) Apple Developer 계정으로 Notarize → Gatekeeper 경고 없음

---

## 검증 방법

1. Xcode에서 빌드 후 실행
2. 시스템 설정 > 손쉬운 사용 → 앱 허용
3. 한글 IME 켠 상태에서 터미널에서 `Ctrl+ㅠ` 입력
4. tmux prefix 동작 확인 / 메뉴바 아이콘에 리매핑 카운터 표시 확인
5. 로그인 자동실행 토글 후 재로그인 테스트
