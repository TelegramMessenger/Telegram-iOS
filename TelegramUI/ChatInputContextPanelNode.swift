import Foundation
import AsyncDisplayKit
import Display

class ChatInputContextPanelNode: ASDisplayNode {
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateFrames(transition: ContainedViewLayoutTransition) {
    }
    
    func animateIn() {
        
    }
    
    func animateOut(completion: @escaping () -> Void) {
        completion()
    }
}
