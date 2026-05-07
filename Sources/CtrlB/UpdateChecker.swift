import CtrlBCore
import Foundation
import os

private let log = Logger(subsystem: "com.yhbyhb.ctrl-b", category: "UpdateChecker")

enum UpdateResult {
    case unknown
    case upToDate
    case available(latestVersion: String)
}

protocol UpdateChecking: AnyObject {
    var result: UpdateResult { get }
    func checkInBackground(completion: ((UpdateResult) -> Void)?)
}

extension UpdateChecking {
    func checkInBackground() {
        checkInBackground(completion: nil)
    }
}

final class UpdateChecker: UpdateChecking {
    // swiftlint:disable:next force_unwrapping
    static let releasesURL = URL(string: "https://github.com/yhbyhb/ctrl-b/releases/latest")!
    // swiftlint:disable:next force_unwrapping
    private static let apiURL = URL(string: "https://api.github.com/repos/yhbyhb/ctrl-b/releases/latest")!

    private(set) var result: UpdateResult = .unknown
    private var isChecking = false
    private let session: URLSession
    private let currentVersion: String

    init(
        session: URLSession = .shared,
        currentVersion: String = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    ) {
        self.session = session
        self.currentVersion = currentVersion
    }

    func checkInBackground(completion: ((UpdateResult) -> Void)? = nil) {
        guard !isChecking else {
            // Re-entry while a check is in flight: deliver the cached result
            // on main so callers always observe completion off the call stack
            // (matches the success/failure paths).
            let cached = result
            DispatchQueue.main.async { completion?(cached) }
            return
        }
        isChecking = true

        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ctrl-b/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            let finishUnknown = { (reason: String) in
                log.info("Update check: \(reason, privacy: .public)")
                DispatchQueue.main.async {
                    // Reset to .unknown so that a transient failure isn't
                    // misreported as a stale cached .upToDate / .available.
                    self.result = .unknown
                    self.isChecking = false
                    completion?(.unknown)
                }
            }
            guard let data, error == nil else {
                finishUnknown("failed: \(String(describing: error))")
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                finishUnknown("HTTP \(http.statusCode)")
                return
            }
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tagName = json["tag_name"] as? String
            else {
                finishUnknown("unexpected response format")
                return
            }
            let raw = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let latest = raw.components(separatedBy: "-").first ?? raw
            // Guard against tags like "nightly" that survive prefix stripping but
            // contain no version components — comparing them would silently
            // report .upToDate, which is misleading.
            guard !latest.split(separator: ".").compactMap({ Int($0) }).isEmpty else {
                finishUnknown("unparseable version tag '\(tagName)'")
                return
            }
            let newResult: UpdateResult = isNewerVersion(latest, than: self.currentVersion)
                ? .available(latestVersion: latest)
                : .upToDate
            DispatchQueue.main.async {
                self.result = newResult
                self.isChecking = false
                log.info("Update check complete: \(String(describing: newResult))")
                completion?(newResult)
            }
        }.resume()
    }
}
