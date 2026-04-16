import Cocoa
import CtrlBCore
import os

private let log = Logger(subsystem: "com.yhbyhb.CtrlB", category: "AppDelegate")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var eventTapManager: EventTapManager?
    private var permissionPollingTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide Dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)

        let stats = StatisticsManager()
        let eventTap = EventTapManager(statisticsManager: stats)
        statusBarController = StatusBarController(eventTap: eventTap, stats: stats)
        eventTapManager = eventTap

        // Check Accessibility permission (shows system dialog if not granted)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if trusted {
            eventTap.start()
        } else {
            waitForAccessibilityPermission()
        }
    }

    // MARK: - Accessibility Permission Monitoring

    /// Monitors for permission grant via DistributedNotification (primary) + polling (fallback)
    private func waitForAccessibilityPermission() {
        log.info("Waiting for Accessibility permission")

        // Primary: observe com.apple.accessibility.api notification (unofficial, used by Loop, Hammerspoon, etc.)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAccessibilityChange),
            name: .init("com.apple.accessibility.api"),
            object: nil
        )

        // Fallback: polling every 3 seconds in case notification is missed
        permissionPollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.tryStartEventTap()
        }
    }

    @objc private func handleAccessibilityChange() {
        log.debug("Received com.apple.accessibility.api notification")
        // Notification arrives slightly before AXIsProcessTrusted() updates — wait 200ms
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.tryStartEventTap()
        }
    }

    private func tryStartEventTap() {
        guard AXIsProcessTrusted() else { return }

        log.info("Accessibility permission granted — starting event tap")
        stopPermissionMonitoring()
        eventTapManager?.start()
    }

    private func stopPermissionMonitoring() {
        DistributedNotificationCenter.default().removeObserver(
            self, name: .init("com.apple.accessibility.api"), object: nil
        )
        permissionPollingTimer?.invalidate()
        permissionPollingTimer = nil
    }
}
