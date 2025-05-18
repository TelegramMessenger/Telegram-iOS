import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ChatControllerInteraction
import AccountContext
import TelegramCore
import Postbox
import WallpaperBackgroundNode
import ChatMessageItemCommon
import ContextUI

public class ChatMessageShareButton: ASDisplayNode {
    private let referenceNode: ContextReferenceContentNode
    private let containerNode: ContextControllerSourceNode
    
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    private var backgroundBlurView: PortalView?
    
    private let topButton: HighlightTrackingButtonNode
    private let topIconNode: ASImageNode
    private var topIconOffset = CGPoint()
    
    private var bottomButton: HighlightTrackingButtonNode?
    private var bottomIconNode: ASImageNode?
    
    private var separatorNode: ASDisplayNode?
    
    private var theme: PresentationTheme?
    private var isReplies: Bool = false
    private var hasMore: Bool = false
    
    private var textNode: ImmediateTextNode?
    
    private var absolutePosition: (CGRect, CGSize)?
    
    public var pressed: (() -> Void)?
    public var morePressed: (() -> Void)?
    public var longPressAction: ((ASDisplayNode, ContextGesture) -> Void)?
    
    override public init() {
        self.referenceNode = ContextReferenceContentNode()
        self.containerNode = ContextControllerSourceNode()
        self.containerNode.animateScale = false
        
        self.topButton = HighlightTrackingButtonNode()
        self.topIconNode = ASImageNode()
        self.topIconNode.displaysAsynchronously = false
        self.topIconNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.allowsGroupOpacity = true
        
        self.containerNode.addSubnode(self.referenceNode)
        self.topButton.addSubnode(self.containerNode)
        
        self.addSubnode(self.topIconNode)
        self.addSubnode(self.topButton)
        
        self.topButton.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
        self.topButton.highligthedChanged = { [weak self] highlighted in
            guard let self else {
                return
            }
            if highlighted {
                self.topIconNode.layer.removeAnimation(forKey: "opacity")
                self.topIconNode.alpha = 0.4
                self.textNode?.layer.removeAnimation(forKey: "opacity")
                self.textNode?.alpha = 0.4
            } else {
                self.topIconNode.alpha = 1.0
                self.topIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                self.textNode?.alpha = 1.0
                self.textNode?.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        
        self.containerNode.shouldBegin = { [weak self] location in
            guard let strongSelf = self, let _ = strongSelf.longPressAction else {
                return false
            }
            return true
        }
        self.containerNode.activated = { [weak self] gesture, _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.longPressAction?(strongSelf.containerNode, gesture)
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func buttonPressed() {
        self.pressed?()
    }
    
    @objc private func moreButtonPressed() {
        self.morePressed?()
    }
    
    public func update(presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction, chatLocation: ChatLocation, subject: ChatControllerSubject?, message: Message, account: Account, disableComments: Bool = false) -> CGSize {
        var isReplies = false
        var isNavigate = false
        var replyCount = 0
        if let channel = message.peers[message.id.peerId] as? TelegramChannel {
            if case .broadcast = channel.info {
                for attribute in message.attributes {
                    if let attribute = attribute as? ReplyThreadMessageAttribute {
                        replyCount = Int(attribute.count)
                        isReplies = true
                        break
                    }
                }
            } else if channel.isMonoForum, case .peer = chatLocation {
                isNavigate = true
            }
        }
        if case let .replyThread(replyThreadMessage) = chatLocation, replyThreadMessage.effectiveTopId == message.id {
            replyCount = 0
            isReplies = false
        }
        if disableComments {
            replyCount = 0
            isReplies = false
        }
        
        var hasMore = false
        if let adAttribute = message.adAttribute, adAttribute.canReport {
            hasMore = true
        }
        
        if self.theme !== presentationData.theme.theme || self.isReplies != isReplies || self.hasMore != hasMore {
            self.theme = presentationData.theme.theme
            self.isReplies = isReplies
            self.hasMore = hasMore

            var updatedIconImage: UIImage?
            var updatedBottomIconImage: UIImage?
            var updatedIconOffset = CGPoint()
            if let _ = message.adAttribute {
                updatedIconImage = PresentationResourcesChat.chatFreeCloseButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                updatedIconOffset = CGPoint(x: UIScreenPixel, y: UIScreenPixel)
                
                if hasMore {
                    updatedBottomIconImage = PresentationResourcesChat.chatFreeMoreButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                }
            } else if case let .customChatContents(contents) = subject, case .hashTagSearch = contents.kind {
                updatedIconImage = PresentationResourcesChat.chatFreeNavigateButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                updatedIconOffset = CGPoint(x: UIScreenPixel, y: 1.0)
            } else if isNavigate {
                updatedIconImage = PresentationResourcesChat.chatFreeNavigateToThreadButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                updatedIconOffset = CGPoint(x: UIScreenPixel, y: -3.0)
            } else if case .pinnedMessages = subject {
                updatedIconImage = PresentationResourcesChat.chatFreeNavigateButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                updatedIconOffset = CGPoint(x: UIScreenPixel, y: 1.0)
            } else if isReplies {
                updatedIconImage = PresentationResourcesChat.chatFreeCommentButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
            } else if message.id.peerId.isRepliesOrSavedMessages(accountPeerId: account.peerId) {
                updatedIconImage = PresentationResourcesChat.chatFreeNavigateButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
                updatedIconOffset = CGPoint(x: UIScreenPixel, y: 1.0)
            } else {
                updatedIconImage = PresentationResourcesChat.chatFreeShareButtonIcon(presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper)
            }
         
            self.topIconNode.image = updatedIconImage
            self.topIconOffset = updatedIconOffset
            
            if let updatedBottomIconImage {
                let bottomButton: HighlightTrackingButtonNode
                let bottomIconNode: ASImageNode
                let separatorNode: ASDisplayNode
                if let currentButton = self.bottomButton, let currentIcon = self.bottomIconNode, let currentSeparator = self.separatorNode {
                    bottomButton = currentButton
                    bottomIconNode = currentIcon
                    separatorNode = currentSeparator
                } else {
                    bottomButton = HighlightTrackingButtonNode()
                    bottomButton.addTarget(self, action: #selector(self.moreButtonPressed), forControlEvents: .touchUpInside)
                    self.bottomButton = bottomButton
                    
                    bottomIconNode = ASImageNode()
                    bottomIconNode.displaysAsynchronously = false
                    self.bottomIconNode = bottomIconNode
                    
                    bottomButton.highligthedChanged = { [weak self] highlighted in
                        guard let self, let bottomIconNode = self.bottomIconNode else {
                            return
                        }
                        if highlighted {
                            bottomIconNode.layer.removeAnimation(forKey: "opacity")
                            bottomIconNode.alpha = 0.4
                        } else {
                            bottomIconNode.alpha = 1.0
                            bottomIconNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                        }
                    }
                    
                    separatorNode = ASDisplayNode()
                    self.separatorNode = separatorNode
                    
                    self.addSubnode(separatorNode)
                    self.addSubnode(bottomIconNode)
                    self.addSubnode(bottomButton)
                }
                separatorNode.backgroundColor = bubbleVariableColor(variableColor: presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: presentationData.theme.wallpaper).withAlphaComponent(0.15)
                bottomIconNode.image = updatedBottomIconImage
            } else {
                self.bottomButton?.removeFromSupernode()
                self.bottomButton = nil
                self.bottomIconNode?.removeFromSupernode()
                self.bottomIconNode = nil
                self.separatorNode?.removeFromSupernode()
                self.separatorNode = nil
            }
        }
        var size = CGSize(width: 30.0, height: 30.0)
        if hasMore {
            size.height += 30.0
        }
        var offsetIcon = false
        if isReplies, replyCount > 0 {
            offsetIcon = true
            
            let textNode: ImmediateTextNode
            if let current = self.textNode {
                textNode = current
            } else {
                textNode = ImmediateTextNode()
                self.textNode = textNode
                self.addSubnode(textNode)
            }
            
            let textColor = bubbleVariableColor(variableColor: presentationData.theme.theme.chat.message.shareButtonForegroundColor, wallpaper: presentationData.theme.wallpaper)
            
            let countString: String
            if replyCount >= 1000 * 1000 {
                countString = "\(replyCount / 1000_000)M"
            } else if replyCount >= 1000 {
                countString = "\(replyCount / 1000)K"
            } else {
                countString = "\(replyCount)"
            }
            
            textNode.attributedText = NSAttributedString(string: countString, font: Font.regular(11.0), textColor: textColor)
            let textSize = textNode.updateLayout(CGSize(width: 100.0, height: 100.0))
            size.height += textSize.height - 1.0
            textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: size.height - textSize.height - 4.0), size: textSize)
        } else if let textNode = self.textNode {
            self.textNode = nil
            textNode.removeFromSupernode()
        }
        
        if self.backgroundBlurView == nil {
            if let backgroundBlurView = controllerInteraction.presentationContext.backgroundNode?.makeFreeBackground() {
                self.backgroundBlurView = backgroundBlurView
                self.view.insertSubview(backgroundBlurView.view, at: 0)
                
                backgroundBlurView.view.clipsToBounds = true
            }
        }
        if let backgroundBlurView = self.backgroundBlurView {
            backgroundBlurView.view.frame = CGRect(origin: CGPoint(), size: size)
            backgroundBlurView.view.layer.cornerRadius = min(size.width, size.height) / 2.0
        }
                
        if let image = self.topIconNode.image {
            self.topIconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0) + self.topIconOffset.x, y: floor((size.width - image.size.width) / 2.0) - (offsetIcon ? 1.0 : 0.0) + self.topIconOffset.y), size: image.size)
        }
        self.topButton.frame = CGRect(origin: .zero, size: CGSize(width: size.width, height: size.width))
        self.containerNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: size.width, height: size.width))
        self.referenceNode.frame = self.containerNode.bounds
        
        if let bottomIconNode = self.bottomIconNode, let bottomButton = self.bottomButton, let bottomImage = bottomIconNode.image {
            bottomIconNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - bottomImage.size.width) / 2.0), y: size.height - size.width + floorToScreenPixels((size.width - bottomImage.size.height) / 2.0)), size: bottomImage.size)
            bottomButton.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height - size.width), size: CGSize(width: size.width, height: size.width))
        }
        
        self.separatorNode?.frame = CGRect(origin: CGPoint(x: 0.0, y: size.height / 2.0), size: CGSize(width: size.width, height: 1.0 - UIScreenPixel))
        
        if controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
            if self.backgroundContent == nil, let backgroundContent = controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                backgroundContent.clipsToBounds = true
                self.backgroundContent = backgroundContent
                self.insertSubnode(backgroundContent, at: 0)
            }
        } else {
            self.backgroundContent?.removeFromSupernode()
            self.backgroundContent = nil
        }
        
        if let backgroundContent = self.backgroundContent {
            //self.backgroundNode.isHidden = true
            self.backgroundBlurView?.view.isHidden = true
            backgroundContent.cornerRadius = min(size.width, size.height) / 2.0
            backgroundContent.frame = CGRect(origin: CGPoint(), size: size)
            if let (rect, containerSize) = self.absolutePosition {
                var backgroundFrame = backgroundContent.frame
                backgroundFrame.origin.x += rect.minX
                backgroundFrame.origin.y += rect.minY
                backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
            }
        } else {
            //self.backgroundNode.isHidden = false
            self.backgroundBlurView?.view.isHidden = false
        }
        
        return size
    }
    
    public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absolutePosition = (rect, containerSize)
        if let backgroundContent = self.backgroundContent {
            var backgroundFrame = backgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
}
