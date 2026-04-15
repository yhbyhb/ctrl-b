# 리서치: macOS 한글 IME + Ctrl 키 문제 분석

## 문제 정의

macOS에서 한글 IME가 활성화된 상태로 Ctrl+B를 누르면, 터미널(tmux 등)에서 해당 단축키가 동작하지 않는다.

## 디버깅 결과

CGEventTap에 디버그 로그를 추가하여 실제 이벤트를 관찰한 결과:

### CGEvent 레벨에서는 문제 없음

```
한글 IME + Ctrl+B → keyCode=11 flags=[Ctrl] chars=[U+0002]  ← 이미 정상
영문    + Ctrl+B → keyCode=11 flags=[Ctrl] chars=[U+0002]  ← 동일
한글 IME + B (Ctrl 없음) → keyCode=11 flags=[] chars=[U+3160]  ← ㅠ
```

- Ctrl이 눌린 상태에서는 macOS가 CGEvent 레벨에서 이미 제어문자(U+0002)로 변환
- 한글 문자(ㅠ, U+3160)는 Ctrl 없이 누를 때만 나타남
- 따라서 `keyboardSetUnicodeString`으로 유니코드를 수정하는 접근법은 무의미

### 실제 문제 발생 계층

```
CGEvent (U+0002 정상)
  → NSEvent
    → 터미널의 keyDown:
      → interpretKeyEvents:
        → 한글 IME가 이벤트 소비 ← 여기서 문제 발생
          → tmux에 바이트 전달 안 됨
```

터미널 에뮬레이터가 한글 IME 활성 시 `interpretKeyEvents:`를 통해 키를 처리하는데, **raw 모드(tmux)에서 한글 IME가 Ctrl+키 이벤트를 소비**해 버린다.

### 환경별 테스트 결과

| 환경 | 결과 | 의미 |
|------|------|------|
| Ghostty + `cat` + 한글 + Ctrl+B | ^B 정상 출력 | cooked 모드에서는 IME가 정상 전달 |
| Ghostty + tmux + 한글 + Ctrl+B | **무반응** | raw 모드에서 IME가 이벤트 소비 |
| Terminal.app + tmux + 한글 + Ctrl+B | **안 됨** | 터미널 종류 무관, 공통 문제 |

---

## 접근법 비교

### A. 이벤트 폐기 + 새 CGEvent 생성 (채택)

한글 IME 상태에서 Ctrl+키 감지 시, 원본 이벤트를 폐기하고 IME 메타데이터가 없는 새 CGEvent를 생성하여 주입.

**신뢰도: 높음**

- 새 이벤트에는 IME 메타데이터가 없으므로 터미널이 `interpretKeyEvents:` 대신 직접 처리
- cmd-eikana(일본어 키보드 도구)가 동일한 방식으로 성공적으로 동작
- 터미널 에뮬레이터 종류에 무관하게 동작

**구현 핵심:**
- `TISCopyCurrentKeyboardInputSource`로 한글 입력 소스 감지 (isHangul 체크 아님)
- `eventSourceUserData` 필드(field 42)에 sentinel 값으로 무한루프 방지
- `.cghidEventTap`에 post (탭 생성은 root 필요하지만 post는 root 불필요)
- keyUp 이벤트도 함께 처리

### B. 입력 소스 전환 (Ctrl 누를 때 영문 전환)

**신뢰도: 낮음 — 미채택**

- `TISSelectInputSource`의 CJKV 버그: 한국어/중국어/일본어 입력 소스 전환 시 메뉴바 아이콘만 바뀌고 실제 전환 안 되는 macOS 버그 (Karabiner-Elements #1602)
- 메뉴바 입력 소스 표시가 매 Ctrl 누를 때마다 깜빡임
- 입력 소스 전환이 비동기적 — 전환 완료 전에 키 이벤트가 도착할 수 있는 레이스 컨디션
- 모든 앱에 영향 (터미널뿐 아니라 브라우저 등에서도 Ctrl 누를 때 입력 소스 전환)

### C. CGEvent 필드 수정

**신뢰도: 낮음 — 미채택**

- IME 메타데이터는 CGEvent의 정수 필드에 저장되지 않음
- 문서화된 키보드 필드: keyCode(9), autorepeat(8), keyboardType(10) — IME 관련 필드 없음
- 비문서화 필드를 조작하는 것은 macOS 버전에 따라 동작이 달라질 위험

### D. .cghidEventTap 사용

**불가**

- 탭 생성에 root 권한 필요. 메뉴바 앱으로는 비현실적

### E. NSEvent 모니터

**불가**

- `NSEvent.addGlobalMonitorForEvents`: 읽기 전용, 이벤트 수정/소비 불가
- `NSEvent.addLocalMonitorForEvents`: 자기 앱 이벤트만 처리 가능

---

## 관련 이슈 및 참고 자료

### 터미널 에뮬레이터

- [Ghostty #2628](https://github.com/ghostty-org/ghostty/discussions/2628): Input method keybinds penetrate
- [Ghostty #2934](https://github.com/ghostty-org/ghostty/discussions/2934): macOS text input system and control keys
- [Ghostty #5487](https://github.com/ghostty-org/ghostty/discussions/5487): Ctrl key not working in 1.1.0 for non-US layouts
- [WezTerm #2435](https://github.com/wezterm/wezterm/pull/2435): Enable control key in macOS IME
- [Kitty #1586](https://github.com/kovidgoyal/kitty/pull/1586): Fix macOS input method
- [Kitty #4062](https://github.com/kovidgoyal/kitty/issues/4062): Chinese IME control keys displayed directly
- [iTerm2 #279](https://github.com/gnachman/iTerm2/pull/279): Use handleEvent instead of interpretKeyEvents

### 키보드/입력 소스 도구

- [Karabiner-Elements #1602](https://github.com/pqrs-org/Karabiner-Elements/issues/1602): CJKV input source switching workaround
- [cmd-eikana](https://github.com/iMasanari/cmd-eikana): CGEventTap consume+re-create 방식 사용
- [Kawa](https://github.com/hatashiro/kawa): TISSelectInputSource CJKV 버그 우회 방식
- [Gureum](https://github.com/gureum/gureum): Apple IME 대체 — 근본적 해결이나 무거운 접근

### 기타

- [Claude Code #29478](https://github.com/anthropics/claude-code/issues/29478): Korean IME composition buffer leaks into tmux
- [CGEventField 문서](https://developer.apple.com/documentation/coregraphics/cgeventfield)
- [tmux Modifier Keys wiki](https://github.com/tmux/tmux/wiki/Modifier-Keys)
