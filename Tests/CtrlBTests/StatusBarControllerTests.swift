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

    func test_start_calledTwice_doesNotLeakPollingTask() {
        let factory = MockRepeatingTaskFactory()
        let sut = makeSUT(taskFactory: factory)
        sut.start()
        let firstTask = factory.lastTask

        sut.start()

        XCTAssertEqual(firstTask?.cancelCallCount, 1,
                       "Re-entering start() must cancel the previous polling task")
    }

    func test_menu_alwaysShowsCheckForUpdatesEntry_regardlessOfState() throws {
        // Sparkle-style: the menu entry is always "Check for Updates…" so the
        // menu does not communicate update state — the dialog does.
        for state in [UpdateResult.unknown, .upToDate, .available(latestVersion: "9.9.9")] {
            let updateChecker = MockUpdateChecker()
            updateChecker.result = state
            let sut = makeSUT(updateChecker: updateChecker)
            let menu = NSMenu()

            sut.menuWillOpen(menu)
            let item = try XCTUnwrap(findMenuItem(in: menu, titleContains: "Check for Updates"),
                                      "Expected 'Check for Updates' item for state \(state)")
            XCTAssertNil(findMenuItem(in: menu, titleContains: "9.9.9"),
                         "Menu must not surface the available version directly")
            XCTAssertEqual(item.action?.description, "checkForUpdates")
        }
    }

    func test_checkForUpdates_whenUpToDate_presentsResultThroughInjectedPresenter() {
        let updateChecker = MockUpdateChecker()
        updateChecker.result = .upToDate
        var presentedResult: UpdateResult?
        let sut = makeSUT(updateChecker: updateChecker, updateResultPresenter: { result, _ in
            presentedResult = result
        })
        let menu = NSMenu()

        sut.menuWillOpen(menu)
        invoke(findMenuItem(in: menu, titleContains: "Check for Updates"))

        XCTAssertEqual(updateChecker.checkInBackgroundCallCount, 1)
        guard case .upToDate = presentedResult else {
            return XCTFail("Expected presenter to be called with .upToDate, got \(String(describing: presentedResult))")
        }
    }

    func test_checkForUpdates_whenAvailable_presentsResultAndCanInvokeDownload() {
        let updateChecker = MockUpdateChecker()
        updateChecker.result = .available(latestVersion: "9.9.9")
        var capturedDownload: (() -> Void)?
        var presentedResult: UpdateResult?
        let sut = makeSUT(updateChecker: updateChecker, updateResultPresenter: { result, onDownload in
            presentedResult = result
            capturedDownload = onDownload
        })
        let menu = NSMenu()

        sut.menuWillOpen(menu)
        invoke(findMenuItem(in: menu, titleContains: "Check for Updates"))

        guard case .available(let version) = presentedResult else {
            return XCTFail("Expected .available, got \(String(describing: presentedResult))")
        }
        XCTAssertEqual(version, "9.9.9")
        XCTAssertNotNil(capturedDownload, "Presenter must receive an onDownload closure")
    }

    func test_downloadCallback_opensReleasesURL() {
        let updateChecker = MockUpdateChecker()
        updateChecker.result = .available(latestVersion: "9.9.9")
        var openedURLs: [URL] = []
        // Simulate the user clicking Download by having the presenter
        // invoke onDownload immediately.
        let sut = makeSUT(
            updateChecker: updateChecker,
            updateResultPresenter: { _, onDownload in onDownload() },
            urlOpener: { url in openedURLs.append(url) }
        )
        let menu = NSMenu()

        sut.menuWillOpen(menu)
        invoke(findMenuItem(in: menu, titleContains: "Check for Updates"))

        XCTAssertEqual(openedURLs, [UpdateChecker.releasesURL],
                       "Download must open the GitHub releases URL exactly once")
    }

    func test_downloadCallback_notInvokedWhenPresenterDeclines() {
        // If the presenter never calls onDownload (user clicks Cancel, or
        // upToDate/unknown branches), no URL is opened.
        let updateChecker = MockUpdateChecker()
        updateChecker.result = .available(latestVersion: "9.9.9")
        var openedURLs: [URL] = []
        let sut = makeSUT(
            updateChecker: updateChecker,
            updateResultPresenter: { _, _ in /* presenter ignores onDownload */ },
            urlOpener: { url in openedURLs.append(url) }
        )
        let menu = NSMenu()

        sut.menuWillOpen(menu)
        invoke(findMenuItem(in: menu, titleContains: "Check for Updates"))

        XCTAssertTrue(openedURLs.isEmpty,
                      "URL must not be opened unless the presenter invokes onDownload")
    }

    func test_checkForUpdates_whenUnknown_presentsUnknownResult() {
        let updateChecker = MockUpdateChecker()
        updateChecker.result = .unknown
        var presentedResult: UpdateResult?
        let sut = makeSUT(updateChecker: updateChecker, updateResultPresenter: { result, _ in
            presentedResult = result
        })
        let menu = NSMenu()

        sut.menuWillOpen(menu)
        invoke(findMenuItem(in: menu, titleContains: "Check for Updates"))

        guard case .unknown = presentedResult else {
            return XCTFail("Expected .unknown, got \(String(describing: presentedResult))")
        }
    }
}

// MARK: - Menu helpers

private func findMenuItem(in menu: NSMenu, titleContains needle: String) -> NSMenuItem? {
    menu.items.first { $0.title.contains(needle) }
}

private func invoke(_ item: NSMenuItem?) {
    guard let item, let action = item.action, let target = item.target else {
        XCTFail("Menu item missing action or target")
        return
    }
    _ = (target as AnyObject).perform(action, with: item)
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
    taskFactory: MockRepeatingTaskFactory = MockRepeatingTaskFactory(),
    updateResultPresenter: @escaping UpdateResultPresenting = { _, _ in },
    urlOpener: @escaping URLOpening = { _ in }
) -> StatusBarController {
    StatusBarController(
        eventTap: eventTap,
        stats: StatisticsManager(defaults: makeStatusBarTestDefaults()),
        secureInputMonitor: secureInputMonitor,
        updateChecker: updateChecker,
        repeatingTaskFactory: taskFactory.make,
        updateResultPresenter: updateResultPresenter,
        urlOpener: urlOpener
    )
}

private func makeStatusBarTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString) ?? .standard
}

private final class MockUpdateChecker: UpdateChecking {
    var result: UpdateResult = .unknown
    private(set) var checkInBackgroundCallCount = 0
    func checkInBackground(completion: ((UpdateResult) -> Void)?) {
        checkInBackgroundCallCount += 1
        completion?(result)
    }
}
