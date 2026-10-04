import SwiftUI

@main
struct SandglassWatchApp: App {
    @State private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environment(model)
        }
    }
}
