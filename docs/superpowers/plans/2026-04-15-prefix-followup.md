# Prefix Follow-up Key Remap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** tmux prefix(Ctrl+B) 리매핑 직후 다음 1개 알파벳 키도 한글→영문으로 리매핑하여, `Ctrl+B, n` 같은 tmux 명령이 한글 IME에서도 동작하게 한다.

**Architecture:** `EventTapManager`에 `pendingFollowUp` 플래그와 1.5초 타이머를 추가. Ctrl+B 리매핑 발생 시 플래그 설정, 다음 modifier 없는 알파벳 keyDown을 consume+recreate로 리매핑한 뒤 플래그 리셋.

**Tech Stack:** Swift 5.9, SPM, CoreGraphics (CGEventTap), DispatchWorkItem

**Spec:** `docs/superpowers/specs/2026-04-15-prefix-followup-design.md`

---

## File Map

| 파일 | 상태 | 역할 |
|------|------|------|
| `Sources/ctrl_b_helper/EventTapManager.swift` | 수정 | follow-up 상태 관리 + 리매핑 로직 추가 |

다른 파일 변경 없음.

---

### Task 1: Follow-up 상태 프로퍼티 추가

**Files:**
- Modify: `Sources/ctrl_b_helper/EventTapManager.swift`

- [ ] **Step 1: 프로퍼티 4개 추가**

`EventTapManager` 클래스의 `private var runLoopSource` 아래에 추가:

```swift
    private let prefixKeyCode: Int64 = 11  // Ctrl+B (향후 설정 가능)
    private var pendingFollowUp = false
    private var followUpTimer: DispatchWorkItem?
    private let followUpTimeout: TimeInterval = 1.5
```

- [ ] **Step 2: 빌드 확인**

Run: `swift build -c release 2>&1`
Expected: `Build complete!`

- [ ] **Step 3: 커밋**

```bash
git add Sources/ctrl_b_helper/EventTapManager.swift
git commit -m "feat: add prefix follow-up state properties to EventTapManager"
```

---

### Task 2: Follow-up 플래그 설정 (Ctrl+B 리매핑 시)

**Files:**
- Modify: `Sources/ctrl_b_helper/EventTapManager.swift`

- [ ] **Step 1: handleKeyEvent에서 Ctrl+B keyDown 리매핑 후 follow-up 활성화**

현재 `handleKeyEvent`의 통계 기록 부분 (line 119-122):

```swift
        // 통계는 keyDown에서만 기록
        if type == .keyDown {
            statisticsManager.recordRemap()
        }
```

이 부분을 다음으로 교체:

```swift
        // 통계는 keyDown에서만 기록
        if type == .keyDown {
            statisticsManager.recordRemap()

            // prefix 키(Ctrl+B) 리매핑 시 follow-up 활성화
            if keyCode == prefixKeyCode {
                pendingFollowUp = true
                followUpTimer?.cancel()
                let timer = DispatchWorkItem { [weak self] in
                    self?.pendingFollowUp = false
                }
                followUpTimer = timer
                DispatchQueue.main.asyncAfter(deadline: .now() + followUpTimeout, execute: timer)
                log.debug("Follow-up armed for next key (timeout: \(self.followUpTimeout)s)")
            }
        }
```

- [ ] **Step 2: 빌드 확인**

Run: `swift build -c release 2>&1`
Expected: `Build complete!`

- [ ] **Step 3: 커밋**

```bash
git add Sources/ctrl_b_helper/EventTapManager.swift
git commit -m "feat: arm follow-up flag after Ctrl+B remap"
```

---

### Task 3: Follow-up 리매핑 로직 구현

**Files:**
- Modify: `Sources/ctrl_b_helper/EventTapManager.swift`

- [ ] **Step 1: handleKeyEvent 메서드 시작 부분에 follow-up 체크 추가**

현재 `handleKeyEvent`의 sentinel 체크 바로 뒤 (line 88, `guard !event.flags.isDisjoint(with: targetModifiers)` 이전)에 follow-up 분기를 삽입:

