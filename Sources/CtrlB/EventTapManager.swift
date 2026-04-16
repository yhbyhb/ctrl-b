import Cocoa
import CoreGraphics
import CtrlBCore
import os

private let log = Logger(subsystem: "com.yhbyhb.CtrlB", category: "EventTap")

final class EventTapManager {
    /// Sentinel value for identifying synthetic events ("CBHRMAP" in ASCII)
    private static let sentinel: Int64 = 0x4342_4852_4D4150
    private let targetModifiers: CGEventFlags = [.maskControl]

    private let statisticsManager: StatisticsManager
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private let prefixKeyCode: Int64 = 11  // Ctrl+b (configurable in the future)
    private var pendingFollowUp = false
    private var followUpTimer: DispatchWorkItem?
    private let followUpTimeout: TimeInterval = 1.5

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

    /// Remaps the next key after a prefix key remap (IME → ASCII)
    private func handleFollowUp(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        pendingFollowUp = false
        followUpTimer?.cancel()
        followUpTimer = nil

        let followUpKeyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let hasNoModifiers = event.flags.isDisjoint(with: [.maskControl, .maskCommand, .maskAlternate])

        guard hasNoModifiers,
              let ascii = keyCodeToLowerASCII[followUpKeyCode],
              isInputMethodActive() else {
            log.debug("Follow-up dismissed: keyCode=\(followUpKeyCode) hasNoModifiers=\(hasNoModifiers)")
            return Unmanaged.passRetained(event)
        }

        guard let source = CGEventSource(stateID: .hidSystemState),
              let newEvent = CGEvent(keyboardEventSource: source,
                                     virtualKey: CGKeyCode(followUpKeyCode),
                                     keyDown: true) else {
            return Unmanaged.passRetained(event)
        }

        newEvent.flags = event.flags
        newEvent.setIntegerValueField(.eventSourceUserData, value: Self.sentinel)

        var asciiChar = UniChar(ascii)
        newEvent.keyboardSetUnicodeString(stringLength: 1, unicodeString: &asciiChar)

        log.debug("FOLLOW-UP REMAP: keyCode=\(followUpKeyCode) → '\(Character(UnicodeScalar(ascii)))'")

        newEvent.post(tap: .cghidEventTap)
        statisticsManager.recordRemap()

        return nil
    }

    fileprivate func handleKeyEvent(_ event: CGEvent, type: CGEventType) -> Unmanaged<CGEvent>? {
        // Pass through synthetic events (prevent infinite loop)
        if event.getIntegerValueField(.eventSourceUserData) == Self.sentinel {
            return Unmanaged.passRetained(event)
        }

        // Follow-up check (next key after prefix remap)
        if pendingFollowUp && type == .keyDown {
            return handleFollowUp(event)
        }

        // Check target modifier (currently: Ctrl)
        guard !event.flags.isDisjoint(with: targetModifiers) else {
            return Unmanaged.passRetained(event)
        }

        // Check target keyCode (a-z alphabet keys only)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCodeToLowerASCII[keyCode] != nil else {
            return Unmanaged.passRetained(event)
        }

        // Check if IME input source is active
        guard isInputMethodActive() else {
            return Unmanaged.passRetained(event)
        }

        // Discard original + create synthetic event
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

        // Record statistics on keyDown only
        if type == .keyDown {
            statisticsManager.recordRemap()

            // Arm follow-up when prefix key (Ctrl+b) is remapped
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

        return nil  // discard original
    }

    private func showAccessibilityAlert() {
        let localized = { (key: String) in NSLocalizedString(key, bundle: .module, comment: "") }
        let alert = NSAlert()
        alert.messageText = localized("alert.accessibility.title")
        alert.informativeText = localized("alert.accessibility.message")
        alert.addButton(withTitle: localized("alert.accessibility.open"))
        alert.addButton(withTitle: localized("alert.accessibility.later"))
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - C callback (CGEventTap callback must be a global function)

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
