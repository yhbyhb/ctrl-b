import XCTest
import AppKit
@testable import CtrlB
@testable import CtrlBCore

final class AppDelegateTests: XCTestCase {
    func test_launch_withTrustedPermission_startsEventTapWithoutMonitoring() {
        let permission = AppDelegateMockPermissionController(isTrusted: true)
        let observer = MockAccessibilityPermissionObserver()
        let repeatingFactory = MockRepeatingTaskFactory()
        let eventTap = MockEventTapController(checkAgainResults: [.enabled])
        var activationPolicies: [NSApplication.ActivationPolicy] = []

        let sut = makeSUT(
            permission: permission,
            observer: observer,
            repeatingFactory: repeatingFactory,
            activationPolicySetter: { activationPolicies.append($0) },
            eventTap: eventTap
        )

        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        XCTAssertEqual(activationPolicies, [.accessory])
        XCTAssertEqual(permission.promptIfNeededOnFirstLaunchCallCount, 1)
        XCTAssertEqual(eventTap.startReasons, [.launch])
        XCTAssertEqual(eventTap.checkAgainCallCount, 0)
        XCTAssertEqual(observer.startObservingCallCount, 1)
        XCTAssertEqual(repeatingFactory.createdTasks.count, 2)
        XCTAssertEqual(repeatingFactory.createdTasks.first?.interval, PermissionPollingPolicy.activeInterval)
        XCTAssertEqual(repeatingFactory.createdTasks.last?.interval, PermissionPollingPolicy.passiveInterval)
        XCTAssertEqual(repeatingFactory.createdTasks.first?.cancelCallCount, 1)
    }

