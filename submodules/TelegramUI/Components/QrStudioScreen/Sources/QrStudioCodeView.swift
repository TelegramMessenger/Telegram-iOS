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
        self.hotMask.endPoint = CGPoint(x: 0.5, y: (bottom + 22.0) / side)

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

    func update(matrix: QrCodeMatrix?, ink: QrStudioColor, cardColor: UIColor, transition: ComponentTransition, animatesInk: Bool = true) {
        let size = self.bounds.size
        let side = min(size.width, size.height)

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
            for (targetLayer, keyPath) in targets {
                let animation = CAKeyframeAnimation(keyPath: keyPath)
                animation.values = values
                animation.duration = 0.5
                animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                targetLayer.add(animation, forKey: "ink")
            }
        }
        self.codeLayer.update(paths: self.paths, color: inkColor, size: size)

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
