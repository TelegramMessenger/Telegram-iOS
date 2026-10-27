import Foundation
import CoreGraphics
import QuartzCore

/// The squash, stretch and drift of a moving lens: UIKit's `_UIFlexInteraction` (iOS 27) with the movement source and
/// the loupe variant, as `_UILiquidLensView` sets up the one it attaches to itself, ported so that `LiquidLensView`
/// drives it from where the lens really is.
///
/// UIKit reconstructs the lens's motion by sampling the lens view's centre once per `UIUpdateLink` tick. The first
/// sample after a lift is often the view's model position, the destination of the position animation that starts with
/// the lift, instead of where the lens is on screen: the velocity then starts with the wrong sign and the acceleration
/// spikes, and since the drift takes its direction from the velocity, the stretch is anchored at the leading edge
/// instead of the trailing one until the velocity recovers, ~130 ms into the move. Whether that sample happens depends
/// on frame timing (the tab switch's main thread work), so moves in opposite directions bounce differently. The
/// response below is mirror-symmetric: a move to the left is the mirror image of the same move to the right.
public struct LiquidLensFlex: Equatable {
    public var scaleX: CGFloat
    public var scaleY: CGFloat
    public var driftX: CGFloat
    public var driftY: CGFloat

    public init(scaleX: CGFloat, scaleY: CGFloat, driftX: CGFloat, driftY: CGFloat) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.driftX = driftX
        self.driftY = driftY
    }

    public static let identity = LiquidLensFlex(scaleX: 1.0, scaleY: 1.0, driftX: 0.0, driftY: 0.0)

    /// UIKit applies it as `CATransform3DTranslate(CATransform3DMakeScale(sx, sy, 1), dx, dy, 0)`, through an additive
    /// presentation modifier on the lens view's layer, whose own transform is the identity.
    public var transform: CATransform3D {
        return CATransform3DTranslate(CATransform3DMakeScale(self.scaleX, self.scaleY, 1.0), self.driftX, self.driftY, 0.0)
    }

    /// What `-[_UIFlexInteraction updateFlex]` animates to while it is active, for a lens of `size` moving with
    /// `velocity` and the directionless `acceleration` of `LiquidLensMotion`. Speeding up along an axis stretches the
    /// lens along it and squashes it across, slowing down does the opposite; the drift keeps the leading edge where the
    /// lens is and lets the trailing edge lag or catch up. UIKit takes the drift's direction with `copysign`, which turns
    /// a velocity of zero into a direction; here it has none.
    public static func target(size: CGSize, velocity: CGPoint, acceleration: CGPoint) -> LiquidLensFlex {
        let spec = LiquidLensFlexSpec(size: size)
        let rangeX = spec.scaleRange(dimension: size.width)
        let rangeY = spec.scaleRange(dimension: size.height)
        let normalizedX = acceleration.x / spec.movementNormalizationFactor
        let normalizedY = acceleration.y / spec.movementNormalizationFactor

        var result = LiquidLensFlex.identity
        if normalizedX != 0.0 && !normalizedX.isNaN {
            let stretch = softClamp(lerp(normalizedX, 1.0, rangeX.max), rangeX.min, rangeX.max)
            result.scaleX += stretch - 1.0
            result.driftX += (1.0 - stretch) * 0.5 * size.width * direction(velocity.x)
            result.scaleY += softClamp(lerp(normalizedX, 1.0, rangeY.min), rangeY.min, rangeY.max) - 1.0
        }
        if normalizedY != 0.0 && !normalizedY.isNaN {
            let stretch = softClamp(lerp(normalizedY, 1.0, rangeY.max), rangeY.min, rangeY.max)
            result.scaleY += stretch - 1.0
            result.driftY += (1.0 - stretch) * 0.5 * size.height * direction(velocity.y)
            result.scaleX += softClamp(lerp(normalizedY, 1.0, rangeX.min), rangeX.min, rangeX.max) - 1.0
        }
        return result
    }
}

