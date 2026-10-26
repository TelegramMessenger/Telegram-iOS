import Foundation
import simd

// MARK: - Transfer card timing

struct DiamondTransferAnimation {
    enum Phase {
        case sending
        case receiving
        case completion
    }

    static let completionDuration: Float = 1.8
    let phase: Phase
    let startTime: Float

    func presentation(at time: Float) -> (energy: Float, scale: Float, offset: Float) {
        let t = max(0, time - self.startTime)
        let energy: Float
        let hit: Float
        let breath: Float
        let blow: Float
        switch self.phase {
        case .sending, .receiving:
            energy = pow(min(t / 0.45, 1), 0.65)
            hit = self.phase == .sending && t < 0.42 ? sin(.pi * t / 0.42) * (1 - 0.3 * t / 0.42) : 0
            breath = sin(2 * .pi * 1.1 * t)
            blow = 0
        case .completion:
            energy = pow(1 - min(t / 0.7, 1), 2.2)
            hit = 0
            breath = 0
            blow = t < 0.9 ? sin(2 * .pi * 1.6 * t) * exp(-t / 0.2) : 0
        }
        let offset: Float = self.phase != .completion ? -1.6 * energy * sin(2 * .pi * 1.1 * (t - 0.18)) : 0
        return (energy, 1 + 0.32 * hit + 0.07 * energy * breath + blow, offset)
    }
}

// MARK: - Motion and interaction

struct DiamondMotion {
    private struct TapRotation {
        var velocity: Float
        var boost: Float
        let decayTime: Float
        let responseTime: Float
        let isFast: Bool

        mutating func step(dt: Float, speed: Float) -> Float {
            let previousVelocity = velocity
            boost *= exp(-dt / decayTime)
            let targetVelocity = speed + boost
            velocity += (targetVelocity - velocity) * (1 - exp(-dt / responseTime))
            if abs(boost) < 0.001 && abs(velocity - speed) < 0.001 {
                boost = 0
                velocity = speed
            }
            return (previousVelocity + velocity) * 0.5 * dt
        }
    }

    static let referencePitch: Float = -0.104458
    private static let pitchLimit: Float = 1.1
    private static let springFrequency: Float = 3 * 2 * .pi
    private static let springDamping: Float = 0.8
    private static let tapUnlockSpeedMultiplier: Float = 1.4

    private(set) var yaw: Float = 0
    var externalYaw: Float = 0
    var renderedYaw: Float { self.yaw + self.lean + self.externalYaw }
    private(set) var pitch: Float = Self.referencePitch
    private(set) var isDragging = false
    var zoom: Float = 1
    var mainSparkleOnRotation = false {
        didSet {
            if self.mainSparkleOnRotation != oldValue {
                self.rotationSparkle = DiamondSparkleAnimation.RotationPulse()
            }
        }
    }
    private(set) var rotationSparkle = DiamondSparkleAnimation.RotationPulse()

    private var targetYaw: Float = 0
    private var targetPitch: Float = Self.referencePitch
    private var rawPitchOffset: Float = 0
    private var yawSpringVelocity: Float = 0
    private var pitchSpringVelocity: Float = 0
    private(set) var isAppearanceImpulseActive = false
    private var yawVelocity: Float = 0
    var swayScale: Float = 0 {
        didSet {
            if swayScale != 0 && swayPhase == nil {
                swayPhase = SIMD2(Float.random(in: 0 ..< 2 * .pi), Float.random(in: 0 ..< 2 * .pi))
            }
        }
    }
    var tilt: Float = 0
    var targetLean: Float = 0
    private(set) var lean: Float = 0
    private var leanVelocity: Float = 0
    var releaseDecay: Float = 0
    var releaseTilt: Float = 0
    private var swayPhase: SIMD2<Float>?
    private var spinVelocity: Float = 0
    private(set) var spinAtPress: Float = 0
    private var spinDecay: Float = 0.7
    private var lastDragTime: Double = 0
    private var timeSinceRelease: Float = 10
    private var tapRotation: TapRotation?
    private var entranceInterrupted = false

    mutating func tap(direction: Float, speed: Float, mode: DiamondStyle.AnimationMode, time: Float, appearance: DiamondStyle.Appearance = .blue) -> Bool? {
        guard !isDragging else { return nil }
        let tapUnlockSpeed = abs(speed) * Self.tapUnlockSpeedMultiplier
        let triggersBurst: Bool
        if let tapRotation {
            let remainingBoost = max(abs(tapRotation.boost), abs(tapRotation.velocity - speed))
            let fastSpinSpeed = max(abs(tapRotation.velocity), abs(speed + tapRotation.boost))
            if tapRotation.isFast && fastSpinSpeed > tapUnlockSpeed {
                return nil
            }
            triggersBurst = !tapRotation.isFast && remainingBoost > 0.12
        } else {
            if mode == .entrance && !entranceInterrupted && speed != 0 {
                let remainingBoost = DiamondEntrance.spinBoost * exp(-max(0, time) / DiamondEntrance.spinDecay)
                if abs(speed) + remainingBoost > tapUnlockSpeed {
                    return nil
                }
            }
            triggersBurst = false
        }
        let interval: Float = 1 / 120
        let currentVelocity = tapRotation?.velocity
            ?? automaticTravel(from: time, to: time + interval, speed: speed, mode: mode, appearance: appearance) / interval * min(timeSinceRelease / 0.75, 1)
        startRotation(direction: direction, velocity: currentVelocity + yawVelocity, isFast: triggersBurst)
        return triggersBurst
    }

