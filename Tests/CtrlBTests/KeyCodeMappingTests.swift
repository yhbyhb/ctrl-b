import XCTest
@testable import CtrlBCore

final class KeyCodeMappingTests: XCTestCase {

    // MARK: - Primary key (tmux prefix)

    func test_keyCode11_mapsTo_b() {
        XCTAssertEqual(keyCodeToLowerASCII[11], 98)  // 'b'
    }

    func test_ctrlB_controlChar() {
        guard let ascii = keyCodeToLowerASCII[11] else {
            XCTFail("keyCode 11 not found"); return
        }
        XCTAssertEqual(ascii & 0x1F, 0x02)  // Ctrl+b = STX
    }

    // MARK: - All mapped values are lowercase ASCII (a–z)

    func test_allValues_areLowercaseASCII() {
        for (keyCode, ascii) in keyCodeToLowerASCII {
            XCTAssertTrue(
                ascii >= 97 && ascii <= 122,
                "keyCode \(keyCode) → \(ascii) is outside a-z range"
            )
        }
    }

    // MARK: - All 26 alphabet letters covered

    func test_allAlphabetLetters_covered() {
        let coveredASCII = Set(keyCodeToLowerASCII.values)
        let alphabet = Set<UInt8>(97...122)  // a–z
        let missing = alphabet.subtracting(coveredASCII).map { Character(UnicodeScalar($0)) }
        XCTAssertTrue(missing.isEmpty, "Missing alphabet mappings: \(missing)")
    }

    // MARK: - Individual key verification

    func test_keyCode0_a() { XCTAssertEqual(keyCodeToLowerASCII[0], 97)  }
    func test_keyCode6_z() { XCTAssertEqual(keyCodeToLowerASCII[6], 122)  }
    func test_keyCode12_q() { XCTAssertEqual(keyCodeToLowerASCII[12], 113)  }
    func test_keyCode14_e() { XCTAssertEqual(keyCodeToLowerASCII[14], 101)  }
    func test_keyCode17_t() { XCTAssertEqual(keyCodeToLowerASCII[17], 116)  }

    // MARK: - Unknown keyCode returns nil

    func test_unknownKeyCode_returnsNil() {
        XCTAssertNil(keyCodeToLowerASCII[99])
        XCTAssertNil(keyCodeToLowerASCII[-1])
    }

    // MARK: - Ctrl character calculation (ascii & 0x1F)

    func test_ctrlChar_a() {
        guard let ascii = keyCodeToLowerASCII[0] else { XCTFail("keyCode 0 not found"); return }
        XCTAssertEqual(ascii & 0x1F, 0x01)  // Ctrl+A = SOH
    }

    func test_ctrlChar_c() {
        guard let ascii = keyCodeToLowerASCII[8] else { XCTFail("keyCode 8 not found"); return }
        XCTAssertEqual(ascii & 0x1F, 0x03)  // Ctrl+C = ETX
    }
}
