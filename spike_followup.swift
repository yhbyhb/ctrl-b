#!/usr/bin/env swift
// Spike: modifier 없는 알파벳 키를 consume+recreate 했을 때
// 한글 IME 하에서 영문이 나오는지 검증
//
// 사용법:
// 1. 한글 2벌식으로 전환
// 2. swift spike_followup.swift 실행
// 3. TextEdit 등 텍스트 편집기를 열고 포커스
// 4. 'n' 키를 누르면 이 앱이 가로채서 합성 이벤트로 교체
// 5. TextEdit에 'n'이 입력되면 성공, 'ㅜ'면 실패
// 6. Ctrl+C로 종료

import CoreGraphics
import Foundation

let sentinel: Int64 = 0x5350_494B_4554_5354  // "SPIKETST"
let targetKeyCode: Int64 = 45  // 'n' key

print("=== Spike: Follow-up Key Remap Test ===")
print("한글 IME 활성 상태에서 'n' 키를 가로채 합성 이벤트로 교체합니다.")
print("TextEdit 등을 열고 'n'을 눌러 보세요.")
print("")
print("Test A: keyCode만 설정 (유니코드 미설정)")
print("Test B: keyCode + keyboardSetUnicodeString('n')")
print("")
print("현재 모드: Test A (2초 후 Test B로 전환, 4초 후 종료)")
print("Ctrl+C로 종료")
print("")

var useExplicitUnicode = false

func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {

    // 합성 이벤트 통과
    if event.getIntegerValueField(.eventSourceUserData) == sentinel {
        return Unmanaged.passRetained(event)
    }

    guard type == .keyDown || type == .keyUp else {
        return Unmanaged.passRetained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

    // 'n' 키만 가로챔 (modifier 없는 경우만)
    guard keyCode == targetKeyCode else {
        return Unmanaged.passRetained(event)
    }

    // Ctrl/Cmd/Opt이 있으면 통과
    let hasModifiers = !event.flags.isDisjoint(with: [.maskControl, .maskCommand, .maskAlternate])
    guard !hasModifiers else {
        return Unmanaged.passRetained(event)
    }

    // Consume + Recreate
    guard let source = CGEventSource(stateID: .hidSystemState),
          let newEvent = CGEvent(keyboardEventSource: source,
                                 virtualKey: CGKeyCode(keyCode),
                                 keyDown: type == .keyDown) else {
        return Unmanaged.passRetained(event)
    }

    newEvent.flags = event.flags
    newEvent.setIntegerValueField(.eventSourceUserData, value: sentinel)

    if useExplicitUnicode && type == .keyDown {
        // Test B: 명시적 유니코드 설정
        var nChar: UniChar = 0x006E  // 'n'
        newEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: &nChar)
        print("[\(type == .keyDown ? "keyDown" : "keyUp")] REMAP (Test B: explicit unicode 'n')")
    } else {
        // Test A: keyCode만
        print("[\(type == .keyDown ? "keyDown" : "keyUp")] REMAP (Test A: keyCode only)")
    }

    newEvent.post(tap: .cghidEventTap)
    return nil
}

// 이벤트 탭 생성
let eventMask: CGEventMask =
    (1 << CGEventType.keyDown.rawValue) |
    (1 << CGEventType.keyUp.rawValue)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: eventMask,
    callback: tapCallback,
    userInfo: nil
) else {
    print("ERROR: CGEvent.tapCreate failed. Accessibility permission needed.")
    exit(1)
}

let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("Event tap active. Press 'n' in another app...")
print("")

// 모드 전환 타이머
DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
    useExplicitUnicode = true
    print("")
    print("=== Switched to Test B: explicit unicode ===")
    print("'n'을 다시 눌러 보세요.")
    print("")
}

DispatchQueue.main.asyncAfter(deadline: .now() + 12.0) {
    print("")
    print("=== Test complete ===")
    exit(0)
}

CFRunLoopRun()