    mutating func spin(_ velocity: Float, decay: Float) {
        spinVelocity += velocity
        spinDecay = max(decay, 0.05)
    }

    mutating func stopSpin() {
        spinVelocity = 0
    }

    mutating func setSpin(_ velocity: Float, decay: Float) {
        guard !isDragging else { return }
        tapRotation = nil
        spinVelocity = velocity
        spinDecay = max(decay, 0.05)
    }

    mutating func pushFromBelow(strength: Float = 1.0) {
        guard !isDragging else { return }
        pitchSpringVelocity -= strength
        isAppearanceImpulseActive = true
    }

    private func sway(at time: Float) -> Float {
        guard swayScale != 0, let phase = swayPhase else { return 0 }
        let frequencies = 2 * Float.pi / SIMD2<Float>(5.3, 8.9)
        return swayScale * (0.17 * sin(frequencies.x * time + phase.x) + 0.10 * sin(frequencies.y * time + phase.y))
    }

    mutating func fling(direction: Float, impulse: Float? = nil) {
        guard !isDragging else { return }
        let currentVelocity = yawSpringVelocity
        targetYaw = yaw
        yawSpringVelocity = 0
        if let impulse {
            tapRotation = nil
            yawVelocity = 0
            spinVelocity = 0
            spin(direction * impulse, decay: 0.7)
        } else {
            startRotation(direction: direction, velocity: currentVelocity, isFast: true)
        }
    }

    private mutating func startRotation(direction: Float, velocity: Float, isFast: Bool) {
        tapRotation = TapRotation(
            velocity: velocity,
            boost: direction * (isFast ? DiamondEntrance.spinBoost : 3.36),
            decayTime: isFast ? DiamondEntrance.spinDecay : 0.85,
            responseTime: isFast ? 0.08 : 0.16,
            isFast: isFast
        )
        entranceInterrupted = true
        yawVelocity = 0
        timeSinceRelease = 0.75
    }

    mutating func begin(at time: Double) {
        spinAtPress = spinVelocity
        isDragging = true
        isAppearanceImpulseActive = false
        tapRotation = nil
        targetYaw = yaw
        targetPitch = pitch
        let offset = min(Self.pitchLimit - 0.001, max(-Self.pitchLimit + 0.001, pitch - Self.referencePitch))
        rawPitchOffset = offset / (1 - abs(offset) / Self.pitchLimit)
        yawSpringVelocity = 0
        pitchSpringVelocity = 0
        yawVelocity = 0
        spinVelocity = 0
        lastDragTime = time
    }

    mutating func drag(dx: Float, dy: Float, scale: Float, at time: Double) {
        guard isDragging else { return }
        let sensitivity = Float.pi / max(scale, 100)
        let deltaYaw = dx * sensitivity
        targetYaw += deltaYaw
        rawPitchOffset += dy * sensitivity
        targetPitch = Self.referencePitch + rawPitchOffset / (1 + abs(rawPitchOffset) / Self.pitchLimit)
        let dt = Float(max(1.0 / 240, min(time - lastDragTime, 0.1)))
        yawVelocity = min(5, max(-5, deltaYaw / dt))
        lastDragTime = time
    }

    mutating func end(at time: Double, cancelled: Bool = false) {
        isDragging = false
        timeSinceRelease = 0
        targetPitch = Self.referencePitch
        if !cancelled {
            pitchSpringVelocity -= releaseTilt
            if releaseDecay > 0 && time - lastDragTime <= 0.12 {
                spinVelocity += yawVelocity
                spinDecay = max(releaseDecay, 0.05)
                yawVelocity = 0
            }
        }
        if cancelled || time - lastDragTime > 0.12 {
            yawVelocity = 0
        }
        if cancelled {
            targetYaw = yaw
            yawSpringVelocity = 0
            pitchSpringVelocity = 0
        }
    }

