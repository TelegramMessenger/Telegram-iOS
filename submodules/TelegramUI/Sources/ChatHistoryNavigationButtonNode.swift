import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import WallpaperBackgroundNode
import AnimatedCountLabelNode

private let badgeFont = Font.with(size: 13.0, traits: [.monospacedNumbers])

enum ChatHistoryNavigationButtonType {
    case down
    case mentions
    case reactions
}

class ChatHistoryNavigationButtonNode: ContextControllerSourceNode {
    let containerNode: ContextExtractedContentContainingNode
    private let buttonNode: HighlightTrackingButtonNode
    private let backgroundNode: NavigationBackgroundNode
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    private let imageNode: ASImageNode
    private let badgeBackgroundNode: ASImageNode
    private let badgeTextNode: ImmediateAnimatedCountLabelNode
    
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
    
    init(theme: PresentationTheme, backgroundNode: WallpaperBackgroundNode, type: ChatHistoryNavigationButtonType) {
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
        self.badgeBackgroundNode.displayWithoutProcessing = true
        self.badgeBackgroundNode.displaysAsynchronously = false
        self.badgeBackgroundNode.image = PresentationResourcesChat.chatHistoryNavigationButtonBadgeImage(theme)
        self.badgeBackgroundNode.alpha = 0.0
        
        self.badgeTextNode = ImmediateAnimatedCountLabelNode()
        self.badgeTextNode.isUserInteractionEnabled = false
        self.badgeTextNode.displaysAsynchronously = false
        self.badgeTextNode.reverseAnimationDirection = true
        
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
        self.badgeBackgroundNode.addSubnode(self.badgeTextNode)
        
        self.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    func updateTheme(theme: PresentationTheme, backgroundNode: WallpaperBackgroundNode) {
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
            
            var segments: [AnimatedCountLabelNode.Segment] = []
            if let value = Int(self.badge) {
                self.currentValue = value
                segments.append(.number(value, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
            } else {
                self.currentValue = 0
                segments.append(.text(100, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
            }
            self.badgeTextNode.segments = segments
        }
        
        if backgroundNode.hasExtraBubbleBackground() {
            if self.backgroundContent == nil {
                if let backgroundContent = backgroundNode.makeBubbleBackground(for: .free) {
                    backgroundContent.allowsGroupOpacity = true
                    backgroundContent.clipsToBounds = true
                    backgroundContent.alpha = 0.3
                    backgroundContent.cornerRadius = 19.0
                    backgroundContent.frame = self.backgroundNode.frame
                    self.buttonNode.insertSubnode(backgroundContent, aboveSubnode: self.backgroundNode)
                    self.backgroundContent = backgroundContent
                }
            }
        } else {
            self.backgroundContent?.removeFromSupernode()
            self.backgroundContent = nil
        }
        
        if let (rect, containerSize) = self.absoluteRect {
            self.backgroundContent?.update(rect: rect, within: containerSize, transition: .immediate)
        }
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)
        
        self.backgroundContent?.update(rect: rect, within: containerSize, transition: transition)
    }
    
    @objc func onTap() {
        if let tapped = self.tapped {
            tapped()
        }
    }
    
    private var currentValue: Int = 0
    private func layoutBadge() {
        if !self.badge.isEmpty {
            let previousValue = self.currentValue
            var segments: [AnimatedCountLabelNode.Segment] = []
            if let value = Int(self.badge) {
                self.currentValue = value
                segments.append(.number(value, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
            } else {
                self.currentValue = 0
                segments.append(.text(100, NSAttributedString(string: self.badge, font: badgeFont, textColor: self.theme.chat.historyNavigation.badgeTextColor)))
            }
            self.badgeTextNode.segments = segments
            
            let badgeSize = self.badgeTextNode.updateLayout(size: CGSize(width: 200.0, height: 100.0), animated: true)
            let backgroundSize = CGSize(width: self.badge.count == 1 ? 18.0 : max(18.0, badgeSize.width + 10.0 + 1.0), height: 18.0)
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((38.0 - backgroundSize.width) / 2.0), y: -9.0), size: backgroundSize)
            if backgroundFrame.width < self.badgeBackgroundNode.frame.width {
                self.badgeBackgroundNode.layer.animateFrame(from: self.badgeBackgroundNode.frame, to: backgroundFrame, duration: 0.2)
                self.badgeBackgroundNode.frame = backgroundFrame
            } else {
                self.badgeBackgroundNode.frame = backgroundFrame
            }
            self.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundFrame.width - badgeSize.width) / 2.0), y: 1.0), size: badgeSize)
            
            if self.badgeBackgroundNode.alpha < 1.0 {
                self.badgeBackgroundNode.alpha = 1.0
                
                self.badgeBackgroundNode.layer.animateScale(from: 0.01, to: 1.2, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.badgeBackgroundNode.layer.animateScale(from: 1.15, to: 1.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
                            strongSelf.badgeBackgroundNode.layer.removeAllAnimations()
                        })
                    }
                })
                self.badgeBackgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            } else if previousValue < self.currentValue {
                self.badgeBackgroundNode.layer.animateScale(from: 1.0, to: 1.2, duration: 0.12, removeOnCompletion: false, completion: { [weak self] finished in
                    if let strongSelf = self {
                        strongSelf.badgeBackgroundNode.layer.animateScale(from: 1.2, to: 1.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
                            strongSelf.badgeBackgroundNode.layer.removeAllAnimations()
                        })
                    }
                })
            }
        } else {
            self.currentValue = 0
            if self.badgeBackgroundNode.alpha > 0.0 {
                self.badgeBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                self.badgeBackgroundNode.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
            }
            self.badgeBackgroundNode.alpha = 0.0
        }
    }
}
