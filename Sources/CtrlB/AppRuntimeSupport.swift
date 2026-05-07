import AppKit
import CtrlBCore
import Foundation

protocol EventTapControlling: AnyObject {
    var state: EventTapState { get }
    var onStateChange: ((EventTapState) -> Void)? { get set }
    var isAwaitingFollowUp: Bool { get }
    func start(reason: EventTapStateChangeReason)
    @discardableResult func checkAgain() -> EventTapState
    @discardableResult func refreshPermissionState() -> EventTapState
    @discardableResult func syncPermissionState() -> EventTapState
    func pause()
    func shutdown()
    func toggle()
    func openAccessibilitySettings()
}

protocol RepeatingTask {
    func cancel()
}

protocol AccessibilityPermissionObserving {
    func startObserving(handler: @escaping () -> Void)
    func stopObserving()
}

final class AccessibilityPermissionObserver: NSObject, AccessibilityPermissionObserving {
    private let center: DistributedNotificationCenter
    private var handler: (() -> Void)?

    init(center: DistributedNotificationCenter = .default()) {
        self.center = center
        super.init()
    }

    func startObserving(handler: @escaping () -> Void) {
        self.handler = handler
        center.addObserver(
            self,
            selector: #selector(handleAccessibilityChange),
            name: .init("com.apple.accessibility.api"),
            object: nil
        )
    }

    func stopObserving() {
        center.removeObserver(self, name: .init("com.apple.accessibility.api"), object: nil)
        handler = nil
    }

    @objc private func handleAccessibilityChange() {
        handler?()
    }
}

final class TimerRepeatingTask: RepeatingTask {
    private var timer: Timer?

    init(interval: TimeInterval, handler: @escaping () -> Void) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            handler()
        }
    }

    deinit {
        // Safety net: if the holder forgets to cancel, invalidate the timer.
        // Timer.invalidate must run on the run-loop thread that owns it
        // (typically main); deinit can fire from any thread, so dispatch
        // when we're not already on main.
        let strayTimer = timer
        timer = nil
        if Thread.isMainThread {
            strayTimer?.invalidate()
        } else if let strayTimer {
            DispatchQueue.main.async { strayTimer.invalidate() }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}

typealias RepeatingTaskFactory = (_ interval: TimeInterval, _ handler: @escaping () -> Void) -> RepeatingTask
typealias EventTapFactory = (_ statisticsManager: StatisticsManager, _ permissionController: AccessibilityPermissionControlling) -> EventTapControlling
typealias UpdateCheckerFactory = () -> UpdateChecking
protocol StatusBarControlling: AnyObject {
    func start()
    func stop()
}

typealias StatusBarFactory = (
    _ eventTap: EventTapControlling,
    _ statisticsManager: StatisticsManager,
    _ secureInputMonitor: SecureInputMonitoring,
    _ updateChecker: UpdateChecking,
    _ repeatingTaskFactory: @escaping RepeatingTaskFactory,
    _ updateResultPresenter: @escaping UpdateResultPresenting,
    _ urlOpener: @escaping URLOpening
) -> StatusBarControlling

enum PermissionPollingPolicy {
    static let activeInterval: TimeInterval = 1.0
    static let passiveInterval: TimeInterval = 5.0

    static func interval(for state: EventTapState) -> TimeInterval {
        switch state {
        case .permissionRequired, .unavailable:
            return activeInterval
        case .enabled, .paused:
            return passiveInterval
        }
    }
}

enum SecureInputPollingPolicy {
    /// Secure Keyboard Entry exposes no notification API; polling is the only
    /// option. 1s matches the macOS ecosystem convention (Karabiner, Hammerspoon)
    /// and is well within the noise floor of menu-bar app overhead.
    static let interval: TimeInterval = 1.0
}
