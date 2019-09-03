import Foundation
import AsyncDisplayKit
import Display

final class ContextContentContainerNode: ASDisplayNode {
    var contentNode: ContextContentNode?
    
    override init() {
        super.init()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition) {
        guard let contentNode = self.contentNode else {
            return
        }
        switch contentNode {
        case .extracted:
            break
        case let .controller(controller):
            controller.updateLayout(size: size, transition: transition)
        }
    }
}