    mutating func step(dt: Float, speed: Float, reduceMotion: Bool,
                       mode: DiamondStyle.AnimationMode = .continuous, time: Float = 0, appearance: DiamondStyle.Appearance = .blue) {
        let dt = min(max(dt, 0), 0.05)
        if reduceMotion {
            lean = targetLean
            leanVelocity = 0
            isAppearanceImpulseActive = false
            self.rotationSparkle = DiamondSparkleAnimation.RotationPulse()
            tapRotation = nil
            if isDragging {
                yaw = targetYaw
                pitch = targetPitch
            } else {
                targetYaw = yaw
                pitch = Self.referencePitch
                targetPitch = pitch
            }
            yawSpringVelocity = 0
            pitchSpringVelocity = 0
            yawVelocity = 0
            spinVelocity = 0
            return
        }

        // The card's yaw adds a separate, softer spring without changing drag or spin velocity.
        var leanRemaining = dt
        while leanRemaining > 0 && (lean != targetLean || leanVelocity != 0) {
            let step = min(leanRemaining, 1 / Float(240))
            leanVelocity += ((targetLean - lean) * 110 - 2 * 0.55 * 10.5 * leanVelocity) * step
            lean += leanVelocity * step
            leanRemaining = max(0, leanRemaining - step)
        }
        if abs(lean - targetLean) < 0.0001 && abs(leanVelocity) < 0.0001 {
            lean = targetLean
            leanVelocity = 0
        }
        var remaining = dt
        while remaining > 0 {
            let step = min(remaining, 1 / Float(isAppearanceImpulseActive ? 240 : 120))
            let previousYaw = yaw
            let stepTime = max(0, time - remaining + step)
            if !isDragging {
                timeSinceRelease += step
                let decay = exp(-4.2 * step)
                targetYaw += yawVelocity * (1 - decay) / 4.2
                yawVelocity *= decay

                if spinVelocity != 0 {
                    let fade = exp(-step / spinDecay)
                    let travel = spinVelocity * spinDecay * (1 - fade)
                    spinVelocity *= fade
                    if abs(spinVelocity) < 0.002 { spinVelocity = 0 }
                    targetYaw += travel
                    yaw += travel
                }

                let automaticTravel: Float
                if var tapRotation = self.tapRotation {
                    automaticTravel = tapRotation.step(dt: step, speed: speed)
                    self.tapRotation = tapRotation
                } else {
                    automaticTravel = self.automaticTravel(from: max(0, stepTime - step), to: stepTime, speed: speed, mode: mode, appearance: appearance)
                }
                let travel = automaticTravel * min(timeSinceRelease / 0.75, 1)
                targetYaw += travel
                yaw += travel
                targetPitch = Self.referencePitch + sway(at: stepTime) + tilt
            }

            let stiffness = Self.springFrequency * Self.springFrequency
            let damping = 2 * Self.springDamping * Self.springFrequency
            // Match CoreListChatScrollMotion's free oscillation after scrolling stops.
            let pitchFrequency = isAppearanceImpulseActive ? 2 * Float.pi * 1.25 : Self.springFrequency
            let pitchDamping = 2 * (isAppearanceImpulseActive ? 0.13 : Self.springDamping) * pitchFrequency
            yawSpringVelocity += ((targetYaw - yaw) * stiffness - damping * yawSpringVelocity) * step
            pitchSpringVelocity += ((targetPitch - pitch) * pitchFrequency * pitchFrequency - pitchDamping * pitchSpringVelocity) * step
            yaw += yawSpringVelocity * step
            pitch += pitchSpringVelocity * step
            if isAppearanceImpulseActive && abs(pitch - targetPitch) < 0.0001 && abs(pitchSpringVelocity) < 0.0001 {
                pitch = targetPitch
                pitchSpringVelocity = 0
                isAppearanceImpulseActive = false
            }
            if mainSparkleOnRotation {
                rotationSparkle.advance(rotation: yaw - previousYaw, dt: step)
            }
            remaining = max(0, remaining - step)
        }

        let fullTurns = (yaw / (2 * .pi)).rounded(.towardZero)
        yaw -= fullTurns * 2 * .pi
        targetYaw -= fullTurns * 2 * .pi
        if !isDragging && swayScale == 0 && tilt == 0 && abs(pitch - Self.referencePitch) < 0.0001 && abs(pitchSpringVelocity) < 0.0001 {
            pitch = Self.referencePitch
            pitchSpringVelocity = 0
        }
    }

    private func automaticTravel(from start: Float, to end: Float, speed: Float, mode: DiamondStyle.AnimationMode, appearance: DiamondStyle.Appearance) -> Float {
        switch mode {
        case .entrance:
            return entranceInterrupted ? speed * (end - start) : DiamondEntrance.angularTravel(from: start, to: end, speed: speed)
        case .continuous:
            return speed * (end - start)
        case .reference:
            return speed == 0 ? 0 : Self.referenceYaw(time: end, appearance: appearance) - Self.referenceYaw(time: start, appearance: appearance)
        }
    }

    mutating func changeReferenceAppearance(from old: DiamondStyle.Appearance, to new: DiamondStyle.Appearance, time: Float) {
        targetYaw += Self.referenceYaw(time: time, appearance: new) - Self.referenceYaw(time: time, appearance: old)
    }

    static func referenceYaw(time: Float, appearance: DiamondStyle.Appearance = .blue) -> Float {
        let frame = DiamondReferenceHighlights.frame(at: time, appearance: appearance)
        if appearance == .white {
            let progress = frame < 59 ? frame/59 : (120-frame)/61
            return -0.42 * DiamondSparkleAnimation.easing(progress, out: SIMD2(0.5,0), in: SIMD2(0.5,1))
        }
        let times: [Float] = [0, 39, 69, 99, 179]
        let angles: [Float] = [0, -0.34, 0, 0.33, 0]
        let index = frame < 39 ? 0 : (frame < 69 ? 1 : (frame < 99 ? 2 : 3))
        let progress = min(1, (frame - times[index]) / (times[index + 1] - times[index]))
        let out = index == 2 ? SIMD2<Float>(0.167, 0.167) : SIMD2<Float>(0.5, 0)
        let into = index == 1 ? SIMD2<Float>(0.833, 0.833) : SIMD2<Float>(0.5, 1)
        let t = DiamondSparkleAnimation.easing(progress, out: out, in: into)
        return angles[index] + (angles[index + 1] - angles[index]) * t
    }
}

