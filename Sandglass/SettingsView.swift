import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.focusMinutesKey) private var focusMinutes = Prefs.defaultFocusMinutes
    @AppStorage(Prefs.shortBreakMinutesKey) private var shortBreakMinutes = Prefs.defaultShortBreakMinutes
    @AppStorage(Prefs.longBreakMinutesKey) private var longBreakMinutes = Prefs.defaultLongBreakMinutes
    @AppStorage(Prefs.longBreakEveryKey) private var longBreakEvery = Prefs.defaultLongBreakEvery
    @AppStorage(Prefs.soundKey) private var soundOn = true
    @AppStorage(Prefs.hapticsKey) private var hapticsOn = true
    @AppStorage(Prefs.keepAwakeKey) private var keepAwake = true
    @AppStorage(Prefs.chimeKey) private var chime = Chime.bowl.rawValue
    @AppStorage(Prefs.focusSoundKey) private var focusSound = FocusSound.off.rawValue
    @AppStorage(Prefs.focusVolumeKey) private var focusVolume = 0.6

    var body: some View {
        NavigationStack {
            Form {
                Section("Durations") {
                    Stepper(value: $focusMinutes, in: 5...90, step: 5) {
                        LabeledContent("Focus", value: "\(focusMinutes) min")
                    }
                    Stepper(value: $shortBreakMinutes, in: 1...30) {
                        LabeledContent("Short break", value: "\(shortBreakMinutes) min")
                    }
                    Stepper(value: $longBreakMinutes, in: 5...45, step: 5) {
                        LabeledContent("Long break", value: "\(longBreakMinutes) min")
                    }
                    Stepper(value: $longBreakEvery, in: 2...8) {
                        LabeledContent("Long break after", value: "\(longBreakEvery) focus sessions")
                    }
                }

                Section {
                    Picker("Focus sound", selection: $focusSound) {
                        ForEach(FocusSound.allCases) { sound in
                            Label(sound.title, systemImage: sound.symbol).tag(sound.rawValue)
                        }
                    }
                    if focusSound != FocusSound.off.rawValue {
                        HStack {
                            Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                            Slider(value: $focusVolume, in: 0.05...1)
                            Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("While the sand runs")
                } footer: {
                    Text("Plays while a session runs, even with the phone locked. While it plays, flipping or turning the locked phone still starts, reverses or pauses the sand.")
                }

                Section("When time is up") {
                    Toggle("Chime", isOn: $soundOn)
                    if soundOn {
                        Picker("Sound", selection: $chime) {
                            ForEach(Chime.allCases) { chime in
                                Text(chime.title).tag(chime.rawValue)
                            }
                        }
                        .onChange(of: chime) { _, newValue in
                            SoundEngine.shared.playChime(Chime(rawValue: newValue) ?? .bowl)
                        }
                    }
                }

                Section("Feedback") {
                    Toggle("Haptics", isOn: $hapticsOn)
                    Toggle("Keep screen on while sand runs", isOn: $keepAwake)
                }

                Section("How it works") {
                    Label("Flip your iPhone over to start the sand.", systemImage: "arrow.triangle.2.circlepath")
                    Label("Turn it sideways to pause, like a real hourglass on its side.", systemImage: "pause.circle")
                    Label("Lying flat on a desk, the sand keeps running.", systemImage: "iphone")
                    Label("Flip it midway and the sand runs back.", systemImage: "hourglass")
                    Label("Tap the hourglass to turn it over without moving your phone.", systemImage: "hand.tap")
                    Label("On the Lock Screen and Dynamic Island, use the play, pause and restart buttons.", systemImage: "lock.iphone")
                }
                .font(.callout)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
