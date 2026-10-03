import Foundation

/// User settings, stored in UserDefaults so SwiftUI's @AppStorage and the model share them.
enum Prefs {
    static let focusMinutesKey = "focusMinutes"
    static let shortBreakMinutesKey = "shortBreakMinutes"
    static let longBreakMinutesKey = "longBreakMinutes"
    static let longBreakEveryKey = "longBreakEvery"
    static let soundKey = "soundOn"
    static let hapticsKey = "hapticsOn"
    static let keepAwakeKey = "keepAwake"

    static let defaultFocusMinutes = 25
    static let defaultShortBreakMinutes = 5
    static let defaultLongBreakMinutes = 15
    static let defaultLongBreakEvery = 4

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            focusMinutesKey: defaultFocusMinutes,
            shortBreakMinutesKey: defaultShortBreakMinutes,
            longBreakMinutesKey: defaultLongBreakMinutes,
            longBreakEveryKey: defaultLongBreakEvery,
            soundKey: true,
            hapticsKey: true,
            keepAwakeKey: true,
        ])
    }

    static func minutes(for phase: Phase) -> Int {
        let key: String
        switch phase {
        case .focus: key = focusMinutesKey
        case .shortBreak: key = shortBreakMinutesKey
        case .longBreak: key = longBreakMinutesKey
        }
        return max(1, UserDefaults.standard.integer(forKey: key))
    }

    static func seconds(for phase: Phase) -> Double {
        Double(minutes(for: phase)) * 60
    }

    static var longBreakEvery: Int { max(1, UserDefaults.standard.integer(forKey: longBreakEveryKey)) }
    static var soundOn: Bool { UserDefaults.standard.bool(forKey: soundKey) }
    static var hapticsOn: Bool { UserDefaults.standard.bool(forKey: hapticsKey) }
    static var keepAwake: Bool { UserDefaults.standard.bool(forKey: keepAwakeKey) }
}
