import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData

private let badgeFont = Font.regular(13.0)

enum ChatHistoryNavigationButtonType {
    case down
    case mentions
}

class ChatHistoryNavigationButtonNode: ASControlNode {
    private let imageNode: ASImageNode
    private let badgeBackgroundNode: ASImageNode
    private let badgeTextNode: ASTextNode
    
    var tapped: (() -> Void)? {
        didSet {
            if (oldValue != nil) != (self.tapped != nil) {
                if self.tapped != nil {
                    self.addTarget(self, action: #selector(onTap), forControlEvents: .touchUpInside)
                } else {
                    self.removeTarget(self, action: #selector(onTap), forControlEvents: .touchUpInside)
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
        
        self.imageNode = ASImageNode()
        self.imageNode.displayWithoutProcessing = true
        switch type {
            case .down:
                self.imageNode.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(theme)
            case .mentions:
                self.imageNode.image = PresentationResourcesChat.chatHistoryMentionsButtonImage(theme)
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
        
        self.addSubnode(self.imageNode)
        self.imageNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
        
        self.addSubnode(self.badgeBackgroundNode)
        self.addSubnode(self.badgeTextNode)
        
        self.frame = CGRect(origin: CGPoint(), size: CGSize(width: 38.0, height: 38.0))
    }
    
    func updateTheme(theme: PresentationTheme) {
        if self.theme !== theme {
            self.theme = theme
            
            switch self.type {
                case .down:
                    self.imageNode.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(theme)
                case .mentions:
                    self.imageNode.image = PresentationResourcesChat.chatHistoryMentionsButtonImage(theme)
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
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((38.0 - backgroundSize.width) / 2.0), y: -6.0), size: backgroundSize)
            self.badgeBackgroundNode.frame = backgroundFrame
            self.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: -5.0), size: badgeSize)
        } else {
            self.badgeBackgroundNode.isHidden = true
            self.badgeTextNode.isHidden = true
        }
    }
}
