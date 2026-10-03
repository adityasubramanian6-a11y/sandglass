import SwiftUI

/// The countdown. While sand runs, the system ticks it every second without waking the app.
struct SessionTimerText: View {
    let snapshot: SessionSnapshot
    let isDone: Bool

    var body: some View {
        Group {
            if isDone {
                Text("0:00")
            } else if snapshot.mode == .running && snapshot.startDate < snapshot.endDate {
                Text(timerInterval: snapshot.startDate...snapshot.endDate, countsDown: true)
            } else if snapshot.mode == .paused {
                Text(SessionText.clock(snapshot.remaining))
            } else {
                Text(SessionText.clock(snapshot.total))
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Filled dots for the focus sessions done in this cycle, stacked vertically.
struct CycleDots: View {
    let snapshot: SessionSnapshot
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<max(1, snapshot.sessionsPerCycle), id: \.self) { index in
                Circle()
                    .fill(index < snapshot.completedFocus ? color : Color.white.opacity(0.2))
                    .frame(width: 7, height: 7)
            }
        }
    }
}

enum SessionText {
    static func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    static func headline(_ snapshot: SessionSnapshot, isDone: Bool) -> String {
        if isDone {
            return "\(snapshot.finishedAndUpcoming().finished.title) done"
        }
        switch snapshot.mode {
        case .running: return snapshot.phase.title
        case .paused: return "\(snapshot.phase.title) · paused"
        case .idle: return snapshot.phase.title
        case .finished: return "\(snapshot.finishedAndUpcoming().finished.title) done"
        }
    }

    static func detail(_ snapshot: SessionSnapshot, isDone: Bool) -> String {
        if isDone {
            let upcoming = snapshot.finishedAndUpcoming().upcoming
            return upcoming == .focus ? "Flip the hourglass to focus again" : "Flip the hourglass for your \(upcoming.title.lowercased())"
        }
        switch snapshot.mode {
        case .running:
            return "Ends at \(snapshot.endDate.formatted(date: .omitted, time: .shortened))"
        case .paused:
            return "Stand it up or tap play to continue"
        case .idle, .finished:
            return "Flip your iPhone to start"
        }
    }
}
