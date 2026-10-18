import Foundation
import UIKit
import Display
import ComponentFlow
import QrCode

private final class QrStudioCodeShapesLayer: SimpleLayer {
    let bodyLayer = CAShapeLayer()
    let framesLayer = CAShapeLayer()
    let ballsLayer = CAShapeLayer()

    var shapeLayers: [CAShapeLayer] {
        return [self.bodyLayer, self.framesLayer, self.ballsLayer]
    }

    override init() {
        super.init()

        self.framesLayer.fillRule = .evenOdd
        self.addSublayer(self.bodyLayer)
        self.addSublayer(self.framesLayer)
        self.addSublayer(self.ballsLayer)
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(paths: QrStudioCodePaths?, color: CGColor, size: CGSize) {
        let frame = CGRect(origin: CGPoint(), size: size)
        self.frame = frame
        for shapeLayer in self.shapeLayers {
            shapeLayer.frame = frame
            shapeLayer.fillColor = color
        }
        self.bodyLayer.path = paths?.body
        self.framesLayer.path = paths?.frames
        self.ballsLayer.path = paths?.balls
    }
}

private final class QrStudioCodeSweep {
    let startedAt: Double
    let side: CGFloat

    let newMask = CAGradientLayer()
    let hotLayer = QrStudioCodeShapesLayer()
    let hotMask = CAGradientLayer()
    let oldLayer = QrStudioCodeShapesLayer()
    let oldMask = CAShapeLayer()
    let emberContainer = SimpleLayer()
    let emberGradient = CAGradientLayer()
    let emberShapes = QrStudioCodeShapesLayer()
    let emberMask = CAShapeLayer()
    let glowLayer = CAShapeLayer()
    let coreLayer = CAShapeLayer()
    let ashLayer = QrStudioAshLayer()

    var layers: [CALayer] {
        return [self.hotLayer, self.oldLayer, self.emberContainer, self.glowLayer, self.coreLayer, self.ashLayer]
    }

    init(startedAt: Double, side: CGFloat, oldPaths: QrStudioCodePaths, oldMatrix: QrCodeMatrix, newPaths: QrStudioCodePaths, ink: QrStudioColor) {
        self.startedAt = startedAt
        self.side = side

        let size = CGSize(width: side, height: side)
        let frame = CGRect(origin: CGPoint(), size: size)
        let pastel = ink.pastel.uiColor.cgColor

        self.newMask.frame = frame
        self.newMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]

        self.hotLayer.update(paths: newPaths, color: pastel, size: size)
        self.hotMask.frame = frame
        self.hotMask.colors = [UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        self.hotMask.locations = [0.0, 0.35, 1.0]
        self.hotLayer.mask = self.hotMask

        self.oldLayer.update(paths: oldPaths, color: ink.uiColor.cgColor, size: size)
        self.oldMask.frame = frame
        self.oldLayer.mask = self.oldMask

        self.emberContainer.frame = frame
        self.emberGradient.frame = frame
        self.emberGradient.colors = [UIColor.clear.cgColor, pastel, UIColor.white.cgColor]
        self.emberShapes.update(paths: oldPaths, color: UIColor.black.cgColor, size: size)
        self.emberGradient.mask = self.emberShapes
        self.emberContainer.addSublayer(self.emberGradient)
        self.emberMask.frame = frame
        self.emberContainer.mask = self.emberMask

        self.glowLayer.frame = frame
        self.glowLayer.fillColor = nil
        self.glowLayer.strokeColor = pastel
        self.glowLayer.lineWidth = 9.0
        self.glowLayer.opacity = 0.35
        self.glowLayer.shadowColor = pastel
        self.glowLayer.shadowRadius = 7.0
        self.glowLayer.shadowOpacity = 1.0
        self.glowLayer.shadowOffset = CGSize()

        self.coreLayer.frame = frame
        self.coreLayer.fillColor = nil
        self.coreLayer.strokeColor = UIColor.white.cgColor
        self.coreLayer.lineWidth = 1.6
        self.coreLayer.opacity = 0.9

        for layer in [self.glowLayer, self.coreLayer] {
            let clip = SimpleLayer()
            clip.backgroundColor = UIColor.black.cgColor
            clip.frame = frame.insetBy(dx: -QrStudioSweep.canvasPad, dy: -QrStudioSweep.canvasPad)
            layer.mask = clip
        }

        let margin = QrStudioAshLayer.margin
        self.ashLayer.frame = frame.insetBy(dx: -margin, dy: -margin)
        self.ashLayer.start(matrix: oldMatrix, side: side, ink: ink, at: startedAt)
    }

