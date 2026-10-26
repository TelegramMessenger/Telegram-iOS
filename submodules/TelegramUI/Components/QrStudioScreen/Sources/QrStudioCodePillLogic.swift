import Foundation
import CoreGraphics

enum QrStudioCodeAction: Hashable {
    case expire
    case permanent
    case restore
    case renew
}

struct QrStudioCodeState: Equatable {
    static let lifetime: Double = 60.0
    static let refreshLead: Double = 20.0

    var removeFee = false
    var expires = false
    var issuedAt: Double = -100.0
    var pourFrom: Double = 0.0
    var lifetime: Double = QrStudioCodeState.lifetime

    func remaining(at time: Double) -> Double {
        return max(0.0, self.lifetime - (time - self.issuedAt))
    }

    func needsNextCode(at time: Double) -> Bool {
        return self.removeFee && self.expires && self.remaining(at: time) <= QrStudioCodeState.refreshLead
    }

    mutating func perform(_ action: QrStudioCodeAction, at time: Double) {
        let wasExpiring = self.expires
        switch action {
        case .expire:
            self.removeFee = true
            self.expires = true
        case .permanent:
            self.removeFee = true
            self.expires = false
        case .restore:
            self.removeFee = false
            self.expires = false
        case .renew:
            break
        }
        self.pourFrom = wasExpiring && self.expires ? self.remaining(at: time) / self.lifetime : 0.0
        self.issuedAt = time
    }

    mutating func adopt(deadline: Double, at time: Double) {
        if time - self.issuedAt < QrStudioBurn.refill {
            self.lifetime = max(1.0, deadline - self.issuedAt)
        } else {
            self.pourFrom = min(1.0, self.remaining(at: time) / self.lifetime)
            self.issuedAt = time
            self.lifetime = max(1.0, deadline - time)
        }
    }
}

struct QrStudioShatter: Equatable {
    static let duration: Double = 0.75

    var at: Double
    var width: CGFloat
    var level: Double

    var front: CGFloat {
        return min(self.width, CGFloat(self.level) * (self.width + QrStudioBurn.band))
    }
}

struct QrStudioParticle {
    var x: CGFloat
    var y: CGFloat
    var radius: CGFloat
    var alpha: Double
    var heat: Double
    var halo: Bool
}

enum QrStudioBurn {
    static let band: CGFloat = 10.0
    static let edge: CGFloat = 4.0
    static let refill: Double = 0.36
    static let dustRate: Double = 90.0
    static let dustLongest: Double = 2.2

    private static func clamp01(_ x: Double) -> Double {
        return min(1.0, max(0.0, x))
    }

    private static func smooth(_ x: Double) -> Double {
        let x = self.clamp01(x)
        return x * x * (3.0 - 2.0 * x)
    }

    static func hash(_ x: Int32, _ y: Int32) -> Double {
        return QrStudioSweep.hash(x, y)
    }

    static func noise(_ x: Double, _ y: Double) -> Double {
        return QrStudioSweep.noise(x, y)
    }

    static func clock(_ seconds: Double) -> String {
        let value = Int(max(0.0, seconds).rounded(.up))
        return "\(value / 60):" + String(format: "%02d", value % 60)
    }

    static func menu(for state: QrStudioCodeState, allowsPermanent: Bool = true) -> [[QrStudioCodeAction]] {
        guard state.removeFee else {
            return []
        }
        if !allowsPermanent {
            return [[.renew], [.restore]]
        }
        return [[.renew, state.expires ? .permanent : .expire], [.restore]]
    }

    static func shatters(_ state: QrStudioCodeState, action: QrStudioCodeAction) -> Bool {
        return state.expires && (action == .restore || action == .permanent)
    }

    static func pour(_ state: QrStudioCodeState, at time: Double) -> Double {
        let x = self.clamp01((time - state.issuedAt) / self.refill)
        return state.pourFrom + (1.0 - state.pourFrom) * (0.55 * x + 0.45 * x * x)
    }

    static func level(_ state: QrStudioCodeState, at time: Double) -> Double {
        guard state.removeFee, state.expires else {
            return 0.0
        }
        return min(state.remaining(at: time) / state.lifetime, self.pour(state, at: time))
    }

