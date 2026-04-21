import XCTest
import Foundation
@testable import CtrlB
@testable import CtrlBCore

final class EventTapManagerTests: XCTestCase {
    func test_checkAgain_permissionMissing_staysPermissionRequired() {
        let permission = MockPermissionController(isTrusted: false)
        let engine = MockEventTapEngine()
        let sut = makeSUT(permission: permission, engine: engine)

        let state = sut.checkAgain()

        XCTAssertEqual(state, .permissionRequired)
        XCTAssertEqual(sut.state, .permissionRequired)
        XCTAssertEqual(engine.startCallCount, 0)
    }

    func test_checkAgain_permissionGrantedAndTapStarts_becomesEnabled() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)

        let state = sut.checkAgain()

        XCTAssertEqual(state, .enabled)
        XCTAssertEqual(sut.state, .enabled)
        XCTAssertEqual(engine.startCallCount, 1)
        XCTAssertEqual(engine.setEnabledCalls, [true])
    }

    func test_checkAgain_permissionGrantedButTapFails_becomesUnavailable() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: false)
        let sut = makeSUT(permission: permission, engine: engine)

        let state = sut.checkAgain()

        XCTAssertEqual(state, .unavailable)
        XCTAssertEqual(sut.state, .unavailable)
        XCTAssertEqual(engine.startCallCount, 1)
        XCTAssertTrue(engine.setEnabledCalls.isEmpty)
    }

    func test_toggle_fromEnabled_pausesWithoutDroppingTap() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()

        sut.toggle()

        XCTAssertEqual(sut.state, .paused)
        XCTAssertEqual(engine.setEnabledCalls, [true, false])
        XCTAssertEqual(engine.startCallCount, 1)
    }

    func test_toggle_fromPaused_attemptsResumeAndReturnsEnabledOnSuccess() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()
        sut.toggle()

        sut.toggle()

        XCTAssertEqual(sut.state, .enabled)
        XCTAssertEqual(engine.startCallCount, 2)
        XCTAssertEqual(engine.setEnabledCalls, [true, false, true])
    }

    func test_openAccessibilitySettings_delegatesToController() {
        let permission = MockPermissionController(isTrusted: false)
        let sut = makeSUT(permission: permission, engine: MockEventTapEngine())

        sut.openAccessibilitySettings()

        XCTAssertEqual(permission.openSettingsCallCount, 1)
    }

    func test_refreshPermissionState_whenPermissionRevokedFromEnabled_becomesPermissionRequired() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()
        permission.isTrustedValue = false

        let state = sut.refreshPermissionState()

        XCTAssertEqual(state, .permissionRequired)
        XCTAssertEqual(sut.state, .permissionRequired)
        XCTAssertEqual(engine.stopCallCount, 1)
    }

    func test_refreshPermissionState_whenPermissionStillGranted_keepsEnabledState() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()

        let state = sut.refreshPermissionState()

        XCTAssertEqual(state, .enabled)
        XCTAssertEqual(sut.state, .enabled)
        XCTAssertEqual(engine.stopCallCount, 0)
    }

    func test_refreshPermissionState_whenPermissionRevokedFromPaused_becomesPermissionRequired() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()
        sut.toggle()
        permission.isTrustedValue = false

        let state = sut.refreshPermissionState()

        XCTAssertEqual(state, .permissionRequired)
        XCTAssertEqual(sut.state, .permissionRequired)
        XCTAssertEqual(engine.stopCallCount, 1)
    }

    func test_refreshPermissionState_whenPermissionRevoked_clearsAwaitingFollowUp() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()

        sut.debugSetAwaitingFollowUpForTests(true)
        XCTAssertTrue(sut.isAwaitingFollowUp)

        permission.isTrustedValue = false
        _ = sut.refreshPermissionState()

        XCTAssertFalse(sut.isAwaitingFollowUp)
    }

    func test_tapDisabled_userInputRecoverySuccess_staysEnabled() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)
        _ = sut.checkAgain()

        sut.handleTapDisabled(type: .tapDisabledByUserInput)

        XCTAssertEqual(sut.state, .enabled)
        XCTAssertEqual(engine.setEnabledCalls, [true, true])
    }

    func test_stateChangeCallback_firesOnTransition() {
        let permission = MockPermissionController(isTrusted: true)
        let engine = MockEventTapEngine(startResult: true)
        let sut = makeSUT(permission: permission, engine: engine)
        var receivedStates: [EventTapState] = []
        sut.onStateChange = { receivedStates.append($0) }

        _ = sut.checkAgain()
        sut.toggle()

        XCTAssertEqual(receivedStates, [.enabled, .paused])
    }

    func test_localizedMenuKeys_exist() {
        let bundleLocalizations = Set(Bundle.module.localizations.map { $0.lowercased() })
        let expectedLocalizations = ["en", "ko", "ja", "zh-hans"]
        let keys = [
            "menu.state.enabled",
            "menu.state.paused",
            "menu.state.permission_required",
            "menu.state.unavailable",
            "menu.action.pause",
            "menu.action.resume",
            "menu.action.open_accessibility_settings",
            "menu.action.check_again",
            "tooltip.state.enabled",
            "tooltip.state.paused",
            "tooltip.state.permission_required",
            "tooltip.state.unavailable"
        ]

        for localization in expectedLocalizations {
            XCTAssertTrue(bundleLocalizations.contains(localization), "Missing bundle for localization \(localization)")

            guard let bundlePath = Bundle.module.path(forResource: localization, ofType: "lproj"),
                  let bundle = Bundle(path: bundlePath) else {
                XCTFail("Missing bundle path for localization \(localization)")
                continue
            }

            for key in keys {
                let value = bundle.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertNotEqual(value, key, "Missing localized string for \(key) in \(localization)")
            }
        }
    }

    private func makeSUT(
        permission: MockPermissionController,
        engine: MockEventTapEngine
    ) -> EventTapManager {
        EventTapManager(
            statisticsManager: StatisticsManager(defaults: makeTestDefaults()),
            permissionController: permission,
            eventTapEngine: engine
        )
    }
}

private func makeTestDefaults() -> UserDefaults {
    UserDefaults(suiteName: UUID().uuidString) ?? .standard
}

private final class MockPermissionController: AccessibilityPermissionControlling {
    var isTrustedValue: Bool
    private(set) var openSettingsCallCount = 0

    init(isTrusted: Bool) {
        self.isTrustedValue = isTrusted
    }

    func promptIfNeededOnFirstLaunch() -> Bool {
        isTrustedValue
    }

    func isTrusted() -> Bool {
        isTrustedValue
    }

    func openSettings() {
        openSettingsCallCount += 1
    }
}

private final class MockEventTapEngine: EventTapEngineControlling {
    var isActive = false
    var startResult: Bool
    private(set) var startCallCount = 0
    private(set) var setEnabledCalls: [Bool] = []
    private(set) var stopCallCount = 0

    init(startResult: Bool = true) {
        self.startResult = startResult
    }

    func start(userInfo: UnsafeMutableRawPointer?) -> Bool {
        startCallCount += 1
        isActive = startResult
        return startResult
    }

    func setEnabled(_ isEnabled: Bool) {
        setEnabledCalls.append(isEnabled)
    }

    func stop() {
        stopCallCount += 1
        isActive = false
    }
}
