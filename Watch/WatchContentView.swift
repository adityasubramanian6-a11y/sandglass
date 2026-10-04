import SwiftUI

struct WatchContentView: View {
    @Environment(WatchModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @State private var showingSettings = false

    var body: some View {
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
                        Text("Tap the hourglass to start")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .containerBackground(palette.backgroundBottom.gradient, for: .navigation)
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

/// Compact settings: each row opens a short list of choices instead of a big stepper.
private struct WatchSettingsView: View {
    @AppStorage(Prefs.focusMinutesKey) private var focusMinutes = Prefs.defaultFocusMinutes
    @AppStorage(Prefs.shortBreakMinutesKey) private var shortBreakMinutes = Prefs.defaultShortBreakMinutes
    @AppStorage(Prefs.longBreakMinutesKey) private var longBreakMinutes = Prefs.defaultLongBreakMinutes
    @AppStorage(Prefs.longBreakEveryKey) private var longBreakEvery = Prefs.defaultLongBreakEvery
    @AppStorage(Prefs.hapticsKey) private var hapticsOn = true

    var body: some View {
        NavigationStack {
            List {
                Section("Minutes") {
                    minutesPicker("Focus", value: $focusMinutes, presets: [10, 15, 20, 25, 30, 40, 45, 50, 60, 90])
                    minutesPicker("Break", value: $shortBreakMinutes, presets: [1, 3, 5, 10, 15])
                    minutesPicker("Long break", value: $longBreakMinutes, presets: [10, 15, 20, 25, 30])
                }
                Section {
                    Picker("Long break after", selection: $longBreakEvery) {
                        ForEach(options(longBreakEvery, presets: [2, 3, 4, 5, 6]), id: \.self) { count in
                            Text("\(count) focus").tag(count)
                        }
                    }
                    Toggle("Haptics", isOn: $hapticsOn)
                }
            }
            .font(.footnote)
            .navigationTitle("Settings")
        }
    }

    private func minutesPicker(_ title: String, value: Binding<Int>, presets: [Int]) -> some View {
        Picker(title, selection: value) {
            ForEach(options(value.wrappedValue, presets: presets), id: \.self) { minutes in
                Text("\(minutes) min").tag(minutes)
            }
        }
    }

    /// The presets, plus the current value if it isn't one of them, so the picker always shows it.
    private func options(_ current: Int, presets: [Int]) -> [Int] {
        presets.contains(current) ? presets : (presets + [current]).sorted()
    }
}