    func test_launch_withoutTrustedPermission_checksAgainAndStartsMonitoring() {
        let permission = AppDelegateMockPermissionController(isTrusted: false)
        let observer = MockAccessibilityPermissionObserver()
        let repeatingFactory = MockRepeatingTaskFactory()
        let eventTap = MockEventTapController(checkAgainResults: [.permissionRequired])

        let sut = makeSUT(
            permission: permission,
            observer: observer,
            repeatingFactory: repeatingFactory,
            activationPolicySetter: { _ in },
            eventTap: eventTap
        )

        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        XCTAssertEqual(eventTap.startReasons, [])
        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 1)
        XCTAssertEqual(observer.startObservingCallCount, 1)
        XCTAssertEqual(repeatingFactory.createdTasks.count, 1)
        XCTAssertEqual(repeatingFactory.createdTasks.last?.interval, PermissionPollingPolicy.activeInterval)
    }

    func test_pollingRecovery_successStopsMonitoring() {
        let permission = AppDelegateMockPermissionController(isTrusted: false)
        let observer = MockAccessibilityPermissionObserver()
        let repeatingFactory = MockRepeatingTaskFactory()
        let eventTap = MockEventTapController(checkAgainResults: [.permissionRequired, .enabled])

        let sut = makeSUT(
            permission: permission,
            observer: observer,
            repeatingFactory: repeatingFactory,
            activationPolicySetter: { _ in },
            eventTap: eventTap
        )
        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        repeatingFactory.createdTasks.first?.fire()

        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 2)
        XCTAssertEqual(observer.stopObservingCallCount, 0)
        XCTAssertEqual(repeatingFactory.createdTasks.first?.cancelCallCount, 1)
        XCTAssertEqual(repeatingFactory.createdTasks.last?.interval, PermissionPollingPolicy.passiveInterval)
    }

    func test_delayedRecovery_doesNotRunAfterMonitoringStops() {
        let permission = AppDelegateMockPermissionController(isTrusted: false)
        let observer = MockAccessibilityPermissionObserver()
        let repeatingFactory = MockRepeatingTaskFactory()
        let eventTap = MockEventTapController(checkAgainResults: [.permissionRequired, .enabled])

        let sut = makeSUT(
            permission: permission,
            observer: observer,
            repeatingFactory: repeatingFactory,
            activationPolicySetter: { _ in },
            eventTap: eventTap
        )
        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        observer.handler?()
        repeatingFactory.createdTasks.first?.fire()
        sut.applicationWillTerminate(Notification(name: Notification.Name("terminate")))
        observer.handler?()

        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 2)
        XCTAssertEqual(observer.stopObservingCallCount, 1)
    }

    func test_pollingRecovery_failureKeepsMonitoring() {
        let permission = AppDelegateMockPermissionController(isTrusted: false)
        let observer = MockAccessibilityPermissionObserver()
        let repeatingFactory = MockRepeatingTaskFactory()
        let eventTap = MockEventTapController(checkAgainResults: [.permissionRequired, .unavailable])

        let sut = makeSUT(
            permission: permission,
            observer: observer,
            repeatingFactory: repeatingFactory,
            activationPolicySetter: { _ in },
            eventTap: eventTap
        )
        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        repeatingFactory.createdTasks.first?.fire()

        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 2)
        XCTAssertEqual(observer.stopObservingCallCount, 0)
        XCTAssertEqual(repeatingFactory.createdTasks.first?.cancelCallCount, 0)
        XCTAssertEqual(repeatingFactory.createdTasks.last?.interval, PermissionPollingPolicy.activeInterval)
    }

    func test_pollingSync_updatesStateWithoutMenuInteraction() {
        let permission = AppDelegateMockPermissionController(isTrusted: false)
        let observer = MockAccessibilityPermissionObserver()
        let repeatingFactory = MockRepeatingTaskFactory()
        let eventTap = MockEventTapController(
            checkAgainResults: [.permissionRequired],
            syncResults: [.permissionRequired, .enabled]
        )

        let sut = makeSUT(
            permission: permission,
            observer: observer,
            repeatingFactory: repeatingFactory,
            activationPolicySetter: { _ in },
            eventTap: eventTap
        )
        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        repeatingFactory.createdTasks.first?.fire()

        XCTAssertEqual(eventTap.syncPermissionStateCallCount, 2)
        XCTAssertEqual(eventTap.state, .enabled)
        XCTAssertEqual(repeatingFactory.createdTasks.last?.interval, PermissionPollingPolicy.passiveInterval)
    }

    func test_pollingSync_whenPermissionRevoked_movesBackToActiveInterval() {
        let permission = AppDelegateMockPermissionController(isTrusted: true)
        let observer = MockAccessibilityPermissionObserver()
        let repeatingFactory = MockRepeatingTaskFactory()
        let eventTap = MockEventTapController(
            checkAgainResults: [.enabled],
            syncResults: [.permissionRequired]
        )

        let sut = makeSUT(
            permission: permission,
            observer: observer,
            repeatingFactory: repeatingFactory,
            activationPolicySetter: { _ in },
            eventTap: eventTap
        )
        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        repeatingFactory.createdTasks.last?.fire()

        XCTAssertEqual(repeatingFactory.createdTasks.last?.interval, PermissionPollingPolicy.activeInterval)
    }

    func test_applicationWillTerminate_stopsMonitoringAndEventTap() {
        let permission = AppDelegateMockPermissionController(isTrusted: false)
        let observer = MockAccessibilityPermissionObserver()
        let repeatingFactory = MockRepeatingTaskFactory()
        let eventTap = MockEventTapController(checkAgainResults: [.permissionRequired])
        let statusBar = MockStatusBarController()

        let sut = makeSUT(
            permission: permission,
            observer: observer,
            repeatingFactory: repeatingFactory,
            activationPolicySetter: { _ in },
            eventTap: eventTap,
            statusBar: statusBar
        )
        sut.applicationDidFinishLaunching(Notification(name: Notification.Name("test")))

        sut.applicationWillTerminate(Notification(name: Notification.Name("terminate")))

        XCTAssertEqual(observer.stopObservingCallCount, 1)
        XCTAssertEqual(repeatingFactory.createdTasks.first?.cancelCallCount, 1)
        XCTAssertEqual(eventTap.shutdownCallCount, 1)
        XCTAssertEqual(statusBar.stopCallCount, 1)
    }

    private func makeSUT(
        permission: AppDelegateMockPermissionController,
        observer: MockAccessibilityPermissionObserver,
        repeatingFactory: MockRepeatingTaskFactory,
        activationPolicySetter: @escaping (NSApplication.ActivationPolicy) -> Void,
        eventTap: MockEventTapController,
        statusBar: MockStatusBarController = MockStatusBarController()
    ) -> AppDelegate {
        AppDelegate(
            permissionController: permission,
            permissionObserver: observer,
            repeatingTaskFactory: repeatingFactory.makeTask,
            activationPolicySetter: activationPolicySetter,
            statisticsFactory: { StatisticsManager(defaults: makeAppDelegateTestDefaults()) },
            eventTapFactory: { _, _ in eventTap },
            statusBarFactory: { _, _, _, _, _ in statusBar },
            updateCheckerFactory: { MockUpdateChecker() }
        )
    }
}

