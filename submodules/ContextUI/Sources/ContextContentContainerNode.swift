import Foundation
import AsyncDisplayKit
import Display

final class ContextContentContainerNode: ASDisplayNode {
    var contentNode: ContextContentNode?
    
    override init() {
        super.init()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
    }
}
