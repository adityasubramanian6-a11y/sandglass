import AppIntents
import Foundation

/// What the Lock Screen and widget buttons can ask the app to do.
enum SessionCommand: String {
    /// Turn the hourglass over to start the next phase (only when the top bulb is empty).
    case start
    /// Pause or resume; starts the next phase if nothing is running.
    case togglePause
    case restart
    case stop
    case skip
}

/// Lets the intents below reach the app's model. The app sets `handler` when it launches.
/// Live Activity intents always run inside the app's process, so the widget extension,
/// which also compiles this file, never needs it.
@MainActor
enum SessionCommandCenter {
    static var handler: (@MainActor (SessionCommand) -> Void)?
}

struct StartSandIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Start the sand"
    static let description = IntentDescription("Turns the hourglass over and starts the next phase.")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionCommandCenter.handler?(.start)
        return .result()
    }
}

struct ToggleSandIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume the sand"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionCommandCenter.handler?(.togglePause)
        return .result()
    }
}

struct RestartSandIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Restart this phase"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionCommandCenter.handler?(.restart)
        return .result()
    }
}

struct StopSandIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop the sand"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionCommandCenter.handler?(.stop)
        return .result()
    }
}

struct SkipPhaseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip to the next phase"

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        SessionCommandCenter.handler?(.skip)
        return .result()
    }
}
