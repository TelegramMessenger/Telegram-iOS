import Foundation
import Display
import AsyncDisplayKit

class ChatInputNode: ASDisplayNode {
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        return 0.0
    }
}