// MARK: - Entrance timing

struct DiamondStarBurst {
    static let lifetime: Float = 6.4
    let startTime: Float
    let seed: UInt32
    var isFromTap: Bool = false
}

enum DiamondEntrance {
    static let spinBoost: Float = 12.6
    static let spinDecay: Float = 0.95 / 1.4
    static let steadyStarCount = 240
    static let burstStarCount = 144

    static func extraAngle(at time: Float) -> Float {
        spinBoost * spinDecay * (1 - exp(-max(0, time) / spinDecay))
    }

    static func angularTravel(from start: Float, to end: Float, speed: Float) -> Float {
        guard speed != 0 else { return 0 }
        return speed * max(0, end-start)
            + (speed > 0 ? 1 : -1) * (extraAngle(at:end)-extraAngle(at:start))
    }

    static func highlightTime(at time: Float, entrance: Bool) -> Float {
        let time = max(0, time)
        return entrance ? time + 4 * spinDecay * (1 - exp(-time / spinDecay)) : time
    }

    static func particleTime(at time: Float, entrance: Bool) -> Float {
        let time = max(0,time)
        return entrance ? time + 2.2 * (1-exp(-time)) : time
    }
}

// MARK: - Facet lighting

enum DiamondLightAnimation {
    private static let facetSweepSpeed: Float = 0.5

    struct State {
        var crown: SIMD4<Float>
        var pavilion: SIMD4<Float>
        var sweep: SIMD4<Float>
        var crownSweep: SIMD4<Float>
        var rightCrownSweep: SIMD4<Float>
        var leftCrownSweep: SIMD4<Float>
        var pavilionSweep: SIMD4<Float>
        var rightPavilionSweep: SIMD4<Float>
        var leftPavilionSweep: SIMD4<Float>
    }

    static func state(time: Float) -> State {
        let frame = max(0, time * 60).truncatingRemainder(dividingBy: 180)
        let sweepFrame = max(0, time * 60 * facetSweepSpeed).truncatingRemainder(dividingBy: 180)
        let times: [Float] = [0, 39, 99, 179]
        let crown: [SIMD4<Float>] = [
            SIMD4(-53.8, 112.9, 50.5, -54.2), SIMD4(12, 53.4, 143.3, -112.9),
            SIMD4(-126.9, 168.8, 190.3, -192.8), SIMD4(-53.8, 112.9, 50.5, -54.2)]
        let pavilion: [SIMD4<Float>] = [
            SIMD4(-53.8, 80.7, 10.8, -165.2), SIMD4(-34.2, 23.1, 104.6, -191),
            SIMD4(-147.9, 125.5, -9.9, -106.1), SIMD4(-53.8, 80.7, 10.8, -165.2)]
        let sweep: [Float] = [-0.05, 0.84, -0.88, -0.05]
        let segment = frame < 39 ? 0 : (frame < 99 ? 1 : 2)
        let progress = min(1, max(0, (frame - times[segment]) / (times[segment+1] - times[segment])))
        let t = easing(progress)
        let transmission: Float
        if frame < 25 { transmission = 0.45 * frame / 25 }
        else if frame < 142 { transmission = 0.45 }
        else { transmission = 0.45 * max(0, (166-frame)/24) }
        return State(crown: simd_mix(crown[segment], crown[segment+1], SIMD4(repeating: t)),
                     pavilion: simd_mix(pavilion[segment], pavilion[segment+1], SIMD4(repeating: t)),
                     sweep: SIMD4(sweep[segment] + (sweep[segment+1] - sweep[segment]) * t,
                                  frame / 180 * 2 * .pi, transmission, 0),
                     crownSweep: facetSweep(sweepFrame, times: [11,49,127,179]),
                     rightCrownSweep: facetSweep(sweepFrame, times: [6,44,88]),
                     leftCrownSweep: facetSweep(sweepFrame, times: [0,38,118,167]),
                     pavilionSweep: facetSweep(sweepFrame, times: [0,38,103,163]),
                     rightPavilionSweep: facetSweep(sweepFrame, times: [5,43,92]),
                     leftPavilionSweep: facetSweep(sweepFrame, times: [0,38,112,168]))
    }

    private static func facetSweep(_ frame: Float, times: [Float]) -> SIMD4<Float> {
        let a = SIMD4<Float>(-115.8,40.3,-279.3,240.6)
        let b = SIMD4<Float>(317,-341.9,188,-131.9)
        for i in 1..<times.count where frame < times[i] {
            let progress = (frame-times[i-1]) / (times[i]-times[i-1])
            let t = DiamondSparkleAnimation.easing(progress, out: SIMD2(0.333,0), in: SIMD2(0.667,1))
            return simd_mix(i % 2 == 1 ? a : b, i % 2 == 1 ? b : a, SIMD4(repeating:t))
        }
        return times.count % 2 == 0 ? b : a
    }

