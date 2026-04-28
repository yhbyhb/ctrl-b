import Cocoa
import CtrlBCore

final class StatusBarController: NSObject, NSMenuDelegate, StatusBarControlling {
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let eventTap: EventTapControlling
    private let stats: StatisticsManager
    private let aboutPanel: AboutPanelController
    private var lastSecureInputActive = false
    private var secureInputPollTimer: Timer?

    init(eventTap: EventTapControlling, stats: StatisticsManager) {
        self.eventTap = eventTap
        self.stats = stats
        self.aboutPanel = AboutPanelController(stats: stats,
                                                currentInputSource: currentInputSourceDisplay)
        super.init()
        eventTap.onStateChange = { [weak self] state in
            self?.applyStatusAppearance(for: state)
        }
    }

    func start() {
        setupStatusItem()
        lastSecureInputActive = isSecureKeyboardEntryActive()
        applyStatusAppearance(for: eventTap.state)
        startSecureInputMonitoring()
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
        refreshStateIfNeeded()
        checkSecureInputChange()
        buildMenu(menu)
    }

    // MARK: - Menu

    private func buildMenu(_ menu: NSMenu) {
        menu.removeAllItems()

        let localized = { (key: String) in NSLocalizedString(key, bundle: .module, comment: "") }

        // Header
        menu.addItem(disabled(localized("menu.header")))
        menu.addItem(.separator())

        let menuModel = StatusMenuModelBuilder.build(for: eventTap.state)
        menu.addItem(disabled(localized(menuModel.statusTitleKey)))
        if lastSecureInputActive {
            menu.addItem(disabled(localized("menu.secure_input.warning")))
        }
        for item in menuModel.primaryItems {
            menu.addItem(action(localized(item.titleKey), selector(for: item.action)))
        }
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

        // About
        menu.addItem(action(localized("menu.about"), #selector(showAbout)))

        // Quit
        let quit = NSMenuItem(title: localized("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        eventTap.toggle()
    }

    @objc private func checkAgain() {
        eventTap.checkAgain()
    }

    @objc private func openAccessibilitySettings() {
        eventTap.openAccessibilitySettings()
    }

    @objc private func resetStats() {
        stats.reset()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLoginManager.toggle()
    }

    @objc private func showAbout() {
        aboutPanel.show(nil)
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

    private func selector(for action: StatusMenuPrimaryAction) -> Selector {
        switch action {
        case .pause, .resume:
            return #selector(toggleEnabled)
        case .openAccessibilitySettings:
            return #selector(openAccessibilitySettings)
        case .checkAgain:
            return #selector(checkAgain)
        }
    }

    private func applyStatusAppearance(for state: EventTapState) {
        let localized = { (key: String) in NSLocalizedString(key, bundle: .module, comment: "") }
        let secure = lastSecureInputActive
        statusItem.button?.title = StatusMenuModelBuilder.statusItemTitle(for: state, secureInputActive: secure)
        statusItem.button?.toolTip = localized(StatusMenuModelBuilder.tooltipKey(for: state, secureInputActive: secure))
    }

    private func startSecureInputMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkSecureInputChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        secureInputPollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkSecureInputChange()
        }
    }

    @objc private func checkSecureInputChange() {
        let active = isSecureKeyboardEntryActive()
        guard active != lastSecureInputActive else { return }
        lastSecureInputActive = active
        applyStatusAppearance(for: eventTap.state)
    }

    private func refreshStateIfNeeded() {
        _ = eventTap.syncPermissionState()
    }

    #if DEBUG
    func debugRefreshStateIfNeeded() {
        refreshStateIfNeeded()
    }
    #endif

    private func formatTime(_ seconds: Double) -> String {
        let localized = { (key: String) in NSLocalizedString(key, bundle: .module, comment: "") }
        switch TimeMagnitude(seconds) {
        case .seconds(let sec): return String(format: localized("time.seconds"), sec)
        case .minutes(let min): return String(format: localized("time.minutes"), min)
        case .hours(let hrs): return String(format: localized("time.hours"), hrs)
        }
    }
}
