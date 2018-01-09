import Foundation
import AsyncDisplayKit
import Display
import TelegramCore

enum ChatInputContextPanelPlacement {
    case overPanels
    case overTextInput
}

class ChatInputContextPanelNode: ASDisplayNode {
    let account: Account
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    var placement: ChatInputContextPanelPlacement = .overPanels
    
    init(account: Account, theme: PresentationTheme, strings: PresentationStrings) {
        self.account = account
        
        super.init()
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
    }
    
    func animateOut(completion: @escaping () -> Void) {
        completion()
    }
}