    private static func easing(_ x: Float) -> Float {
        if x == 0 || x == 1 { return x }
        var low: Float = 0, high: Float = 1
        for _ in 0..<16 {
            let t = (low + high) * 0.5, s = 1 - t
            let bx = 1.5*s*s*t + 1.5*s*t*t + t*t*t
            if bx < x { low = t } else { high = t }
        }
        let t = (low + high) * 0.5
        return t*t*(3 - 2*t)
    }
}

// MARK: - Authored Lottie highlights

enum DiamondReferenceHighlights {
    // Hold the last authored frame instead of wrapping back to the start.
    static let lastFrameTime: Float = 179.0 / 60.0

    struct Event {
        let frame: Float
        let position: SIMD2<Float>
        var peakScale: Float = 0.632
        var riseY: Float = 0.167
        var decayY: Float = 0.72

        func scale(at time: Float, appearance: DiamondStyle.Appearance = .blue) -> Float {
            let age = DiamondReferenceHighlights.frame(at: time, appearance: appearance) - frame
            guard age > 0, age < 14 else { return 0 }
            let envelope = age < 2
                ? DiamondSparkleAnimation.easing(age / 2, out: SIMD2(0.167, riseY), in: SIMD2(0.5, 1))
                : 1 - DiamondSparkleAnimation.easing((age - 2) / 12, out: SIMD2(0.347, 0), in: SIMD2(0.823, decayY))
            return (peakScale / 0.75) * envelope
        }
    }

    struct Streak {
        var center: SIMD2<Float>
        var axisX: SIMD2<Float>
        var axisY: SIMD2<Float>
        var opacity: Float
    }

    static func frame(at time: Float, appearance: DiamondStyle.Appearance = .blue) -> Float {
        let frame = max(0, time * 60).truncatingRemainder(dividingBy: 180)
        return appearance == .white ? frame * 121 / 180 : frame
    }

    static func events(for appearance: DiamondStyle.Appearance) -> [Event] {
        appearance == .white ? whiteEvents : events
    }

    struct Key {
        let frame: Float
        let value: Float
        var out: SIMD2<Float> = SIMD2(0.333, 0)
        var into: SIMD2<Float> = SIMD2(0.667, 1)
    }

    static func sample(_ keys: [Key], frame: Float) -> Float {
        guard frame > keys[0].frame else { return keys[0].value }
        for i in 1..<keys.count where frame < keys[i].frame {
            let a = keys[i-1], b = keys[i]
            let t = DiamondSparkleAnimation.easing((frame-a.frame)/(b.frame-a.frame), out: a.out, in: a.into)
            return a.value + (b.value-a.value)*t
        }
        return keys.last!.value
    }

    struct FacetFlash {
        let region: Int // front pavilion, right pavilion, left pavilion, crown, right crown, left crown
        let opacity: [Key]
    }

    static func facetFlashes(at time: Float) -> (crown: SIMD4<Float>, pavilion: SIMD4<Float>) {
        let frame = frame(at: time, appearance: .white)
        var crown = SIMD4<Float>.zero, pavilion = SIMD4<Float>.zero
        for flash in whiteFacetFlashes {
            let alpha = sample(flash.opacity, frame: frame) * 0.55
            let component = flash.region % 3
            if flash.region < 3 { pavilion[component] = 1-(1-pavilion[component])*(1-alpha) }
            else { crown[component] = 1-(1-crown[component])*(1-alpha) }
        }
        return (crown, pavilion)
    }

