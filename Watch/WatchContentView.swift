import SwiftUI

struct WatchContentView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var showingSettings = false

    var body: some View {
        @Bindable var model = model
        let palette = Palette(phase: model.phase)
        NavigationStack {
            ZStack {
                WatchHourglass(model: model, palette: palette)
                    .padding(.vertical, 6)
                    .opacity(isLuminanceReduced ? 0.55 : 1)
                    .onTapGesture { model.flip() }
                    .accessibilityLabel("Hourglass")
                    .accessibilityHint("Double-tap to turn it over")

                VStack {
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.phase.title)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(palette.sand)
                        Spacer()
                        timeText
                            .font(.system(.title3, design: .rounded).weight(.medium))
                            .monospacedDigit()
                    }
                    Spacer()
                    if model.status == .idle {
                        Text("Turn the crown or tap to start")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .containerBackground(palette.backgroundBottom.gradient, for: .navigation)
            .focusable()
            .digitalCrownRotation($model.crown, from: -10_000, through: 10_000, by: 0.05,
                                  sensitivity: .medium, isContinuous: true, isHapticFeedbackEnabled: false)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        model.restart()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Restart")
                    Button {
                        model.togglePause()
                    } label: {
                        Image(systemName: model.status == .running ? "pause.fill" : "play.fill")
                    }
                    .controlSize(.large)
                    .tint(palette.sand)
                    .accessibilityLabel(model.status == .running ? "Pause" : "Start")
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                WatchSettingsView()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            switch newPhase {
            case .active: model.resume()
            case .inactive, .background: model.suspend()
            @unknown default: break
            }
        }
    }

    /// With the wrist down the app isn't ticking, so let the system count down.
    @ViewBuilder
    private var timeText: some View {
        if model.status == .running && isLuminanceReduced {
            Text(timerInterval: Date()...model.endDate, countsDown: true)
        } else {
            let seconds = max(0, Int(model.remainingSeconds.rounded(.up)))
            Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
        }
    }
}

private struct WatchHourglass: View {
    let model: WatchModel
    let palette: Palette

    var body: some View {
        let frame = SandFrame(topSand: model.topSand,
                              gravity: model.localGravity,
                              rotation: model.rotation,
                              clock: model.clock,
                              streaming: model.status == .running,
                              palette: palette)
        Canvas { context, size in
            HourglassRenderer.draw(frame, in: &context, size: size)
        }
    }
}

private struct WatchSettingsView: View {
    @AppStorage(Prefs.focusMinutesKey) private var focusMinutes = Prefs.defaultFocusMinutes
    @AppStorage(Prefs.shortBreakMinutesKey) private var shortBreakMinutes = Prefs.defaultShortBreakMinutes
    @AppStorage(Prefs.longBreakMinutesKey) private var longBreakMinutes = Prefs.defaultLongBreakMinutes
    @AppStorage(Prefs.hapticsKey) private var hapticsOn = true

    var body: some View {
        List {
            Stepper("Focus \(focusMinutes) min", value: $focusMinutes, in: 5...90, step: 5)
            Stepper("Break \(shortBreakMinutes) min", value: $shortBreakMinutes, in: 1...30)
            Stepper("Long break \(longBreakMinutes) min", value: $longBreakMinutes, in: 5...45, step: 5)
            Toggle("Haptics", isOn: $hapticsOn)
        }
        .navigationTitle("Settings")
    }
}