    static func front(_ state: QrStudioCodeState, width: CGFloat, at time: Double) -> CGFloat {
        return (width + self.band) * CGFloat(self.level(state, at: time))
    }

    static func liquid(_ state: QrStudioCodeState, at time: Double) -> CGFloat {
        guard state.expires else {
            return 0.0
        }
        return CGFloat(1.0 - self.smooth((time - state.issuedAt - self.refill) / 0.15))
    }

    static func isPouring(_ state: QrStudioCodeState, at time: Double) -> Bool {
        let since = time - state.issuedAt
        return state.expires && since >= -0.05 && since < self.refill + 0.5
    }

    static func ragged(_ y: CGFloat, _ time: Double) -> CGFloat {
        return CGFloat(0.55 * self.noise(Double(y) / 2.6 + 11.0, time * 0.7) + 0.45 * self.noise(Double(y) / 0.9 + 3.0, time * 1.6))
    }

    static func meniscus(_ y: CGFloat, height: CGFloat, time: Double) -> CGFloat {
        let u = (y - height / 2.0) / (height / 2.0)
        return 7.0 * u * u + CGFloat(0.9 * sin(Double(y) * 0.7 + time * 16.0))
    }

    static func flash(_ state: QrStudioCodeState, at time: Double) -> Double {
        guard state.expires else {
            return 0.0
        }
        let s = time - state.issuedAt - self.refill
        guard s > -0.03, s < 0.3 else {
            return 0.0
        }
        return s < 0.0 ? (s + 0.03) / 0.03 : exp(-s / 0.07)
    }

    static func capsuleRight(_ y: CGFloat, pill: CGSize) -> CGFloat {
        let r = pill.height / 2.0
        let dy = y - r
        return pill.width - r + max(0.0, r * r - dy * dy).squareRoot()
    }

    static func capsuleLeft(_ y: CGFloat, height: CGFloat) -> CGFloat {
        let r = height / 2.0
        let dy = y - r
        return r - max(0.0, r * r - dy * dy).squareRoot()
    }

    static func cutPath(front: CGFloat, rect: CGRect, time: Double, liquid: CGFloat) -> CGPath? {
        if front >= rect.maxX + self.band {
            return CGPath(rect: rect.insetBy(dx: -2.0, dy: -2.0), transform: nil)
        }
        if front <= rect.minX {
            return nil
        }
        let path = CGMutablePath()
        let steps = 26
        path.move(to: CGPoint(x: rect.minX - 2.0, y: rect.minY - 2.0))
        for i in 0 ... steps {
            let y = rect.minY - 2.0 + (rect.height + 4.0) * CGFloat(i) / CGFloat(steps)
            let ragged = self.edge * self.ragged(y, time)
            let meniscus = self.meniscus(y - rect.minY, height: rect.height, time: time)
            path.addLine(to: CGPoint(x: front - ragged * (1.0 - liquid) - meniscus * liquid, y: y))
        }
        path.addLine(to: CGPoint(x: rect.minX - 2.0, y: rect.maxY + 2.0))
        path.closeSubpath()
        return path
    }