    static let whiteMainScale: [Key] = [
        Key(frame: 0, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.833, 0.833)),
        Key(frame: 22.123, value: 0, out: SIMD2(0.167, 0), into: SIMD2(0.833, 1)),
        Key(frame: 83, value: 0, out: SIMD2(0.41, 0), into: SIMD2(0.12, 1)),
        Key(frame: 120, value: 1)
    ]
    static let whiteMorph: [Key] = [
        Key(frame: 0, value: 0, out: SIMD2(0.167, 0.167), into: SIMD2(0.833, 0.833)),
        Key(frame: 12, value: 1, out: SIMD2(0.167, 0.167), into: SIMD2(0.833, 0.833)),
        Key(frame: 102, value: 1, out: SIMD2(0.167, 0.167), into: SIMD2(0.4, 1)),
        Key(frame: 120, value: 0)
    ]
    static let whiteCoreScale: [Key] = [
        Key(frame: 0, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 12.066, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 23.463, value: 0.8, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 33.52, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 43.576, value: 0.8, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 60.336, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 70.391, value: 0.8, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 80.447, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 90.502, value: 0.8, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 114.637, value: 1)
    ]
    static let whiteHaloScale: [Key] = [
        Key(frame: 5.363, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 17.43, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 28.826, value: 0.8, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 38.883, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 48.939, value: 0.8, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 65.699, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 75.754, value: 0.8, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 85.811, value: 1, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 95.865, value: 0.8, out: SIMD2(0.333, 0), into: SIMD2(0.667, 1)),
        Key(frame: 120, value: 1)
    ]
    static let whiteStreakOpacity: [Key] = [
        Key(frame: 12.066, value: 0, out: SIMD2(0.167, 0.167), into: SIMD2(0.833, 0.833)),
        Key(frame: 20.781, value: 1, out: SIMD2(0.167, 0.167), into: SIMD2(0.833, 0.833)),
        Key(frame: 70.391, value: 1, out: SIMD2(0.167, 0.167), into: SIMD2(0.833, 0.833)),
        Key(frame: 86, value: 0)
    ]
    static let whiteStreakScale: [Key] = [
        Key(frame: 12, value: 0, out: SIMD2(0.167, 0.167), into: SIMD2(0.833, 0.833)),
        Key(frame: 26, value: 0.75, out: SIMD2(0.167, 0.167), into: SIMD2(0.833, 0.833)),
        Key(frame: 65, value: 0.75, out: SIMD2(0.167, 0.167), into: SIMD2(0.833, 0.833)),
        Key(frame: 85.5645, value: 0)
    ]
    static let whiteEvents: [Event] = [
        Event(frame: 33, position: SIMD2(219.694, 280.654), peakScale: 0.63197, riseY: 0.167, decayY: 0.72),
        Event(frame: 52, position: SIMD2(332.694, 196.654), peakScale: 0.75, riseY: 0.141, decayY: 0.764),
        Event(frame: 70, position: SIMD2(358.694, 279.654), peakScale: 0.55, riseY: 0.192, decayY: 0.678)
    ]
    static let whiteFacetFlashes: [FacetFlash] = [
        FacetFlash(region: 0, opacity: [
        Key(frame: 38, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 44, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 51, value: 0)
    ]),
        FacetFlash(region: 1, opacity: [
        Key(frame: 20, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 26, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 33, value: 0)
    ]),
        FacetFlash(region: 2, opacity: [
        Key(frame: 39, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 45, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 52, value: 0)
    ]),
        FacetFlash(region: 4, opacity: [
        Key(frame: 55, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 61, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 68, value: 0)
    ]),
        FacetFlash(region: 5, opacity: [
        Key(frame: 33, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 39, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 46, value: 0)
    ]),
        FacetFlash(region: 0, opacity: [
        Key(frame: 31, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 37, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 44, value: 0)
    ]),
        FacetFlash(region: 1, opacity: [
        Key(frame: 47, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 53, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 60, value: 0)
    ]),
        FacetFlash(region: 2, opacity: [
        Key(frame: 18, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 24, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 31, value: 0)
    ]),
        FacetFlash(region: 4, opacity: [
        Key(frame: 82, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 88, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 95, value: 0)
    ]),
        FacetFlash(region: 5, opacity: [
        Key(frame: 60, value: 0, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 66, value: 0.77, out: SIMD2(1, 0), into: SIMD2(0, 1)),
        Key(frame: 73, value: 0)
    ])
    ]
    
    static func streaks(at time: Float, appearance: DiamondStyle.Appearance = .blue) -> [Streak] {
        let frame = frame(at: time, appearance: appearance)

        func make(innerPosition: SIMD2<Float>, innerScale: SIMD2<Float>, innerAngle: Float,
                  outerPosition: SIMD2<Float>, outerAngle: Float, layerPosition: SIMD2<Float>,
                  layerAnchor: SIMD2<Float>, opacity: Float = 0.4, layerScale: Float = 0.75) -> Streak {
            func rotate(_ p: SIMD2<Float>, _ degrees: Float) -> SIMD2<Float> {
                let r = degrees * .pi / 180
                return SIMD2(cos(r)*p.x - sin(r)*p.y, sin(r)*p.x + cos(r)*p.y)
            }
            let gradientCenter = SIMD2<Float>(-3.2, -84.1)
            let center = rotate(innerPosition + rotate(gradientCenter * innerScale, innerAngle), outerAngle)
            return Streak(center: layerPosition + layerScale * (outerPosition + center - layerAnchor),
                          axisX: rotate(SIMD2(innerScale.x, 0), innerAngle + outerAngle) * layerScale,
                          axisY: rotate(SIMD2(0, innerScale.y), innerAngle + outerAngle) * layerScale,
                          opacity: opacity)
        }
        if appearance == .white {
            let sway = DiamondSparkleAnimation.easing(frame < 59 ? frame/59 : (120-frame)/61,
                out: SIMD2(0.5, 0), in: SIMD2(0.5, 1))
            let top = make(innerPosition: SIMD2(-30.026, 1.203), innerScale: SIMD2(0.07139, 0.418), innerAngle: 90,
                outerPosition: SIMD2(287.292, 106.248), outerAngle: 0,
                layerPosition: SIMD2(238.031, 256.411), layerAnchor: SIMD2(238.031, 256.411))
            let left = make(innerPosition: SIMD2(-30.026, 1.203) + SIMD2(14.441, 34.194)*sway,
                innerScale: SIMD2(0.07139, 0.768), innerAngle: 90-8.804*sway,
                outerPosition: SIMD2(158.649, 298.438), outerAngle: 60.525,
                layerPosition: SIMD2(238.031, 256.411), layerAnchor: SIMD2(238.031, 256.411))
            let sweep = make(innerPosition: SIMD2(-30.026, 1.203), innerScale: SIMD2(0.07139, 0.418), innerAngle: 90,
                outerPosition: SIMD2(297.292, 106.248), outerAngle: 0,
                layerPosition: SIMD2(311.829-166*min(1,max(0,(frame-12.066)/73.934)), 244.564),
                layerAnchor: SIMD2(303.096, 107.282),
                opacity: 0.4*sample(whiteStreakOpacity, frame: frame),
                layerScale: sample(whiteStreakScale, frame: frame))
            return [top, left, sweep]
        }
        let times: [Float] = [0, 39, 69, 99, 179]
        let positions: [SIMD2<Float>] = [SIMD2(-30, 1.2), SIMD2(-31.3, 24.4),
            SIMD2(-30, 1.2), SIMD2(4, -39.6), SIMD2(-30, 1.2)]
        let angles: [Float] = [90, 82.9, 82.9, 100.6, 90]
        let segment = frame < 39 ? 0 : (frame < 69 ? 1 : (frame < 99 ? 2 : 3))
        let progress = (frame - times[segment]) / (times[segment+1] - times[segment])
        let out = segment == 2 ? SIMD2<Float>(0.167, 0.167) : SIMD2<Float>(0.5, 0)
        let into = segment == 1 ? SIMD2<Float>(0.833, 0.833) : SIMD2<Float>(0.5, 1)
        let t = DiamondSparkleAnimation.easing(progress, out: out, in: into)
        let position = simd_mix(positions[segment], positions[segment+1], SIMD2(repeating: t))
        let rotationT = DiamondSparkleAnimation.easing(progress, out: out,
            in: segment == 1 ? SIMD2(0.833, 1) : into)
        let angle = angles[segment] + (angles[segment+1] - angles[segment]) * rotationT

        let top = make(innerPosition: SIMD2(-30, 1.2), innerScale: SIMD2(0.071, 0.418), innerAngle: 90,
                       outerPosition: SIMD2(297.3, 106.2), outerAngle: 0,
                       layerPosition: SIMD2(238, 256.4), layerAnchor: SIMD2(238, 256.4))
        let left = make(innerPosition: position, innerScale: SIMD2(0.071, 0.768), innerAngle: angle,
                        outerPosition: SIMD2(158.6, 298.4), outerAngle: 60.5,
                        layerPosition: SIMD2(238, 256.4), layerAnchor: SIMD2(238, 256.4))
        let opacity = min(1, max(0, (frame-18)/12)) * min(1, max(0, (117-frame)/13))
        let sweep = make(innerPosition: SIMD2(-30, 1.2), innerScale: SIMD2(0.071, 0.418), innerAngle: 90,
                         outerPosition: SIMD2(297.3, 106.2), outerAngle: 0,
                         layerPosition: SIMD2(181.8 + 160 * min(1, max(0, (frame-18)/99)), 244.6),
                         layerAnchor: SIMD2(303.1, 107.3), opacity: opacity * 0.4)
        return [top, left, sweep]
    }

    static let events: [Event] = [
        Event(frame: 7, position: SIMD2(242.7, 357.7)),
        Event(frame: 15, position: SIMD2(166.7, 233.7)),
        Event(frame: 21, position: SIMD2(322.7, 173.7)),
        Event(frame: 27, position: SIMD2(392.7, 228.7)),
        Event(frame: 33, position: SIMD2(144.7, 238.7)),
        Event(frame: 41, position: SIMD2(209.7, 364.7)),
        Event(frame: 47, position: SIMD2(365.7, 249.7)),
        Event(frame: 52, position: SIMD2(338.7, 152.7)),
        Event(frame: 58, position: SIMD2(198.7, 246.7)),
        Event(frame: 64, position: SIMD2(123.7, 210.7)),
        Event(frame: 70, position: SIMD2(303.7, 336.7)),
        Event(frame: 77, position: SIMD2(385.7, 211.7)),
        Event(frame: 83, position: SIMD2(153.7, 253.7)),
        Event(frame: 91, position: SIMD2(139.7, 305.7)),
        Event(frame: 97, position: SIMD2(309.7, 313.7)),
        Event(frame: 105, position: SIMD2(379.7, 211.7)),
        Event(frame: 111, position: SIMD2(224.7, 204.7)),
        Event(frame: 119, position: SIMD2(158.7, 277.7)),
        Event(frame: 126, position: SIMD2(323.7, 302.7))
    ]
}

