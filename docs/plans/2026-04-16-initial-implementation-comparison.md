# 플랜 비교: Claude 플랜 vs Ultraplan

## 주요 차이점

### 1. 빌드 시스템

| 항목 | Claude 플랜 | Ultraplan |
|------|------------|-----------|
| 방식 | Xcode 프로젝트 | **SPM + Makefile** |
| Xcode 필요 | 필요 | 불필요 (`swiftc`만 있으면 됨) |

→ **Ultraplan 우세**: Xcode 없이도 빌드 가능해 다른 Mac 배포에 더 유리

---

### 2. 리매핑 방식 (핵심 차이)

| 항목 | Claude 플랜 | Ultraplan |
|------|------------|-----------|
| 방식 | 원본 이벤트 폐기 + 새 이벤트 주입 (`CGEventPost`) | **이벤트 in-place 수정** (`keyboardSetUnicodeString`) |
| 복잡도 | 무한루프 가드 필요 | 단순, 같은 이벤트 객체 수정 후 반환 |

→ **Ultraplan 우세**: 더 깔끔한 접근법

---

### 3. 한글 감지 범위

| 항목 | Claude 플랜 | Ultraplan |
|------|------------|-----------|
| 대상 | ㅠ, ᅲ 2개만 | Hangul Jamo 전체 (0x1100–0x11FF, 0x3130–0x318F, 0xAC00–0xD7A3) |
| 키 매핑 | Ctrl+ㅠ → Ctrl+b만 | **전체 알파벳 keyCode 테이블** (a–z 전부) |

→ **Ultraplan 우세**: `Ctrl+ㄴ`, `Ctrl+ㄱ` 등 다른 Ctrl+한글 조합도 자동으로 처리

---

### 4. 복원력

| 항목 | Claude 플랜 | Ultraplan |
|------|------------|-----------|
| 탭 비활성화 대응 | 없음 | `tapDisabledByTimeout` / `tapDisabledByUserInput` 수신 시 자동 재활성화 |

→ **Ultraplan 우세**: 장시간 실행 시 더 안정적

---

### 5. Claude 플랜에만 있는 것

- **로그인 시 자동 실행** 토글 (LaunchAgent 등록/해제)
- **오늘/누계 통계 구분** 표시 (오늘 N회 · ~M분 / 누계 N회 · ~M시간)

---

## 최종 결정: 두 플랜 통합

**Ultraplan의 구현 방식** + **Claude 플랜의 자동실행/상세 통계**를 합친 방향으로 진행.

| 채택 항목 | 출처 |
|----------|------|
| SPM + Makefile 빌드 시스템 | Ultraplan |
| in-place 이벤트 수정 (`keyboardSetUnicodeString`) | Ultraplan |
| 전체 한글 범위 + keyCode 테이블 | Ultraplan |
| `tapDisabled` 자동 복원 | Ultraplan |
| 로그인 시 자동 실행 토글 | Claude 플랜 |
| 오늘/누계 통계 구분 표시 | Claude 플랜 |
| 절약 시간 추정 (1회 = 3.5초) | Claude 플랜 |