    static func timerParticles(_ state: QrStudioCodeState, pill: CGSize, at time: Double) -> [QrStudioParticle] {
        guard state.removeFee, state.expires, pill.width > 0.0 else {
            return []
        }
        var result: [QrStudioParticle] = []
        self.pourParticles(state, pill: pill, at: time, into: &result)

        let start = state.issuedAt + self.refill
        guard time > start else {
            return result
        }
        let now = self.front(state, width: pill.width, at: time)
        if now > 1.0 {
            let spots = 8
            for j in 0 ..< spots {
                let y = 2.0 + (pill.height - 4.0) * CGFloat(j) / CGFloat(spots - 1)
                let x = now - self.edge * self.ragged(y, time)
                guard x < self.capsuleRight(y, pill: pill) - 0.5 else {
                    continue
                }
                let flicker = self.noise(Double(j) * 3.1, time * 3.2)
                result.append(QrStudioParticle(x: x, y: y, radius: 1.8 + 1.2 * CGFloat(flicker), alpha: 0.15 * (0.5 + 0.5 * flicker), heat: 1.0, halo: true))
            }
        }

        let first = max(0, Int(floor((time - self.dustLongest - start) * self.dustRate)))
        let last = Int(floor((time - start) * self.dustRate))
        guard last >= first else {
            return result
        }
        for k in first ... last {
            let born = start + Double(k) / self.dustRate
            func h(_ salt: Int32) -> Double {
                return self.hash(Int32(truncatingIfNeeded: k), salt)
            }
            let spark = h(9) > 0.92
            let life = spark ? 0.6 + 0.5 * h(3) : 1.1 + 1.1 * h(3)
            let tau = time - born
            guard tau >= 0.0, tau < life else {
                continue
            }
            let bornFront = self.front(state, width: pill.width, at: born)
            guard bornFront > 1.0 else {
                continue
            }
            let y = 1.5 + (pill.height - 3.0) * CGFloat(h(1))
            let edgeX = Double(min(bornFront - self.edge * self.ragged(y, born), self.capsuleRight(y, pill: pill))) - 0.8 + 1.4 * h(2)
            guard edgeX > 0.0 else {
                continue
            }
            let k01 = tau / life
            let speed = spark ? 2.2 : 1.0
            let vx = (8.0 + 24.0 * h(4)) * speed
            let vy = -(4.0 + 14.0 * h(5)) * speed
            let px = edgeX + vx * tau + 7.0 * tau * tau + 2.2 * sin(2.6 * tau + 6.283 * h(6)) * tau
            let py = Double(y) + vy * tau - 6.0 * tau * tau + 1.8 * cos(3.3 * tau + 6.283 * h(7)) * tau
            let radius = (spark ? 0.6 : 0.45 + 1.3 * pow(h(8), 2.2)) * (1.0 - 0.5 * k01)
            let heat = spark ? max(0.0, 1.0 - k01 * 1.4) : max(0.0, 1.0 - k01 * 2.5)
            let alpha = min(1.0, tau * 12.0) * pow(1.0 - k01, 1.4) * 0.95
            if heat > 0.05 {
                result.append(QrStudioParticle(x: CGFloat(px), y: CGFloat(py), radius: CGFloat(radius * 3.0 * (0.6 + 0.4 * heat)), alpha: 0.22 * alpha * heat, heat: heat, halo: true))
            }
            result.append(QrStudioParticle(x: CGFloat(px), y: CGFloat(py), radius: CGFloat(radius), alpha: alpha, heat: heat, halo: false))
        }
        return result
    }

    private static func pourParticles(_ state: QrStudioCodeState, pill: CGSize, at time: Double, into result: inout [QrStudioParticle]) {
        let since = time - state.issuedAt
        guard since >= 0.0, since < self.refill + 0.5 else {
            return
        }
        func spark(_ x: Double, _ y: Double, _ r: Double, _ alpha: Double) {
            result.append(QrStudioParticle(x: CGFloat(x), y: CGFloat(y), radius: CGFloat(r * 3.2), alpha: 0.3 * alpha, heat: 1.0, halo: true))
            result.append(QrStudioParticle(x: CGFloat(x), y: CGFloat(y), radius: CGFloat(r), alpha: alpha, heat: 1.0, halo: false))
        }
        let trail = 18
        for k in 0 ..< trail {
            let born = self.refill * Double(k) / Double(trail)
            func h(_ salt: Int32) -> Double {
                return self.hash(Int32(truncatingIfNeeded: k &+ 9000), salt)
            }
            let life = 0.22 + 0.2 * h(3)
            let tau = since - born
            guard tau >= 0.0, tau < life else {
                continue
            }
            let y = 2.0 + (pill.height - 4.0) * CGFloat(h(1))
            let bornFront = self.front(state, width: pill.width, at: state.issuedAt + born)
            let x0 = min(bornFront - self.meniscus(y, height: pill.height, time: state.issuedAt + born), self.capsuleRight(y, pill: pill))
            let k01 = tau / life
            let x = Double(x0) + (-14.0 + 32.0 * h(4)) * tau
            let y1 = Double(y) - (20.0 + 40.0 * h(5)) * tau + 18.0 * tau * tau
            spark(x, y1, (0.5 + 0.9 * h(8)) * (1.0 - 0.5 * k01), pow(1.0 - k01, 1.2))
        }
        let s = since - self.refill
        if s >= 0.0 {
            let burst = 26
            for k in 0 ..< burst {
                func h(_ salt: Int32) -> Double {
                    return self.hash(Int32(truncatingIfNeeded: k &+ 7000), salt)
                }
                let life = 0.25 + 0.25 * h(3)
                guard s < life else {
                    continue
                }
                let k01 = s / life
                let angle = (h(1) - 0.5) * 2.5
                let distance = (110.0 + 170.0 * h(4)) * (1.0 - exp(-6.0 * s)) / 6.0
                let y0 = pill.height * (0.12 + 0.76 * CGFloat(h(2)))
                let x0 = Double(self.capsuleRight(y0, pill: pill)) - 2.0
                spark(x0 + cos(angle) * distance, Double(y0) + sin(angle) * distance - 10.0 * s, (0.7 + 1.4 * h(8)) * (1.0 - 0.6 * k01), pow(1.0 - k01, 1.3))
            }
        }
    }

