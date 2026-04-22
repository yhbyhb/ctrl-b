# 플랜 비교: Claude 로컬 vs Ultraplan (About 패널 추가)

대상 파일
- Claude 로컬: `docs/plans/2026-04-22-about-panel-claude.md` (135 줄)
- Ultraplan: `docs/plans/2026-04-22-about-panel-ultraplan.md` (263 줄)

두 플랜은 **같은 설계 결정**에서 출발 — 표준 `orderFrontStandardAboutPanel` + D+E 옵션 (라이브 IME + 키캡 시연) + 영어 전용 Credits + 메뉴 제목만 로컬라이즈. 큰 골격은 일치하고, 차이는 디테일 수준과 코드 배선 접근법에 있음.

## 판정 요약

| 항목 | Claude 로컬 | Ultraplan | 우세 |
|---|---|---|---|
| 전체 분량 | 135줄 | 263줄 (1.95×) | 용도에 따라 — |
| 아키텍처 다이어그램 | ✗ | ✅ ASCII 모듈 다이어그램 | **Ultraplan** |
| 코드 스니펫 구체성 | 부분적 | 거의 모든 신규 함수 완본 | **Ultraplan** |
| 메뉴 와이어링 | `aboutItem.target = aboutPanel` (직접 타깃 재배치, 기존 헬퍼 우회) | `@objc showAbout()` 포워더 → 기존 `action(_:_:)` 헬퍼 재사용 | **Ultraplan** (기존 패턴 일관성) |
| `StatusBarController` 테스트 영향 | 언급 없음 | "기존 테스트 수정 없이 통과" 명시 | **Ultraplan** |
| 국기 매핑 엣지 케이스 | 정적 매핑 | `zh-Hant*` 를 `zh*`보다 먼저, prefix-match 명시 | **Ultraplan** (정확성) |
| 통계 포맷 구체성 | "영어로 포맷" 정도 | `NumberFormatter.localizedString` + `Locale("en_US")`, 초/분/시 버킷 구체화 | **Ultraplan** |
| MIT License 링크 | `opensource.org/licenses/MIT` (임시) + "LICENSE 없음" 가정 | `github.com/yhbyhb/ctrl-b/blob/main/LICENSE` (파일 실재 가정) | **Ultraplan** (사실 확인 결과 LICENSE 실제로 존재) |
| Credits 키캡 표기 | `⌃B under 한 / 中 / あ` | `⌃b under 한 / 中 / あ` (앱 브랜딩 소문자와 일관) | **Ultraplan** |
| 범위 외 항목 | LICENSE 생성, 이스터에그, NSPanel 커스텀, Credits 로컬라이즈 | 이스터에그, NSPanel 커스텀, Credits 로컬라이즈, README 업데이트 | 동등 |
| 재사용 코드 섹션 | 5개 항목 | 5개 항목 (거의 동일) | 동등 |

**종합 — Ultraplan 쪽이 실행 가능성이 더 높음.** 단 큰 설계 결정은 같아서 "선택"보다는 "Ultraplan 버전을 채택하고 Claude 로컬의 섹션 구성을 부분 차용" 수준이 적절.

## 핵심 차이점 상세

### 1. 메뉴 와이어링 접근법 (가장 중요한 차이)

**Claude 로컬**:
```swift
let aboutItem = NSMenuItem(title: localized("menu.about"),
                           action: #selector(AboutPanelController.show(_:)),
                           keyEquivalent: "")
aboutItem.target = aboutPanel
menu.addItem(aboutItem)
```
기존 `action(_:_:)` 헬퍼를 재사용하지 못하는 이유까지 플랜에 명시. 선택 대상이 `StatusBarController`가 아닌 다른 인스턴스라서 헬퍼가 자동 설정하는 `target = self`를 피해야 함.

**Ultraplan**:
```swift
// StatusBarController 안
@objc private func showAbout() {
    aboutPanel.show(nil)
}

// buildMenu 내
menu.addItem(action(localized("menu.about"), #selector(showAbout)))
```
`StatusBarController`에 포워더 메서드 하나 추가 → 기존 `action(_:_:)` 헬퍼 그대로 사용. 코드베이스 기존 패턴과 **완전 일관**.

판정: **Ultraplan이 더 낫다.** 헬퍼 우회가 필요 없고, 나머지 메뉴 항목들과 같은 방식으로 리뷰어가 이해 가능.

### 2. LICENSE 링크

**Claude 로컬**이 기반으로 삼은 오래된 메모리(`feedback_ultraplan_handoff.md` 근처의 `project_workflow.md`, "next: LICENSE + Release Please")를 현재 상태 확인 없이 신뢰해서, "LICENSE 아직 없음 → 임시로 opensource.org 링크 → 범위 외" 구조로 작성됨.

