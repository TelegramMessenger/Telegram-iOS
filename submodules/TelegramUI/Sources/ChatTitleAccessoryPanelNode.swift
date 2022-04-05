import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ChatPresentationInterfaceState

class ChatTitleAccessoryPanelNode: ASDisplayNode {
    struct LayoutResult {
        var backgroundHeight: CGFloat
        var insetHeight: CGFloat
    }

    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> LayoutResult {
        preconditionFailure()
    }
}
