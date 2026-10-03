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
- **Widgets**: long-press the Home Screen or Lock Screen, tap Edit › Add Widget, and pick Sandglass.
  There is a small Home Screen widget plus round, rectangular and inline Lock Screen widgets.

iOS doesn't let Lock Screen views run their own animation, so there the sand level drains
smoothly and the falling stream is drawn still. Inside the app everything moves.

Defaults: 25-minute focus, 5-minute short break, and a 15-minute long break after every 4 focus
sessions. All of these can be changed in Settings (the slider button), along with sound, haptics
and keep-screen-on.

## Run it on your iPhone

You need a Mac with **Xcode 16 or newer** and an iPhone on **iOS 17 or newer**.

1. Unzip and double-click `Sandglass.xcodeproj`.
2. In Xcode, click the **Sandglass** project in the left sidebar. Open **Signing & Capabilities**
   and pick your Apple ID under **Team** for **both** targets: **Sandglass** and
   **SandglassWidgetExtension** (add your Apple ID in Xcode › Settings › Accounts if it isn't listed).
3. Bundle identifiers come from one setting. If Xcode says one is taken, select the **Sandglass
   project** (not a target), open **Build Settings**, search for `BASE_BUNDLE_ID` and change
   `com.example.sandglass` to something unique, such as `com.yourname.sandglass`. The widget's ID
   and the shared app group follow automatically.
   If signing complains about **App Groups** (some free accounts can't use them), remove the App
   Groups capability from both targets. The Live Activity still works; the widgets then just show
   "Flip your iPhone to start".
4. Plug in your iPhone (or pick it from the wireless device list), select it as the run
   destination at the top of the window, and press **Run** (⌘R).
5. The first time, the iPhone will block the app as coming from an untrusted developer. Go to
   **Settings › General › VPN & Device Management**, tap your Apple ID, and choose **Trust**.
   On iOS 16+ you may also need to turn on **Settings › Privacy & Security › Developer Mode**
   and restart the phone.

Apps signed with a free Apple ID expire after 7 days; run it from Xcode again to refresh it.
The iOS Simulator has no motion sensors, so there you turn the hourglass by tapping it.

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
| `Shared/` | Used by the app and the widget extension: geometry, phases, settings, the session snapshot and the small hourglass |
| `SandglassWidget/` | The Live Activity, Dynamic Island and widget views |

If Xcode ever refuses to open the project file, create a new iOS App project named
Sandglass (SwiftUI, Swift), delete its generated `ContentView.swift` and `SandglassApp.swift`,
and drag in the files from the `Sandglass` folder.
