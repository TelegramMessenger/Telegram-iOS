import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData

enum ChatInputContextPanelPlacement {
    case overPanels
    case overTextInput
}

class ChatInputContextPanelNode: ASDisplayNode {
    let context: AccountContextImpl
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    var placement: ChatInputContextPanelPlacement = .overPanels
    var theme: PresentationTheme
    
    init(context: AccountContextImpl, theme: PresentationTheme, strings: PresentationStrings) {
        self.context = context
        self.theme = theme
        
        super.init()
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
    }
    
    func animateOut(completion: @escaping () -> Void) {
        completion()
    }
}
