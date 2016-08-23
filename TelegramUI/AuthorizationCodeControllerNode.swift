import Foundation
import Display
import AsyncDisplayKit

class AuthorizationCodeControllerNode: ASDisplayNode {
    let codeNode: ASEditableTextNode
    
    override init() {
        self.codeNode = ASEditableTextNode()
        
        super.init()
        
        self.codeNode.typingAttributes = [NSFontAttributeName: Font.regular(17.0)]
        self.codeNode.backgroundColor = UIColor.lightGray
        self.addSubnode(self.codeNode)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.codeNode.frame = CGRect(origin: CGPoint(x: 4.0, y: navigationBarHeight + 4.0), size: CGSize(width: layout.size.width - 8.0, height: 32.0))
    }
}
