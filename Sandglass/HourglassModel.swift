import Observation
import QuartzCore
import UIKit

enum SandStatus: Equatable {
    /// The upper bulb is empty: turn the hourglass over to start.
    case idle
    case running
    /// The phone is held sideways, so the sand rests, just like a real hourglass on its side.
    case pausedOnSide
    case pausedManually
    /// Sand is being reset by the Restart / Stop buttons.
    case pouring
}

/// The whole app state: how much sand is in each bulb, which way it falls, and the Pomodoro cycle.
///
/// The sand is the timer. A full bulb holds one phase's worth of time, and sand drains from
/// whichever bulb gravity puts on top at 1 / duration per second. Turning the phone over starts
/// the sand running the other way, so a finished phase is restarted simply by flipping the phone.
@MainActor
@Observable
final class HourglassModel {
    /// One model for the whole app, so the Lock Screen buttons (App Intents) can reach it.
    static let shared = HourglassModel()

    // MARK: Drawn every frame

    /// Share of the sand in the hourglass's own upper bulb (0...1).
    private(set) var topSand: Double = 0
    /// Gravity as the hourglass feels it, in its own coordinates (unit length).
    private(set) var localGravity = Vec.down
    /// On-screen rotation of the glass in radians; tapping it animates this by π.
    private(set) var rotation: Double = 0
    /// Seconds since launch, used to animate the falling grains.
    private(set) var clock: Double = 0

    // MARK: Drawn when they change

    private(set) var phase: Phase = .focus
    private(set) var completedFocus = 0
    private(set) var status: SandStatus = .idle
    private(set) var displaySeconds = 0
    /// True while the phone is upside down, so the text can turn to stay readable.
    private(set) var textUpsideDown = false
    /// The phase that just ended, until the next one starts (drives the "nice work" hint).
    private(set) var lastFinished: Phase?
    private(set) var isManuallyPaused = false

    // MARK: Internals

    private let motion = MotionService()
    @ObservationIgnored private var displayLink: CADisplayLink?
    @ObservationIgnored private var lastTimestamp: CFTimeInterval?
    @ObservationIgnored private var targetRotation: Double = 0
    /// +1 when sand falls towards the hourglass's own lower bulb, -1 the other way.
    @ObservationIgnored private var flowDirection = 1
    @ObservationIgnored private var isOnSide = false
    @ObservationIgnored private var lastScreenGravity = Vec.down
    @ObservationIgnored private var pourTarget: Double?
    /// While nothing is ticking (app suspended), when the sand was last brought up to date.
    @ObservationIgnored private var lastAdvance: Date?
    @ObservationIgnored private var isForeground = false
    /// Keeps the physics running behind the Lock Screen while a focus sound plays.
    @ObservationIgnored private var backgroundTimer: Timer?
    @ObservationIgnored private var lastBackgroundStep: Date?
    @ObservationIgnored private var finishedWaitingSince: Date?
    @ObservationIgnored private var lastBackgroundState: String = ""
    @ObservationIgnored private var askedForNotifications = false
    @ObservationIgnored private var wantsNotificationPrompt = false
    @ObservationIgnored private var liveActivity: LiveActivityController?

    private let defaults = UserDefaults.standard

    init() {
        Prefs.registerDefaults()
        restore()
        refreshStatus()
    }

    // MARK: Derived values

    /// Sand still waiting in whichever bulb is currently on top.
    var sourceSand: Double { flowDirection > 0 ? topSand : 1 - topSand }
    var phaseSeconds: Double { Prefs.seconds(for: phase) }
    var nextPhase: Phase { Self.transition(from: phase, completedFocus: completedFocus, countingFocus: true).phase }

    // MARK: Lifecycle

    private var isTicking: Bool { displayLink != nil || backgroundTimer != nil }

    private var liveActivityController: LiveActivityController {
        if let liveActivity { return liveActivity }
        let controller = LiveActivityController()
        liveActivity = controller
        return controller
    }

