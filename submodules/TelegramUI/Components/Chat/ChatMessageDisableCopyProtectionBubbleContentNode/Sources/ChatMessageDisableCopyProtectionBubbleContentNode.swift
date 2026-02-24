import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import ComponentFlow
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import LocalizedPeerData
import UrlEscaping
import TelegramStringFormatting
import WallpaperBackgroundNode
import ReactionSelectionNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import ChatControllerInteraction
import ShimmerEffect
import Markdown
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import TextNodeWithEntities

private func attributedServiceMessageString(theme: ChatPresentationThemeData, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: EngineMessage, accountPeerId: EnginePeer.Id) -> NSAttributedString? {
    return universalServiceMessageString(presentationData: (theme.theme, theme.wallpaper), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: message, accountPeerId: accountPeerId, forChatList: false, forForumOverview: false, forAdditionalServiceMessage: true)
}

public class ChatMessageDisableCopyProtectionBubbleContentNode: ChatMessageBubbleContentNode {
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let textNode: TextNodeWithEntities
    private let infoNode: TextNodeWithEntities
    
    private var absoluteRect: (CGRect, CGSize)?
    
    private var isPlaying: Bool = false
    
    override public var disablesClipping: Bool {
        return true
    }
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            let wasVisible = oldValue != .none
            let isVisible = self.visibility != .none
            
