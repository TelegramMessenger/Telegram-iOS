import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import LocalizedPeerData
import TelegramStringFormatting
import WallpaperBackgroundNode
import ReactionSelectionNode
import PhotoResources
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import GalleryUI
import Markdown
import ComponentFlow
import AvatarStoryIndicatorComponent
import AvatarNode

class ChatMessageStoryMentionContentNode: ChatMessageBubbleContentNode {
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let mediaBackgroundNode: NavigationBackgroundNode
    private let subtitleNode: TextNode
    private let imageNode: TransformImageNode
    private let storyIndicator = ComponentView<Empty>()
    
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonTitleNode: TextNode
    
    private var absoluteRect: (CGRect, CGSize)?
    
    private let fetchDisposable = MetaDisposable()
            
    required init() {
        self.mediaBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.mediaBackgroundNode.clipsToBounds = true
        self.mediaBackgroundNode.cornerRadius = 24.0
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 17.0
                        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
        self.buttonTitleNode.displaysAsynchronously = false
        
        super.init()

        self.addSubnode(self.mediaBackgroundNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.imageNode)
    
        self.addSubnode(self.buttonNode)
        self.addSubnode(self.buttonTitleNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
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
        }
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override func transitionNode(messageId: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if self.item?.message.id == messageId {
            return (self.imageNode, self.imageNode.bounds, { [weak self] in
                guard let strongSelf = self else {
                    return (nil, nil)
                }
                
                let resultView = strongSelf.imageNode.view.snapshotContentTree(unhide: true)
                return (resultView, nil)
            })
        } else {
            return nil
        }
    }
    
    override func updateHiddenMedia(_ media: [Media]?) -> Bool {
        var mediaHidden = false
        var currentMedia: Media?
        if let item = item {
            mediaLoop: for media in item.message.media {
                if let media = media as? TelegramMediaStory {
                    currentMedia = media
                }
            }
        }
        if let currentMedia = currentMedia, let media = media {
            for item in media {
                if item.isSemanticallyEqual(to: currentMedia) {
                    mediaHidden = true
                    break
                }
            }
        }
        
        self.imageNode.isHidden = mediaHidden
        return mediaHidden
    }
    
    @objc private func buttonPressed() {
        guard let item = self.item else {
            return
        }
        let _ = item.controllerInteraction.openMessage(item.message, .default)
    }
                
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeImageLayout = self.imageNode.asyncLayout()
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)
        
        let currentItem = self.item

        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let width: CGFloat = 180.0
                let imageSize = CGSize(width: 100.0, height: 100.0)
                            
                let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                                
                var story: Stories.Item?
                
                let storyMedia: TelegramMediaStory? = item.message.media.first(where: { $0 is TelegramMediaStory }) as? TelegramMediaStory
                var selectedMedia: Media?
                
                if let storyMedia, let storyItem = item.message.associatedStories[storyMedia.storyId], !storyItem.data.isEmpty, case let .item(storyValue) = storyItem.get(Stories.StoredItem.self) {
                    selectedMedia = storyValue.media
                    story = storyValue
                }
                
                var mediaUpdated = false
                if let selectedMedia, let currentItem, let storyMedia = currentItem.message.media.first(where: { $0 is TelegramMediaStory }) as? TelegramMediaStory, let storyItem = currentItem.message.associatedStories[storyMedia.storyId], !storyItem.data.isEmpty, case let .item(storyValue) = storyItem.get(Stories.StoredItem.self) {
                    if let currentMedia = storyValue.media {
                        mediaUpdated = !selectedMedia.isSemanticallyEqual(to: currentMedia)
                    } else {
                        mediaUpdated = true
                    }
                } else {
                    mediaUpdated = true
                }
                
                let fromYou = item.message.author?.id == item.context.account.peerId
                