/// The lens's velocity and acceleration from its positions: `_UIVelocityIntegrator` as `_UIFlexInteraction` sets it
/// up (an exponential moving average of 0.3 on the position, on the velocity and on the acceleration, and a
/// directionless acceleration: the change of the speed along each axis, positive while the lens speeds up whichever way
/// it moves). On the same samples it matches UIKit's integrator to a tenth of a point per second. UIKit averages per
/// sample at the display's rate; here the averages are per 1/120 s, so a dropped frame does not change them.
public struct LiquidLensMotion: Equatable {
    public private(set) var velocity: CGPoint = CGPoint()
    public private(set) var acceleration: CGPoint = CGPoint()

    private var position: CGPoint?
    private var timestamp: Double = 0.0
    private var hasVelocity: Bool = false
    private var hasAcceleration: Bool = false

    public init() {
    }

    public mutating func add(position sample: CGPoint, timestamp: Double) {
        guard let position = self.position else {
            self.position = sample
            self.timestamp = timestamp
            return
        }
        let deltaTime = timestamp - self.timestamp
        if deltaTime <= 0.0 {
            return
        }
        let weight = 1.0 - pow(0.7, deltaTime * 120.0)

        let filteredPosition = CGPoint(x: lerp(weight, position.x, sample.x), y: lerp(weight, position.y, sample.y))
        let sampleVelocity = CGPoint(x: (filteredPosition.x - position.x) / deltaTime, y: (filteredPosition.y - position.y) / deltaTime)
        let velocity = self.hasVelocity ? CGPoint(x: lerp(weight, self.velocity.x, sampleVelocity.x), y: lerp(weight, self.velocity.y, sampleVelocity.y)) : sampleVelocity
        let sampleAcceleration = CGPoint(x: (abs(velocity.x) - abs(self.velocity.x)) / deltaTime, y: (abs(velocity.y) - abs(self.velocity.y)) / deltaTime)
        let acceleration = self.hasAcceleration ? CGPoint(x: lerp(weight, self.acceleration.x, sampleAcceleration.x), y: lerp(weight, self.acceleration.y, sampleAcceleration.y)) : sampleAcceleration

        self.position = filteredPosition
        self.timestamp = timestamp
        self.velocity = velocity
        self.acceleration = acceleration
        self.hasVelocity = true
        self.hasAcceleration = true
    }
}

/// Carries the flex to its target the way UIKit does: `-[UIView _animateUsingSpringBehavior:tracking:]` with the
/// variant's scale spring, retargeted every frame, tracking while the flex is active and settling back to the identity
/// after it.
public struct LiquidLensFlexAnimator: Equatable {
    public private(set) var flex: LiquidLensFlex = .identity
    private var velocity: LiquidLensFlex = LiquidLensFlex(scaleX: 0.0, scaleY: 0.0, driftX: 0.0, driftY: 0.0)

    public init() {
    }

    public var isSettled: Bool {
        let flex = self.flex
        let velocity = self.velocity
        return abs(flex.scaleX - 1.0) < 0.0005 && abs(flex.scaleY - 1.0) < 0.0005 && abs(flex.driftX) < 0.01 && abs(flex.driftY) < 0.01 && abs(velocity.scaleX) < 0.005 && abs(velocity.scaleY) < 0.005 && abs(velocity.driftX) < 0.1 && abs(velocity.driftY) < 0.1
    }

    public mutating func reset() {
        self = LiquidLensFlexAnimator()
    }

