import Cocoa
import CoreGraphics
import CtrlBCore
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b", category: "EventTap")

final class EventTapManager: EventTapControlling {
    /// Sentinel value for identifying synthetic events ("CBHRMAP" in ASCII)
    private static let sentinel: Int64 = 0x4342_4852_4D4150
    private let targetModifiers: CGEventFlags = [.maskControl]

    private let statisticsManager: StatisticsManager
    private let permissionController: AccessibilityPermissionControlling
    private let eventTapEngine: EventTapEngineControlling

    private let prefixKeyCode: Int64 = 11  // Ctrl+b (configurable in the future)
    private var pendingFollowUp = false
    private var followUpTimer: DispatchWorkItem?
    private let followUpTimeout: TimeInterval = 1.5

    private(set) var state: EventTapState = .permissionRequired {
        didSet {
            guard oldValue != state else { return }
            onStateChange?(state)
        }
    }
    var onStateChange: ((EventTapState) -> Void)?
    var isAwaitingFollowUp: Bool { pendingFollowUp }

    init(
        statisticsManager: StatisticsManager,
        permissionController: AccessibilityPermissionControlling = AccessibilityPermissionController(),
        eventTapEngine: EventTapEngineControlling = EventTapEngine()
    ) {
        self.statisticsManager = statisticsManager
        self.permissionController = permissionController
        self.eventTapEngine = eventTapEngine
    }

    func start(reason: EventTapStateChangeReason = .launch) {
        _ = attemptToEnable(reason: reason)
    }

    func pause() {
        eventTapEngine.stop()
        transition(to: .paused, reason: .userPaused)
    }

    func shutdown() {
        eventTapEngine.stop()
        pendingFollowUp = false
        followUpTimer?.cancel()
        followUpTimer = nil
    }

    func toggle() {
        switch state {
        case .enabled:
            eventTapEngine.setEnabled(false)
            transition(to: .paused, reason: .userPaused)
        case .paused:
            _ = attemptToEnable(reason: .userResumed)
        case .permissionRequired, .unavailable:
            _ = checkAgain()
        }
    }

    @discardableResult
    func checkAgain() -> EventTapState {
        attemptToEnable(reason: .checkAgainRequested)
    }

    @discardableResult
    func refreshPermissionState() -> EventTapState {
        let trusted = permissionController.isTrusted()
        log.info("Accessibility trusted refresh: \(trusted ? "YES" : "NO")")

        guard trusted else {
            if state == .enabled || state == .paused {
                shutdown()
            }
            transition(to: .permissionRequired, reason: .permissionMissing)
            return state
        }

        return state
    }

    @discardableResult
    func syncPermissionState() -> EventTapState {
        let refreshedState = refreshPermissionState()

        switch refreshedState {
        case .permissionRequired, .unavailable:
            return checkAgain()
        case .enabled, .paused:
            return refreshedState
        }
    }

    func openAccessibilitySettings() {
        permissionController.openSettings()
    }

    #if DEBUG
    func debugSetAwaitingFollowUpForTests(_ isAwaiting: Bool) {
        pendingFollowUp = isAwaiting
    }
    #endif

    // MARK: - Private

    func handleTapDisabled(type: CGEventType) {
        guard state == .enabled else { return }

        let reason: EventTapStateChangeReason = switch type {
        case .tapDisabledByUserInput:
            .tapDisabledByUserInput
        default:
            .tapDisabledByTimeout
        }
        eventTapEngine.setEnabled(true)
        transition(to: .enabled, reason: reason)
    }

    private func attemptToEnable(reason: EventTapStateChangeReason) -> EventTapState {
        let trusted = permissionController.isTrusted()
        log.info("Accessibility trusted: \(trusted ? "YES" : "NO")")

        guard trusted else {
            transition(to: .permissionRequired, reason: reason == .initialPromptShown ? .initialPromptShown : .permissionMissing)
            return state
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        guard eventTapEngine.start(userInfo: selfPtr) else {
            transition(to: .unavailable, reason: .tapCreateFailed)
            return state
        }

        eventTapEngine.setEnabled(true)
        transition(to: .enabled, reason: reason == .checkAgainRequested ? .checkAgainRequested : .permissionGranted)
        return state
    }

    private func transition(to newState: EventTapState, reason: EventTapStateChangeReason) {
        log.info("state transition: \(String(describing: self.state)) -> \(String(describing: newState)) reason=\(reason.rawValue)")
        state = newState
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

}

// MARK: - C callback (CGEventTap callback must be a global function)

func tapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<EventTapManager>.fromOpaque(userInfo).takeUnretainedValue()

    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        manager.handleTapDisabled(type: type)
        return Unmanaged.passRetained(event)
    case .keyDown, .keyUp:
        return manager.handleKeyEvent(event, type: type)
    default:
        return Unmanaged.passRetained(event)
    }
}
