import Foundation
import Observation
import UserNotifications
import WatchKit

/// The watch's own hourglass. The sand is the timer, as on the iPhone, but it ignores the
/// watch's motion (a wrist never keeps still): sand always falls down the screen, and a tap
/// or the play button turns the glass over.
@MainActor
@Observable
final class WatchModel {
    enum Status { case idle, running, paused }

    private(set) var topSand: Double = 0
    private(set) var localGravity = Vec.down
    private(set) var rotation: Double = 0
    private(set) var clock: Double = 0
    private(set) var phase: Phase = .focus
    private(set) var completedFocus = 0
    private(set) var status: Status = .idle
    private(set) var isManuallyPaused = false
    private(set) var lastFinished: Phase?

    /// How many times the glass has been turned over; each turn rotates it by π.
    @ObservationIgnored private var turns = 0

    private var targetRotation: Double { Double(turns) * .pi }
    @ObservationIgnored private var flowDirection = 1
    @ObservationIgnored private var isOnSide = false
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var lastStep: Date?
    @ObservationIgnored private var lastAdvance: Date?
    @ObservationIgnored private var askedForNotifications = false
    @ObservationIgnored private let defaults = UserDefaults.standard

    init() {
        Prefs.registerDefaults()
        restore()
        refreshStatus()
    }

    var phaseSeconds: Double { Prefs.seconds(for: phase) }
    var sourceSand: Double { flowDirection > 0 ? topSand : 1 - topSand }
    var remainingSeconds: Double { status == .idle ? phaseSeconds : sourceSand * phaseSeconds }
    var endDate: Date { Date().addingTimeInterval(sourceSand * phaseSeconds) }

    // MARK: Lifecycle

    func resume() {
        if let last = lastAdvance, status == .running {
            advanceSand(by: Date().timeIntervalSince(last), silently: true)
        }
        lastAdvance = nil
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        refreshStatus()
        guard timer == nil else { return }
        lastStep = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.step()
            }
        }
    }

    func suspend() {
        timer?.invalidate()
        timer = nil
        lastAdvance = Date()
        save()
        scheduleNotification()
    }

    // MARK: Actions

    func flip() {
        WKInterfaceDevice.current().play(.click)
        isManuallyPaused = false
        turns += 1
    }

    func togglePause() {
        if status == .idle {
            flip()
            return
        }
        isManuallyPaused.toggle()
        WKInterfaceDevice.current().play(isManuallyPaused ? .stop : .start)
        refreshStatus()
    }

    func restart() {
        isManuallyPaused = false
        lastFinished = nil
        topSand = flowDirection > 0 ? 1 : 0
        refreshStatus()
    }

    func stop() {
        isManuallyPaused = false
        topSand = flowDirection > 0 ? 0 : 1
        refreshStatus()
    }

    // MARK: Simulation

    private func step() {
        let now = Date()
        let dt = min(max(now.timeIntervalSince(lastStep ?? now), 0), 0.25)
        lastStep = now
        clock += dt

        // Gravity always points down the screen; only the glass turns, when it is flipped.
        rotation += (targetRotation - rotation) * (1 - exp(-dt * 8))
        if abs(targetRotation - rotation) < 0.001 { rotation = targetRotation }
        localGravity = Vec.down.rotated(by: -rotation)

        // Briefly true while the glass is mid-turn, so the sand waits until it lands.
        isOnSide = abs(localGravity.y) < 0.42
        if !isOnSide {
            let direction = localGravity.y > 0 ? 1 : -1
            if direction != flowDirection {
                flowDirection = direction
                if sourceSand > 0.01 { WKInterfaceDevice.current().play(.start) }
            }
            if !isManuallyPaused { advanceSand(by: dt, silently: false) }
        }
        refreshStatus()
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
        lastFinished = phase
        switch phase {
        case .focus:
            completedFocus += 1
            phase = completedFocus >= Prefs.longBreakEvery ? .longBreak : .shortBreak
        case .shortBreak:
            phase = .focus
        case .longBreak:
            phase = .focus
            completedFocus = 0
        }
        isManuallyPaused = false
        if !silently, Prefs.hapticsOn { WKInterfaceDevice.current().play(.success) }
    }

    private func refreshStatus() {
        let newStatus: Status
        if sourceSand <= 0 {
            newStatus = .idle
        } else if isManuallyPaused || isOnSide {
            newStatus = .paused
        } else {
            newStatus = .running
        }
        if newStatus != status {
            if newStatus == .running {
                lastFinished = nil
                if !askedForNotifications {
                    askedForNotifications = true
                    Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
                }
            }
            status = newStatus
        }
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard status == .running else { return }
        let content = UNMutableNotificationContent()
        content.title = phase == .focus ? "Focus session complete" : "Break's over"
        content.body = phase == .focus ? "Tap the hourglass to start your break." : "Tap the hourglass to start focusing again."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, sourceSand * phaseSeconds), repeats: false)
        center.add(UNNotificationRequest(identifier: "sandglass.watch.finished", content: content, trigger: trigger))
    }

    // MARK: Persistence

    private func save() {
        defaults.set(topSand, forKey: "watch.topSand")
        defaults.set(phase.rawValue, forKey: "watch.phase")
        defaults.set(completedFocus, forKey: "watch.completed")
        defaults.set(flowDirection, forKey: "watch.direction")
        defaults.set(turns, forKey: "watch.turns")
        defaults.set(isManuallyPaused, forKey: "watch.paused")
        defaults.set(isOnSide, forKey: "watch.onSide")
        defaults.set(lastAdvance?.timeIntervalSince1970, forKey: "watch.lastAdvance")
        defaults.set(askedForNotifications, forKey: "watch.askedNotifications")
    }

    private func restore() {
        guard defaults.object(forKey: "watch.phase") != nil else { return }
        topSand = min(1, max(0, defaults.double(forKey: "watch.topSand")))
        phase = Phase(rawValue: defaults.string(forKey: "watch.phase") ?? "") ?? .focus
        completedFocus = defaults.integer(forKey: "watch.completed")
        flowDirection = defaults.integer(forKey: "watch.direction") < 0 ? -1 : 1
        turns = defaults.integer(forKey: "watch.turns")
        rotation = targetRotation
        localGravity = Vec.down.rotated(by: -rotation)
        isManuallyPaused = defaults.bool(forKey: "watch.paused")
        isOnSide = defaults.bool(forKey: "watch.onSide")
        askedForNotifications = defaults.bool(forKey: "watch.askedNotifications")
        let stamp = defaults.double(forKey: "watch.lastAdvance")
        lastAdvance = stamp > 0 ? Date(timeIntervalSince1970: stamp) : nil
    }
}
