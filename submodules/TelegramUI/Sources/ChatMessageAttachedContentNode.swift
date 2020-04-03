import Foundation
import UIKit
import Postbox
import Display
import AsyncDisplayKit
import SwiftSignalKit
import TelegramCore
import SyncCore
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import TextFormat
import AccountContext
import UrlEscaping
import PhotoResources

private let buttonFont = Font.semibold(13.0)

enum ChatMessageAttachedContentActionIcon {
    case instant
}

struct ChatMessageAttachedContentNodeMediaFlags: OptionSet {
    var rawValue: Int32
    
    init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    init() {
        self.rawValue = 0
    }
    
    static let preferMediaInline = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 0)
    static let preferMediaBeforeText = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 1)
    static let preferMediaAspectFilled = ChatMessageAttachedContentNodeMediaFlags(rawValue: 1 << 2)
}

final class ChatMessageAttachedContentButtonNode: HighlightTrackingButtonNode {
    private let textNode: TextNode
    private let iconNode: ASImageNode
    private let highlightedTextNode: TextNode
    private let backgroundNode: ASImageNode
    
    private var regularImage: UIImage?
    private var highlightedImage: UIImage?
    private var regularIconImage: UIImage?
    private var highlightedIconImage: UIImage?
    
    var pressed: (() -> Void)?
    
    init() {
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.highlightedTextNode = TextNode()
        self.highlightedTextNode.isUserInteractionEnabled = false
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        
        self.iconNode = ASImageNode()
        self.iconNode.isLayerBacked = true
        self.iconNode.displayWithoutProcessing = true
        self.iconNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.highlightedTextNode)
        self.highlightedTextNode.isHidden = true
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backgroundNode.image = strongSelf.highlightedImage
                    strongSelf.iconNode.image = strongSelf.highlightedIconImage
                    strongSelf.textNode.isHidden = true
                    strongSelf.highlightedTextNode.isHidden = false
                } else {
                    UIView.transition(with: strongSelf.view, duration: 0.2, options: [.transitionCrossDissolve], animations: {
                        strongSelf.backgroundNode.image = strongSelf.regularImage
                        strongSelf.iconNode.image = strongSelf.regularIconImage
                        strongSelf.textNode.isHidden = false
                        strongSelf.highlightedTextNode.isHidden = true
                    }, completion: nil)
                }
            }
        }
        
        self.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc func buttonPressed() {
        self.pressed?()
    }
    
    static func asyncLayout(_ current: ChatMessageAttachedContentButtonNode?) -> (_ width: CGFloat, _ regularImage: UIImage, _ highlightedImage: UIImage, _ iconImage: UIImage?, _ highlightedIconImage: UIImage?, _ title: String, _ titleColor: UIColor, _ highlightedTitleColor: UIColor) -> (CGFloat, (CGFloat) -> (CGSize, () -> ChatMessageAttachedContentButtonNode)) {
        let previousRegularImage = current?.regularImage
        let previousHighlightedImage = current?.highlightedImage
        let previousRegularIconImage = current?.regularIconImage
        let previousHighlightedIconImage = current?.highlightedIconImage
        
        let maybeMakeTextLayout = (current?.textNode).flatMap(TextNode.asyncLayout)
        let maybeMakeHighlightedTextLayout = (current?.highlightedTextNode).flatMap(TextNode.asyncLayout)
        
        return { width, regularImage, highlightedImage, iconImage, highlightedIconImage, title, titleColor, highlightedTitleColor in            
            let targetNode: ChatMessageAttachedContentButtonNode
            if let current = current {
                targetNode = current
            } else {
                targetNode = ChatMessageAttachedContentButtonNode()
            }
            
            let makeTextLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeTextLayout = maybeMakeTextLayout {
                makeTextLayout = maybeMakeTextLayout
            } else {
                makeTextLayout = TextNode.asyncLayout(targetNode.textNode)
            }
            
            let makeHighlightedTextLayout: (TextNodeLayoutArguments) -> (TextNodeLayout, () -> TextNode)
            if let maybeMakeHighlightedTextLayout = maybeMakeHighlightedTextLayout {
                makeHighlightedTextLayout = maybeMakeHighlightedTextLayout
            } else {
                makeHighlightedTextLayout = TextNode.asyncLayout(targetNode.highlightedTextNode)
            }
            
            var updatedRegularImage: UIImage?
            if regularImage !== previousRegularImage {
                updatedRegularImage = regularImage
            }
            
            var updatedHighlightedImage: UIImage?
            if highlightedImage !== previousHighlightedImage {
                updatedHighlightedImage = highlightedImage
            }
            
            var updatedRegularIconImage: UIImage?
            if iconImage !== previousRegularIconImage {
                updatedRegularIconImage = iconImage
            }
            
            var updatedHighlightedIconImage: UIImage?
            if highlightedIconImage !== previousHighlightedIconImage {
                updatedHighlightedIconImage = highlightedIconImage
            }
            
            var iconWidth: CGFloat = 0.0
            if let iconImage = iconImage {
                iconWidth = iconImage.size.width + 5.0
            }
            
            let labelInset: CGFloat = 8.0
            
            let (textSize, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: buttonFont, textColor: titleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, width - labelInset * 2.0 - iconWidth), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
            
            let (_, highlightedTextApply) = makeHighlightedTextLayout(TextNodeLayoutArguments(attributedString: NSAttributedString(string: title, font: buttonFont, textColor: highlightedTitleColor), backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: max(1.0, width - labelInset * 2.0), height: CGFloat.greatestFiniteMagnitude), alignment: .left, cutout: nil, insets: UIEdgeInsets()))
            
            return (textSize.size.width + labelInset * 2.0, { refinedWidth in
                return (CGSize(width: refinedWidth, height: 33.0), {
                    targetNode.accessibilityLabel = title
                    
                    if let updatedRegularImage = updatedRegularImage {
                        targetNode.regularImage = updatedRegularImage
                        if !targetNode.textNode.isHidden {
                            targetNode.backgroundNode.image = updatedRegularImage
                        }
                    }
                    if let updatedHighlightedImage = updatedHighlightedImage {
                        targetNode.highlightedImage = updatedHighlightedImage
                        if targetNode.textNode.isHidden {
                            targetNode.backgroundNode.image = updatedHighlightedImage
                        }
                    }
                    if let updatedRegularIconImage = updatedRegularIconImage {
                        targetNode.regularIconImage = updatedRegularIconImage
                        if !targetNode.textNode.isHidden {
                            targetNode.iconNode.image = updatedRegularIconImage
                        }
                    }
                    if let updatedHighlightedIconImage = updatedHighlightedIconImage {
                        targetNode.highlightedIconImage = updatedHighlightedIconImage
                        if targetNode.iconNode.isHidden {
                            targetNode.iconNode.image = updatedHighlightedIconImage
                        }
                    }
                    
                    let _ = textApply()
                    let _ = highlightedTextApply()
                    
                    targetNode.backgroundNode.frame = CGRect(origin: CGPoint(), size: CGSize(width: refinedWidth, height: 33.0))
                    var textFrame = CGRect(origin: CGPoint(x: floor((refinedWidth - textSize.size.width) / 2.0), y: floor((34.0 - textSize.size.height) / 2.0)), size: textSize.size)
                    if let image = targetNode.iconNode.image {
                        textFrame.origin.x += floor(image.size.width / 2.0)
                        targetNode.iconNode.frame = CGRect(origin: CGPoint(x: textFrame.minX - image.size.width - 5.0, y: textFrame.minY + 2.0), size: image.size)
                        if targetNode.iconNode.supernode == nil {
                            targetNode.addSubnode(targetNode.iconNode)
                        }
                    } else if targetNode.iconNode.supernode != nil {
                        targetNode.iconNode.removeFromSupernode()
                    }
                    
                    targetNode.textNode.frame = textFrame
                    targetNode.highlightedTextNode.frame = targetNode.textNode.frame
                    
                    return targetNode
                })
            })
        }
    }
}

