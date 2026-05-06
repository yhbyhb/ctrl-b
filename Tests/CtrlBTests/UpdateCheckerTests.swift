import XCTest
@testable import CtrlB
@testable import CtrlBCore

final class UpdateCheckerTests: XCTestCase {
    func test_isNewerVersion_majorBump() {
        XCTAssertTrue(isNewerVersion("2.0.0", than: "1.9.9"))
    }

    func test_isNewerVersion_minorBump() {
        XCTAssertTrue(isNewerVersion("1.2.0", than: "1.1.0"))
    }

    func test_isNewerVersion_patchBump() {
        XCTAssertTrue(isNewerVersion("1.1.1", than: "1.1.0"))
    }

    func test_isNewerVersion_sameVersion_returnsFalse() {
        XCTAssertFalse(isNewerVersion("1.1.0", than: "1.1.0"))
    }

    func test_isNewerVersion_olderVersion_returnsFalse() {
        XCTAssertFalse(isNewerVersion("1.0.0", than: "1.1.0"))
    }

    func test_isNewerVersion_missingPatch_treatedAsZero() {
        XCTAssertFalse(isNewerVersion("1.1", than: "1.1.0"))
        XCTAssertTrue(isNewerVersion("1.2", than: "1.1.0"))
    }

    func test_checkInBackground_withNewerVersion_setsAvailable() {
        let expectation = expectation(description: "result updated")
        let session = makeSession(tagName: "v1.9.0")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if case .available(let version) = sut.result {
                XCTAssertEqual(version, "1.9.0")
                expectation.fulfill()
            } else {
                XCTFail("Expected .available, got \(sut.result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_checkInBackground_withSameVersion_setsUpToDate() {
        let expectation = expectation(description: "result updated")
        let session = makeSession(tagName: "v1.1.0")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if case .upToDate = sut.result {
                expectation.fulfill()
            } else {
                XCTFail("Expected .upToDate, got \(sut.result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_checkInBackground_withInvalidResponse_keepsUnknown() {
        let expectation = expectation(description: "timeout passes")
        let session = makeSession(responseData: Data("not json".utf8))
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if case .unknown = sut.result {
                expectation.fulfill()
            } else {
                XCTFail("Expected .unknown, got \(sut.result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_checkInBackground_withPreReleaseTag_stripsPreReleaseSuffix() {
        let expectation = expectation(description: "result updated")
        let session = makeSession(tagName: "v1.9.0-beta.1")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if case .available(let version) = sut.result {
                XCTAssertEqual(version, "1.9.0")
                expectation.fulfill()
            } else {
                XCTFail("Expected .available(\"1.9.0\"), got \(sut.result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_checkInBackground_concurrentCall_ignored() {
        let session = makeSession(tagName: "v1.9.0")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground()
        sut.checkInBackground()

        // second call should be a no-op — no assertion needed beyond "no crash"
    }
}

// MARK: - Helpers

private func makeSession(tagName: String) -> URLSession {
    makeSession(responseData: Data("{\"tag_name\":\"\(tagName)\"}".utf8))
}

private func makeSession(responseData: Data) -> URLSession {
    MockURLProtocol.responseData = responseData
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private final class MockURLProtocol: URLProtocol {
    static var responseData: Data = Data()

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: MockURLProtocol.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
