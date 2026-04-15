#!/usr/bin/env swift
// 새 이벤트 재생성 로직 검증용 시뮬레이션
// 전제: 한글 입력 소스(2벌식 등)가 활성인 상태에서 실행
import CoreGraphics
import Foundation

let sentinel: Int64 = 0x4342_4852_4D4150

// Test 1: Ctrl+b (keyDown) — 한글 활성이므로 재작성 대상
print("=== Test 1: Ctrl+b keyDown (한글 활성 → 재작성 대상) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: true) {
    event.flags = .maskControl
    var yu: UniChar = 0x3160
    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &yu)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, char=U+3160 (ㅠ)")
}
usleep(300_000)

// Test 2: Ctrl+b (keyUp) — 한글 활성이므로 재작성 대상
print("=== Test 2: Ctrl+b keyUp (한글 활성 → 재작성 대상) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: false) {
    event.flags = .maskControl
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, keyUp")
}
usleep(300_000)

// Test 3: Ctrl+Space — 알파벳 아님, 입력 소스 무관하게 항상 통과
print("=== Test 3: Ctrl+Space (비알파벳 → 항상 통과) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true) {
    event.flags = .maskControl
    var space: UniChar = 0x0020
    event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &space)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=49, flags=Ctrl, char=U+0020 (space)")
}
usleep(300_000)

// Test 4: sentinel이 있는 이벤트 — 합성 이벤트, 항상 통과
print("=== Test 4: Sentinel 이벤트 (합성 → 항상 통과) ===")
if let event = CGEvent(keyboardEventSource: nil, virtualKey: 11, keyDown: true) {
    event.flags = .maskControl
    event.setIntegerValueField(.eventSourceUserData, value: sentinel)
    event.post(tap: .cgSessionEventTap)
    print("  Posted: keyCode=11, flags=Ctrl, sentinel=YES")
}
usleep(300_000)

print("\n=== Done ===")
