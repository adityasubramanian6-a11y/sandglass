import SwiftUI
import WidgetKit

@main
struct SandglassWidgetBundle: WidgetBundle {
    var body: some Widget {
        SandglassLiveActivity()
        SandglassStatusWidget()
    }
}
