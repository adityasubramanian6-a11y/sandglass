import SwiftUI

/// Everything the renderer needs for one frame.
struct SandFrame {
    var topSand: Double
    var gravity: Vec
    var rotation: Double
    var clock: Double
    var streaming: Bool
    var palette: Palette
}

enum HourglassRenderer {
    static func draw(_ f: SandFrame, in ctx: inout GraphicsContext, size: CGSize) {
        let shape = HourglassShape.self
        let scale = min(size.height / (shape.totalHeight + 0.04), size.width / (shape.totalWidth + 0.04))
        guard scale > 0 else { return }
        ctx.translateBy(x: size.width / 2, y: size.height / 2)
        ctx.rotate(by: .radians(f.rotation))
        ctx.scaleBy(x: scale, y: scale)
        let px = 1 / scale

        drawFrame(f.palette, posts: true, in: &ctx)

        ctx.fill(shape.glassPath, with: .color(.white.opacity(0.045)))

        let g = f.gravity
        let topFill = PolygonMath.sandFill(in: shape.topBulb, bulbArea: shape.bulbArea, gravity: g,
                                           fraction: f.topSand * shape.sandCapacity)
        let bottomFill = PolygonMath.sandFill(in: shape.bottomBulb, bulbArea: shape.bulbArea, gravity: g,
                                              fraction: (1 - f.topSand) * shape.sandCapacity)
        drawSand(topFill, grains: shape.topGrains, frame: f, in: &ctx)
        drawSand(bottomFill, grains: shape.bottomGrains, frame: f, in: &ctx)

        if f.streaming {
            let fallsDown = g.y > 0
            drawStream(f,
                       destination: fallsDown ? shape.bottomBulb : shape.topBulb,
                       destinationFill: fallsDown ? bottomFill : topFill,
                       in: &ctx)
        }

        ctx.stroke(shape.glassPath, with: .color(.white.opacity(0.42)),
                   style: StrokeStyle(lineWidth: 1.6 * px, lineJoin: .round))
        ctx.stroke(shape.highlightPath, with: .color(.white.opacity(0.16)),
                   style: StrokeStyle(lineWidth: 3 * px, lineCap: .round))

        drawFrame(f.palette, posts: false, in: &ctx)
    }

    private static func drawSand(_ poly: [Vec], grains: Path, frame f: SandFrame, in ctx: inout GraphicsContext) {
        guard poly.count > 2 else { return }
        let path = Path.polygon(poly)
        let g = f.gravity
        ctx.fill(path, with: .linearGradient(Gradient(colors: [f.palette.sand, f.palette.sandShade]),
                                             startPoint: (g * -0.9).cgPoint,
                                             endPoint: (g * 0.9).cgPoint))
        ctx.drawLayer { layer in
            layer.clip(to: path)
            layer.fill(grains, with: .color(f.palette.sandShade.opacity(0.6)))
        }
    }

    /// The thin trickle from the neck down to the sand pile below, with grains tumbling along it.
    private static func drawStream(_ f: SandFrame, destination: [Vec], destinationFill: [Vec],
                                   in ctx: inout GraphicsContext) {
        let g = f.gravity
        var length = 0.03
        while length < 1.0 {
            let p = g * length
            if !PolygonMath.contains(destination, p) { break }
            if destinationFill.count > 2 && PolygonMath.contains(destinationFill, p) { break }
            length += 0.008
        }
        let end = g * length

        var trickle = Path()
        trickle.move(to: (g * -0.02).cgPoint)
        trickle.addLine(to: end.cgPoint)
        ctx.stroke(trickle, with: .color(f.palette.sand.opacity(0.75)),
                   style: StrokeStyle(lineWidth: HourglassShape.neck * 0.55, lineCap: .round))

        var grains = Path()
        let side = g.perpendicular
        func dot(at c: Vec, radius r: Double) {
            grains.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
        }
        for i in 0..<14 {
            let progress = (f.clock * 1.7 + Double(i) / 14).truncatingRemainder(dividingBy: 1)
            let wobble = sin(Double(i) * 12.9898 + f.clock * 7) * 0.005
            dot(at: g * (progress * length) + side * wobble, radius: 0.0065)
        }
        // A little splash where the grains land.
        for j in 0..<6 {
            let t = (f.clock * 2.3 + Double(j) / 6).truncatingRemainder(dividingBy: 1)
            let spread = (j.isMultiple(of: 2) ? 1.0 : -1.0) * (0.01 + 0.035 * t)
            let hop = sin(t * .pi) * 0.02
            dot(at: end + side * spread - g * hop, radius: 0.005 * (1 - t * 0.6))
        }
        ctx.fill(grains, with: .color(f.palette.sand))
    }

    /// The wooden caps and the posts between them; posts sit behind the glass, caps in front.
    private static func drawFrame(_ palette: Palette, posts: Bool, in ctx: inout GraphicsContext) {
        let shape = HourglassShape.self
        let capHalfWidth = shape.bulbWidth + shape.capOverhang
        if posts {
            for x in [-1.0, 1.0] {
                let rect = CGRect(x: x * (capHalfWidth - 0.04) - 0.012, y: -shape.bulbHeight,
                                  width: 0.024, height: 2 * shape.bulbHeight)
                ctx.fill(Path(roundedRect: rect, cornerRadius: 0.012),
                         with: .linearGradient(Gradient(colors: [palette.frame, palette.frameShade]),
                                               startPoint: CGPoint(x: rect.minX, y: 0),
                                               endPoint: CGPoint(x: rect.maxX, y: 0)))
            }
            return
        }
        for sign in [-1.0, 1.0] {
            let inner = sign * shape.bulbHeight
            let outer = sign * (shape.bulbHeight + shape.capHeight)
            let rect = CGRect(x: -capHalfWidth, y: min(inner, outer), width: 2 * capHalfWidth, height: shape.capHeight)
            ctx.fill(Path(roundedRect: rect, cornerRadius: shape.capHeight * 0.35),
                     with: .linearGradient(Gradient(colors: [palette.frame, palette.frameShade]),
                                           startPoint: CGPoint(x: 0, y: rect.minY),
                                           endPoint: CGPoint(x: 0, y: rect.maxY)))
        }
    }
}
