import Foundation

// Public-API model ported from Revealer/Swipe. Response/damping are the measured
// oscillator parameters, not the unrelated CA animation duration/metadata.
struct ItemListRevealSpring {
    var value: Double = 0
    var velocity: Double = 0
    var target: Double = 0
    var response: Double = 0.5
    var damping: Double = 1

    var isAtRest: Bool { return abs(self.value - self.target) < 0.001 && abs(self.velocity) < 0.01 }

    mutating func snap(to value: Double) {
        self.value = value
        self.target = value
        self.velocity = 0
    }

    mutating func advance(by dt: Double) {
        guard dt > 0, dt.isFinite else { return }
        if self.isAtRest { self.snap(to: self.target); return }
        let w = 2 * Double.pi / max(0.01, self.response)
        let z = max(0.01, self.damping)
        let y = self.value - self.target, v = self.velocity
        if abs(z - 1) < 0.00001 {
            let e = exp(-w * dt), k = v + w * y
            self.value = self.target + (y + k * dt) * e
            self.velocity = (v - w * k * dt) * e
        } else if z < 1 {
            let a = w * z, b = w * sqrt(1 - z * z)
            let e = exp(-a * dt), c = cos(b * dt), s = sin(b * dt)
            self.value = self.target + e * (y * c + (v + a * y) / b * s)
            self.velocity = e * (v * c - (a * v + w * w * y) / b * s)
        } else {
            let q = sqrt(z * z - 1), r1 = -w * (z - q), r2 = -w * (z + q)
            let a = (v - r2 * y) / (r1 - r2), b = y - a
            let e1 = exp(r1 * dt), e2 = exp(r2 * dt)
            self.value = self.target + a * e1 + b * e2
            self.velocity = a * r1 * e1 + b * r2 * e2
        }
    }
}

struct ItemListRevealMotionParameters {
    var width: Double = 0
    var buttonWidth: Double = 50
    var spacing: Double = 10
    var edgeInset: Double = 10
    var sideInset: Double = 0
    var count: Int = 0
    var isDestructive = false
    var displayScale: Double = 2

    var openDistance: Double {
        return self.count == 0 ? 0 : self.sideInset + 2 * self.edgeInset + Double(self.count) * self.buttonWidth + Double(self.count - 1) * self.spacing
    }

    var confirmationDistance: Double {
        let distance = self.isDestructive ? max(self.openDistance, self.width - 29) : min(self.width, max(self.openDistance + 20, self.width * 0.525))
        let scale = max(1, self.displayScale)
        return (distance * scale).rounded() / scale
    }

    var armedDistance: Double {
        return self.isDestructive ? self.confirmationDistance : max(self.confirmationDistance, self.width * 0.75)
    }

    var edgeZone: Double { return self.width >= 414 ? 90 : (self.width == 375 ? 75 : 50) }

    func edgeFraction(velocity: Double) -> Double {
        return min(self.width >= 414 ? 0.75 : 0.8, max(self.width >= 414 ? 0.5 : 0.66, abs(velocity) / 2500))
    }

    func resisted(_ distance: Double, inverse: Bool = false) -> Double {
        let exponent = inverse ? 1 / 0.7 : 0.7
        if distance < 0 { return -pow(-distance, exponent) }
        if distance > self.confirmationDistance { return self.confirmationDistance + pow(distance - self.confirmationDistance, exponent) }
        return distance
    }
}

struct ItemListRevealButtonGeometry {
    // Distance of the center from the outside edge; index zero is the primary.
    var center: Double
    var width: Double
    var scale: Double
    var opacity: Double