            if wasVisible != isVisible {
                self.visibilityStatus = isVisible
                
                switch self.visibility {
                case .none:
                    self.textNode.visibilityRect = nil
                case let .visible(_, subRect):
                    var subRect = subRect
                    subRect.origin.x = 0.0
                    subRect.size.width = 10000.0
                    self.textNode.visibilityRect = subRect
                }
            }
        }
    }
    
    private var visibilityStatus: Bool? {
        didSet {
            if self.visibilityStatus != oldValue {
                self.updateVisibility()
            }
        }
    }
    
    private var fetchDisposable: Disposable?
    private var setupTimestamp: Double?
    
    private var cachedTonImage: (UIImage, UIColor)?
    
    required public init() {
        self.textNode = TextNodeWithEntities()
        self.textNode.textNode.isUserInteractionEnabled = false
        self.textNode.textNode.displaysAsynchronously = false
        
        self.infoNode = TextNodeWithEntities()
        self.infoNode.textNode.isUserInteractionEnabled = false
        self.infoNode.textNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.textNode.textNode)
        self.addSubnode(self.infoNode.textNode)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable?.dispose()
    }
        
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeTextLayout = TextNodeWithEntities.asyncLayout(self.textNode)
        let makeInfoLayout = TextNodeWithEntities.asyncLayout(self.infoNode)
                            
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                var bubbleSize = CGSize(width: 246.0, height: 240.0)
                let textConstrainedSize = CGSize(width: bubbleSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude)
                
                let incoming: Bool
                if item.message.id.peerId == item.context.account.peerId && item.message.forwardInfo == nil {
                    incoming = true
                } else {
                    incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                }
                
                let textColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                
                var text: String = ""
                var hasActionButtons = false
                if let action = item.message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .copyProtectionRequest(hasExpired, _, _) = action.action {
                    let currentTimestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    
                    let appConfiguration = item.context.currentAppConfiguration.with { $0 }
                    let configuration = CopyProtectionConfiguration.with(appConfiguration: appConfiguration)
                    let expireDate = item.message.timestamp + configuration.requestExpirePeriod
                    
                    hasActionButtons = incoming && !hasExpired && expireDate > currentTimestamp
                }
                
                let peerName = item.message.peers[item.message.id.peerId].flatMap { EnginePeer($0) }?.compactDisplayTitle ?? ""
                if incoming {
                    text = item.presentationData.strings.Notification_CopyProtection_RequestChat(peerName).string
                } else {
                    text = item.presentationData.strings.Notification_CopyProtection_RequestChatYou
                }
                
                var infoText = item.presentationData.strings.Notification_CopyProtection_RequestChatInfo
                infoText = " #   \(infoText.replacingOccurrences(of: "\n", with: "\n #   "))"
                
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: textColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: textColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: textColor),
                    linkAttribute: { url in
                        return ("URL", url)
                    }
                ), textAlignment: .center)
                
                let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .center, lineSpacing: 0.2, cutout: nil, insets: UIEdgeInsets()))
                
                let attributedInfoText = parseMarkdownIntoAttributedString(infoText, attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: textColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: textColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: textColor),
                    linkAttribute: { url in
                        return ("URL", url)
                    }
                ), textAlignment: .left).mutableCopy() as! NSMutableAttributedString
                let ranges = attributedInfoText.string.subranges(of: "#")
                for range in ranges.ranges {
                    attributedInfoText.addAttribute(.attachment, value: UIImage(bundleImageName: "Chat/Empty Chat/ListCheckIcon")!, range: NSRange(range, in: attributedInfoText.string))
                }
                
                let (infoLayout, infoApply) = makeInfoLayout(TextNodeLayoutArguments(attributedString: attributedInfoText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .left, lineSpacing: 1.0, cutout: nil, insets: UIEdgeInsets(top: 0.0, left: 2.0, bottom: 0.0, right: 2.0)))
           
                bubbleSize.height = textLayout.size.height + infoLayout.size.height + 25.0
                
                let backgroundSize = CGSize(width: bubbleSize.width, height: bubbleSize.height + 4.0)
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, info in
                        if let strongSelf = self {
                            strongSelf.item = item
                                                              
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingWidth - bubbleSize.width) / 2.0), y: 0.0), size: bubbleSize)
                            let mediaBackgroundFrame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                                                    
                            strongSelf.updateVisibility()
                            
                            let _ = textApply(TextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.controllerInteraction.presentationContext.animationCache,
                                renderer: item.controllerInteraction.presentationContext.animationRenderer,
                                placeholderColor: item.presentationData.theme.theme.chat.message.freeform.withWallpaper.reactionInactiveBackground,
                                attemptSynchronous: synchronousLoads
                            ))
                            
                            let _ = infoApply(TextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.controllerInteraction.presentationContext.animationCache,
                                renderer: item.controllerInteraction.presentationContext.animationRenderer,
                                placeholderColor: item.presentationData.theme.theme.chat.message.freeform.withWallpaper.reactionInactiveBackground,
                                attemptSynchronous: synchronousLoads
                            ))
                                                  
                            let textFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - textLayout.size.width) / 2.0), y: mediaBackgroundFrame.minY + 14.0), size: textLayout.size)
                            strongSelf.textNode.textNode.frame = textFrame
                            
                            let infoFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - infoLayout.size.width) / 2.0), y: mediaBackgroundFrame.minY + 14.0 + textLayout.size.height + 12.0), size: infoLayout.size)
                            strongSelf.infoNode.textNode.frame = infoFrame
                            
                            if strongSelf.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                backgroundContent.clipsToBounds = true
                                backgroundContent.cornerRadius = 24.0
                                
                                strongSelf.mediaBackgroundContent = backgroundContent
                                strongSelf.insertSubnode(backgroundContent, at: 0)
                            }
                            
                            if let backgroundContent = strongSelf.mediaBackgroundContent {
                                animation.animator.updateFrame(layer: backgroundContent.layer, frame: mediaBackgroundFrame, completion: nil)
                                backgroundContent.clipsToBounds = true
                                
                                if hasActionButtons {
                                    backgroundContent.cornerRadius = 0.0
                                    if backgroundContent.view.mask == nil {
                                        backgroundContent.view.mask = UIImageView(image: generateImage(mediaBackgroundFrame.size, rotatedContext: { size, context in
                                            context.clear(CGRect(origin: .zero, size: size))
                                            context.setFillColor(UIColor.white.cgColor)
                                            
                                            context.addPath(CGPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.5), cornerWidth: 24.0, cornerHeight: 24.0, transform: nil))
                                            context.addPath(CGPath(roundedRect: CGRect(x: 0, y: size.height * 0.5 - 30.0, width: size.width, height: size.height * 0.5 + 30.0), cornerWidth: 8.0, cornerHeight: 8.0, transform: nil))
                                            context.fillPath()
                                        }))
                                    }
                                } else {
                                    backgroundContent.view.mask = nil
                                    backgroundContent.cornerRadius = 24.0
                                }
                            }
                                                        
                            if let (rect, size) = strongSelf.absoluteRect {
                                strongSelf.updateAbsoluteRect(rect, within: size)
                            }
                             
                            switch strongSelf.visibility {
                            case .none:
                                strongSelf.textNode.visibilityRect = nil
                                strongSelf.infoNode.visibilityRect = nil
                            case let .visible(_, subRect):
                                var subRect = subRect
                                subRect.origin.x = 0.0
                                subRect.size.width = 10000.0
                                strongSelf.textNode.visibilityRect = subRect
                                strongSelf.infoNode.visibilityRect = subRect
                            }
                        }
                    })
                })
            })
        }
    }

    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        if let mediaBackgroundContent = self.mediaBackgroundContent {
            var backgroundFrame = mediaBackgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            mediaBackgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }

    override public func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {

    }

    override public func applyAbsoluteOffsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {

    }
    
    override public func unreadMessageRangeUpdated() {
        self.updateVisibility()
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        return ChatMessageBubbleContentTapAction(content: .none)
    }
    
    private func updateVisibility() {
    }
}
