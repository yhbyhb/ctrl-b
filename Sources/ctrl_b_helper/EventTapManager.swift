import Cocoa
import CoreGraphics
import CtrlBHelperCore
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b-helper", category: "EventTap")

final class EventTapManager {
    /// 합성 이벤트 식별용 sentinel ("CBHRMAP" in ASCII)
    private static let sentinel: Int64 = 0x4342_4852_4D4150
    private let targetModifiers: CGEventFlags = [.maskControl]

    private let statisticsManager: StatisticsManager
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private(set) var isEnabled: Bool = true {
        didSet {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: isEnabled)
            }
        }
    }

    init(statisticsManager: StatisticsManager) {
        self.statisticsManager = statisticsManager
    }

    func start() {
        let trusted = AXIsProcessTrusted()
        log.info("Accessibility trusted: \(trusted ? "YES" : "NO")")

        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue) |
            (1 << CGEventType.tapDisabledByTimeout.rawValue) |
            (1 << CGEventType.tapDisabledByUserInput.rawValue)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: tapCallback,
            userInfo: selfPtr
        ) else {
            log.error("CGEvent.tapCreate failed — no accessibility permission?")
            showAccessibilityAlert()
            return
        }

        log.info("CGEvent.tapCreate succeeded")
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        log.info("Event tap enabled and added to run loop")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
    }

    func toggle() {
        isEnabled.toggle()
    }

    // MARK: - Private

    fileprivate func handleTapDisabled() {
        if let tap = eventTap, isEnabled {
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    fileprivate func handleKeyEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        // 합성 이벤트는 통과 (무한루프 방지)
        if event.getIntegerValueField(.eventSourceUserData) == Self.sentinel {
            return Unmanaged.passRetained(event)
        }

        // 대상 modifier 체크 (현재: Ctrl)
        guard !event.flags.isDisjoint(with: targetModifiers) else {
            return Unmanaged.passRetained(event)
        }

        // 대상 keyCode 체크 (a-z 알파벳 키만)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCodeToLowerASCII[keyCode] != nil else {
            return Unmanaged.passRetained(event)
        }

        // 한글 입력 소스 체크
        guard isKoreanInputSourceActive() else {
            return Unmanaged.passRetained(event)
        }

        // 원본 폐기 + 합성 이벤트 생성
        guard let source = CGEventSource(stateID: .hidSystemState),
              let newEvent = CGEvent(keyboardEventSource: source,
                                     virtualKey: CGKeyCode(keyCode),
                                     keyDown: type == .keyDown) else {
            return Unmanaged.passRetained(event)
        }

        newEvent.flags = event.flags
        newEvent.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)

        log.debug("REMAP: keyCode=\(keyCode) type=\(type == .keyDown ? "keyDown" : "keyUp") flags=0x\(String(event.flags.rawValue, radix: 16))")

        newEvent.post(tap: .cghidEventTap)

        // 통계는 keyDown에서만 기록
        if type == .keyDown {
            statisticsManager.recordRemap()
        }

        return nil  // 원본 폐기
    }

    private func showAccessibilityAlert() {
        let alert = NSAlert()
        alert.messageText = "손쉬운 사용 권한 필요"
        alert.informativeText = """
            ctrl-b-helper가 키보드 이벤트를 처리하려면 손쉬운 사용 권한이 필요합니다.

            시스템 설정 > 개인 정보 보호 및 보안 > 손쉬운 사용에서 허용해 주세요.
            """
        alert.addButton(withTitle: "시스템 설정 열기")
        alert.addButton(withTitle: "나중에")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - C callback (CGEventTap 콜백은 전역 함수여야 함)

private func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        manager.handleTapDisabled()
        return Unmanaged.passRetained(event)
    case .keyDown, .keyUp:
        return manager.handleKeyEvent(event, type: type)
    default:
        return Unmanaged.passRetained(event)
    }
}
