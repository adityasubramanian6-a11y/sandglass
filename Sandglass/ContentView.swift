import SwiftUI

struct ContentView: View {
    @Environment(HourglassModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Prefs.longBreakEveryKey) private var longBreakEvery = Prefs.defaultLongBreakEvery
    @AppStorage(Prefs.focusSoundKey) private var focusSound = FocusSound.off.rawValue
    @State private var showingSettings = false

    var body: some View {
        let palette = Palette(phase: model.phase)
        ZStack {
            LinearGradient(colors: [palette.backgroundTop, palette.backgroundBottom],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: model.phase)

            HourglassView(model: model, palette: palette)
                .padding(.vertical, 170)
                .padding(.horizontal, 32)
                .contentShape(Rectangle())
                .onTapGesture { model.flipByTap() }
                .accessibilityElement()
                .accessibilityLabel("Hourglass")
                .accessibilityValue(timeText)
                .accessibilityHint("Double-tap to turn it over")
                .accessibilityAddTraits(.isButton)

            // Text and buttons turn to stay readable when the phone is upside down;
            // the hourglass itself never turns with them, so flipping the phone flips the sand.
            overlay(palette: palette)
                .rotationEffect(.degrees(model.textUpsideDown ? 180 : 0))
                .animation(.spring(duration: 0.5), value: model.textUpsideDown)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            switch newPhase {
            case .active: model.resume()
            case .background: model.suspend()
            default: break
            }
        }
    }

    // MARK: Pieces

    private func overlay(palette: Palette) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(model.phase.title.uppercased())
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(palette.sand)
                Text(timeText)
                    .font(.system(size: 68, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: model.displaySeconds)
            }
            .padding(.top, 16)

            Spacer(minLength: 0)

            VStack(spacing: 16) {
                Text(hint)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .frame(minHeight: 44)
                    .animation(.easeInOut, value: hint)
                controls(palette: palette)
                cycleDots(palette: palette)
            }
            .padding(.bottom, 12)
        }
        .padding(.horizontal, 24)
    }

    private func controls(palette: Palette) -> some View {
        HStack(spacing: 22) {
            Menu {
                Picker("Focus sound", selection: $focusSound) {
                    ForEach(FocusSound.allCases) { sound in
                        Label(sound.title, systemImage: sound.symbol).tag(sound.rawValue)
                    }
                }
            } label: {
                CircleIcon(systemName: (FocusSound(rawValue: focusSound) ?? .off).symbol, size: 52)
            }
            .accessibilityLabel("Focus sound")

            Menu {
                Button("Restart \(model.phase.title.lowercased())", systemImage: "arrow.counterclockwise") {
                    model.restartPhase()
                }
                Button("Skip to \(model.nextPhase.title.lowercased())", systemImage: "forward.end") {
                    model.skipPhase()
                }
                Button("Stop", systemImage: "stop") {
                    model.stopSession()
                }
                Button("Reset all sessions", systemImage: "arrow.uturn.backward", role: .destructive) {
                    model.resetCycle()
                }
            } label: {
                CircleIcon(systemName: "arrow.counterclockwise", size: 52)
            }
            .accessibilityLabel("Restart or skip")

            Button(action: primaryAction) {
                Image(systemName: primaryIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(palette.backgroundBottom)
                    .frame(width: 72, height: 72)
                    .background(Circle().fill(palette.sand))
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(primaryLabel)
            .disabled(model.status == .pouring)

            Button {
                showingSettings = true
            } label: {
                CircleIcon(systemName: "slider.horizontal.3", size: 52)
            }
            .accessibilityLabel("Settings")
        }
    }

    private func cycleDots(palette: Palette) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<max(1, longBreakEvery), id: \.self) { index in
                Circle()
                    .fill(index < model.completedFocus ? palette.sand : Color.white.opacity(0.18))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(model.completedFocus) of \(longBreakEvery) focus sessions done")
    }

    // MARK: Text

    private var timeText: String {
        let s = model.displaySeconds
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private var hint: String {
        switch model.status {
        case .idle:
            switch model.lastFinished {
            case .focus?:
                return "Nice work! Flip your iPhone for a \(Prefs.minutes(for: model.phase))-minute break."
            case .shortBreak?, .longBreak?:
                return "Break's over. Flip your iPhone to focus again."
            case nil:
                return "Flip your iPhone over to start the sand.\nOr tap the hourglass."
            }
        case .running:
            return model.phase == .focus ? "Focus. Turn it sideways to pause." : "Relax. The sand will tell you when."
        case .pausedOnSide:
            return "Paused on its side. Stand it up to continue."
        case .pausedManually:
            return "Paused."
        case .pouring:
            return " "
        }
    }

    private var primaryIcon: String {
        switch model.status {
        case .idle, .pausedManually: "play.fill"
        case .running, .pausedOnSide, .pouring: "pause.fill"
        }
    }

    private var primaryLabel: String {
        switch model.status {
        case .idle: "Start"
        case .pausedManually: "Resume"
        default: "Pause"
        }
    }

    private func primaryAction() {
        switch model.status {
        case .idle: model.flipByTap()
        case .pouring: break
        default: model.togglePause()
        }
    }
}

private struct CircleIcon: View {
    let systemName: String
    let size: CGFloat

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.36, weight: .medium))
            .foregroundStyle(.white.opacity(0.85))
            .frame(width: size, height: size)
            .background(Circle().fill(.white.opacity(0.1)))
    }
}
