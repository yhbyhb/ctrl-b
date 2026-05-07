import Foundation
@testable import CtrlB
@testable import CtrlBCore

func makeEventTapManagerSUT(
    permission: MockPermissionController,
    engine: MockEventTapEngine
) -> EventTapManager {
    let defaults = UserDefaults(suiteName: UUID().uuidString) ?? .standard
    return EventTapManager(
        statisticsManager: StatisticsManager(defaults: defaults),
        permissionController: permission,
        eventTapEngine: engine
    )
}

final class MockPermissionController: AccessibilityPermissionControlling {
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

final class MockEventTapEngine: EventTapEngineControlling {
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
