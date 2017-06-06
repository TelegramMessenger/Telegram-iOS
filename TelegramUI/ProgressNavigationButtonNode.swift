import Foundation
import AsyncDisplayKit
import Display

final class ProgressNavigationButtonNode: ASDisplayNode {
    private var indicatorNode: ASImageNode
    
    init(theme: PresentationTheme = defaultPresentationTheme) {
        self.indicatorNode = ASImageNode()
        self.indicatorNode.isLayerBacked = true
        self.indicatorNode.displayWithoutProcessing = true
        self.indicatorNode.displaysAsynchronously = false
        
        self.indicatorNode.image = PresentationResourcesRootController.navigationIndefiniteActivityImage(theme)
        
        super.init()
        
        self.isLayerBacked = true
        
        self.addSubnode(self.indicatorNode)
    }
    
    override func willEnterHierarchy() {
        super.willEnterHierarchy()
        
        let basicAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        basicAnimation.duration = 0.5
        basicAnimation.fromValue = NSNumber(value: Float(0.0))
        basicAnimation.toValue = NSNumber(value: Float.pi * 2.0)
        basicAnimation.repeatCount = Float.infinity
        basicAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        self.indicatorNode.layer.add(basicAnimation, forKey: "progressRotation")
    }
    
    override func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        return CGSize(width: 26.0, height: 22.0)
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        let indicatorSize = CGSize(width: 22.0, height: 22.0)
        self.indicatorNode.frame = CGRect(origin: CGPoint(x: floor((size.width - indicatorSize.width) / 2.0), y: floor((size.height - indicatorSize.height) / 2.0)), size: indicatorSize)
    }
}
