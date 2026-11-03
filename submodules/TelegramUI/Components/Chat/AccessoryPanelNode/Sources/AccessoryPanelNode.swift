import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState

open class AccessoryPanelNode: ASDisplayNode {
    open var originalFrameBeforeDismissed: CGRect?
    open var dismiss: (() -> Void)?
    open var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    open func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
    }
    
    open func updateState(size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
    }
    
    open func animateIn() {
    }
    
    open func animateOut() {
    }
}
