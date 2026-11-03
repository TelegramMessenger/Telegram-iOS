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
    private var holders: [Int: UIView] = [:]
    private var fadingContents: [QrStudioBackgroundContent] = []
    private var topReveal: (id: Int, startedAt: Double)?

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

        for (_, holder) in self.holders {
            holder.frame = CGRect(origin: CGPoint(), size: size)
        }
        for content in self.stack.layers.map({ $0.item }) + self.fadingContents {
            content.frame = CGRect(origin: CGPoint(), size: size)
            content.update(size: size, revealCenter: revealCenter)
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

        if animated, let topReveal = self.topReveal, let top = self.stack.layers.last, top.id == topReveal.id, let holder = self.holders[top.id], QrStudioClock.now - topReveal.startedAt < QrStudioReveal.duration * 0.6 {
            self.crossfade(from: top.item, to: content, in: holder)
            return
        }

        let holder = UIView(frame: CGRect(origin: CGPoint(), size: size))
        holder.isUserInteractionEnabled = false
        holder.addSubview(content)
        self.addSubview(holder)
        let id = self.stack.push(content)
        self.holders[id] = holder

        if isFirst || !animated || size.width <= 0.0 || size.height <= 0.0 {
            self.topReveal = nil
            self.revealCompleted(id: id)
        } else {
            self.topReveal = (id, QrStudioClock.now)
            content.beginReveal(at: QrStudioClock.now)
            self.runReveal(on: holder, id: id, center: revealCenter, size: size)
        }
    }

    private func crossfade(from previous: QrStudioBackgroundContent, to content: QrStudioBackgroundContent, in holder: UIView) {
        holder.addSubview(content)
        self.stack.replaceTop(content)
        self.fadingContents.append(previous)
        content.alpha = 0.0
        UIView.animate(withDuration: 0.25, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            content.alpha = 1.0
        }, completion: { [weak self, weak previous] _ in
            guard let self, let previous else {
                return
            }
            self.fadingContents.removeAll(where: { $0 === previous })
            previous.setVisible(false)
            previous.removeFromSuperview()
        })
    }

    func tick(time: Double, pan: QrStudioPan, drift: QrStudioDrift, tilt: SIMD2<Double>) {
        for content in self.stack.layers.map({ $0.item }) + self.fadingContents {
            content.tick(time: time, pan: pan, drift: drift, tilt: tilt)
        }
    }

    func forEachContent(_ f: (QrStudioBackgroundContent) -> Void) {
        for layer in self.stack.layers {
            f(layer.item)
        }
    }

    func setVisible(_ isVisible: Bool) {
        self.isVisible = isVisible
        for content in self.stack.layers.map({ $0.item }) + self.fadingContents {
            content.setVisible(isVisible)
        }
    }

    private func revealCompleted(id: Int) {
        if self.topReveal?.id == id {
            self.topReveal = nil
        }
        let removedIds = self.stack.revealCompleted(id: id)
        for removedId in removedIds {
            guard let holder = self.holders.removeValue(forKey: removedId) else {
                continue
            }
            for case let content as QrStudioBackgroundContent in holder.subviews {
                content.setVisible(false)
                self.fadingContents.removeAll(where: { $0 === content })
            }
            holder.removeFromSuperview()
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