    static func calculate(reveal: Double, expansion: Double, parameters p: ItemListRevealMotionParameters) -> [ItemListRevealButtonGeometry] {
        let distance = max(0, reveal)
        let consolidation = p.isDestructive ? 0 : min(1, max(0, expansion))
        return (0..<p.count).map { index in
            let outside = p.sideInset + p.edgeInset + Double(index) * (p.buttonWidth + p.spacing)
            let end = outside + p.buttonWidth + p.edgeInset
            let start = end - p.buttonWidth + 2 * p.spacing
            var scale = min(1, max(0, (distance - start) / max(1, end - start)))
            var opacity = scale
            var width = p.buttonWidth
            var center = outside + width / 2
            if index == 0 {
                // Keep the same geometry on both sides of openDistance. The
                // expansion spring may still be unwinding during a fast retreat.
                let stretchedWidth = width + max(0, distance - p.openDistance)
                let expandedWidth = max(width, distance - p.sideInset - 2 * p.edgeInset)
                width = stretchedWidth + (expandedWidth - stretchedWidth) * consolidation
                center = p.sideInset + p.edgeInset + width / 2
            }
            if distance > p.openDistance + 0.001 {
                if index == 0 {
                    scale = 1
                    opacity = 1
                } else {
                    center += distance - p.openDistance
                    scale = 1 - consolidation
                    opacity = (1 - min(1, distance / max(1, p.confirmationDistance)) * 0.7) * (1 - consolidation)
                }
            }
            return ItemListRevealButtonGeometry(center: center, width: width, scale: scale, opacity: opacity < 0.01 ? 0 : opacity)
        }
    }
}

struct ItemListRevealMotion {
    enum State: Equatable {
        case closed
        case dragging
        case settling(open: Bool)
        case open
        case filling
    }

    var parameters = ItemListRevealMotionParameters()
    private(set) var state: State = .closed
    private(set) var isArmed = false
    private(set) var body = ItemListRevealSpring()
    private(set) var surface = ItemListRevealSpring(response: 0.66, damping: 0.95)
    private(set) var surfaceOpacity = ItemListRevealSpring(response: 0.66, damping: 0.95)
    private(set) var expansion = ItemListRevealSpring()
    private(set) var scales: [ItemListRevealSpring] = []
    private(set) var opacities: [ItemListRevealSpring] = []
    private var initial = 0.0
    private var confirmationAdjustment = 0.0
    private var gestureOriginAdjustment = 0.0
    private var continuingSpring = false

    var isAtRest: Bool {
        return self.body.isAtRest && self.surface.isAtRest && self.surfaceOpacity.isAtRest && self.expansion.isAtRest && self.scales.allSatisfy(\.isAtRest) && self.opacities.allSatisfy(\.isAtRest)
    }
    var wantsOpen: Bool { return self.state == .dragging || self.body.target > 0 }
    var isExpanded: Bool { return self.isArmed || self.state == .filling }

    var buttonGeometry: [ItemListRevealButtonGeometry] {
        // Readiness changes the target immediately, but the primary's width and
        // content placement follow the same spring in both directions.
        return ItemListRevealButtonGeometry.calculate(reveal: self.body.value, expansion: self.expansion.value, parameters: self.parameters)
    }

    mutating func configure(_ parameters: ItemListRevealMotionParameters) {
        self.parameters = parameters
        if self.scales.count != parameters.count {
            self.scales = Array(repeating: ItemListRevealSpring(response: 0.5, damping: 0.7), count: parameters.count)
            self.opacities = Array(repeating: ItemListRevealSpring(), count: parameters.count)
        }
        self.retargetButtons()
    }

    mutating func begin(highlightAlpha: Double = 0) {
        let settling: Bool
        if case .settling = self.state {
            settling = abs(self.body.value - self.body.target) > 0.5 || abs(self.body.velocity) > 5
        } else {
            settling = false
        }
        self.continuingSpring = settling
        // Body and expansion share the same spring. Remove the animated advance
        // before inverting resistance, so regrabbing cannot count it as finger
        // travel and immediately arm the action again. Fill has its own target.
        let advance = self.state == .filling ? 0 : self.parameters.armedDistance - self.parameters.confirmationDistance
        let trackingPosition = self.body.value - advance * self.expansion.value
        let trackingTarget = self.body.target - advance * self.expansion.target
        self.initial = self.parameters.resisted(trackingPosition, inverse: true)
        self.gestureOriginAdjustment = settling ? self.parameters.resisted(trackingTarget, inverse: true) - self.initial : 0
        self.confirmationAdjustment = 0
        self.isArmed = false
        self.state = .dragging
        self.surface.target = 1
        // A held row may already have a touch highlight. Preserve its opacity
        // while its previously square background starts rounding independently.
        if highlightAlpha > self.surfaceOpacity.value { self.surfaceOpacity.snap(to: highlightAlpha) }
        self.surfaceOpacity.target = 1
    }

