import Cocoa
import CtrlBCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var eventTapManager: EventTapManager?

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
            // 앱 초기화 완료 후 안내 알림 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                eventTap.start()  // 권한 부여 후 재실행 없이도 동작하도록 시도
            }
        }
    }
}
