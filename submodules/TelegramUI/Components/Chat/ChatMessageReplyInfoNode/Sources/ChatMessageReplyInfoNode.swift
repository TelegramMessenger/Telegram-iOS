import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import LocalizedPeerData
import PhotoResources
import TelegramStringFormatting
import TextFormat
import InvisibleInkDustNode
import TextNodeWithEntities
import AnimationCache
import MultiAnimationRenderer
import ChatMessageItemCommon
import MessageInlineBlockBackgroundView

public enum ChatMessageReplyInfoType {
    case bubble(incoming: Bool)
    case standalone
}

private let quoteIcon: UIImage = {
    return UIImage(bundleImageName: "Chat/Message/ReplyQuoteIcon")!.precomposed().withRenderingMode(.alwaysTemplate)
}()

private let channelIcon: UIImage = {
    let sourceImage = UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextChannelIcon")!
    return generateImage(CGSize(width: sourceImage.size.width + 4.0, height: sourceImage.size.height + 4.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        UIGraphicsPushContext(context)
        sourceImage.draw(at: CGPoint(x: 2.0, y: 1.0 + UIScreenPixel))
        UIGraphicsPopContext()
    })!.precomposed().withRenderingMode(.alwaysTemplate)
}()

private func generateGroupIcon() -> UIImage {
    let sourceImage = UIImage(bundleImageName: "Chat/Input/Accessory Panels/PanelTextGroupIcon")!
    return generateImage(CGSize(width: sourceImage.size.width, height: sourceImage.size.height + 4.0), rotatedContext: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        UIGraphicsPushContext(context)
        sourceImage.draw(at: CGPoint(x: 0.0, y: 1.0 - UIScreenPixel))
        UIGraphicsPopContext()
        
        //context.setFillColor(UIColor.white.cgColor)
        //context.fill(CGRect(origin: CGPoint(), size: size))
    })!.precomposed().withRenderingMode(.alwaysTemplate)
}

private let groupIcon: UIImage = {
    return generateGroupIcon()
}()

public class ChatMessageReplyInfoNode: ASDisplayNode {
    public final class TransitionReplyPanel {
        public let titleNode: ASDisplayNode
        public let textNode: ASDisplayNode
        public let lineNode: ASDisplayNode
        public let imageNode: ASDisplayNode
        public let relativeSourceRect: CGRect
        public let relativeTargetRect: CGRect
        
        public init(titleNode: ASDisplayNode, textNode: ASDisplayNode, lineNode: ASDisplayNode, imageNode: ASDisplayNode, relativeSourceRect: CGRect, relativeTargetRect: CGRect) {
            self.titleNode = titleNode
            self.textNode = textNode
            self.lineNode = lineNode
            self.imageNode = imageNode
            self.relativeSourceRect = relativeSourceRect
            self.relativeTargetRect = relativeTargetRect
        }
    }
    
    public class Arguments {
        public let presentationData: ChatPresentationData
        public let strings: PresentationStrings
        public let context: AccountContext
        public let type: ChatMessageReplyInfoType
        public let message: Message?
        public let replyForward: QuotedReplyMessageAttribute?
        public let quote: (quote: EngineMessageReplyQuote, isQuote: Bool)?
        public let story: StoryId?
        public let parentMessage: Message
        public let constrainedSize: CGSize
        public let animationCache: AnimationCache?
        public let animationRenderer: MultiAnimationRenderer?
        public let associatedData: ChatMessageItemAssociatedData
        
        public init(
            presentationData: ChatPresentationData,
            strings: PresentationStrings,
            context: AccountContext,
            type: ChatMessageReplyInfoType,
            message: Message?,
            replyForward: QuotedReplyMessageAttribute?,
            quote: (quote: EngineMessageReplyQuote, isQuote: Bool)?,
            story: StoryId?,
            parentMessage: Message,
            constrainedSize: CGSize,
            animationCache: AnimationCache?,
            animationRenderer: MultiAnimationRenderer?,
            associatedData: ChatMessageItemAssociatedData
        ) {
            self.presentationData = presentationData
            self.strings = strings
            self.context = context
            self.type = type
            self.message = message
            self.replyForward = replyForward
            self.quote = quote
            self.story = story
            self.parentMessage = parentMessage
            self.constrainedSize = constrainedSize
            self.animationCache = animationCache
            self.animationRenderer = animationRenderer
            self.associatedData = associatedData
        }
    }
    
    public var visibility: Bool = false {
        didSet {
            if self.visibility != oldValue {
                self.textNode?.visibilityRect = self.visibility ? CGRect.infinite : nil
            }
        }
    }
    
    private let backgroundView: MessageInlineBlockBackgroundView
    private var quoteIconView: UIImageView?
    private let contentNode: ASDisplayNode
    private var titleNode: TextNode?
    private var textNode: TextNodeWithEntities?
    private var dustNode: InvisibleInkDustNode?
    private var imageNode: TransformImageNode?
    private var previousMediaReference: AnyMediaReference?
    private var expiredStoryIconView: UIImageView?
    
    private var currentProgressDisposable: Disposable?
    
    public var isQuoteExpanded: Bool = false
    
    override public init() {
        self.backgroundView = MessageInlineBlockBackgroundView(frame: CGRect())
        
        self.contentNode = ASDisplayNode()
        self.contentNode.isUserInteractionEnabled = false
        self.contentNode.displaysAsynchronously = false
        self.contentNode.contentMode = .left
        self.contentNode.contentsScale = UIScreenScale
        
        super.init()
        
        self.addSubnode(self.contentNode)
    }
    
