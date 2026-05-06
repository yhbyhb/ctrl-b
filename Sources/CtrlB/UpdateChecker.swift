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
    func checkInBackground()
}

final class UpdateChecker: UpdateChecking {
    static let releasesURL = URL(string: "https://github.com/yhbyhb/ctrl-b/releases/latest")!
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

    func checkInBackground() {
        guard !isChecking else { return }
        isChecking = true

        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ctrl-b/\(currentVersion)", forHTTPHeaderField: "User-Agent")

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }
            guard let data, error == nil else {
                log.info("Update check failed: \(String(describing: error))")
                DispatchQueue.main.async { self.isChecking = false }
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                log.info("Update check HTTP \(http.statusCode)")
                DispatchQueue.main.async { self.isChecking = false }
                return
            }
            guard
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let tagName = json["tag_name"] as? String
            else {
                log.info("Update check: unexpected response format")
                DispatchQueue.main.async { self.isChecking = false }
                return
            }
            let raw = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
            let latest = raw.components(separatedBy: "-").first ?? raw
            let newResult: UpdateResult = isNewerVersion(latest, than: self.currentVersion)
                ? .available(latestVersion: latest)
                : .upToDate
            DispatchQueue.main.async {
                self.result = newResult
                self.isChecking = false
                log.info("Update check complete: \(String(describing: newResult))")
            }
        }.resume()
    }
}
