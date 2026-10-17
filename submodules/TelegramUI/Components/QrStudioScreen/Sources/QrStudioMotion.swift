import Foundation
import CoreGraphics
import simd

enum QrStudioCurve {
    static func smooth(_ x: Double) -> Double {
        return x * x * (3.0 - 2.0 * x)
    }

    static func backOut(_ x: Double) -> Double {
        let c1 = 1.70158
        let c3 = c1 + 1.0
        let u = x - 1.0
        return 1.0 + c3 * u * u * u + c1 * u * u
    }

    static func clamp01(_ x: Double) -> Double {
        return min(1.0, max(0.0, x))
    }
}

func qrStudioFract(_ x: Double) -> Double {
    return x - floor(x)
}

final class QrStudioPan {
    static let glide: Double = 0.35
    private static let velocityLimit: CGFloat = 2600.0
    private static let settleDuration: Double = 1.6

    private var base = CGSize.zero
    private var translation = CGSize.zero
    private var velocity = CGSize.zero
    private var releaseStretch = CGSize.zero
    private var stretchBase = CGSize.zero
    private var releasedAt: Double = -10.0
    private(set) var isDragging = false

    func begin(at t: Double) {
        guard !self.isDragging else {
            return
        }
        self.base = self.offset(at: t)
        self.stretchBase = self.stretch(at: t)
        self.velocity = .zero
        self.translation = .zero
        self.isDragging = true
    }

    func update(translation: CGSize) {
        guard self.isDragging else {
            return
        }
        self.translation = translation
    }

    func end(translation: CGSize, velocity: CGSize, at t: Double) {
        guard self.isDragging else {
            return
        }
        self.base = CGSize(width: self.base.width + translation.width, height: self.base.height + translation.height)
        self.releaseStretch = CGSize(width: self.stretchBase.width + translation.width, height: self.stretchBase.height + translation.height)
        self.translation = .zero
        self.isDragging = false
        let limit = QrStudioPan.velocityLimit
        self.velocity = CGSize(width: min(max(velocity.width, -limit), limit), height: min(max(velocity.height, -limit), limit))
        self.releasedAt = t
    }

    func cancel(at t: Double) {
        guard self.isDragging else {
            return
        }
        self.base = CGSize(width: self.base.width + self.translation.width, height: self.base.height + self.translation.height)
        self.releaseStretch = CGSize(width: self.stretchBase.width + self.translation.width, height: self.stretchBase.height + self.translation.height)
        self.translation = .zero
        self.velocity = .zero
        self.isDragging = false
        self.releasedAt = t
    }

    func offset(at t: Double) -> CGSize {
        if self.isDragging {
            return CGSize(width: self.base.width + self.translation.width, height: self.base.height + self.translation.height)
        }
        let k = CGFloat(QrStudioPan.glide * (1.0 - exp(-max(0.0, t - self.releasedAt) / QrStudioPan.glide)))
        return CGSize(width: self.base.width + self.velocity.width * k, height: self.base.height + self.velocity.height * k)
    }

    func stretch(at t: Double) -> CGSize {
        if self.isDragging {
            return CGSize(width: self.stretchBase.width + self.translation.width, height: self.stretchBase.height + self.translation.height)
        }
        let dt = max(0.0, t - self.releasedAt)
        let k = CGFloat(exp(-dt / 0.22) * cos(dt * 2.0 * .pi / 0.85))
        return CGSize(width: self.releaseStretch.width * k, height: self.releaseStretch.height * k)
    }

    func isActive(at t: Double) -> Bool {
        return self.isDragging || t - self.releasedAt < QrStudioPan.settleDuration
    }
}

struct QrStudioEdgeSqueeze {
    var size: CGSize
    var band: CGFloat

    init(size: CGSize, band: CGFloat = 90.0) {
        self.size = size
        self.band = band
    }

    var margin: CGFloat {
        return self.band * 1.3
    }

    func apply(_ p: CGPoint) -> (point: CGPoint, scale: CGFloat) {
        let (x, sx) = self.axis(p.x, self.size.width)
        let (y, sy) = self.axis(p.y, self.size.height)
        return (CGPoint(x: x, y: y), min(sx, sy))
    }

    func alpha(_ scale: CGFloat) -> Double {
        return QrStudioCurve.smooth(QrStudioCurve.clamp01(Double((scale - 0.08) / 0.17)))
    }

    private func axis(_ v: CGFloat, _ length: CGFloat) -> (CGFloat, CGFloat) {
        if v < self.band, v <= length - v {
            let g = exp(v / self.band - 1.0)
            return (self.band * g, g)
        }
        let w = length - v
        if w < self.band {
            let g = exp(w / self.band - 1.0)
            return (length - self.band * g, g)
        }
        return (v, 1.0)
    }
}

