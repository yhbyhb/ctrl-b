# Design: Prefix Follow-up Key Remap

## 문제

한글 IME에서 tmux prefix(`Ctrl+B`) 후 명령키(`n`, `c`, `p` 등)를 누르면, 한글 자모(`ㅜ`, `ㅊ`, `ㅔ` 등)가 전달되어 tmux가 명령을 인식하지 못한다. `[` 같은 기호는 IME 영향을 받지 않아 정상 동작.

## 해결

Ctrl+B 리매핑 직후 **1.5초 이내** 다음 **modifier 없는 알파벳 keyDown** 1개를 한글→영문으로 리매핑한다.

## 대상 prefix 키

- 현재: **Ctrl+B만** (keyCode 11)
- `prefixKeyCode` 프로퍼티로 관리하여 향후 설정 변경 가능

## 동작 흐름

```
Ctrl+B keyDown 리매핑 발생
  → pendingFollowUp = true
  → 1.5초 타이머 시작 (DispatchWorkItem)

다음 keyDown 도착
  ├─ pendingFollowUp == false → 기존 로직 (변경 없음)
  │
  └─ pendingFollowUp == true
       ├─ modifier 없음 + 알파벳 키 (keyCodeToLowerASCII에 존재) + 한글 IME
       │    → 원본 폐기 + 합성 이벤트 생성/post (기존 consume+recreate 기법 동일)
       │    → recordRemap()
       │
       ├─ 그 외 (기호, Enter, Esc, modifier 포함 키 등)
       │    → 통과 (이벤트 수정 없음)
       │
       └─ 어떤 키든 pendingFollowUp = false, 타이머 취소

타이머 만료 (1.5초)
  → pendingFollowUp = false

keyUp 이벤트
  → pendingFollowUp 플래그에 영향 없음
```

## 변경 파일

### 수정: `Sources/ctrl_b_helper/EventTapManager.swift`

**추가할 상태:**
```swift
private let prefixKeyCode: Int64 = 11  // Ctrl+B (향후 설정 가능)
private var pendingFollowUp = false
private var followUpTimer: DispatchWorkItem?
private let followUpTimeout: TimeInterval = 1.5
```

**handleKeyEvent 변경:**

1. 기존 Ctrl+알파벳 리매핑 로직 후, keyCode가 `prefixKeyCode`이고 keyDown이면 follow-up 플래그 설정 + 타이머 시작.

2. 메서드 진입 시 `pendingFollowUp`이 true이고 keyDown이면 follow-up 분기:
   - modifier 없음 + 알파벳 키 + 한글 IME → consume+recreate (sentinel 포함)
   - 조건 불일치 → 통과
   - 어느 경우든 플래그 리셋 + 타이머 취소

**follow-up 리매핑은 기존 Ctrl+키 리매핑과 동일한 consume+recreate 기법 사용.** 합성 이벤트에 sentinel을 설정하여 무한루프 방지. 통계도 keyDown에서만 recordRemap().

**주의: follow-up 체크는 Ctrl+키 체크보다 먼저 실행.** 순서:
1. sentinel 체크 (무한루프 방지)
2. follow-up 체크 (pendingFollowUp == true && keyDown)
3. Ctrl+알파벳 체크 (기존 로직)

이유: follow-up 키는 modifier가 없으므로 Ctrl 체크에 걸리지 않지만, Ctrl+B → Ctrl+B 같은 경우(prefix 취소 후 재시도) follow-up이 먼저 소비되고 두 번째 Ctrl+B가 정상 처리되어야 함. 실제로 Ctrl+B는 modifier가 있으므로 follow-up 조건(modifier 없음)에 걸리지 않아 통과 후 Ctrl+키 로직에서 처리됨. 순서가 올바름.

### 유지 (변경 없음)

- `Sources/ctrl_b_helper/InputSourceUtils.swift`
- `Sources/CtrlBHelperCore/HangulUtils.swift`
- `Sources/CtrlBHelperCore/StatisticsManager.swift`
- `Sources/ctrl_b_helper/StatusBarController.swift`

## 타임아웃 값 근거

- 숙련 tmux 사용자: prefix 후 100~500ms 내에 명령키 입력
- 느린/망설이는 사용자: 1초 이내
- 1.5초: 99%+ 커버 + 오탐 방지 (Karabiner-Elements의 `to_if_alone_timeout` 1000ms보다 보수적)
- 오탐 시 피해: 한글 1글자 대신 영문 1글자 입력 → 백스페이스 1회로 복구

## 안전장치

1. **modifier 키 포함 시 제외** — Ctrl+B 후 Ctrl+C는 follow-up이 아닌 새 단축키. modifier가 있으면 follow-up 조건 불일치 → 통과 → 기존 Ctrl+키 로직에서 처리.
2. **1회 소비** — 어떤 keyDown이든 pendingFollowUp을 false로 리셋. 다음 입력으로 누수 없음.
3. **1.5초 자동 만료** — Ctrl+B 후 한참 뒤에 한글 입력해도 영향 없음.
4. **keyUp 무시** — Ctrl+B의 keyUp이 follow-up을 소비하지 않음.

## 테스트 계획

### 수동 테스트 — 핵심 동작

| # | 환경 | 조작 | 기대 결과 | PASS 기준 |
|---|------|------|-----------|-----------|
| 1 | Ghostty + tmux + 한글 | Ctrl+B → n | next-window 실행 | 창 전환 확인 |
| 2 | Ghostty + tmux + 한글 | Ctrl+B → c | new-window 실행 | 새 창 생성 |
| 3 | Ghostty + tmux + 한글 | Ctrl+B → p | previous-window 실행 | 창 전환 확인 |
| 4 | Ghostty + tmux + 한글 | Ctrl+B → [ | copy mode 진입 | 스크롤 가능 확인 (기호, 기존 동작) |
| 5 | Ghostty + tmux + 한글 | Ctrl+B → d | detach | tmux 세션에서 분리 |

### 수동 테스트 — 엣지 케이스

| # | 조작 | 기대 결과 |
|---|------|-----------|
| 6 | 한글 + Ctrl+B → (2초 대기) → 한글 입력 | 한글 정상 입력 (리매핑 안 됨) |
| 7 | 한글 + Ctrl+B → Enter | Enter 통과, follow-up 리셋 |
| 8 | 한글 + Ctrl+B → Ctrl+B (prefix 재시도) | 첫 Ctrl+B에서 follow-up 리셋 (modifier 있어서 불일치), 두 번째 Ctrl+B 정상 처리 |
| 9 | 영문 + Ctrl+B → n | 기존 동작 (리매핑 불필요, 간섭 없음) |
| 10 | 한글 + Ctrl+C → 한글 입력 | 한글 정상 입력 (Ctrl+C는 prefix가 아니므로 follow-up 없음) |

### 수동 테스트 — 통계

| # | 조작 | 기대 결과 |
|---|------|-----------|
| 11 | 한글 + Ctrl+B → n | 카운트 +2 (Ctrl+B 1회 + follow-up n 1회) |
