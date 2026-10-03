import SwiftUI

/// A small 2D vector in Double, so the sand maths never mixes CGFloat and Double.
struct Vec: Equatable {
    var x: Double
    var y: Double

    static let down = Vec(x: 0, y: 1)

    static func + (a: Vec, b: Vec) -> Vec { Vec(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: Vec, b: Vec) -> Vec { Vec(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: Vec, k: Double) -> Vec { Vec(x: a.x * k, y: a.y * k) }

    func dot(_ o: Vec) -> Double { x * o.x + y * o.y }
    var length: Double { (x * x + y * y).squareRoot() }
    var normalized: Vec {
        let l = length
        return l > 1e-9 ? Vec(x: x / l, y: y / l) : .down
    }
    var perpendicular: Vec { Vec(x: -y, y: x) }

    /// Rotates by `angle` radians using the same convention as `GraphicsContext.rotate(by:)`.
    func rotated(by angle: Double) -> Vec {
        let c = cos(angle), s = sin(angle)
        return Vec(x: x * c - y * s, y: x * s + y * c)
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

extension Path {
    static func polygon(_ points: [Vec]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first.cgPoint)
        for p in points.dropFirst() { path.addLine(to: p.cgPoint) }
        path.closeSubpath()
        return path
    }
}

enum PolygonMath {
    static func area(_ p: [Vec]) -> Double {
        guard p.count > 2 else { return 0 }
        var sum = 0.0
        for i in p.indices {
            let a = p[i], b = p[(i + 1) % p.count]
            sum += a.x * b.y - b.x * a.y
        }
        return abs(sum) / 2
    }

    /// Keeps the part of `poly` where `point · normal >= offset` (one Sutherland–Hodgman pass).
    static func clip(_ poly: [Vec], normal n: Vec, offset c: Double) -> [Vec] {
        guard poly.count > 2 else { return [] }
        var out: [Vec] = []
        out.reserveCapacity(poly.count + 4)
        for i in poly.indices {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            let da = a.dot(n) - c, db = b.dot(n) - c
            if da >= 0 { out.append(a) }
            if (da >= 0) != (db >= 0) {
                let t = da / (da - db)
                out.append(a + (b - a) * t)
            }
        }
        return out
    }

    static func contains(_ poly: [Vec], _ pt: Vec) -> Bool {
        guard poly.count > 2 else { return false }
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > pt.y) != (b.y > pt.y) {
                let xCross = (b.x - a.x) * (pt.y - a.y) / (b.y - a.y) + a.x
                if pt.x < xCross { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// The region of `bulb` that sand fills when it settles under `gravity` and takes up
    /// `fraction` of the bulb's area. The sand's surface is always level (perpendicular to gravity).
    static func sandFill(in bulb: [Vec], bulbArea: Double, gravity g: Vec, fraction: Double) -> [Vec] {
        if fraction <= 0.0005 { return [] }
        if fraction >= 0.9995 { return bulb }
        let target = fraction * bulbArea
        var lo = Double.infinity, hi = -Double.infinity
        for p in bulb {
            let d = p.dot(g)
            lo = min(lo, d)
            hi = max(hi, d)
        }
        // Sliding the surface along gravity only ever shrinks the filled area, so bisect.
        for _ in 0..<22 {
            let mid = (lo + hi) / 2
            if area(clip(bulb, normal: g, offset: mid)) > target { lo = mid } else { hi = mid }
        }
        return clip(bulb, normal: g, offset: (lo + hi) / 2)
    }
}

/// The hourglass in its own coordinates: the neck sits at the origin, y points down,
/// and each glass bulb is `bulbHeight` tall.
enum HourglassShape {
    static let neck = 0.03
    static let bulbWidth = 0.40
    static let bulbHeight = 0.90
    static let capHeight = 0.075
    static let capOverhang = 0.07
    /// How much of one bulb the whole load of sand fills (a real hourglass is never filled to the brim).
    static let sandCapacity = 0.72
    static let samples = 48

    static var totalHeight: Double { 2 * (bulbHeight + capHeight) }
    static var totalWidth: Double { 2 * (bulbWidth + capOverhang) }

    /// Half-width of the glass at `t`, from 0 at the neck to 1 at the cap.
    static func halfWidth(_ t: Double) -> Double {
        let rise = sin(.pi / 2 * min(t / 0.6, 1))
        var w = neck + (bulbWidth - neck) * pow(rise, 1.35)
        if t > 0.6 {
            let u = (t - 0.6) / 0.4
            w *= 1 - 0.06 * u * u
        }
        if t > 0.86 {
            let u = (t - 0.86) / 0.14
            w *= 0.8 + 0.2 * max(0, 1 - u * u).squareRoot()
        }
        return w
    }

    private static func ts(reversed: Bool) -> [Double] {
        let values = (0...samples).map { Double($0) / Double(samples) }
        return reversed ? values.reversed() : values
    }

    /// Upper bulb (sign -1) or lower bulb (sign +1) as a closed polygon, including the neck opening.
    private static func makeBulb(sign: Double) -> [Vec] {
        var points: [Vec] = []
        for t in ts(reversed: false) { points.append(Vec(x: halfWidth(t), y: sign * t * bulbHeight)) }
        for t in ts(reversed: true) { points.append(Vec(x: -halfWidth(t), y: sign * t * bulbHeight)) }
        return points
    }

    static let topBulb = makeBulb(sign: -1)
    static let bottomBulb = makeBulb(sign: 1)
    static let bulbArea = PolygonMath.area(topBulb)

    static let glassOutline: [Vec] = {
        var points: [Vec] = []
        for t in ts(reversed: true) { points.append(Vec(x: halfWidth(t), y: -t * bulbHeight)) }
        for t in ts(reversed: false).dropFirst() { points.append(Vec(x: halfWidth(t), y: t * bulbHeight)) }
        for t in ts(reversed: true) { points.append(Vec(x: -halfWidth(t), y: t * bulbHeight)) }
        for t in ts(reversed: false).dropFirst() { points.append(Vec(x: -halfWidth(t), y: -t * bulbHeight)) }
        return points
    }()
    static let glassPath = Path.polygon(glassOutline)

    /// Soft reflections running down the left side of each bulb.
    static let highlightPath: Path = {
        var path = Path()
        for sign in [-1.0, 1.0] {
            let range = Array(stride(from: 0.3, through: 0.82, by: 0.02))
            path.move(to: Vec(x: -halfWidth(range[0]) * 0.8, y: sign * range[0] * bulbHeight).cgPoint)
            for t in range.dropFirst() {
                path.addLine(to: Vec(x: -halfWidth(t) * 0.8, y: sign * t * bulbHeight).cgPoint)
            }
        }
        return path
    }()

    static let topGrains = grainPath(in: topBulb, seed: 7)
    static let bottomGrains = grainPath(in: bottomBulb, seed: 11)

    /// Speckles that give the sand a grainy texture; drawn clipped to the sand.
    private static func grainPath(in bulb: [Vec], seed: UInt64) -> Path {
        var rng = LCG(state: seed)
        var path = Path()
        var placed = 0
        var attempts = 0
        while placed < 320 && attempts < 6000 {
            attempts += 1
            let p = Vec(x: (rng.next() * 2 - 1) * bulbWidth, y: (rng.next() * 2 - 1) * bulbHeight)
            guard PolygonMath.contains(bulb, p) else { continue }
            let r = 0.004 + rng.next() * 0.004
            path.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            placed += 1
        }
        return path
    }
}

private struct LCG {
    var state: UInt64
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(UInt64(1) << 53)
    }
}
