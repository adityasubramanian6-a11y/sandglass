import UIKit
import UserNotifications

/// Haptics, the chime and the "time's up" notification for when the app is in the background.
@MainActor
enum Feedback {
    private static let notificationID = "sandglass.phase-finished"

    /// A soft thunk when the sand starts running in a new direction.
    static func sandTurned() {
        guard Prefs.hapticsOn else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func tap() {
        guard Prefs.hapticsOn else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func phaseFinished() {
        if Prefs.hapticsOn {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        if Prefs.soundOn {
            SoundEngine.shared.playChime()
        }
    }

    static func requestNotificationPermission() {
        // The async form: a completion handler written here would be tied to the main actor but
        // called on a background queue, which can crash.
        Task { _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) }
    }

    static func scheduleFinish(in seconds: TimeInterval, title: String, body: String) {
        guard seconds >= 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = Prefs.soundOn ? UNNotificationSound(named: UNNotificationSoundName(Chime.current.fileName)) : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }
}
