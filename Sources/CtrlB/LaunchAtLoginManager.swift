import ServiceManagement

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
            print("LaunchAtLogin error: \(error.localizedDescription)")
        }
    }
}
