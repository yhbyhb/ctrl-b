import XCTest
import AppKit
@testable import CtrlB
@testable import CtrlBCore

final class StatusBarControllerTests: XCTestCase {
    func test_menuWillOpen_refreshesPermissionStateForPermissionRequired() {
        let eventTap = MockStatusEventTapController(
            state: .permissionRequired,
            refreshResult: .permissionRequired
        )
        let sut = StatusBarController(
            eventTap: eventTap,
            stats: StatisticsManager(defaults: makeStatusBarTestDefaults())
        )

        sut.menuWillOpen(NSMenu())

        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 1)
        XCTAssertEqual(eventTap.refreshPermissionStateCallCount, 0)
        XCTAssertEqual(eventTap.checkAgainCallCount, 0)
    }

    func test_menuWillOpen_doesNotCheckAgainWhenEnabled() {
        let eventTap = MockStatusEventTapController(
            state: .enabled,
            refreshResult: .enabled
        )
        let sut = StatusBarController(
            eventTap: eventTap,
            stats: StatisticsManager(defaults: makeStatusBarTestDefaults())
        )

        sut.menuWillOpen(NSMenu())

        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 1)
        XCTAssertEqual(eventTap.refreshPermissionStateCallCount, 0)
        XCTAssertEqual(eventTap.checkAgainCallCount, 0)
    }
}

private final class MockStatusEventTapController: EventTapControlling {
    var state: EventTapState
    var onStateChange: ((EventTapState) -> Void)?
    let isAwaitingFollowUp = false
    private let refreshResult: EventTapState
    private(set) var checkAgainCallCount = 0
    private(set) var refreshPermissionStateCallCount = 0
    private(set) var syncPermissionStateCallCount = 0

    init(state: EventTapState, refreshResult: EventTapState) {
        self.state = state
        self.refreshResult = refreshResult
    }

    func start(reason: EventTapStateChangeReason) {}

    func checkAgain() -> EventTapState {
        checkAgainCallCount += 1
        state = refreshResult
        return state
    }

    func refreshPermissionState() -> EventTapState {
        refreshPermissionStateCallCount += 1
        state = refreshResult
        return state
    }

    func syncPermissionState() -> EventTapState {
        syncPermissionStateCallCount += 1
        state = refreshResult
        return state
    }

    func pause() {}

    func shutdown() {}

    func toggle() {}

    func openAccessibilitySettings() {}
}

private func makeStatusBarTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString) ?? .standard
}