// MARK: - Surface sparkles

enum DiamondSparkleAnimation {
    struct State {
        var shape: SIMD4<Float>
        var haloScale: Float
    }

    struct RotationPulse {
        private static let rotationInterval: Float = .pi
        private static let probability: Float = 0.6
        private static let highSpeedThreshold: Float = 2 * .pi
        private static let highSpeedProbability: Float = 0.05
        private static let rise: Float = 0.08
        private static let duration: Float = rise + 33.0 / 60.0
        private var rotation: Float = 0
        private var age: Float = 0
        private var from = State(shape: .zero, haloScale: 1)

        var state: State {
            guard self.age < Self.duration else { return State(shape: .zero, haloScale: 1) }
            if self.age < Self.rise {
                let t = DiamondSparkleAnimation.smoothstep(self.age / Self.rise)
                let peak = DiamondSparkleAnimation.state(time: 0)
                return State(shape: simd_mix(self.from.shape, peak.shape, SIMD4(repeating: t)),
                    haloScale: self.from.haloScale + (peak.haloScale - self.from.haloScale) * t)
            }
            return DiamondSparkleAnimation.state(time: min(33.0 / 60.0, self.age - Self.rise))
        }

        mutating func advance(rotation: Float, dt: Float) {
            self.age = min(Self.duration, self.age + dt)
            self.rotation += abs(rotation)
            let speed = dt > 0 ? abs(rotation) / dt : 0
            let probability = speed >= Self.highSpeedThreshold ? Self.highSpeedProbability : Self.probability
            while self.rotation >= Self.rotationInterval {
                self.rotation -= Self.rotationInterval
                if Float.random(in: 0 ..< 1) < probability, self.age >= Self.rise {
                    self.from = self.state
                    self.age = 0
                }
            }
        }
    }

