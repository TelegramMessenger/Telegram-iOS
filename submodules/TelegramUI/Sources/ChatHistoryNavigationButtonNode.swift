import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let badgeFont = Font.regular(13.0)

enum ChatHistoryNavigationButtonType {
    case down
    case mentions
    case reactions
}

class ChatHistoryNavigationButtonNode: ContextControllerSourceNode {
    let containerNode: ContextExtractedContentContainingNode
    private let buttonNode: HighlightTrackingButtonNode
    private let backgroundNode: NavigationBackgroundNode
    private let imageNode: ASImageNode
    private let badgeBackgroundNode: ASImageNode
    private let badgeTextNode: ASTextNode
    
    var tapped: (() -> Void)? {
        didSet {
            if (oldValue != nil) != (self.tapped != nil) {
                if self.tapped != nil {
                    self.buttonNode.addTarget(self, action: #selector(self.onTap), forControlEvents: .touchUpInside)
                } else {
                    self.buttonNode.removeTarget(self, action: #selector(self.onTap), forControlEvents: .touchUpInside)
                }
            }
        }
    }
    
    var badge: String = "" {
        didSet {
            if self.badge != oldValue {
                self.layoutBadge()
            }
        }
    }
    
    private var theme: PresentationTheme
    private let type: ChatHistoryNavigationButtonType
    
    init(theme: PresentationTheme, type: ChatHistoryNavigationButtonType) {
        self.theme = theme
        self.type = type
        
        self.containerNode = ContextExtractedContentContainingNode()
        self.buttonNode = HighlightTrackingButtonNode()

        self.backgroundNode = NavigationBackgroundNode(color: theme.chat.inputPanel.panelBackgroundColor)
        
        self.imageNode = ASImageNode()
        self.imageNode.displayWithoutProcessing = true
        switch type {
            case .down:
                self.imageNode.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(theme)
            case .mentions:
                self.imageNode.image = PresentationResourcesChat.chatHistoryMentionsButtonImage(theme)
            case .reactions:
                self.imageNode.image = PresentationResourcesChat.chatHistoryReactionsButtonImage(theme)
        }
        self.imageNode.isLayerBacked = true
        
        self.badgeBackgroundNode = ASImageNode()
        self.badgeBackgroundNode.isLayerBacked = true
        self.badgeBackgroundNode.displayWithoutProcessing = true
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.image = PresentationResourcesChat.chatHistoryNavigationButtonBadgeImage(theme)
        
        self.badgeTextNode = ASTextNode()
        self.badgeTextNode.maximumNumberOfLines = 1
        self.badgeTextNode.isUserInteractionEnabled = false
        self.badgeTextNode.displaysAsynchronously = false
        
        super.init()
        
        self.targetNodeForActivationProgress = self.buttonNode
        
        self.addSubnode(self.containerNode)
        
        let size = CGSize(width: 38.0, height: 38.0)
        
        self.containerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
        self.containerNode.contentRect = CGRect(origin: CGPoint(), size: size)
        
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        self.containerNode.contentNode.addSubnode(self.buttonNode)

        self.buttonNode.addSubnode(self.backgroundNode)
        self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: size.width / 2.0, transition: .immediate)

        self.buttonNode.addSubnode(self.imageNode)
        self.imageNode.frame = CGRect(origin: CGPoint(), size: size)
        
        self.buttonNode.addSubnode(self.badgeBackgroundNode)
        self.buttonNode.addSubnode(self.badgeTextNode)
        
        self.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme

            self.backgroundNode.updateColor(color: theme.chat.inputPanel.panelBackgroundColor, transition: .immediate)
            switch self.type {
                case .down:
                    self.imageNode.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(theme)
                case .mentions:
                    self.imageNode.image = PresentationResourcesChat.chatHistoryMentionsButtonImage(theme)
                case .reactions:
                    self.imageNode.image = PresentationResourcesChat.chatHistoryReactionsButtonImage(theme)
            }
            self.badgeBackgroundNode.image = PresentationResourcesChat.chatHistoryNavigationButtonBadgeImage(theme)
            
            if let string = self.badgeTextNode.attributedText?.string {
                self.badgeTextNode.attributedText = NSAttributedString(string: string, font: badgeFont, textColor: theme.chat.historyNavigation.badgeTextColor)
                self.badgeTextNode.redrawIfPossible()
            }
        }
    }
    
    @objc func onTap() {
        if let tapped = self.tapped {
            tapped()
        }
    }
    
    private func layoutBadge() {
        if !self.badge.isEmpty {
            self.badgeTextNode.attributedText = NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)
            self.badgeBackgroundNode.isHidden = false
            self.badgeTextNode.isHidden = false
            
            let badgeSize = self.badgeTextNode.measure(CGSize(width: 200.0, height: 100.0))
            let backgroundSize = CGSize(width: max(18.0, badgeSize.width + 10.0 + 1.0), height: 18.0)
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((38.0 - backgroundSize.width) / 2.0), y: -9.0), size: backgroundSize)
            self.badgeBackgroundNode.frame = backgroundFrame
            self.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: -8.0), size: badgeSize)
        } else {
            self.badgeBackgroundNode.isHidden = true
            self.badgeTextNode.isHidden = true
        }
    }
}
