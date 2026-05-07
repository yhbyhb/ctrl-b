import XCTest
@testable import CtrlB
@testable import CtrlBCore

final class UpdateCheckerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

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

    func test_checkInBackground_withUnparseableTag_keepsUnknown() {
        let expectation = expectation(description: "result updated")
        let session = makeSession(tagName: "nightly")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if case .unknown = sut.result {
                expectation.fulfill()
            } else {
                XCTFail("Expected .unknown for non-numeric tag, got \(sut.result)")
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

    // MARK: - Completion callback

    func test_completion_onUpToDate_firesWithUpToDate() {
        let expectation = expectation(description: "completion fired")
        let session = makeSession(tagName: "v1.1.0")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground { result in
            XCTAssertTrue(Thread.isMainThread,
                          "Completion must be delivered on the main thread")
            if case .upToDate = result {
                expectation.fulfill()
            } else {
                XCTFail("Expected .upToDate, got \(result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_completion_onAvailable_firesWithVersion() {
        let expectation = expectation(description: "completion fired")
        let session = makeSession(tagName: "v1.9.0")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground { result in
            if case .available(let version) = result {
                XCTAssertEqual(version, "1.9.0")
                expectation.fulfill()
            } else {
                XCTFail("Expected .available, got \(result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_completion_onInvalidResponse_firesWithCachedUnknown() {
        let expectation = expectation(description: "completion fired")
        let session = makeSession(responseData: Data("not json".utf8))
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground { result in
            XCTAssertTrue(Thread.isMainThread,
                          "Failure-path completion must also be delivered on main")
            // Result stays as .unknown rather than being silently
            // swallowed; the caller still gets a callback so the UI can react.
            if case .unknown = result {
                expectation.fulfill()
            } else {
                XCTFail("Expected .unknown on invalid response, got \(result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_completion_onValidJSONWithoutTagName_firesWithUnknown() {
        // Distinct from invalid JSON: the body parses, but the GitHub
        // response shape is unexpected (e.g., an error envelope without
        // a tag_name field). Hits the same finishUnknown path but a
        // different guard branch.
        let expectation = expectation(description: "completion fired")
        let session = makeSession(responseData: Data("{\"message\":\"Not Found\"}".utf8))
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground { result in
            if case .unknown = result {
                expectation.fulfill()
            } else {
                XCTFail("Expected .unknown when tag_name is missing, got \(result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_completion_onUnparseableTag_firesWithUnknown() {
        // 'nightly' survives prefix stripping but has no numeric components,
        // so the tag-validity guard rejects it. The companion sut.result
        // test exists; this one verifies the completion contract too.
        let expectation = expectation(description: "completion fired")
        let session = makeSession(tagName: "nightly")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground { result in
            if case .unknown = result {
                expectation.fulfill()
            } else {
                XCTFail("Expected .unknown for unparseable tag, got \(result)")
            }
        }
        waitForExpectations(timeout: 2)
    }

    func test_completion_failureAfterPriorSuccess_deliversUnknownNotCached() {
        let session = makeSession(tagName: "v1.1.0")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        let firstExpectation = expectation(description: "first check")
        sut.checkInBackground { result in
            if case .upToDate = result {
                firstExpectation.fulfill()
            } else {
                XCTFail("Expected first .upToDate, got \(result)")
            }
        }
        wait(for: [firstExpectation], timeout: 2)

        // Now flip the mock to return an HTTP failure for the next request.
        MockURLProtocol.setHandler { _ in (500, Data()) }

        let secondExpectation = expectation(description: "second check")
        sut.checkInBackground { result in
            // Regression guard: a failure must communicate .unknown rather
            // than echo the previously cached .upToDate.
            if case .unknown = result {
                secondExpectation.fulfill()
            } else {
                XCTFail("Expected .unknown after failure, got cached \(result)")
            }
        }
        wait(for: [secondExpectation], timeout: 2)
    }

    func test_completion_onReentry_firesImmediatelyWithCurrentResult() {
        let firstExpectation = expectation(description: "first completion")
        let session = makeSession(tagName: "v1.9.0")
        let sut = UpdateChecker(session: session, currentVersion: "1.1.0")

        sut.checkInBackground { _ in
            firstExpectation.fulfill()
        }
        // Immediate re-entry while the first request is still in flight.
        var reentryFired = false
        var reentryOnMainThread = false
        sut.checkInBackground { _ in
            reentryFired = true
            reentryOnMainThread = Thread.isMainThread
        }

        waitForExpectations(timeout: 2)
        XCTAssertTrue(reentryFired,
                      "Re-entry call must still fire its completion (with the cached result) instead of silently dropping it")
        XCTAssertTrue(reentryOnMainThread,
                      "Re-entry path must also dispatch completion to main")
    }
}

// MARK: - Helpers

private func makeSession(tagName: String) -> URLSession {
    makeSession(responseData: Data("{\"tag_name\":\"\(tagName)\"}".utf8))
}

private func makeSession(responseData: Data) -> URLSession {
    MockURLProtocol.setHandler { _ in (200, responseData) }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

private final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var handler: (URLRequest) -> (Int, Data) = { _ in (200, Data()) }

    static func setHandler(_ newHandler: @escaping (URLRequest) -> (Int, Data)) {
        lock.lock(); defer { lock.unlock() }
        handler = newHandler
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        handler = { _ in (200, Data()) }
    }

    private static func currentHandler() -> (URLRequest) -> (Int, Data) {
        lock.lock(); defer { lock.unlock() }
        return handler
    }

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (statusCode, data) = Self.currentHandler()(request)
        guard let url = request.url,
              let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
