import Foundation
import UIKit
import Display
import AsyncDisplayKit

class ChatTitleAccessoryPanelNode: ASDisplayNode {
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> CGFloat {
        return 0.0
    }
}