    func update(time: Double) {
        let since = time - self.startedAt
        let side = self.side
        let front = QrStudioSweep.front(at: since, side: side)
        let isFrontVisible = since < QrStudioSweep.sweepTime + 0.05

        let steps = 40
        var edgePoints: [CGPoint] = []
        edgePoints.reserveCapacity(steps + 1)
        for i in 0 ... steps {
            let x = side * CGFloat(i) / CGFloat(steps)
            edgePoints.append(CGPoint(x: x, y: QrStudioSweep.edge(x: x, front: front, since: since)))
        }

        let visible = CGMutablePath()
        visible.move(to: CGPoint(x: -2.0, y: -2.0))
        visible.addLine(to: CGPoint(x: side + 2.0, y: -2.0))
        for point in edgePoints.reversed() {
            visible.addLine(to: point)
        }
        visible.closeSubpath()
        self.oldMask.path = visible

        let line = CGMutablePath()
        let ember = CGMutablePath()
        for (i, point) in edgePoints.enumerated() {
            if i == 0 {
                line.move(to: point)
                ember.move(to: point)
            } else {
                line.addLine(to: point)
                ember.addLine(to: point)
            }
        }
        for point in edgePoints.reversed() {
            ember.addLine(to: CGPoint(x: point.x, y: point.y - 9.0))
        }
        ember.closeSubpath()
        self.emberMask.path = ember
        self.emberGradient.startPoint = CGPoint(x: 0.5, y: (front - 9.0) / side)
        self.emberGradient.endPoint = CGPoint(x: 0.5, y: (front + QrStudioSweep.depth) / side)

        self.glowLayer.path = line
        self.coreLayer.path = line
        self.glowLayer.isHidden = !isFrontVisible
        self.coreLayer.isHidden = !isFrontVisible
        self.emberContainer.isHidden = !isFrontVisible

        let top = front + QrStudioSweep.lag
        let bottom = top + QrStudioSweep.fade
        self.newMask.startPoint = CGPoint(x: 0.5, y: top / side)
        self.newMask.endPoint = CGPoint(x: 0.5, y: bottom / side)
        self.hotMask.startPoint = CGPoint(x: 0.5, y: top / side)
        self.hotMask.endPoint = CGPoint(x: 0.5, y: (bottom + QrStudioSweep.hot) / side)

        self.ashLayer.tick(time: time)
    }

    var isFinished: Bool {
        return !self.ashLayer.isRunning
    }

    func isCodeSettled(at time: Double) -> Bool {
        return time - self.startedAt >= QrStudioSweep.transition
    }
}

final class QrStudioCodeView: UIView {
    private let codeLayer = QrStudioCodeShapesLayer()
    private let logoBackgroundLayer = SimpleLayer()
    private let planeHostView = UIView()
    private let planeLayer = QrStudioPlaneLayer()

    var planeView: UIView? {
        return self.planeHostView
    }


    private var matrix: QrCodeMatrix?
    private var pathsSize: CGSize?
    private var paths: QrStudioCodePaths?
    private var ink: QrStudioColor?

    private var sweep: QrStudioCodeSweep?
    private var sweepLink: SharedDisplayLinkDriver.Link?
    private var pendingMatrix: QrCodeMatrix?