enum QrStudioReveal {
    static let duration: Double = 0.9
    static let feather: CGFloat = 70.0
    static let frontSpeed: Double = 620.0

    static func radius(progress: Double, center: CGPoint, size: CGSize) -> CGFloat {
        let far = hypot(max(center.x, size.width - center.x), max(center.y, size.height - center.y))
        return (far + self.feather) * CGFloat(progress)
    }

    static func entrance(_ p: CGPoint, center: CGPoint, since: Double) -> Double {
        let d = Double(hypot(p.x - center.x, p.y - center.y))
        let local = (since - d / self.frontSpeed) / 0.45
        if local >= 1.0 {
            return 1.0
        }
        if local <= 0.0 {
            return 0.0
        }
        return QrStudioCurve.backOut(local)
    }

    static func flash(_ p: CGPoint, center: CGPoint, since: Double) -> Double {
        let d = Double(hypot(p.x - center.x, p.y - center.y))
        let u = (since - d / self.frontSpeed - 0.18) / 0.14
        return exp(-u * u)
    }
}

final class QrStudioDrift {
    struct Sample {
        var t: Double
        var w: SIMD2<Double>
        var flow: SIMD2<Double>
    }

    private static let flowGain: Double = 120.0

    private var samples: [Sample] = []
    private var pathTime: Double = 0.0
    private var pathPoint = SIMD2<Double>(0.0, 0.0)
    private var flowTime: Double?
    private var flowPoint = SIMD2<Double>(0.0, 0.0)

    static func heading(_ t: Double) -> Double {
        return 1.2 * sin(0.025 * t) + 0.6 * sin(0.016 * t + 1.0)
    }

    func path(at target: Double) -> SIMD2<Double> {
        var remaining = target - self.pathTime
        if abs(remaining) > 600.0 {
            self.pathTime = target
            return self.pathPoint
        }
        while abs(remaining) > 1e-9 {
            let dt = remaining > 0.0 ? min(remaining, 1.0 / 60.0) : max(remaining, -1.0 / 60.0)
            let mid = QrStudioDrift.heading(self.pathTime + dt / 2.0)
            self.pathPoint += SIMD2(cos(mid), sin(mid)) * dt
            self.pathTime += dt
            remaining -= dt
        }
        return self.pathPoint
    }

    func flow(at target: Double, tilt: SIMD2<Double>) -> SIMD2<Double> {
        defer {
            self.flowTime = max(self.flowTime ?? target, target)
        }
        guard let last = self.flowTime, target > last, target - last < 0.5 else {
            return self.flowPoint
        }
        self.flowPoint += SIMD2(tilt.x, -tilt.y) * QrStudioDrift.flowGain * (target - last)
        return self.flowPoint
    }

    func record(_ t: Double, _ w: SIMD2<Double>, _ flow: SIMD2<Double>) {
        if let last = self.samples.last, t <= last.t {
            return
        }
        self.samples.append(Sample(t: t, w: w, flow: flow))
        if let first = self.samples.first, t - first.t > 0.6 {
            self.samples.removeFirst(min(self.samples.count - 1, 8))
        }
    }

    func sample(at t: Double) -> Sample {
        guard let last = self.samples.last else {
            return Sample(t: t, w: SIMD2(0.0, 0.0), flow: SIMD2(0.0, 0.0))
        }
        if t >= last.t {
            return last
        }
        guard t > self.samples[0].t else {
            return self.samples[0]
        }
        var lo = 0
        var hi = self.samples.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if self.samples[mid].t <= t {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        let a = self.samples[lo]
        let b = self.samples[min(lo + 1, self.samples.count - 1)]
        let k = b.t > a.t ? (t - a.t) / (b.t - a.t) : 0.0
        return Sample(t: t, w: a.w + (b.w - a.w) * k, flow: a.flow + (b.flow - a.flow) * k)
    }
}

struct QrStudioLattice {
    struct Cell {
        var r: Int
        var c: Int
        var point: CGPoint
        var hash: Double
    }

    var dx: CGFloat
    var dy: CGFloat
    var velocity: CGVector
    var lag: ClosedRange<Double>
    var orbit: ClosedRange<CGFloat>

    init(dx: CGFloat, dy: CGFloat, velocity: CGVector, lag: ClosedRange<Double>, orbit: ClosedRange<CGFloat>) {
        self.dx = dx
        self.dy = dy
        self.velocity = velocity
        self.lag = lag
        self.orbit = orbit
    }

