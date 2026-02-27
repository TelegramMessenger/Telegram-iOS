import UIKit
import simd
import Display

final class Transform3DView: UIView {
    override class var layerClass: AnyClass { CATransformLayer.self }
}

final class PassthroughView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        for subview in self.subviews where !subview.isHidden && subview.alpha > 0 && subview.isUserInteractionEnabled {
            let converted = self.convert(point, to: subview)
            if subview.point(inside: converted, with: event) {
                return true
            }
        }
        return false
    }
}

final class CubeAnimationView: UIView {
    private let cubeSize: CGFloat
    private var perspective: CGFloat = 400.0
    private let stickerSize: CGFloat
    private let stickerGap: CGFloat

    private let camera = UIView()
    private let cubeContainer = Transform3DView()
    private var faces: [UIView] = []
    private var faceOccupants: [Int: UIView] = [:]

    let stickerContainer = PassthroughView()

    private var stickers: [UIView] = []
    private var isRunning = false

    private var displayLink: SharedDisplayLinkDriver.Link?
    private var lastTimestamp: CFTimeInterval = 0
    private var warpDisplayLink: SharedDisplayLinkDriver.Link?
    private weak var warpView: UIView?
    private var warpStartQuad: Quad?
    private var warpEndQuad: Quad?
    private var warpDuration: TimeInterval = 0
    private var warpDynamicTarget: (() -> Quad)?
    private var warpCompletion: (() -> Void)?
    private var warpStartTimestamp: CFTimeInterval = 0
    private var warpLastProgress: CGFloat = 0
    private var warpCurrentQuad: Quad?
    private var warpHasCompleted = false
    private var warpSnapshot: UIView?

    private var rotation = SIMD3<Float>(repeating: 0)
    private var angularVelocity = SIMD3<Float>(repeating: 0)

    private let dampingPerSecond: Float = 0.66
    private let finishSpringX: Float = 28.0
    private let finishSpringY: Float = 18.0
    private let finishDampingX: Float = 2.0 * sqrt(28.0)
    private let finishDampingY: Float = 2.0 * sqrt(18.0)
    private let finishWobbleAmplitudeZ: Float = 10.0 * .pi / 180.0
    private let finishWobbleCycles: Float = 1.0
    private let finishWobbleDampingExponent: Float = 0.6
    private let finishSuccessScale: Float = 1.3
    private let finishSuccessScaleTriggerAngle: Float = 0.4 * .pi
    private let finishApproachTriggerAngle: Float = 1.5 * .pi
    private let baseImpulseStrength: Float = 4.0
    private let impactNudgeDistance: CGFloat = 20.0
    private let impactNudgeEmphasis: CGFloat = 28.0

    private var isFinishingX = false
    private var isFinishingY = false
    private var finishTargetX: Float = 0.0
    private var finishTargetY: Float = 0.0
    private var finishDirectionY: Float = 1.0
    private var finishRotationY: Float = 0.0
    private var finishTargetYUnwrapped: Float = 0.0
    private var finishRemainingYStart: Float = 0.0
    private var finishDelayTimerX: Timer?
    private var finishDelayTimerY: Timer?
    private var cubeScale: Float = 1.0
    private var hasFiredFinishApproach = false
    
    var isSuccess = false

    var onStickerLaunch: (() -> Void)?
    var onFinishApproach: ((Bool, Bool) -> Void)?

    private let defaultStickOrder: [Int] = [0, 5, 4, 3]
    private let sequenceStickOrders: [String: [Int]] = [
        "0": [0],
        "0,1": [0, 5],
        "0,2": [0, 5],
        "0,3": [0, 5],
        "0,1,2": [0, 5, 4],
        "0,1,3": [0, 5, 2],
        "0,2,3": [0, 5, 1],
        "0,1,2,3": [0, 5, 4, 3]
    ]
    private var activeStickOrder: [Int] = []

