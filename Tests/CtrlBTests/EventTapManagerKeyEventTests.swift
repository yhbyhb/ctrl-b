import XCTest
import CoreGraphics
@testable import CtrlB
@testable import CtrlBCore

final class EventTapManagerKeyEventTests: XCTestCase {
    // keyCode 11 == 'b' (the prefix key)
    private let keyCodeB: CGKeyCode = 11

    // MARK: - keyDown remap

    func test_handleKeyDown_whenIMEActiveAndCtrlHeld_isRemappedAndTracked() {
        let imeActive = MutableBool(true)
        let sut = makeSUT(imeActive: imeActive)
        let keyDown = makeKeyEvent(keyCode: keyCodeB, keyDown: true, flags: .maskControl)

        let consumed = sut.debugHandleKeyEventForTests(keyDown, type: .keyDown)

        XCTAssertTrue(consumed, "Ctrl+b keyDown with IME active must be discarded")
        XCTAssertEqual(sut.debugTrackedRemappedKeyCodesForTests(), [Int64(keyCodeB)])
    }

    func test_handleKeyDown_whenIMEInactive_passesThrough() {
        let imeActive = MutableBool(false)
        let sut = makeSUT(imeActive: imeActive)
        let keyDown = makeKeyEvent(keyCode: keyCodeB, keyDown: true, flags: .maskControl)

        let consumed = sut.debugHandleKeyEventForTests(keyDown, type: .keyDown)

        XCTAssertFalse(consumed)
        XCTAssertTrue(sut.debugTrackedRemappedKeyCodesForTests().isEmpty)
    }

    func test_handleKeyDown_withoutCtrl_passesThrough() {
        let imeActive = MutableBool(true)
        let sut = makeSUT(imeActive: imeActive)
        let keyDown = makeKeyEvent(keyCode: keyCodeB, keyDown: true, flags: [])

        let consumed = sut.debugHandleKeyEventForTests(keyDown, type: .keyDown)

        XCTAssertFalse(consumed)
        XCTAssertTrue(sut.debugTrackedRemappedKeyCodesForTests().isEmpty)
    }

    // MARK: - keyUp pairing

    func test_handleKeyUp_whenKeyDownWasRemapped_keyUpIsAlsoRemapped() {
        let imeActive = MutableBool(true)
        let sut = makeSUT(imeActive: imeActive)
        let keyDown = makeKeyEvent(keyCode: keyCodeB, keyDown: true, flags: .maskControl)
        _ = sut.debugHandleKeyEventForTests(keyDown, type: .keyDown)

        let keyUp = makeKeyEvent(keyCode: keyCodeB, keyDown: false, flags: .maskControl)
        let consumed = sut.debugHandleKeyEventForTests(keyUp, type: .keyUp)

        XCTAssertTrue(consumed, "keyUp matching a remapped keyDown must be remapped to keep the synthetic pair balanced")
        XCTAssertTrue(sut.debugTrackedRemappedKeyCodesForTests().isEmpty,
                      "tracking set must be cleared after the matching keyUp")
    }

    func test_handleKeyUp_whenIMEDeactivatesAfterKeyDown_keyUpStillRemapped() {
        // Reproduces the original bug: IME state is queried per-event, so a
        // toggle between keyDown and keyUp would orphan the synthetic keyDown.
        let imeActive = MutableBool(true)
        let sut = makeSUT(imeActive: imeActive)
        let keyDown = makeKeyEvent(keyCode: keyCodeB, keyDown: true, flags: .maskControl)
        _ = sut.debugHandleKeyEventForTests(keyDown, type: .keyDown)

        // User toggles the IME off mid-press.
        imeActive.value = false

        let keyUp = makeKeyEvent(keyCode: keyCodeB, keyDown: false, flags: .maskControl)
        let consumed = sut.debugHandleKeyEventForTests(keyUp, type: .keyUp)

        XCTAssertTrue(consumed, "keyUp must mirror the keyDown decision regardless of current IME state")
        XCTAssertTrue(sut.debugTrackedRemappedKeyCodesForTests().isEmpty)
    }

    func test_handleKeyUp_withoutPriorRemap_passesThrough() {
        let imeActive = MutableBool(true)
        let sut = makeSUT(imeActive: imeActive)
        let keyUp = makeKeyEvent(keyCode: keyCodeB, keyDown: false, flags: .maskControl)

        let consumed = sut.debugHandleKeyEventForTests(keyUp, type: .keyUp)

        XCTAssertFalse(consumed, "Stray keyUp without a tracked keyDown must pass through")
    }

    // MARK: - Helpers

    private func makeSUT(imeActive: MutableBool) -> EventTapManager {
        EventTapManager(
            statisticsManager: StatisticsManager(defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard),
            permissionController: KeyEventStubPermissionController(),
            eventTapEngine: KeyEventStubEventTapEngine(),
            isIMEActive: { imeActive.value }
        )
    }

    private func makeKeyEvent(keyCode: CGKeyCode, keyDown: Bool, flags: CGEventFlags) -> CGEvent {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else {
            fatalError("Unable to create CGEvent in test")
        }
        event.flags = flags
        return event
    }
}

private final class MutableBool {
    var value: Bool
    init(_ value: Bool) { self.value = value }
}

private final class KeyEventStubPermissionController: AccessibilityPermissionControlling {
    func promptIfNeededOnFirstLaunch() -> Bool { true }
    func isTrusted() -> Bool { true }
    func openSettings() {}
}

private final class KeyEventStubEventTapEngine: EventTapEngineControlling {
    var isActive = false
    func start(userInfo: UnsafeMutableRawPointer?) -> Bool { true }
    func setEnabled(_ isEnabled: Bool) {}
    func stop() {}
}
