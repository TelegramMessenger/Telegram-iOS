import Foundation
import AsyncDisplayKit

enum ActivityIndicatorType: Equatable {
    case navigationAccent(PresentationTheme)
    case custom(UIColor, CGFloat)
    
    static func ==(lhs: ActivityIndicatorType, rhs: ActivityIndicatorType) -> Bool {
        switch lhs {
            case let .navigationAccent(lhsTheme):
                if case let .navigationAccent(rhsTheme) = rhs, lhsTheme === rhsTheme {
                    return true
                } else {
                    return false
                }
            case let .custom(lhsColor, lhsDiameter):
                if case let .custom(rhsColor, rhsDiameter) = rhs, lhsColor.isEqual(rhsColor), lhsDiameter == rhsDiameter {
                    return true
                } else {
                    return false
                }
        }
    }
}

enum ActivityIndicatorSpeed {
    case regular
    case slow
}

final class ActivityIndicator: ASDisplayNode {
    var type: ActivityIndicatorType {
        didSet {
            switch type {
                case let .navigationAccent(theme):
                    self.indicatorNode.image = PresentationResourcesRootController.navigationIndefiniteActivityImage(theme)
                case let .custom(color, diameter):
                    self.indicatorNode.image = generateIndefiniteActivityIndicatorImage(color: color, diameter: diameter)
            }
        }
    }
    
    private let speed: ActivityIndicatorSpeed
    
    private let indicatorNode: ASImageNode
    
    init(type: ActivityIndicatorType, speed: ActivityIndicatorSpeed = .regular) {
        self.type = type
        self.speed = speed
        
        self.indicatorNode = ASImageNode()
        self.indicatorNode.isLayerBacked = true
        self.indicatorNode.displayWithoutProcessing = true
        self.indicatorNode.displaysAsynchronously = false
        
        switch type {
            case let .navigationAccent(theme):
                self.indicatorNode.image = PresentationResourcesRootController.navigationIndefiniteActivityImage(theme)
            case let .custom(color, diameter):
                self.indicatorNode.image = generateIndefiniteActivityIndicatorImage(color: color, diameter: diameter)
        }
        
        super.init()
        
        self.isLayerBacked = true
        
        self.addSubnode(self.indicatorNode)
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        switch self.speed {
            case .regular:
                basicAnimation.duration = 0.5
            case .slow:
                basicAnimation.duration = 0.7
        }
        basicAnimation.fromValue = NSNumber(value: Float(0.0))
        basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
        basicAnimation.repeatCount = Float.infinity
        basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        self.indicatorNode.layer.add(basicAnimation, forKey: "progressRotation")
    }
    
    override func didExitHierarchy() {
        super.didExitHierarchy()
        
        self.indicatorNode.layer.removeAnimation(forKey: "progressRotation")
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        switch self.type {
            case .navigationAccent:
                return CGSize(width: 22.0, height: 22.0)
            case let .custom(_, diameter):
                return CGSize(width: diameter, height: diameter)
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let indicatorSize: CGSize
        switch self.type {
            case .navigationAccent:
                indicatorSize = CGSize(width: 22.0, height: 22.0)
            case let .custom(_, diameter):
                indicatorSize = CGSize(width: diameter, height: diameter)
        }
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: floor((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
    }
}