    init(cubeSize: CGFloat = 110.0, stickerSize: CGFloat = 76.0, stickerGap: CGFloat = 30.0) {
        self.cubeSize = cubeSize
        self.stickerSize = stickerSize
        self.stickerGap = stickerGap
        
        super.init(frame: .zero)
        
        self.activeStickOrder = self.defaultStickOrder
        
        self.camera.backgroundColor = .clear
        self.camera.clipsToBounds = false
        self.addSubview(self.camera)

        self.cubeContainer.backgroundColor = .clear
        self.cubeContainer.clipsToBounds = false
        self.camera.addSubview(self.cubeContainer)

        var p = CATransform3DIdentity
        p.m34 = -1.0 / self.perspective
        self.camera.layer.sublayerTransform = p
        self.stickerContainer.layer.sublayerTransform = p
        
        self.stickerContainer.backgroundColor = .clear
        self.stickerContainer.clipsToBounds = false
        self.addSubview(self.stickerContainer)

#if DEBUG
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.camera.addGestureRecognizer(pan)
#endif
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        self.camera.bounds = CGRect(x: 0, y: 0, width: self.cubeSize, height: self.cubeSize)
        self.camera.center = CGPoint(x: self.bounds.midX, y: self.bounds.midY)

        self.cubeContainer.frame = self.camera.bounds
        self.stickerContainer.frame = self.bounds

        self.layoutStickers()
        self.layoutFaces()
        self.applyCubeRotation()
    }

    func setStickers(_ views: [UIView]) {
        self.stickers = views
        for view in views {
            view.layer.anchorPoint = .zero
            view.isUserInteractionEnabled = true

            if view.superview !== self.stickerContainer {
                self.stickerContainer.addSubview(view)
            }
        }
        self.layoutStickers()
    }

