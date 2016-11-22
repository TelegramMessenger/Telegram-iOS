import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

class ChatInputContextPanelNode: ASDisplayNode {
    let account: Account
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    init(account: Account) {
        self.account = account
        
        super.init()
    }
    
    func updateLayout(size: CGSize, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
    }
    
    func animateOut(completion: @escaping () -> Void) {
        completion()
    }
}
