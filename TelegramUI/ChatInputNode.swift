import Foundation
import Display
import AsyncDisplayKit

class ChatInputNode: ASDisplayNode {
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateLayout(width: CGFloat, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, standardInputHeight: CGFloat, inputHeight: CGFloat, maximumHeight: CGFloat, inputPanelHeight: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) -> (CGFloat, CGFloat) {
        return (0.0, 0.0)
    }
}
