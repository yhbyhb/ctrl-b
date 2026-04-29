import Carbon
import Foundation

/// Observes macOS Secure Keyboard Entry state.
/// When active, no external CGEventTap can observe key input — ctrl-b cannot
/// remap inside whichever app turned it on (Terminal, Ghostty, iTerm2, etc.).
protocol SecureInputMonitoring {
    func isActive() -> Bool
}

final class SecureInputMonitor: SecureInputMonitoring {
    func isActive() -> Bool {
        IsSecureEventInputEnabled()
    }
}

typealias SecureInputMonitorFactory = () -> SecureInputMonitoring
