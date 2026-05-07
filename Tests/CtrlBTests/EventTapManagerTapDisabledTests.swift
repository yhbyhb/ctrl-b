import XCTest
@testable import CtrlB

final class EventTapManagerTapDisabledTests: XCTestCase {
    // MARK: - userInput recovery

    func test_tapDisabled_userInputRecoverySuccess_staysEnabled() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeEventTapManagerSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()

        sut.handleTapDisabled(type: .tapDisabledByUserInput)

        XCTAssertEqual(sut.state, .enabled)
        XCTAssertEqual(engine.setEnabledCalls, [true, true])
        XCTAssertEqual(engine.stopCallCount, 0)
        XCTAssertEqual(engine.startCallCount, 1)
    }

    // MARK: - timeout recovery

    func test_tapDisabled_timeoutRecovery_recreatesTapAndStaysEnabled() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeEventTapManagerSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()

        sut.handleTapDisabled(type: .tapDisabledByTimeout)

        // The CFMachPort is invalidated by macOS on timeout, so the manager
        // must tear down and re-create the tap rather than re-enable it in place.
        XCTAssertEqual(sut.state, .enabled)
        XCTAssertEqual(engine.stopCallCount, 1)
        XCTAssertEqual(engine.startCallCount, 2)
        XCTAssertEqual(engine.setEnabledCalls, [true, true])
    }

    func test_tapDisabled_timeoutRecovery_whenStartFails_becomesUnavailable() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeEventTapManagerSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()
        engine.startResult = false  // recovery start will fail

        sut.handleTapDisabled(type: .tapDisabledByTimeout)

        XCTAssertEqual(sut.state, .unavailable)
        XCTAssertEqual(engine.stopCallCount, 1)
        XCTAssertEqual(engine.startCallCount, 2)
    }

    // MARK: - guard against re-enabling when not in .enabled

    func test_handleTapDisabled_whenPaused_doesNotReEnable() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeEventTapManagerSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()
        sut.toggle()  // -> .paused
        let setEnabledCountBefore = engine.setEnabledCalls.count

        sut.handleTapDisabled(type: .tapDisabledByUserInput)

        XCTAssertEqual(sut.state, .paused)
        XCTAssertEqual(engine.setEnabledCalls.count, setEnabledCountBefore)
    }

    func test_handleTapDisabled_whenPermissionRequired_doesNotReEnable() {
        let permission = MockPermissionController(isTrusted: false)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeEventTapManagerSUT(permission: permission, engine: engine)
        // state is .permissionRequired

        sut.handleTapDisabled(type: .tapDisabledByUserInput)

        XCTAssertEqual(sut.state, .permissionRequired)
        XCTAssertTrue(engine.setEnabledCalls.isEmpty)
    }
}
