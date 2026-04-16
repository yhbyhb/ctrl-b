import Cocoa
import CtrlBCore
import os

private let log = Logger(subsystem: "com.yhbyhb.CtrlB", category: "AppDelegate")

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var eventTapManager: EventTapManager?
    private var permissionPollingTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock 아이콘 숨김 (메뉴바 전용 앱)
        NSApp.setActivationPolicy(.accessory)

        let stats = StatisticsManager()
        let eventTap = EventTapManager(statisticsManager: stats)
        statusBarController = StatusBarController(eventTap: eventTap, stats: stats)
        eventTapManager = eventTap

        // Accessibility 권한 확인 (없으면 시스템 다이얼로그 자동 표시)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options as CFDictionary)

        if trusted {
            eventTap.start()
        } else {
            waitForAccessibilityPermission()
        }
    }

    // MARK: - Accessibility 권한 대기

    /// DistributedNotification(주) + 폴링(보조)으로 권한 부여를 감지하여 event tap 시작
    private func waitForAccessibilityPermission() {
        log.info("Accessibility 권한 대기 시작")

        // 1차: com.apple.accessibility.api 알림 감시 (Loop, Hammerspoon 등이 사용하는 비공식 알림)
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleAccessibilityChange),
            name: .init("com.apple.accessibility.api"),
            object: nil
        )

        // 2차: 폴링 백업 (알림 누락 대비, 3초 간격)
        permissionPollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.tryStartEventTap()
        }
    }

    @objc private func handleAccessibilityChange() {
        log.debug("com.apple.accessibility.api 알림 수신")
        // 알림이 AXIsProcessTrusted() 업데이트보다 약간 먼저 도착 — 200ms 대기
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.tryStartEventTap()
        }
    }

    private func tryStartEventTap() {
        guard AXIsProcessTrusted() else { return }

        log.info("Accessibility 권한 확인됨 — event tap 시작")
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
