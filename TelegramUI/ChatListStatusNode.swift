import Foundation
import AsyncDisplayKit
import Display

enum ChatListStatusNodeState {
    case none
    case clock
    case delivered
    case read
    case progress(CGFloat)
}

final class ChatListStatusNode: ASDisplayNode {
    private let iconNode: ASImageNode
    private let checksNode: ASImageNode
    private let clockNode: ASImageNode
    private let progressNode: RadialStatusNode
    
    override init() {
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displaysAsynchronously = false
        self.iconNode.displayWithoutProcessing = true
        
        self.checksNode = ASImageNode()
        self.clockNode = ASImageNode()
        self.progressNode = RadialStatusNode(backgroundNodeColor: .clear)
        
        super.init()
        
        self.addSubnode(self.iconNode)
        self.addSubnode(self.checksNode)
        self.addSubnode(self.clockNode)
        self.addSubnode(self.progressNode)
    }
    
    func asyncLayout() -> (CGSize) -> (CGSize, (Bool) -> Void) {
        return { [weak self] constrainedSize in
            return (CGSize(width: 14.0, height: 14.0), { animated in
                if let strongSelf = self {
                    strongSelf.iconNode.frame = CGRect(x: 0.0, y: 0.0, width: 14.0, height: 14.0)
                    
                    if animated {
                        let initialScale: CGFloat = CGFloat((strongSelf.iconNode.value(forKeyPath: "layer.presentationLayer.transform.scale.x") as? NSNumber)?.floatValue ?? 1.0)
                        let targetScale: CGFloat = 1.0
                        strongSelf.iconNode.isHidden = false
                        strongSelf.iconNode.layer.animateScale(from: initialScale, to: targetScale, duration: 0.2, removeOnCompletion: false, completion: { [weak self] finished in
                            if let strongSelf = self, finished {
                                
                            }
                        })
                    } else {
                        
                    }
                }
            })
        }
    }
}
