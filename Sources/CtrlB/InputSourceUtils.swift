import Carbon
import CtrlBCore
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b", category: "InputSource")

/// Determines if the currently active keyboard input source is an IME.
/// kTISTypeKeyboardInputMode means IME → remapping needed
/// kTISTypeKeyboardLayout means simple keymap (ABC, AZERTY, etc.) → no remapping needed
func isInputMethodActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let typePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else {
        return false
    }
    let sourceType = Unmanaged<CFString>.fromOpaque(typePtr).takeUnretainedValue() as String
    return isInputMethod(sourceType)
}

/// Debug: logs current input source information.
/// Call when isInputMethodActive() returns false to detect missing input methods early.
func logCurrentInputSource() {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        log.warning("Unable to get current input source")
        return
    }

    var id = "(unknown)"
    var name = "(unknown)"
    var languages: [String] = []

    if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
        id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
    }
    if let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) {
        name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
    }
    if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
        languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
    }

    log.debug("Current input source: id=\(id) name=\(name) languages=\(languages.joined(separator: ","))")
}
