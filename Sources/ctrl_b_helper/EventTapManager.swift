import Cocoa
import CoreGraphics
import CtrlBHelperCore

final class EventTapManager {
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
        let eventMask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
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
            showAccessibilityAlert()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
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

    fileprivate func handleKeyEvent(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        guard event.flags.contains(.maskControl) else {
            return Unmanaged.passRetained(event)
        }

        var chars = [UniChar](repeating: 0, count: 4)
        var length = 0
        event.keyboardGetUnicodeString(
            maxStringLength: 4,
            actualStringLength: &length,
            unicodeString: &chars
        )

        guard length > 0, isHangul(chars[0]) else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard let ascii = keyCodeToLowerASCII[keyCode] else {
            return Unmanaged.passRetained(event)
        }

        // Ctrl 문자로 변환 (예: 'b' & 0x1F = 0x02 = Ctrl+B)
        var ctrl = UniChar(ascii & 0x1F)
        event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ctrl)

        statisticsManager.recordRemap()

        return Unmanaged.passRetained(event)
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
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
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
    case .keyDown:
        return manager.handleKeyEvent(event)
    default:
        return Unmanaged.passRetained(event)
    }
}