final class ChatMessageAttachedContentNode: ASDisplayNode {
    private let lineNode: ASImageNode
    private let textNode: TextNode
    private let inlineImageNode: TransformImageNode
    private var contentImageNode: ChatMessageInteractiveMediaNode?
    private var contentInstantVideoNode: ChatMessageInteractiveInstantVideoNode?
    private var contentFileNode: ChatMessageInteractiveFileNode?
    private var buttonNode: ChatMessageAttachedContentButtonNode?
    
    private let statusNode: ChatMessageDateAndStatusNode
    private var additionalImageBadgeNode: ChatMessageInteractiveMediaBadge?
    private var linkHighlightingNode: LinkHighlightingNode?
    
    private var context: AccountContext?
    private var message: Message?
    private var media: Media?
    private var theme: ChatPresentationThemeData?
    
    var openMedia: ((InteractiveMediaNodeActivateContent) -> Void)?
    var activateAction: (() -> Void)?
    
    var visibility: ListViewItemNodeVisibility = .none {
        didSet {
            self.contentImageNode?.visibility = self.visibility != .none
            self.contentInstantVideoNode?.visibility = self.visibility != .none
        }
    }
    
    override init() {
        self.lineNode = ASImageNode()
        self.lineNode.isLayerBacked = true
        self.lineNode.displaysAsynchronously = false
        self.lineNode.displayWithoutProcessing = true
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = true
        self.textNode.contentsScale = UIScreenScale
        self.textNode.contentMode = .topLeft
        
        self.inlineImageNode = TransformImageNode()
        self.inlineImageNode.contentAnimations = [.subsequentUpdates]
        self.inlineImageNode.isLayerBacked = !smartInvertColorsEnabled()
        self.inlineImageNode.displaysAsynchronously = false
        
        self.statusNode = ChatMessageDateAndStatusNode()
        
        super.init()
        
        self.addSubnode(self.lineNode)
        self.addSubnode(self.textNode)
        
        self.addSubnode(self.statusNode)
    }
    
