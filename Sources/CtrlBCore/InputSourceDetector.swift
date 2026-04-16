import Foundation

/// macOS input source type constants
/// - kTISTypeKeyboardLayout: simple keymap (ABC, AZERTY, etc.) — not an IME
/// - kTISTypeKeyboardInputMode: IME-based input source (Korean, Chinese, Japanese, etc.)
public let inputMethodType = "TISTypeKeyboardInputMode"
public let keyboardLayoutType = "TISTypeKeyboardLayout"

/// Determines if the input source type is an IME (Input Method)
/// IME-based input sources may consume events in interpretKeyEvents, so they are remap targets
public func isInputMethod(_ sourceType: String) -> Bool {
    sourceType == inputMethodType
}