    private func shift(_ w: SIMD2<Double>, _ flow: SIMD2<Double>, _ pan: CGSize) -> CGPoint {
        let speed = Double(hypot(self.velocity.dx, self.velocity.dy))
        let angle = Double(atan2(self.velocity.dy, self.velocity.dx))
        return CGPoint(
            x: CGFloat(speed * (w.x * cos(angle) - w.y * sin(angle)) + flow.x) + pan.width,
            y: CGFloat(speed * (w.x * sin(angle) + w.y * cos(angle)) + flow.y) + pan.height
        )
    }

    func cells(in size: CGSize, at t: Double, offset: CGSize, margin: CGFloat, drift: QrStudioDrift, tilt: SIMD2<Double>) -> [Cell] {
        let w = drift.path(at: t)
        let flow = drift.flow(at: t, tilt: tilt)
        drift.record(t, w, flow)
        let now = self.shift(w, flow, offset)
        let ox = now.x
        let oy = now.y

        var lags: [CGPoint] = []
        lags.reserveCapacity(8)
        for i in 0 ..< 8 {
            let delay = self.lag.lowerBound + (self.lag.upperBound - self.lag.lowerBound) * Double(i) / 7.0
            let past = drift.sample(at: t - delay)
            lags.append(self.shift(past.w, past.flow, offset))
        }

        let orbitLower = self.orbit.lowerBound
        let orbitRange = self.orbit.upperBound - self.orbit.lowerBound

        let r0 = Int(floor((-margin - oy) / self.dy))
        let r1 = Int(ceil((size.height + margin - oy) / self.dy))
        var cells: [Cell] = []
        guard r0 <= r1 else {
            return cells
        }
        for r in r0 ... r1 {
            let rowShift: CGFloat = r.isMultiple(of: 2) ? 0.0 : self.dx / 2.0
            let c0 = Int(floor((-margin - ox - rowShift) / self.dx))
            let c1 = Int(ceil((size.width + margin - ox - rowShift) / self.dx))
            guard c0 <= c1 else {
                continue
            }
            for c in c0 ... c1 {
                let h = QrStudioLattice.hash(r, c)
                let then = lags[min(Int(qrStudioFract(h * 29.3) * 8.0), 7)]
                let radius = orbitLower + orbitRange * CGFloat(qrStudioFract(h * 31.7))
                let period = 9.0 + 11.0 * qrStudioFract(h * 37.1)
                let a = (qrStudioFract(h * 43.3) < 0.5 ? -1.0 : 1.0) * 2.0 * .pi * t / period + h * 6.283
                let ownX = then.x - ox + radius * CGFloat(cos(a))
                let ownY = then.y - oy + radius * CGFloat(sin(a))
                cells.append(Cell(
                    r: r,
                    c: c,
                    point: CGPoint(x: CGFloat(c) * self.dx + rowShift + ox + ownX, y: CGFloat(r) * self.dy + oy + ownY),
                    hash: h
                ))
            }
        }
        return cells
    }

    static func hash(_ r: Int, _ c: Int) -> Double {
        var h = UInt64(bitPattern: Int64(r)) &* 0x9E37_79B9_7F4A_7C15 ^ UInt64(bitPattern: Int64(c)) &* 0xC2B2_AE3D_27D4_EB4F
        h ^= h >> 31
        h &*= 0xBF58_476D_1CE4_E5B9
        h ^= h >> 27
        h &*= 0x94D0_49BB_1331_11EB
        h ^= h >> 31
        return Double(h >> 11) / Double(UInt64(1) << 53)
    }
}

enum QrStudioMesh {
    static func points(at time: Double, pull: SIMD2<Double>) -> [SIMD2<Float>] {
        let px = 0.32 * tanh(pull.x * 2.5)
        let py = 0.32 * tanh(pull.y * 2.5)
        func p(_ x: Double, _ y: Double) -> SIMD2<Float> {
            return SIMD2(Float(x), Float(y))
        }
        func inner(_ v: Double) -> Double {
            let d = v - 0.5
            let a = abs(d)
            let knee = 0.3
            let room = 0.12
            guard a > knee else {
                return v
            }
            return 0.5 + (d < 0.0 ? -1.0 : 1.0) * (knee + room * tanh((a - knee) / room))
        }
        let t = time * 0.6
        return [
            p(0.0, 0.0),
            p(inner(0.5 + 0.22 * sin(t * 0.55) + px * 0.6), 0.0),
            p(1.0, 0.0),
            p(0.0, inner(0.5 + 0.2 * sin(t * 0.47 + 1.0) + py * 0.6)),
            p(inner(0.5 + 0.24 * sin(t * 0.41 + 0.6) + px), inner(0.5 + 0.22 * sin(t * 0.6 + 2.1) + py)),
            p(1.0, inner(0.5 + 0.2 * sin(t * 0.52 + 3.0) + py * 0.6)),
            p(0.0, 1.0),
            p(inner(0.5 + 0.22 * sin(t * 0.45 + 2.0) + px * 0.6), 1.0),
            p(1.0, 1.0)
        ]
    }
}

func qrStudioEmojiIndex(r: Int, c: Int, count: Int) -> Int {
    guard count > 0 else {
        return 0
    }
    let q = c - (r - (r & 1)) / 2
    let value = (q - r) % count
    return value < 0 ? value + count : value
}

func qrStudioPhaseGroup(hash: Double) -> Int {
    return min(5, max(0, Int(hash * 6.0)))
}

struct QrStudioStageStack<Item> {
    private(set) var layers: [(id: Int, item: Item)] = []
    private var serial = 0