    static func state(time: Float, appearance: DiamondStyle.Appearance = .blue) -> State {
        let frame = DiamondReferenceHighlights.frame(at: time, appearance: appearance)
        if appearance == .white {
            return State(shape: SIMD4(
                DiamondReferenceHighlights.sample(DiamondReferenceHighlights.whiteMainScale, frame: frame),
                DiamondReferenceHighlights.sample(DiamondReferenceHighlights.whiteMorph, frame: frame),
                DiamondReferenceHighlights.sample(DiamondReferenceHighlights.whiteCoreScale, frame: frame), 1),
                haloScale: DiamondReferenceHighlights.sample(DiamondReferenceHighlights.whiteHaloScale, frame: frame))
        }
        let scale: Float
        if frame < 33 {
            scale = 1 - easing(frame / 33, out: SIMD2(0.333, 0), in: SIMD2(0.833, 0.833))
        } else if frame < 129 {
            scale = 0
        } else {
            scale = easing((frame - 129) / 50, out: SIMD2(0.167, 0.167), in: SIMD2(0.4, 1))
        }
        let morph: Float
        if frame < 18 {
            morph = easing(frame / 18, out: SIMD2(0.167, 0.167), in: SIMD2(0.667, 1))
        } else if frame < 151 {
            morph = 1
        } else {
            morph = 1 - easing((frame - 151) / 28, out: SIMD2(0.167, 0.167), in: SIMD2(0.4, 1))
        }
        return State(shape: SIMD4(scale, morph, groupScale(frame: frame), groupScale(frame: frame - 4)),
                     haloScale: groupScale(frame: frame - 8))
    }

    struct MainPlacement {
        var faceRotation: Float
        var visibility: Float
    }

    static func mainPlacement(model: simd_float4x4, angularSpeed: Float = 0, rotationTriggered: Bool = false) -> MainPlacement {
        let pitch = DiamondMotion.referencePitch
        let referenceFront = SIMD4<Float>(0, -sin(pitch), cos(pitch), 0)
        var bestFacing: Float = -1
        var faceAngle: Float = 0
        for face in 0..<4 {
            let angle = Float(face) * .pi / 2
            let forward = model * SIMD4<Float>(sin(angle), 0, cos(angle), 0)
            let facing = simd_dot(forward, referenceFront)
            if facing > bestFacing { bestFacing = facing; faceAngle = angle }
        }
        if rotationTriggered {
            return MainPlacement(faceRotation: faceAngle, visibility: 1)
        }
        let limit = Float.pi * 12 / 180
        let angle = acos(min(1, max(-1, bestFacing)))
        let facing = smoothstep(1 - angle / limit)
        let crossingDuration = 2 * limit / max(abs(angularSpeed), 0.001)
        let duration = smoothstep((crossingDuration - 0.06) / 0.34)
        return MainPlacement(faceRotation: faceAngle, visibility: facing * duration)
    }

    private static func smoothstep(_ value: Float) -> Float {
        let t = min(1, max(0, value))
        return t * t * (3 - 2 * t)
    }

    private static func groupScale(frame: Float) -> Float {
        let times: [Float] = [0, 18, 35, 50, 65, 90, 105, 120, 135, 171]
        let values: [Float] = [1, 1, 0.8, 1, 0.8, 1, 0.8, 1, 0.8, 1]
        for i in 1..<times.count where frame < times[i] {
            let t = easing((frame - times[i-1]) / (times[i] - times[i-1]),
                           out: SIMD2(0.333, 0), in: SIMD2(0.667, 1))
            return values[i-1] + (values[i] - values[i-1]) * t
        }
        return 1
    }

    static func easing(_ progress: Float, out a: SIMD2<Float>, in b: SIMD2<Float>) -> Float {
        let x = min(1, max(0, progress))
        if x == 0 || x == 1 { return x }
        var low: Float = 0, high: Float = 1
        for _ in 0..<18 {
            let t = (low + high) * 0.5, s = 1 - t
            let bx = 3*s*s*t*a.x + 3*s*t*t*b.x + t*t*t
            if bx < x { low = t } else { high = t }
        }
        let t = (low + high) * 0.5, s = 1 - t
        return 3*s*s*t*a.y + 3*s*t*t*b.y + t*t*t
    }
}
