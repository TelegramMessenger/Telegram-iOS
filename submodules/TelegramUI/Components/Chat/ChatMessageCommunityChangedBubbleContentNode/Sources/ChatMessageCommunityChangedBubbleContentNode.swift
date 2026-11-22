import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import WallpaperBackgroundNode
import AvatarNode
import ChatMessageBubbleContentNode
import ChatMessageItemCommon
import ChatControllerInteraction
import Markdown

private func communityChangedPeer(message: EngineRawMessage) -> (EnginePeer.Id, TelegramCommunity)? {
    for media in message.media {
        guard let action = media as? TelegramMediaAction else {
            continue
        }
        if case let .communityChanged(communityId) = action.action, let communityId, let community = message.peers[communityId] as? TelegramCommunity {
            return (communityId, community)
        }
    }
    return nil
}

public class ChatMessageCommunityChangedBubbleContentNode: ChatMessageBubbleContentNode {
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let mediaBackgroundNode: NavigationBackgroundNode
    private let avatarShadowNode: ASImageNode
    private let avatarNode: AvatarNode
    private let subtitleNode: TextNode
    
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonTitleNode: TextNode
    
    private var absoluteRect: (CGRect, CGSize)?
    
    required public init() {
        self.mediaBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.mediaBackgroundNode.clipsToBounds = true
        self.mediaBackgroundNode.cornerRadius = 24.0
        
        self.avatarShadowNode = ASImageNode()
        self.avatarShadowNode.displaysAsynchronously = false
        self.avatarShadowNode.displayWithoutProcessing = true
        self.avatarShadowNode.isHidden = true

        self.avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 28.0))
        self.avatarNode.isUserInteractionEnabled = false
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 17.0
        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
        self.buttonTitleNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.mediaBackgroundNode)
        self.addSubnode(self.avatarShadowNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.buttonTitleNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.buttonNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.buttonNode.alpha = 0.4
                strongSelf.buttonTitleNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.buttonTitleNode.alpha = 0.4
            } else {
                strongSelf.buttonNode.alpha = 1.0
                strongSelf.buttonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                strongSelf.buttonTitleNode.alpha = 1.0
                strongSelf.buttonTitleNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func buttonPressed() {
        guard let item = self.item, let (communityId, _) = communityChangedPeer(message: item.message) else {
            return
        }
        let controller = item.context.sharedContext.makeCommunityViewScreen(context: item.context, communityId: communityId, mode: .sheet)
        if let navigationController = item.controllerInteraction.navigationController() {
            navigationController.pushViewController(controller)
        } else {
            item.controllerInteraction.presentControllerInCurrent(controller, nil)
        }
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)
        
        return { [weak self] item, _, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { [weak self] constrainedSize, _ in
                let width: CGFloat = 180.0
                let imageSize = CGSize(width: 80.0, height: 80.0)
                let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                
                let community = communityChangedPeer(message: item.message)?.1
                let authorName = item.message.author.flatMap { peer -> String? in
                    let title = EnginePeer(peer).compactDisplayTitle
                    return title.isEmpty ? nil : title
                } ?? ""
                
                var isGroup = false
                let messagePeer = item.message.peers[item.message.id.peerId]
                let isBot = messagePeer is TelegramUser
                if let channel = messagePeer as? TelegramChannel, case .group = channel.info {
                    isGroup = true
                }
                
                let text: String
                if isBot {
                    text = item.presentationData.strings.Notification_CommunityAddedBot("**\(community?.title ?? "")**").string
                } else if isGroup {
                    if item.message.author?.id == item.context.account.peerId {
                        text = item.presentationData.strings.Notification_CommunityAddedGroupYou("**\(community?.title ?? "")**").string
                    } else {
                        if item.message.author?.id.namespace != Namespaces.Peer.CloudUser {
                            text = item.presentationData.strings.Notification_CommunityAddedGroupUnknown("**\(community?.title ?? "")**").string
                        } else {
                            text = item.presentationData.strings.Notification_CommunityAddedGroup("**\(authorName)**", "**\(community?.title ?? "")**").string
                        }
                    }
                } else {
                    text = item.presentationData.strings.Notification_CommunityAddedChannel("**\(community?.title ?? "")**").string
                }
                
                let attributedText = parseMarkdownIntoAttributedString(text, attributes: MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: primaryTextColor),
                    link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: primaryTextColor),
                    linkAttribute: { url in
                        return ("URL", url)
                    }
                ), textAlignment: .center)
                
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: attributedText, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Community_CommunityAdded_View, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let backgroundSize = CGSize(width: width, height: subtitleLayout.size.height + 165.0)
                
                return (backgroundSize.width, { [weak self] boundingWidth in
                    return (backgroundSize, { [weak self] _, synchronousLoads, _ in
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.item = item
                        
                        let mediaBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((boundingWidth - width) / 2.0), y: 0.0), size: backgroundSize)
                        strongSelf.mediaBackgroundNode.frame = mediaBackgroundFrame
                        strongSelf.mediaBackgroundNode.updateColor(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: item.controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), transition: .immediate)
                        strongSelf.mediaBackgroundNode.update(size: mediaBackgroundFrame.size, transition: .immediate)
                        let buttonColor = item.presentationData.theme.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                        strongSelf.buttonNode.backgroundColor = buttonColor
                        
                        let avatarFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - imageSize.width) / 2.0), y: 15.0), size: imageSize)
                        if let shadowImage = UIImage(bundleImageName: "Components/CommunityShadow"), community != nil {
                            strongSelf.avatarShadowNode.isHidden = false
                            strongSelf.avatarShadowNode.image = generateTintedImage(image: shadowImage, color: buttonColor.withMultipliedAlpha(4.0))

                            let aspectRatio = shadowImage.size.width / shadowImage.size.height
                            let shadowSize = CGSize(width: imageSize.width * aspectRatio, height: imageSize.width)
                            strongSelf.avatarShadowNode.frame = shadowSize.centered(around: avatarFrame.center).offsetBy(dx: -11.0, dy: 0.0)
                        } else {
                            strongSelf.avatarShadowNode.isHidden = true
                        }
                        strongSelf.avatarNode.frame = avatarFrame
                        if let community {
                            strongSelf.avatarNode.setPeer(context: item.context, theme: item.presentationData.theme.theme, peer: EnginePeer(community), clipStyle: .roundedRect, synchronousLoad: synchronousLoads, displayDimensions: imageSize)
                        }
                        
                        let _ = subtitleApply()
                        let _ = buttonTitleApply()
                        
                        let subtitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0), y: mediaBackgroundFrame.minY + 108.0), size: subtitleLayout.size)
                        strongSelf.subtitleNode.frame = subtitleFrame
                        
                        let buttonTitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonTitleLayout.size.width) / 2.0), y: subtitleFrame.maxY + 18.0), size: buttonTitleLayout.size)
                        strongSelf.buttonTitleNode.frame = buttonTitleFrame
                        
                        let buttonSize = CGSize(width: buttonTitleLayout.size.width + 38.0, height: 34.0)
                        strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonSize.width) / 2.0), y: subtitleFrame.maxY + 10.0), size: buttonSize)
                        
                        if item.controllerInteraction.presentationContext.backgroundNode?.hasExtraBubbleBackground() == true {
                            if strongSelf.mediaBackgroundContent == nil, let backgroundContent = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                strongSelf.mediaBackgroundNode.isHidden = true
                                backgroundContent.clipsToBounds = true
                                backgroundContent.allowsGroupOpacity = true
                                backgroundContent.cornerRadius = 24.0
                                
                                strongSelf.mediaBackgroundContent = backgroundContent
                                strongSelf.insertSubnode(backgroundContent, at: 0)
                            }
                            
                            strongSelf.mediaBackgroundContent?.frame = mediaBackgroundFrame
                        } else {
                            strongSelf.mediaBackgroundNode.isHidden = false
                            strongSelf.mediaBackgroundContent?.removeFromSupernode()
                            strongSelf.mediaBackgroundContent = nil
                        }
                        
                        if let (rect, size) = strongSelf.absoluteRect {
                            strongSelf.updateAbsoluteRect(rect, within: size)
                        }
                    })
                })
            })
        }
    }
    
    override public func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.mediaBackgroundNode.frame.contains(point) {
            return ChatMessageBubbleContentTapAction(content: .custom({ [weak self] in
                self?.buttonPressed()
            }))
        } else {
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
}
