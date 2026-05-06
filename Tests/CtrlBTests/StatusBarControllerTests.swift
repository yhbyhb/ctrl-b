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
        let sut = makeSUT(eventTap: eventTap)

        sut.menuWillOpen(NSMenu())

        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 1)
        XCTAssertEqual(eventTap.refreshPermissionStateCallCount, 0)
        XCTAssertEqual(eventTap.checkAgainCallCount, 0)
    }

    func test_init_wiresOnStateChangeCallback() {
        let eventTap = MockStatusEventTapController(state: .enabled, refreshResult: .enabled)
        XCTAssertNil(eventTap.onStateChange)

        _ = makeSUT(eventTap: eventTap)

        XCTAssertNotNil(eventTap.onStateChange)
    }

    func test_menuWillOpen_doesNotCheckAgainWhenEnabled() {
        let eventTap = MockStatusEventTapController(
            state: .enabled,
            refreshResult: .enabled
        )
        let sut = makeSUT(eventTap: eventTap)

        sut.menuWillOpen(NSMenu())

        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 1)
        XCTAssertEqual(eventTap.refreshPermissionStateCallCount, 0)
        XCTAssertEqual(eventTap.checkAgainCallCount, 0)
    }

    func test_start_samplesSecureInputAndSchedulesPolling() {
        let monitor = MockSecureInputMonitor(initialState: false)
        let factory = MockRepeatingTaskFactory()
        let sut = makeSUT(secureInputMonitor: monitor, taskFactory: factory)

        sut.start()

        XCTAssertEqual(monitor.isActiveCallCount, 1)
        XCTAssertEqual(factory.lastInterval, SecureInputPollingPolicy.interval)
        XCTAssertNotNil(factory.lastHandler)
        XCTAssertFalse(sut.debugSecureInputActive)
    }

    func test_secureInputBecomesActive_updatesInternalState() {
        let monitor = MockSecureInputMonitor(initialState: false)
        let factory = MockRepeatingTaskFactory()
        let sut = makeSUT(secureInputMonitor: monitor, taskFactory: factory)
        sut.start()

        monitor.currentState = true
        factory.lastHandler?()

        XCTAssertTrue(sut.debugSecureInputActive)
    }

    func test_secureInputUnchanged_noRedundantWork() {
        let monitor = MockSecureInputMonitor(initialState: true)
        let factory = MockRepeatingTaskFactory()
        let sut = makeSUT(secureInputMonitor: monitor, taskFactory: factory)
        sut.start()
        let baselineCount = monitor.isActiveCallCount

        factory.lastHandler?()
        factory.lastHandler?()

        XCTAssertTrue(sut.debugSecureInputActive)
        XCTAssertEqual(monitor.isActiveCallCount, baselineCount + 2,
                       "Each poll samples the monitor exactly once")
    }

    func test_stop_cancelsPollingTask() {
        let factory = MockRepeatingTaskFactory()
        let sut = makeSUT(taskFactory: factory)
        sut.start()
        XCTAssertEqual(factory.lastTask?.cancelCallCount, 0)

        sut.stop()

        XCTAssertEqual(factory.lastTask?.cancelCallCount, 1)
    }
}

// MARK: - Test fixtures

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

private final class MockSecureInputMonitor: SecureInputMonitoring {
    var currentState: Bool
    private(set) var isActiveCallCount = 0

    init(initialState: Bool) { self.currentState = initialState }

    func isActive() -> Bool {
        isActiveCallCount += 1
        return currentState
    }
}

private final class MockRepeatingTask: RepeatingTask {
    private(set) var cancelCallCount = 0
    func cancel() { cancelCallCount += 1 }
}

private final class MockRepeatingTaskFactory {
    private(set) var lastInterval: TimeInterval?
    private(set) var lastHandler: (() -> Void)?
    private(set) var lastTask: MockRepeatingTask?

    func make(_ interval: TimeInterval, _ handler: @escaping () -> Void) -> RepeatingTask {
        lastInterval = interval
        lastHandler = handler
        let task = MockRepeatingTask()
        lastTask = task
        return task
    }
}

private func makeSUT(
    eventTap: MockStatusEventTapController = MockStatusEventTapController(
        state: .enabled, refreshResult: .enabled
    ),
    secureInputMonitor: SecureInputMonitoring = MockSecureInputMonitor(initialState: false),
    updateChecker: UpdateChecking = MockUpdateChecker(),
    taskFactory: MockRepeatingTaskFactory = MockRepeatingTaskFactory()
) -> StatusBarController {
    StatusBarController(
        eventTap: eventTap,
        stats: StatisticsManager(defaults: makeStatusBarTestDefaults()),
        secureInputMonitor: secureInputMonitor,
        updateChecker: updateChecker,
        repeatingTaskFactory: taskFactory.make
    )
}

private func makeStatusBarTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString) ?? .standard
}

private final class MockUpdateChecker: UpdateChecking {
    var result: UpdateResult = .unknown
    private(set) var checkInBackgroundCallCount = 0
    func checkInBackground() { checkInBackgroundCallCount += 1 }
}
