import AppIntents
import SwiftUI
import WidgetKit

struct SandEntry: TimelineEntry {
    let date: Date
    let snapshot: SessionSnapshot
    let isDone: Bool
}

struct SandProvider: TimelineProvider {
    func placeholder(in context: Context) -> SandEntry {
        SandEntry(date: Date(), snapshot: .preview, isDone: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (SandEntry) -> Void) {
        let snapshot: SessionSnapshot = context.isPreview ? .preview : (SharedStore.load() ?? Self.idle)
        completion(SandEntry(date: Date(), snapshot: snapshot, isDone: false))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SandEntry>) -> Void) {
        let snapshot = SharedStore.load() ?? Self.idle
        let now = Date()
        var entries: [SandEntry] = []
        if snapshot.mode == .running && snapshot.endDate <= now {
            entries.append(SandEntry(date: now, snapshot: snapshot, isDone: true))
        } else {
            entries.append(SandEntry(date: now, snapshot: snapshot, isDone: false))
            if snapshot.mode == .running {
                // Switch to "time's up" the moment the sand runs out, even if the app is asleep.
                entries.append(SandEntry(date: snapshot.endDate, snapshot: snapshot, isDone: true))
            }
        }
        // The app reloads the timeline whenever the session changes.
        completion(Timeline(entries: entries, policy: .never))
    }

    private static var idle: SessionSnapshot {
        let total = Double(Prefs.defaultFocusMinutes) * 60
        return SessionSnapshot(mode: .idle, phase: .focus, nextPhase: .shortBreak, lastFinished: nil,
                               startDate: Date(), endDate: Date(), remaining: 0, total: total,
                               completedFocus: 0, sessionsPerCycle: Prefs.defaultLongBreakEvery)
    }
}

struct SandglassStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SandglassStatus", provider: SandProvider()) { entry in
            SandWidgetView(entry: entry)
        }
        .configurationDisplayName("Sandglass")
        .description("Watch the sand of your current Pomodoro.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct SandWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SandEntry

    var body: some View {
        let snapshot = entry.snapshot
        let palette = Palette(phase: snapshot.phase)
        content(snapshot: snapshot, palette: palette)
            .containerBackground(for: .widget) {
                if family == .systemSmall {
                    LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                                   startPoint: .top, endPoint: .bottom)
                } else {
                    Color.clear
                }
            }
    }

    @ViewBuilder
    private func content(snapshot: SessionSnapshot, palette: Palette) -> some View {
        switch family {
        case .accessoryCircular:
            // The whole circle is a play / pause button.
            Button(intent: ToggleSandIntent()) {
                ZStack {
                    AccessoryWidgetBackground()
                    MiniHourglass(snapshot: snapshot, isDone: entry.isDone)
                        .padding(7)
                }
            }
            .buttonStyle(.plain)
        case .accessoryRectangular:
            HStack(spacing: 8) {
                MiniHourglass(snapshot: snapshot, isDone: entry.isDone)
                    .frame(width: 22, height: 44)
                VStack(alignment: .leading, spacing: 0) {
                    Text(SessionText.headline(snapshot, isDone: entry.isDone))
                        .font(.headline)
                        .lineLimit(1)
                    SessionTimerText(snapshot: snapshot, isDone: entry.isDone)
                        .font(.system(.title2, design: .rounded))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
        case .accessoryInline:
            Label {
                SessionTimerText(snapshot: snapshot, isDone: entry.isDone)
            } icon: {
                Image(systemName: "hourglass")
            }
        default:
            HStack(spacing: 12) {
                MiniHourglass(snapshot: snapshot, isDone: entry.isDone)
                    .frame(width: 44, height: 84)
                VStack(alignment: .leading, spacing: 4) {
                    Text(SessionText.headline(snapshot, isDone: entry.isDone))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.sand)
                        .lineLimit(2)
                    SessionTimerText(snapshot: snapshot, isDone: entry.isDone)
                        .font(.system(size: 28, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                    Button(intent: ToggleSandIntent()) {
                        Image(systemName: snapshot.mode == .running && !entry.isDone ? "pause.fill" : "play.fill")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(palette.sand.opacity(0.25)))
                            .foregroundStyle(palette.sand)
                    }
                    .buttonStyle(.plain)
                    HStack(spacing: 4) {
                        ForEach(0..<max(1, snapshot.sessionsPerCycle), id: \.self) { index in
                            Circle()
                                .fill(index < snapshot.completedFocus ? palette.sand : Color.white.opacity(0.2))
                                .frame(width: 5, height: 5)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}
