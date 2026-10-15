import Foundation
import UIKit
import Display

final class QrStudioBackgroundStage: UIView {
    var makeContent: ((QrStudioBackdrop) -> QrStudioBackgroundContent)?
    var updateContent: ((QrStudioBackgroundContent, QrStudioBackdrop) -> Void)?

    private var stack = QrStudioStageStack<QrStudioBackgroundContent>()
    private var currentBackdrop: QrStudioBackdrop?
    private var size = CGSize()
    private var revealCenter = CGPoint()
    private var activeReveals = 0
    private var isVisible = true

    var isRevealing: Bool {
        return self.activeReveals > 0
    }

    var wantsFullFrameRate: Bool {
        return self.stack.layers.last?.item.wantsFullFrameRate ?? false
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        self.clipsToBounds = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(backdrop: QrStudioBackdrop, size: CGSize, revealCenter: CGPoint, animated: Bool) {
        self.size = size
        self.revealCenter = revealCenter

        for layer in self.stack.layers {
            layer.item.frame = CGRect(origin: CGPoint(), size: size)
            layer.item.update(size: size, revealCenter: revealCenter)
        }

        guard let makeContent = self.makeContent else {
            return
        }
        if let currentBackdrop = self.currentBackdrop {
            if currentBackdrop.signature == backdrop.signature {
                return
            }
            if currentBackdrop.key == backdrop.key, let top = self.stack.layers.last {
                self.currentBackdrop = backdrop
                self.updateContent?(top.item, backdrop)
                return
            }
        }
        let isFirst = self.currentBackdrop == nil
        self.currentBackdrop = backdrop

        let content = makeContent(backdrop)
        content.frame = CGRect(origin: CGPoint(), size: size)
        content.update(size: size, revealCenter: revealCenter)
        content.setVisible(self.isVisible)
        self.addSubview(content)
        let id = self.stack.push(content)

        if isFirst || !animated || size.width <= 0.0 || size.height <= 0.0 {
            self.revealCompleted(id: id)
        } else {
            content.beginReveal(at: QrStudioClock.now)
            self.runReveal(on: content, id: id, center: revealCenter, size: size)
        }
    }

    func tick(time: Double, pan: QrStudioPan, drift: QrStudioDrift, tilt: SIMD2<Double>) {
        for layer in self.stack.layers {
            layer.item.tick(time: time, pan: pan, drift: drift, tilt: tilt)
        }
    }

    func forEachContent(_ f: (QrStudioBackgroundContent) -> Void) {
        for layer in self.stack.layers {
            f(layer.item)
        }
    }

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        for layer in self.stack.layers {
            layer.item.setVisible(isVisible)
        }
    }

    private func revealCompleted(id: Int) {
        let removedIds = Set(self.stack.revealCompleted(id: id))
        guard !removedIds.isEmpty else {
            return
        }
        let remaining = Set(self.stack.layers.map { ObjectIdentifier($0.item) })
        for subview in self.subviews {
            if let content = subview as? QrStudioBackgroundContent, !remaining.contains(ObjectIdentifier(content)) {
                content.setVisible(false)
                content.removeFromSuperview()
            }
        }
    }

    private func runReveal(on view: UIView, id: Int, center: CGPoint, size: CGSize) {
        let steps = 30
        let unitCenter = CGPoint(x: center.x / size.width, y: center.y / size.height)
        var endPoints: [NSValue] = []
        var locations: [[NSNumber]] = []
        var ringEndPoints: [NSValue] = []
        var ringLocations: [[NSNumber]] = []
        var ringOpacity: [NSNumber] = []
        for i in 0 ... steps {
            let linear = Double(i) / Double(steps)
            let progress = 1.0 - pow(1.0 - linear, 2.0)
            let radius = max(QrStudioReveal.radius(progress: progress, center: center, size: size), 0.01)
            endPoints.append(NSValue(cgPoint: CGPoint(x: unitCenter.x + radius / size.width, y: unitCenter.y + radius / size.height)))
            let soft = radius > 1.0 ? max(0.0, (radius - QrStudioReveal.feather) / radius) : 0.0
            locations.append([0.0, NSNumber(value: Double(soft)), 1.0])

            let ringRadius = max(radius - QrStudioReveal.feather * 0.5, 0.01)
            let outer = ringRadius + 12.0
            ringEndPoints.append(NSValue(cgPoint: CGPoint(x: unitCenter.x + outer / size.width, y: unitCenter.y + outer / size.height)))
            ringLocations.append([NSNumber(value: Double(max(0.0, (ringRadius - 12.0) / outer))), NSNumber(value: Double(ringRadius / outer)), 1.0])
            ringOpacity.append(NSNumber(value: sin(.pi * min(1.0, progress * 1.15))))
        }

        let frame = CGRect(origin: CGPoint(), size: size)

        let mask = CAGradientLayer()
        mask.type = .radial
        mask.frame = frame
        mask.colors = [UIColor.white.cgColor, UIColor.white.cgColor, UIColor.clear.cgColor]
        mask.startPoint = unitCenter
        mask.endPoint = endPoints[steps].cgPointValue
        mask.locations = locations[steps]
        view.layer.mask = mask

        let ring = CAGradientLayer()
        ring.type = .radial
        ring.frame = frame
        ring.colors = [UIColor.clear.cgColor, UIColor(white: 1.0, alpha: 0.5).cgColor, UIColor.clear.cgColor]
        ring.startPoint = unitCenter
        ring.endPoint = ringEndPoints[steps].cgPointValue
        ring.locations = ringLocations[steps]
        ring.opacity = 0.0
        ring.compositingFilter = "plusL"
        self.layer.insertSublayer(ring, above: view.layer)

        func makeAnimation(_ keyPath: String, _ values: [Any]) -> CAKeyframeAnimation {
            let animation = CAKeyframeAnimation(keyPath: keyPath)
            animation.values = values
            animation.duration = QrStudioReveal.duration
            animation.calculationMode = .linear
            return animation
        }

        self.activeReveals += 1
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self, weak view, weak ring] in
            view?.layer.mask = nil
            ring?.removeFromSuperlayer()
            guard let self else {
                return
            }
            self.activeReveals -= 1
            self.revealCompleted(id: id)
        }
        mask.add(makeAnimation("endPoint", endPoints), forKey: "reveal")
        mask.add(makeAnimation("locations", locations), forKey: "revealLocations")
        ring.add(makeAnimation("endPoint", ringEndPoints), forKey: "reveal")
        ring.add(makeAnimation("locations", ringLocations), forKey: "revealLocations")
        ring.add(makeAnimation("opacity", ringOpacity), forKey: "revealOpacity")
        CATransaction.commit()
    }
}
