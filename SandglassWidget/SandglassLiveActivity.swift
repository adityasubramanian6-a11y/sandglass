import ActivityKit
import SwiftUI
import WidgetKit

/// Lock Screen banner, Dynamic Island and StandBy / Always-On views for a running session.
struct SandglassLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SandglassActivityAttributes.self) { context in
            LockScreenActivityView(snapshot: context.state, isDone: Self.isDone(context))
                .activityBackgroundTint(Palette(phase: context.state.phase).backgroundBottom.opacity(0.88))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            Self.island(context)
        }
    }

    private static func isDone(_ context: ActivityViewContext<SandglassActivityAttributes>) -> Bool {
        context.state.mode == .finished || (context.state.mode == .running && context.isStale)
    }

    private static func island(_ context: ActivityViewContext<SandglassActivityAttributes>) -> DynamicIsland {
        let snapshot = context.state
        let done = isDone(context)
        let palette = Palette(phase: snapshot.phase)
        return DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                MiniHourglass(snapshot: snapshot, isDone: done)
                    .frame(width: 40, height: 70)
                    .padding(.leading, 6)
            }
            DynamicIslandExpandedRegion(.trailing) {
                SessionTimerText(snapshot: snapshot, isDone: done)
                    .font(.system(size: 36, weight: .light, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 130, alignment: .trailing)
                    .padding(.trailing, 6)
            }
            DynamicIslandExpandedRegion(.center) {
                Text(SessionText.headline(snapshot, isDone: done))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.sand)
            }
            DynamicIslandExpandedRegion(.bottom) {
                VStack(spacing: 8) {
                    Text(SessionText.detail(snapshot, isDone: done))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                    SessionControls(snapshot: snapshot, isDone: done, tint: palette.sand)
                }
            }
        } compactLeading: {
            MiniHourglass(snapshot: snapshot, isDone: done)
                .frame(width: 14, height: 24)
        } compactTrailing: {
            SessionTimerText(snapshot: snapshot, isDone: done)
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(palette.sand)
                .frame(width: 48, alignment: .trailing)
        } minimal: {
            MiniHourglass(snapshot: snapshot, isDone: done)
                .frame(width: 14, height: 24)
        }
        .keylineTint(palette.sand)
    }
}

struct LockScreenActivityView: View {
    let snapshot: SessionSnapshot
    let isDone: Bool

    var body: some View {
        let palette = Palette(phase: snapshot.phase)
        // Live Activities get at most 160 points of height on the Lock Screen.
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                MiniHourglass(snapshot: snapshot, isDone: isDone)
                    .frame(width: 44, height: 80)
                VStack(alignment: .leading, spacing: 0) {
                    Text(SessionText.headline(snapshot, isDone: isDone))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.sand)
                    SessionTimerText(snapshot: snapshot, isDone: isDone)
                        .font(.system(size: 40, weight: .light, design: .rounded))
                        .foregroundStyle(.white)
                    Text(SessionText.detail(snapshot, isDone: isDone))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                CycleDots(snapshot: snapshot, color: palette.sand)
            }
            SessionControls(snapshot: snapshot, isDone: isDone, tint: palette.sand)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }
}
