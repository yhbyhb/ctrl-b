import Cocoa
import CtrlBCore
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b", category: "AppDelegate")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarControlling?
    private var eventTapManager: EventTapControlling?
    private var permissionPollingTask: RepeatingTask?
    private let permissionController: AccessibilityPermissionControlling
    private let permissionObserver: AccessibilityPermissionObserving
    private let repeatingTaskFactory: RepeatingTaskFactory
    private let activationPolicySetter: (NSApplication.ActivationPolicy) -> Void
    private let statisticsFactory: () -> StatisticsManager
    private let eventTapFactory: EventTapFactory
    private let statusBarFactory: StatusBarFactory
    private let secureInputMonitorFactory: SecureInputMonitorFactory
    private var isMonitoringAccessibilityPermission = false
    private var recoveryWorkItem: DispatchWorkItem?
    private var currentPollingInterval: TimeInterval?

    init(
        permissionController: AccessibilityPermissionControlling = AccessibilityPermissionController(),
        permissionObserver: AccessibilityPermissionObserving = AccessibilityPermissionObserver(),
        repeatingTaskFactory: @escaping RepeatingTaskFactory = { interval, handler in
            TimerRepeatingTask(interval: interval, handler: handler)
        },
        activationPolicySetter: @escaping (NSApplication.ActivationPolicy) -> Void = { policy in
            NSApp.setActivationPolicy(policy)
        },
        statisticsFactory: @escaping () -> StatisticsManager = { StatisticsManager() },
        eventTapFactory: @escaping EventTapFactory = { stats, permissionController in
            EventTapManager(statisticsManager: stats, permissionController: permissionController)
        },
        statusBarFactory: @escaping StatusBarFactory = { eventTap, stats, secureInputMonitor, repeatingTaskFactory in
            return StatusBarController(
                eventTap: eventTap,
                stats: stats,
                secureInputMonitor: secureInputMonitor,
                repeatingTaskFactory: repeatingTaskFactory
            )
        },
        secureInputMonitorFactory: @escaping SecureInputMonitorFactory = { SecureInputMonitor() }
    ) {
        self.permissionController = permissionController
        self.permissionObserver = permissionObserver
        self.repeatingTaskFactory = repeatingTaskFactory
        self.activationPolicySetter = activationPolicySetter
        self.statisticsFactory = statisticsFactory
        self.eventTapFactory = eventTapFactory
        self.statusBarFactory = statusBarFactory
        self.secureInputMonitorFactory = secureInputMonitorFactory
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon (menu bar only app)
        activationPolicySetter(.accessory)

        let stats = statisticsFactory()
        let eventTap = eventTapFactory(stats, permissionController)
        let secureInputMonitor = secureInputMonitorFactory()
        statusBarController = statusBarFactory(eventTap, stats, secureInputMonitor, repeatingTaskFactory)
        statusBarController?.start()
        eventTapManager = eventTap
        startPermissionMonitoring()

        let trusted = permissionController.promptIfNeededOnFirstLaunch()

        if trusted {
            eventTap.start(reason: .launch)
            reconfigurePollingIfNeeded(for: eventTap.state)
        } else {
            let state = eventTap.syncPermissionState()
            reconfigurePollingIfNeeded(for: state)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPermissionMonitoring()
        statusBarController?.stop()
        eventTapManager?.shutdown()
    }

    // MARK: - Accessibility Permission Monitoring

    private func startPermissionMonitoring() {
        log.info("Starting Accessibility permission monitoring")
        isMonitoringAccessibilityPermission = true

        permissionObserver.startObserving { [weak self] in
            self?.scheduleDelayedRecovery()
        }

        reconfigurePollingIfNeeded(for: eventTapManager?.state ?? .permissionRequired)
    }

    private func scheduleDelayedRecovery() {
        log.debug("Received com.apple.accessibility.api notification")
        recoveryWorkItem?.cancel()

        // Notification arrives slightly before AXIsProcessTrusted() updates — wait 200ms
        let workItem = DispatchWorkItem { [weak self] in
            self?.tryRecoverEventTap()
        }
        recoveryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }

    private func tryRecoverEventTap() {
        guard isMonitoringAccessibilityPermission else { return }
        guard let eventTapManager else { return }

        let previousState = eventTapManager.state
        let state = eventTapManager.syncPermissionState()
        reconfigurePollingIfNeeded(for: state)
        guard state != previousState else { return }

        log.info("Accessibility permission state updated: \(String(describing: previousState)) -> \(String(describing: state))")
    }

    private func reconfigurePollingIfNeeded(for state: EventTapState) {
        let interval = PermissionPollingPolicy.interval(for: state)
        guard currentPollingInterval != interval else { return }

        permissionPollingTask?.cancel()
        currentPollingInterval = interval
        permissionPollingTask = repeatingTaskFactory(interval) { [weak self] in
            self?.tryRecoverEventTap()
        }
    }

    private func stopPermissionMonitoring() {
        isMonitoringAccessibilityPermission = false
        permissionObserver.stopObserving()
        permissionPollingTask?.cancel()
        permissionPollingTask = nil
        currentPollingInterval = nil
        recoveryWorkItem?.cancel()
        recoveryWorkItem = nil
    }
}