    deinit {
        self.currentProgressDisposable?.dispose()
    }
    
    public func makeProgress() -> Promise<Bool> {
        let progress = Promise<Bool>()
        self.currentProgressDisposable?.dispose()
        self.currentProgressDisposable = (progress.get()
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] hasProgress in
            guard let self else {
                return
            }
            self.backgroundView.displayProgress = hasProgress
        })
        return progress
    }
    
    public static func asyncLayout(_ maybeNode: ChatMessageReplyInfoNode?) -> (_ arguments: Arguments) -> (CGSize, (CGSize, Bool, ListViewItemUpdateAnimation) -> ChatMessageReplyInfoNode) {
        let titleNodeLayout = TextNode.asyncLayout(maybeNode?.titleNode)
        let textNodeLayout = TextNodeWithEntities.asyncLayout(maybeNode?.textNode)
        let imageNodeLayout = TransformImageNode.asyncLayout(maybeNode?.imageNode)
        let previousMediaReference = maybeNode?.previousMediaReference
        
        let isQuoteExpanded = maybeNode?.isQuoteExpanded ?? false
        
        return { arguments in
            let fontSize = floor(arguments.presentationData.fontSize.baseDisplaySize * 14.0 / 17.0)
            let titleFont = Font.semibold(fontSize)
            let textFont = Font.regular(fontSize)
            
            var titleString: NSAttributedString
            var textString: NSAttributedString
            let isMedia: Bool
            let isText: Bool
            var isExpiredStory: Bool = false
            var isStory: Bool = false
            
            let titleColor: UIColor
            let mainColor: UIColor
            let dustColor: UIColor
            var secondaryColor: UIColor?
            var tertiaryColor: UIColor?
            
            var authorNameColor: UIColor?
            var dashSecondaryColor: UIColor?
            var dashTertiaryColor: UIColor?
            
            var author = arguments.message?.effectiveAuthor
            
            if let forwardInfo = arguments.message?.forwardInfo {
                if let peer = forwardInfo.author {
                    author = peer
                } else if let authorSignature = forwardInfo.authorSignature {
                    author = TelegramUser(id: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(Int64(authorSignature.persistentHashValue % 32))), accessHash: nil, firstName: authorSignature, lastName: nil, username: nil, phone: nil, photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil)
                }
            }
            
            let colors = author?.nameColor.flatMap { arguments.context.peerNameColors.get($0, dark: arguments.presentationData.theme.theme.overallDarkAppearance) }
            authorNameColor = colors?.main
            dashSecondaryColor = colors?.secondary
            dashTertiaryColor = colors?.tertiary
            
            switch arguments.type {
            case let .bubble(incoming):
                titleColor = incoming ? (authorNameColor ?? arguments.presentationData.theme.theme.chat.message.incoming.accentTextColor) : arguments.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                if incoming {
                    if let authorNameColor {
                        mainColor = authorNameColor
                        secondaryColor = dashSecondaryColor
                        tertiaryColor = dashTertiaryColor
                    } else {
                        mainColor = arguments.presentationData.theme.theme.chat.message.incoming.accentTextColor
                    }
                } else {
                    mainColor = arguments.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    if dashSecondaryColor != nil {
                        secondaryColor = .clear
                    }
                    if dashTertiaryColor != nil {
                        tertiaryColor = .clear
                    }
                }
                dustColor = incoming ? arguments.presentationData.theme.theme.chat.message.incoming.secondaryTextColor : arguments.presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
            case .standalone:
                let serviceColor = serviceMessageColorComponents(theme: arguments.presentationData.theme.theme, wallpaper: arguments.presentationData.theme.wallpaper)
                titleColor = serviceColor.primaryText
                if dashSecondaryColor != nil {
                    secondaryColor = .clear
                }
                if dashTertiaryColor != nil {
                    tertiaryColor = .clear
                }
                
                mainColor = serviceMessageColorComponents(chatTheme: arguments.presentationData.theme.theme.chat, wallpaper: arguments.presentationData.theme.wallpaper).primaryText
                dustColor = titleColor
            }
            
            if let message = arguments.message {
                let author = message.effectiveAuthor
                let rawTitleString = author.flatMap(EnginePeer.init)?.displayTitle(strings: arguments.strings, displayOrder: arguments.presentationData.nameDisplayOrder) ?? arguments.strings.User_DeletedAccount
                titleString = NSAttributedString(string: rawTitleString, font: titleFont, textColor: titleColor)
                
                if let forwardInfo = message.forwardInfo {
                    if let author = forwardInfo.author {
                        let rawTitleString = EnginePeer(author).displayTitle(strings: arguments.strings, displayOrder: arguments.presentationData.nameDisplayOrder)
                        titleString = NSAttributedString(string: rawTitleString, font: titleFont, textColor: titleColor)
                    } else if let authorSignature = forwardInfo.authorSignature {
                        let rawTitleString = authorSignature
                        titleString = NSAttributedString(string: rawTitleString, font: titleFont, textColor: titleColor)
                    }
                }
                
                if message.id.peerId != arguments.parentMessage.id.peerId, let peer = message.peers[message.id.peerId], (peer is TelegramChannel || peer is TelegramGroup) {
                    final class RunDelegateData {
                        let ascent: CGFloat
                        let descent: CGFloat
                        let width: CGFloat
                        
                        init(ascent: CGFloat, descent: CGFloat, width: CGFloat) {
                            self.ascent = ascent
                            self.descent = descent
                            self.width = width
                        }
                    }
                    let font = titleFont
                    let runDelegateData = RunDelegateData(
                        ascent: font.ascender,
                        descent: font.descender,
                        width: channelIcon.size.width
                    )
                    var callbacks = CTRunDelegateCallbacks(
                        version: kCTRunDelegateCurrentVersion,
                        dealloc: { dataRef in
                            Unmanaged<RunDelegateData>.fromOpaque(dataRef).release()
                        },
                        getAscent: { dataRef in
                            let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                            return data.takeUnretainedValue().ascent
                        },
                        getDescent: { dataRef in
                            let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                            return data.takeUnretainedValue().descent
                        },
                        getWidth: { dataRef in
                            let data = Unmanaged<RunDelegateData>.fromOpaque(dataRef)
                            return data.takeUnretainedValue().width
                        }
                    )
                    
                    if let runDelegate = CTRunDelegateCreate(&callbacks, Unmanaged.passRetained(runDelegateData).toOpaque()) {
                        if let peer = peer as? TelegramChannel, case .broadcast = peer.info {
                            let rawTitleString = NSMutableAttributedString(attributedString: titleString)
                            rawTitleString.insert(NSAttributedString(string: ">", attributes: [
                                .attachment: channelIcon,
                                .foregroundColor: titleColor,
                                NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String): runDelegate
                            ]), at: 0)
                            titleString = rawTitleString
                        } else {
                            let rawTitleString = NSMutableAttributedString(attributedString: titleString)
                            rawTitleString.append(NSAttributedString(string: "\u{200B}", font: titleFont, textColor: titleColor))
                            rawTitleString.append(NSAttributedString(string: ">", attributes: [
                                .attachment: groupIcon,
                                .foregroundColor: titleColor,
                                NSAttributedString.Key(rawValue: kCTRunDelegateAttributeName as String): runDelegate
                            ]))
                            rawTitleString.append(NSAttributedString(string: peer.debugDisplayTitle, font: titleFont, textColor: titleColor))
                            titleString = rawTitleString
                        }
                    }
                }
                
                let (textStringValue, isMediaValue, isTextValue) = descriptionStringForMessage(contentSettings: arguments.context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: arguments.strings, nameDisplayOrder: arguments.presentationData.nameDisplayOrder, dateTimeFormat: arguments.presentationData.dateTimeFormat, accountPeerId: arguments.context.account.peerId)
                textString = textStringValue
                isMedia = isMediaValue
                isText = isTextValue
            } else if let replyForward = arguments.replyForward {
                if let replyAuthorId = replyForward.peerId, let replyAuthor = arguments.parentMessage.peers[replyAuthorId] {
                    let rawTitleString = EnginePeer(replyAuthor).displayTitle(strings: arguments.strings, displayOrder: arguments.presentationData.nameDisplayOrder)
                    titleString = NSAttributedString(string: rawTitleString, font: titleFont, textColor: titleColor)
                } else {
                    let rawTitleString = replyForward.authorName ?? " "
                    titleString = NSAttributedString(string: rawTitleString, font: titleFont, textColor: titleColor)
                }

                textString = NSAttributedString(string: replyForward.quote?.text ?? arguments.presentationData.strings.VoiceOver_ChatList_Message)
                if let media = replyForward.quote?.media {
                    if let text = replyForward.quote?.text, !text.isEmpty {
                        isMedia = false
                    } else {
                        if let contentKind = mediaContentKind(EngineMedia(media), message: nil, strings: arguments.strings, nameDisplayOrder: arguments.presentationData.nameDisplayOrder, dateTimeFormat: arguments.presentationData.dateTimeFormat, accountPeerId: arguments.context.account.peerId) {
                            let (string, _) = stringForMediaKind(contentKind, strings: arguments.strings)
                            textString = string
                        } else {
                            textString = NSAttributedString(string: arguments.presentationData.strings.VoiceOver_ChatList_Message)
                        }
                        isMedia = true
                    }
                } else {
                    isMedia = false
                }
                isText = replyForward.quote?.text != nil && replyForward.quote?.text != ""
            } else if let story = arguments.story {
                if let authorPeer = arguments.parentMessage.peers[story.peerId] {
                    let rawTitleString = EnginePeer(authorPeer).displayTitle(strings: arguments.strings, displayOrder: arguments.presentationData.nameDisplayOrder)
                    titleString = NSAttributedString(string: rawTitleString, font: titleFont, textColor: titleColor)
                } else {
                    let rawTitleString = arguments.strings.User_DeletedAccount
                    titleString = NSAttributedString(string: rawTitleString, font: titleFont, textColor: titleColor)
                }
                isText = false
                
                var hideStory = false
                if let peer = arguments.parentMessage.peers[story.peerId] as? TelegramChannel, peer.username == nil, peer.usernames.isEmpty {
                    switch peer.participationStatus {
                    case .member:
                        break
                    case .kicked, .left:
                        hideStory = true
                    }
                }
                
                if let storyItem = arguments.parentMessage.associatedStories[story], storyItem.data.isEmpty {
                    isExpiredStory = true
                    textString = NSAttributedString(string: arguments.strings.Chat_ReplyExpiredStory)
                    isMedia = false
                } else if hideStory {
                    isExpiredStory = true
                    textString = NSAttributedString(string: arguments.strings.Chat_ReplyStoryPrivateChannel)
                    isMedia = false
                } else {
                    isStory = true
                    textString = NSAttributedString(string: arguments.strings.Chat_ReplyStory)
                    isMedia = true
                }
            } else {
                titleString = NSAttributedString(string: " ", font: titleFont, textColor: titleColor)
                textString = NSAttributedString(string: " ")
                isMedia = true
                isText = false
            }
            
            let isIncoming = arguments.parentMessage.effectivelyIncoming(arguments.context.account.peerId)
            
            let placeholderColor: UIColor = isIncoming ? arguments.presentationData.theme.theme.chat.message.incoming.mediaPlaceholderColor : arguments.presentationData.theme.theme.chat.message.outgoing.mediaPlaceholderColor
            
            let textColor: UIColor
            
            switch arguments.type {
                case let .bubble(incoming):
                    if isExpiredStory || isStory {
                        textColor = incoming ? arguments.presentationData.theme.theme.chat.message.incoming.accentTextColor : arguments.presentationData.theme.theme.chat.message.outgoing.accentTextColor
                    } else if isMedia {
                        textColor = incoming ? arguments.presentationData.theme.theme.chat.message.incoming.secondaryTextColor : arguments.presentationData.theme.theme.chat.message.outgoing.secondaryTextColor
                    } else {
                        textColor = incoming ? arguments.presentationData.theme.theme.chat.message.incoming.primaryTextColor : arguments.presentationData.theme.theme.chat.message.outgoing.primaryTextColor
                    }
                case .standalone:
                    textColor = titleColor
            }
            
            let messageText: NSAttributedString
            if isText, let message = arguments.message {
                var text: String
                var messageEntities: [MessageTextEntity]
                
                if let quote = arguments.quote?.quote, !quote.text.isEmpty {
                    text = quote.text
                    messageEntities = quote.entities
                } else {
                    text = foldLineBreaks(message.text)
                    messageEntities = message.textEntitiesAttribute?.entities ?? []
                }
                
                if let translateToLanguage = arguments.associatedData.translateToLanguage, !text.isEmpty {
                    for attribute in message.attributes {
                        if let attribute = attribute as? TranslationMessageAttribute, !attribute.text.isEmpty, attribute.toLang == translateToLanguage {
                            text = attribute.text
                            messageEntities = attribute.entities
                            break
                        }
                    }
                }
                    
                let entities = messageEntities.filter { entity in
                    if case .Strikethrough = entity.type {
                        return true
                    } else if case .Spoiler = entity.type {
                        return true
                    } else if case .CustomEmoji = entity.type {
                        return true
                    } else {
                        return false
                    }
                }
                if entities.count > 0 {
                    messageText = stringWithAppliedEntities(text, entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: message)
                } else {
                    messageText = NSAttributedString(string: text, font: textFont, textColor: textColor)
                }
            } else if isText, let replyForward = arguments.replyForward, let quote = replyForward.quote {
                let entities = quote.entities.filter { entity in
                    if case .Strikethrough = entity.type {
                        return true
                    } else if case .Spoiler = entity.type {
                        return true
                    } else if case .CustomEmoji = entity.type {
                        return true
                    } else {
                        return false
                    }
                }
                if entities.count > 0 {
                    messageText = stringWithAppliedEntities(quote.text, entities: entities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false, message: nil)
                } else {
                    messageText = NSAttributedString(string: quote.text, font: textFont, textColor: textColor)
                }
            } else {
                messageText = NSAttributedString(string: textString.string, font: textFont, textColor: textColor)
            }
            
            var leftInset: CGFloat = 11.0
            let spacing: CGFloat = 2.0
            
            var updatedMediaReference: AnyMediaReference?
            var imageDimensions: CGSize?
            var hasRoundImage = false
            if let message = arguments.message, !message.containsSecretMedia {
                for media in message.media {
                    if let image = media as? TelegramMediaImage {
                        updatedMediaReference = .message(message: MessageReference(message), media: image)
                        if let representation = largestRepresentationForPhoto(image) {
                            imageDimensions = representation.dimensions.cgSize
                        }
                        break
                    } else if let file = media as? TelegramMediaFile, !file.isVideoSticker {
                        updatedMediaReference = .message(message: MessageReference(message), media: file)
                        
                        if let dimensions = file.dimensions {
                            imageDimensions = dimensions.cgSize
                        } else if let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                            imageDimensions = representation.dimensions.cgSize
                        }
                        if file.isInstantVideo {
                            hasRoundImage = true
                        }
                        break
                    }
                }
            } else if let story = arguments.story, let storyPeer = arguments.parentMessage.peers[story.peerId], let storyItem = arguments.parentMessage.associatedStories[story] {
                if let itemValue = storyItem.get(Stories.StoredItem.self), case let .item(item) = itemValue, let peerReference = PeerReference(storyPeer) {
                    if let image = item.media as? TelegramMediaImage {
                        updatedMediaReference = .story(peer: peerReference, id: story.id, media: image)
                        if let representation = largestRepresentationForPhoto(image) {
                            imageDimensions = representation.dimensions.cgSize
                        }
                    } else if let file = item.media as? TelegramMediaFile, file.isVideo && !file.isVideoSticker {
                        updatedMediaReference = .story(peer: peerReference, id: story.id, media: file)
                        
                        if let dimensions = file.dimensions {
                            imageDimensions = dimensions.cgSize
                        } else if let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                            imageDimensions = representation.dimensions.cgSize
                        }
                    }
                }
            } else if let replyForward = arguments.replyForward, let media = replyForward.quote?.media {
                if let image = media as? TelegramMediaImage {
                    updatedMediaReference = .message(message: MessageReference(arguments.parentMessage), media: image)
                    if let representation = largestRepresentationForPhoto(image) {
                        imageDimensions = representation.dimensions.cgSize
                    }
                } else if let file = media as? TelegramMediaFile, file.isVideo && !file.isVideoSticker {
                    updatedMediaReference = .message(message: MessageReference(arguments.parentMessage), media: file)
                    
                    if let dimensions = file.dimensions {
                        imageDimensions = dimensions.cgSize
                    } else if let representation = largestImageRepresentation(file.previewRepresentations), !file.isSticker {
                        imageDimensions = representation.dimensions.cgSize
                    }
                    if file.isInstantVideo {
                        hasRoundImage = true
                    }
                }
            }
            
            var imageTextInset: CGFloat = 0.0
            if let _ = imageDimensions {
                imageTextInset += floor(arguments.presentationData.fontSize.baseDisplaySize * 32.0 / 17.0)
            }
            
            let maximumTextWidth = max(0.0, arguments.constrainedSize.width - 8.0 - imageTextInset)
            
            var contrainedTextSize = CGSize(width: maximumTextWidth, height: arguments.constrainedSize.height)
            
            let textInsets = UIEdgeInsets(top: 3.0, left: 0.0, bottom: 3.0, right: 0.0)
            
            var additionalTitleWidth: CGFloat = 0.0
            var maxTitleNumberOfLines = 1
            var maxTextNumberOfLines = 1
            var adjustedConstrainedTextSize = contrainedTextSize
            var textCutout: TextNodeCutout?
            var textCutoutWidth: CGFloat = 0.0
            
            var isQuote = false
            if let quote = arguments.quote, quote.isQuote {
                isQuote = true
            } else if let replyForward = arguments.replyForward, replyForward.quote != nil, replyForward.isQuote {
                isQuote = true
            }
            
            if isQuote {
                additionalTitleWidth += 10.0
                maxTitleNumberOfLines = 2
                maxTextNumberOfLines = isQuoteExpanded ? 50 : 5
                if imageTextInset != 0.0 {
                    adjustedConstrainedTextSize.width += imageTextInset
                    textCutout = TextNodeCutout(topLeft: CGSize(width: imageTextInset + 6.0, height: 10.0))
                    textCutoutWidth = imageTextInset + 6.0
                }
            }
            
            let (titleLayout, titleApply) = titleNodeLayout(TextNodeLayoutArguments(attributedString: titleString, backgroundColor: nil, maximumNumberOfLines: maxTitleNumberOfLines, truncationType: .end, constrainedSize: CGSize(width: contrainedTextSize.width - additionalTitleWidth, height: contrainedTextSize.height), alignment: .natural, cutout: nil, insets: textInsets))
            if isExpiredStory || isStory {
                contrainedTextSize.width -= 26.0
            }
            
            if titleLayout.numberOfLines > 1 {
                textCutout = nil
            }
            
            let (textLayout, textApply) = textNodeLayout(TextNodeLayoutArguments(attributedString: messageText, backgroundColor: nil, maximumNumberOfLines: maxTextNumberOfLines, truncationType: .end, constrainedSize: adjustedConstrainedTextSize, alignment: .natural, lineSpacing: 0.07, cutout: textCutout, insets: textInsets))
            
            let imageSide: CGFloat
            let titleLineHeight: CGFloat = titleLayout.linesRects().first?.height ?? 12.0
            imageSide = titleLineHeight * 2.0
            
            var applyImage: (() -> TransformImageNode)?
            if let imageDimensions = imageDimensions {
                let boundingSize = CGSize(width: imageSide, height: imageSide)
                leftInset += imageSide + 6.0
                var radius: CGFloat = 4.0
                var imageSize = imageDimensions.aspectFilled(boundingSize)
                if hasRoundImage {
                    radius = boundingSize.width / 2.0
                    imageSize.width += 2.0
                    imageSize.height += 2.0
                }
                if !isExpiredStory {
                    applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageSize, boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets(), emptyColor: placeholderColor))
                }
            }
            
            var mediaUpdated = false
            if let updatedMediaReference = updatedMediaReference, let previousMediaReference = previousMediaReference {
                mediaUpdated = !updatedMediaReference.media.isEqual(to: previousMediaReference.media)
            } else if (updatedMediaReference != nil) != (previousMediaReference != nil) {
                mediaUpdated = true
            }
            
            let hasSpoiler: Bool
            if let message = arguments.message {
                hasSpoiler = message.attributes.contains(where: { $0 is MediaSpoilerMessageAttribute })
            } else {
                hasSpoiler = false
            }
            
            var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
            
            var mediaUserLocation: MediaResourceUserLocation = .other
            if let message = arguments.message {
                mediaUserLocation = .peer(message.id.peerId)
            }
            
            if let updatedMediaReference = updatedMediaReference, mediaUpdated && imageDimensions != nil {
                if let imageReference = updatedMediaReference.concrete(TelegramMediaImage.self) {
                    updateImageSignal = chatMessagePhotoThumbnail(account: arguments.context.account, userLocation: mediaUserLocation, photoReference: imageReference, blurred: hasSpoiler)
                } else if let fileReference = updatedMediaReference.concrete(TelegramMediaFile.self) {
                    if fileReference.media.isVideo {
                        updateImageSignal = chatMessageVideoThumbnail(account: arguments.context.account, userLocation: mediaUserLocation, fileReference: fileReference, blurred: hasSpoiler)
                    } else if let iconImageRepresentation = smallestImageRepresentation(fileReference.media.previewRepresentations) {
                        updateImageSignal = chatWebpageSnippetFile(account: arguments.context.account, userLocation: mediaUserLocation, mediaReference: fileReference.abstract, representation: iconImageRepresentation)
                    }
                }
            }
            
            var size = CGSize()
            size.width = max(titleLayout.size.width + additionalTitleWidth - textInsets.left - textInsets.right, textLayout.size.width - textInsets.left - textInsets.right - textCutoutWidth) + leftInset + 6.0
            size.height = titleLayout.size.height + textLayout.size.height - 2 * (textInsets.top + textInsets.bottom) + 2 * spacing
            size.height += 2.0
            if isExpiredStory || isStory {
                size.width += 16.0
            }
            
            return (size, { realSize, attemptSynchronous, animation in
                let node: ChatMessageReplyInfoNode
                if let maybeNode = maybeNode {
                    node = maybeNode
                } else {
                    node = ChatMessageReplyInfoNode()
                }
                
                node.previousMediaReference = updatedMediaReference
                
                //node.textNode?.textNode.displaysAsynchronously = !arguments.presentationData.isPreview
                
                let titleNode = titleApply()
                titleNode.displaysAsynchronously = !arguments.presentationData.isPreview
                
                var textArguments: TextNodeWithEntities.Arguments?
                if let cache = arguments.animationCache, let renderer = arguments.animationRenderer {
                    textArguments = TextNodeWithEntities.Arguments(context: arguments.context, cache: cache, renderer: renderer, placeholderColor: placeholderColor, attemptSynchronous: attemptSynchronous)
                }
                let previousTextContents = node.textNode?.textNode.layer.contents
                let textNode = textApply(textArguments)
                textNode.textNode.displaysAsynchronously = !arguments.presentationData.isPreview
                
                textNode.visibilityRect = node.visibility ? CGRect.infinite : nil
                
                if node.titleNode == nil {
                    titleNode.isUserInteractionEnabled = false
                    node.titleNode = titleNode
                    node.contentNode.addSubnode(titleNode)
                }
                
                if node.textNode == nil {
                    textNode.textNode.isUserInteractionEnabled = false
                    textNode.textNode.contentMode = .topLeft
                    textNode.textNode.clipsToBounds = true
                    textNode.textNode.contentsScale = UIScreenScale
                    textNode.textNode.displaysAsynchronously = false
                    node.textNode = textNode
                    node.contentNode.addSubnode(textNode.textNode)
                }
                
                if let applyImage = applyImage {
                    let imageNode = applyImage()
                    if node.imageNode == nil {
                        imageNode.isLayerBacked = false
                        node.addSubnode(imageNode)
                        node.imageNode = imageNode
                    }
                    imageNode.frame = CGRect(origin: CGPoint(x: 9.0, y: 4.0), size: CGSize(width: imageSide, height: imageSide))
                    
                    if let updateImageSignal = updateImageSignal {
                        imageNode.setSignal(updateImageSignal)
                    }
                } else if let imageNode = node.imageNode {
                    imageNode.removeFromSupernode()
                    node.imageNode = nil
                }
                if let message = arguments.message {
                    node.imageNode?.captureProtected = message.isCopyProtected()
                }
                
                titleNode.frame = CGRect(origin: CGPoint(x: leftInset - textInsets.left - 2.0, y: spacing - textInsets.top + 1.0), size: titleLayout.size)
                
                let textFrame = CGRect(origin: CGPoint(x: leftInset - textInsets.left - 2.0 - textCutoutWidth, y: titleNode.frame.maxY - textInsets.bottom + spacing - textInsets.top - 2.0), size: textLayout.size)
                let effectiveTextFrame = textFrame.offsetBy(dx: (isExpiredStory || isStory) ? 18.0 : 0.0, dy: 0.0)
                
                if textNode.textNode.bounds.isEmpty || !animation.isAnimated || textNode.textNode.bounds.height == effectiveTextFrame.height {
                    textNode.textNode.frame = effectiveTextFrame
                } else {
                    if textNode.textNode.bounds.height != effectiveTextFrame.height {
                        animation.animator.updateFrame(layer: textNode.textNode.layer, frame: effectiveTextFrame, completion: nil)
                        
                        textNode.textNode.layer.setNeedsDisplay()
                        textNode.textNode.layer.display()
                    } else {
                        animation.animator.updateFrame(layer: textNode.textNode.layer, frame: effectiveTextFrame, completion: nil)
                    }
                    
                    if let previousTextContents, let updatedContents = textNode.textNode.contents {
                        let previousTextContents = previousTextContents as AnyObject
                        let updatedContents = updatedContents as AnyObject
                        if previousTextContents !== updatedContents {
                            textNode.textNode.layer.animate(from: previousTextContents, to: updatedContents, keyPath: "contents", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                        }
                    }
                }
                
                if isExpiredStory || isStory {
                    let expiredStoryIconView: UIImageView
                    if let current = node.expiredStoryIconView {
                        expiredStoryIconView = current
                    } else {
                        expiredStoryIconView = UIImageView()
                        node.expiredStoryIconView = expiredStoryIconView
                        node.view.addSubview(expiredStoryIconView)
                    }
                    
                    let imageType: ChatExpiredStoryIndicatorType
                    switch arguments.type {
                    case .standalone:
                        imageType = .free
                    case let .bubble(incoming):
                        imageType = incoming ? .incoming : .outgoing
                    }
                    
                    if isExpiredStory {
                        expiredStoryIconView.image = PresentationResourcesChat.chatExpiredStoryIndicatorIcon(arguments.presentationData.theme.theme, type: imageType)
                    } else {
                        expiredStoryIconView.image = PresentationResourcesChat.chatReplyStoryIndicatorIcon(arguments.presentationData.theme.theme, type: imageType)
                    }
                    if let image = expiredStoryIconView.image {
                        let imageSize: CGSize
                        if isExpiredStory {
                            imageSize = CGSize(width: floor(image.size.width * 1.22), height: floor(image.size.height * 1.22))
                            expiredStoryIconView.frame = CGRect(origin: CGPoint(x: textFrame.minX - 2.0, y: textFrame.minY + 2.0), size: imageSize)
                        } else {
                            imageSize = image.size
                            expiredStoryIconView.frame = CGRect(origin: CGPoint(x: textFrame.minX - 1.0, y: textFrame.minY + 3.0 + UIScreenPixel), size: imageSize)
                        }
                    }
                } else if let expiredStoryIconView = node.expiredStoryIconView {
                    expiredStoryIconView.removeFromSuperview()
                }
                
                if !textLayout.spoilers.isEmpty {
                    let dustNode: InvisibleInkDustNode
                    if let current = node.dustNode {
                        dustNode = current
                    } else {
                        dustNode = InvisibleInkDustNode(textNode: nil, enableAnimations: arguments.context.sharedContext.energyUsageSettings.fullTranslucency && !arguments.presentationData.isPreview)
                        dustNode.isUserInteractionEnabled = false
                        node.dustNode = dustNode
                        node.contentNode.insertSubnode(dustNode, aboveSubnode: textNode.textNode)
                    }
                    dustNode.frame = textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0)
                    dustNode.update(size: dustNode.frame.size, color: dustColor, textColor: dustColor, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
                } else if let dustNode = node.dustNode {
                    dustNode.removeFromSupernode()
                    node.dustNode = nil
                }
                
                if node.backgroundView.superview == nil {
                    node.contentNode.view.insertSubview(node.backgroundView, at: 0)
                }
                
                let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: realSize.width, height: realSize.height))
                
                node.backgroundView.frame = backgroundFrame
                
                var pattern: MessageInlineBlockBackgroundView.Pattern?
                if let backgroundEmojiId = author?.backgroundEmojiId {
                    pattern = MessageInlineBlockBackgroundView.Pattern(
                        context: arguments.context,
                        fileId: backgroundEmojiId,
                        file: arguments.parentMessage.associatedMedia[MediaId(
                            namespace: Namespaces.Media.CloudFile,
                            id: backgroundEmojiId
                        )] as? TelegramMediaFile
                    )
                }
                var isTransparent: Bool = false
                if case .standalone = arguments.type {
                    isTransparent = true
                }
                node.backgroundView.update(
                    size: backgroundFrame.size,
                    isTransparent: isTransparent,
                    primaryColor: mainColor,
                    secondaryColor: secondaryColor,
                    thirdColor: tertiaryColor,
                    backgroundColor: nil,
                    pattern: pattern,
                    animation: animation
                )
                
                if isQuote {
                    let quoteIconFrame = CGRect(origin: CGPoint(x: backgroundFrame.maxX - 4.0 - quoteIcon.size.width, y: backgroundFrame.minY + 4.0), size: quoteIcon.size)
                    
                    let quoteIconView: UIImageView
                    if let current = node.quoteIconView {
                        quoteIconView = current
                        
                        animation.animator.updateFrame(layer: quoteIconView.layer, frame: quoteIconFrame, completion: nil)
                    } else {
                        quoteIconView = UIImageView(image: quoteIcon)
                        node.quoteIconView = quoteIconView
                        node.contentNode.view.addSubview(quoteIconView)
                            
                        quoteIconView.frame = quoteIconFrame
                    }
                    quoteIconView.tintColor = mainColor
                } else {
                    if let quoteIconView = node.quoteIconView {
                        node.quoteIconView = nil
                        quoteIconView.removeFromSuperview()
                    }
                }
                
                node.contentNode.frame = CGRect(origin: CGPoint(), size: size)
                
                return node
            })
        }
    }
    
    public func updateTouchesAtPoint(_ point: CGPoint?) {
        var isHighlighted = false
        if point != nil {
            isHighlighted = true
        }
        
        let transition: ContainedViewLayoutTransition = .animated(duration: isHighlighted ? 0.3 : 0.2, curve: .easeInOut)
        let scale: CGFloat = isHighlighted ? ((self.bounds.width - 5.0) / self.bounds.width) : 1.0
        transition.updateSublayerTransformScale(node: self, scale: scale, beginWithCurrentState: true)
    }

    public func animateFromInputPanel(sourceReplyPanel: TransitionReplyPanel, unclippedTransitionNode: ASDisplayNode? = nil, localRect: CGRect, transition: CombinedTransition) -> CGPoint {
        let sourceParentNode = ASDisplayNode()

        let sourceParentOffset: CGPoint

        if let unclippedTransitionNode = unclippedTransitionNode {
            unclippedTransitionNode.addSubnode(sourceParentNode)
            sourceParentNode.frame = sourceReplyPanel.relativeSourceRect
            sourceParentOffset = self.view.convert(CGPoint(), to: sourceParentNode.view)
            sourceParentNode.clipsToBounds = true

            let panelOffset = sourceReplyPanel.relativeTargetRect.minY - sourceReplyPanel.relativeSourceRect.minY

            sourceParentNode.frame = sourceParentNode.frame.offsetBy(dx: 0.0, dy: panelOffset)
            sourceParentNode.bounds = sourceParentNode.bounds.offsetBy(dx: 0.0, dy: panelOffset)
            transition.vertical.animatePositionAdditive(layer: sourceParentNode.layer, offset: CGPoint(x: 0.0, y: -panelOffset))
            transition.vertical.animateOffsetAdditive(layer: sourceParentNode.layer, offset: -panelOffset)
        } else {
            self.addSubnode(sourceParentNode)
            sourceParentOffset = CGPoint()
        }

        sourceParentNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, removeOnCompletion: false, completion: { [weak sourceParentNode] _ in
            sourceParentNode?.removeFromSupernode()
        })

        if let titleNode = self.titleNode {
            let offset = CGPoint(
                x: localRect.minX + sourceReplyPanel.titleNode.frame.minX - titleNode.frame.minX,
                y: localRect.minY + sourceReplyPanel.titleNode.frame.midY - titleNode.frame.midY
            )

            transition.horizontal.animatePositionAdditive(node: titleNode, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(node: titleNode, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.titleNode)

            titleNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

            sourceReplyPanel.titleNode.frame = sourceReplyPanel.titleNode.frame
                .offsetBy(dx: sourceParentOffset.x, dy: sourceParentOffset.y)
                .offsetBy(dx: localRect.minX - offset.x, dy: localRect.minY - offset.y)
            transition.horizontal.animatePositionAdditive(node: sourceReplyPanel.titleNode, offset: CGPoint(x: offset.x, y: 0.0), removeOnCompletion: false)
            transition.vertical.animatePositionAdditive(node: sourceReplyPanel.titleNode, offset: CGPoint(x: 0.0, y: offset.y), removeOnCompletion: false)
        }

        if let textNode = self.textNode {
            let offset = CGPoint(
                x: localRect.minX + sourceReplyPanel.textNode.frame.minX - textNode.textNode.frame.minX,
                y: localRect.minY + sourceReplyPanel.textNode.frame.midY - textNode.textNode.frame.midY
            )

            transition.horizontal.animatePositionAdditive(node: textNode.textNode, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(node: textNode.textNode, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.textNode)

            textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

            sourceReplyPanel.textNode.frame = sourceReplyPanel.textNode.frame
                .offsetBy(dx: sourceParentOffset.x, dy: sourceParentOffset.y)
                .offsetBy(dx: localRect.minX - offset.x, dy: localRect.minY - offset.y)
            transition.horizontal.animatePositionAdditive(node: sourceReplyPanel.textNode, offset: CGPoint(x: offset.x, y: 0.0), removeOnCompletion: false)
            transition.vertical.animatePositionAdditive(node: sourceReplyPanel.textNode, offset: CGPoint(x: 0.0, y: offset.y), removeOnCompletion: false)
        }

        if let imageNode = self.imageNode {
            let offset = CGPoint(
                x: localRect.minX + sourceReplyPanel.imageNode.frame.midX - imageNode.frame.midX,
                y: localRect.minY + sourceReplyPanel.imageNode.frame.midY - imageNode.frame.midY
            )

            transition.horizontal.animatePositionAdditive(node: imageNode, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(node: imageNode, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.imageNode)

            imageNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

            sourceReplyPanel.imageNode.frame = sourceReplyPanel.imageNode.frame
                .offsetBy(dx: sourceParentOffset.x, dy: sourceParentOffset.y)
                .offsetBy(dx: localRect.minX - offset.x, dy: localRect.minY - offset.y)
            transition.horizontal.animatePositionAdditive(node: sourceReplyPanel.imageNode, offset: CGPoint(x: offset.x, y: 0.0), removeOnCompletion: false)
            transition.vertical.animatePositionAdditive(node: sourceReplyPanel.imageNode, offset: CGPoint(x: 0.0, y: offset.y), removeOnCompletion: false)
        }

        do {
            let backgroundView = self.backgroundView

            let offset = CGPoint(
                x: localRect.minX + sourceReplyPanel.lineNode.frame.minX - backgroundView.frame.minX,
                y: localRect.minY + sourceReplyPanel.lineNode.frame.minY - backgroundView.frame.minY
            )

            transition.horizontal.animatePositionAdditive(layer: backgroundView.layer, offset: CGPoint(x: offset.x, y: 0.0))
            transition.vertical.animatePositionAdditive(layer: backgroundView.layer, offset: CGPoint(x: 0.0, y: offset.y))

            sourceParentNode.addSubnode(sourceReplyPanel.lineNode)

            backgroundView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)

            sourceReplyPanel.lineNode.frame = sourceReplyPanel.lineNode.frame
                .offsetBy(dx: sourceParentOffset.x, dy: sourceParentOffset.y)
                .offsetBy(dx: localRect.minX - offset.x, dy: localRect.minY - offset.y)
            transition.horizontal.animatePositionAdditive(node: sourceReplyPanel.lineNode, offset: CGPoint(x: offset.x, y: 0.0), removeOnCompletion: false)
            transition.vertical.animatePositionAdditive(node: sourceReplyPanel.lineNode, offset: CGPoint(x: 0.0, y: offset.y), removeOnCompletion: false)

            return offset
        }
    }
    
    public func mediaTransitionView() -> UIView? {
        if let imageNode = self.imageNode {
            return imageNode.view
        }
        return nil
    }
}
