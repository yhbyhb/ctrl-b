import Cocoa
import CtrlBHelperCore

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let eventTap: EventTapManager
    private let stats: StatisticsManager

    init(eventTap: EventTapManager, stats: StatisticsManager) {
        self.eventTap = eventTap
        self.stats = stats
        super.init()
        setupStatusItem()
    }

    // MARK: - Setup

    private func setupStatusItem() {
        statusItem.button?.title = "⌃B"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        buildMenu(menu)
    }

    // MARK: - Menu 구성

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        // 헤더
        menu.addItem(disabled("Ctrl+ㅠ → Ctrl+B 리매핑"))
        menu.addItem(.separator())

        // 활성화 토글
        let toggleTitle = eventTap.isEnabled ? "✓ 활성화됨" : "비활성화됨"
        menu.addItem(action(toggleTitle, #selector(toggleEnabled)))
        menu.addItem(.separator())

        // 오늘 통계
        menu.addItem(disabled("오늘: \(stats.todayRemapCount)회 · \(stats.formattedTodayTimeSaved) 절약"))
        // 누계 통계
        menu.addItem(disabled("누계: \(stats.remapCount)회 · \(stats.formattedTimeSaved) 절약"))
        menu.addItem(.separator())

        // 통계 초기화
        menu.addItem(action("통계 초기화", #selector(resetStats)))
        menu.addItem(.separator())

        // 로그인 시 자동 실행
        let loginTitle = LaunchAtLoginManager.isEnabled ? "✓ 로그인 시 자동 실행" : "로그인 시 자동 실행"
        menu.addItem(action(loginTitle, #selector(toggleLaunchAtLogin)))
        menu.addItem(.separator())

        // 종료
        let quit = NSMenuItem(title: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        eventTap.toggle()
    }

    @objc private func resetStats() {
        stats.reset()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginManager.toggle()
    }

    // MARK: - Helpers

    private func disabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }
}
