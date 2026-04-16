import Cocoa
import CtrlBCore

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
        statusItem.button?.title = "⌃b"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        buildMenu(menu)
    }

    // MARK: - Menu

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let localized = { (key: String) in NSLocalizedString(key, bundle: .module, comment: "") }

        // Header
        menu.addItem(disabled(localized("menu.header")))
        menu.addItem(.separator())

        // Toggle
        let toggleTitle = eventTap.isEnabled ? localized("menu.enabled") : localized("menu.disabled")
        menu.addItem(action(toggleTitle, #selector(toggleEnabled)))
        menu.addItem(.separator())

        // Today stats
        let todayText = String(format: localized("menu.today"), stats.todayRemapCount, formatTime(stats.todayTimeSavedSeconds))
        menu.addItem(disabled(todayText))
        // Cumulative stats
        let totalText = String(format: localized("menu.total"), stats.remapCount, formatTime(stats.timeSavedSeconds))
        menu.addItem(disabled(totalText))
        menu.addItem(.separator())

        // Reset
        menu.addItem(action(localized("menu.reset"), #selector(resetStats)))
        menu.addItem(.separator())

        // Launch at login
        let loginTitle = LaunchAtLoginManager.isEnabled ? localized("menu.login.enabled") : localized("menu.login.disabled")
        menu.addItem(action(loginTitle, #selector(toggleLaunchAtLogin)))
        menu.addItem(.separator())

        // Quit
        let quit = NSMenuItem(title: localized("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
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

    private func formatTime(_ seconds: Double) -> String {
        let localized = { (key: String) in NSLocalizedString(key, bundle: .module, comment: "") }
        if seconds < 60 {
            return String(format: localized("time.seconds"), seconds)
        } else if seconds < 3600 {
            return String(format: localized("time.minutes"), seconds / 60)
        } else {
            return String(format: localized("time.hours"), seconds / 3600)
        }
    }
}
