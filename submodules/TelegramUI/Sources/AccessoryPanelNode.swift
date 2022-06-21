import Foundation
import UIKit
import AsyncDisplayKit
import TelegramPresentationData
import ChatPresentationInterfaceState

class AccessoryPanelNode: ASDisplayNode {
    var originalFrameBeforeDismissed: CGRect?
    var dismiss: (() -> Void)?
    var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
    }
    
    func updateState(size: CGSize, inset: CGFloat, interfaceState: ChatPresentationInterfaceState) {
    }
    
    func animateIn() {
    }
    
    func animateOut() {
    }
}
