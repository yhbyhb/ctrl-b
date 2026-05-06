import Cocoa
import CtrlBCore
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b", category: "SecureInput")

final class StatusBarController: NSObject, NSMenuDelegate, StatusBarControlling {
    private lazy var statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let eventTap: EventTapControlling
    private let stats: StatisticsManager
    private let aboutPanel: AboutPanelController
    private let secureInputMonitor: SecureInputMonitoring
    private let updateChecker: UpdateChecking
    private let repeatingTaskFactory: RepeatingTaskFactory
    private var lastSecureInputActive = false
    private var pollingTask: RepeatingTask?

    init(eventTap: EventTapControlling,
         stats: StatisticsManager,
         secureInputMonitor: SecureInputMonitoring,
         updateChecker: UpdateChecking,
         repeatingTaskFactory: @escaping RepeatingTaskFactory) {
        self.eventTap = eventTap
        self.stats = stats
        self.secureInputMonitor = secureInputMonitor
        self.updateChecker = updateChecker
        self.repeatingTaskFactory = repeatingTaskFactory
        self.aboutPanel = AboutPanelController(
            stats: stats,
            currentInputSource: currentInputSourceDisplay,
            secureInputMonitor: secureInputMonitor
        )
        super.init()
        eventTap.onStateChange = { [weak self] state in
            self?.applyStatusAppearance(for: state)
        }
    }

    deinit { stop() }

    func start() {
        setupStatusItem()
        lastSecureInputActive = secureInputMonitor.isActive()
        applyStatusAppearance(for: eventTap.state)
        startSecureInputMonitoring()
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask = nil
        NSWorkspace.shared.notificationCenter.removeObserver(
            self,
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
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

        menu.addItem(disabled(localized("menu.header")))
        menu.addItem(.separator())

        let menuModel = StatusMenuModelBuilder.build(for: eventTap.state)
        menu.addItem(disabled(localized(menuModel.statusTitleKey)))
        if eventTap.state == .enabled, lastSecureInputActive {
            menu.addItem(disabled(localized("menu.secure_input.warning")))
        }
        for item in menuModel.primaryItems {
            menu.addItem(action(localized(item.titleKey), selector(for: item.action)))
        }
        menu.addItem(.separator())

        let todayText = String(format: localized("menu.today"), stats.todayRemapCount, formatTime(stats.todayTimeSavedSeconds))
        menu.addItem(disabled(todayText))
        let totalText = String(format: localized("menu.total"), stats.remapCount, formatTime(stats.timeSavedSeconds))
        menu.addItem(disabled(totalText))
        menu.addItem(.separator())

        menu.addItem(action(localized("menu.reset"), #selector(resetStats)))
        menu.addItem(.separator())

        let loginTitle = LaunchAtLoginManager.isEnabled ? localized("menu.login.enabled") : localized("menu.login.disabled")
        menu.addItem(action(loginTitle, #selector(toggleLaunchAtLogin)))
        menu.addItem(.separator())

        menu.addItem(action(localized("menu.about"), #selector(showAbout)))

        let checkForUpdatesTitle: String
        if case .available(let version) = updateChecker.result {
            checkForUpdatesTitle = String(format: localized("menu.update_available"), version)
        } else {
            checkForUpdatesTitle = localized("menu.check_for_updates")
        }
        menu.addItem(action(checkForUpdatesTitle, #selector(openLatestRelease)))

        let quit = NSMenuItem(title: localized("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    // MARK: - Actions

    @objc private func toggleEnabled() { eventTap.toggle() }
    @objc private func checkAgain() { eventTap.checkAgain() }
    @objc private func openAccessibilitySettings() { eventTap.openAccessibilitySettings() }
    @objc private func resetStats() { stats.reset() }
    @objc private func toggleLaunchAtLogin() { LaunchAtLoginManager.toggle() }
    @objc private func showAbout() { aboutPanel.show(nil) }
    @objc private func openLatestRelease() { NSWorkspace.shared.open(UpdateChecker.releasesURL) }

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
        case .pause, .resume: return #selector(toggleEnabled)
        case .openAccessibilitySettings: return #selector(openAccessibilitySettings)
        case .checkAgain: return #selector(checkAgain)
        }
    }

    private func applyStatusAppearance(for state: EventTapState) {
        let localized = { (key: String) in NSLocalizedString(key, bundle: .module, comment: "") }
        let appearance = StatusMenuModelBuilder.statusItemAppearance(
            for: state,
            secureInputActive: lastSecureInputActive
        )
        guard let button = statusItem.button else { return }
        button.title = appearance.title
        button.toolTip = localized(
            StatusMenuModelBuilder.tooltipKey(for: state, secureInputActive: lastSecureInputActive)
        )
        if let symbolName = appearance.symbolName {
            let image = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: localized("tooltip.state.secure_input_active")
            )
            image?.isTemplate = true
            button.image = image
            button.imagePosition = .imageRight
        } else {
            button.image = nil
        }
    }

    private func startSecureInputMonitoring() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(checkSecureInputChange),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        pollingTask = repeatingTaskFactory(SecureInputPollingPolicy.interval) { [weak self] in
            self?.checkSecureInputChange()
        }
    }

    @objc private func checkSecureInputChange() {
        let active = secureInputMonitor.isActive()
        guard active != lastSecureInputActive else { return }
        lastSecureInputActive = active
        if active {
            log.warning("Secure Keyboard Entry became active — ctrl-b cannot intercept")
        } else {
            log.info("Secure Keyboard Entry deactivated")
        }
        applyStatusAppearance(for: eventTap.state)
    }

    private func refreshStateIfNeeded() {
        _ = eventTap.syncPermissionState()
    }

    #if DEBUG
    var debugSecureInputActive: Bool { lastSecureInputActive }
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