    mutating func push(_ item: Item) -> Int {
        self.serial += 1
        self.layers.append((self.serial, item))
        return self.serial
    }

    mutating func replaceTop(_ item: Item) {
        guard !self.layers.isEmpty else {
            return
        }
        self.layers[self.layers.count - 1].item = item
    }

    mutating func revealCompleted(id: Int) -> [Int] {
        guard let index = self.layers.firstIndex(where: { $0.id == id }) else {
            return []
        }
        let removed = self.layers[0 ..< index].map { $0.id }
        self.layers.removeFirst(index)
        return removed
    }
}

enum QrStudioSweep {
    static let transition: Double = 1.3
    static let sweepTime: Double = 0.49
    static let depth: CGFloat = 9.0
    static let lag: CGFloat = 8.0
    static let fade: CGFloat = 26.0
    static let hot: CGFloat = 22.0
    static let canvasPad: CGFloat = 16.0

    private static func span(_ side: CGFloat) -> CGFloat {
        return side + self.depth * 2.0 + self.lag + self.fade + self.hot
    }

    static func front(at s: Double, side: CGFloat) -> CGFloat {
        let p = min(1.0, max(0.0, s / self.sweepTime))
        let e = p < 0.5 ? 2.0 * p * p : 1.0 - pow(-2.0 * p + 2.0, 2.0) / 2.0
        return side + self.depth - self.span(side) * CGFloat(e)
    }

    static func time(at y: CGFloat, side: CGFloat) -> Double {
        let c = min(1.0, max(0.0, Double((side + self.depth - y) / self.span(side))))
        let p = c < 0.5 ? (c / 2.0).squareRoot() : 1.0 - (2.0 * (1.0 - c)).squareRoot() / 2.0
        return p * self.sweepTime
    }

    static func hash(_ x: Int32, _ y: Int32) -> Double {
        var h = UInt32(bitPattern: x) &* 0x8DA6_B343 ^ UInt32(bitPattern: y) &* 0xD816_3841
        h ^= h >> 13
        h = h &* 0x5BD1_E995
        h ^= h >> 15
        return Double(h & 0xFFFF) / 65535.0
    }

    static func noise(_ x: Double, _ y: Double) -> Double {
        let ix = floor(x)
        let iy = floor(y)
        let fx = x - ix
        let fy = y - iy
        let ux = fx * fx * (3.0 - 2.0 * fx)
        let uy = fy * fy * (3.0 - 2.0 * fy)
        let i = Int32(ix)
        let j = Int32(iy)
        let a = self.hash(i, j)
        let b = self.hash(i &+ 1, j)
        let c = self.hash(i, j &+ 1)
        let d = self.hash(i &+ 1, j &+ 1)
        let ab = a + (b - a) * ux
        let cd = c + (d - c) * ux
        return ab + (cd - ab) * uy
    }

    static func edge(x: CGFloat, front: CGFloat, since: Double) -> CGFloat {
        let n = 0.6 * self.noise(Double(x) / 9.0 + 3.0, since * 3.0) + 0.4 * self.noise(Double(x) / 3.5 + 7.0, since * 6.0)
        return front + self.depth * CGFloat(n)
    }
}

func qrStudioTokenRefreshDelay(expires: Double, now: Double, staleAttempt: Int) -> Double {
    if expires > now {
        return expires - now
    }
    return min(15.0, pow(2.0, Double(min(staleAttempt, 8))))
}

func qrStudioTokenIsExpired(expires: Double, now: Double) -> Bool {
    return now >= expires
}
