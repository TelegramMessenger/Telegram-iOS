import Foundation
import UIKit
import AsyncDisplayKit

private struct CachedMaskParams: Equatable {
    let size: CGSize
    let relativeArrowPosition: CGFloat
    let arrowOnBottom: Bool
}

private final class ContextMenuContainerMaskView: UIView {
    override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }
}

public final class ContextMenuContainerNode: ASDisplayNode {
    private var cachedMaskParams: CachedMaskParams?
    private let maskView = ContextMenuContainerMaskView()
    
    public var relativeArrowPosition: (CGFloat, Bool)?
    
    //private let effectView: UIVisualEffectView
    
    override public init() {
        //self.effectView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        
        super.init()
        
        self.backgroundColor = UIColor(rgb: 0x8c8e8e)
        //self.view.addSubview(self.effectView)
        //self.effectView.mask = self.maskView
        self.view.mask = self.maskView
    }
    
    override public func didLoad() {
        super.didLoad()
        
        self.layer.allowsGroupOpacity = true
    }
    
    override public func layout() {
        super.layout()
        
        self.updateLayout(transition: .immediate)
    }
    
    public func updateLayout(transition: ContainedViewLayoutTransition) {
        //self.effectView.frame = self.bounds
        
        let maskParams = CachedMaskParams(size: self.bounds.size, relativeArrowPosition: self.relativeArrowPosition?.0 ?? self.bounds.size.width / 2.0, arrowOnBottom: self.relativeArrowPosition?.1 ?? true)
        if self.cachedMaskParams != maskParams {
            let path = UIBezierPath()
            let cornerRadius: CGFloat = 10.0
            let verticalInset: CGFloat = 9.0
            let arrowWidth: CGFloat = 18.0
            let requestedArrowPosition = maskParams.relativeArrowPosition
            let arrowPosition = max(cornerRadius + arrowWidth / 2.0, min(maskParams.size.width - cornerRadius - arrowWidth / 2.0, requestedArrowPosition))
            let arrowOnBottom = maskParams.arrowOnBottom
            
            path.move(to: CGPoint(x: 0.0, y: verticalInset + cornerRadius))
            path.addArc(withCenter: CGPoint(x: cornerRadius, y: verticalInset + cornerRadius), radius: cornerRadius, startAngle: CGFloat.pi, endAngle: CGFloat(3.0 * CGFloat.pi / 2.0), clockwise: true)
            if !arrowOnBottom {
                path.addLine(to: CGPoint(x: arrowPosition - arrowWidth / 2.0, y: verticalInset))
                path.addLine(to: CGPoint(x: arrowPosition, y: 0.0))
                path.addLine(to: CGPoint(x: arrowPosition + arrowWidth / 2.0, y: verticalInset))
            }
            path.addLine(to: CGPoint(x: maskParams.size.width - cornerRadius, y: verticalInset))
            path.addArc(withCenter: CGPoint(x: maskParams.size.width - cornerRadius, y: verticalInset + cornerRadius), radius: cornerRadius, startAngle: CGFloat(3.0 * CGFloat.pi / 2.0), endAngle: 0.0, clockwise: true)
            path.addLine(to: CGPoint(x: maskParams.size.width, y: maskParams.size.height - cornerRadius - verticalInset))
            path.addArc(withCenter: CGPoint(x: maskParams.size.width - cornerRadius, y: maskParams.size.height - cornerRadius - verticalInset), radius: cornerRadius, startAngle: 0.0, endAngle: CGFloat(CGFloat.pi / 2.0), clockwise: true)
            if arrowOnBottom {
                path.addLine(to: CGPoint(x: arrowPosition + arrowWidth / 2.0, y: maskParams.size.height - verticalInset))
                path.addLine(to: CGPoint(x: arrowPosition, y: maskParams.size.height))
                path.addLine(to: CGPoint(x: arrowPosition - arrowWidth / 2.0, y: maskParams.size.height - verticalInset))
            }
            path.addLine(to: CGPoint(x: cornerRadius, y: maskParams.size.height - verticalInset))
            path.addArc(withCenter: CGPoint(x: cornerRadius, y: maskParams.size.height - cornerRadius - verticalInset), radius: cornerRadius, startAngle: CGFloat(CGFloat.pi / 2.0), endAngle: CGFloat.pi, clockwise: true)
            path.close()
            
            self.cachedMaskParams = maskParams
            if let layer = self.maskView.layer as? CAShapeLayer {
                if case let .animated(duration, curve) = transition, let previousPath = layer.path {
                    layer.animate(from: previousPath, to: path.cgPath, keyPath: "path", timingFunction: curve.timingFunction, duration: duration)
                }
                layer.path = path.cgPath
            }
        }
    }
}
