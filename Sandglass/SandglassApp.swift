import SwiftUI

@main
struct SandglassApp: App {
    @State private var model = HourglassModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
        }
    }
}
