import Foundation
import UIKit
import AsyncDisplayKit
import Display

public final class PeerOnlineMarkerNode: ASDisplayNode {
    private let iconNode: ASImageNode
    
    override public init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.isHidden = true
    
        super.init()
        
        self.isLayerBacked = true
        
        self.addSubnode(self.iconNode)
    }
    
    public func setImage(_ image: UIImage?) {
        self.iconNode.image = image
    }
    
    public func asyncLayout() -> (Bool) -> (CGSize, (Bool) -> Void) {
        return { [weak self] online in
            return (CGSize(width: 14.0, height: 14.0), { animated in
                if let strongSelf = self {
                    strongSelf.iconNode.frame = CGRect(x: 0.0, y: 0.0, width: 14.0, height: 14.0)

                    if animated {
                        let initialScale: CGFloat = strongSelf.iconNode.isHidden ? 0.0 : CGFloat((strongSelf.iconNode.value(forKeyPath: "layer.presentationLayer.transform.scale.x") as? NSNumber)?.floatValue ?? 1.0)
                        let targetScale: CGFloat = online ? 1.0 : 0.0
                        strongSelf.iconNode.isHidden = false
                        strongSelf.iconNode.layer.animateScale(from: initialScale, to: targetScale, duration: 0.2, removeOnCompletion: false, completion: { [weak self] finished in
                            if let strongSelf = self, finished {
                                strongSelf.iconNode.isHidden = !online
                            }
                        })
                    } else {
                        strongSelf.iconNode.isHidden = !online
                    }
                }
            })
        }
    }
}