    static func shatterParticles(_ shatter: QrStudioShatter, at time: Double) -> [QrStudioParticle] {
        let since = time - shatter.at
        guard since >= 0.0, since < QrStudioShatter.duration else {
            return []
        }
        let front = shatter.front
        guard front > 1.0 else {
            return []
        }
        let height: CGFloat = 24.0
        let pill = CGSize(width: shatter.width, height: height)
        let count = Int(70.0 + 230.0 * front / max(shatter.width, 1.0))
        let cx = Double(front) / 2.0
        let cy = Double(height) / 2.0
        let heat = max(0.0, 1.0 - since / 0.2)
        var result: [QrStudioParticle] = []
        result.reserveCapacity(count * 2)
        for k in 0 ..< count {
            func r(_ salt: Int32) -> Double {
                return self.hash(Int32(truncatingIfNeeded: k &+ 5000), salt)
            }
            let y0 = 1.0 + (Double(height) - 2.0) * r(2)
            let left = Double(self.capsuleLeft(CGFloat(y0), height: height))
            let right = min(Double(front), Double(self.capsuleRight(CGFloat(y0), pill: pill)))
            guard right > left else {
                continue
            }
            let x0 = left + (right - left) * r(1)
            var dx = (x0 - cx) / max(cx, 1.0)
            var dy = (y0 - cy) / cy * 1.6
            let jitter = (r(3) - 0.5) * 1.6
            let a = atan2(dy, dx) + jitter
            let len = (dx * dx + dy * dy).squareRoot()
            dx = cos(a)
            dy = sin(a)
            let fine = r(8) < 0.82
            let speed = (fine ? 150.0 + 300.0 * r(4) : 80.0 + 120.0 * r(4)) * (0.55 + 0.45 * min(1.0, len))
            let drag = fine ? 6.0 : 4.5
            let travel = speed * (1.0 - exp(-drag * since)) / drag
            let life = fine ? 0.35 + 0.3 * r(5) : 0.5 + 0.25 * r(5)
            guard since < life else {
                continue
            }
            let k01 = since / life
            let px = x0 + dx * travel + 2.4 * sin(5.0 * since + 6.283 * r(6)) * since
            let py = y0 + dy * travel - (10.0 + 16.0 * r(7)) * since * since
            let size = (fine ? 0.45 + 0.9 * pow(r(9), 1.6) : 1.4 + 1.6 * r(9)) * (1.0 - 0.45 * k01)
            let alpha = pow(1.0 - k01, 1.25)
            if heat > 0.05 {
                result.append(QrStudioParticle(x: CGFloat(px), y: CGFloat(py), radius: CGFloat(size * 3.0), alpha: 0.28 * heat, heat: heat, halo: true))
            }
            result.append(QrStudioParticle(x: CGFloat(px), y: CGFloat(py), radius: CGFloat(size), alpha: alpha, heat: heat, halo: false))
        }
        return result
    }
}
