import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction

public enum ChatInputContextPanelPlacement {
    case overPanels
    case overTextInput
}

open class ChatInputContextPanelNode: ASDisplayNode {
    public let context: AccountContext
    open var interfaceInteraction: ChatPanelInterfaceInteraction?
    open var placement: ChatInputContextPanelPlacement = .overPanels
    open var theme: PresentationTheme
    open var strings: PresentationStrings
    open var fontSize: PresentationFontSize
    /// The part of `updateLayout`'s `bottomInset` that hides what is under it: the keyboard or the chat's own input
    /// (emoji, stickers), else the home indicator's strip. The rest is the input panel and its margin, which the panel's
    /// content shows through. Set by the chat before each `updateLayout`.
    public var coveredBottomInset: CGFloat = 0.0
    
    public init(context: AccountContext, theme: PresentationTheme, strings: PresentationStrings, fontSize: PresentationFontSize, chatPresentationContext: ChatPresentationContext) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.fontSize = fontSize
        
        super.init()
    }
    
    open func updateLayout(size: CGSize, leftInset: CGFloat, rightInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition, interfaceState: ChatPresentationInterfaceState) {
    }
    
    open func animateOut(completion: @escaping () -> Void) {
        completion()
    }
    
    open var topItemFrame: CGRect? {
        return nil
    }
}
