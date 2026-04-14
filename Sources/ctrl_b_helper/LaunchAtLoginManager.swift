import ServiceManagement

/// macOS 13+ SMAppService를 이용한 로그인 시 자동 실행 관리
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
            print("LaunchAtLogin 오류: \(error.localizedDescription)")
        }
    }
}
