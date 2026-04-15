import Carbon
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b-helper", category: "InputSource")

/// 현재 활성 키보드 입력 소스가 한글인지 2단계로 판별한다.
/// 1차: kTISPropertyInputSourceLanguages 배열에 "ko" 포함 여부
/// 2차: kTISPropertyInputSourceID 문자열에 "Korean" 포함 여부 (language 배열 누락 대비)
func isKoreanInputSourceActive() -> Bool {
    guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
        return false
    }

    // 1차: language 배열
    if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
        let languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
        if languages.contains("ko") {
            return true
        }
    }

    // 2차: input source ID
    if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        if id.localizedCaseInsensitiveContains("korean") {
            return true
        }
    }

    return false
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
