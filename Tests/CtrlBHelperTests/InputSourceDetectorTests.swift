import XCTest
@testable import CtrlBHelperCore

final class InputSourceDetectorTests: XCTestCase {

    // MARK: - isInputMethod

    func test_keyboardInputMode_isIME() {
        XCTAssertTrue(isInputMethod("TISTypeKeyboardInputMode"))
    }

    func test_keyboardLayout_isNotIME() {
        XCTAssertFalse(isInputMethod("TISTypeKeyboardLayout"))
    }

    func test_empty_isNotIME() {
        XCTAssertFalse(isInputMethod(""))
    }

    func test_unknownType_isNotIME() {
        XCTAssertFalse(isInputMethod("TISTypeUnknown"))
    }
}
