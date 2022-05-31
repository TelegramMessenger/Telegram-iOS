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
import UrlEscaping
import PhotoResources
import TelegramStringFormatting
import UniversalMediaPlayer
import TelegramUniversalVideoContent
import GalleryUI
import WallpaperBackgroundNode
import InvisibleInkDustNode

private func attributedServiceMessageString(theme: ChatPresentationThemeData, strings: PresentationStrings, nameDisplayOrder: PresentationPersonNameOrder, dateTimeFormat: PresentationDateTimeFormat, message: Message, accountPeerId: PeerId) -> NSAttributedString? {
    return universalServiceMessageString(presentationData: (theme.theme, theme.wallpaper), strings: strings, nameDisplayOrder: nameDisplayOrder, dateTimeFormat: dateTimeFormat, message: EngineMessage(message), accountPeerId: accountPeerId, forChatList: false)
}

class ChatMessageActionBubbleContentNode: ChatMessageBubbleContentNode {
    let labelNode: TextNode
    private var dustNode: InvisibleInkDustNode?
    var backgroundNode: WallpaperBubbleBackgroundNode?
    var backgroundColorNode: ASDisplayNode
    let backgroundMaskNode: ASImageNode
    var linkHighlightingNode: LinkHighlightingNode?
    
    private let mediaBackgroundNode: ASImageNode
    fileprivate var imageNode: TransformImageNode?
    fileprivate var videoNode: UniversalVideoNode?
    private var videoContent: NativeVideoContent?
    private var videoStartTimestamp: Double?
    private let fetchDisposable = MetaDisposable()

    private var cachedMaskBackgroundImage: (CGPoint, UIImage, [CGRect])?
    private var absoluteRect: (CGRect, CGSize)?
    
