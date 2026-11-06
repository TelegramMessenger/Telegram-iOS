import Foundation
import UIKit
import AsyncDisplayKit
import Display
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import LottieSettings

/// An item-relative, one-shot decoration. The owner supplies its frame and
/// viewport mask and removes it on completion or when the chat loses focus.
final class AllMentionSendEffectNode: ASDisplayNode {
    private struct HonkBeat {
        let start: Double
        let compression: Double
        let snap: Double
        let strength: CGFloat
        let recoil: CGFloat
        let lifetimeScale: Double

        var release: Double { self.start + self.compression + self.snap }
        var openX: CGFloat { 1.0 + 0.20 * self.strength }
        var openY: CGFloat { 1.0 + 0.10 * self.strength }
    }

    private struct ParticleSpec {
        let fontSize: CGFloat
        let delay: Double
        let duration: Double
        let tilt: CGFloat
        let spin: CGFloat
    }

    private static let bellPivot = CGPoint(x: 230.0 / 512.0, y: 256.0 / 512.0)
    private static let mouthPoint = CGPoint(x: 145.0 / 512.0, y: 225.0 / 512.0)
    private static let beats: [HonkBeat] = (0 ..< 11).map { index in
        let strengths: [CGFloat] = [1.0, 0.82, 0.94, 0.78, 0.98, 0.84, 1.0, 0.80, 0.95, 0.86, 1.0]
        return HonkBeat(start: 0.47 + Double(index) * 0.09, compression: 0.012, snap: 0.008, strength: strengths[index], recoil: 6.0 + strengths[index] * 6.0, lifetimeScale: index % 3 == 0 ? 1.02 : 0.96)
    }
    private static let particleSpecs: [ParticleSpec] = [
        ParticleSpec(fontSize: 32.0, delay: 0.0, duration: 1.42, tilt: -0.18, spin: -1.1),
        ParticleSpec(fontSize: 18.0, delay: 0.021, duration: 1.56, tilt: 0.16, spin: 2.0)
    ]
    private static let particleFlightSpeed: Double = 2.2

    private let travelRig = ASDisplayNode()
    private let carrier = ASDisplayNode()
    private let bellRig = ASDisplayNode()
    private let bell: AnimatedStickerNode
    private let grip: AnimatedStickerNode
    private var flowRibbons: [CAShapeLayer] = []
    private var splashes: [CAShapeLayer] = []
    private var debris: [CALayer] = []
    private var mentionParticles: [CATextLayer] = []
    private var attentionMarks: [CATextLayer] = []
    private var glints: [CAShapeLayer] = []
    private var layoutSize: CGSize?
    private var iconSide: CGFloat = 114.0
    private var travelDistance: CGFloat = 0.0
    private var hasRequestedPlay = false
    private var hasStarted = false
    private var hasFinished = false
    private var usesReducedMotion = false
    private let reduceMotion: Bool
    private var completions: [() -> Void] = []
    private var exitWorkItem: DispatchWorkItem?
    private var finishWorkItem: DispatchWorkItem?
    private var reduceMotionObserver: NSObjectProtocol?