    mutating func change(translation: Double, velocity: Double, distanceFromCommitEdge: Double, reduceMotion: Bool = false) {
        guard self.state == .dragging else { return }
        var proposed = self.initial + translation + self.gestureOriginAdjustment + self.confirmationAdjustment
        let confirmation = self.parameters.confirmationDistance
        var armed = proposed >= confirmation
        if !armed && proposed > confirmation * self.parameters.edgeFraction(velocity: velocity) && distanceFromCommitEdge < self.parameters.edgeZone {
            armed = true
            if self.confirmationAdjustment == 0 {
                self.confirmationAdjustment = confirmation - proposed
                proposed = confirmation
            }
        }
        self.isArmed = armed
        if armed && !reduceMotion {
            // Once the spring takes over, keep it for the remainder of this
            // touch. Disarming must preserve its current position and velocity.
            self.continuingSpring = true
        }
        // Readiness advances the entire row, with further finger travel resisted
        // from that new resting position. The trigger distance stays unchanged.
        let target = self.parameters.resisted(proposed) + (armed ? self.parameters.armedDistance - confirmation : 0)
        if (armed || self.continuingSpring) && !reduceMotion {
            self.body.target = target
        } else {
            self.body.snap(to: target)
        }
        self.retargetButtons()
        if reduceMotion { self.snapToTargets() }
    }

    // Action policy belongs to the host. A commit first resolves to open, then
    // the synchronous handler may close, fill, or retain the open actions.
    @discardableResult mutating func end(translation: Double, velocity: Double, cancelled: Bool, animated: Bool = true) -> Bool {
        guard self.state == .dragging else { return false }
        let commit = !cancelled && self.isArmed
        let open = commit || (abs(velocity) > 50 ? velocity > 50 : self.initial + translation + self.gestureOriginAdjustment > self.parameters.openDistance / 2)
        self.settle(to: open ? self.parameters.openDistance : 0, velocity: velocity, animated: animated)
        return commit
    }

    mutating func settle(to target: Double, velocity: Double, animated: Bool, filling: Bool = false) {
        self.state = filling ? .filling : .settling(open: target > 0)
        self.isArmed = false
        self.continuingSpring = false
        self.body.target = target
        self.body.velocity = Self.transferredVelocity(velocity, position: self.body.value, target: target)
        self.surface.target = target > 0 ? 1 : 0
        self.surfaceOpacity.target = self.surface.target
        self.retargetButtons()
        if !animated { self.snapToTargets(); self.didSettle() }
    }

    static func transferredVelocity(_ velocity: Double, position: Double, target: Double) -> Double {
        let remaining = target - position
        guard abs(remaining) > 0.000001 else { return 0 }
        return min(100, max(0, velocity / remaining)) * remaining
    }

    private mutating func retargetButtons() {
        self.expansion.target = self.isExpanded ? 1 : 0
        let geometry = ItemListRevealButtonGeometry.calculate(reveal: self.body.target, expansion: self.expansion.target, parameters: self.parameters)
        for i in self.scales.indices {
            self.scales[i].target = geometry[i].scale
            self.opacities[i].target = geometry[i].opacity
            self.opacities[i].response = self.state == .dragging ? 0.25 : 0.5
        }
    }

    mutating func snapToTargets() {
        self.body.snap(to: self.body.target)
        self.surface.snap(to: self.surface.target)
        self.surfaceOpacity.snap(to: self.surfaceOpacity.target)
        self.expansion.snap(to: self.expansion.target)
        for i in self.scales.indices {
            self.scales[i].snap(to: self.scales[i].target)
            self.opacities[i].snap(to: self.opacities[i].target)
        }
    }

    mutating func advance(by dt: Double) {
        if self.state != .dragging || self.isArmed || self.continuingSpring { self.body.advance(by: dt) }
        self.surface.advance(by: dt)
        self.surfaceOpacity.advance(by: dt)
        self.retargetButtons()
        self.expansion.advance(by: dt)
        for i in self.scales.indices {
            self.scales[i].advance(by: dt)
            self.opacities[i].advance(by: dt)
        }
        if self.isAtRest { self.snapToTargets(); self.didSettle() }
    }

    private mutating func didSettle() {
        if case let .settling(open) = self.state { self.state = open ? .open : .closed }
    }

    mutating func reset() {
        let parameters = self.parameters
        self = Self()
        self.configure(parameters)
    }
}
