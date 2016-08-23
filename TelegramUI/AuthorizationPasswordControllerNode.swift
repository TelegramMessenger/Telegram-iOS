import Foundation
import Display
import AsyncDisplayKit

class AuthorizationPasswordControllerNode: ASDisplayNode {
    let passwordNode: ASEditableTextNode
    
    override init() {
        self.passwordNode = ASEditableTextNode()
        
        super.init()
        
        self.passwordNode.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
        self.passwordNode.backgroundColor = UIColor.lightGray
        self.addSubnode(self.passwordNode)
    }

    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.passwordNode.frame = CGRect(origin: CGPoint(x: 4.0, y: navigationBarHeight + 4.0), size: CGSize(width: layout.size.width - 8.0, height: 32.0))
    }
}