    func setSticker(_ sticker: UIView?, face index: Int, mirror: Bool, animated: Bool = false) {
        guard self.faces.indices.contains(index) else {
            return
        }

        if let existing = self.faceOccupants[index] {
            existing.removeFromSuperview()
            self.faceOccupants[index] = nil
        }

        guard let sticker else {
            return
        }

        if let priorIndex = self.faceOccupants.first(where: { $0.value === sticker })?.key {
            self.faceOccupants[priorIndex] = nil
        }
        
        if animated, let stickerSuperview = sticker.superview, let snapshotView = sticker.snapshotView(afterScreenUpdates: false) {
            stickerSuperview.addSubview(snapshotView)
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                snapshotView.removeFromSuperview()
            })
        }
        sticker.removeFromSuperview()
        
        let targetFace = self.faces[index]
        targetFace.addSubview(sticker)
        self.faceOccupants[index] = sticker

        sticker.layer.removeAllAnimations()
        sticker.transform = .identity
        sticker.layer.transform = CATransform3DIdentity
        sticker.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sticker.layer.isDoubleSided = false
        sticker.clipsToBounds = false
        sticker.isUserInteractionEnabled = false

        let faceStickerSize = self.cubeSize
        sticker.bounds = CGRect(x: 0, y: 0, width: faceStickerSize, height: faceStickerSize)
        sticker.center = CGPoint(x: self.cubeSize / 2, y: self.cubeSize / 2)

        var snappedAngle: CGFloat = 0.0
        if mirror {
            snappedAngle += .pi
        }
        sticker.transform = CGAffineTransform(rotationAngle: snappedAngle)
        
        if animated {
            sticker.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
    }

    func startStickerSequence(indices: [Int]? = nil) {
        guard !self.isRunning else {
            return
        }
        guard self.stickers.contains(where: { $0.superview === self.stickerContainer }) else {
            return
        }
        self.isRunning = true
        
        let sequence: [Int]
        if let indices, !indices.isEmpty {
            var seen = Set<Int>()
            var result: [Int] = []
            for index in indices where self.stickers.indices.contains(index) {
                if seen.insert(index).inserted {
                    result.append(index)
                }
            }
            sequence = result
        } else {
            sequence = Array(self.stickers.indices)
        }
        
        var stickOrder: [Int]
        let key = sequence.map(String.init).joined(separator: ",")
        if let order = self.sequenceStickOrders[key] {
            stickOrder = order
        } else {
            stickOrder = Array(self.defaultStickOrder.prefix(sequence.count))
        }
        self.activeStickOrder = stickOrder
        
        self.scheduleStickerSequence(from: 0, indices: sequence)
    }

    func resetAll() {
        self.isRunning = false
        self.resetStickers()
        self.resetCube()
        self.activeStickOrder = self.defaultStickOrder
    }

    func setFaces(_ views: [UIView]) {
        guard views.count == 6 else {
            return
        }
        self.faces.forEach { $0.removeFromSuperview() }
        self.faces = views
        for face in views {
            face.layer.isDoubleSided = false
            self.cubeContainer.addSubview(face)
        }
        self.layoutFaces()
    }

    private func layoutFaces() {
        guard self.faces.count == 6 else {
            return
        }
        let half = self.cubeSize / 2

        for face in self.faces {
            face.bounds = CGRect(x: 0, y: 0, width: self.cubeSize, height: self.cubeSize)
            face.center = CGPoint(x: self.cubeSize / 2, y: self.cubeSize / 2)
        }

        func faceTransform(rx: CGFloat, ry: CGFloat) -> CATransform3D {
            var m = CATransform3DIdentity
            m = CATransform3DRotate(m, rx, 1, 0, 0)
            m = CATransform3DRotate(m, ry, 0, 1, 0)
            m = CATransform3DTranslate(m, 0, 0, half)
            return m
        }

        self.faces[0].layer.transform = faceTransform(rx: 0, ry: 0)
        self.faces[1].layer.transform = faceTransform(rx: 0, ry: .pi / 2)
        self.faces[2].layer.transform = faceTransform(rx: 0, ry: .pi)
        self.faces[3].layer.transform = faceTransform(rx: 0, ry: -.pi / 2)
        self.faces[4].layer.transform = faceTransform(rx: -.pi / 2, ry: 0)
        self.faces[5].layer.transform = faceTransform(rx: .pi / 2, ry: 0)
    }

    private func animateWarp(for view: UIView, from startQuad: Quad, to targetQuad: Quad, duration: TimeInterval, dynamicTarget: (() -> Quad)? = nil, completion: @escaping () -> Void) {
        self.cancelWarp()
        self.warpView = view
        self.warpStartQuad = startQuad
        self.warpEndQuad = targetQuad
        self.warpDuration = duration
        self.warpDynamicTarget = dynamicTarget
        self.warpCompletion = completion
        self.warpStartTimestamp = 0
        self.warpLastProgress = 0
        self.warpHasCompleted = false
        self.warpCurrentQuad = startQuad
        startQuad.apply(to: view)

        let link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max) { [weak self] _ in
            self?.stepWarp()
        }
        link.isPaused = false
        self.warpDisplayLink = link
    }
    
    private func stepWarp() {
        guard let view = self.warpView, let currentQuad = self.warpCurrentQuad, let endQuad = self.warpEndQuad else {
            self.finishWarp()
            return
        }

        if self.warpStartTimestamp == 0 {
            self.warpStartTimestamp = CACurrentMediaTime()
        }

        let elapsed = CACurrentMediaTime() - self.warpStartTimestamp
        let progress = self.warpDuration > 0 ? min(1.0, elapsed / self.warpDuration) : 1.0
        let t = CGFloat(progress)
        let eased = t * t * (3 - 2 * t)
        let target = self.warpDynamicTarget?() ?? endQuad
        let delta = eased - self.warpLastProgress
        let remaining = max(1 - self.warpLastProgress, 0.0001)
        let weight = max(0, min(1, delta / remaining))
        let nextQuad = currentQuad.interpolated(to: target, t: weight)
        nextQuad.apply(to: view)
        self.warpCurrentQuad = nextQuad
        self.warpLastProgress = eased

        if progress >= 1.0 {
            self.finishWarp()
        }
    }

    private func cancelWarp() {
        self.warpHasCompleted = true
        self.warpDisplayLink?.invalidate()
        self.warpDisplayLink = nil
        self.warpCompletion = nil
        self.clearWarpState()
    }

    private func finishWarp() {
        guard !self.warpHasCompleted else { return }
        self.warpHasCompleted = true
        self.warpDisplayLink?.invalidate()
        self.warpDisplayLink = nil
        self.warpCompletion?()
        self.warpCompletion = nil
        self.clearWarpState()
    }

    private func clearWarpState() {
        self.warpView = nil
        self.warpStartQuad = nil
        self.warpEndQuad = nil
        self.warpDynamicTarget = nil
        self.warpStartTimestamp = 0
        self.warpLastProgress = 0
        self.warpCurrentQuad = nil
    }

    private func projectedQuad(for face: UIView) -> ProjectedFace {
        let bounds = face.bounds

        func project(_ p: CGPoint) -> CGPoint {
            let inRoot = face.layer.convert(p, to: self.layer)
            return self.stickerContainer.layer.convert(inRoot, from: self.layer)
        }

        var topLeft = project(CGPoint(x: bounds.minX, y: bounds.minY))
        var topRight = project(CGPoint(x: bounds.maxX, y: bounds.minY))
        var bottomLeft = project(CGPoint(x: bounds.minX, y: bounds.maxY))
        var bottomRight = project(CGPoint(x: bounds.maxX, y: bounds.maxY))

        func center(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) * 0.5, y: (a.y + b.y) * 0.5)
        }

        func normalized(_ v: CGPoint) -> CGPoint? {
            let len = hypot(v.x, v.y)
            guard len > 1e-5 else { return nil }
            return CGPoint(x: v.x / len, y: v.y / len)
        }

        func dot(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
            a.x * b.x + a.y * b.y
        }

        let screenUp = CGPoint(x: 0, y: -1)
        let screenRight = CGPoint(x: 1, y: 0)

        if let up = normalized(CGPoint(
            x: center(topLeft, topRight).x - center(bottomLeft, bottomRight).x,
            y: center(topLeft, topRight).y - center(bottomLeft, bottomRight).y
        )), dot(up, screenUp) < 0 {
            swap(&topLeft, &bottomLeft)
            swap(&topRight, &bottomRight)
        }

        let faceOrigin = project(.zero)
        let faceX = project(CGPoint(x: 1, y: 0))

        if let right = normalized(CGPoint(
            x: center(topRight, bottomRight).x - center(topLeft, bottomLeft).x,
            y: center(topRight, bottomRight).y - center(topLeft, bottomLeft).y
        )), dot(right, screenRight) < 0 {
            swap(&topLeft, &topRight)
            swap(&bottomLeft, &bottomRight)
        }

        let quad = Quad(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)

        let desiredTopVector = CGPoint(x: quad.topRight.x - quad.topLeft.x, y: quad.topRight.y - quad.topLeft.y)
        let baseTopVector = CGPoint(x: faceX.x - faceOrigin.x, y: faceX.y - faceOrigin.y)

        let desiredAngle = atan2(desiredTopVector.y, desiredTopVector.x)
        let baseAngle = atan2(baseTopVector.y, baseTopVector.x)
        let rotation = normalizeAngle(desiredAngle - baseAngle)

        return ProjectedFace(quad: quad, rotation: rotation)
    }

    private func layoutStickers() {
        guard !self.stickers.isEmpty else {
            return
        }

        let cubeCenterInSticker = self.stickerContainer.convert(self.camera.center, from: self)
        let r = self.cubeSize / 2 + self.stickerGap + self.stickerSize / 2
        let scale = self.stickerSize / self.cubeSize

        let positions = [
            CGPoint(x: cubeCenterInSticker.x - r, y: cubeCenterInSticker.y - r * 0.4),
            CGPoint(x: cubeCenterInSticker.x + r, y: cubeCenterInSticker.y - r * 0.4),
            CGPoint(x: cubeCenterInSticker.x - r, y: cubeCenterInSticker.y + r * 0.4),
            CGPoint(x: cubeCenterInSticker.x + r, y: cubeCenterInSticker.y + r * 0.4)
        ]

        for (i, view) in self.stickers.enumerated() {
            if view.superview !== self.stickerContainer {
                continue
            }
            view.bounds = CGRect(x: 0, y: 0, width: self.cubeSize, height: self.cubeSize)
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.center = CGPoint(x: positions[i].x - self.stickerSize * 0.5, y: positions[i].y - self.stickerSize * 0.5)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: self.camera)
        switch gesture.state {
        case .changed:
            let delta = CGPoint(x: translation.x, y: translation.y)

            self.rotation.y += Float(delta.x) * 0.018
            self.rotation.x += Float(-delta.y) * 0.018
            self.rotation = normalizedRotation(self.rotation)
            self.applyCubeRotation()
            
            gesture.setTranslation(.zero, in: self.camera)
        default:
            break
        }
    }

    func launchStickerView(_ sticker: UIView, emphasized: Bool, willFinish: Bool = false) {
        guard sticker.superview === self.stickerContainer else {
            return
        }
        var number = 0
        if self.faceOccupants.count < self.activeStickOrder.count {
            number = self.activeStickOrder[self.faceOccupants.count]
        }
        let faceIndex = number
        guard self.faces.count > faceIndex else { return }
        let targetFace = self.faces[faceIndex]

        let startCenterInSticker = sticker.center
        let cubeCenterInSticker = self.stickerContainer.convert(self.camera.center, from: self)

        sticker.isUserInteractionEnabled = false
        sticker.layer.isDoubleSided = false

        let faceStickerSize = self.cubeSize
        let duration: TimeInterval = 0.2
        let startQuad = Quad(rect: sticker.frame)
        let animationView: UIView
        if let snapshot = sticker.snapshotView(afterScreenUpdates: false) {
            self.warpSnapshot?.removeFromSuperview()
            self.warpSnapshot = snapshot
                        
            snapshot.bounds = sticker.bounds
            snapshot.center = sticker.center
            snapshot.layer.anchorPoint = sticker.layer.anchorPoint
            snapshot.layer.transform = sticker.layer.transform
            snapshot.layer.isDoubleSided = sticker.layer.isDoubleSided
            snapshot.isUserInteractionEnabled = false
            self.stickerContainer.addSubview(snapshot)
           
            sticker.isHidden = true
            animationView = snapshot
        } else {
            animationView = sticker
        }
        sticker.transform = .identity
        
        let projectedFace = self.projectedQuad(for: targetFace)
        let targetQuad = projectedFace.quad
        let dynamicTarget: () -> Quad = { [weak self, weak targetFace] in
            guard let self, let face = targetFace else {
                return targetQuad
            }
            return self.projectedQuad(for: face).quad
        }

        self.animateWarp(for: animationView, from: startQuad, to: targetQuad, duration: duration, dynamicTarget: dynamicTarget) { [weak self, weak sticker, weak targetFace, weak animationView] in
            guard let self, let sticker, let targetFace else {
                return
            }

            self.onStickerLaunch?()
            
            if let animationView, animationView !== sticker {
                animationView.removeFromSuperview()
                self.warpSnapshot = nil
                sticker.isHidden = false
            }

            sticker.removeFromSuperview()
            targetFace.addSubview(sticker)
            self.faceOccupants[faceIndex] = sticker

            sticker.bounds = CGRect(x: 0, y: 0, width: faceStickerSize, height: faceStickerSize)
            sticker.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            sticker.center = CGPoint(x: self.cubeSize / 2, y: self.cubeSize / 2)
            sticker.layer.transform = CATransform3DIdentity
            let finalProjection = self.projectedQuad(for: targetFace)
            let snappedAngle = snappedRightAngle(finalProjection.rotation)
            sticker.transform = CGAffineTransform(rotationAngle: snappedAngle)

            let delta = SIMD2<Float>(Float(cubeCenterInSticker.x - startCenterInSticker.x), Float(cubeCenterInSticker.y - startCenterInSticker.y))
            let direction = normalize2(delta)
            self.applyImpulse(direction: direction, emphasized: emphasized, replace: true)
            self.applyImpactSpring(direction: direction, emphasized: emphasized)
            if willFinish {
                self.startFinishingAnimation()
            }
            self.startSpinLoopIfNeeded()
        }
    }

    private func resetStickers() {
        self.cancelWarp()
        self.warpSnapshot?.removeFromSuperview()
        self.warpSnapshot = nil

        for sticker in self.stickers {
            sticker.layer.removeAllAnimations()
            sticker.transform = .identity
            sticker.layer.transform = CATransform3DIdentity
            sticker.layer.anchorPoint = .zero
            sticker.layer.isDoubleSided = true
            sticker.clipsToBounds = false
            sticker.isUserInteractionEnabled = true
            sticker.removeFromSuperview()
            self.stickerContainer.addSubview(sticker)
        }

        self.faceOccupants.removeAll()
        self.layoutStickers()
    }

    private func resetCube() {
        self.displayLink?.invalidate()
        self.displayLink = nil
        self.angularVelocity = .zero
        self.lastTimestamp = 0
        self.isFinishingX = false
        self.isFinishingY = false
        self.finishDelayTimerX?.invalidate()
        self.finishDelayTimerX = nil
        self.finishDelayTimerY?.invalidate()
        self.finishDelayTimerY = nil
        self.cubeScale = 1.0
        self.hasFiredFinishApproach = false
        
        self.rotation = SIMD3<Float>(repeating: 0)
        self.cubeScale = 1.0
        self.applyCubeRotation()
    }

    private func scheduleStickerSequence(from index: Int, indices: [Int]) {
        guard self.isRunning else {
            return
        }
        guard index < indices.count else {
            self.isRunning = false
            return
        }

        let delay: TimeInterval = index == 0 ? 0.0 : 1.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else {
                return
            }
            guard self.isRunning else {
                return
            }
            let stickerIndex = indices[index]
            if self.stickers.indices.contains(stickerIndex) {
                let isLast = index == indices.count - 1
                self.launchStickerView(self.stickers[stickerIndex], emphasized: isLast, willFinish: isLast)
            }
            self.scheduleStickerSequence(from: index + 1, indices: indices)
        }
    }

    private func applyImpulse(direction: SIMD2<Float>, emphasized: Bool, replace: Bool) {
        var xStrength = self.baseImpulseStrength
        var yStrength = self.baseImpulseStrength
        if emphasized {
            xStrength *= 10.0
            yStrength *= 4.0
        }
        let impulseX: Float = -direction.y * xStrength
        let impulseY: Float = direction.x * yStrength
        let impulseZ: Float = 0.0

        if replace {
            self.angularVelocity = SIMD3<Float>(impulseX, impulseY, impulseZ)
        } else {
            self.angularVelocity += SIMD3<Float>(impulseX, impulseY, impulseZ)
        }
    }

    private func applyImpactSpring(direction: SIMD2<Float>, emphasized: Bool) {
        guard simd_length(direction) > 0.0001 else {
            return
        }
        let distance = emphasized ? self.impactNudgeEmphasis : self.impactNudgeDistance
        let offsetX = CGFloat(direction.x) * distance
        let offsetY = CGFloat(direction.y) * distance

        let currentTransform = self.camera.layer.presentation()?.affineTransform() ?? self.camera.transform
        self.camera.layer.removeAllAnimations()
        let impactTransform = currentTransform.translatedBy(x: offsetX, y: offsetY)

        UIView.animate(withDuration: 0.08, delay: 0.0, options: [.curveEaseOut, .beginFromCurrentState]) {
            self.camera.transform = impactTransform
        } completion: { _ in
            UIView.animate(withDuration: 0.55, delay: 0, usingSpringWithDamping: 0.72, initialSpringVelocity: 0.2, options: .beginFromCurrentState) {
                self.camera.transform = .identity
            }
        }
    }

    private func startSpinLoopIfNeeded() {
        if self.displayLink == nil {
            let link = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max) { [weak self] _ in
                self?.tick()
            }
            link.isPaused = false
            self.displayLink = link
            self.lastTimestamp = 0.0
        }
    }

    private func tick() {
        let ts = CACurrentMediaTime()
        if self.lastTimestamp == 0 { self.lastTimestamp = ts; return }
        let dt = Float(ts - self.lastTimestamp)
        self.lastTimestamp = ts

        self.rotation += self.angularVelocity * dt
        if self.isFinishingX {
            let delta = shortestAngleDelta(from: self.rotation.x, to: self.finishTargetX)
            let accel = self.finishSpringX * delta - self.finishDampingX * self.angularVelocity.x
            self.angularVelocity.x += accel * dt
            if abs(delta) < 0.0006 && abs(self.angularVelocity.x) < 0.001 {
                self.rotation.x = self.finishTargetX
                self.angularVelocity.x = 0.0
                self.isFinishingX = false
            }
        }
        if self.isFinishingY {
            self.finishRotationY += self.angularVelocity.y * dt
            let remaining = self.finishTargetYUnwrapped - self.finishRotationY
            let accel = self.finishSpringY * remaining - self.finishDampingY * self.angularVelocity.y
            self.angularVelocity.y += accel * dt
            self.rotation.y = normalizeAngle(self.finishRotationY)
            let total = max(abs(self.finishRemainingYStart), 0.0001)
            let progress = min(max(1.0 - abs(remaining) / total, 0.0), 1.0)
            let damping = pow(1.0 - progress, self.finishWobbleDampingExponent)
            let phase = 2.0 * Float.pi * self.finishWobbleCycles * progress
            self.rotation.z = self.finishWobbleAmplitudeZ * sin(phase) * damping
            let absRemaining = abs(remaining)
            if !self.hasFiredFinishApproach && absRemaining <= self.finishApproachTriggerAngle {
                self.hasFiredFinishApproach = true
                let upsideDown = abs(shortestAngleDelta(from: self.rotation.x, to: Float.pi)) < (Float.pi / 2)
                let isClockwise = self.finishDirectionY > 0
                self.onFinishApproach?(upsideDown, isClockwise)
            }
            if self.isSuccess, absRemaining <= self.finishSuccessScaleTriggerAngle {
                let raw = (self.finishSuccessScaleTriggerAngle - absRemaining) / self.finishSuccessScaleTriggerAngle
                let eased = raw * raw * (3 - 2 * raw)
                self.cubeScale = 1.0 + (self.finishSuccessScale - 1.0) * eased
            } else if !self.isSuccess {
                self.cubeScale = 1.0
            }
            if abs(remaining) < 0.0008 && abs(self.angularVelocity.y) < 0.0015 {
                self.finishRotationY = self.finishTargetYUnwrapped
                self.rotation.y = self.finishTargetY
                self.angularVelocity.y = 0.0
                self.isFinishingY = false
                self.rotation.z = 0.0
                self.angularVelocity.z = 0.0
            }
        } else if self.rotation.z != 0 {
            self.rotation.z = 0.0
        }
        self.rotation = normalizedRotation(self.rotation)

        let damp = pow(self.dampingPerSecond, dt)
        self.angularVelocity *= damp

        self.applyCubeRotation()
    }

    private func startFinishingAnimation() {
        self.finishDelayTimerX?.invalidate()
        self.finishDelayTimerX = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: false) { [weak self] _ in
            self?.beginFinishingX()
        }
    }

    private func beginFinishingX() {
        let deltaToZero = abs(shortestAngleDelta(from: self.rotation.x, to: 0))
        let deltaToPi = abs(shortestAngleDelta(from: self.rotation.x, to: Float.pi))
        self.finishTargetX = deltaToZero <= deltaToPi ? 0 : Float.pi
        self.finishTargetY = self.finishTargetX == 0 ? 0 : Float.pi
        self.isFinishingX = true
        self.finishDelayTimerY?.invalidate()
        self.finishDelayTimerY = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            self?.beginFinishingY()
        }
    }

    private func beginFinishingY() {
        self.finishRotationY = self.rotation.y
        let directionY = nonZeroSign(self.angularVelocity.y, fallback: 1)
        self.finishDirectionY = directionY
        let startMod = normalizeAnglePositive(self.finishRotationY)
        let targetMod = normalizeAnglePositive(self.finishTargetY)
        let baseDelta: Float
        if directionY >= 0 {
            baseDelta = targetMod >= startMod ? targetMod - startMod : (Float.pi * 2) - (startMod - targetMod)
        } else {
            baseDelta = startMod >= targetMod ? startMod - targetMod : (Float.pi * 2) - (targetMod - startMod)
        }
        var delta = baseDelta
        if delta < Float.pi {
            delta += Float.pi * 2
        }
        self.finishTargetYUnwrapped = self.finishRotationY + directionY * delta
        self.finishRemainingYStart = self.finishTargetYUnwrapped - self.finishRotationY
        self.isFinishingY = true
        self.hasFiredFinishApproach = false
    }

    private func applyCubeRotation() {
        var m = CATransform3DIdentity
        m = CATransform3DRotate(m, CGFloat(self.rotation.x), 1, 0, 0)
        m = CATransform3DRotate(m, CGFloat(self.rotation.y), 0, 1, 0)
        m = CATransform3DRotate(m, CGFloat(self.rotation.z), 0, 0, 1)
        m = CATransform3DScale(m, CGFloat(self.cubeScale), CGFloat(self.cubeScale), 1)
        self.cubeContainer.layer.transform = m
    }
}
