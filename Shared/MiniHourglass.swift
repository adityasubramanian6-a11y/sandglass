import SwiftUI

/// A small hourglass for the Lock Screen, Dynamic Island and widgets.
///
/// These surfaces can't run our own animation, but the system keeps a
/// `ProgressView(timerInterval:)` moving on its own. Each bulb's sand is one of those bars,
/// turned upright, stretched across the bulb and clipped to the glass, so the top bulb drains
/// and the bottom one fills continuously while the phone stays locked.
struct MiniHourglass: View {
    let snapshot: SessionSnapshot
    var isDone = false

    private var isRunning: Bool { snapshot.mode == .running && !isDone }

    var body: some View {
        let palette = Palette(phase: snapshot.phase)
        GeometryReader { geo in
            let m = MiniMetrics(size: geo.size)
            ZStack {
                MiniGlassShape(part: .glass).fill(Color.white.opacity(0.08))

                bulbSand(top: true, palette: palette, metrics: m)
                bulbSand(top: false, palette: palette, metrics: m)

                if isRunning {
                    stream(palette: palette, metrics: m)
                }

                MiniGlassShape(part: .glass)
                    .stroke(Color.white.opacity(0.55), lineWidth: max(0.75, m.scale * 0.014))
                MiniGlassShape(part: .caps).fill(palette.frame)
            }
        }
        .aspectRatio(CGFloat(HourglassShape.totalWidth / HourglassShape.totalHeight), contentMode: .fit)
    }

    private func bulbSand(top: Bool, palette: Palette, metrics m: MiniMetrics) -> some View {
        let height = CGFloat(HourglassShape.bulbHeight) * m.scale
        let width = 2 * CGFloat(HourglassShape.bulbWidth) * m.scale
        return sandBar(top: top, color: palette.sand)
            .frame(width: width, height: height)
            .position(x: m.center.x, y: m.center.y + (top ? -height / 2 : height / 2))
            .mask { MiniGlassShape(part: top ? .topBulb : .bottomBulb) }
    }

    /// A progress bar turned upright so it fills from the bottom; scaled wide enough to cover the bulb.
    private func sandBar(top: Bool, color: Color) -> some View {
        GeometryReader { geo in
            progress(top: top)
                .progressViewStyle(.linear)
                .labelsHidden()
                .tint(color)
                .frame(width: geo.size.height)
                .scaleEffect(x: 1, y: max(40, geo.size.width), anchor: .center)
                .rotationEffect(.degrees(-90))
                .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func progress(top: Bool) -> some View {
        if isRunning && snapshot.startDate < snapshot.endDate {
            ProgressView(timerInterval: snapshot.startDate...snapshot.endDate, countsDown: top) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
        } else {
            let upper = isDone ? 0 : snapshot.topFraction
            ProgressView(value: top ? upper : 1 - upper)
        }
    }

    /// The falling trickle. It runs to the bottom of the glass; where it meets the pile it is the
    /// same colour as the sand, so it seems to land on whatever height the pile has reached.
    private func stream(palette: Palette, metrics m: MiniMetrics) -> some View {
        let length = CGFloat(HourglassShape.bulbHeight) * m.scale * 0.97
        let width = max(1, CGFloat(HourglassShape.neck) * m.scale * 0.8)
        let grain = max(1, width * 1.1)
        return ZStack {
            Capsule()
                .fill(palette.sand)
                .frame(width: width, height: length)
                .position(x: m.center.x, y: m.center.y + length / 2)
            ForEach(Array([0.18, 0.37, 0.55, 0.74].enumerated()), id: \.offset) { index, t in
                Circle()
                    .fill(palette.sand)
                    .frame(width: grain, height: grain)
                    .position(x: m.center.x + (index.isMultiple(of: 2) ? grain : -grain),
                              y: m.center.y + length * CGFloat(t))
            }
        }
    }
}

private struct MiniMetrics {
    let scale: CGFloat
    let center: CGPoint

    init(size: CGSize) {
        scale = min(size.width / CGFloat(HourglassShape.totalWidth), size.height / CGFloat(HourglassShape.totalHeight))
        center = CGPoint(x: size.width / 2, y: size.height / 2)
    }

    var transform: CGAffineTransform {
        CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: scale, y: scale)
    }
}

/// The hourglass geometry from the app, fitted into whatever rectangle SwiftUI offers.
struct MiniGlassShape: Shape {
    enum Part { case glass, topBulb, bottomBulb, caps }
    let part: Part

    func path(in rect: CGRect) -> Path {
        let m = MiniMetrics(size: rect.size)
        let local: Path
        switch part {
        case .glass:
            local = HourglassShape.glassPath
        case .topBulb:
            local = Path.polygon(HourglassShape.topBulb)
        case .bottomBulb:
            local = Path.polygon(HourglassShape.bottomBulb)
        case .caps:
            var caps = Path()
            let halfWidth = HourglassShape.bulbWidth + HourglassShape.capOverhang
            for sign in [-1.0, 1.0] {
                let inner = sign * HourglassShape.bulbHeight
                let outer = sign * (HourglassShape.bulbHeight + HourglassShape.capHeight)
                caps.addRoundedRect(in: CGRect(x: -halfWidth, y: min(inner, outer),
                                               width: 2 * halfWidth, height: HourglassShape.capHeight),
                                    cornerSize: CGSize(width: 0.025, height: 0.025))
            }
            local = caps
        }
        return local.applying(m.transform).offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