    func asyncLayout() -> (_ presentationData: ChatPresentationData, _ automaticDownloadSettings: MediaAutoDownloadSettings, _ associatedData: ChatMessageItemAssociatedData, _ attributes: ChatMessageEntryAttributes, _ context: AccountContext, _ controllerInteraction: ChatControllerInteraction, _ message: Message, _ messageRead: Bool, _ title: String?, _ subtitle: NSAttributedString?, _ text: String?, _ entities: [MessageTextEntity]?, _ media: (Media, ChatMessageAttachedContentNodeMediaFlags)?, _ mediaBadge: String?, _ actionIcon: ChatMessageAttachedContentActionIcon?, _ actionTitle: String?, _ displayLine: Bool, _ layoutConstants: ChatMessageItemLayoutConstants, _ constrainedSize: CGSize) -> (CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool) -> Void))) {
        let textAsyncLayout = TextNode.asyncLayout(self.textNode)
        let currentImage = self.media as? TelegramMediaImage
        let imageLayout = self.inlineImageNode.asyncLayout()
        let statusLayout = self.statusNode.asyncLayout()
        let contentImageLayout = ChatMessageInteractiveMediaNode.asyncLayout(self.contentImageNode)
        let contentFileLayout = ChatMessageInteractiveFileNode.asyncLayout(self.contentFileNode)
        let contentInstantVideoLayout = ChatMessageInteractiveInstantVideoNode.asyncLayout(self.contentInstantVideoNode)
        
        let makeButtonLayout = ChatMessageAttachedContentButtonNode.asyncLayout(self.buttonNode)
        
        let currentAdditionalImageBadgeNode = self.additionalImageBadgeNode
        
        return { presentationData, automaticDownloadSettings, associatedData, attributes, context, controllerInteraction, message, messageRead, title, subtitle, text, entities, mediaAndFlags, mediaBadge, actionIcon, actionTitle, displayLine, layoutConstants, constrainedSize in
            let fontSize: CGFloat = floor(presentationData.fontSize.baseDisplaySize * 15.0 / 17.0)
            
            let titleFont = Font.semibold(fontSize)
            let textFont = Font.regular(fontSize)
            let textBoldFont = Font.semibold(fontSize)
            let textItalicFont = Font.italic(fontSize)
            let textBoldItalicFont = Font.semiboldItalic(fontSize)
            let textFixedFont = Font.regular(fontSize)
            let textBlockQuoteFont = Font.regular(fontSize)
            
            let incoming = message.effectivelyIncoming(context.account.peerId)
            
            var horizontalInsets = UIEdgeInsets(top: 0.0, left: 12.0, bottom: 0.0, right: 12.0)
            if displayLine {
                horizontalInsets.left += 10.0
            }
            
            var preferMediaBeforeText = false
            var preferMediaAspectFilled = false
            if let (_, flags) = mediaAndFlags {
                preferMediaBeforeText = flags.contains(.preferMediaBeforeText)
                preferMediaAspectFilled = flags.contains(.preferMediaAspectFilled)
            }
            
            var contentMode: InteractiveMediaNodeContentMode = preferMediaAspectFilled ? .aspectFill : .aspectFit
            
            var edited = false
            if attributes.updatingMedia != nil {
                edited = true
            }
            var viewCount: Int?
            for attribute in message.attributes {
                if let attribute = attribute as? EditedMessageAttribute {
                    edited = !attribute.isHidden
                } else if let attribute = attribute as? ViewCountMessageAttribute {
                    viewCount = attribute.count
                }
            }
            
            var dateReactions: [MessageReaction] = []
            var dateReactionCount = 0
            if let reactionsAttribute = mergedMessageReactions(attributes: message.attributes), !reactionsAttribute.reactions.isEmpty {
                for reaction in reactionsAttribute.reactions {
                    if reaction.isSelected {
                        dateReactions.insert(reaction, at: 0)
                    } else {
                        dateReactions.append(reaction)
                    }
                    dateReactionCount += Int(reaction.count)
                }
            }
            
            let dateText = stringForMessageTimestampStatus(accountPeerId: context.account.peerId, message: message, dateTimeFormat: presentationData.dateTimeFormat, nameDisplayOrder: presentationData.nameDisplayOrder, strings: presentationData.strings, reactionCount: dateReactionCount)
            
            var webpageGalleryMediaCount: Int?
            for media in message.media {
                if let media = media as? TelegramMediaWebpage {
                    if case let .Loaded(content) = media.content, let instantPage = content.instantPage, let image = content.image {
                        switch instantPageType(of: content) {
                            case .album:
                                let count = instantPageGalleryMedia(webpageId: media.webpageId, page: instantPage, galleryMedia: image).count
                                if count > 1 {
                                    webpageGalleryMediaCount = count
                                }
                            default:
                                break
                        }
                    }
                }
            }
            
            var textString: NSAttributedString?
            var inlineImageDimensions: CGSize?
            var inlineImageSize: CGSize?
            var updateInlineImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            var textCutout = TextNodeCutout()
            var initialWidth: CGFloat = CGFloat.greatestFiniteMagnitude
            var refineContentImageLayout: ((CGSize, Bool, Bool, ImageCorners) -> (CGFloat, (CGFloat) -> (CGSize, (ContainedViewLayoutTransition, Bool) -> ChatMessageInteractiveMediaNode)))?
            var refineContentFileLayout: ((CGSize) -> (CGFloat, (CGFloat) -> (CGSize, (Bool) -> ChatMessageInteractiveFileNode)))?

            var contentInstantVideoSizeAndApply: (ChatMessageInstantVideoItemLayoutResult, (ChatMessageInstantVideoItemLayoutData, ContainedViewLayoutTransition) -> ChatMessageInteractiveInstantVideoNode)?
            
            let string = NSMutableAttributedString()
            var notEmpty = false
            
            let messageTheme = incoming ? presentationData.theme.theme.chat.message.incoming : presentationData.theme.theme.chat.message.outgoing
            
            if let title = title, !title.isEmpty {
                string.append(NSAttributedString(string: title, font: titleFont, textColor: messageTheme.accentTextColor))
                notEmpty = true
            }
            
            if let subtitle = subtitle, subtitle.length > 0 {
                if notEmpty {
                    string.append(NSAttributedString(string: "\n", font: textFont, textColor: messageTheme.primaryTextColor))
                }
                let updatedSubtitle = NSMutableAttributedString()
                updatedSubtitle.append(subtitle)
                updatedSubtitle.addAttribute(.foregroundColor, value: messageTheme.primaryTextColor, range: NSMakeRange(0, subtitle.length))
                updatedSubtitle.addAttribute(.font, value: titleFont, range: NSMakeRange(0, subtitle.length))
                string.append(updatedSubtitle)
                notEmpty = true
            }
            
            if let text = text, !text.isEmpty {
                if notEmpty {
                    string.append(NSAttributedString(string: "\n", font: textFont, textColor: messageTheme.primaryTextColor))
                }
                if let entities = entities {
                    string.append(stringWithAppliedEntities(text, entities: entities, baseColor: messageTheme.primaryTextColor, linkColor: messageTheme.linkTextColor, baseFont: textFont, linkFont: textFont, boldFont: textBoldFont, italicFont: textItalicFont, boldItalicFont: textBoldItalicFont, fixedFont: textFixedFont, blockQuoteFont: textBlockQuoteFont))
                } else {
                    string.append(NSAttributedString(string: text + "\n", font: textFont, textColor: messageTheme.primaryTextColor))
                }
                notEmpty = true
            }
            
            textString = string
            if string.length > 1000 {
                textString = string.attributedSubstring(from: NSMakeRange(0, 1000))
            }
            
            var automaticPlayback = false
            
            var skipStandardStatus = false
            
            if let (media, flags) = mediaAndFlags {
                if let file = media as? TelegramMediaFile {
                    if file.mimeType == "application/x-tgtheme-ios", let size = file.size, size < 16 * 1024 {
                        let (_, initialImageWidth, refineLayout) = contentImageLayout(context, presentationData.theme.theme, presentationData.strings, presentationData.dateTimeFormat, message, attributes, file, .full, associatedData.automaticDownloadPeerType, .constrained(CGSize(width: constrainedSize.width - horizontalInsets.left - horizontalInsets.right, height: constrainedSize.height)), layoutConstants, contentMode)
                        initialWidth = initialImageWidth + horizontalInsets.left + horizontalInsets.right
                        refineContentImageLayout = refineLayout
                    } else if file.isInstantVideo {
                        let automaticDownload = shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: file)
                        let (videoLayout, apply) = contentInstantVideoLayout(ChatMessageBubbleContentItem(context: context, controllerInteraction: controllerInteraction, message: message, read: messageRead, presentationData: presentationData, associatedData: associatedData, attributes: attributes), constrainedSize.width - horizontalInsets.left - horizontalInsets.right, CGSize(width: 212.0, height: 212.0), .bubble, automaticDownload)
                        initialWidth = videoLayout.contentSize.width + videoLayout.overflowLeft + videoLayout.overflowRight
                        contentInstantVideoSizeAndApply = (videoLayout, apply)
                    } else if file.isVideo {
                        var automaticDownload: InteractiveMediaNodeAutodownloadMode = .none
                        
                        if shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: file) {
                            automaticDownload = .full
                        } else if shouldPredownloadMedia(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, media: file) {
                            automaticDownload = .prefetch
                        }
                        if file.isAnimated {
                            automaticPlayback = automaticDownloadSettings.autoplayGifs
                        } else if file.isVideo && automaticDownloadSettings.autoplayVideos {
                            var willDownloadOrLocal = false
                            if case .full = automaticDownload {
                                willDownloadOrLocal = true
                            } else {
                                willDownloadOrLocal = context.account.postbox.mediaBox.completedResourcePath(file.resource) != nil
                            }
                            if willDownloadOrLocal {
                                automaticPlayback = true
                                contentMode = .aspectFill
                            }
                        }

                        let (_, initialImageWidth, refineLayout) = contentImageLayout(context, presentationData.theme.theme, presentationData.strings, presentationData.dateTimeFormat, message, attributes, file, automaticDownload, associatedData.automaticDownloadPeerType, .constrained(CGSize(width: constrainedSize.width - horizontalInsets.left - horizontalInsets.right, height: constrainedSize.height)), layoutConstants, contentMode)
                        initialWidth = initialImageWidth + horizontalInsets.left + horizontalInsets.right
                        refineContentImageLayout = refineLayout
                    } else if file.isSticker || file.isAnimatedSticker {
                        let automaticDownload = shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: file)
                        let (_, initialImageWidth, refineLayout) = contentImageLayout(context, presentationData.theme.theme, presentationData.strings, presentationData.dateTimeFormat, message, attributes, file, automaticDownload ? .full : .none, associatedData.automaticDownloadPeerType, .constrained(CGSize(width: constrainedSize.width - horizontalInsets.left - horizontalInsets.right, height: constrainedSize.height)), layoutConstants, contentMode)
                        initialWidth = initialImageWidth + horizontalInsets.left + horizontalInsets.right
                        refineContentImageLayout = refineLayout
                    } else {
                        let automaticDownload = shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: file)
                        
                        let statusType: ChatMessageDateAndStatusType
                        if message.effectivelyIncoming(context.account.peerId) {
                            statusType = .BubbleIncoming
                        } else {
                            if message.flags.contains(.Failed) {
                                statusType = .BubbleOutgoing(.Failed)
                            } else if (message.flags.isSending && !message.isSentOrAcknowledged) || attributes.updatingMedia != nil {
                                statusType = .BubbleOutgoing(.Sending)
                            } else {
                                statusType = .BubbleOutgoing(.Sent(read: messageRead))
                            }
                        }
                        
                        let (_, refineLayout) = contentFileLayout(context, presentationData, message, attributes, file, automaticDownload, message.effectivelyIncoming(context.account.peerId), false, associatedData.forcedResourceStatus, statusType, CGSize(width: constrainedSize.width - horizontalInsets.left - horizontalInsets.right, height: constrainedSize.height))
                        refineContentFileLayout = refineLayout
                    }
                } else if let image = media as? TelegramMediaImage {
                    if !flags.contains(.preferMediaInline) {
                        let automaticDownload = shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: image)
                        let (_, initialImageWidth, refineLayout) = contentImageLayout(context, presentationData.theme.theme, presentationData.strings, presentationData.dateTimeFormat, message, attributes, image, automaticDownload ? .full : .none, associatedData.automaticDownloadPeerType, .constrained(CGSize(width: constrainedSize.width - horizontalInsets.left - horizontalInsets.right, height: constrainedSize.height)), layoutConstants, contentMode)
                        initialWidth = initialImageWidth + horizontalInsets.left + horizontalInsets.right
                        refineContentImageLayout = refineLayout
                    } else if let dimensions = largestImageRepresentation(image.representations)?.dimensions {
                        inlineImageDimensions = dimensions.cgSize
                        
                        if image != currentImage {
                            updateInlineImageSignal = chatWebpageSnippetPhoto(account: context.account, photoReference: .message(message: MessageReference(message), media: image))
                        }
                    }
                } else if let image = media as? TelegramMediaWebFile {
                    let automaticDownload = shouldDownloadMediaAutomatically(settings: automaticDownloadSettings, peerType: associatedData.automaticDownloadPeerType, networkType: associatedData.automaticDownloadNetworkType, authorPeerId: message.author?.id, contactsPeerIds: associatedData.contactsPeerIds, media: image)
                    let (_, initialImageWidth, refineLayout) = contentImageLayout(context, presentationData.theme.theme, presentationData.strings, presentationData.dateTimeFormat, message, attributes, image, automaticDownload ? .full : .none, associatedData.automaticDownloadPeerType, .constrained(CGSize(width: constrainedSize.width - horizontalInsets.left - horizontalInsets.right, height: constrainedSize.height)), layoutConstants, contentMode)
                    initialWidth = initialImageWidth + horizontalInsets.left + horizontalInsets.right
                    refineContentImageLayout = refineLayout
                } else if let wallpaper = media as? WallpaperPreviewMedia {
                    let (_, initialImageWidth, refineLayout) = contentImageLayout(context, presentationData.theme.theme, presentationData.strings, presentationData.dateTimeFormat, message, attributes, wallpaper, .full, associatedData.automaticDownloadPeerType, .constrained(CGSize(width: constrainedSize.width - horizontalInsets.left - horizontalInsets.right, height: constrainedSize.height)), layoutConstants, contentMode)
                    initialWidth = initialImageWidth + horizontalInsets.left + horizontalInsets.right
                    refineContentImageLayout = refineLayout
                    if case let .file(_, _, _, _, isTheme, _) = wallpaper.content, isTheme {
                        skipStandardStatus = true
                    }
                }
            }
            
            if let _ = inlineImageDimensions {
                inlineImageSize = CGSize(width: 54.0, height: 54.0)
                
                if let inlineImageSize = inlineImageSize {
                    textCutout.topRight = CGSize(width: inlineImageSize.width + 10.0, height: inlineImageSize.height + 10.0)
                }
            }
            
            return (initialWidth, { constrainedSize, position in
                var insets = UIEdgeInsets(top: 0.0, left: horizontalInsets.left, bottom: 5.0, right: horizontalInsets.right)
                switch position {
                    case .linear(.None, _):
                        insets.top += 8.0
                    default:
                        break
                }
                
                var statusInText = false
                
                var statusSizeAndApply: (CGSize, (Bool) -> Void)?
                
                let textConstrainedSize = CGSize(width: constrainedSize.width - insets.left - insets.right, height: constrainedSize.height - insets.top - insets.bottom)
                
                var additionalImageBadgeContent: ChatMessageInteractiveMediaBadgeContent?
                
                switch position {
                    case .linear(_, .None):
                        let imageMode = !((refineContentImageLayout == nil && refineContentFileLayout == nil && contentInstantVideoSizeAndApply == nil) || preferMediaBeforeText)
                        statusInText = !imageMode
                        
                        
                        if let count = webpageGalleryMediaCount {
                            additionalImageBadgeContent = .text(inset: 0.0, backgroundColor: presentationData.theme.theme.chat.message.mediaDateAndStatusFillColor, foregroundColor: presentationData.theme.theme.chat.message.mediaDateAndStatusTextColor, text: NSAttributedString(string: presentationData.strings.Items_NOfM("1", "\(count)").0))
                            skipStandardStatus = imageMode
                        } else if let mediaBadge = mediaBadge {
                            additionalImageBadgeContent = .text(inset: 0.0, backgroundColor: presentationData.theme.theme.chat.message.mediaDateAndStatusFillColor, foregroundColor: presentationData.theme.theme.chat.message.mediaDateAndStatusTextColor, text: NSAttributedString(string: mediaBadge))
                        }
                        
                        if !skipStandardStatus {
                            let statusType: ChatMessageDateAndStatusType
                            if message.effectivelyIncoming(context.account.peerId) {
                                if imageMode {
                                    statusType = .ImageIncoming
                                } else {
                                    statusType = .BubbleIncoming
                                }
                            } else {
                                if message.flags.contains(.Failed) {
                                    if imageMode {
                                        statusType = .ImageOutgoing(.Failed)
                                    } else {
                                        statusType = .BubbleOutgoing(.Failed)
                                    }
                                } else if (message.flags.isSending && !message.isSentOrAcknowledged) || attributes.updatingMedia != nil {
                                    if imageMode {
                                        statusType = .ImageOutgoing(.Sending)
                                    } else {
                                        statusType = .BubbleOutgoing(.Sending)
                                    }
                                } else {
                                    if imageMode {
                                        statusType = .ImageOutgoing(.Sent(read: messageRead))
                                    } else {
                                        statusType = .BubbleOutgoing(.Sent(read: messageRead))
                                    }
                                }
                            }
                        
                            statusSizeAndApply = statusLayout(context, presentationData, edited, viewCount, dateText, statusType, textConstrainedSize, dateReactions)
                        }
                    default:
                        break
                }
                
                var updatedAdditionalImageBadge: ChatMessageInteractiveMediaBadge?
                if let _ = additionalImageBadgeContent {
                    updatedAdditionalImageBadge = currentAdditionalImageBadgeNode ?? ChatMessageInteractiveMediaBadge()
                }
                
                var upatedTextCutout = textCutout
                if statusInText, let (statusSize, _) = statusSizeAndApply {
                    upatedTextCutout.bottomRight = statusSize
                }
                
                let (textLayout, textApply) = textAsyncLayout(TextNodeLayoutArguments(attributedString: textString, backgroundColor: nil, maximumNumberOfLines: 12, truncationType: .end, constrainedSize: textConstrainedSize, alignment: .natural, cutout: upatedTextCutout, insets: UIEdgeInsets()))
                
                var textFrame = CGRect(origin: CGPoint(), size: textLayout.size)
                
                var statusFrame: CGRect?
                
                if statusInText, let (statusSize, _) = statusSizeAndApply {
                    var frame = CGRect(origin: CGPoint(x: textFrame.maxX - statusSize.width, y: textFrame.maxY - statusSize.height), size: statusSize)
                    
                    /*let trailingLineWidth = textLayout.trailingLineWidth
                    if textLayout.size.width - trailingLineWidth >= statusSize.width {
                        frame.origin = CGPoint(x: textFrame.maxX - statusSize.width, y: textFrame.maxY - statusSize.height)
                    } else if trailingLineWidth + statusSize.width < textConstrainedSize.width {
                        frame.origin = CGPoint(x: textFrame.minX + trailingLineWidth, y: textFrame.maxY - statusSize.height)
                    } else {
                        frame.origin = CGPoint(x: textFrame.maxX - statusSize.width, y: textFrame.maxY)
                    }*/
                    
                    if let inlineImageSize = inlineImageSize {
                        if frame.origin.y < inlineImageSize.height + 4.0 {
                            frame.origin.y = inlineImageSize.height + 4.0
                        }
                    }
                    
                    frame = frame.offsetBy(dx: insets.left, dy: insets.top)
                    statusFrame = frame
                }
                
                textFrame = textFrame.offsetBy(dx: insets.left, dy: insets.top)
                
                let lineImage = incoming ? PresentationResourcesChat.chatBubbleVerticalLineIncomingImage(presentationData.theme.theme) : PresentationResourcesChat.chatBubbleVerticalLineOutgoingImage(presentationData.theme.theme)
                
                var boundingSize = textFrame.size
                var lineHeight = textLayout.rawTextSize.height
                if let statusFrame = statusFrame {
                    boundingSize = textFrame.union(statusFrame).size
                    if let _ = actionTitle {
                        lineHeight = boundingSize.height
                    }
                }
                if let inlineImageSize = inlineImageSize {
                    if boundingSize.height < inlineImageSize.height {
                        boundingSize.height = inlineImageSize.height
                    }
                    if lineHeight < inlineImageSize.height {
                        lineHeight = inlineImageSize.height
                    }
                }
                
                var finalizeContentImageLayout: ((CGFloat) -> (CGSize, (ContainedViewLayoutTransition, Bool) -> ChatMessageInteractiveMediaNode))?
                if let refineContentImageLayout = refineContentImageLayout {
                    let (refinedWidth, finalizeImageLayout) = refineContentImageLayout(textConstrainedSize, automaticPlayback, true, ImageCorners(radius: 4.0))
                    finalizeContentImageLayout = finalizeImageLayout
                    
                    boundingSize.width = max(boundingSize.width, refinedWidth)
                }
                var finalizeContentFileLayout: ((CGFloat) -> (CGSize, (Bool) -> ChatMessageInteractiveFileNode))?
                if let refineContentFileLayout = refineContentFileLayout {
                    let (refinedWidth, finalizeFileLayout) = refineContentFileLayout(textConstrainedSize)
                    finalizeContentFileLayout = finalizeFileLayout
                    
                    boundingSize.width = max(boundingSize.width, refinedWidth)
                }
                
                if let (videoLayout, _) = contentInstantVideoSizeAndApply {
                    boundingSize.width = max(boundingSize.width, videoLayout.contentSize.width + videoLayout.overflowLeft + videoLayout.overflowRight)
                }
                
                lineHeight += insets.top + insets.bottom
                
                var imageApply: (() -> Void)?
                if let inlineImageSize = inlineImageSize, let inlineImageDimensions = inlineImageDimensions {
                    let imageCorners = ImageCorners(topLeft: .Corner(4.0), topRight: .Corner(4.0), bottomLeft: .Corner(4.0), bottomRight: .Corner(4.0))
                    let arguments = TransformImageArguments(corners: imageCorners, imageSize: inlineImageDimensions.aspectFilled(inlineImageSize), boundingSize: inlineImageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: incoming ? presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor)
                    imageApply = imageLayout(arguments)
                }
                
                var continueActionButtonLayout: ((CGFloat) -> (CGSize, () -> ChatMessageAttachedContentButtonNode))?
                if let actionTitle = actionTitle {
                    let buttonImage: UIImage
                    let buttonHighlightedImage: UIImage
                    var buttonIconImage: UIImage?
                    var buttonHighlightedIconImage: UIImage?
                    let titleColor: UIColor
                    let titleHighlightedColor: UIColor
                    if incoming {
                        buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonIncoming(presentationData.theme.theme)!
                        buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonIncoming(presentationData.theme.theme)!
                        if let actionIcon = actionIcon, case .instant = actionIcon {
                            buttonIconImage = PresentationResourcesChat.chatMessageAttachedContentButtonIconInstantIncoming(presentationData.theme.theme)!
                            buttonHighlightedIconImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonIconInstantIncoming(presentationData.theme.theme, wallpaper: !presentationData.theme.wallpaper.isEmpty)!
                        }
                        titleColor = presentationData.theme.theme.chat.message.incoming.accentTextColor
                        let bubbleColor = bubbleColorComponents(theme: presentationData.theme.theme, incoming: true, wallpaper: !presentationData.theme.wallpaper.isEmpty)
                        titleHighlightedColor = bubbleColor.fill
                    } else {
                        buttonImage = PresentationResourcesChat.chatMessageAttachedContentButtonOutgoing(presentationData.theme.theme)!
                        buttonHighlightedImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonOutgoing(presentationData.theme.theme)!
                        if let actionIcon = actionIcon, case .instant = actionIcon {
                            buttonIconImage = PresentationResourcesChat.chatMessageAttachedContentButtonIconInstantOutgoing(presentationData.theme.theme)!
                            buttonHighlightedIconImage = PresentationResourcesChat.chatMessageAttachedContentHighlightedButtonIconInstantOutgoing(presentationData.theme.theme, wallpaper: !presentationData.theme.wallpaper.isEmpty)!
                        }
                        titleColor = presentationData.theme.theme.chat.message.outgoing.accentTextColor
                        let bubbleColor = bubbleColorComponents(theme: presentationData.theme.theme, incoming: false, wallpaper: !presentationData.theme.wallpaper.isEmpty)
                        titleHighlightedColor = bubbleColor.fill
                    }
                    let (buttonWidth, continueLayout) = makeButtonLayout(constrainedSize.width, buttonImage, buttonHighlightedImage, buttonIconImage, buttonHighlightedIconImage, actionTitle, titleColor, titleHighlightedColor)
                    boundingSize.width = max(buttonWidth, boundingSize.width)
                    continueActionButtonLayout = continueLayout
                }
                
                boundingSize.width += insets.left + insets.right
                boundingSize.height += insets.top + insets.bottom
                
                return (boundingSize.width, { boundingWidth in
                    var adjustedBoundingSize = boundingSize
                    var adjustedLineHeight = lineHeight
                    
                    var imageFrame: CGRect?
                    if let inlineImageSize = inlineImageSize {
                        imageFrame = CGRect(origin: CGPoint(x: boundingWidth - inlineImageSize.width - insets.right, y: 0.0), size: inlineImageSize)
                    }
                    
                    var contentImageSizeAndApply: (CGSize, (ContainedViewLayoutTransition, Bool) -> ChatMessageInteractiveMediaNode)?
                    if let finalizeContentImageLayout = finalizeContentImageLayout {
                        let (size, apply) = finalizeContentImageLayout(boundingWidth - insets.left - insets.right)
                        contentImageSizeAndApply = (size, apply)
                        
                        var imageHeightAddition = size.height
                        if textFrame.size.height > CGFloat.ulpOfOne {
                            imageHeightAddition += 2.0
                        }
                        
                        adjustedBoundingSize.height += imageHeightAddition + 5.0
                        adjustedLineHeight += imageHeightAddition + 4.0
                        
                        if !statusInText, let (statusSize, _) = statusSizeAndApply {
                            statusFrame = CGRect(origin: CGPoint(), size: statusSize)
                        }
                    }
                    
                    var contentFileSizeAndApply: (CGSize, (Bool) -> ChatMessageInteractiveFileNode)?
                    if let finalizeContentFileLayout = finalizeContentFileLayout {
                        let (size, apply) = finalizeContentFileLayout(boundingWidth - insets.left - insets.right)
                        contentFileSizeAndApply = (size, apply)
                        
                        var imageHeightAddition = size.height + 6.0
                        if textFrame.size.height > CGFloat.ulpOfOne {
                            imageHeightAddition += 6.0
                        }
                        
                        adjustedBoundingSize.height += imageHeightAddition + 5.0
                        adjustedLineHeight += imageHeightAddition + 4.0
                    }
                    
                    if let (videoLayout, _) = contentInstantVideoSizeAndApply {
                        let imageHeightAddition = videoLayout.contentSize.height + 6.0
                        if textFrame.size.height > CGFloat.ulpOfOne {
                            //imageHeightAddition += 2.0
                        }
                    
                        adjustedBoundingSize.height += imageHeightAddition// + 5.0
                        adjustedLineHeight += imageHeightAddition// + 4.0
                    }
                    
                    var actionButtonSizeAndApply: ((CGSize, () -> ChatMessageAttachedContentButtonNode))?
                    if let continueActionButtonLayout = continueActionButtonLayout {
                        let (size, apply) = continueActionButtonLayout(boundingWidth - 13.0 - insets.right)
                        actionButtonSizeAndApply = (size, apply)
                        adjustedBoundingSize.width = max(adjustedBoundingSize.width, insets.left + size.width + insets.right)
                        adjustedBoundingSize.height += 7.0 + size.height
                    }
                    
                    var adjustedStatusFrame: CGRect?
                    if statusInText, let statusFrame = statusFrame {
                        adjustedStatusFrame = CGRect(origin: CGPoint(x: boundingWidth - statusFrame.size.width - insets.right, y: statusFrame.origin.y), size: statusFrame.size)
                    }
                    
                    adjustedBoundingSize.width = max(boundingWidth, adjustedBoundingSize.width)
 
                    return (adjustedBoundingSize, { [weak self] animation, synchronousLoads in
                        if let strongSelf = self {
                            strongSelf.context = context
                            strongSelf.message = message
                            strongSelf.media = mediaAndFlags?.0
                            strongSelf.theme = presentationData.theme
                            
                            var hasAnimation = true
                            var transition: ContainedViewLayoutTransition = .immediate
                            switch animation {
                                case .None, .Crossfade:
                                    hasAnimation = false
                                case let .System(duration):
                                    hasAnimation = true
                                    transition = .animated(duration: duration, curve: .easeInOut)
                            }
                            
                            strongSelf.lineNode.image = lineImage
                            strongSelf.lineNode.frame = CGRect(origin: CGPoint(x: 13.0, y: insets.top), size: CGSize(width: 2.0, height: adjustedLineHeight - insets.top - insets.bottom - 2.0))
                            strongSelf.lineNode.isHidden = !displayLine
                            
                            let _ = textApply()
                            
                            if let imageFrame = imageFrame {
                                if let updateImageSignal = updateInlineImageSignal {
                                    strongSelf.inlineImageNode.setSignal(updateImageSignal)
                                }
                                
                                strongSelf.inlineImageNode.frame = imageFrame
                                if strongSelf.inlineImageNode.supernode == nil {
                                    strongSelf.addSubnode(strongSelf.inlineImageNode)
                                }
                                
                                if let imageApply = imageApply {
                                    imageApply()
                                }
                            } else if strongSelf.inlineImageNode.supernode != nil {
                                strongSelf.inlineImageNode.removeFromSupernode()
                            }
                            
                            var contentMediaHeight: CGFloat?
                            
                            if let (contentImageSize, contentImageApply) = contentImageSizeAndApply {
                                contentMediaHeight = contentImageSize.height
                                
                                let contentImageNode = contentImageApply(transition, synchronousLoads)
                                if strongSelf.contentImageNode !== contentImageNode {
                                    strongSelf.contentImageNode = contentImageNode
                                    strongSelf.addSubnode(contentImageNode)
                                    contentImageNode.activateLocalContent = { [weak strongSelf] mode in
                                        if let strongSelf = strongSelf {
                                            strongSelf.openMedia?(mode)
                                        }
                                    }
                                    contentImageNode.visibility = strongSelf.visibility != .none
                                }
                                let _ = contentImageApply(transition, synchronousLoads)
                                let contentImageFrame: CGRect
                                if let (_, flags) = mediaAndFlags, flags.contains(.preferMediaBeforeText) {
                                    contentImageFrame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: contentImageSize)
                                } else {
                                    contentImageFrame = CGRect(origin: CGPoint(x: insets.left, y: textFrame.maxY + (textFrame.size.height > CGFloat.ulpOfOne ? 4.0 : 0.0)), size: contentImageSize)
                                }
                                
                                contentImageNode.frame = contentImageFrame
                                
                                if !statusInText, let statusFrame = statusFrame {
                                    adjustedStatusFrame = CGRect(origin: CGPoint(x: contentImageFrame.width - statusFrame.size.width - 2.0, y: contentImageFrame.height - statusFrame.size.height - 2.0), size: statusFrame.size)
                                }
                            } else if let contentImageNode = strongSelf.contentImageNode {
                                contentImageNode.visibility = false
                                contentImageNode.removeFromSupernode()
                                strongSelf.contentImageNode = nil
                            }
                            
                            if let updatedAdditionalImageBadge = updatedAdditionalImageBadge, let contentImageNode = strongSelf.contentImageNode, let contentImageSize = contentImageSizeAndApply?.0 {
                                if strongSelf.additionalImageBadgeNode != updatedAdditionalImageBadge {
                                    strongSelf.additionalImageBadgeNode?.removeFromSupernode()
                                }
                                strongSelf.additionalImageBadgeNode = updatedAdditionalImageBadge
                                contentImageNode.addSubnode(updatedAdditionalImageBadge)
                                if mediaBadge != nil {
                                    updatedAdditionalImageBadge.update(theme: presentationData.theme.theme, content: additionalImageBadgeContent, mediaDownloadState: nil, animated: false)
                                    updatedAdditionalImageBadge.frame = CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: CGSize(width: 0.0, height: 0.0))
                                } else {
                                    updatedAdditionalImageBadge.update(theme: presentationData.theme.theme, content: additionalImageBadgeContent, mediaDownloadState: nil, alignment: .right, animated: false)
                                    updatedAdditionalImageBadge.frame = CGRect(origin: CGPoint(x: contentImageSize.width - 6.0, y: contentImageSize.height - 18.0 - 6.0), size: CGSize(width: 0.0, height: 0.0))
                                }
                            } else if let additionalImageBadgeNode = strongSelf.additionalImageBadgeNode {
                                strongSelf.additionalImageBadgeNode = nil
                                additionalImageBadgeNode.removeFromSupernode()
                            }
                            
                            if let (contentFileSize, contentFileApply) = contentFileSizeAndApply {
                                contentMediaHeight = contentFileSize.height
                                
                                let contentFileNode = contentFileApply(synchronousLoads)
                                if strongSelf.contentFileNode !== contentFileNode {
                                    strongSelf.contentFileNode = contentFileNode
                                    strongSelf.addSubnode(contentFileNode)
                                    contentFileNode.activateLocalContent = { [weak strongSelf] in
                                        if let strongSelf = strongSelf {
                                            strongSelf.openMedia?(.default)
                                        }
                                    }
                                }
                                if let (_, flags) = mediaAndFlags, flags.contains(.preferMediaBeforeText) {
                                    contentFileNode.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: contentFileSize)
                                } else {
                                    contentFileNode.frame = CGRect(origin: CGPoint(x: insets.left, y: textFrame.maxY + (textFrame.size.height > CGFloat.ulpOfOne ? 8.0 : 0.0)), size: contentFileSize)
                                }
                            } else if let contentFileNode = strongSelf.contentFileNode {
                                contentFileNode.removeFromSupernode()
                                strongSelf.contentFileNode = nil
                            }
                            
                            if let (videoLayout, apply) = contentInstantVideoSizeAndApply {
                                contentMediaHeight = videoLayout.contentSize.height
                                let contentInstantVideoNode = apply(.unconstrained(width: boundingWidth - insets.left - insets.right), transition)
                                if strongSelf.contentInstantVideoNode !== contentInstantVideoNode {
                                    strongSelf.contentInstantVideoNode = contentInstantVideoNode
                                    strongSelf.addSubnode(contentInstantVideoNode)
                                }
                                if let (_, flags) = mediaAndFlags, flags.contains(.preferMediaBeforeText) {
                                    contentInstantVideoNode.frame = CGRect(origin: CGPoint(x: insets.left, y: insets.top), size: videoLayout.contentSize)
                                } else {
                                    contentInstantVideoNode.frame = CGRect(origin: CGPoint(x: insets.left, y: textFrame.maxY + (textFrame.size.height > CGFloat.ulpOfOne ? 4.0 : 0.0)), size: videoLayout.contentSize)
                                }
                            } else if let contentInstantVideoNode = strongSelf.contentInstantVideoNode {
                                contentInstantVideoNode.removeFromSupernode()
                                strongSelf.contentInstantVideoNode = nil
                            }
                            
                            var textVerticalOffset: CGFloat = 0.0
                            if let contentMediaHeight = contentMediaHeight, let (_, flags) = mediaAndFlags, flags.contains(.preferMediaBeforeText) {
                                textVerticalOffset = contentMediaHeight + 7.0
                            }
                            
                            strongSelf.textNode.frame = textFrame.offsetBy(dx: 0.0, dy: textVerticalOffset)
                            
                            if let (size, apply) = actionButtonSizeAndApply {
                                let buttonNode = apply()
                                if buttonNode !== strongSelf.buttonNode {
                                    strongSelf.buttonNode?.removeFromSupernode()
                                    strongSelf.buttonNode = buttonNode
                                    strongSelf.addSubnode(buttonNode)
                                    buttonNode.pressed = {
                                        if let strongSelf = self {
                                            strongSelf.activateAction?()
                                        }
                                    }
                                }
                                buttonNode.frame = CGRect(origin: CGPoint(x: 13.0, y: adjustedLineHeight - insets.top - insets.bottom - 2.0 + 6.0), size: size)
                            } else if let buttonNode = strongSelf.buttonNode {
                                buttonNode.removeFromSupernode()
                                strongSelf.buttonNode = nil
                            }
                            
                            if let (_, statusApply) = statusSizeAndApply, let adjustedStatusFrame = adjustedStatusFrame {
                                strongSelf.statusNode.frame = adjustedStatusFrame.offsetBy(dx: 0.0, dy: textVerticalOffset)
                                if statusInText {
                                    if strongSelf.statusNode.supernode != strongSelf {
                                        strongSelf.addSubnode(strongSelf.statusNode)
                                    }
                                } else if let contentImageNode = strongSelf.contentImageNode {
                                    if strongSelf.statusNode.supernode != contentImageNode {
                                        contentImageNode.addSubnode(strongSelf.statusNode)
                                    }
                                }
                                statusApply(hasAnimation)
                            } else if strongSelf.statusNode.supernode != nil {
                                strongSelf.statusNode.removeFromSupernode()
                            }
                        }
                    })
                })
            })
        }
    }
    
    func updateHiddenMedia(_ media: [Media]?) -> Bool {
        if let currentMedia = self.media {
            if let media = media {
                var found = false
                for m in media {
                    if currentMedia.isEqual(to: m) {
                        found = true
                        break
                    }
                }
                if let contentImageNode = self.contentImageNode {
                    contentImageNode.isHidden = found
                    contentImageNode.updateIsHidden(found)
                    return found
                }
            } else if let contentImageNode = self.contentImageNode {
                contentImageNode.isHidden = false
                contentImageNode.updateIsHidden(false)
            }
        }
        return false
    }
    
    func transitionNode(media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        if let contentImageNode = self.contentImageNode, let image = self.media as? TelegramMediaImage, image.isEqual(to: media) {
            return (contentImageNode, contentImageNode.bounds, { [weak contentImageNode] in
                return (contentImageNode?.view.snapshotContentTree(unhide: true), nil)
            })
        } else if let contentImageNode = self.contentImageNode, let file = self.media as? TelegramMediaFile, file.isEqual(to: media) {
            return (contentImageNode, contentImageNode.bounds, { [weak contentImageNode] in
                return (contentImageNode?.view.snapshotContentTree(unhide: true), nil)
            })
        }
        return nil
    }
    
    func hasActionAtPoint(_ point: CGPoint) -> Bool {
        if let buttonNode = self.buttonNode, buttonNode.frame.contains(point) {
            return true
        }
        return false
    }
    
    func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.textNode.frame
        if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
            if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let (attributeText, fullText) = self.textNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
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
            } else {
                return .none
            }
        } else {
            return .none
        }
    }
    
    func updateTouchesAtPoint(_ point: CGPoint?) {
        if let context = self.context, let message = self.message, let theme = self.theme {
            var rects: [CGRect]?
            if let point = point {
                let textNodeFrame = self.textNode.frame
                if let (index, attributes) = self.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag,
                        TelegramTextAttributes.BankCard
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.textNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                }
            }
            
            if let rects = rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: message.effectivelyIncoming(context.account.peerId) ? theme.theme.chat.message.incoming.linkHighlightColor : theme.theme.chat.message.outgoing.linkHighlightColor)
                    self.linkHighlightingNode = linkHighlightingNode
                    self.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode)
                }
                linkHighlightingNode.frame = self.textNode.frame
                linkHighlightingNode.updateRects(rects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }
    
    func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return self.contentImageNode?.playMediaWithSound()
    }
    
    func reactionTargetNode(value: String) -> (ASDisplayNode, Int)? {
        if !self.statusNode.isHidden {
            return self.statusNode.reactionNode(value: value)
        }
        return nil
    }
}
