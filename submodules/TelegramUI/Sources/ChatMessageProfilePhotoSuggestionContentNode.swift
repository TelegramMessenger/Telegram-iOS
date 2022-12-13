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

class ChatMessageProfilePhotoSuggestionContentNode: ChatMessageBubbleContentNode {
    private var mediaBackgroundContent: WallpaperBubbleBackgroundNode?
    private let mediaBackgroundNode: NavigationBackgroundNode
    private let titleNode: TextNode
    private let subtitleNode: TextNode
    private let imageNode: TransformImageNode
    
    private let buttonNode: HighlightTrackingButtonNode
    private let buttonStarsNode: PremiumStarsNode
    private let buttonTitleNode: TextNode
    
    private var absoluteRect: (CGRect, CGSize)?
    
    private let fetchDisposable = MetaDisposable()
            
    required init() {
        self.mediaBackgroundNode = NavigationBackgroundNode(color: .clear)
        self.mediaBackgroundNode.clipsToBounds = true
        self.mediaBackgroundNode.cornerRadius = 24.0
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        self.titleNode.displaysAsynchronously = false
        
        self.subtitleNode = TextNode()
        self.subtitleNode.isUserInteractionEnabled = false
        self.subtitleNode.displaysAsynchronously = false
        
        self.imageNode = TransformImageNode()
        
        self.buttonNode = HighlightTrackingButtonNode()
        self.buttonNode.clipsToBounds = true
        self.buttonNode.cornerRadius = 17.0
                
        self.buttonStarsNode = PremiumStarsNode()
        
        self.buttonTitleNode = TextNode()
        self.buttonTitleNode.isUserInteractionEnabled = false
        self.buttonTitleNode.displaysAsynchronously = false
        
        super.init()

        self.addSubnode(self.mediaBackgroundNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.subtitleNode)
        self.addSubnode(self.imageNode)
    
        self.addSubnode(self.buttonNode)
        self.buttonNode.addSubnode(self.buttonStarsNode)
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
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
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
                if let media = media as? TelegramMediaAction {
                    switch media.action {
                    case let .suggestedProfilePhoto(image):
                        currentMedia = image
                        break mediaLoop
                    default:
                        break
                    }
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
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeImageLayout = self.imageNode.asyncLayout()
        let makeSubtitleLayout = TextNode.asyncLayout(self.subtitleNode)
        let makeButtonTitleLayout = TextNode.asyncLayout(self.buttonTitleNode)
        
        let currentItem = self.item

        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
                        
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let width: CGFloat = 220.0
                let imageSize = CGSize(width: 100.0, height: 100.0)
                            
                let primaryTextColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                                
                var photo: TelegramMediaImage?
                if let media = item.message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .suggestedProfilePhoto(image) = media.action {
                    photo = image
                }
                
                var mediaUpdated = true
                if let photo = photo, let media = currentItem?.message.media.first(where: { $0 is TelegramMediaAction }) as? TelegramMediaAction, case let .suggestedProfilePhoto(maybeCurrentPhoto) = media.action, let currentPhoto = maybeCurrentPhoto {
                    mediaUpdated = !photo.isSemanticallyEqual(to: currentPhoto)
                }
                
                let isVideo = !(photo?.videoRepresentations.isEmpty ?? true)
                let fromYou = item.message.author?.id == item.context.account.peerId
                
                let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: isVideo ? item.presentationData.strings.Conversation_SuggestedVideoTitle : item.presentationData.strings.Conversation_SuggestedPhotoTitle, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let peerName = item.message.peers[item.message.id.peerId].flatMap { EnginePeer($0).compactDisplayTitle } ?? ""
                let text: String
                if fromYou {
                    text = isVideo ? item.presentationData.strings.Conversation_SuggestedVideoTextYou(peerName).string : item.presentationData.strings.Conversation_SuggestedPhotoTextYou(peerName).string
                } else {
                    text = isVideo ? item.presentationData.strings.Conversation_SuggestedVideoText(peerName).string : item.presentationData.strings.Conversation_SuggestedPhotoText(peerName).string
                }
                
                let (subtitleLayout, subtitleApply) = makeSubtitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: text, font: Font.regular(13.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
                
                let (buttonTitleLayout, buttonTitleApply) = makeButtonTitleLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: isVideo ? item.presentationData.strings.Conversation_SuggestedVideoView : item.presentationData.strings.Conversation_SuggestedPhotoView, font: Font.semibold(15.0), textColor: primaryTextColor, paragraphAlignment: .center), backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
                let backgroundSize = CGSize(width: width, height: titleLayout.size.height + subtitleLayout.size.height + 182.0)
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            if let photo = photo {
                                if mediaUpdated {
                                    strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(context: item.context, photoReference: .message(message: MessageReference(item.message), media: photo), displayAtSize: nil, storeToDownloadsPeerType: nil).start())
                                }
                                     
                                let updateImageSignal = chatMessagePhoto(postbox: item.context.account.postbox, photoReference: .message(message: MessageReference(item.message), media: photo), synchronousLoad: synchronousLoads)
                                strongSelf.imageNode.setSignal(updateImageSignal, attemptSynchronously: synchronousLoads)
                                
                                let arguments = TransformImageArguments(corners: ImageCorners(radius: imageSize.width / 2.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                                let apply = makeImageLayout(arguments)
                                apply()
                                
                                strongSelf.imageNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - imageSize.width) / 2.0), y: 13.0), size: imageSize)
                            }
                            
                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - width) / 2.0), y: 0.0), size: backgroundSize)
                            let mediaBackgroundFrame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                            strongSelf.mediaBackgroundNode.frame = mediaBackgroundFrame
                                                        
                            strongSelf.mediaBackgroundNode.updateColor(color: selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), enableBlur: dateFillNeedsBlur(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper), transition: .immediate)
                            strongSelf.mediaBackgroundNode.update(size: mediaBackgroundFrame.size, transition: .immediate)
                            strongSelf.buttonNode.backgroundColor = item.presentationData.theme.theme.overallDarkAppearance ? UIColor(rgb: 0xffffff, alpha: 0.12) : UIColor(rgb: 0x000000, alpha: 0.12)
                            
                            let _ = titleApply()
                            let _ = subtitleApply()
                            let _ = buttonTitleApply()
                                                        
                            let titleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - titleLayout.size.width) / 2.0) , y: mediaBackgroundFrame.minY + 127.0), size: titleLayout.size)
                            strongSelf.titleNode.frame = titleFrame
                            
                            let subtitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - subtitleLayout.size.width) / 2.0) , y: titleFrame.maxY + 2.0), size: subtitleLayout.size)
                            strongSelf.subtitleNode.frame = subtitleFrame
                            
                            let buttonTitleFrame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonTitleLayout.size.width) / 2.0), y: subtitleFrame.maxY + 18.0), size: buttonTitleLayout.size)
                            strongSelf.buttonTitleNode.frame = buttonTitleFrame
                            
                            let buttonSize = CGSize(width: buttonTitleLayout.size.width + 38.0, height: 34.0)
                            strongSelf.buttonNode.frame = CGRect(origin: CGPoint(x: mediaBackgroundFrame.minX + floorToScreenPixels((mediaBackgroundFrame.width - buttonSize.width) / 2.0), y: subtitleFrame.maxY + 10.0), size: buttonSize)
                            strongSelf.buttonStarsNode.frame = CGRect(origin: .zero, size: buttonSize)

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
