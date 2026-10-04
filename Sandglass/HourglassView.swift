import SwiftUI

struct HourglassView: View {
    let model: HourglassModel
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
