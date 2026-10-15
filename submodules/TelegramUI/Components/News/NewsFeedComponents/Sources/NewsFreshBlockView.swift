import Foundation
import UIKit
import Display
import NewsFeedSupport

/// A fresh row's slice of the new-posts card: the accent fill, and on the first row the drifting glow
/// (FeedRow.swift:230-288; spec §4.2). Its alpha follows `NewsFreshBlock.alpha` from the reveal, picked up wherever
/// the row joins the timeline.
final class NewsFreshBlockView: UIView {
    private let fillLayer = CAShapeLayer()
    private let glowContainer = SimpleLayer()
    private let glowInnerContainer = SimpleLayer()
    private let glowInnerMask = CAShapeLayer()
    private let glowBlurLayer = CAShapeLayer()
    private let glowStrokeLayer = CAShapeLayer()
    private let glowMask = CAGradientLayer()
    private var playedRevealTime: Double?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.layer.addSublayer(self.fillLayer)

        self.glowBlurLayer.fillColor = UIColor.clear.cgColor
        self.glowBlurLayer.lineWidth = 8.0
        if let blur = CALayer.blur() {
            blur.setValue(7.0 as NSNumber, forKey: "inputRadius")
            self.glowBlurLayer.filters = [blur]
        }
        self.glowInnerContainer.mask = self.glowInnerMask
        self.glowInnerContainer.addSublayer(self.glowBlurLayer)
        self.glowStrokeLayer.fillColor = UIColor.clear.cgColor
        self.glowStrokeLayer.lineWidth = 1.2
        self.glowContainer.addSublayer(self.glowInnerContainer)
        self.glowContainer.addSublayer(self.glowStrokeLayer)
        self.glowMask.type = .radial
        self.glowMask.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.55).cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
        self.glowMask.locations = [0.0, 0.45, 1.0]
        self.glowMask.startPoint = CGPoint(x: 0.5, y: 0.5)
        self.glowMask.endPoint = CGPoint(x: 1.0, y: 1.0)
        self.glowMask.bounds = CGRect(x: 0.0, y: 0.0, width: 300.0, height: 300.0)
        self.glowContainer.mask = self.glowMask
        self.layer.addSublayer(self.glowContainer)
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }

    func update(size: CGSize, segment: NewsFreshSegment, accentColor: UIColor) {
        let bounds = CGRect(origin: CGPoint(), size: size)
        let slice = NewsFreshBlock.sliceRect(bounds: bounds, isFirst: segment.isFirst, isLast: segment.isLast)
        let path = UIBezierPath(roundedRect: slice, cornerRadius: NewsRefreshMetrics.cardCorner).cgPath

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.fillLayer.frame = bounds
        self.fillLayer.path = path
        self.fillLayer.fillColor = accentColor.withAlphaComponent(NewsFreshBlock.fillAlpha).cgColor

        self.glowContainer.isHidden = !segment.isFirst
        self.glowContainer.frame = bounds
        self.glowInnerContainer.frame = bounds
        self.glowInnerMask.frame = bounds
        self.glowInnerMask.path = path
        self.glowBlurLayer.frame = bounds
        self.glowBlurLayer.path = path
        self.glowBlurLayer.strokeColor = accentColor.withAlphaComponent(0.42).cgColor
        self.glowStrokeLayer.frame = bounds
        self.glowStrokeLayer.path = path
        self.glowStrokeLayer.strokeColor = accentColor.withAlphaComponent(0.5).cgColor
        let (start, end) = NewsFreshBlock.glowCenters(size: slice.size)
        let startPoint = CGPoint(x: slice.minX + start.x, y: slice.minY + start.y)
        let endPoint = CGPoint(x: slice.minX + end.x, y: slice.minY + end.y)
        self.glowMask.position = startPoint
        CATransaction.commit()

        guard self.playedRevealTime != segment.revealTime else {
            return
        }
        self.playedRevealTime = segment.revealTime
        self.play(segment: segment, glowFrom: startPoint, glowTo: endPoint)
    }

    private func play(segment: NewsFreshSegment, glowFrom: CGPoint, glowTo: CGPoint) {
        let now = CACurrentMediaTime()
        let t = now - segment.revealTime
        let remaining = NewsFreshBlock.duration - t
        self.layer.removeAnimation(forKey: "newsFreshAlpha")
        guard remaining > 0.0 else {
            self.layer.opacity = 0.0
            return
        }
        let steps = max(2, Int(remaining * 30.0))
        var values: [NSNumber] = []
        for i in 0 ... steps {
            values.append(NewsFreshBlock.alpha(at: t + remaining * Double(i) / Double(steps)) as NSNumber)
        }
        let alpha = CAKeyframeAnimation(keyPath: "opacity")
        alpha.values = values
        alpha.duration = remaining
        alpha.calculationMode = .linear
        self.layer.opacity = 0.0
        self.layer.add(alpha, forKey: "newsFreshAlpha")

        if !self.glowContainer.isHidden {
            let drift = CABasicAnimation(keyPath: "position")
            drift.fromValue = NSValue(cgPoint: glowFrom)
            drift.toValue = NSValue(cgPoint: glowTo)
            drift.duration = 2.8
            drift.autoreverses = true
            drift.repeatCount = .infinity
            drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.glowMask.add(drift, forKey: "newsGlowDrift")
            let breathe = CABasicAnimation(keyPath: "opacity")
            breathe.fromValue = 0.78 as NSNumber
            breathe.toValue = 1.0 as NSNumber
            breathe.duration = 2.8
            breathe.autoreverses = true
            breathe.repeatCount = .infinity
            breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            self.glowContainer.add(breathe, forKey: "newsGlowBreathe")
        }
    }
}