    func resume() {
        isForeground = true
        stopBackgroundLoop()
        motion.start()
        _ = liveActivityController
        catchUp()
        lastAdvance = nil
        defaults.removeObject(forKey: Key.suspendedAt)
        Feedback.cancelNotifications()
        refreshStatus()

        guard displayLink == nil else { return }
        let link = CADisplayLink(target: DisplayLinkTarget { [weak self] link in self?.tick(link) },
                                 selector: #selector(DisplayLinkTarget.fire(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 60, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = nil
    }

    func suspend() {
        isForeground = false
        displayLink?.invalidate()
        displayLink = nil
        UIApplication.shared.isIdleTimerDisabled = false

        if SoundEngine.shared.isRunning {
            // Background audio keeps the app awake, so the sand keeps following gravity:
            // flipping the locked phone still starts, reverses or pauses it.
            startBackgroundLoop()
        } else {
            goToSleep()
        }
        save()
        scheduleFinishNotification()
    }

    /// Nothing will tick until the app comes back; remember when, so the sand can catch up.
    private func goToSleep() {
        stopBackgroundLoop()
        motion.stop()
        lastAdvance = Date()
        save()
    }

    /// Brings the sand up to date after a stretch with nothing ticking.
    private func catchUp() {
        guard !isTicking, let last = lastAdvance else { return }
        let now = Date()
        if status == .running {
            advanceSand(by: now.timeIntervalSince(last), silently: true)
        }
        lastAdvance = now
        refreshStatus()
    }

    private func startBackgroundLoop() {
        guard backgroundTimer == nil else { return }
        lastBackgroundStep = Date()
        backgroundTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.backgroundTick()
            }
        }
    }

    private func stopBackgroundLoop() {
        backgroundTimer?.invalidate()
        backgroundTimer = nil
        lastBackgroundStep = nil
    }

    private func backgroundTick() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastBackgroundStep ?? now), 0), 1)
        lastBackgroundStep = now
        step(dt: dt)

        // Keep the "time's up" notification right when the sand changes direction or pauses.
        let state = "\(status)|\(flowDirection)|\(phase)"
        if state != lastBackgroundState {
            lastBackgroundState = state
            scheduleFinishNotification()
            save()
        }
        // Once the focus sound has faded out, iOS will suspend the app: stop cleanly first.
        if !SoundEngine.shared.isRunning {
            goToSleep()
            scheduleFinishNotification()
        }
    }

    private func scheduleFinishNotification() {
        Feedback.cancelNotifications()
        guard !isForeground, status == .running else { return }
        let next = nextPhase
        let title = phase == .focus ? "Focus session complete" : "Break's over"
        let body = phase == .focus
            ? "Time for a \(Prefs.minutes(for: next))-minute \(next == .longBreak ? "long " : "")break. Flip the hourglass when you're ready."
            : "Flip the hourglass to start your next focus session."
        Feedback.scheduleFinish(in: sourceSand * phaseSeconds, title: title, body: body)
    }

    // MARK: Lock Screen and widget buttons

    func handle(_ command: SessionCommand) {
        catchUp()
        switch command {
        case .start:
            if status == .idle { turnOver() }
        case .togglePause:
            if status == .idle { turnOver() } else { togglePause() }
        case .restart:
            restartPhase()
        case .stop:
            stopSession()
        case .skip:
            skipPhase()
        }

        guard !isTicking else { return }
        // Nothing is animating, so settle everything now and tell the Lock Screen.
        if let pour = pourTarget {
            topSand = pour
            pourTarget = nil
        }
        refreshStatus()
        lastAdvance = Date()
        if let snapshot = makeSnapshot() { liveActivityController.sync(snapshot) }

        // If a focus sound is chosen, start it and keep following gravity behind the Lock Screen.
        updateSound()
        if SoundEngine.shared.isRunning {
            motion.start()
            lastAdvance = nil
            startBackgroundLoop()
        }
        scheduleFinishNotification()
        save()
    }

    /// Turns the hourglass over. On screen this animates; with nothing ticking it happens at once.
    private func turnOver() {
        if isTicking {
            flipByTap()
        } else {
            targetRotation += .pi
            rotation = targetRotation
            flowDirection = -flowDirection
            localGravity = Vec(x: localGravity.x, y: -localGravity.y)
            lastFinished = nil
        }
    }

    // MARK: Actions

    /// Turns the hourglass over on screen, for when moving the phone isn't convenient.
    func flipByTap() {
        Feedback.tap()
        targetRotation += .pi
    }

    func togglePause() {
        isManuallyPaused.toggle()
        refreshStatus()
    }

    /// Refills the upper bulb so the current phase starts over.
    func restartPhase() {
        isManuallyPaused = false
        lastFinished = nil
        pourTarget = flowDirection > 0 ? 1 : 0
        refreshStatus()
    }

    /// Drops all the sand into the lower bulb, ending the session without finishing the phase.
    func stopSession() {
        isManuallyPaused = false
        pourTarget = flowDirection > 0 ? 0 : 1
        refreshStatus()
    }

    func skipPhase() {
        let next = Self.transition(from: phase, completedFocus: completedFocus, countingFocus: false)
        phase = next.phase
        completedFocus = next.completedFocus
        lastFinished = nil
        stopSession()
    }

    func resetCycle() {
        phase = .focus
        completedFocus = 0
        lastFinished = nil
        stopSession()
    }

    // MARK: Frame loop

    private func tick(_ link: CADisplayLink) {
        let now = link.targetTimestamp
        let dt = min(max(now - (lastTimestamp ?? now), 0), 0.25)
        lastTimestamp = now
        step(dt: dt)
    }

    /// One step of the simulation, from the display link on screen or the background timer.
    private func step(dt: Double) {
        clock += dt

        // 1. Animate a tap-flip.
        if rotation != targetRotation {
            rotation += (targetRotation - rotation) * (1 - exp(-dt * 8))
            if abs(targetRotation - rotation) < 0.002 {
                rotation = targetRotation
                // Keep the angles small; the drawing is identical every full turn.
                let turns = (rotation / (2 * .pi)).rounded(.down) * 2 * .pi
                rotation -= turns
                targetRotation -= turns
            }
        }

        // 2. Work out gravity. Flat on a table there's no useful direction in the screen's plane,
        //    so keep the last one: the sand carries on as if the phone were still upright.
        let raw = motion.screenGravity
        let screenGravity: Vec
        if raw.length > 0.35 {
            screenGravity = raw.normalized
            lastScreenGravity = screenGravity
        } else {
            screenGravity = lastScreenGravity
        }
        if screenGravity.y < -0.6, !textUpsideDown { textUpsideDown = true }
        if screenGravity.y > 0.6, textUpsideDown { textUpsideDown = false }

        let target = screenGravity.rotated(by: -rotation)
        let blend = 1 - exp(-dt * 14)
        let smoothed = localGravity + (target - localGravity) * blend
        localGravity = smoothed.length > 0.2 ? smoothed.normalized : target

        // 3. Move sand.
        isOnSide = abs(localGravity.y) < 0.42
        if !isOnSide {
            let direction = localGravity.y > 0 ? 1 : -1
            if direction != flowDirection {
                flowDirection = direction
                if sourceSand > 0.01, pourTarget == nil { Feedback.sandTurned() }
            }
        }

        if let pour = pourTarget {
            let step = 1.6 * dt
            if abs(pour - topSand) <= step {
                topSand = pour
                pourTarget = nil
            } else {
                topSand += pour > topSand ? step : -step
            }
        } else if !isOnSide && !isManuallyPaused {
            advanceSand(by: dt, silently: false)
        }

        refreshStatus()

        // Side effects that need a running app (so they live here, not in refreshStatus, which also runs in init).
        if isForeground {
            let keepAwake = Prefs.keepAwake && status == .running
            if UIApplication.shared.isIdleTimerDisabled != keepAwake {
                UIApplication.shared.isIdleTimerDisabled = keepAwake
            }
        }
        updateSound()
        if wantsNotificationPrompt {
            wantsNotificationPrompt = false
            Feedback.requestNotificationPermission()
        }
        if let snapshot = makeSnapshot() {
            liveActivityController.sync(snapshot)
        }
    }

    /// Focus sounds play while a session is on, quieter while paused, and for a few minutes after
    /// a phase ends so that flipping the locked phone can still start the next one.
    private func updateSound() {
        let sound = FocusSound(rawValue: Prefs.focusSoundName) ?? .off
        var active = false
        switch status {
        case .running, .pausedOnSide, .pausedManually, .pouring:
            active = true
            finishedWaitingSince = nil
        case .idle:
            if lastFinished != nil {
                let since = finishedWaitingSince ?? Date()
                finishedWaitingSince = since
                active = Date().timeIntervalSince(since) < 5 * 60
            }
        }
        SoundEngine.shared.update(sound: sound,
                                  active: active,
                                  flowing: status == .running,
                                  volume: Float(Prefs.focusVolume))
    }

    /// The session as the Lock Screen and widgets show it: always upright, sand draining from the top.
    private func makeSnapshot() -> SessionSnapshot? {
        let mode: SessionSnapshot.Mode
        switch status {
        case .pouring: return nil
        case .running: mode = .running
        case .pausedOnSide, .pausedManually: mode = .paused
        case .idle: mode = lastFinished == nil ? .idle : .finished
        }
        let total = phaseSeconds
        let remaining = mode == .idle || mode == .finished ? 0 : sourceSand * total
        let now = Date()
        return SessionSnapshot(mode: mode,
                               phase: phase,
                               nextPhase: nextPhase,
                               lastFinished: lastFinished,
                               startDate: now.addingTimeInterval(remaining - total),
                               endDate: now.addingTimeInterval(remaining),
                               remaining: remaining,
                               total: total,
                               completedFocus: completedFocus,
                               sessionsPerCycle: Prefs.longBreakEvery)
    }

    private func advanceSand(by seconds: Double, silently: Bool) {
        guard seconds > 0 else { return }
        let amount = seconds / phaseSeconds
        if flowDirection > 0 {
            guard topSand > 0 else { return }
            topSand = max(0, topSand - amount)
            if topSand <= 1e-7 { topSand = 0; finishPhase(silently: silently) }
        } else {
            guard topSand < 1 else { return }
            topSand = min(1, topSand + amount)
            if topSand >= 1 - 1e-7 { topSand = 1; finishPhase(silently: silently) }
        }
    }

    private func finishPhase(silently: Bool) {
        let finished = phase
        let next = Self.transition(from: phase, completedFocus: completedFocus, countingFocus: true)
        phase = next.phase
        completedFocus = next.completedFocus
        lastFinished = finished
        isManuallyPaused = false
        if !silently { Feedback.phaseFinished() }
    }

    private static func transition(from phase: Phase, completedFocus: Int, countingFocus: Bool) -> (phase: Phase, completedFocus: Int) {
        switch phase {
        case .focus:
            let done = completedFocus + (countingFocus ? 1 : 0)
            return (done >= Prefs.longBreakEvery ? .longBreak : .shortBreak, done)
        case .shortBreak:
            return (.focus, completedFocus)
        case .longBreak:
            return (.focus, 0)
        }
    }

    private func refreshStatus() {
        let newStatus: SandStatus
        if pourTarget != nil {
            newStatus = .pouring
        } else if sourceSand <= 0 {
            newStatus = .idle
        } else if isManuallyPaused {
            newStatus = .pausedManually
        } else if isOnSide {
            newStatus = .pausedOnSide
        } else {
            newStatus = .running
        }

        if newStatus != status {
            if newStatus == .running {
                lastFinished = nil
                if !askedForNotifications {
                    askedForNotifications = true
                    wantsNotificationPrompt = true
                }
            }
            status = newStatus
        }

        let seconds = newStatus == .idle
            ? Int(phaseSeconds)
            : Int((sourceSand * phaseSeconds - 1e-6).rounded(.up))
        if seconds != displaySeconds { displaySeconds = max(0, seconds) }
    }

    // MARK: Persistence

    private enum Key {
        static let topSand = "state.topSand"
        static let phase = "state.phase"
        static let completed = "state.completedFocus"
        static let direction = "state.flowDirection"
        static let rotation = "state.rotation"
        static let paused = "state.paused"
        static let suspendedAt = "state.suspendedAt"
        static let onSide = "state.onSide"
        static let askedNotifications = "state.askedNotifications"
    }

    private func save() {
        defaults.set(pourTarget ?? topSand, forKey: Key.topSand)
        defaults.set(phase.rawValue, forKey: Key.phase)
        defaults.set(completedFocus, forKey: Key.completed)
        defaults.set(flowDirection, forKey: Key.direction)
        defaults.set(targetRotation, forKey: Key.rotation)
        defaults.set(isManuallyPaused, forKey: Key.paused)
        defaults.set(lastAdvance?.timeIntervalSince1970, forKey: Key.suspendedAt)
        defaults.set(isOnSide, forKey: Key.onSide)
        defaults.set(askedForNotifications, forKey: Key.askedNotifications)
    }

    private func restore() {
        guard defaults.object(forKey: Key.phase) != nil else { return }
        topSand = min(1, max(0, defaults.double(forKey: Key.topSand)))
        phase = Phase(rawValue: defaults.string(forKey: Key.phase) ?? "") ?? .focus
        completedFocus = defaults.integer(forKey: Key.completed)
        flowDirection = defaults.integer(forKey: Key.direction) < 0 ? -1 : 1
        targetRotation = defaults.double(forKey: Key.rotation)
        rotation = targetRotation
        localGravity = Vec.down.rotated(by: -rotation)
        isManuallyPaused = defaults.bool(forKey: Key.paused)
        isOnSide = defaults.bool(forKey: Key.onSide)
        askedForNotifications = defaults.bool(forKey: Key.askedNotifications)
        let stamp = defaults.double(forKey: Key.suspendedAt)
        lastAdvance = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }
}

/// CADisplayLink retains its target, so this small object holds the model weakly.
@MainActor
private final class DisplayLinkTarget: NSObject {
    private let handler: @MainActor (CADisplayLink) -> Void

    init(_ handler: @escaping @MainActor (CADisplayLink) -> Void) {
        self.handler = handler
    }

    @objc func fire(_ link: CADisplayLink) {
        handler(link)
    }
}
