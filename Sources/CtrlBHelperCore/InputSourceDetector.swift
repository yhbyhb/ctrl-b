import Foundation

/// macOS 입력 소스 타입 상수
/// - kTISTypeKeyboardLayout: 단순 키맵 (ABC, AZERTY 등) — IME 아님
/// - kTISTypeKeyboardInputMode: IME 기반 입력 소스 (한국어, 중국어, 일본어 등)
public let inputMethodType = "TISTypeKeyboardInputMode"
public let keyboardLayoutType = "TISTypeKeyboardLayout"

/// 입력 소스 타입이 IME(Input Method)인지 판별
/// IME 기반 입력 소스는 interpretKeyEvents에서 이벤트를 소비할 수 있으므로 리매핑 대상
public func isInputMethod(_ sourceType: String) -> Bool {
    sourceType == inputMethodType
}
