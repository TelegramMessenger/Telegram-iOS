import Foundation
import AsyncDisplayKit
import Display

class SecretMediaPreviewControllerNode: ASDisplayNode {
    var containerLayout: (CGFloat, ContainerViewLayout)?
    var backgroundNode: ASDisplayNode
    
    var dismiss: (() -> Void)?
    
    private var itemNode: GalleryItemNode?
    private var itemNodeActivated = false
    
    override init() {
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.backgroundColor = UIColor.black
        
        super.init()
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.addSubnode(self.backgroundNode)
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.containerLayout = (navigationBarHeight, layout)
        
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: layout.size.height)))
        if let itemNode = self.itemNode {
            transition.updateFrame(node: itemNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: layout.size.height)))
            itemNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
            if !self.itemNodeActivated {
                self.itemNodeActivated = true
                itemNode.centralityUpdated(isCentral: true)
            }
        }
    }
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.dismiss?()
        }
    }
    
    func setItemNode(_ itemNode: GalleryItemNode?) {
        if let itemNode = self.itemNode {
            itemNode.removeFromSupernode()
            self.itemNodeActivated = false
        }
        
        self.itemNode = itemNode
        
        if let itemNode = self.itemNode {
            self.addSubnode(itemNode)
            
            if let (_, layout) = self.containerLayout {
                itemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: layout.size.height))
                itemNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: .immediate)
                if !self.itemNodeActivated {
                    self.itemNodeActivated = true
                    itemNode.centralityUpdated(isCentral: true)
                }
            }
        }
    }
}
