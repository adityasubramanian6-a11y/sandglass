import SwiftUI

@main
struct SandglassApp: App {
    @State private var model = HourglassModel.shared

    init() {
        // Lock Screen and widget buttons run their App Intents inside this process.
        SessionCommandCenter.handler = { command in
            HourglassModel.shared.handle(command)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
