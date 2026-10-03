import ActivityKit
import Foundation

/// What the Lock Screen, Dynamic Island and widgets need to know about the current session.
/// While sand runs, only the start and end dates are needed: the system animates the rest.
struct SessionSnapshot: Codable, Hashable {
    enum Mode: String, Codable, Hashable {
        /// Nothing running; flip the hourglass to start `phase`.
        case idle
        case running
        case paused
        /// `lastFinished` just ended; `phase` is the one that comes next.
        case finished
    }

    var mode: Mode
    var phase: Phase
    var nextPhase: Phase
    var lastFinished: Phase?
    /// When a full bulb would have started draining, so start...end spans the whole phase.
    var startDate: Date
    var endDate: Date
    /// Seconds left; used when the sand is not running.
    var remaining: Double
    var total: Double
    var completedFocus: Int
    var sessionsPerCycle: Int

    /// Share of the sand still in the upper bulb.
    var topFraction: Double { total > 0 ? min(1, max(0, remaining / total)) : 0 }

    /// The phase that just ended (or ends once the countdown reaches zero) and the one after it.
    func finishedAndUpcoming() -> (finished: Phase, upcoming: Phase) {
        mode == .finished ? (lastFinished ?? phase, phase) : (phase, nextPhase)
    }

    /// Close enough that the Lock Screen would look the same, so no update is needed.
    func isEquivalent(to other: SessionSnapshot) -> Bool {
        guard mode == other.mode, phase == other.phase, lastFinished == other.lastFinished,
              completedFocus == other.completedFocus, sessionsPerCycle == other.sessionsPerCycle,
              abs(total - other.total) < 0.5 else { return false }
        switch mode {
        case .running: return abs(endDate.timeIntervalSince(other.endDate)) < 1.5
        case .paused: return abs(remaining - other.remaining) < 1
        case .idle, .finished: return true
        }
    }

    static let preview = SessionSnapshot(
        mode: .running, phase: .focus, nextPhase: .shortBreak, lastFinished: nil,
        startDate: Date().addingTimeInterval(-9 * 60), endDate: Date().addingTimeInterval(16 * 60),
        remaining: 16 * 60, total: 25 * 60, completedFocus: 1, sessionsPerCycle: 4)
}

struct SandglassActivityAttributes: ActivityAttributes {
    typealias ContentState = SessionSnapshot
}

/// The latest snapshot, shared with the widget extension through the app group.
enum SharedStore {
    private static let key = "sandglass.snapshot"

    private static var defaults: UserDefaults? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "SandglassAppGroup") as? String,
              !group.isEmpty, !group.contains("$(") else { return nil }
        return UserDefaults(suiteName: group)
    }

    static func save(_ snapshot: SessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> SessionSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SessionSnapshot.self, from: data)
    }
}
