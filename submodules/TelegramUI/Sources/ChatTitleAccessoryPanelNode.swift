import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ChatPresentationInterfaceState
import AccountContext

class ChatTitleAccessoryPanelNode: ASDisplayNode {
    typealias LayoutResult = ChatControllerCustomNavigationPanelNode.LayoutResult

    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        preconditionFailure()
    }
}
