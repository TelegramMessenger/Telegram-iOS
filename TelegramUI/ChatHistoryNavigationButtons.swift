import Foundation
import Display
import AsyncDisplayKit

final class ChatHistoryNavigationButtons: ASDisplayNode {
    private var theme: PresentationTheme
    
    private let mentionsButton: ChatHistoryNavigationButtonNode
    private let downButton: ChatHistoryNavigationButtonNode
    
    var downPressed: (() -> Void)? {
        didSet {
            self.downButton.tapped = self.downPressed
        }
    }
    
    var mentionsPressed: (() -> Void)? {
        didSet {
            self.mentionsButton.tapped = self.mentionsPressed
        }
    }
    
    var displayDownButton: Bool = false {
        didSet {
            if oldValue != self.displayDownButton {
                let _ = self.updateLayout(transition: .animated(duration: 0.3, curve: .spring))
            }
        }
    }
    
    var unreadCount: Int32 = 0 {
        didSet {
            if self.unreadCount != 0 {
                self.downButton.badge = "\(self.unreadCount)"
            } else {
                self.downButton.badge = ""
            }
        }
    }
    
    var mentionCount: Int32 = 0 {
        didSet {
            if self.mentionCount != 0 {
                self.mentionsButton.badge = "\(self.mentionCount)"
            } else {
                self.mentionsButton.badge = ""
            }
            
            if (oldValue != 0) != (self.mentionCount != 0) {
                let _ = self.updateLayout(transition: .animated(duration: 0.3, curve: .spring))
            }
        }
    }
    
    init(theme: PresentationTheme) {
        self.theme = theme
        
        self.mentionsButton = ChatHistoryNavigationButtonNode(theme: theme, type: .mentions)
        self.mentionsButton.alpha = 0.0
        self.downButton = ChatHistoryNavigationButtonNode(theme: theme, type: .down)
        self.downButton.alpha = 0.0
        
        super.init()
        
        self.addSubnode(self.mentionsButton)
        self.addSubnode(self.downButton)
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            self.mentionsButton.updateTheme(theme: theme)
            self.downButton.updateTheme(theme: theme)
        }
    }
    
    func updateLayout(transition: ContainedViewLayoutTransition) -> CGSize {
        let buttonSize = CGSize(width: 38.0, height: 38.0)
        let completeSize = CGSize(width: buttonSize.width, height: buttonSize.height * 2.0 + 6.0)
        var mentionsOffset: CGFloat = 0.0
        
        if self.displayDownButton {
            mentionsOffset = buttonSize.height + 8.0
            transition.updateAlpha(node: self.downButton, alpha: 1.0)
            transition.updateTransformScale(node: self.downButton, scale: 1.0)
        } else {
            transition.updateAlpha(node: self.downButton, alpha: 0.0)
            transition.updateTransformScale(node: self.downButton, scale: 0.2)
        }
        
        if self.mentionCount != 0 {
            transition.updateAlpha(node: self.mentionsButton, alpha: 1.0)
            transition.updateTransformScale(node: self.mentionsButton, scale: 1.0)
        } else {
            transition.updateAlpha(node: self.mentionsButton, alpha: 0.0)
            transition.updateTransformScale(node: self.mentionsButton, scale: 0.2)
        }
        
        transition.updatePosition(node: self.downButton, position: CGRect(origin: CGPoint(x: 0.0, y: completeSize.height - buttonSize.height), size: buttonSize).center)
        
        transition.updatePosition(node: self.mentionsButton, position: CGRect(origin: CGPoint(x: 0.0, y: completeSize.height - buttonSize.height - mentionsOffset), size: buttonSize).center)
        
        return completeSize
    }
}