**실제 상태**: `/Users/hanbyul/repos/ctrl-b/LICENSE` (2026-04-16 생성, 1069 바이트) **이미 존재**. 따라서:
- Ultraplan의 `github.com/yhbyhb/ctrl-b/blob/main/LICENSE` 링크가 **그대로 유효**
- Claude 로컬의 "범위 외: LICENSE 생성"은 **삭제** 대상
- 메모리 `project_workflow.md`는 업데이트 필요

이는 메모리 시스템의 "always verify against current state" 원칙 위반 사례 — 검증 없이 메모리를 신뢰했을 때 플랜이 실제와 어긋남.

### 3. 국기 매핑 정확성

**Claude 로컬**: 단순 일대일 매핑 기술. 구현 디테일은 "implementation 때 결정".

**Ultraplan**: prefix-match 규칙을 플랜에서 못 박음:
```
zh-Hant* → 🇹🇼   (zh-Hans* 보다 먼저 검사하도록 명시)
zh*      → 🇨🇳
```
이는 `TISCopyCurrentKeyboardInputSource`가 반환할 수 있는 `zh-Hans-CN`, `zh-Hant-TW` 같은 확장 태그를 고려한 것. 구현 시 버그 예방.

### 4. 코드 스니펫 밀도

- Claude 로컬: `AboutPanelController`와 `InputSourceDisplay`의 **시그니처만** 명시, 본문은 "implementation time"에 결정.
- Ultraplan: `currentInputSourceDisplay()` 전체 본문, `AboutPanelController` 초안, `InputSourceDisplay` struct 전체 인터페이스를 플랜 단계에서 확정.

Ultraplan은 "플랜 = 준(準)구현"에 가깝고, Claude 로컬은 "플랜 = 의사결정 기록"에 가까움. 어느 쪽이 나은가는 팀 문화에 따라 다르지만, 첫 구현이라면 Ultraplan 방식이 merge까지 도달 시간을 단축함.

## Ultraplan에만 있고 Claude 로컬에 없는 것

1. ASCII 아키텍처 다이어그램 (CtrlBCore ↔ CtrlB 경계 시각화)
2. 테스트 영향 명시: "기존 `StatusBarController` 테스트 변경 없이 통과"
3. prefix-match 우선순위 규칙
4. 통계 포맷의 정확한 API 선택 (`NumberFormatter.localizedString`, `Locale(en_US)`)
5. 7번째 검증 케이스: "알 수 없는 태그(`fr`) → 🌐 폴백, localizedName은 그대로 보존"
6. 범위 외: README 업데이트 (v1.0.0 릴리즈 노트로 대체)

## Claude 로컬에만 있고 Ultraplan에 없는 것

1. `AboutPanelController` 타깃 배선이 **왜** 기존 헬퍼로 불가능한지의 설명 (결과적으로 Ultraplan이 그 문제를 우회하므로 무의미해짐)
2. LICENSE 생성을 범위 외로 명시 (틀림 — LICENSE 이미 존재)
3. 메모리 업데이트 자체를 플랜에 반영하지 않았음 (메모리 갱신은 구현 과정 산출물)

## 권장 진행 방향

1. **Ultraplan 버전을 구현의 기준 문서로 채택.**
2. MIT License 링크는 **실제 `github.com/yhbyhb/ctrl-b/blob/main/LICENSE`** 로 확정.
3. Claude 로컬 플랜의 배경 섹션만큼은 서사가 더 매끄러워서, 이 섹션만 Ultraplan 앞에 덧대어도 좋음 (실무적으론 둘 중 하나로 통일).
4. 구현 착수 전 `project_workflow.md` 메모리를 **현재 상태 기준으로 업데이트** — "LICENSE 이미 존재, 다음은 Release Please"로 정정.

## 메타 관찰 — 두 모델의 성격

- **Claude 로컬 (Opus 4.7 메인 세션)**: 대화 맥락을 최대한 활용 — 사용자와의 왕복에서 나온 옵션 A/B/C/D/E 이름을 그대로 쓰고, "왜 이 선택인가"의 서사가 강함. 반면 오래된 메모리를 검증 없이 신뢰하는 약점 노출.
- **Ultraplan (원격 정제)**: 대화 맥락 없이 현 코드만 기반으로 설계 → 기존 `action(_:_:)` 헬퍼 재사용처럼 "이 레포의 기존 패턴"에 더 충실. 엣지 케이스 (prefix match, 테스트 영향) 명시가 강함. 설명 서사는 상대적으로 건조.

**두 도구를 함께 쓰는 게 일관되게 유익해 보임** — 로컬에서 브레인스토밍·옵션 탐색, Ultraplan에서 실행 가능한 정제. 이번에도 프로세스 자체가 효과적이었다는 증거.
