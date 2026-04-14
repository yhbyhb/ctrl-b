import Foundation

/// 리매핑 횟수 및 절약 시간 집계 (UserDefaults 영구 저장)
public final class StatisticsManager {
    private let defaults: UserDefaults
    private let countKey = "remapCount"
    private let timeSavedKey = "timeSaved"
    private let todayCountKey = "todayRemapCount"
    private let todayDateKey = "todayDate"

    /// 리매핑 1회당 절약되는 시간 추정값 (초)
    /// 입력기 전환(~3초) + 재입력(~0.5초)
    public static let secondsPerRemap: Double = 3.5

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - 누계

    public var remapCount: Int {
        defaults.integer(forKey: countKey)
    }

    public var timeSavedSeconds: Double {
        defaults.double(forKey: timeSavedKey)
    }

    // MARK: - 오늘

    public var todayRemapCount: Int {
        resetTodayIfNeeded()
        return defaults.integer(forKey: todayCountKey)
    }

    public var todayTimeSavedSeconds: Double {
        Double(todayRemapCount) * Self.secondsPerRemap
    }

    // MARK: - 기록

    public func recordRemap() {
        defaults.set(remapCount + 1, forKey: countKey)
        defaults.set(timeSavedSeconds + Self.secondsPerRemap, forKey: timeSavedKey)

        resetTodayIfNeeded()
        defaults.set(defaults.integer(forKey: todayCountKey) + 1, forKey: todayCountKey)
    }

    public func reset() {
        defaults.set(0, forKey: countKey)
        defaults.set(0.0, forKey: timeSavedKey)
        defaults.set(0, forKey: todayCountKey)
        defaults.set(todayString, forKey: todayDateKey)
    }

    // MARK: - 포맷

    public var formattedTimeSaved: String {
        formatted(seconds: timeSavedSeconds)
    }

    public var formattedTodayTimeSaved: String {
        formatted(seconds: todayTimeSavedSeconds)
    }

    // MARK: - Private

    private var todayString: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func resetTodayIfNeeded() {
        let saved = defaults.string(forKey: todayDateKey) ?? ""
        if saved != todayString {
            defaults.set(0, forKey: todayCountKey)
            defaults.set(todayString, forKey: todayDateKey)
        }
    }

    private func formatted(seconds: Double) -> String {
        if seconds < 60 {
            return String(format: "%.1f초", seconds)
        } else if seconds < 3600 {
            return String(format: "%.1f분", seconds / 60)
        } else {
            return String(format: "%.1f시간", seconds / 3600)
        }
    }
}