    public mutating func step(toward target: LiquidLensFlex, size: CGSize, isTracking: Bool, deltaTime: Double) {
        let spec = LiquidLensFlexSpec(size: size)
        let response = isTracking ? spec.trackingResponse : spec.response
        let dampingRatio = isTracking ? spec.trackingDampingRatio : spec.dampingRatio
        let stiffness = pow(2.0 * CGFloat.pi / response, 2.0)
        let damping = 4.0 * CGFloat.pi * dampingRatio / response

        var remaining = CGFloat(max(0.0, min(deltaTime, 0.1)))
        while remaining > 0.0 {
            let step = min(remaining, 1.0 / 480.0)
            remaining -= step
            springStep(&self.flex.scaleX, &self.velocity.scaleX, target.scaleX, stiffness, damping, step)
            springStep(&self.flex.scaleY, &self.velocity.scaleY, target.scaleY, stiffness, damping, step)
            springStep(&self.flex.driftX, &self.velocity.driftX, target.driftX, stiffness, damping, step)
            springStep(&self.flex.driftY, &self.velocity.driftY, target.driftY, stiffness, damping, step)
        }
    }
}

/// `_UIFlexInteractionSpec`'s `smallLoupe` and `loupe` variant specs, interpolated by the lens's shorter side between
/// their `associatedDimension`s, 37 and 70 points (UIKit's variant 4, `sub_1c5126e6c` in UIKitCore 27.0).
struct LiquidLensFlexSpec {
    let movementScalePoints: CGFloat
    let movementMinScale: CGFloat
    let movementMaxScale: CGFloat
    let movementNormalizationFactor: CGFloat
    let response: CGFloat
    let dampingRatio: CGFloat
    let trackingResponse: CGFloat
    let trackingDampingRatio: CGFloat

    init(size: CGSize) {
        var fraction = (min(size.width, size.height) - 37.0) / (70.0 - 37.0)
        if !fraction.isFinite || fraction < 0.0 {
            fraction = 0.0
        }
        fraction = min(fraction, 1.0)

        self.movementScalePoints = lerp(fraction, 10.0, 100.0)
        self.movementMinScale = lerp(fraction, 0.9, 0.75)
        self.movementMaxScale = lerp(fraction, 1.1, 1.15)
        self.movementNormalizationFactor = lerp(fraction, 2000.0, 2500.0)
        self.response = lerp(fraction, 0.444, 0.5)
        self.dampingRatio = lerp(fraction, 0.56, 1.0)
        self.trackingResponse = lerp(fraction, 0.444, 0.5)
        self.trackingDampingRatio = lerp(fraction, 0.56, 0.9)
    }

    /// The scale an axis may reach: at most `movementScalePoints` either way, within the variant's scale limits.
    func scaleRange(dimension: CGFloat) -> (min: CGFloat, max: CGFloat) {
        if dimension <= 0.0 {
            return (1.0, 1.0)
        }
        return (max(self.movementMinScale, (dimension - self.movementScalePoints) / dimension), min((dimension + self.movementScalePoints) / dimension, self.movementMaxScale))
    }
}

/// `_UILerp`: `(1 - t) * a + t * b`.
private func lerp(_ t: CGFloat, _ a: CGFloat, _ b: CGFloat) -> CGFloat {
    return (1.0 - t) * a + t * b
}

/// UIKit's rubber-banded clamp: a value past either limit approaches it plus a third of the range, along `tanh`.
private func softClamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
    let reach = (upper - lower) / 3.0
    if reach <= 0.0 {
        return min(max(value, lower), upper)
    }
    if value < lower {
        return lower + reach * tanh(0.55 * (value - lower) / reach)
    } else if value > upper {
        return upper + reach * tanh(0.55 * (value - upper) / reach)
    } else {
        return value
    }
}

private func direction(_ value: CGFloat) -> CGFloat {
    if value > 0.0 {
        return 1.0
    } else if value < 0.0 {
        return -1.0
    } else {
        return 0.0
    }
}

private func springStep(_ value: inout CGFloat, _ velocity: inout CGFloat, _ target: CGFloat, _ stiffness: CGFloat, _ damping: CGFloat, _ deltaTime: CGFloat) {
    let force = -stiffness * (value - target) - damping * velocity
    velocity += force * deltaTime
    value += velocity * deltaTime
}
