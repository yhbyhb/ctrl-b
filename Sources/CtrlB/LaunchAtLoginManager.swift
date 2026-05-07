import ServiceManagement
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b", category: "LaunchAtLogin")

/// Manages launch-at-login via SMAppService (macOS 13+)
enum LaunchAtLoginManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func toggle() {
        do {
            if isEnabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            log.error("LaunchAtLogin toggle failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
