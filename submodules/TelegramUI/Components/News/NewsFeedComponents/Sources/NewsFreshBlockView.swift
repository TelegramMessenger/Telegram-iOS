import Foundation
import UIKit
import Display
import NewsFeedSupport

/// A fresh row's slice of the new-posts card: the accent fill (FeedRow.swift:230-288; spec §4.2). The glow runs through
/// all of the block's rows, so the list draws it (`NewsFreshGlowView`). Its alpha follows `NewsFreshBlock.alpha` from
/// the reveal, picked up wherever the row joins the timeline.
final class NewsFreshBlockView: UIView {
    private let fillLayer = CAShapeLayer()
    private var playedRevealTime: Double?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = false
        self.clipsToBounds = true
        self.layer.addSublayer(self.fillLayer)
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
        CATransaction.commit()

        guard self.playedRevealTime != segment.revealTime else {
            return
        }
        self.playedRevealTime = segment.revealTime
        self.play(segment: segment)
    }

    private func play(segment: NewsFreshSegment) {
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
    }
}
