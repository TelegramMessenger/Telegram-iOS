import Foundation
import UIKit
import ComponentFlow
import Display
import HierarchyTrackingLayer

public final class ShimmeringMaskView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var containerWidth: CGFloat
        var offsetX: CGFloat
        var gradientWidth: CGFloat
    }

    public let contentView: UIView

    private let peakAlpha: CGFloat
    private let duration: Double

    private let hierarchyTrackingLayer: HierarchyTrackingLayer
    private let maskLayer: CAGradientLayer

    private var params: Params?

    public init(peakAlpha: CGFloat, duration: Double) {
        self.peakAlpha = peakAlpha
        self.duration = duration

        self.contentView = UIView()

        self.hierarchyTrackingLayer = HierarchyTrackingLayer()

        self.maskLayer = CAGradientLayer()
        self.maskLayer.startPoint = CGPoint(x: 0.0, y: 0.5)
        self.maskLayer.endPoint = CGPoint(x: 1.0, y: 0.5)
        self.maskLayer.colors = [
            UIColor(white: 1.0, alpha: 1.0).cgColor,
            UIColor(white: 1.0, alpha: self.peakAlpha).cgColor,
            UIColor(white: 1.0, alpha: 1.0).cgColor
        ]
        self.maskLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)

        super.init(frame: CGRect())

        self.addSubview(self.contentView)
        self.contentView.layer.mask = self.maskLayer

        self.layer.addSublayer(self.hierarchyTrackingLayer)
        self.hierarchyTrackingLayer.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.updateAnimations()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateAnimations() {
        guard let params = self.params else {
            return
        }
        if self.maskLayer.animation(forKey: "shimmer") != nil {
            return
        }
        let travelDelta = params.containerWidth + params.gradientWidth
        let animation = self.maskLayer.makeAnimation(
            from: 0.0 as NSNumber,
            to: travelDelta as NSNumber,
            keyPath: "position.x",
            timingFunction: CAMediaTimingFunctionName.easeOut.rawValue,
            duration: self.duration,
            delay: 0.0,
            mediaTimingFunction: nil,
            removeOnCompletion: true,
            additive: true
        )
        animation.repeatCount = Float.infinity
        self.maskLayer.add(animation, forKey: "shimmer")
    }

    public func update(
        size: CGSize,
        containerWidth: CGFloat,
        offsetX: CGFloat,
        gradientWidth: CGFloat,
        transition: ComponentTransition
    ) {
        let params = Params(
            size: size,
            containerWidth: containerWidth,
            offsetX: offsetX,
            gradientWidth: gradientWidth
        )
        if self.params == params {
            return
        }
        self.params = params

        transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: size))

        let travelDistance = containerWidth + gradientWidth
        let maskWidth = size.width + 2.0 * travelDistance

        let dipHalfFraction: CGFloat
        if maskWidth > 0.0 {
            dipHalfFraction = (gradientWidth * 0.5) / maskWidth
        } else {
            dipHalfFraction = 0.0
        }
        self.maskLayer.locations = [
            (0.5 - dipHalfFraction) as NSNumber,
            0.5 as NSNumber,
            (0.5 + dipHalfFraction) as NSNumber
        ]

        let maskBounds = CGRect(origin: CGPoint(), size: CGSize(width: maskWidth, height: size.height))
        let staticPositionX = -gradientWidth * 0.5 - offsetX
        let maskPosition = CGPoint(x: staticPositionX, y: size.height * 0.5)

        transition.setBounds(layer: self.maskLayer, bounds: maskBounds)
        transition.setPosition(layer: self.maskLayer, position: maskPosition)

        self.maskLayer.removeAnimation(forKey: "shimmer")
        self.updateAnimations()
    }
}
