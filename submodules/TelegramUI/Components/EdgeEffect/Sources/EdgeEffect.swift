import Foundation
import UIKit
import Display
import ComponentFlow

public final class EdgeEffectView: UIView {
    public enum Edge {
        case top
        case bottom
    }

    private let contentView: UIView
    private let contentMaskView: UIImageView
    
    public override init(frame: CGRect) {
        self.contentView = UIView()
        self.contentMaskView = UIImageView()
        self.contentView.mask = self.contentMaskView
        
        super.init(frame: frame)
        
        self.addSubview(self.contentView)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(content: UIColor, alpha: CGFloat = 0.65, rect: CGRect, edge: Edge, edgeSize: CGFloat, transition: ComponentTransition) {
        self.contentView.backgroundColor = content
        
        switch edge {
        case .top:
            self.contentMaskView.transform = CGAffineTransformMakeScale(1.0, -1.0)
        case .bottom:
            self.contentMaskView.transform = .identity
        }
        
        transition.setFrame(view: self.contentView, frame: CGRect(origin: CGPoint(), size: rect.size))
        transition.setFrame(view: self.contentMaskView, frame: CGRect(origin: CGPoint(), size: rect.size))
        
        if self.contentMaskView.image?.size.height != edgeSize {
            let baseGradientAlpha: CGFloat = alpha
            let numSteps = 8
            let firstStep = 1
            let firstLocation = 0.0
            let colors: [UIColor] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return UIColor(white: 1.0, alpha: 1.0)
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    let value: CGFloat = bezierPoint(0.42, 0.0, 0.58, 1.0, step)
                    return UIColor(white: 1.0, alpha: baseGradientAlpha * value)
                }
            }
            let locations: [CGFloat] = (0 ..< numSteps).map { i in
                if i < firstStep {
                    return 0.0
                } else {
                    let step: CGFloat = CGFloat(i - firstStep) / CGFloat(numSteps - firstStep - 1)
                    return (firstLocation + (1.0 - firstLocation) * step)
                }
            }
                
            if edgeSize > 0.0 {
                self.contentMaskView.image = generateGradientImage(
                    size: CGSize(width: 8.0, height: edgeSize),
                    colors: colors,
                    locations: locations
                )?.stretchableImage(withLeftCapWidth: 0, topCapHeight: Int(edgeSize))
            } else {
                self.contentMaskView.image = nil
            }
        }
    }
}
