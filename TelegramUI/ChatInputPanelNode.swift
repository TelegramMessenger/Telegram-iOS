import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

class ChatInputPanelNode: ASDisplayNode {
    var account: Account?
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, maxHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        return 0.0
    }
    
    func minimalHeight(interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        return 0.0
    }
}
