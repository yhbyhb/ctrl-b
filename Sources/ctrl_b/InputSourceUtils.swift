import Carbon
import CtrlBCore
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b", category: "InputSource")

/// 현재 활성 키보드 입력 소스가 IME(Input Method)인지 판별한다.
/// kTISTypeKeyboardInputMode이면 IME → 리매핑 필요
/// kTISTypeKeyboardLayout이면 단순 키맵 (ABC, AZERTY 등) → 리매핑 불필요
func isInputMethodActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let typePtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceType) else {
        return false
    }
    let sourceType = Unmanaged<CFString>.fromOpaque(typePtr).takeUnretainedValue() as String
    return isInputMethod(sourceType)
}

/// 디버그용: 현재 입력 소스 정보를 로그로 출력한다.
/// isKoreanInputSourceActive()가 false를 반환할 때 호출하여 누락 입력기를 조기에 발견한다.
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
