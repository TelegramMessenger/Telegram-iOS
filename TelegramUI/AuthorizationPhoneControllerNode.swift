import Foundation
import Display
import AsyncDisplayKit

class AuthorizationPhoneControllerNode: ASDisplayNode {
    let phoneNode: ASEditableTextNode
    
    override init() {
        self.phoneNode = ASEditableTextNode()
        
        super.init()
        
        self.phoneNode.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
        self.phoneNode.backgroundColor = UIColor.lightGray
        self.addSubnode(self.phoneNode)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.phoneNode.frame = CGRect(origin: CGPoint(x: 4.0, y: navigationBarHeight + 4.0), size: CGSize(width: layout.size.width - 8.0, height: 32.0))
    }
}