    required init() {
        self.labelNode = TextNode()
        self.labelNode.isUserInteractionEnabled = false
        self.labelNode.displaysAsynchronously = false

        self.backgroundColorNode = ASDisplayNode()
        self.backgroundMaskNode = ASImageNode()
        
        self.mediaBackgroundNode = ASImageNode()
        self.mediaBackgroundNode.displaysAsynchronously = false
        self.mediaBackgroundNode.displayWithoutProcessing = true
        
        super.init()

        self.addSubnode(self.labelNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchDisposable.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
    }
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let imageNode = self.imageNode, self.item?.message.id == messageId {
            return (imageNode, imageNode.bounds, { [weak self] in
                guard let strongSelf = self, let imageNode = strongSelf.imageNode else {
                    return (nil, nil)
                }
                
                let resultView = imageNode.view.snapshotContentTree(unhide: true)
                if let resultView = resultView, strongSelf.mediaBackgroundNode.supernode != nil, let backgroundView = strongSelf.mediaBackgroundNode.view.snapshotContentTree(unhide: true) {
                    let backgroundContainer = UIView()
                    
                    backgroundContainer.addSubview(backgroundView)
                    backgroundContainer.frame = CGRect(origin: CGPoint(x: -2.0, y: -2.0), size: CGSize(width: resultView.frame.width + 4.0, height: resultView.frame.height + 4.0))
                    backgroundView.frame = backgroundContainer.bounds
                    let viewWithBackground = UIView()
                    viewWithBackground.addSubview(backgroundContainer)
                    viewWithBackground.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: resultView.frame.size)
                    resultView.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: resultView.frame.size)
                    viewWithBackground.addSubview(resultView)
                    return (viewWithBackground, backgroundContainer)
                }
                
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
                    case let .photoUpdated(image):
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
        
        self.imageNode?.isHidden = mediaHidden
        self.mediaBackgroundNode.isHidden = mediaHidden
        return mediaHidden
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)

        let cachedMaskBackgroundImage = self.cachedMaskBackgroundImage
        
        return { item, layoutConstants, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
            
            let backgroundImage = PresentationResourcesChat.chatActionPhotoBackgroundImage(item.presentationData.theme.theme, wallpaper: !item.presentationData.theme.wallpaper.isEmpty)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let attributedString = attributedServiceMessageString(theme: item.presentationData.theme, strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, message: item.message, accountPeerId: item.context.account.peerId)
            
                var image: TelegramMediaImage?
                for media in item.message.media {
                    if let action = media as? TelegramMediaAction {
                        switch action.action {
                        case let .photoUpdated(img):
                            image = img
                        default:
                            break
                        }
                    }
                }
                
                let imageSize = CGSize(width: 212.0, height: 212.0)
                
                let (labelLayout, apply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: constrainedSize.width - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
                var labelRects = labelLayout.linesRects()
                if labelRects.count > 1 {
                    let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
                    for i in 0 ..< sortedIndices.count {
                        let index = sortedIndices[i]
                        for j in -1 ... 1 {
                            if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                                if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                                    labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                                    labelRects[index].size.width = labelRects[index + j].size.width
                                }
                            }
                        }
                    }
                }
                for i in 0 ..< labelRects.count {
                    labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
                    labelRects[i].size.height = 20.0
                    labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
                }

                let backgroundMaskImage: (CGPoint, UIImage)?
                var backgroundMaskUpdated = false
                if let (currentOffset, currentImage, currentRects) = cachedMaskBackgroundImage, currentRects == labelRects {
                    backgroundMaskImage = (currentOffset, currentImage)
                } else {
                    backgroundMaskImage = LinkHighlightingNode.generateImage(color: .black, inset: 0.0, innerRadius: 10.0, outerRadius: 10.0, rects: labelRects)
                    backgroundMaskUpdated = true
                }
            
                var backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
                
                if let _ = image {
                    backgroundSize.height += imageSize.height + 10
                }
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation, synchronousLoads, _ in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            let maskPath = UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: imageSize), cornerRadius: 15.5)

                            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - imageSize.width) / 2.0), y: labelLayout.size.height + 10 + 2), size: imageSize)
                            if let image = image {
                                let imageNode: TransformImageNode
                                if let current = strongSelf.imageNode {
                                    imageNode = current
                                } else {
                                    imageNode = TransformImageNode()
                                    let shape = CAShapeLayer()
                                    shape.path = maskPath.cgPath
                                    imageNode.layer.mask = shape
                                    strongSelf.imageNode = imageNode
                                    strongSelf.insertSubnode(imageNode, at: 0)
                                    strongSelf.insertSubnode(strongSelf.mediaBackgroundNode, at: 0)
                                }
                                strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(context: item.context, photoReference: .message(message: MessageReference(item.message), media: image), displayAtSize: nil, storeToDownloadsPeerType: nil).start())
                                let updateImageSignal = chatMessagePhoto(postbox: item.context.account.postbox, photoReference: .message(message: MessageReference(item.message), media: image), synchronousLoad: synchronousLoads)

                                imageNode.setSignal(updateImageSignal, attemptSynchronously: synchronousLoads)
                                
                                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                                let apply = imageNode.asyncLayout()(arguments)
                                apply()
                                
                                imageNode.frame = imageFrame
                                strongSelf.mediaBackgroundNode.frame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                            } else if let imageNode = strongSelf.imageNode {
                                strongSelf.mediaBackgroundNode.removeFromSupernode()
                                imageNode.removeFromSupernode()
                                strongSelf.imageNode = nil
                            }
                            strongSelf.mediaBackgroundNode.image = backgroundImage
                            
                            if let image = image, let video = image.videoRepresentations.last, let id = image.id?.id {
                                let videoFileReference = FileMediaReference.message(message: MessageReference(item.message), media: TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: 0), partialReference: nil, resource: video.resource, previewRepresentations: image.representations, videoThumbnails: [], immediateThumbnailData: image.immediateThumbnailData, mimeType: "video/mp4", size: nil, attributes: [.Animated, .Video(duration: 0, size: video.dimensions, flags: [])]))
                                let videoContent = NativeVideoContent(id: .profileVideo(id, "action"), fileReference: videoFileReference, streamVideo: isMediaStreamable(resource: video.resource) ? .conservative : .none, loopVideo: true, enableSound: false, fetchAutomatically: true, onlyFullSizeThumbnail: false, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true, continuePlayingWithoutSoundOnLostAudioSession: false, placeholderColor: .clear)
                                if videoContent.id != strongSelf.videoContent?.id {
                                    let mediaManager = item.context.sharedContext.mediaManager
                                    let videoNode = UniversalVideoNode(postbox: item.context.account.postbox, audioSession: mediaManager.audioSession, manager: mediaManager.universalVideoManager, decoration: GalleryVideoDecoration(), content: videoContent, priority: .secondaryOverlay)
                                    videoNode.isUserInteractionEnabled = false
                                    videoNode.ownsContentNodeUpdated = { [weak self] owns in
                                        if let strongSelf = self {
                                            strongSelf.videoNode?.isHidden = !owns
                                        }
                                    }
                                    strongSelf.videoContent = videoContent
                                    strongSelf.videoNode = videoNode
                                    
                                    videoNode.updateLayout(size: imageSize, transition: .immediate)
                                    videoNode.frame = imageFrame
                                    
                                    let shape = CAShapeLayer()
                                    shape.path = maskPath.cgPath
                                    videoNode.layer.mask = shape
                                    
                                    strongSelf.addSubnode(videoNode)
                                    
                                    videoNode.canAttachContent = true
                                    if let videoStartTimestamp = video.startTimestamp {
                                        videoNode.seek(videoStartTimestamp)
                                    } else {
                                        videoNode.seek(0.0)
                                    }
                                    videoNode.play()
                                    
                                }
                            } else if let videoNode = strongSelf.videoNode {
                                strongSelf.videoContent = nil
                                strongSelf.videoNode = nil
                                
                                videoNode.removeFromSupernode()
                            }
                                                        
                            let _ = apply()
                            
                            let labelFrame = CGRect(origin: CGPoint(x: 8.0, y: image != nil ? 2 : floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
                            strongSelf.labelNode.frame = labelFrame
                            strongSelf.backgroundColorNode.backgroundColor = selectDateFillStaticColor(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)

                            if !labelLayout.spoilers.isEmpty {
                                let dustColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper).primaryText
                                
                                let dustNode: InvisibleInkDustNode
                                if let current = strongSelf.dustNode {
                                    dustNode = current
                                } else {
                                    dustNode = InvisibleInkDustNode(textNode: nil)
                                    dustNode.isUserInteractionEnabled = false
                                    strongSelf.dustNode = dustNode
                                    strongSelf.insertSubnode(dustNode, aboveSubnode: strongSelf.labelNode)
                                }
                                dustNode.frame = labelFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 1.0)
                                dustNode.update(size: dustNode.frame.size, color: dustColor, textColor: dustColor, rects: labelLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: labelLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                            } else if let dustNode = strongSelf.dustNode {
                                dustNode.removeFromSupernode()
                                strongSelf.dustNode = nil
                            }
                            
                            let baseBackgroundFrame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)

                            if let (offset, image) = backgroundMaskImage {
                                if strongSelf.backgroundNode == nil {
                                    if let backgroundNode = item.controllerInteraction.presentationContext.backgroundNode?.makeBubbleBackground(for: .free) {
                                        strongSelf.backgroundNode = backgroundNode
                                        backgroundNode.addSubnode(strongSelf.backgroundColorNode)
                                        strongSelf.insertSubnode(backgroundNode, at: 0)
                                    }
                                }

                                if backgroundMaskUpdated, let backgroundNode = strongSelf.backgroundNode {
                                    if labelRects.count == 1 {
                                        backgroundNode.clipsToBounds = true
                                        backgroundNode.cornerRadius = labelRects[0].height / 2.0
                                        backgroundNode.view.mask = nil
                                    } else {
                                        backgroundNode.clipsToBounds = false
                                        backgroundNode.cornerRadius = 0.0
                                        backgroundNode.view.mask = strongSelf.backgroundMaskNode.view
                                    }
                                }

                                if let backgroundNode = strongSelf.backgroundNode {
                                    backgroundNode.frame = CGRect(origin: CGPoint(x: baseBackgroundFrame.minX + offset.x, y: baseBackgroundFrame.minY + offset.y), size: image.size)
                                    if let (rect, size) = strongSelf.absoluteRect {
                                        strongSelf.updateAbsoluteRect(rect, within: size)
                                    }
                                }
                                strongSelf.backgroundMaskNode.image = image
                                strongSelf.backgroundMaskNode.frame = CGRect(origin: CGPoint(), size: image.size)

                                strongSelf.backgroundColorNode.frame = CGRect(origin: CGPoint(), size: image.size)

                                strongSelf.cachedMaskBackgroundImage = (offset, image, labelRects)
                            }
                        }
                    })
                })
            })
        }
    }

    override func updateAbsoluteRect(_ rect: CGRect, within containerSize: CGSize) {
        self.absoluteRect = (rect, containerSize)

        if let backgroundNode = self.backgroundNode {
            var backgroundFrame = backgroundNode.frame
            backgroundFrame.origin.x += rect.minX
            backgroundFrame.origin.y += rect.minY
            backgroundNode.update(rect: backgroundFrame, within: containerSize, transition: .immediate)
        }
    }

    override func applyAbsoluteOffset(value: CGPoint, animationCurve: ContainedViewLayoutTransitionCurve, duration: Double) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offset(value: value, animationCurve: animationCurve, duration: duration)
        }
    }

    override func applyAbsoluteOffsetSpring(value: CGFloat, duration: Double, damping: CGFloat) {
        if let backgroundNode = self.backgroundNode {
            backgroundNode.offsetSpring(value: value, duration: duration, damping: damping)
        }
    }
    
    override func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [(CGRect, CGRect)]?
            let textNodeFrame = self.labelNode.frame
            if let point = point {
                if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.labelNode.lineAndAttributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
        
            if let rects = rects {
                var mappedRects: [CGRect] = []
                for i in 0 ..< rects.count {
                    let lineRect = rects[i].0
                    var itemRect = rects[i].1
                    itemRect.origin.x = floor((textNodeFrame.size.width - lineRect.width) / 2.0) + itemRect.origin.x
                    mappedRects.append(itemRect)
                }
                
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    let serviceColor = serviceMessageColorComponents(theme: item.presentationData.theme.theme, wallpaper: item.presentationData.theme.wallpaper)
                    linkHighlightingNode = LinkHighlightingNode(color: serviceColor.linkHighlight)
                    linkHighlightingNode.inset = 2.5
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.labelNode)
                }
                linkHighlightingNode.frame = self.labelNode.frame.offsetBy(dx: 0.0, dy: 1.5)
                linkHighlightingNode.updateRects(mappedRects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }

    override func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.labelNode.frame
        if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)), gesture == .tap {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.labelNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                return .url(url: url, concealed: concealed)
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return .peerMention(peerMention.peerId, peerMention.mention)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .textMention(peerName)
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return .botCommand(botCommand)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            }
        }
        if let imageNode = imageNode, imageNode.frame.contains(point) {
            return .openMessage
        }
        
        if let backgroundNode = self.backgroundNode, backgroundNode.frame.contains(point) {
            return .openMessage
        } else {
            return .none
        }
    }
}
