# Sandglass: a Pomodoro hourglass for iPhone

A Pomodoro timer that is a real-feeling hourglass. The sand is the timer, and it follows
gravity from your iPhone's motion sensors (CoreMotion fuses the accelerometer and gyroscope).

## How it works

- **Flip your iPhone over to start.** The full bulb ends up on top and the sand starts running.
- **Tilt it** and the sand surface stays level, like real sand.
- **Turn it sideways to pause.** An hourglass on its side stops, and so does this one.
- **Lay it flat on your desk** and the sand keeps running, so it works as a desk timer.
- **Flip it midway** and the sand runs back, just like the real thing.
- **Tap the hourglass** (or the play button) to turn it over without moving the phone.
- When the top bulb empties you get a chime and a haptic. The sand changes colour
  (amber for focus, mint for breaks), and you flip the phone again to start the next phase.
- If you leave the app, a notification tells you when time is up. Coming back catches the sand up.

## Lock Screen, Dynamic Island and widgets

- **Live Activity**: as soon as sand starts running, a Lock Screen banner shows a small hourglass
  whose sand drains in real time, the countdown, when it ends and your session dots. On iPhones
  with a Dynamic Island the hourglass and countdown sit in the island; long-press it for more.
  It also appears on the Always-On display (dimmed) and in StandBy. When time runs out it switches
  to "Focus done" by itself, even if the app is asleep.
- **Controls on the Lock Screen**: Pause / Resume, Restart and Stop buttons sit under the Lock Screen
  banner and in the expanded Dynamic Island, and "Start break" / "Start focus" appears when a phase
  ends. They work from the Always-On display and StandBy too (the first tap wakes the screen).
- **Widgets**: long-press the Home Screen or Lock Screen, tap Edit › Add Widget, and pick Sandglass.
  There is a small Home Screen widget with a play / pause button, a round Lock Screen widget that is
  itself a play / pause button, plus rectangular and inline Lock Screen widgets.
- **Physics with the phone locked**: iOS stops apps that are not on screen, so normally the sand
  only follows gravity inside the app and the Lock Screen buttons do the work. While a **focus
  sound** is playing the app stays awake, so flipping the locked phone still starts or reverses
  the sand and turning it sideways still pauses it.

## Sounds

- **Focus sounds** (speaker button, or Settings): Falling sand, Rain, Ocean waves, Fireplace or
  Brown noise. They are generated live, so they never loop. Falling sand follows the sand exactly
  and goes quiet the moment it stops; the others dip while paused. They mix with your music or
  podcasts, keep playing with the phone locked, and carry on for five minutes after a phase ends so
  you can flip straight into the next one.
- **Chimes** (Settings › When time is up): Singing bowl, Soft bell, Wind chimes, Marimba or Wood
  block. The same sound is used for the "time's up" notification.

## Apple Watch

The watch app is its own hourglass, with its own timer.
- **Turn the Digital Crown** to turn the hourglass: half a turn flips it and starts the sand,
  stopping on its side pauses it. Tapping the glass flips it too.
- Tilt your wrist and the sand stays level, using the watch's motion sensors.
- Pause, restart and settings buttons sit along the bottom; a tap on the wrist tells you when
  time is up. With your wrist down the countdown keeps going on the always-on screen.
- The iPhone's Lock Screen banner also shows in the watch's Smart Stack (watchOS 11).

iOS doesn't let Lock Screen views run their own animation, so there the sand level drains
smoothly and the falling stream is drawn still. Inside the app everything moves.

Defaults: 25-minute focus, 5-minute short break, and a 15-minute long break after every 4 focus
sessions. All of these can be changed in Settings (the slider button), along with sound, haptics
and keep-screen-on.

## Build it on your Mac

1. Install Xcode (16 or newer) and XcodeGen: `brew install xcodegen`
2. In this folder: `xcodegen generate`, then open `Sandglass.xcodeproj`.
3. In `project.yml`, replace `com.example.sandglass` with your own id everywhere (one line does it:
   `sed -i '' 's/com.example.sandglass/com.yourname.sandglass/g' project.yml`), then re-run `xcodegen generate`.
4. Select each target (**Sandglass**, **SandglassWidgets** and **SandglassWatch**) > Signing & Capabilities > pick your Team
   (a free Apple ID works; apps then expire after 7 days).
5. Plug in your iPhone (watch paired), choose the **Sandglass** scheme and your iPhone, press Run. The widgets and
   watch app install alongside. If the watch app doesn't appear, choose the **SandglassWatch** scheme and your
   watch and run that too.

Widgets read the running session through a shared App Group (`group.com.example.sandglass`, renamed with
the rest of the ids). If Xcode can't sign the App Groups capability with your team, remove it from both
targets: the Lock Screen Live Activity still works, and the widgets just show "Flip your iPhone to start".

The iOS Simulator has no motion sensors, so there you turn the hourglass by tapping it.
[RUN-ON-IPHONE.md](RUN-ON-IPHONE.md) walks through every click, including the first-time iPhone setup.

## Code map

| File | What it does |
| --- | --- |
| `Sandglass/HourglassModel.swift` | The timer: sand in each bulb, flow direction, Pomodoro cycle, background catch-up |
| `MotionService.swift` | Reads gravity from CoreMotion |
| `Shared/Geometry.swift` | Hourglass shape and the level-sand maths (clips each bulb at the height that holds the right amount of sand) |
| `HourglassView.swift` | Draws the glass, sand, falling grains and frame with SwiftUI `Canvas` |
| `ContentView.swift` | Screen layout, buttons and hints |
| `SettingsView.swift` | Durations and feedback settings |
| `Feedback.swift` | Haptics, chime and notifications |
| `LiveActivityController.swift` | Starts, updates and ends the Live Activity; refreshes widgets |
| `SoundEngine.swift` | Focus sounds (synthesised live) and chimes |
| `Sounds/` | The chime recordings |
| `Shared/SessionIntents.swift` | The Lock Screen and widget buttons (App Intents) |
| `Watch/` | The Apple Watch app |
| `Shared/` | Used by the app and the widget extension: geometry, phases, settings, the session snapshot and the small hourglass |
| `SandglassWidget/` | The Live Activity, Dynamic Island and widget views |

If XcodeGen gives you trouble, create a new project in Xcode with the **iOS App** template (SwiftUI, Swift)
named Sandglass, delete the template's Swift files, drag `Sandglass/` + `Shared/` into the app target, then
add a **Widget Extension** target (with Live Activity) and drag `SandglassWidget/` + `Shared/` into it.
