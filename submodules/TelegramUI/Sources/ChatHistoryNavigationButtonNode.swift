import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import WallpaperBackgroundNode
import AnimatedCountLabelNode
import GlassBackgroundComponent
import ComponentFlow
import ComponentDisplayAdapters

private let badgeFont = Font.with(size: 13.0, traits: [.monospacedNumbers])

enum ChatHistoryNavigationButtonType {
    case down
    case up
    case mentions
    case reactions
}

class ChatHistoryNavigationButtonNode: ContextControllerSourceNode {
    let containerNode: ContextExtractedContentContainingNode
    let buttonNode: HighlightTrackingButtonNode
    private let backgroundView: GlassBackgroundView
    let imageView: GlassBackgroundView.ContentImageView
    private let badgeBackgroundView: GlassBackgroundView
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

        self.backgroundView = GlassBackgroundView()
        
        self.imageView = GlassBackgroundView.ContentImageView()
        switch type {
        case .down:
            self.imageView.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(theme)
        case .up:
            self.imageView.image = PresentationResourcesChat.chatHistoryNavigationUpButtonImage(theme)
        case .mentions:
            self.imageView.image = PresentationResourcesChat.chatHistoryMentionsButtonImage(theme)
        case .reactions:
            self.imageView.image = PresentationResourcesChat.chatHistoryReactionsButtonImage(theme)
        }
        
        self.badgeBackgroundView = GlassBackgroundView()
        self.badgeBackgroundView.alpha = 0.0
        
        self.badgeTextNode = ImmediateAnimatedCountLabelNode()
        self.badgeTextNode.isUserInteractionEnabled = false
        self.badgeTextNode.displaysAsynchronously = false
        self.badgeTextNode.reverseAnimationDirection = true
        
        super.init()
        
        self.targetNodeForActivationProgress = self.buttonNode
        
        self.addSubnode(self.containerNode)
        
        let size = CGSize(width: 40.0, height: 40.0)
        
        self.containerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
        self.containerNode.contentRect = CGRect(origin: CGPoint(), size: size)
        
        self.buttonNode.frame = CGRect(origin: CGPoint(), size: size)
        self.containerNode.contentNode.addSubnode(self.buttonNode)

        self.buttonNode.view.addSubview(self.backgroundView)
        self.backgroundView.frame = CGRect(origin: CGPoint(), size: size)
        self.backgroundView.update(size: size, cornerRadius: size.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), transition: .immediate)
        self.imageView.tintColor = theme.chat.inputPanel.panelControlColor

        self.backgroundView.contentView.addSubview(self.imageView)
        self.imageView.frame = CGRect(origin: CGPoint(), size: size)
        
        self.buttonNode.view.addSubview(self.badgeBackgroundView)
        self.badgeBackgroundView.contentView.addSubview(self.badgeTextNode.view)
        
        self.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    func updateTheme(theme: PresentationTheme, backgroundNode: WallpaperBackgroundNode) {
        if self.theme !== theme {
            self.theme = theme

            self.backgroundView.update(size: self.backgroundView.bounds.size, cornerRadius: self.backgroundView.bounds.size.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .panel, color: theme.chat.inputPanel.inputBackgroundColor.withMultipliedAlpha(0.7)), transition: .immediate)
            self.imageView.tintColor = theme.chat.inputPanel.panelControlColor
            
            switch self.type {
            case .down:
                self.imageView.image = PresentationResourcesChat.chatHistoryNavigationButtonImage(theme)
            case .up:
                self.imageView.image = PresentationResourcesChat.chatHistoryNavigationUpButtonImage(theme)
            case .mentions:
                self.imageView.image = PresentationResourcesChat.chatHistoryMentionsButtonImage(theme)
            case .reactions:
                self.imageView.image = PresentationResourcesChat.chatHistoryReactionsButtonImage(theme)
            }
            
            self.badgeBackgroundView.update(size: self.badgeBackgroundView.bounds.size, cornerRadius: self.badgeBackgroundView.bounds.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .custom, color: theme.chat.inputPanel.actionControlFillColor), transition: .immediate)
            
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
    }
    
    private var absoluteRect: (CGRect, CGSize)?
    func update(rect: CGRect, within containerSize: CGSize, transition: ContainedViewLayoutTransition) {
        self.absoluteRect = (rect, containerSize)
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
            let backgroundSize = CGSize(width: self.badge.count == 1 ? 20.0 : max(20.0, badgeSize.width + 10.0 + 1.0), height: 20.0)
            let backgroundFrame = CGRect(origin: CGPoint(x: floor((40.0 - backgroundSize.width) / 2.0), y: -7.0), size: backgroundSize)
            if backgroundFrame.width < self.badgeBackgroundView.frame.width {
                self.badgeBackgroundView.layer.animateFrame(from: self.badgeBackgroundView.frame, to: backgroundFrame, duration: 0.2)
                self.badgeBackgroundView.frame = backgroundFrame
            } else {
                self.badgeBackgroundView.frame = backgroundFrame
            }
            
            let transition: ContainedViewLayoutTransition = .animated(duration: 0.2, curve: .easeInOut)
            self.badgeBackgroundView.update(size: backgroundFrame.size, cornerRadius: backgroundFrame.height * 0.5, isDark: theme.overallDarkAppearance, tintColor: .init(kind: .custom, color: self.theme.chat.inputPanel.actionControlFillColor), transition: ComponentTransition(transition))
            
            self.badgeTextNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundFrame.width - badgeSize.width) / 2.0), y: 2.0), size: badgeSize)
            
            if self.badgeBackgroundView.alpha < 1.0 {
                self.badgeBackgroundView.alpha = 1.0
                
                self.badgeBackgroundView.layer.animateScale(from: 0.01, to: 1.2, duration: 0.2, removeOnCompletion: false, completion: { [weak self] _ in
                    if let strongSelf = self {
                        strongSelf.badgeBackgroundView.layer.animateScale(from: 1.15, to: 1.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
                            strongSelf.badgeBackgroundView.layer.removeAllAnimations()
                        })
                    }
                })
                self.badgeBackgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            } else if previousValue < self.currentValue {
                self.badgeBackgroundView.layer.animateScale(from: 1.0, to: 1.2, duration: 0.12, removeOnCompletion: false, completion: { [weak self] finished in
                    if let strongSelf = self {
                        strongSelf.badgeBackgroundView.layer.animateScale(from: 1.2, to: 1.0, duration: 0.12, removeOnCompletion: false, completion: { _ in
                            strongSelf.badgeBackgroundView.layer.removeAllAnimations()
                        })
                    }
                })
            }
        } else {
            self.currentValue = 0
            if self.badgeBackgroundView.alpha > 0.0 {
                self.badgeBackgroundView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2)
                self.badgeBackgroundView.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2)
            }
            self.badgeBackgroundView.alpha = 0.0
        }
    }
}
