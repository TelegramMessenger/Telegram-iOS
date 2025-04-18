import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import SolidRoundedButtonNode

final class InviteContactsCountPanelNode: ASDisplayNode {
    private let theme: PresentationTheme
    private let strings: PresentationStrings
    
    private let separatorNode: ASDisplayNode
    private let button: SolidRoundedButtonNode
    
    private var validLayout: (CGFloat, CGFloat, CGFloat)?
    
    var count: Int = 0 {
        didSet {
            if self.count != oldValue && self.count > 0 {
                self.button.title = self.strings.Contacts_InviteContacts(Int32(self.count))
                
                if let (width, sideInset, bottomInset) = self.validLayout {
                    let _ = self.updateLayout(width: width, sideInset: sideInset, bottomInset: bottomInset, transition: .immediate)
                }
            }
        }
    }
    
    init(theme: PresentationTheme, strings: PresentationStrings, action: @escaping () -> Void) {
        self.theme = theme
        self.strings = strings

        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = theme.rootController.navigationBar.separatorColor
        
        self.button = SolidRoundedButtonNode(theme: SolidRoundedButtonTheme(theme: theme), height: 48.0, cornerRadius: 10.0)
        
        super.init()
        
        self.backgroundColor = theme.rootController.navigationBar.opaqueBackgroundColor
        
        self.addSubnode(self.button)
        self.addSubnode(self.separatorNode)
        
        self.button.pressed = {
            action()
        }
    }
    
    func updateLayout(width: CGFloat, sideInset: CGFloat, bottomInset: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = (width, sideInset, bottomInset)
        let topInset: CGFloat = 9.0
        var bottomInset = bottomInset
        bottomInset += topInset - (bottomInset.isZero ? 0.0 : 4.0)
        
        let buttonInset: CGFloat = 16.0 + sideInset
        let buttonWidth = width - buttonInset * 2.0
        let buttonHeight = self.button.updateLayout(width: buttonWidth, transition: transition)
        transition.updateFrame(node: self.button, frame: CGRect(x: buttonInset, y: topInset, width: buttonWidth, height: buttonHeight))
        
        transition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: width, height: UIScreenPixel)))
        
        return topInset + buttonHeight + bottomInset
    }
}