private func makeAppDelegateTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString) ?? .standard
}

private final class MockEventTapController: EventTapControlling {
    var state: EventTapState = .permissionRequired
    var onStateChange: ((EventTapState) -> Void)?
    let isAwaitingFollowUp = false
    private(set) var startReasons: [EventTapStateChangeReason] = []
    private(set) var checkAgainCallCount = 0
    private(set) var refreshPermissionStateCallCount = 0
    private(set) var syncPermissionStateCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var shutdownCallCount = 0
    private let checkAgainResults: [EventTapState]
    private let syncResults: [EventTapState]
    private var currentCheckAgainIndex = 0
    private var currentSyncIndex = 0

    init(checkAgainResults: [EventTapState], syncResults: [EventTapState]? = nil) {
        self.checkAgainResults = checkAgainResults
        self.syncResults = syncResults ?? checkAgainResults
    }

    func start(reason: EventTapStateChangeReason) {
        startReasons.append(reason)
        state = .enabled
        onStateChange?(.enabled)
    }

    func checkAgain() -> EventTapState {
        checkAgainCallCount += 1
        let result = currentCheckAgainIndex < checkAgainResults.count
            ? checkAgainResults[currentCheckAgainIndex]
            : checkAgainResults.last ?? .permissionRequired
        currentCheckAgainIndex += 1
        state = result
        onStateChange?(result)
        return result
    }

    func refreshPermissionState() -> EventTapState {
        refreshPermissionStateCallCount += 1
        return state
    }

    func syncPermissionState() -> EventTapState {
        syncPermissionStateCallCount += 1
        let result = currentSyncIndex < syncResults.count
            ? syncResults[currentSyncIndex]
            : syncResults.last ?? state
        currentSyncIndex += 1
        state = result
        onStateChange?(result)
        return result
    }

    func pause() {
        pauseCallCount += 1
    }

    func shutdown() {
        shutdownCallCount += 1
    }

    func toggle() {}

    func openAccessibilitySettings() {}
}

private final class AppDelegateMockPermissionController: AccessibilityPermissionControlling {
    var isTrustedValue: Bool
    private(set) var promptIfNeededOnFirstLaunchCallCount = 0

    init(isTrusted: Bool) {
        self.isTrustedValue = isTrusted
    }

    func promptIfNeededOnFirstLaunch() -> Bool {
        promptIfNeededOnFirstLaunchCallCount += 1
        return isTrustedValue
    }

    func isTrusted() -> Bool {
        isTrustedValue
    }

    func openSettings() {}
}

private final class MockAccessibilityPermissionObserver: AccessibilityPermissionObserving {
    private(set) var startObservingCallCount = 0
    private(set) var stopObservingCallCount = 0
    var handler: (() -> Void)?

    func startObserving(handler: @escaping () -> Void) {
        startObservingCallCount += 1
        self.handler = handler
    }

    func stopObserving() {
        stopObservingCallCount += 1
        handler = nil
    }
}

private final class MockRepeatingTask: RepeatingTask {
    let interval: TimeInterval
    var handler: (() -> Void)?
    private(set) var cancelCallCount = 0

    init(interval: TimeInterval) {
        self.interval = interval
    }

    func fire() {
        handler?()
    }

    func cancel() {
        cancelCallCount += 1
    }
}

private final class MockStatusBarController: StatusBarControlling {
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    func start() { startCallCount += 1 }
    func stop() { stopCallCount += 1 }
}

private final class MockRepeatingTaskFactory {
    private(set) var createdTasks: [MockRepeatingTask] = []

    func makeTask(interval: TimeInterval, handler: @escaping () -> Void) -> RepeatingTask {
        let task = MockRepeatingTask(interval: interval)
        task.handler = handler
        createdTasks.append(task)
        return task
    }
}

private final class MockUpdateChecker: UpdateChecking {
    var result: UpdateResult = .unknown
    private(set) var checkInBackgroundCallCount = 0
    func checkInBackground() { checkInBackgroundCallCount += 1 }
}
