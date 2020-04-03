import Foundation
import UIKit
import AsyncDisplayKit
import Display

final class IconButtonNode: HighlightTrackingButtonNode {
    private let iconNode: ASImageNode
    
    var icon: UIImage? {
        didSet {
            self.iconNode.image = self.icon
            
            self.setNeedsLayout()
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            self.alpha = self.isEnabled ? 1.0 : 0.4
        }
    }
    
    init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        super.init(pointerStyle: .circle)
        
        self.addSubnode(self.iconNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.09, curve: .spring)
                    transition.updateSublayerTransformScale(node: strongSelf, scale: 0.8)
                } else {
                    let transition: ContainedViewLayoutTransition = .animated(duration: 0.18, curve: .spring)
                    transition.updateSublayerTransformScale(node: strongSelf, scale: 1.0)
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        
        let size = self.bounds.size
        
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0), y: floor((size.height - image.size.height) / 2.0)), size: image.size)
        }
    }
}
