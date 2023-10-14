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

public class ChatMessageShareButton: HighlightableButtonNode {
    private var backgroundContent: WallpaperBubbleBackgroundNode?
    private var backgroundBlurView: PortalView?
    
    private let iconNode: ASImageNode
    private var iconOffset = CGPoint()
    
    private var theme: PresentationTheme?
    private var isReplies: Bool = false
    
    private var textNode: ImmediateTextNode?
    
    private var absolutePosition: (CGRect, CGSize)?
    
    public init() {
        self.iconNode = ASImageNode()
        
        super.init(pointerStyle: nil)
        
        self.allowsGroupOpacity = true
        
        self.addSubnode(self.iconNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func update(presentationData: ChatPresentationData, controllerInteraction: ChatControllerInteraction, chatLocation: ChatLocation, subject: ChatControllerSubject?, message: Message, account: Account, disableComments: Bool = false) -> CGSize {
        var isReplies = false
        var replyCount = 0
        if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = channel.info {
            for attribute in message.attributes {
                if let attribute = attribute as? ReplyThreadMessageAttribute {
                    replyCount = Int(attribute.count)
                    isReplies = true
                    break
                }
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
        
        if self.theme !== presentationData.theme.theme || self.isReplies != isReplies {
            self.theme = presentationData.theme.theme
            self.isReplies = isReplies

            var updatedIconImage: UIImage?
            var updatedIconOffset = CGPoint()
            if case .pinnedMessages = subject {
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
            //self.backgroundNode.updateColor(color: selectDateFillStaticColor(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), enableBlur: controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: presentationData.theme.theme, wallpaper: presentationData.theme.wallpaper), transition: .immediate)
            self.iconNode.image = updatedIconImage
            self.iconOffset = updatedIconOffset
        }
        var size = CGSize(width: 30.0, height: 30.0)
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
        
        //self.backgroundNode.frame = CGRect(origin: CGPoint(), size: size)
        //self.backgroundNode.update(size: self.backgroundNode.bounds.size, cornerRadius: min(self.backgroundNode.bounds.width, self.backgroundNode.bounds.height) / 2.0, transition: .immediate)
        if let image = self.iconNode.image {
            self.iconNode.frame = CGRect(origin: CGPoint(x: floor((size.width - image.size.width) / 2.0) + self.iconOffset.x, y: floor((size.width - image.size.width) / 2.0) - (offsetIcon ? 1.0 : 0.0) + self.iconOffset.y), size: image.size)
        }
        
        
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