                let peerName = item.message.peers[item.message.id.peerId].flatMap { EnginePeer($0).compactDisplayTitle } ?? ""
                let textWithRanges: PresentationStrings.FormattedString
                if fromYou {
                    textWithRanges = item.presentationData.strings.Conversation_StoryMentionTextOutgoing(peerName)
                } else {
                    textWithRanges = item.presentationData.strings.Conversation_StoryMentionTextIncoming(peerName)
                }
                
                let text = NSMutableAttributedString()
                text.append(NSAttributedString(string: textWithRanges.string, font: Font.regular(13.0), textColor: primaryTextColor))
                for range in textWithRanges.ranges {
                    if range.index == 0 {
                        text.addAttribute(.font, value: Font.semibold(13.0), range: range.range)
                    }
                }
                
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: text, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: item.presentationData.strings.Chat_StoryMentionAction, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
                let backgroundSize = CGSize(width: width, height: subtitleLayout.size.height + 167.0 + buttonTitleLayout.size.height)
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - imageSize.width) / 2.0), y: 15.0), size: imageSize).insetBy(dx: 6.0, dy: 6.0)
                            if let story, let selectedMedia {
                                if mediaUpdated {
                                    if story.isForwardingDisabled {
                                        let maxImageSize = CGSize(width: 180.0, height: 180.0).aspectFitted(imageSize)
                                        let boundingImageSize = maxImageSize
                                        
                                        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
                                        if let author = item.message.author {
                                            updateImageSignal = peerAvatarCompleteImage(account: item.context.account, peer: EnginePeer(author), size: imageSize)
                                            |> map { image in
                                                return { arguments in
                                                    let context = DrawingContext(size: arguments.drawingSize, scale: arguments.scale ?? 0.0, clear: true)
                                                    context?.withContext { c in
                                                        UIGraphicsPushContext(c)
                                                        c.addEllipse(in: CGRect(origin: CGPoint(), size: arguments.drawingSize))
                                                        c.clip()
                                                        if let image {
                                                            image.draw(in: arguments.imageRect)
                                                        }
                                                        UIGraphicsPopContext()
                                                    }
                                                    return context
                                                }
                                            }
                                        }
                                        if let updateImageSignal {
                                            strongSelf.imageNode.setSignal(updateImageSignal, attemptSynchronously: synchronousLoads)
                                        }
                                        
                                        let arguments = TransformImageArguments(corners: ImageCorners(radius: imageFrame.height / 2.0), imageSize: boundingImageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets())
                                        let apply = makeImageLayout(arguments)
                                        apply()
                                        
                                        strongSelf.imageNode.frame = imageFrame
                                    } else if let photo = selectedMedia as? TelegramMediaImage {
                                        let maxImageSize = photo.representations.last?.dimensions.cgSize ?? imageFrame.size
                                        let boundingImageSize = maxImageSize.aspectFilled(imageFrame.size)
                                        
                                        strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(context: item.context, userLocation: .peer(item.message.id.peerId), photoReference: .message(message: MessageReference(item.message), media: photo), displayAtSize: nil, storeToDownloadsPeerId: nil).start())
                                        
                                        let updateImageSignal = chatMessagePhoto(postbox: item.context.account.postbox, userLocation: .peer(item.message.id.peerId), photoReference: .message(message: MessageReference(item.message), media: photo), synchronousLoad: synchronousLoads)
                                        strongSelf.imageNode.setSignal(updateImageSignal, attemptSynchronously: synchronousLoads)
                                        
                                        let arguments = TransformImageArguments(corners: ImageCorners(radius: imageFrame.height / 2.0), imageSize: boundingImageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets())
                                        let apply = makeImageLayout(arguments)
                                        apply()
                                        
                                        strongSelf.imageNode.frame = imageFrame
                                    } else if let file = selectedMedia as? TelegramMediaFile {
                                        let maxImageSize = file.dimensions?.cgSize ?? imageFrame.size
                                        let boundingImageSize = maxImageSize.aspectFilled(imageFrame.size)
                                        
                                        let updateImageSignal = chatMessageVideoThumbnail(account: item.context.account, userLocation: .peer(item.message.id.peerId), fileReference: .message(message: MessageReference(item.message), media: file), blurred: false, synchronousLoads: synchronousLoads)
                                        
                                        strongSelf.imageNode.setSignal(updateImageSignal, attemptSynchronously: synchronousLoads)
                                        
                                        let arguments = TransformImageArguments(corners: ImageCorners(radius: imageFrame.width / 2.0), imageSize: boundingImageSize, boundingSize: imageFrame.size, intrinsicInsets: UIEdgeInsets())
                                        let apply = makeImageLayout(arguments)
                                        apply()
                                        
                                        strongSelf.imageNode.frame = imageFrame
                                    }
                                }
                            }
                            
                            if let storyMedia {
                                var hasUnseen = false
                                if !fromYou {
                                    hasUnseen = item.associatedData.maxReadStoryId.flatMap({ $0 < storyMedia.storyId.id }) ?? false
                                }
                                
                                let indicatorFrame = imageFrame
                                var storyColors = AvatarStoryIndicatorComponent.Colors(theme: item.presentationData.theme.theme)
                                storyColors.seenColors = [UIColor(white: 1.0, alpha: 0.2), UIColor(white: 1.0, alpha: 0.2)]
                                let _ = strongSelf.storyIndicator.update(
                                    transition: .immediate,
                                    component: AnyComponent(AvatarStoryIndicatorComponent(
                                        hasUnseen: hasUnseen,
                                        hasUnseenCloseFriendsItems: hasUnseen && (story?.isCloseFriends ?? false),
                                        colors: storyColors,
                                        activeLineWidth: 3.0,
                                        inactiveLineWidth: 1.0 + UIScreenPixel,
                                        counters: nil
                                    )),
                                    environment: {},
                                    containerSize: indicatorFrame.size
                                )
                                if let storyIndicatorView = strongSelf.storyIndicator.view {
                                    if storyIndicatorView.superview == nil {
                                        strongSelf.view.addSubview(storyIndicatorView)
                                    }
                                    storyIndicatorView.frame = indicatorFrame
                                }
                            }
                            
                            let mediaBackgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - width) / 2.0), y: 0.0), size: backgroundSize)
                            strongSelf.mediaBackgroundNode.frame = mediaBackgroundFrame
                                                        
                            strongSelf.mediaBackgroundNode.updateColor(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: item.controllerInteraction.enableFullTranslucency && dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), transition: .immediate)
                            strongSelf.mediaBackgroundNode.update(size: mediaBackgroundFrame.size, transition: .immediate)
                            strongSelf.buttonNode.backgroundColor = item.presentationData.theme.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                            
                            let _ = subtitleApply()
                            let _ = buttonTitleApply()
                                                        
                            let subtitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0) , y: mediaBackgroundFrame.minY + 128.0), size: subtitleLayout.size)
                            strongSelf.subtitleNode.frame = subtitleFrame
                            
                            let buttonTitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonTitleLayout.size.width) / 2.0), y: subtitleFrame.maxY + 19.0), size: buttonTitleLayout.size)
                            strongSelf.buttonTitleNode.frame = buttonTitleFrame
                            
                            let buttonSize = CGSize(width: buttonTitleLayout.size.width + 38.0, height: 15.0 + buttonTitleLayout.size.height)
                            strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonSize.width) / 2.0), y: subtitleFrame.maxY + 11.0), size: buttonSize)

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
                        }
                    })
                })
            })
        }
    }

    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)
        
        if let mediaBackgroundContent = self.mediaBackgroundContent {
            var backgroundFrame = mediaBackgroundContent.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            mediaBackgroundContent.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }
    
    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if self.mediaBackgroundNode.frame.contains(point) {
            return .openMessage
        } else {
            return .none
        }
    }
}
