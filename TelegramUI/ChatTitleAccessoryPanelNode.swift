import Foundation
import Display
import AsyncDisplayKit

class ChatTitleAccessoryPanelNode: ASDisplayNode {
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        return 0.0
    }
}
