import Foundation
import AsyncDisplayKit
import Display

private let indicatorImage = generateImage(CGSize(width: 22.0, height: 22.0), rotatedContext: { size, context in
    context.clear(CGRect(origin: CGPoint(), size: size))
    context.setFillColor(UIColor(0x007ee5).cgColor)
    let _ = try? drawSvgPath(context, path: "M11,22 C17.0751322,22 22,17.0751322 22,11 C22,4.92486775 17.0751322,0 11,0 C4.92486775,0 0,4.92486775 0,11 C0,12.4564221 0.28362493,13.8747731 0.827833595,15.1935223 C1.00609922,15.6255031 1.50080164,15.8311798 1.93278238,15.6529142 C2.36476311,15.4746485 2.57043984,14.9799461 2.39217421,14.5479654 C1.93209084,13.4330721 1.69230769,12.233965 1.69230769,11 C1.69230769,5.85950348 5.85950348,1.69230769 11,1.69230769 C16.1404965,1.69230769 20.3076923,5.85950348 20.3076923,11 C20.3076923,16.1404965 16.1404965,20.3076923 11,20.3076923 C10.5326821,20.3076923 10.1538462,20.6865283 10.1538462,21.1538462 C10.1538462,21.621164 10.5326821,22 11,22 Z ")
    /*
     
     
     <svg width="22px" height="22px" viewBox="0 0 22 22" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
     <!-- Generator: Sketch 42 (36781) - http://www.bohemiancoding.com/sketch -->
     <desc>Created with Sketch.</desc>
     <defs></defs>
     <path d="M11,22 C17.0751322,22 22,17.0751322 22,11 C22,4.92486775 17.0751322,0 11,0 C4.92486775,0 0,4.92486775 0,11 C0,12.4564221 0.28362493,13.8747731 0.827833595,15.1935223 C1.00609922,15.6255031 1.50080164,15.8311798 1.93278238,15.6529142 C2.36476311,15.4746485 2.57043984,14.9799461 2.39217421,14.5479654 C1.93209084,13.4330721 1.69230769,12.233965 1.69230769,11 C1.69230769,5.85950348 5.85950348,1.69230769 11,1.69230769 C16.1404965,1.69230769 20.3076923,5.85950348 20.3076923,11 C20.3076923,16.1404965 16.1404965,20.3076923 11,20.3076923 C10.5326821,20.3076923 10.1538462,20.6865283 10.1538462,21.1538462 C10.1538462,21.621164 10.5326821,22 11,22 Z" id="Oval" stroke="none" fill="#159BEC" fill-rule="nonzero"></path>
     </svg>
     */
    
    
})

final class ProgressNavigationButtonNode: ASDisplayNode {
    private var indicatorNode: ASImageNode
    
    override init() {
        self.indicatorNode = ASImageNode()
        self.indicatorNode.isLayerBacked = true
        self.indicatorNode.displayWithoutProcessing = true
        self.indicatorNode.displaysAsynchronously = false
        self.indicatorNode.image = indicatorImage
        
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
        basicAnimation.toValue = NSNumber(value: Float(M_PI * 2.0))
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