    init(reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        self.bell = DefaultAnimatedStickerNodeImpl(lottieSettings: .noAccountFallback)
        self.grip = DefaultAnimatedStickerNodeImpl(lottieSettings: .noAccountFallback)
        super.init()

        self.isUserInteractionEnabled = false
        self.isAccessibilityElement = false
        self.accessibilityElementsHidden = true
        self.clipsToBounds = true
        // The air has a visible, shared course. Put it behind the horn and
        // released objects so the glyphs read as travelling inside the flow.
        for index in 0 ..< 3 {
            let ribbon = CAShapeLayer()
            ribbon.fillColor = (index == 0 ? UIColor(red: 0.0, green: 0.67, blue: 1.0, alpha: 0.22) : (index == 1 ? UIColor.white.withAlphaComponent(0.48) : UIColor(red: 0.0, green: 0.58, blue: 1.0, alpha: 0.23))).cgColor
            ribbon.strokeColor = index == 0 ? UIColor(red: 0.0, green: 0.65, blue: 0.98, alpha: 0.38).cgColor : nil
            ribbon.lineWidth = 0.8
            ribbon.lineJoin = .round
            ribbon.opacity = 0.0
            self.layer.addSublayer(ribbon)
            self.flowRibbons.append(ribbon)
        }
        self.addSubnode(self.travelRig)
        self.travelRig.isUserInteractionEnabled = false
        self.travelRig.addSubnode(self.carrier)
        self.carrier.isUserInteractionEnabled = false
        self.carrier.alpha = 0.0
        // The rigid cone/handle sits behind the independently deforming front.
        self.carrier.addSubnode(self.grip)
        self.carrier.addSubnode(self.bellRig)
        self.bellRig.addSubnode(self.bell)
        self.bellRig.isUserInteractionEnabled = false
        self.bellRig.layer.anchorPoint = Self.bellPivot
        self.configure(sticker: self.grip, sourceName: "AllMentionMegaphoneGrip")
        self.configure(sticker: self.bell, sourceName: "AllMentionMegaphoneBell")

        // Short pressure puffs sit behind the glyph stream. Their staggered
        // 150–170ms lives permit only two puffs to overlap at a time.
        for index in Self.beats.indices {
            let size: CGFloat = index % 3 == 0 ? 31.0 : (index % 2 == 0 ? 22.0 : 18.0)
            let splash = CAShapeLayer()
            splash.bounds = CGRect(x: -size * 0.5 - 2.0, y: -size * 0.5 - 2.0, width: size + 4.0, height: size + 4.0)
            splash.path = Self.splashPath(size: size)
            splash.fillColor = UIColor.white.withAlphaComponent(0.96).cgColor
            splash.strokeColor = UIColor(red: 0.05, green: 0.69, blue: 0.97, alpha: 0.80).cgColor
            splash.lineWidth = 0.9
            splash.opacity = 0.0
            self.layer.addSublayer(splash)
            self.splashes.append(splash)
        }
        for index in 0 ..< Self.beats.count * 3 {
            let slot = index % 3
            let piece = CALayer()
            let size = slot == 0 ? CGSize(width: 7.0, height: 2.5) : (slot == 1 ? CGSize(width: 3.5, height: 3.5) : CGSize(width: 10.0, height: 2.0))
            piece.bounds = CGRect(origin: .zero, size: size)
            piece.cornerRadius = slot == 1 ? 1.75 : 1.0
            piece.backgroundColor = Self.particleColor(slot: slot == 1 ? 1 : 0, burst: index / 3).cgColor
            piece.allowsEdgeAntialiasing = true
            piece.opacity = 0.0
            self.layer.addSublayer(piece)
            self.debris.append(piece)
        }
        // Each released glyph belongs to the overlay, never the recoiling rig.
        for index in 0 ..< Self.particleSpecs.count * Self.beats.count {
            let slot = index % Self.particleSpecs.count
            let size = Self.glyphSize(slot: slot, burst: index / Self.particleSpecs.count)
            let baseFont = UIFont.systemFont(ofSize: size, weight: .bold)
            let font: UIFont
            if #available(iOS 13.0, *), let descriptor = baseFont.fontDescriptor.withDesign(.rounded) {
                font = UIFont(descriptor: descriptor, size: size)
            } else {
                font = baseFont
            }
            let glyph = NSAttributedString(string: "@", attributes: [
                .font: font,
                .foregroundColor: Self.particleColor(slot: slot, burst: index / Self.particleSpecs.count),
                .strokeColor: UIColor.white.withAlphaComponent(0.94),
                .strokeWidth: -3.0
            ])
            let particle = CATextLayer()
            particle.string = glyph
            particle.alignmentMode = .center
            particle.contentsScale = self.view.contentScaleFactor
            particle.bounds = CGRect(origin: .zero, size: CGSize(width: ceil(glyph.size().width) + 8.0, height: ceil(font.lineHeight) + 6.0))
            particle.allowsEdgeAntialiasing = true
            particle.opacity = 0.0
            self.layer.addSublayer(particle)
            self.mentionParticles.append(particle)
        }
        for index in 0 ..< 3 {
            let size: CGFloat = index == 1 ? 23.0 : 28.0
            let base = UIFont.systemFont(ofSize: size, weight: .heavy)
            let font: UIFont
            if #available(iOS 13.0, *), let descriptor = base.fontDescriptor.withDesign(.rounded) {
                font = UIFont(descriptor: descriptor, size: size)
            } else { font = base }
            let color = index == 1 ? UIColor(red: 0.98, green: 0.29, blue: 0.25, alpha: 1.0) : UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
            let mark = CATextLayer()
            mark.string = NSAttributedString(string: "!", attributes: [.font: font, .foregroundColor: color, .strokeColor: UIColor.white, .strokeWidth: -4.0])
            mark.alignmentMode = .center
            mark.contentsScale = self.view.contentScaleFactor
            mark.bounds = CGRect(origin: .zero, size: CGSize(width: 25.0, height: ceil(font.lineHeight) + 6.0))
            mark.allowsEdgeAntialiasing = true
            mark.opacity = 0.0
            self.layer.addSublayer(mark)
            self.attentionMarks.append(mark)
        }
        for index in 0 ..< 5 {
            let radius: CGFloat = index % 2 == 0 ? 7.5 : 5.0
            let star = CAShapeLayer()
            star.bounds = CGRect(x: -radius - 1.0, y: -radius - 1.0, width: radius * 2.0 + 2.0, height: radius * 2.0 + 2.0)
            let path = UIBezierPath()
            path.move(to: CGPoint(x: 0.0, y: -radius))
            for point in [CGPoint(x: radius * 0.22, y: -radius * 0.22), CGPoint(x: radius, y: 0.0), CGPoint(x: radius * 0.22, y: radius * 0.22), CGPoint(x: 0.0, y: radius), CGPoint(x: -radius * 0.22, y: radius * 0.22), CGPoint(x: -radius, y: 0.0), CGPoint(x: -radius * 0.22, y: -radius * 0.22)] { path.addLine(to: point) }
            path.close()
            star.path = path.cgPath
            star.fillColor = (index == 3 ? UIColor(red: 0.16, green: 0.75, blue: 1.0, alpha: 1.0) : UIColor(red: 1.0, green: 0.76, blue: 0.18, alpha: 1.0)).cgColor
            star.strokeColor = UIColor.white.cgColor
            star.lineWidth = 0.7
            star.opacity = 0.0
            self.layer.addSublayer(star)
            self.glints.append(star)
        }
        self.reduceMotionObserver = NotificationCenter.default.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main, using: { [weak self] _ in
            self?.updateReduceMotion(UIAccessibility.isReduceMotionEnabled)
        })
    }

    func updateReduceMotion(_ enabled: Bool) {
        guard enabled, self.hasStarted, !self.hasFinished, !self.usesReducedMotion else { return }
        self.usesReducedMotion = true
        self.cancelScheduledWork()
        let travelPosition = self.travelRig.layer.presentation()?.position ?? self.travelRig.position
        let travelTransform = self.travelRig.layer.presentation()?.transform ?? self.travelRig.layer.transform
        let position = self.carrier.layer.presentation()?.position ?? self.carrier.position
        let transform = self.carrier.layer.presentation()?.transform ?? self.carrier.layer.transform
        let bellTransform = self.bellRig.layer.presentation()?.transform ?? self.bellRig.layer.transform
        let alpha = CGFloat(self.carrier.layer.presentation()?.opacity ?? Float(self.carrier.alpha))
        self.travelRig.layer.removeAllAnimations()
        self.travelRig.position = travelPosition
        self.travelRig.layer.transform = travelTransform
        self.carrier.layer.removeAllAnimations()
        self.bellRig.layer.removeAllAnimations()
        self.carrier.position = position
        self.carrier.layer.transform = transform
        self.bellRig.layer.transform = bellTransform
        self.hideSecondaryLayers()
        self.carrier.alpha = 0.0
        self.carrier.layer.animateAlpha(from: alpha, to: 0.0, duration: 0.18)
        self.scheduleFinish(after: 0.18)
    }

    func cancel() {
        self.finish()
    }

    deinit {
        self.exitWorkItem?.cancel()
        self.finishWorkItem?.cancel()
        if let observer = self.reduceMotionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        self.travelRig.layer.removeAllAnimations()
        self.carrier.layer.removeAllAnimations()
        self.bellRig.layer.removeAllAnimations()
        for layer in self.flowRibbons { layer.removeAllAnimations() }
        for layer in self.splashes { layer.removeAllAnimations() }
        for layer in self.debris { layer.removeAllAnimations() }
        for layer in self.mentionParticles { layer.removeAllAnimations() }
        for layer in self.attentionMarks { layer.removeAllAnimations() }
        for layer in self.glints { layer.removeAllAnimations() }
        for sticker in [self.grip, self.bell] {
            sticker.visibility = false
            sticker.stop()
            sticker.reset()
        }
    }

    private func configure(sticker: AnimatedStickerNode, sourceName: String) {
        sticker.isUserInteractionEnabled = false
        sticker.automaticallyLoadFirstFrame = true
        sticker.visibility = false
        sticker.setup(source: AnimatedStickerNodeLocalFileSource(name: sourceName), width: 512, height: 512, playbackMode: .still(.start), mode: .direct(cachePathPrefix: nil))
    }

    private static func glyphSize(slot: Int, burst: Int) -> CGFloat {
        let large: [CGFloat] = [34.0, 26.0, 30.0, 24.0, 32.0, 28.0, 34.0, 25.0, 31.0, 27.0, 33.0]
        let small: [CGFloat] = [18.0, 14.0, 17.0, 15.0, 20.0, 16.0, 18.0, 14.0, 19.0, 16.0, 20.0]
        return slot == 0 ? large[burst] : small[burst]
    }

    private static func particleColor(slot: Int, burst: Int) -> UIColor {
        if slot == 1 && burst % 4 == 0 {
            return UIColor(red: 1.0, green: 0.68, blue: 0.12, alpha: 1.0)
        } else if slot == 1 && burst % 4 == 2 {
            return UIColor(red: 0.58, green: 0.35, blue: 0.98, alpha: 1.0)
        } else if slot == 1 || burst % 3 == 1 {
            return UIColor(red: 0.0, green: 0.69, blue: 0.91, alpha: 1.0)
        } else {
            return UIColor(red: 0.0, green: 0.48, blue: 1.0, alpha: 1.0)
        }
    }

    private static func splashPath(size: CGFloat) -> CGPath {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0.21, y: 0.36))
        path.addCurve(to: CGPoint(x: 0.51, y: 0.21), controlPoint1: CGPoint(x: 0.07, y: 0.16), controlPoint2: CGPoint(x: 0.44, y: -0.01))
        path.addCurve(to: CGPoint(x: 0.79, y: 0.46), controlPoint1: CGPoint(x: 0.74, y: -0.02), controlPoint2: CGPoint(x: 1.04, y: 0.32))
        path.addCurve(to: CGPoint(x: 0.53, y: 0.77), controlPoint1: CGPoint(x: 1.05, y: 0.63), controlPoint2: CGPoint(x: 0.75, y: 1.0))
        path.addCurve(to: CGPoint(x: 0.21, y: 0.36), controlPoint1: CGPoint(x: 0.28, y: 1.03), controlPoint2: CGPoint(x: -0.10, y: 0.72))
        path.close()
        path.apply(CGAffineTransform(a: size, b: 0.0, c: 0.0, d: size, tx: -size * 0.5, ty: -size * 0.5))
        return path.cgPath
    }

    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        guard !self.hasFinished, size.width > 0.0, size.height > 0.0, size.width.isFinite, size.height.isFinite else { return }
        if self.hasStarted, let previousSize = self.layoutSize, previousSize != size {
            // Item-space trajectories cannot be reused after the canvas changes.
            self.finish()
            return
        }
        self.layoutSize = size
        for ribbon in self.flowRibbons { ribbon.frame = CGRect(origin: .zero, size: size) }
        let side: CGFloat = 114.0
        self.iconSide = side
        self.travelDistance = size.height * 0.5 + side * 0.5 + 16.0
        transition.updateBounds(node: self.travelRig, bounds: CGRect(origin: .zero, size: CGSize(width: side, height: side)), beginWithCurrentState: true)
        transition.updatePosition(node: self.travelRig, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5), beginWithCurrentState: true)
        self.carrier.bounds = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        self.carrier.position = CGPoint(x: side * 0.5, y: side * 0.5)
        self.bellRig.bounds = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        self.bellRig.position = CGPoint(x: Self.bellPivot.x * side, y: Self.bellPivot.y * side)
        for sticker in [self.grip, self.bell] {
            sticker.frame = CGRect(origin: .zero, size: CGSize(width: side, height: side))
            sticker.updateLayout(size: CGSize(width: side, height: side))
        }
        for particle in self.mentionParticles { particle.contentsScale = self.view.contentScaleFactor }
        for mark in self.attentionMarks { mark.contentsScale = self.view.contentScaleFactor }
        if self.hasRequestedPlay && !self.hasStarted { self.start() }
    }

    func play(completion: @escaping () -> Void) {
        guard !self.hasFinished else { completion(); return }
        self.completions.append(completion)
        self.hasRequestedPlay = true
        if self.layoutSize != nil && !self.hasStarted { self.start() }
    }

    private func start() {
        self.hasStarted = true
        self.usesReducedMotion = self.reduceMotion || UIAccessibility.isReduceMotionEnabled
        self.carrier.alpha = 1.0
        for sticker in [self.grip, self.bell] {
            sticker.visibility = false
            sticker.seekTo(.start)
        }
        if self.usesReducedMotion {
            self.carrier.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.16)
        } else {
            self.animateTravel(entering: true)
            self.animateSatellites(now: CACurrentMediaTime())
            self.animateBurst()
        }
        let exit = DispatchWorkItem { [weak self] in self?.animateOut() }
        self.exitWorkItem = exit
        DispatchQueue.main.asyncAfter(deadline: .now() + (self.usesReducedMotion ? 0.38 : 1.60), execute: exit)
        self.scheduleFinish(after: self.usesReducedMotion ? 0.62 : 3.25)
    }

    private func animateBurst() {
        let now = CACurrentMediaTime()
        let start = 0.35
        let end = Self.beats[Self.beats.count - 1].release + 0.07
        var times: [Double] = [start, Self.beats[0].release - 0.02]
        var widths: [CGFloat] = [1.0, 0.76]
        var heights: [CGFloat] = [1.0, 1.08]
        var recoils: [CGFloat] = [0.0, -2.0]
        for (index, shot) in Self.beats.enumerated() {
            times.append(shot.release)
            widths.append(shot.openX)
            heights.append(shot.openY)
            recoils.append(shot.recoil)
            times.append(shot.release + 0.025)
            widths.append(0.97)
            heights.append(0.99)
            recoils.append(-1.0)
            if index + 1 < Self.beats.count {
                let next = Self.beats[index + 1]
                times.append(next.release - 0.018)
                widths.append(1.0 - 0.17 * next.strength)
                heights.append(1.0 + 0.06 * next.strength)
                recoils.append(-1.5)
            }
        }
        times.append(end); widths.append(1.0); heights.append(1.0); recoils.append(0.0)
        let keyTimes = times.map { NSNumber(value: ($0 - start) / (end - start)) }
        // One uninterrupted curve per rig property; no overlapping 90ms shots
        // can replace or blend independently scheduled scale/recoil animations.
        let width = CAKeyframeAnimation(keyPath: "transform.scale.x")
        width.values = widths; width.keyTimes = keyTimes; width.duration = end - start
        width.beginTime = self.bellRig.layer.convertTime(now, from: nil) + start
        width.calculationMode = .linear
        self.bellRig.layer.add(width, forKey: "allMentionAutomaticBellWidth")
        let height = CAKeyframeAnimation(keyPath: "transform.scale.y")
        height.values = heights; height.keyTimes = keyTimes; height.duration = width.duration
        height.beginTime = width.beginTime; height.calculationMode = .linear
        self.bellRig.layer.add(height, forKey: "allMentionAutomaticBellHeight")
        let recoil = CAKeyframeAnimation(keyPath: "position.x")
        recoil.values = recoils; recoil.keyTimes = keyTimes; recoil.duration = width.duration
        recoil.beginTime = self.carrier.layer.convertTime(now, from: nil) + start
        recoil.calculationMode = .linear; recoil.isAdditive = true
        self.carrier.layer.add(recoil, forKey: "allMentionAutomaticRecoil")
        self.animateAirFlow(now: now)
        self.animateMentionParticles(now: now)
        self.animateSplashesAndDebris(now: now)
    }

    private func emissionOrigin(for beat: HonkBeat) -> CGPoint {
        guard let size = self.layoutSize else { return .zero }
        let x = Self.bellPivot.x + (Self.mouthPoint.x - Self.bellPivot.x) * beat.openX
        let y = Self.bellPivot.y + (Self.mouthPoint.y - Self.bellPivot.y) * beat.openY
        return CGPoint(x: size.width * 0.5 + (x - 0.5) * self.iconSide + beat.recoil, y: size.height * 0.5 + (y - 0.5) * self.iconSide)
    }

    private static func streamPoint(origin: CGPoint, progress: CGFloat, elapsed: Double, lane: CGFloat = 0.0) -> CGPoint {
        let u = max(0.0, min(1.06, progress))
        let envelope = sin(min(1.0, u) * .pi)
        let bend = -60.0 * sin(u * .pi) + 25.0 * sin(u * .pi * 2.0) + 18.0 * u
        let ripple = 7.0 * sin(u * 12.0 - CGFloat(elapsed) * 11.0) * envelope
        let separation = lane * min(1.0, u * 8.0) * (0.45 + 0.55 * u)
        return CGPoint(x: origin.x - 230.0 * u, y: origin.y + bend + ripple + separation)
    }

    private func animateAirFlow(now: CFTimeInterval) {
        let origin = self.emissionOrigin(for: Self.beats[0])
        let duration = 1.95
        let samples = (0 ... 80).map { Double($0) / 80.0 }
        for (index, ribbon) in self.flowRibbons.enumerated() {
            let path = CAKeyframeAnimation(keyPath: "path")
            path.values = samples.map { sample in
                Self.airRibbonPath(origin: origin, elapsed: sample * duration, band: index)
            }
            path.keyTimes = samples.map { NSNumber(value: $0) }
            path.duration = duration
            path.calculationMode = .linear
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.0, 0.95, 0.90, 0.45, 0.0]
            opacity.keyTimes = [0.0, 0.08, 0.65, 0.90, 1.0]
            opacity.duration = duration
            let flow = CAAnimationGroup()
            flow.animations = [path, opacity]
            flow.duration = duration
            flow.timingFunction = CAMediaTimingFunction(name: .linear)
            flow.beginTime = ribbon.convertTime(now, from: nil) + Self.beats[0].release
            ribbon.add(flow, forKey: "allMentionAirFlow")
        }
    }

    private static func airRibbonPath(origin: CGPoint, elapsed: Double, band: Int) -> CGPath {
        func smoothstep(_ value: Double) -> Double {
            let t = max(0.0, min(1.0, value))
            return t * t * (3.0 - 2.0 * t)
        }
        // The head unfolds first; after the last shot, the tail lifts off the
        // mouth and follows it. The path always has the same point topology.
        let head = smoothstep(elapsed / 0.58)
        let tail = smoothstep((elapsed - 0.93) / 1.02)
        let lane: CGFloat = band == 2 ? -6.0 : (band == 1 ? 4.0 : 0.0)
        let width: CGFloat = band == 0 ? 1.0 : (band == 1 ? 0.53 : 0.29)
        var upper: [CGPoint] = []
        var lower: [CGPoint] = []
        for index in 0 ... 32 {
            let fraction = Double(index) / 32.0
            let u = CGFloat(tail + (head - tail) * fraction)
            let center = Self.streamPoint(origin: origin, progress: u, elapsed: elapsed, lane: lane)
            let before = Self.streamPoint(origin: origin, progress: u - 0.002, elapsed: elapsed, lane: lane)
            let after = Self.streamPoint(origin: origin, progress: u + 0.002, elapsed: elapsed, lane: lane)
            let dx = after.x - before.x, dy = after.y - before.y
            let length = max(0.001, hypot(dx, dy))
            let taper = CGFloat(pow(max(0.0, sin(fraction * .pi)), 0.55))
            let breath = 0.88 + 0.12 * sin(CGFloat(elapsed) * 18.0 - u * 12.0 + CGFloat(band))
            let radius = (8.0 + 18.0 * u) * width * taper * breath
            let nx = -dy / length * radius, ny = dx / length * radius
            upper.append(CGPoint(x: center.x + nx, y: center.y + ny))
            lower.append(CGPoint(x: center.x - nx, y: center.y - ny))
        }
        let path = UIBezierPath()
        path.move(to: upper[0])
        for point in upper.dropFirst() { path.addLine(to: point) }
        for point in lower.reversed() { path.addLine(to: point) }
        path.close()
        return path.cgPath
    }

    private func animateSplashesAndDebris(now: CFTimeInterval) {
        for (index, shot) in Self.beats.enumerated() {
            let origin = self.emissionOrigin(for: shot)
            let splash = self.splashes[index]
            let duration = index % 3 == 0 ? 0.17 : 0.15
            let flight = CABasicAnimation(keyPath: "position")
            flight.fromValue = NSValue(cgPoint: origin)
            flight.toValue = NSValue(cgPoint: CGPoint(x: origin.x - (index % 3 == 0 ? 28.0 : 22.0), y: origin.y + CGFloat(index % 2 == 0 ? -4.0 : 4.0)))
            flight.duration = duration
            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [0.22, 0.98, 1.28]; scale.keyTimes = [0.0, 0.35, 1.0]; scale.duration = duration
            let alpha = CAKeyframeAnimation(keyPath: "opacity")
            alpha.values = [0.0, 0.88, 0.62, 0.0]; alpha.keyTimes = [0.0, 0.10, 0.45, 1.0]; alpha.duration = duration
            let group = CAAnimationGroup()
            group.animations = [flight, scale, alpha]; group.duration = duration
            group.beginTime = splash.convertTime(now, from: nil) + shot.release
            splash.position = origin
            splash.add(group, forKey: "allMentionSplash")
            for slot in 0 ..< 3 {
                let piece = self.debris[index * 3 + slot]
                let life = 0.48 + Double((index + slot) % 4) * 0.06
                let path = CAKeyframeAnimation(keyPath: "position")
                let ts = (0 ... 20).map { Double($0) / 20.0 }
                path.values = ts.map { t in
                    NSValue(cgPoint: Self.streamPoint(origin: origin, progress: CGFloat(t) * (0.30 + CGFloat(slot) * 0.09), elapsed: shot.release - Self.beats[0].release + t * life, lane: (CGFloat(slot) - 1.0) * 10.0))
                }
                path.keyTimes = ts.map { NSNumber(value: $0) }; path.duration = life; path.calculationMode = .linear
                let turn = CABasicAnimation(keyPath: "transform.rotation.z")
                turn.fromValue = CGFloat(index % 2 == 0 ? -0.25 : 0.25)
                turn.toValue = CGFloat(slot % 2 == 0 ? -2.2 : 2.2); turn.duration = life
                let shrink = CAKeyframeAnimation(keyPath: "transform.scale")
                shrink.values = [0.5, 1.0, 0.2]; shrink.keyTimes = [0.0, 0.08, 1.0]; shrink.duration = life
                let opacity = CAKeyframeAnimation(keyPath: "opacity")
                opacity.values = [0.0, 0.95, 0.8, 0.0]; opacity.keyTimes = [0.0, 0.08, 0.45, 1.0]; opacity.duration = life
                let emission = CAAnimationGroup()
                emission.animations = [path, turn, shrink, opacity]; emission.duration = life
                emission.beginTime = piece.convertTime(now, from: nil) + shot.release + Double(slot) * 0.008
                piece.position = origin; piece.add(emission, forKey: "allMentionDebris")
            }
        }
    }

    private func animateMentionParticles(now: CFTimeInterval) {
        guard self.layoutSize != nil else { return }
        let sampleTimes = (0 ... 72).map { Double($0) / 72.0 }
        for (index, particle) in self.mentionParticles.enumerated() {
            let slot = index % Self.particleSpecs.count
            let burst = index / Self.particleSpecs.count
            let spec = Self.particleSpecs[slot]
            let beat = Self.beats[burst]
            let origin = self.emissionOrigin(for: beat)
            let radius = hypot(particle.bounds.width, particle.bounds.height) * 0.72 + 4.0
            let duration = spec.duration * beat.lifetimeScale
            let playbackDuration = duration / Self.particleFlightSpeed
            let phase = Double(slot) * 1.37 + Double(burst) * 0.71
            let flowOrigin = self.emissionOrigin(for: Self.beats[0])
            let lane = slot == 0 ? CGFloat(burst % 3 - 1) * 9.0 : (burst % 2 == 0 ? 12.0 : -12.0)
            let rideDuration = 0.55 + Double(burst % 3) * 0.025 + Double(slot) * 0.025
            let releaseProgress: CGFloat = 0.64 + CGFloat(burst % 3) * 0.035 + CGFloat(slot) * 0.025
            let birth = beat.release - Self.beats[0].release + spec.delay * beat.lifetimeScale
            func ridingPoint(_ seconds: Double) -> CGPoint {
                let t = max(0.0, min(1.0, seconds / rideDuration))
                let progress = CGFloat((1.0 - exp(-0.38 * t)) / (1.0 - exp(-0.38)))
                let center = Self.streamPoint(origin: flowOrigin, progress: progress * releaseProgress, elapsed: birth + seconds / Self.particleFlightSpeed, lane: lane)
                return CGPoint(x: center.x + (origin.x - flowOrigin.x) * (1.0 - progress), y: center.y + (origin.y - flowOrigin.y) * (1.0 - progress))
            }
            let releasePoint = ridingPoint(rideDuration)
            let beforeRelease = ridingPoint(rideDuration - 0.008)
            let velocity = CGPoint(x: (releasePoint.x - beforeRelease.x) / 0.008, y: (releasePoint.y - beforeRelease.y) / 0.008)
            let turnDirection: CGFloat = (burst + slot) % 2 == 0 ? -1.0 : 1.0
            let angularVelocity = turnDirection * (turnDirection > 0.0 ? 1.45 + CGFloat(burst % 3) * 0.12 : 2.15 + CGFloat(burst % 4) * 0.20)
            let gravity: CGFloat = turnDirection > 0.0 ? 310.0 : 145.0 + CGFloat(slot) * 25.0
            let freeTimes = sampleTimes.map { max(0.0, $0 * duration - rideDuration) }
            let rawPositions = sampleTimes.map { time -> CGPoint in
                let seconds = time * duration
                guard seconds > rideDuration else { return ridingPoint(seconds) }
                let flightTime = CGFloat(seconds - rideDuration)
                let angle = angularVelocity * flightTime
                // Carry the stream's actual exit velocity into a turning eddy.
                // The integral has the same position AND velocity at release.
                let dx = (velocity.x * sin(angle) + velocity.y * (cos(angle) - 1.0)) / angularVelocity
                let dy = (velocity.x * (1.0 - cos(angle)) + velocity.y * sin(angle)) / angularVelocity
                let drag = CGFloat((1.0 - exp(-0.24 * Double(flightTime))) / (0.24 * Double(flightTime)))
                let flutter = CGFloat(sin(Double(flightTime) * 12.0 + phase) - sin(phase)) * 8.0 * min(1.0, flightTime / 0.15)
                let boost = 1.0 + 0.18 * (1.0 - exp(-flightTime * 8.0))
                return CGPoint(x: releasePoint.x + dx * drag * boost, y: releasePoint.y + dy * drag * boost + 0.5 * gravity * flightTime * flightTime + flutter)
            }
            // Fit the full arc with one additional downward acceleration if
            // necessary. Never flatten individual samples against a wall.
            var extraGravity: CGFloat = 0.0
            for (point, freeTime) in zip(rawPositions, freeTimes) where freeTime > 0.001 && point.y < radius {
                extraGravity = max(extraGravity, 2.0 * (radius - point.y) / CGFloat(freeTime * freeTime))
            }
            let positions = zip(rawPositions, freeTimes).map { point, freeTime in
                NSValue(cgPoint: CGPoint(x: point.x, y: point.y + 0.5 * extraGravity * CGFloat(freeTime * freeTime)))
            }
            let transforms = sampleTimes.map { time -> NSValue in
                let freeTime = max(0.0, time * duration - rideDuration)
                let flutterGate = CGFloat(min(1.0, freeTime / 0.16))
                let deformationTimes = [0.0, 0.06, 0.15, 0.30, 0.65, 1.0]
                let flex = CGFloat(sin(freeTime * 14.0 + phase)) * flutterGate
                let sx = Self.interpolate(time, times: deformationTimes, values: [0.25, 1.36, 0.93, 1.0, 1.0, 0.90]) * (1.0 + 0.12 * flex)
                let sy = Self.interpolate(time, times: deformationTimes, values: [0.80, 0.62, 1.15, 1.0, 1.0, 0.90]) * (1.0 - 0.08 * flex)
                let flutterAmplitude: CGFloat = spec.fontSize >= 28.0 ? 0.22 + 0.16 * flutterGate : 0.52 + 0.22 * flutterGate
                let spinDirection: CGFloat = burst % 2 == 0 ? 1.0 : -1.0
                let freeSpin: CGFloat = slot == 0 ? 2.7 + CGFloat(burst % 3) * 0.35 : 4.1 + CGFloat(burst % 3) * 0.40
                let angle = spec.tilt + spec.spin * spinDirection * CGFloat(time) + freeSpin * spinDirection * CGFloat(freeTime) + CGFloat(sin(time * .pi * 2.0 + phase) - sin(phase)) * 0.10
                var transform = CATransform3DIdentity
                transform.m34 = -1.0 / 400.0
                transform = CATransform3DRotate(transform, angle, 0.0, 0.0, 1.0)
                transform = CATransform3DRotate(transform, CGFloat(sin(time * .pi * 3.0 + freeTime * 5.0 + phase)) * flutterAmplitude, 0.0, 1.0, 0.0)
                transform = CATransform3DRotate(transform, CGFloat(cos(time * .pi * 2.2 + freeTime * 4.0 + phase)) * (0.18 + 0.12 * flutterGate), 1.0, 0.0, 0.0)
                transform = CATransform3DScale(transform, sx, sy, 1.0)
                return NSValue(caTransform3D: transform)
            }
            let flight = CAKeyframeAnimation(keyPath: "position")
            flight.values = positions
            flight.keyTimes = sampleTimes.map { NSNumber(value: $0) }
            flight.calculationMode = .linear
            flight.duration = playbackDuration
            let shape = CAKeyframeAnimation(keyPath: "transform")
            shape.values = transforms
            shape.keyTimes = flight.keyTimes
            shape.calculationMode = .linear
            shape.duration = playbackDuration
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = [0.0, 1.0, 1.0, 0.85, 0.0]
            opacity.keyTimes = [0.0, 0.04, 0.78, 0.92, 1.0]
            opacity.duration = playbackDuration
            let emission = CAAnimationGroup()
            emission.animations = [flight, shape, opacity]
            emission.duration = playbackDuration
            emission.timingFunction = CAMediaTimingFunction(name: .linear)
            emission.beginTime = particle.convertTime(now, from: nil) + beat.release + spec.delay * beat.lifetimeScale
            particle.position = origin
            particle.add(emission, forKey: "allMentionParticle")
        }
    }

    private static func interpolate(_ time: Double, times: [Double], values: [CGFloat]) -> CGFloat {
        for index in 1 ..< times.count where time <= times[index] {
            let fraction = CGFloat((time - times[index - 1]) / (times[index] - times[index - 1]))
            return values[index - 1] + (values[index] - values[index - 1]) * fraction
        }
        return values[values.count - 1]
    }

    private func animateTravel(entering: Bool) {
        guard let size = self.layoutSize else { return }
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        let offsets: [CGPoint]
        let times: [Double]
        let xs: [CGFloat]
        let ys: [CGFloat]
        let duration: Double
        if entering {
            offsets = [CGPoint(x: 105.0, y: self.travelDistance), CGPoint(x: 60.0, y: 90.0), CGPoint(x: -16.0, y: -11.0), CGPoint(x: 6.0, y: 5.0), .zero]
            times = [0.0, 0.50, 0.73, 0.91, 1.0]
            xs = [0.68, 0.88, 1.16, 0.95, 1.0]
            ys = [1.30, 1.16, 0.84, 1.06, 1.0]
            duration = 0.44
        } else {
            // Escape visibly across the chat before diving below its viewport.
            offsets = [.zero, CGPoint(x: 14.0, y: -10.0), CGPoint(x: -65.0, y: -18.0), CGPoint(x: -130.0, y: 35.0), CGPoint(x: -155.0, y: self.travelDistance + 20.0)]
            times = [0.0, 0.16, 0.46, 0.70, 1.0]
            xs = [1.0, 1.07, 0.94, 0.80, 0.60]
            ys = [1.0, 0.94, 1.08, 1.24, 0.82]
            duration = 0.50
        }
        let samples = (0 ... 64).map { Double($0) / 64.0 }
        let position = CAKeyframeAnimation(keyPath: "position")
        position.values = samples.map { t -> NSValue in
            let offset = Self.smoothTravel(t, points: offsets, times: times, settle: entering)
            return NSValue(cgPoint: CGPoint(x: center.x + offset.x, y: center.y + offset.y))
        }
        position.keyTimes = samples.map { NSNumber(value: $0) }
        position.calculationMode = .linear
        position.duration = duration
        position.isRemovedOnCompletion = entering
        position.fillMode = .forwards
        self.travelRig.layer.add(position, forKey: entering ? "allMentionArrival" : "allMentionDeparture")
        for (keyPath, values) in [("transform.scale.x", xs), ("transform.scale.y", ys)] {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = samples.map { Self.interpolate($0, times: times, values: values) }
            animation.keyTimes = position.keyTimes
            animation.duration = duration
            animation.calculationMode = .linear
            animation.isRemovedOnCompletion = entering
            animation.fillMode = .forwards
            self.travelRig.layer.add(animation, forKey: keyPath)
        }
    }

    private static func smoothTravel(_ time: Double, points: [CGPoint], times: [Double], settle: Bool) -> CGPoint {
        let segment = (1 ..< times.count).first(where: { time <= times[$0] }) ?? (times.count - 1)
        let left = segment - 1
        let span = times[segment] - times[left]
        let u = CGFloat((time - times[left]) / span)
        func tangent(_ index: Int) -> CGPoint {
            if index == points.count - 1 && settle { return .zero }
            let a = max(0, index - 1), b = min(points.count - 1, index + 1)
            let dt = CGFloat(times[b] - times[a])
            return CGPoint(x: (points[b].x - points[a].x) / dt, y: (points[b].y - points[a].y) / dt)
        }
        let a = points[left], b = points[segment], va = tangent(left), vb = tangent(segment)
        let h00 = 2.0 * u * u * u - 3.0 * u * u + 1.0
        let h10 = u * u * u - 2.0 * u * u + u
        let h01 = -2.0 * u * u * u + 3.0 * u * u
        let h11 = u * u * u - u * u
        let dt = CGFloat(span)
        return CGPoint(x: h00 * a.x + h10 * va.x * dt + h01 * b.x + h11 * vb.x * dt, y: h00 * a.y + h10 * va.y * dt + h01 * b.y + h11 * vb.y * dt)
    }

    private func animateSatellites(now: CFTimeInterval) {
        guard let size = self.layoutSize else { return }
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: center.x + x, y: center.y + y) }
        let markPaths: [(Double, CGPoint, CGPoint, CGPoint, CGPoint)] = [
            (0.72, point(-8.0, -25.0), point(-35.0, -85.0), point(-85.0, -130.0), point(-130.0, -110.0)),
            (1.12, point(25.0, -10.0), point(-35.0, -100.0), point(-145.0, -110.0), point(-210.0, -75.0)),
            (1.45, point(-25.0, 12.0), point(-70.0, -15.0), point(-145.0, 35.0), point(-180.0, 80.0))
        ]
        for (index, path) in markPaths.enumerated() {
            self.animateSatellite(layer: self.attentionMarks[index], origin: path.1, control1: path.2, control2: path.3, end: path.4, birth: path.0, duration: 1.0 + Double(index) * 0.04, spin: index == 1 ? 0.45 : -0.35, peak: 1.12, now: now)
        }
        for (index, star) in self.glints.enumerated() {
            let lift: CGFloat = index % 2 == 0 ? -1.0 : 1.0
            let origin = point(CGFloat(index % 2 == 0 ? -35.0 : 22.0), CGFloat(index % 2 == 0 ? -18.0 : 8.0))
            self.animateSatellite(layer: star, origin: origin, control1: point(-45.0, lift * 50.0), control2: point(-110.0 - CGFloat(index) * 10.0, lift * 90.0), end: point(-145.0 - CGFloat(index) * 18.0, lift * (65.0 + CGFloat(index) * 12.0)), birth: 0.58 + Double(index) * 0.23, duration: 0.68 + Double(index % 3) * 0.08, spin: lift * 1.1, peak: 1.4, now: now)
        }
    }

    private func animateSatellite(layer: CALayer, origin: CGPoint, control1: CGPoint, control2: CGPoint, end: CGPoint, birth: Double, duration: Double, spin: CGFloat, peak: CGFloat, now: CFTimeInterval) {
        let samples = (0 ... 48).map { Double($0) / 48.0 }
        let flight = CAKeyframeAnimation(keyPath: "position")
        flight.values = samples.map { time -> NSValue in
            let t = CGFloat((1.0 - exp(-0.8 * time)) / (1.0 - exp(-0.8)))
            let v = 1.0 - t
            return NSValue(cgPoint: CGPoint(x: v * v * v * origin.x + 3.0 * v * v * t * control1.x + 3.0 * v * t * t * control2.x + t * t * t * end.x, y: v * v * v * origin.y + 3.0 * v * v * t * control1.y + 3.0 * v * t * t * control2.y + t * t * t * end.y))
        }
        flight.keyTimes = samples.map { NSNumber(value: $0) }; flight.duration = duration; flight.calculationMode = .linear
        let scale = CAKeyframeAnimation(keyPath: "transform.scale")
        scale.values = [0.18, peak, 0.94, 1.0, 0.82]; scale.keyTimes = [0.0, 0.12, 0.26, 0.50, 1.0]; scale.duration = duration
        let turn = CABasicAnimation(keyPath: "transform.rotation.z")
        turn.fromValue = -spin * 0.3; turn.toValue = spin; turn.duration = duration
        let alpha = CAKeyframeAnimation(keyPath: "opacity")
        alpha.values = [0.0, 1.0, 1.0, 0.0]; alpha.keyTimes = [0.0, 0.08, 0.70, 1.0]; alpha.duration = duration
        let animation = CAAnimationGroup()
        animation.animations = [flight, scale, turn, alpha]; animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.beginTime = layer.convertTime(now, from: nil) + birth
        layer.position = origin
        layer.add(animation, forKey: "allMentionNotificationAccent")
    }

    private func animateOut() {
        guard !self.hasFinished else { return }
        if self.usesReducedMotion {
            self.carrier.alpha = 0.0
            self.carrier.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.24)
        } else {
            self.animateTravel(entering: false)
        }
    }

    private func hideSecondaryLayers() {
        for layer in self.flowRibbons { layer.removeAllAnimations(); layer.opacity = 0.0 }
        for layer in self.splashes { layer.removeAllAnimations(); layer.opacity = 0.0 }
        for layer in self.debris { layer.removeAllAnimations(); layer.opacity = 0.0 }
        for layer in self.mentionParticles { layer.removeAllAnimations(); layer.opacity = 0.0 }
        for layer in self.attentionMarks { layer.removeAllAnimations(); layer.opacity = 0.0 }
        for layer in self.glints { layer.removeAllAnimations(); layer.opacity = 0.0 }
    }

    private func scheduleFinish(after duration: Double) {
        self.finishWorkItem?.cancel()
        let finish = DispatchWorkItem { [weak self] in self?.finish() }
        self.finishWorkItem = finish
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: finish)
    }

    private func cancelScheduledWork() {
        self.exitWorkItem?.cancel()
        self.finishWorkItem?.cancel()
        self.exitWorkItem = nil
        self.finishWorkItem = nil
    }

    private func finish() {
        guard !self.hasFinished else { return }
        self.hasFinished = true
        self.cancelScheduledWork()
        self.carrier.alpha = 0.0
        self.travelRig.layer.removeAllAnimations()
        self.carrier.layer.removeAllAnimations()
        self.bellRig.layer.removeAllAnimations()
        self.hideSecondaryLayers()
        for sticker in [self.grip, self.bell] {
            sticker.visibility = false
            sticker.stop()
            sticker.reset()
        }
        let completions = self.completions
        self.completions.removeAll()
        for completion in completions { completion() }
    }
}
