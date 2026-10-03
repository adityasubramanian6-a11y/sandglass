import ActivityKit
import Foundation
import WidgetKit

/// Mirrors the session onto the Lock Screen / Dynamic Island (a Live Activity) and the widgets.
/// It is fed a snapshot every frame but only talks to the system when something visible changed.
@MainActor
final class LiveActivityController {
    private var activity: Activity<SandglassActivityAttributes>?
    private var lastSent: SessionSnapshot?

    init() {
        // Pick up an activity left over from a previous launch.
        let existing = Activity<SandglassActivityAttributes>.activities
        activity = existing.first
        for extra in existing.dropFirst() {
            Task { await extra.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func sync(_ snapshot: SessionSnapshot) {
        if let lastSent, lastSent.isEquivalent(to: snapshot) { return }
        lastSent = snapshot

        SharedStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()

        switch snapshot.mode {
        case .running, .paused:
            startOrUpdate(snapshot)
        case .finished:
            end(snapshot, dismissAfter: 15 * 60)
        case .idle:
            end(snapshot, dismissAfter: nil)
        }
    }

    private func content(for snapshot: SessionSnapshot) -> ActivityContent<SessionSnapshot> {
        // Once the countdown passes its end the activity goes stale, and the views switch to
        // "time's up" by themselves, even if the app is suspended and can't send an update.
        ActivityContent(state: snapshot, staleDate: snapshot.mode == .running ? snapshot.endDate : nil)
    }

    private func startOrUpdate(_ snapshot: SessionSnapshot) {
        let content = content(for: snapshot)
        if let activity, activity.activityState == .active {
            Task { await activity.update(content) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(attributes: SandglassActivityAttributes(), content: content, pushType: nil)
    }

    private func end(_ snapshot: SessionSnapshot, dismissAfter seconds: TimeInterval?) {
        guard let activity else { return }
        self.activity = nil
        let content = ActivityContent(state: snapshot, staleDate: nil)
        let policy: ActivityUIDismissalPolicy
        if let seconds {
            policy = .after(Date().addingTimeInterval(seconds))
        } else {
            policy = .immediate
        }
        Task { await activity.end(content, dismissalPolicy: policy) }
    }
}
