import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ChatPresentationInterfaceState

enum ChatInputContextPanelPlacement {
    case overPanels
    case overTextInput
}

class ChatInputContextPanelNode: ASDisplayNode {
    let context: AccountContext
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    var placement: ChatInputContextPanelPlacement = .overPanels
    var theme: PresentationTheme
    var fontSize: PresentationFontSize
    
    init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize) {
        self.context = context
        self.theme = theme
        self.fontSize = fontSize
        
        super.init()
    }
    
    func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
    }
    
    func animateOut(completion: @escaping () -> Void) {
        completion()
    }
    
    var topItemFrame: CGRect? {
        return nil
    }
}
