import Foundation
import UIKit
import Display
import NewsFeedSupport

/// A new-posts block's glow, which the list draws over all of the block's rows (Feed3 FeedRow.swift `FreshBlock`;
/// spec §4.2): the card's ring blurred inside it and its thin contour, seen through a soft spot that drifts along the
/// card's top-left corner and breathes. The rows draw the block's fill. Everything runs on the reveal's clock, so a glow
/// placed later (scrolled back in, or its block changed) is in step with the fill under it.
public final class NewsFreshGlowView: UIView {
    private let glowContainer = SimpleLayer()
    private let glowInnerContainer = SimpleLayer()
    private let glowInnerMask = CAShapeLayer()
    private let glowBlurLayer = CAShapeLayer()
    private let glowStrokeLayer = CAShapeLayer()
    private let glowMask = CAGradientLayer()
    private var playedRevealTime: Double?
    private var playedDrift: (revealTime: Double, start: CGPoint, end: CGPoint)?
    /// The shapes as last drawn, in this view's coordinates. The list updates its glows on every scroll frame, which
    /// moves nothing here; redrawing would blur the ring again each time.
    private var drawn: (size: CGSize, card: CGRect, accentColor: UIColor)?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.layer.opacity = 0.0

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

    /// `layout` is the one the parent placed this view by (`NewsFreshGlowBlock.layout`).
    public func update(layout: NewsFreshGlowLayout, revealTime: Double, accentColor: UIColor) {
        let size = layout.frame.size
        let isDrawn = self.drawn.map { drawn in
            return drawn.size == size && drawn.card == layout.card && drawn.accentColor.isEqual(accentColor)
        } ?? false
        if !isDrawn {
            self.drawn = (size, layout.card, accentColor)
            let bounds = CGRect(origin: CGPoint(), size: size)
            let path = UIBezierPath(roundedRect: layout.card, cornerRadius: NewsRefreshMetrics.cardCorner).cgPath

            CATransaction.begin()
            CATransaction.setDisableActions(true)
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
            CATransaction.commit()
        }

        if self.playedRevealTime != revealTime {
            self.playedRevealTime = revealTime
            self.playEnvelope(revealTime: revealTime)
        }
        if let playedDrift = self.playedDrift, playedDrift.revealTime == revealTime, playedDrift.start == layout.driftStart, playedDrift.end == layout.driftEnd {
            return
        }
        self.playedDrift = (revealTime, layout.driftStart, layout.driftEnd)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.glowMask.position = layout.driftStart
        CATransaction.commit()
        self.playDrift(revealTime: revealTime, start: layout.driftStart, end: layout.driftEnd)
    }

    /// The block's alpha (`NewsFreshBlock.alpha`), from the reveal: begun then, it plays from wherever it is now.
    private func playEnvelope(revealTime: Double) {
        let duration = NewsFreshBlock.duration
        let steps = Int(duration * 30.0)
        var values: [NSNumber] = []
        for i in 0 ... steps {
            values.append(NewsFreshBlock.alpha(at: duration * Double(i) / Double(steps)) as NSNumber)
        }
        let alpha = CAKeyframeAnimation(keyPath: "opacity")
        alpha.values = values
        alpha.duration = duration
        alpha.calculationMode = .linear
        alpha.beginTime = revealTime
        alpha.fillMode = .forwards
        alpha.isRemovedOnCompletion = false
        self.layer.add(alpha, forKey: "newsFreshAlpha")
    }

    /// From the left edge to the top and back, every 2.8 s, from the reveal: a drift whose ends moved goes on in phase.
    private func playDrift(revealTime: Double, start: CGPoint, end: CGPoint) {
        let drift = CABasicAnimation(keyPath: "position")
        drift.fromValue = NSValue(cgPoint: start)
        drift.toValue = NSValue(cgPoint: end)
        drift.duration = 2.8
        drift.autoreverses = true
        drift.repeatCount = .infinity
        drift.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        drift.beginTime = revealTime
        self.glowMask.add(drift, forKey: "newsGlowDrift")
        let breathe = CABasicAnimation(keyPath: "opacity")
        breathe.fromValue = 0.78 as NSNumber
        breathe.toValue = 1.0 as NSNumber
        breathe.duration = 2.8
        breathe.autoreverses = true
        breathe.repeatCount = .infinity
        breathe.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        breathe.beginTime = revealTime
        self.glowContainer.add(breathe, forKey: "newsGlowBreathe")
    }
}