    private var revealLink: SharedDisplayLinkDriver.Link?
    private var revealElapsed: Double = 0.0
    private var revealLastTick: Double?
    private let revealMask = CAShapeLayer()
    private var revealEyes: [(layer: CAShapeLayer, distance: Double)] = []

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.layer.addSublayer(self.codeLayer)
        self.layer.addSublayer(self.logoBackgroundLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func endSweep() {
        guard let sweep = self.sweep else {
            return
        }
        self.sweep = nil
        self.sweepLink = nil
        self.codeLayer.mask = nil
        for layer in sweep.layers {
            layer.removeFromSuperlayer()
        }
    }

    private func settleSweepCode() {
        guard let sweep = self.sweep else {
            return
        }
        self.codeLayer.mask = nil
        sweep.hotLayer.removeFromSuperlayer()
        sweep.oldLayer.removeFromSuperlayer()
        sweep.emberContainer.removeFromSuperlayer()
        sweep.glowLayer.removeFromSuperlayer()
        sweep.coreLayer.removeFromSuperlayer()
    }

    private func startSweep(oldMatrix: QrCodeMatrix, oldPaths: QrStudioCodePaths, newPaths: QrStudioCodePaths, ink: QrStudioColor, side: CGFloat) {
        self.endReveal()
        self.endSweep()

        let sweep = QrStudioCodeSweep(startedAt: QrStudioClock.now, side: side, oldPaths: oldPaths, oldMatrix: oldMatrix, newPaths: newPaths, ink: ink)
        self.sweep = sweep
        self.codeLayer.mask = sweep.newMask
        self.layer.insertSublayer(sweep.hotLayer, above: self.codeLayer)
        self.layer.insertSublayer(sweep.oldLayer, above: sweep.hotLayer)
        self.layer.insertSublayer(sweep.emberContainer, above: sweep.oldLayer)
        self.layer.insertSublayer(sweep.glowLayer, above: sweep.emberContainer)
        self.layer.insertSublayer(sweep.coreLayer, above: sweep.glowLayer)
        self.layer.addSublayer(sweep.ashLayer)
        sweep.update(time: sweep.startedAt)

        self.animateLogoDip()

        self.sweepLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .fps(60), { [weak self] _ in
            guard let self, let sweep = self.sweep else {
                return
            }
            let time = QrStudioClock.now
            if let pendingMatrix = self.pendingMatrix, time - sweep.startedAt >= QrStudioSweep.sweepTime {
                self.pendingMatrix = nil
                self.applyPendingMatrix(pendingMatrix)
                return
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            if sweep.isCodeSettled(at: time) {
                if self.codeLayer.mask != nil {
                    self.settleSweepCode()
                }
                sweep.ashLayer.tick(time: time)
            } else {
                sweep.update(time: time)
            }
            if sweep.isFinished {
                self.endSweep()
            }
            CATransaction.commit()
        })
    }

    private func applyPendingMatrix(_ matrix: QrCodeMatrix) {
        let size = self.bounds.size
        let side = min(size.width, size.height)
        guard let previousMatrix = self.matrix, let previousPaths = self.paths, let ink = self.ink, previousMatrix != matrix, side > 0.0 else {
            return
        }
        let paths = QrStudioCodePaths(matrix: matrix, side: side)
        self.matrix = matrix
        self.pathsSize = size
        self.paths = paths
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.codeLayer.update(paths: paths, color: ink.uiColor.cgColor, size: size)
        self.startSweep(oldMatrix: previousMatrix, oldPaths: previousPaths, newPaths: paths, ink: ink, side: side)
        CATransaction.commit()
    }

    private func animateLogoDip() {
        let dip = CABasicAnimation(keyPath: "transform.scale")
        dip.fromValue = 1.0
        dip.toValue = 0.86
        dip.duration = 0.14
        dip.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let spring = CASpringAnimation(keyPath: "transform.scale")
        spring.fromValue = 0.86
        spring.toValue = 1.0
        spring.mass = 1.0
        spring.stiffness = 195.0
        spring.damping = 15.36
        spring.beginTime = 0.14
        spring.duration = 0.6

        let group = CAAnimationGroup()
        group.animations = [dip, spring]
        group.duration = 0.74
        self.logoBackgroundLayer.add(group, forKey: "dip")
        self.planeHostView.layer.add(group, forKey: "dip")
    }

    static let revealTime: Double = 0.6
    private static let logoRevealTime: Double = 0.9

    private static func logoSpring(_ t: Double) -> Double {
        let zeta = 0.7
        let omega = 2.0 * Double.pi / 0.6
        let damped = omega * (1.0 - zeta * zeta).squareRoot()
        return 1.0 - exp(-zeta * omega * t) * (cos(damped * t) + zeta * omega / damped * sin(damped * t))
    }

    func playReveal(delay: Double) {
        self.endReveal()
        let size = self.bounds.size
        let side = min(size.width, size.height)
        guard let matrix = self.matrix, let ink = self.ink, side > 0.0 else {
            return
        }
        let n = matrix.size
        let unit = side / CGFloat(max(1, n))
        let center = Double(n - 1) / 2.0
        let reach = hypot(center, center)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.revealMask.frame = CGRect(origin: CGPoint(), size: size)
        self.revealMask.path = nil
        self.codeLayer.bodyLayer.mask = self.revealMask
        self.codeLayer.framesLayer.isHidden = true
        self.codeLayer.ballsLayer.isHidden = true
        for eye in matrix.eyes {
            let rect = CGRect(x: CGFloat(eye.x) * unit, y: CGFloat(eye.y) * unit, width: unit * 7.0, height: unit * 7.0)
            let local = CGRect(origin: CGPoint(), size: rect.size)
            let parts = QrStudioCodePaths.eyeParts(rect: local, unit: unit)
            let path = CGMutablePath()
            path.addPath(parts.outer)
            path.addPath(parts.inner)
            path.addPath(parts.ball)
            let layer = CAShapeLayer()
            layer.fillRule = .evenOdd
            layer.fillColor = ink.uiColor.cgColor
            layer.path = path
            layer.bounds = local
            layer.position = CGPoint(x: rect.midX, y: rect.midY)
            layer.transform = CATransform3DMakeScale(0.001, 0.001, 1.0)
            self.codeLayer.addSublayer(layer)
            self.revealEyes.append((layer, hypot(Double(eye.x) + 3.0 - center, Double(eye.y) + 3.0 - center) / reach))
        }
        for layer in [self.logoBackgroundLayer, self.planeHostView.layer] {
            layer.transform = CATransform3DMakeScale(0.55, 0.55, 1.0)
            layer.opacity = 0.0
        }
        CATransaction.commit()

        var cells: [(x: Int, y: Int, distance: Double)] = []
        for y in 0 ..< n {
            for x in 0 ..< n where matrix[x, y] && !QrCodeMatrix.isEye(x: x, y: y, size: n) && !QrStudioCodePaths.isInLogo(x: x, y: y, size: n) {
                cells.append((x, y, hypot(Double(x) - center, Double(y) - center) / reach))
            }
        }

        self.revealElapsed = -delay
        self.revealLastTick = nil
        self.revealLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] _ in
            guard let self else {
                return
            }
            let now = QrStudioClock.now
            if let lastTick = self.revealLastTick {
                self.revealElapsed += min(now - lastTick, 1.0 / 30.0)
            }
            self.revealLastTick = now
            let k = min(1.0, max(0.0, self.revealElapsed / QrStudioCodeView.revealTime))
            if self.revealElapsed >= QrStudioCodeView.logoRevealTime {
                self.endReveal()
                return
            }
            let logoTime = max(0.0, self.revealElapsed)
            let logoScale = 0.55 + 0.45 * QrStudioCodeView.logoSpring(logoTime)
            let logoAlpha = 1.0 - pow(1.0 - min(1.0, logoTime / 0.25), 2.0)
            func grow(_ distance: Double) -> Double {
                return QrStudioCurve.backOut(QrStudioCurve.clamp01((k - 0.5 * distance) / 0.5))
            }
            let windows = CGMutablePath()
            for cell in cells {
                let s = grow(cell.distance)
                guard s > 0.01 else {
                    continue
                }
                let w = unit * 1.5 * CGFloat(s)
                let r = min(w * 0.5, w * 0.5 * CGFloat(1.0 - 0.7 * QrStudioCurve.clamp01(s)))
                windows.addRoundedRect(in: CGRect(x: (CGFloat(cell.x) + 0.5) * unit - w * 0.5, y: (CGFloat(cell.y) + 0.5) * unit - w * 0.5, width: w, height: w), cornerWidth: r, cornerHeight: r)
            }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.revealMask.path = windows
            for layer in [self.logoBackgroundLayer, self.planeHostView.layer] {
                layer.transform = CATransform3DMakeScale(CGFloat(logoScale), CGFloat(logoScale), 1.0)
                layer.opacity = Float(logoAlpha)
            }
            for eye in self.revealEyes {
                let s = max(0.001, CGFloat(grow(eye.distance)))
                eye.layer.transform = CATransform3DMakeScale(s, s, 1.0)
            }
            CATransaction.commit()
        })
    }

    private func endReveal() {
        guard self.revealLink != nil || !self.revealEyes.isEmpty else {
            return
        }
        self.revealLink = nil
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        if self.codeLayer.bodyLayer.mask === self.revealMask {
            self.codeLayer.bodyLayer.mask = nil
        }
        self.codeLayer.framesLayer.isHidden = false
        self.codeLayer.ballsLayer.isHidden = false
        for layer in [self.logoBackgroundLayer, self.planeHostView.layer] {
            layer.transform = CATransform3DIdentity
            layer.opacity = 1.0
        }
        for eye in self.revealEyes {
            eye.layer.removeFromSuperlayer()
        }
        self.revealEyes = []
        CATransaction.commit()
    }

    func update(matrix: QrCodeMatrix?, ink: QrStudioColor, cardColor: UIColor, transition: ComponentTransition, animatesInk: Bool = true) {
        let size = self.bounds.size
        let side = min(size.width, size.height)

        var matrix = matrix
        if let incoming = matrix, let sweep = self.sweep, self.matrix != nil, self.pathsSize == size, !transition.animation.isImmediate, QrStudioClock.now - sweep.startedAt < QrStudioSweep.sweepTime {
            self.pendingMatrix = incoming == self.matrix ? nil : incoming
            matrix = self.matrix
        } else {
            self.pendingMatrix = nil
        }

        let previousMatrix = self.matrix
        let previousPaths = self.paths
        if let matrix, self.matrix != matrix || self.pathsSize != size {
            self.matrix = matrix
            self.pathsSize = size
            self.paths = QrStudioCodePaths(matrix: matrix, side: side)
        }

        let previousInk = self.ink
        self.ink = ink

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let inkColor = ink.uiColor.cgColor
        if let previousInk, previousInk != ink, animatesInk, !transition.animation.isImmediate {
            var values: [CGColor] = []
            for i in 0 ..< 16 {
                values.append(QrStudioColor.mixLab(previousInk, ink, CGFloat(i) / 15.0).uiColor.cgColor)
            }
            var targets: [(CALayer, String)] = self.codeLayer.shapeLayers.map { ($0, "fillColor") }
            targets.append((self.logoBackgroundLayer, "backgroundColor"))
            for eye in self.revealEyes {
                targets.append((eye.layer, "fillColor"))
            }
            for (targetLayer, keyPath) in targets {
                let animation = CAKeyframeAnimation(keyPath: keyPath)
                animation.values = values
                animation.duration = 0.5
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                targetLayer.add(animation, forKey: "ink")
            }
        }
        self.codeLayer.update(paths: self.paths, color: inkColor, size: size)
        for eye in self.revealEyes {
            eye.layer.fillColor = inkColor
        }

        let hasCode = self.paths != nil
        let logoDiameter = self.paths?.logoDiameter ?? 0.0
        let logoFrame = CGRect(x: (size.width - logoDiameter) * 0.5, y: (size.height - logoDiameter) * 0.5, width: logoDiameter, height: logoDiameter)
        self.logoBackgroundLayer.bounds = CGRect(origin: CGPoint(), size: logoFrame.size)
        self.logoBackgroundLayer.position = CGPoint(x: logoFrame.midX, y: logoFrame.midY)
        self.logoBackgroundLayer.cornerRadius = logoDiameter * 0.5
        self.logoBackgroundLayer.backgroundColor = inkColor
        self.logoBackgroundLayer.isHidden = !hasCode

        if let previousMatrix, let previousPaths, let matrix = self.matrix, let paths = self.paths, previousMatrix != matrix, !transition.animation.isImmediate, side > 0.0 {
            self.startSweep(oldMatrix: previousMatrix, oldPaths: previousPaths, newPaths: paths, ink: ink, side: side)
        }

        CATransaction.commit()

        let planeSide = logoDiameter + 8.0
        if self.planeHostView.superview == nil {
            self.planeHostView.isUserInteractionEnabled = false
            self.addSubview(self.planeHostView)
        }
        self.planeHostView.bounds = CGRect(x: 0.0, y: 0.0, width: planeSide, height: planeSide)
        self.planeHostView.center = CGPoint(x: size.width * 0.5, y: size.height * 0.5 - 1.0)
        self.planeHostView.isHidden = !hasCode
        if self.planeLayer.superlayer == nil {
            self.planeHostView.layer.addSublayer(self.planeLayer)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.planeLayer.frame = CGRect(x: 0.0, y: 0.0, width: planeSide, height: planeSide)
        CATransaction.commit()
        self.planeLayer.update(pointSize: CGSize(width: planeSide, height: planeSide))
    }
}