```swift
        // --- Follow-up 체크 (prefix 키 리매핑 직후 다음 1키) ---
        if pendingFollowUp && type == .keyDown {
            pendingFollowUp = false
            followUpTimer?.cancel()
            followUpTimer = nil

            // modifier 없는 알파벳 키 + 한글 IME → 리매핑
            let followUpKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let hasNoModifiers = event.flags.isDisjoint(with: [.maskControl, .maskCommand, .maskAlternate])

            if hasNoModifiers,
               keyCodeToLowerASCII[followUpKeyCode] != nil,
               isKoreanInputSourceActive() {

                guard let source = CGEventSource(stateID: .hidSystemState),
                      let newEvent = CGEvent(keyboardEventSource: source,
                                             virtualKey: CGKeyCode(followUpKeyCode),
                                             keyDown: true) else {
                    return Unmanaged.passRetained(event)
                }

                newEvent.flags = event.flags
                newEvent.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)

                log.debug("FOLLOW-UP REMAP: keyCode=\(followUpKeyCode) flags=0x\(String(event.flags.rawValue, radix: 16))")

                newEvent.post(tap: .cghidEventTap)
                statisticsManager.recordRemap()

                return nil  // 원본 폐기
            }

            // 조건 불일치 → 통과 (플래그는 이미 리셋됨)
            log.debug("Follow-up dismissed: keyCode=\(followUpKeyCode) hasNoModifiers=\(hasNoModifiers)")
        }
        // --- Follow-up 체크 끝 ---
```

이 블록은 sentinel 체크와 Ctrl 체크 사이에 위치한다. 전체 순서:
1. sentinel 체크 → 합성 이벤트 통과
2. **follow-up 체크** → pendingFollowUp일 때 처리
3. Ctrl+알파벳 체크 → 기존 로직

- [ ] **Step 2: 빌드 확인**

Run: `swift build -c release 2>&1`
Expected: `Build complete!`

- [ ] **Step 3: 기존 테스트 통과 확인**

Run: `swift test 2>&1`
Expected: 47개 테스트 전부 통과

- [ ] **Step 4: lint 확인**

Run: `make lint 2>&1`
Expected: 0 violations

- [ ] **Step 5: 커밋**

```bash
git add Sources/ctrl_b_helper/EventTapManager.swift
git commit -m "feat: implement prefix follow-up key remap with 1.5s timeout"
```

---

### Task 4: 수동 테스트

**Files:** 없음 (수동 확인)

- [ ] **Step 1: 앱 빌드 및 실행**

```bash
swift build -c release 2>&1 && .build/release/ctrl-b-helper 2>&1 | tee /tmp/ctrl-b-followup-test.log
```

또는:

```bash
make app && make install && open /Applications/ctrl-b-helper.app
```

- [ ] **Step 2: 핵심 동작 테스트 (스펙 테스트 #1-5)**

한글 2벌식으로 전환 후:

1. Ghostty + tmux → Ctrl+B → n → next-window 실행? (PASS/FAIL)
2. Ghostty + tmux → Ctrl+B → c → new-window 실행? (PASS/FAIL)
3. Ghostty + tmux → Ctrl+B → p → previous-window 실행? (PASS/FAIL)
4. Ghostty + tmux → Ctrl+B → [ → copy mode 진입? (PASS/FAIL — 기호, 기존 동작)
5. Ghostty + tmux → Ctrl+B → d → detach? (PASS/FAIL)

- [ ] **Step 3: 엣지 케이스 테스트 (스펙 테스트 #6-10)**

6. 한글 → Ctrl+B → (2초 대기) → 한글 입력 → 한글 정상? (PASS/FAIL)
7. 한글 → Ctrl+B → Enter → Enter 통과, 한글 정상? (PASS/FAIL)
8. 한글 → Ctrl+B → Ctrl+B → 두 번째 Ctrl+B 정상? (PASS/FAIL)
9. 영문 → Ctrl+B → n → 기존 동작, 간섭 없음? (PASS/FAIL)
10. 한글 → Ctrl+C → 한글 입력 → 한글 정상? (PASS/FAIL — follow-up 없어야 함)

- [ ] **Step 4: 통계 테스트 (스펙 테스트 #11)**

11. 통계 초기화 → 한글 + Ctrl+B → n → 카운트 +2? (PASS/FAIL — Ctrl+B 1회 + follow-up n 1회)

- [ ] **Step 5: 테스트 FAIL 시 대응**

- follow-up 리매핑 안 됨: 로그에서 `Follow-up armed` → `FOLLOW-UP REMAP` 순서 확인. `Follow-up dismissed`가 뜨면 조건 불일치 원인 확인 (modifier? 한글 감지?)
- 타임아웃 후에도 리매핑됨: `pendingFollowUp` 리셋이 안 되는 경우 → 타이머 동작 확인
- 통계 2배: follow-up에서 `recordRemap()` 호출 확인

- [ ] **Step 6: 커밋 (테스트 결과 기록)**

테스트 PASS 확인 후:

```bash
git commit --allow-empty -m "test: manual testing for prefix follow-up - all PASS

Tested: Ctrl+B → n/c/p/d (tmux commands), Ctrl+B → [ (symbol passthrough),
timeout expiry, Enter dismissal, Ctrl+B → Ctrl+B retry, Ctrl+C no follow-up,
English mode no interference, statistics accuracy (+2 for prefix+follow-up)"
```
