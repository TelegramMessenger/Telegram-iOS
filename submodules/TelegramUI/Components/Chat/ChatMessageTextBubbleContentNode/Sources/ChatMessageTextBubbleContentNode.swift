import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TextFormat
import UrlEscaping
import TelegramUniversalVideoContent
import TextSelectionNode
import Emoji
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import SwiftSignalKit
import AccountContext
import YuvConversion
import AnimationCache
import LottieAnimationCache
import MultiAnimationRenderer
import EmojiTextAttachmentView
import TextNodeWithEntities
import ChatMessageDateAndStatusNode
import ChatMessageBubbleContentNode
import ShimmeringLinkNode
import ChatMessageItemCommon
import TextLoadingEffect
import ChatControllerInteraction
import InteractiveTextComponent

private final class CachedChatMessageText {
    let text: String
    let inputEntities: [MessageTextEntity]?
    let entities: [MessageTextEntity]?
    
    init(text: String, inputEntities: [MessageTextEntity]?, entities: [MessageTextEntity]?) {
        self.text = text
        self.inputEntities = inputEntities
        self.entities = entities
    }
    
    func matches(text: String, inputEntities: [MessageTextEntity]?) -> Bool {
        if self.text != text {
            return false
        }
        if let current = self.inputEntities, let inputEntities = inputEntities {
            if current != inputEntities {
                return false
            }
        } else if (self.inputEntities != nil) != (inputEntities != nil) {
            return false
        }
        return true
    }
}

private func findQuoteRange(string: String, quoteText: String, offset: Int?) -> NSRange? {
    let nsString = string as NSString
    var currentRange: NSRange?
    while true {
        let startOffset = currentRange?.upperBound ?? 0
        let range = nsString.range(of: quoteText, range: NSRange(location: startOffset, length: nsString.length - startOffset))
        if range.location != NSNotFound {
            if let offset {
                if let currentRangeValue = currentRange {
                    if abs(range.location - offset) > abs(currentRangeValue.location - offset) {
                        break
                    } else {
                        currentRange = range
                    }
                } else {
                    currentRange = range
                }
            } else {
                currentRange = range
                break
            }
        } else {
            break
        }
    }
    return currentRange
}

public class ChatMessageTextBubbleContentNode: ChatMessageBubbleContentNode {
    private let containerNode: ASDisplayNode
    private let textNode: InteractiveTextNodeWithEntities
    
    private let textAccessibilityOverlayNode: TextAccessibilityOverlayNode
    public var statusNode: ChatMessageDateAndStatusNode?
    private var linkHighlightingNode: LinkHighlightingNode?
    private var shimmeringNode: ShimmeringLinkNode?
    private var textSelectionNode: TextSelectionNode?
    
    private var textHighlightingNodes: [LinkHighlightingNode] = []
    
    private var cachedChatMessageText: CachedChatMessageText?
    
    private var textSelectionState: Promise<ChatControllerSubject.MessageOptionsInfo.SelectionState>?
    
    private var linkPreviewHighlightText: String?
    private var linkPreviewOptionsDisposable: Disposable?
    private var linkPreviewHighlightingNodes: [LinkHighlightingNode] = []
    
    private var quoteHighlightingNode: LinkHighlightingNode?
    
    private var linkProgressRange: NSRange?
    private var linkProgressView: TextLoadingEffectView?
    private var linkProgressDisposable: Disposable?
    
    private var codeHighlightState: (id: EngineMessage.Id, specs: [CachedMessageSyntaxHighlight.Spec], disposable: Disposable)?
    
    private var expandedBlockIds: Set<Int> = Set()
    private var appliedExpandedBlockIds: Set<Int>?
    private var displayContentsUnderSpoilers: (value: Bool, location: CGPoint?) = (false, nil)
    
    override public var visibility: ListViewItemNodeVisibility {
        didSet {
            if oldValue != self.visibility {
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
    
    required public init() {
        self.containerNode = ASDisplayNode()
        
        self.textNode = InteractiveTextNodeWithEntities()
        
        self.textAccessibilityOverlayNode = TextAccessibilityOverlayNode()
        
        super.init()
        
        self.addSubnode(self.containerNode)
        
        self.textNode.textNode.isUserInteractionEnabled = true
        self.textNode.textNode.contentMode = .topLeft
        self.textNode.textNode.contentsScale = UIScreenScale
        self.textNode.textNode.displaysAsynchronously = true
        //self.containerNode.addSubnode(self.textAccessibilityOverlayNode)
        self.containerNode.addSubnode(self.textNode.textNode)
        
        self.textAccessibilityOverlayNode.openUrl = { [weak self] url in
            self?.item?.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url, concealed: false, external: false))
        }
        
        self.textNode.textNode.requestToggleBlockCollapsed = { [weak self] blockId in
            guard let self, let item = self.item else {
                return
            }
            if self.expandedBlockIds.contains(blockId) {
                self.expandedBlockIds.remove(blockId)
            } else {
                self.expandedBlockIds.insert(blockId)
            }
            item.controllerInteraction.requestMessageUpdate(item.message.id, false)
        }
        self.textNode.textNode.requestDisplayContentsUnderSpoilers = { [weak self] location in
            guard let self else {
                return
            }
            
            cancelParentGestures(view: self.view)
            
            var mappedLocation: CGPoint?
            if let location {
                mappedLocation = self.textNode.textNode.layer.convert(location, to: self.layer)
            }
            self.updateDisplayContentsUnderSpoilers(value: true, at: mappedLocation)
        }
        self.textNode.textNode.canHandleTapAtPoint = { [weak self] point in
            guard let self else {
                return false
            }
            let localPoint = self.textNode.textNode.view.convert(point, to: self.view)
            let action = self.tapActionAtPoint(localPoint, gesture: .tap, isEstimating: true)
            if case .none = action.content {
                return true
            } else {
                return false
            }
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.linkPreviewOptionsDisposable?.dispose()
        self.linkProgressDisposable?.dispose()
        self.codeHighlightState?.disposable.dispose()
    }
    
    override public func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize, _ avatarInset: CGFloat) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation, Bool, ListViewItemApply?) -> Void))) {
        let textLayout = InteractiveTextNodeWithEntities.asyncLayout(self.textNode)
        let statusLayout = ChatMessageDateAndStatusNode.asyncLayout(self.statusNode)
        
        let currentCachedChatMessageText = self.cachedChatMessageText
        let expandedBlockIds = self.expandedBlockIds
        let displayContentsUnderSpoilers = self.displayContentsUnderSpoilers
        
        return { item, layoutConstants, _, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: false, headerSpacing: 0.0, hidesBackground: .never, forceFullCorners: false, forceAlignment: .none)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                var topInset: CGFloat = 0.0
                var bottomInset: CGFloat = 0.0
                if case let .linear(top, bottom) = position {
                    switch top {
                    case .None:
                        topInset = layoutConstants.text.bubbleInsets.top
                    case let .Neighbour(_, topType, _):
                        switch topType {
                        case .text:
                            topInset = layoutConstants.text.bubbleInsets.top - 2.0
                        case .header, .footer, .media, .reactions:
                            topInset = layoutConstants.text.bubbleInsets.top
                        }
                    default:
                        topInset = layoutConstants.text.bubbleInsets.top
                    }
                    
                    switch bottom {
                    case .None:
                        bottomInset = layoutConstants.text.bubbleInsets.bottom
                    default:
                        bottomInset = layoutConstants.text.bubbleInsets.bottom - 3.0
                    }
                }
                
                let message = item.message
                
                var incoming = item.message.effectivelyIncoming(item.context.account.peerId)
                if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject {
                    if case .forward = info {
                        incoming = false
                    } else if case let .link(link) = info, link.isCentered {
                        incoming = true
                    }
                }
                
                var maxTextWidth = CGFloat.greatestFiniteMagnitude
                for media in item.message.media {
                    if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, content.type == "telegram_background" || content.type == "telegram_theme" {
                        maxTextWidth = layoutConstants.wallpapers.maxTextWidth
                        break
                    }
                }
                
                let horizontalInset = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                let textConstrainedSize = CGSize(width: min(maxTextWidth, constrainedSize.width - horizontalInset), height: constrainedSize.height)
                
                var edited = false
                if item.attributes.updatingMedia != nil {
                    edited = true
                }
                var viewCount: Int?
                var dateReplies = 0
                var starsCount: Int64?
                var dateReactionsAndPeers = mergedMessageReactionsAndPeers(accountPeerId: item.context.account.peerId, accountPeer: item.associatedData.accountPeer, message: item.topMessage)
                if item.message.isRestricted(platform: "ios", contentSettings: item.context.currentContentSettings.with { $0 }) {
                    dateReactionsAndPeers = ([], [])
                }
                
                for attribute in item.message.attributes {
                    if let attribute = attribute as? EditedMessageAttribute {
                        edited = !attribute.isHidden
                    } else if let attribute = attribute as? ViewCountMessageAttribute {
                        viewCount = attribute.count
                    } else if let attribute = attribute as? ReplyThreadMessageAttribute, case .peer = item.chatLocation {
                        if let channel = item.message.peers[item.message.id.peerId] as? TelegramChannel, case .group = channel.info {
                            dateReplies = Int(attribute.count)
                        }
                    } else if let attribute = attribute as? PaidStarsMessageAttribute, item.message.id.peerId.namespace == Namespaces.Peer.CloudChannel {
                        starsCount = attribute.stars.value
                    }
                }
                
                let dateFormat: MessageTimestampStatusFormat
                if item.presentationData.isPreview {
                    dateFormat = .full
                } else if let subject = item.associatedData.subject, case .messageOptions = subject {
                    dateFormat = .minimal
                } else {
                    dateFormat = .regular
                }
                let dateText = stringForMessageTimestampStatus(accountPeerId: item.context.account.peerId, message: item.message, dateTimeFormat: item.presentationData.dateTimeFormat, nameDisplayOrder: item.presentationData.nameDisplayOrder, strings: item.presentationData.strings, format: dateFormat, associatedData: item.associatedData)
                
                let statusType: ChatMessageDateAndStatusType?
                var displayStatus = false
                switch position {
                case let .linear(_, neighbor):
                    if case .None = neighbor {
                        displayStatus = true
                    } else if case .Neighbour(true, _, _) = neighbor {
                        displayStatus = true
                    }
                default:
                    break
                }
                if case let .customChatContents(contents) = item.associatedData.subject {
                    if case .hashTagSearch = contents.kind {
                        displayStatus = true
                    } else {
                        displayStatus = false
                    }
                } else if !item.presentationData.chatBubbleCorners.hasTails {
                    displayStatus = false
                } else if case let .messageOptions(_, _, info) = item.associatedData.subject, case let .link(link) = info, link.isCentered {
                    displayStatus = false
                }
                if displayStatus {
                    if incoming {
                        statusType = .BubbleIncoming
                    } else {
                        if message.flags.contains(.Failed) {
                            statusType = .BubbleOutgoing(.Failed)
                        } else if (message.flags.isSending && !message.isSentOrAcknowledged) || item.attributes.updatingMedia != nil {
                            statusType = .BubbleOutgoing(.Sending)
                        } else {
                            statusType = .BubbleOutgoing(.Sent(read: item.read))
                        }
                    }
                } else {
                    statusType = nil
                }
                
                var rawText: String
                var attributedText: NSAttributedString
                var messageEntities: [MessageTextEntity]?
                
                var mediaDuration: Double? = nil
                var isSeekableWebMedia = false
                var isUnsupportedMedia = false
                var story: Stories.Item?
                var invoice: TelegramMediaInvoice?
                for media in item.message.media {
                    if let file = media as? TelegramMediaFile, let duration = file.duration {
                        mediaDuration = Double(duration)
                    }
                    if let media = media as? TelegramMediaInvoice, media.currency == "XTR" {
                        invoice = media
                    } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, webEmbedType(content: content).supportsSeeking {
                        isSeekableWebMedia = true
                    } else if media is TelegramMediaUnsupported {
                        isUnsupportedMedia = true
                    } else if let storyMedia = media as? TelegramMediaStory {
                        if let value = item.message.associatedStories[storyMedia.storyId]?.get(Stories.StoredItem.self) {
                            if case let .item(storyValue) = value {
                                story = storyValue
                            }
                        }
                    }
                }
                
                var isTranslating = false
                if let invoice {
                    rawText = invoice.description
                } else if let story {
                    rawText = story.text
                    messageEntities = story.entities
                } else if isUnsupportedMedia {
                    rawText = item.presentationData.strings.Conversation_UnsupportedMediaPlaceholder
                    messageEntities = [MessageTextEntity(range: 0..<rawText.count, type: .Italic)]
                } else {
                    if let updatingMedia = item.attributes.updatingMedia {
                        rawText = updatingMedia.text
                    } else {
                        rawText = item.message.text
                    }
                    
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            messageEntities = attribute.entities
                        } else if mediaDuration == nil, let attribute = attribute as? ReplyMessageAttribute {
                            if let replyMessage = item.message.associatedMessages[attribute.messageId] {
                                for media in replyMessage.media {
                                    if let file = media as? TelegramMediaFile, let duration = file.duration {
                                        mediaDuration = Double(duration)
                                    }
                                    if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content, webEmbedType(content: content).supportsSeeking {
                                        isSeekableWebMedia = true
                                    }
                                }
                            }
                        }
                    }
                    
                    if let updatingMedia = item.attributes.updatingMedia {
                        messageEntities = updatingMedia.entities?.entities ?? []
                    }
                    
                    if let subject = item.associatedData.subject, case .messageOptions = subject {
                    } else if let translateToLanguage = item.associatedData.translateToLanguage, !item.message.text.isEmpty && incoming {
                        isTranslating = true
                        for attribute in item.message.attributes {
                            if let attribute = attribute as? TranslationMessageAttribute, !attribute.text.isEmpty, attribute.toLang == translateToLanguage {
                                rawText = attribute.text
                                messageEntities = attribute.entities
                                isTranslating = false
                                break
                            }
                        }
                    }
                }
                
                var entities: [MessageTextEntity]?
                var updatedCachedChatMessageText: CachedChatMessageText?
                if let cached = currentCachedChatMessageText, cached.matches(text: rawText, inputEntities: messageEntities) {
                    entities = cached.entities
                } else {
                    entities = messageEntities
                    
                    if entities == nil && (mediaDuration != nil || isSeekableWebMedia) {
                        entities = []
                    }
                    
                    if let entitiesValue = entities {
                        var enabledTypes: EnabledEntityTypes = .all
                        if mediaDuration != nil || isSeekableWebMedia {
                            enabledTypes.insert(.timecode)
                            if mediaDuration == nil {
                                mediaDuration = 60.0 * 60.0 * 24.0
                            }
                        }
                        if let result = addLocallyGeneratedEntities(rawText, enabledTypes: enabledTypes, entities: entitiesValue, mediaDuration: mediaDuration) {
                            entities = result
                        }
                    } else {
                        var generateEntities = false
                        for media in message.media {
                            if media is TelegramMediaImage || media is TelegramMediaFile {
                                generateEntities = true
                                break
                            }
                        }
                        if message.id.peerId.namespace == Namespaces.Peer.SecretChat {
                           generateEntities = true
                        }
                        if generateEntities {
                            let parsedEntities = generateTextEntities(rawText, enabledTypes: .all)
                            if !parsedEntities.isEmpty {
                                entities = parsedEntities
                            }
                        }
                    }
                    
                    if !item.associatedData.hasBots {
                        messageEntities = messageEntities?.filter { $0.type != .BotCommand }
                        entities = entities?.filter { $0.type != .BotCommand }
                    }
                    
                    updatedCachedChatMessageText = CachedChatMessageText(text: rawText, inputEntities: messageEntities, entities: entities)
                }
                
                
                let messageTheme = incoming ? item.presentationData.theme.theme.chat.message.incoming : item.presentationData.theme.theme.chat.message.outgoing
                
                let textFont = item.presentationData.messageFont
                
                var codeHighlightSpecs: [CachedMessageSyntaxHighlight.Spec] = []
                var cachedMessageSyntaxHighlight: CachedMessageSyntaxHighlight?
                
                if let entities {
                    var underlineLinks = true
                    if !messageTheme.primaryTextColor.isEqual(messageTheme.linkTextColor) {
                        underlineLinks = false
                    }
                    
                    let author = item.message.author
                    let mainColor: UIColor
                    var secondaryColor: UIColor? = nil
                    var tertiaryColor: UIColor? = nil
                    
                    let nameColors = author?.nameColor.flatMap { item.context.peerNameColors.get($0, dark: item.presentationData.theme.theme.overallDarkAppearance) }
                    let codeBlockTitleColor: UIColor
                    let codeBlockAccentColor: UIColor
                    let codeBlockBackgroundColor: UIColor
                    if !incoming {
                        mainColor = messageTheme.accentTextColor
                        if let _ = nameColors?.secondary {
                            secondaryColor = .clear
                        }
                        if let _ = nameColors?.tertiary {
                            tertiaryColor = .clear
                        }
                        
                        if item.presentationData.theme.theme.overallDarkAppearance {
                            codeBlockTitleColor = .white
                            codeBlockAccentColor = UIColor(white: 1.0, alpha: 0.5)
                            codeBlockBackgroundColor = UIColor(white: 0.0, alpha: 0.25)
                        } else {
                            codeBlockTitleColor = mainColor
                            codeBlockAccentColor = mainColor
                            codeBlockBackgroundColor = mainColor.withMultipliedAlpha(0.1)
                        }
                    } else {
                        let authorNameColor = nameColors?.main
                        secondaryColor = nameColors?.secondary
                        tertiaryColor = nameColors?.tertiary
                        
                        if let authorNameColor {
                            mainColor = authorNameColor
                        } else {
                            mainColor = messageTheme.accentTextColor
                        }
                        
                        codeBlockTitleColor = mainColor
                        codeBlockAccentColor = mainColor
                        
                        if item.presentationData.theme.theme.overallDarkAppearance {
                            codeBlockBackgroundColor = UIColor(white: 0.0, alpha: 0.65)
                        } else {
                            codeBlockBackgroundColor = UIColor(white: 0.0, alpha: 0.05)
                        }
                    }
                    
                    codeHighlightSpecs = extractMessageSyntaxHighlightSpecs(text: rawText, entities: entities)
                    
                    if !codeHighlightSpecs.isEmpty {
                        for attribute in message.attributes {
                            if let attribute = attribute as? DerivedDataMessageAttribute {
                                if let value = attribute.data["code"]?.get(CachedMessageSyntaxHighlight.self) {
                                    cachedMessageSyntaxHighlight = value
                                }
                            }
                        }
                    }
                    
                    attributedText = stringWithAppliedEntities(rawText, entities: entities, baseColor: messageTheme.primaryTextColor, linkColor: messageTheme.linkTextColor, baseQuoteTintColor: mainColor, baseQuoteSecondaryTintColor: secondaryColor, baseQuoteTertiaryTintColor: tertiaryColor, codeBlockTitleColor: codeBlockTitleColor, codeBlockAccentColor: codeBlockAccentColor, codeBlockBackgroundColor: codeBlockBackgroundColor, baseFont: textFont, linkFont: textFont, boldFont: item.presentationData.messageBoldFont, italicFont: item.presentationData.messageItalicFont, boldItalicFont: item.presentationData.messageBoldItalicFont, fixedFont: item.presentationData.messageFixedFont, blockQuoteFont: item.presentationData.messageBlockQuoteFont, underlineLinks: underlineLinks, message: item.message, adjustQuoteFontSize: true, cachedMessageSyntaxHighlight: cachedMessageSyntaxHighlight)
                } else if !rawText.isEmpty {
                    attributedText = NSAttributedString(string: rawText, font: textFont, textColor: messageTheme.primaryTextColor)
                } else {
                    attributedText = NSAttributedString(string: " ", font: textFont, textColor: messageTheme.primaryTextColor)
                }
                
                if let entities = entities {
                    let updatedString = NSMutableAttributedString(attributedString: attributedText)
                    
                    for entity in entities.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
                        guard case let .CustomEmoji(_, fileId) = entity.type else {
                            continue
                        }
                        
                        let range = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                        
                        let currentDict = updatedString.attributes(at: range.lowerBound, effectiveRange: nil)
                        var updatedAttributes: [NSAttributedString.Key: Any] = currentDict
                        updatedAttributes[ChatTextInputAttributes.customEmoji] = ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: fileId, file: item.message.associatedMedia[MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)] as? TelegramMediaFile)
                        
                        let insertString = NSAttributedString(string: updatedString.attributedSubstring(from: range).string, attributes: updatedAttributes)
                        updatedString.replaceCharacters(in: range, with: insertString)
                    }
                    attributedText = updatedString
                }
                                
                var customTruncationToken: ((UIFont, Bool) -> NSAttributedString?)?
                var maximumNumberOfLines: Int = 0
                if item.presentationData.isPreview {
                    if item.message.groupingKey != nil {
                        maximumNumberOfLines = 6
                    } else if let image = item.message.media.first(where: { $0 is TelegramMediaImage }) as? TelegramMediaImage, let dimensions = image.representations.first?.dimensions {
                        if dimensions.width > dimensions.height {
                            maximumNumberOfLines = 9
                        } else {
                            maximumNumberOfLines = 6
                        }
                    } else if let file = item.message.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile, file.isVideo || file.isAnimated, let dimensions = file.dimensions {
                        if dimensions.width > dimensions.height {
                            maximumNumberOfLines = 9
                        } else {
                            maximumNumberOfLines = 6
                        }
                    } else if let _ = item.message.media.first(where: { $0 is TelegramMediaWebpage }) as? TelegramMediaWebpage {
                        maximumNumberOfLines = 9
                    } else {
                        maximumNumberOfLines = 12
                    }
                    
                    let truncationTokenText = item.presentationData.strings.Conversation_ReadMore
                    customTruncationToken = { baseFont, isQuote in
                        let truncationToken = NSMutableAttributedString()
                        if isQuote {
                            truncationToken.append(NSAttributedString(string: "\u{2026}", font: Font.regular(baseFont.pointSize), textColor: messageTheme.primaryTextColor))
                        } else {
                            truncationToken.append(NSAttributedString(string: "\u{2026} ", font: Font.regular(baseFont.pointSize), textColor: messageTheme.primaryTextColor))
                            truncationToken.append(NSAttributedString(string: truncationTokenText, font: Font.regular(baseFont.pointSize), textColor: messageTheme.accentTextColor))
                        }
                        return truncationToken
                    }
                }
                
                let textInsets = UIEdgeInsets(top: 2.0, left: 2.0, bottom: 5.0, right: 2.0)
                let (textLayout, textApply) = textLayout(InteractiveTextNodeLayoutArguments(
                    attributedString: attributedText,
                    backgroundColor: nil,
                    maximumNumberOfLines: maximumNumberOfLines,
                    truncationType: .end,
                    constrainedSize: textConstrainedSize,
                    alignment: .natural,
                    cutout: nil,
                    insets: textInsets,
                    lineColor: messageTheme.accentControlColor,
                    displayContentsUnderSpoilers: displayContentsUnderSpoilers.value,
                    customTruncationToken: customTruncationToken,
                    expandedBlocks: expandedBlockIds
                ))
            
                var statusSuggestedWidthAndContinue: (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> ChatMessageDateAndStatusNode))?
                if let statusType = statusType {
                    var isReplyThread = false
                    if case .replyThread = item.chatLocation {
                        isReplyThread = true
                    }
                    
                    let trailingWidthToMeasure: CGFloat
                    if let lastSegment = textLayout.segments.last, lastSegment.hasRTL {
                        trailingWidthToMeasure = 10000.0
                    } else if let lastSegment = textLayout.segments.last, lastSegment.hasBlockQuote {
                        trailingWidthToMeasure = textLayout.size.width
                    } else {
                        trailingWidthToMeasure = textLayout.trailingLineWidth
                    }
                    
                    let dateLayoutInput: ChatMessageDateAndStatusNode.LayoutInput
                    dateLayoutInput = .trailingContent(contentWidth: trailingWidthToMeasure, reactionSettings: ChatMessageDateAndStatusNode.TrailingReactionSettings(displayInline: shouldDisplayInlineDateReactions(message: item.message, isPremium: item.associatedData.isPremium, forceInline: item.associatedData.forceInlineReactions), preferAdditionalInset: false))
                    
                    statusSuggestedWidthAndContinue = statusLayout(ChatMessageDateAndStatusNode.Arguments(
                        context: item.context,
                        presentationData: item.presentationData,
                        edited: edited && !item.presentationData.isPreview,
                        impressionCount: !item.presentationData.isPreview ? viewCount : nil,
                        dateText: dateText,
                        type: statusType,
                        layoutInput: dateLayoutInput,
                        constrainedSize: textConstrainedSize,
                        availableReactions: item.associatedData.availableReactions,
                        savedMessageTags: item.associatedData.savedMessageTags,
                        reactions: item.presentationData.isPreview ? [] : dateReactionsAndPeers.reactions,
                        reactionPeers: dateReactionsAndPeers.peers,
                        displayAllReactionPeers: item.message.id.peerId.namespace == Namespaces.Peer.CloudUser,
                        areReactionsTags: item.topMessage.areReactionsTags(accountPeerId: item.context.account.peerId),
                        messageEffect: item.topMessage.messageEffect(availableMessageEffects: item.associatedData.availableMessageEffects),
                        replyCount: dateReplies,
                        starsCount: starsCount,
                        isPinned: item.message.tags.contains(.pinned) && (!item.associatedData.isInPinnedListMode || isReplyThread),
                        hasAutoremove: item.message.isSelfExpiring,
                        canViewReactionList: canViewMessageReactionList(message: item.topMessage),
                        animationCache: item.controllerInteraction.presentationContext.animationCache,
                        animationRenderer: item.controllerInteraction.presentationContext.animationRenderer
                    ))
                }
                
                var textFrame = CGRect(origin: CGPoint(x: -textInsets.left, y: -textInsets.top), size: textLayout.size)
                var textFrameWithoutInsets = CGRect(origin: CGPoint(x: textFrame.origin.x + textInsets.left, y: textFrame.origin.y + textInsets.top), size: CGSize(width: textFrame.width - textInsets.left - textInsets.right, height: textFrame.height - textInsets.top - textInsets.bottom))
                
                textFrame = textFrame.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: topInset)
                textFrameWithoutInsets = textFrameWithoutInsets.offsetBy(dx: layoutConstants.text.bubbleInsets.left, dy: topInset)
                
                var suggestedBoundingWidth: CGFloat = textFrameWithoutInsets.width
                if let statusSuggestedWidthAndContinue = statusSuggestedWidthAndContinue {
                    suggestedBoundingWidth = max(suggestedBoundingWidth, statusSuggestedWidthAndContinue.0)
                }
                let sideInsets = layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                suggestedBoundingWidth += sideInsets
                
                return (suggestedBoundingWidth, { boundingWidth in
                    var boundingSize: CGSize
                    
                    let statusSizeAndApply = statusSuggestedWidthAndContinue?.1(boundingWidth - sideInsets)
                    
                    boundingSize = textFrameWithoutInsets.size
                    if let statusSizeAndApply = statusSizeAndApply {
                        boundingSize.height += statusSizeAndApply.0.height
                    }
                    
                    boundingSize.width += layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right
                    
                    boundingSize.height += topInset + bottomInset
                    
                    return (boundingSize, { [weak self] animation, synchronousLoads, itemApply in
                        if let strongSelf = self {
                            strongSelf.item = item
                            if let updatedCachedChatMessageText = updatedCachedChatMessageText {
                                strongSelf.cachedChatMessageText = updatedCachedChatMessageText
                            }
                            
                            strongSelf.textNode.textNode.displaysAsynchronously = !item.presentationData.isPreview
                            strongSelf.containerNode.frame = CGRect(origin: CGPoint(), size: boundingSize)
                            
                            if strongSelf.appliedExpandedBlockIds != nil && strongSelf.appliedExpandedBlockIds != strongSelf.expandedBlockIds {
                                itemApply?.setInvertOffsetDirection()
                            }
                            strongSelf.appliedExpandedBlockIds = strongSelf.expandedBlockIds
                            
                            var spoilerExpandRect: CGRect?
                            if let location = strongSelf.displayContentsUnderSpoilers.location {
                                strongSelf.displayContentsUnderSpoilers.location = nil
                                
                                let mappedLocation = CGPoint(x: location.x - textFrame.minX, y: location.y - textFrame.minY)
                                
                                let getDistance: (CGPoint, CGPoint) -> CGFloat = { a, b in
                                    let v = CGPoint(x: a.x - b.x, y: a.y - b.y)
                                    return sqrt(v.x * v.x + v.y * v.y)
                                }
                                
                                var maxDistance: CGFloat = getDistance(mappedLocation, CGPoint(x: 0.0, y: 0.0))
                                maxDistance = max(maxDistance, getDistance(mappedLocation, CGPoint(x: textFrame.width, y: 0.0)))
                                maxDistance = max(maxDistance, getDistance(mappedLocation, CGPoint(x: textFrame.width, y: textFrame.height)))
                                maxDistance = max(maxDistance, getDistance(mappedLocation, CGPoint(x: 0.0, y: textFrame.height)))
                                
                                let mappedSize = CGSize(width: maxDistance * 2.0, height: maxDistance * 2.0)
                                spoilerExpandRect = mappedSize.centered(around: mappedLocation)
                            }
                            
                            let _ = textApply(InteractiveTextNodeWithEntities.Arguments(
                                context: item.context,
                                cache: item.controllerInteraction.presentationContext.animationCache,
                                renderer: item.controllerInteraction.presentationContext.animationRenderer,
                                placeholderColor: messageTheme.mediaPlaceholderColor,
                                attemptSynchronous: synchronousLoads,
                                textColor: messageTheme.primaryTextColor,
                                spoilerEffectColor: messageTheme.secondaryTextColor,
                                applyArguments: InteractiveTextNode.ApplyArguments(
                                    animation: animation,
                                    spoilerTextColor: messageTheme.primaryTextColor,
                                    spoilerEffectColor: messageTheme.secondaryTextColor,
                                    areContentAnimationsEnabled: item.context.sharedContext.energyUsageSettings.loopEmoji,
                                    spoilerExpandRect: spoilerExpandRect,
                                    crossfadeContents: { [weak strongSelf] sourceView in
                                        guard let strongSelf else {
                                            return
                                        }
                                        if let textNodeContainer = strongSelf.textNode.textNode.view.superview {
                                            sourceView.frame = CGRect(origin: strongSelf.textNode.textNode.frame.origin, size: sourceView.bounds.size)
                                            textNodeContainer.addSubview(sourceView)
                                            
                                            sourceView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.12, removeOnCompletion: false, completion: { [weak sourceView] _ in
                                                sourceView?.removeFromSuperview()
                                            })
                                            strongSelf.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1)
                                        }
                                    }
                                )
                            ))
                            animation.animator.updateFrame(layer: strongSelf.textNode.textNode.layer, frame: textFrame, completion: nil)
                            
                            switch strongSelf.visibility {
                            case .none:
                                strongSelf.textNode.visibilityRect = nil
                            case let .visible(_, subRect):
                                var subRect = subRect
                                subRect.origin.x = 0.0
                                subRect.size.width = 10000.0
                                strongSelf.textNode.visibilityRect = subRect
                            }
                            
                            if let textSelectionNode = strongSelf.textSelectionNode {
                                let shouldUpdateLayout = textSelectionNode.frame.size != textFrame.size
                                textSelectionNode.frame = textFrame
                                textSelectionNode.highlightAreaNode.frame = textFrame
                                if shouldUpdateLayout {
                                    textSelectionNode.updateLayout()
                                }
                            }
                            strongSelf.textAccessibilityOverlayNode.frame = textFrame
                            //TODO:release
                            //strongSelf.textAccessibilityOverlayNode.cachedLayout = textLayout
                    
                            strongSelf.updateIsTranslating(isTranslating)
                            
                            if let statusSizeAndApply {
                                let statusNode = statusSizeAndApply.1(strongSelf.statusNode == nil ? .None : animation)
                                let statusFrame = CGRect(origin: CGPoint(x: textFrameWithoutInsets.minX, y: textFrameWithoutInsets.maxY), size: statusSizeAndApply.0)
                                
                                if strongSelf.statusNode !== statusNode {
                                    strongSelf.statusNode?.removeFromSupernode()
                                    strongSelf.statusNode = statusNode
                                    
                                    strongSelf.addSubnode(statusNode)
                                    
                                    statusNode.reactionSelected = { [weak strongSelf] _, value, sourceView in
                                        guard let strongSelf, let item = strongSelf.item else {
                                            return
                                        }
                                        item.controllerInteraction.updateMessageReaction(item.topMessage, .reaction(value), false, sourceView)
                                    }
                                    statusNode.openReactionPreview = { [weak strongSelf] gesture, sourceNode, value in
                                        guard let strongSelf, let item = strongSelf.item else {
                                            gesture?.cancel()
                                            return
                                        }
                                        
                                        item.controllerInteraction.openMessageReactionContextMenu(item.topMessage, sourceNode, gesture, value)
                                    }
                                    statusNode.frame = statusFrame
                                } else {
                                    animation.animator.updateFrame(layer: statusNode.layer, frame: statusFrame, completion: nil)
                                }
                            } else if let statusNode = strongSelf.statusNode {
                                strongSelf.statusNode = nil
                                statusNode.removeFromSupernode()
                            }
                            
                            if let forwardInfo = item.message.forwardInfo, forwardInfo.flags.contains(.isImported), let statusNode = strongSelf.statusNode {
                                statusNode.pressed = {
                                    guard let strongSelf = self, let statusNode = strongSelf.statusNode else {
                                        return
                                    }
                                    item.controllerInteraction.displayImportedMessageTooltip(statusNode)
                                }
                            } else {
                                strongSelf.statusNode?.pressed = nil
                            }
                            
                            if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject {
                                if case let .reply(info) = info {
                                    if strongSelf.textSelectionNode == nil {
                                        strongSelf.updateIsExtractedToContextPreview(true)
                                        if let initialQuote = info.quote, item.message.id == initialQuote.messageId {
                                            let nsString = item.message.text as NSString
                                            let subRange = nsString.range(of: initialQuote.text)
                                            if subRange.location != NSNotFound {
                                                strongSelf.beginTextSelection(range: subRange, displayMenu: true)
                                            }
                                        }
                                        
                                        if strongSelf.textSelectionState == nil {
                                            if let textSelectionNode = strongSelf.textSelectionNode {
                                                let range = textSelectionNode.getSelection()
                                                strongSelf.textSelectionState = Promise(strongSelf.getSelectionState(range: range))
                                            } else {
                                                strongSelf.textSelectionState = Promise(strongSelf.getSelectionState(range: nil))
                                            }
                                        }
                                        if let textSelectionState = strongSelf.textSelectionState {
                                            info.selectionState.set(textSelectionState.get())
                                        }
                                    }
                                } else if case let .link(link) = info {
                                    if strongSelf.linkPreviewOptionsDisposable == nil {
                                        strongSelf.linkPreviewOptionsDisposable = (link.options
                                        |> deliverOnMainQueue).startStrict(next: { [weak strongSelf] options in
                                            guard let strongSelf else {
                                                return
                                            }
                                            
                                            if options.hasAlternativeLinks {
                                                strongSelf.linkPreviewHighlightText = options.url
                                                strongSelf.updateLinkPreviewTextHighlightState(text: strongSelf.linkPreviewHighlightText)
                                            }
                                        })
                                    }
                                }
                            }
                            
                            strongSelf.updateLinkProgressState()
                            if let linkPreviewHighlightText = strongSelf.linkPreviewHighlightText {
                                strongSelf.updateLinkPreviewTextHighlightState(text: linkPreviewHighlightText)
                            }
                            
                            if !codeHighlightSpecs.isEmpty {
                                if let current = strongSelf.codeHighlightState, current.id == message.id, current.specs == codeHighlightSpecs {
                                } else {
                                    if let codeHighlightState = strongSelf.codeHighlightState {
                                        strongSelf.codeHighlightState = nil
                                        codeHighlightState.disposable.dispose()
                                    }
                                    
                                    let disposable = MetaDisposable()
                                    strongSelf.codeHighlightState = (message.id, codeHighlightSpecs, disposable)
                                    disposable.set(asyncUpdateMessageSyntaxHighlight(engine: item.context.engine, messageId: message.id, current: cachedMessageSyntaxHighlight, specs: codeHighlightSpecs).startStrict(completed: {
                                    }))
                                }
                            } else if let codeHighlightState = strongSelf.codeHighlightState {
                                strongSelf.codeHighlightState = nil
                                codeHighlightState.disposable.dispose()
                            }
                        }
                    })
                })
            })
        }
    }
    
    override public func animateInsertion(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateAdded(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.statusNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override public func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        self.textNode.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.statusNode?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override public func tapActionAtPoint(_ point: CGPoint, gesture: TapLongTapOrDoubleTapGesture, isEstimating: Bool) -> ChatMessageBubbleContentTapAction {
        if case .tap = gesture {
        } else {
            if let item = self.item, let subject = item.associatedData.subject, case .messageOptions = subject {
                return ChatMessageBubbleContentTapAction(content: .none)
            }
        }
        
        func makeActivate(_ urlRange: NSRange?) -> (() -> Promise<Bool>?)? {
            return { [weak self] in
                guard let self else {
                    return nil
                }
                
                let promise = Promise<Bool>()
                
                self.linkProgressDisposable?.dispose()
                
                if self.linkProgressRange != nil {
                    self.linkProgressRange = nil
                    self.updateLinkProgressState()
                }
                
                self.linkProgressDisposable = (promise.get() |> deliverOnMainQueue).startStrict(next: { [weak self] value in
                    guard let self else {
                        return
                    }
                    let updatedRange: NSRange? = value ? urlRange : nil
                    if self.linkProgressRange != updatedRange {
                        self.linkProgressRange = updatedRange
                        self.updateLinkProgressState()
                    }
                })
                
                return promise
            }
        }
        
        let textNodeFrame = self.textNode.textNode.frame
        let textLocalPoint = CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)
        if let (index, attributes) = self.textNode.textNode.attributesAtPoint(textLocalPoint) {
            var rects: [CGRect]?
            let possibleNames: [String] = [
                TelegramTextAttributes.URL,
                TelegramTextAttributes.PeerMention,
                TelegramTextAttributes.PeerTextMention,
                TelegramTextAttributes.BotCommand,
                TelegramTextAttributes.Hashtag,
                TelegramTextAttributes.Timecode,
                TelegramTextAttributes.BankCard
            ]
            for name in possibleNames {
                if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                    rects = self.textNode.textNode.attributeRects(name: name, at: index)
                    break
                }
            }
            
            
            if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)], !self.displayContentsUnderSpoilers.value {
                return ChatMessageBubbleContentTapAction(content: .none)
            } else if let url = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                var urlRange: NSRange?
                if let (attributeText, fullText, urlRangeValue) = self.textNode.textNode.attributeSubstringWithRange(name: TelegramTextAttributes.URL, index: index) {
                    urlRange = urlRangeValue
                    concealed = !doesUrlMatchText(url: url, text: attributeText, fullText: fullText)
                }
                
                var content: ChatMessageBubbleContentTapAction.Content
                if url.hasPrefix("tel:") {
                    content = .phone(url.replacingOccurrences(of: "tel:", with: ""))
                } else {
                    content = .url(ChatMessageBubbleContentTapAction.Url(url: url, concealed: concealed))
                }
                
                return ChatMessageBubbleContentTapAction(content: content, rects: rects, activate: makeActivate(urlRange))
            } else if let peerMention = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return ChatMessageBubbleContentTapAction(content: .peerMention(peerId: peerMention.peerId, mention: peerMention.mention, openProfile: false), rects: rects)
            } else if let peerName = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                var urlRange: NSRange?
                if let (_, _, urlRangeValue) = self.textNode.textNode.attributeSubstringWithRange(name: TelegramTextAttributes.PeerTextMention, index: index) {
                    urlRange = urlRangeValue
                }
                
                return ChatMessageBubbleContentTapAction(content: .textMention(peerName), rects: rects, activate: makeActivate(urlRange))
            } else if let botCommand = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return ChatMessageBubbleContentTapAction(content: .botCommand(botCommand), rects: rects)
            } else if let hashtag = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return ChatMessageBubbleContentTapAction(content: .hashtag(hashtag.peerName, hashtag.hashtag), rects: rects)
            } else if let timecode = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Timecode)] as? TelegramTimecode {
                return ChatMessageBubbleContentTapAction(content: .timecode(timecode.time, timecode.text), rects: rects)
            } else if let bankCard = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.BankCard)] as? String {
                var urlRange: NSRange?
                if let (_, _, urlRangeValue) = self.textNode.textNode.attributeSubstringWithRange(name: TelegramTextAttributes.BankCard, index: index) {
                    urlRange = urlRangeValue
                }
                return ChatMessageBubbleContentTapAction(content: .bankCard(bankCard), rects: rects, activate: makeActivate(urlRange))
            } else if let pre = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Pre)] as? String {
                return ChatMessageBubbleContentTapAction(content: .copy(pre))
            } else if let code = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Code)] as? String {
                return ChatMessageBubbleContentTapAction(content: .copy(code))
            } else if let _ = attributes[NSAttributedString.Key(rawValue: "Attribute__Blockquote")] {
                if let _ = self.textNode.textNode.collapsibleBlockAtPoint(textLocalPoint) {
                    return ChatMessageBubbleContentTapAction(content: .none)
                } else {
                    if let text = self.textNode.textNode.attributeSubstring(name: "Attribute__Blockquote", index: index) {
                        return ChatMessageBubbleContentTapAction(content: .copy(text.0))
                    } else {
                        return ChatMessageBubbleContentTapAction(content: .none)
                    }
                }
            } else if let emoji = attributes[NSAttributedString.Key(rawValue: ChatTextInputAttributes.customEmoji.rawValue)] as? ChatTextInputTextCustomEmojiAttribute, let file = emoji.file {
                return ChatMessageBubbleContentTapAction(content: .customEmoji(file))
            } else {
                if let item = self.item, item.message.text.count == 1, !item.presentationData.largeEmoji {
                    let (emoji, fitz) = item.message.text.basicEmoji
                    var emojiFile: TelegramMediaFile?
                    
                    emojiFile = item.associatedData.animatedEmojiStickers[emoji]?.first?.file._parse()
                    if emojiFile == nil {
                        emojiFile = item.associatedData.animatedEmojiStickers[emoji.strippedEmoji]?.first?.file._parse()
                    }
                    
                    if let emojiFile = emojiFile {
                        return ChatMessageBubbleContentTapAction(content: .largeEmoji(emoji, fitz, emojiFile))
                    } else {
                        return ChatMessageBubbleContentTapAction(content: .none)
                    }
                } else {
                    return ChatMessageBubbleContentTapAction(content: .none)
                }
            }
        } else {
            if let statusNode = self.statusNode, let _ = statusNode.hitTest(self.view.convert(point, to: statusNode.view), with: nil) {
                return ChatMessageBubbleContentTapAction(content: .ignore)
            }
            return ChatMessageBubbleContentTapAction(content: .none)
        }
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let statusNode = self.statusNode, statusNode.supernode != nil, let result = statusNode.hitTest(self.view.convert(point, to: statusNode.view), with: event) {
            return result
        }
        return super.hitTest(point, with: event)
    }
    
    private func updateIsTranslating(_ isTranslating: Bool) {
        guard let item = self.item else {
            return
        }
        let rects = self.textNode.textNode.rangeRects(in: NSRange(location: 0, length: self.textNode.textNode.cachedLayout?.attributedString?.length ?? 0))?.rects ?? [] 
        if isTranslating, !rects.isEmpty {
            let shimmeringNode: ShimmeringLinkNode
            if let current = self.shimmeringNode {
                shimmeringNode = current
            } else {
                shimmeringNode = ShimmeringLinkNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.secondaryTextColor.withAlphaComponent(0.1) : item.presentationData.theme.theme.chat.message.outgoing.secondaryTextColor.withAlphaComponent(0.1))
                shimmeringNode.updateRects(rects)
                shimmeringNode.frame = self.textNode.textNode.frame
                shimmeringNode.updateLayout(self.textNode.textNode.frame.size)
                shimmeringNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                self.shimmeringNode = shimmeringNode
                self.containerNode.insertSubnode(shimmeringNode, belowSubnode: self.textNode.textNode)
            }
        } else if let shimmeringNode = self.shimmeringNode {
            self.shimmeringNode = nil
            shimmeringNode.alpha = 0.0
            shimmeringNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { [weak shimmeringNode] _ in
                shimmeringNode?.removeFromSupernode()
            })
        }
    }
    
    override public func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [CGRect]?
            var spoilerRects: [CGRect]?
            if let point = point {
                let textNodeFrame = self.textNode.textNode.frame
                if let (index, attributes) = self.textNode.textNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.URL,
                        TelegramTextAttributes.PeerMention,
                        TelegramTextAttributes.PeerTextMention,
                        TelegramTextAttributes.BotCommand,
                        TelegramTextAttributes.Hashtag,
                        TelegramTextAttributes.Timecode,
                        TelegramTextAttributes.BankCard
                    ]
                    for name in possibleNames {
                        if let _ = attributes[NSAttributedString.Key(rawValue: name)] {
                            rects = self.textNode.textNode.attributeRects(name: name, at: index)
                            break
                        }
                    }
                    if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.Spoiler)] {
                        spoilerRects = self.textNode.textNode.attributeRects(name: TelegramTextAttributes.Spoiler, at: index)
                    }
                }
            }
            
            if let spoilerRects = spoilerRects, !spoilerRects.isEmpty, !self.displayContentsUnderSpoilers.value {
            } else if let rects = rects {
                let linkHighlightingNode: LinkHighlightingNode
                if let current = self.linkHighlightingNode {
                    linkHighlightingNode = current
                } else {
                    linkHighlightingNode = LinkHighlightingNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.linkHighlightColor : item.presentationData.theme.theme.chat.message.outgoing.linkHighlightColor)
                    self.linkHighlightingNode = linkHighlightingNode
                    self.containerNode.insertSubnode(linkHighlightingNode, belowSubnode: self.textNode.textNode)
                }
                linkHighlightingNode.frame = self.textNode.textNode.frame
                linkHighlightingNode.updateRects(rects)
            } else if let linkHighlightingNode = self.linkHighlightingNode {
                self.linkHighlightingNode = nil
                linkHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.18, removeOnCompletion: false, completion: { [weak linkHighlightingNode] _ in
                    linkHighlightingNode?.removeFromSupernode()
                })
            }
        }
    }
    
    override public func updateSearchTextHighlightState(text: String?, messages: [MessageIndex]?) {
        guard let item = self.item else {
            return
        }
        let rectsSet: [[CGRect]]
        if let text = text, let messages = messages, !text.isEmpty, messages.contains(item.message.index) {
            rectsSet = self.textNode.textNode.textRangesRects(text: text)
        } else {
            rectsSet = []
        }
        for i in 0 ..< rectsSet.count {
            var rects = rectsSet[i]
            if rects.count > 1 {
                for i in 0 ..< rects.count - 1 {
                    let deltaY = rects[i + 1].minY - rects[i].maxY
                    if deltaY > 0.0 && deltaY <= 2.0 {
                        rects[i].size.height += deltaY * 0.5
                        rects[i + 1].size.height += deltaY * 0.5
                        rects[i + 1].origin.y -= deltaY * 0.5
                    }
                }
            }
            let textHighlightNode: LinkHighlightingNode
            if i < self.textHighlightingNodes.count {
                textHighlightNode = self.textHighlightingNodes[i]
            } else {
                textHighlightNode = LinkHighlightingNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.textHighlightColor : item.presentationData.theme.theme.chat.message.outgoing.textHighlightColor)
                self.textHighlightingNodes.append(textHighlightNode)
                self.containerNode.insertSubnode(textHighlightNode, belowSubnode: self.textNode.textNode)
            }
            textHighlightNode.frame = self.textNode.textNode.frame
            textHighlightNode.updateRects(rects)
        }
        for i in (rectsSet.count ..< self.textHighlightingNodes.count).reversed() {
            self.textHighlightingNodes[i].removeFromSupernode()
            self.textHighlightingNodes.remove(at: i)
        }
    }
    
    private func updateLinkPreviewTextHighlightState(text: String?) {
        guard let item = self.item else {
            return
        }
        
        var rectsSet: [[CGRect]] = []
        if let text = text, !text.isEmpty, let cachedLayout = self.textNode.textNode.cachedLayout, let string = cachedLayout.attributedString?.string {
            let nsString = string as NSString
            let range = nsString.range(of: text)
            if range.location != NSNotFound {
                if let rects = cachedLayout.rangeRects(in: range)?.rects, !rects.isEmpty {
                    rectsSet = [rects]
                }
            }
        }
        for i in 0 ..< rectsSet.count {
            let rects = rectsSet[i]
            let textHighlightNode: LinkHighlightingNode
            if i < self.linkPreviewHighlightingNodes.count {
                textHighlightNode = self.linkPreviewHighlightingNodes[i]
            } else {
                textHighlightNode = LinkHighlightingNode(color: item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.linkHighlightColor.withMultipliedAlpha(0.5) : item.presentationData.theme.theme.chat.message.outgoing.linkHighlightColor.withMultipliedAlpha(0.5))
                self.linkPreviewHighlightingNodes.append(textHighlightNode)
                self.containerNode.insertSubnode(textHighlightNode, belowSubnode: self.textNode.textNode)
            }
            textHighlightNode.frame = self.textNode.textNode.frame
            textHighlightNode.updateRects(rects)
        }
        for i in (rectsSet.count ..< self.linkPreviewHighlightingNodes.count).reversed() {
            self.linkPreviewHighlightingNodes[i].removeFromSupernode()
            self.linkPreviewHighlightingNodes.remove(at: i)
        }
    }
    
    private func updateLinkProgressState() {
        guard let item = self.item else {
            return
        }
        
        let range: NSRange = self.linkProgressRange ?? NSRange(location: NSNotFound, length: 0)
        if range.location != NSNotFound {
            let linkProgressView: TextLoadingEffectView
            if let current = self.linkProgressView {
                linkProgressView = current
            } else {
                linkProgressView = TextLoadingEffectView(frame: CGRect())
                self.linkProgressView = linkProgressView
                self.containerNode.view.addSubview(linkProgressView)
            }
            linkProgressView.frame = self.textNode.textNode.frame
            
            let progressColor: UIColor = item.message.effectivelyIncoming(item.context.account.peerId) ? item.presentationData.theme.theme.chat.message.incoming.linkHighlightColor : item.presentationData.theme.theme.chat.message.outgoing.linkHighlightColor
            
            linkProgressView.update(color: progressColor, textNode: self.textNode.textNode, range: range)
        } else {
            if let linkProgressView = self.linkProgressView {
                self.linkProgressView = nil
                linkProgressView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak linkProgressView] _ in
                    linkProgressView?.removeFromSuperview()
                })
            }
        }
    }
    
    public func animateQuoteTextHighlightIn(sourceFrame: CGRect, transition: ContainedViewLayoutTransition) -> CGRect? {
        if let quoteHighlightingNode = self.quoteHighlightingNode {
            var currentRect = CGRect()
            for rect in quoteHighlightingNode.rects {
                if currentRect.isEmpty {
                    currentRect = rect
                } else {
                    currentRect = currentRect.union(rect)
                }
            }
            if !currentRect.isEmpty {
                currentRect = currentRect.insetBy(dx: -quoteHighlightingNode.inset, dy: -quoteHighlightingNode.inset)
                let innerRect = currentRect.offsetBy(dx: quoteHighlightingNode.frame.minX, dy: quoteHighlightingNode.frame.minY)
                
                quoteHighlightingNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, delay: 0.04)
                
                let fromScale = CGPoint(x: sourceFrame.width / innerRect.width, y: sourceFrame.height / innerRect.height)
                
                var fromTransform = CATransform3DIdentity
                let fromOffset = CGPoint(x: sourceFrame.midX - innerRect.midX, y: sourceFrame.midY - innerRect.midY)
                
                fromTransform = CATransform3DTranslate(fromTransform, fromOffset.x, fromOffset.y, 0.0)
                
                fromTransform = CATransform3DTranslate(fromTransform, -quoteHighlightingNode.bounds.width * 0.5 + currentRect.midX, -quoteHighlightingNode.bounds.height * 0.5 + currentRect.midY, 0.0)
                fromTransform = CATransform3DScale(fromTransform, fromScale.x, fromScale.y, 1.0)
                fromTransform = CATransform3DTranslate(fromTransform, quoteHighlightingNode.bounds.width * 0.5 - currentRect.midX, quoteHighlightingNode.bounds.height * 0.5 - currentRect.midY, 0.0)
                
                quoteHighlightingNode.transform = fromTransform
                transition.updateTransform(node: quoteHighlightingNode, transform: CGAffineTransformIdentity)
                
                return currentRect.offsetBy(dx: quoteHighlightingNode.frame.minX, dy: quoteHighlightingNode.frame.minY)
            }
        }
        return nil
    }
    
    public func getQuoteRect(quote: String, offset: Int?) -> CGRect? {
        var rectsSet: [CGRect] = []
        if !quote.isEmpty, let cachedLayout = self.textNode.textNode.cachedLayout, let string = cachedLayout.attributedString?.string {
            
            let range = findQuoteRange(string: string, quoteText: quote, offset: offset)
            if let range, let rects = cachedLayout.rangeRects(in: range)?.rects, !rects.isEmpty {
                rectsSet = rects
            }
        }
        if !rectsSet.isEmpty {
            var currentRect = CGRect()
            for rect in rectsSet {
                if currentRect.isEmpty {
                    currentRect = rect
                } else {
                    currentRect = currentRect.union(rect)
                }
            }
            
            return currentRect.offsetBy(dx: self.textNode.textNode.frame.minX, dy: self.textNode.textNode.frame.minY)
        }
        
        return nil
    }
    
    public func updateQuoteTextHighlightState(text: String?, offset: Int?, color: UIColor, animated: Bool) {
        var rectsSet: [CGRect] = []
        if let text = text, !text.isEmpty, let cachedLayout = self.textNode.textNode.cachedLayout, let string = cachedLayout.attributedString?.string {
            
            let quoteRange = findQuoteRange(string: string, quoteText: text, offset: offset)
            if let quoteRange, let rects = cachedLayout.rangeRects(in: quoteRange)?.rects, !rects.isEmpty {
                rectsSet = rects
            }
        }
        if !rectsSet.isEmpty {
            let rects = rectsSet
            let textHighlightNode: LinkHighlightingNode
            if let current = self.quoteHighlightingNode {
                textHighlightNode = current
            } else {
                textHighlightNode = LinkHighlightingNode(color: color)
                self.quoteHighlightingNode = textHighlightNode
                self.containerNode.insertSubnode(textHighlightNode, belowSubnode: self.textNode.textNode)
            }
            textHighlightNode.frame = self.textNode.textNode.frame
            textHighlightNode.updateRects(rects)
        } else {
            if let quoteHighlightingNode = self.quoteHighlightingNode {
                self.quoteHighlightingNode = nil
                if animated {
                    quoteHighlightingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak quoteHighlightingNode] _ in
                        quoteHighlightingNode?.removeFromSupernode()
                    })
                } else {
                    quoteHighlightingNode.removeFromSupernode()
                }
            }
        }
    }
    
    override public func willUpdateIsExtractedToContextPreview(_ value: Bool) {
        if !value {
            if let textSelectionNode = self.textSelectionNode {
                self.textSelectionNode = nil
                textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                    textSelectionNode?.highlightAreaNode.removeFromSupernode()
                    textSelectionNode?.removeFromSupernode()
                })
            }
        }
    }
    
    override public func updateIsExtractedToContextPreview(_ value: Bool) {
        if value {
            if self.textSelectionNode == nil, let item = self.item, let rootNode = item.controllerInteraction.chatControllerNode() {
                let selectionColor: UIColor
                let knobColor: UIColor
                if item.message.effectivelyIncoming(item.context.account.peerId) {
                    selectionColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionColor
                    knobColor = item.presentationData.theme.theme.chat.message.incoming.textSelectionKnobColor
                } else {
                    selectionColor = item.presentationData.theme.theme.chat.message.outgoing.textSelectionColor
                    knobColor = item.presentationData.theme.theme.chat.message.outgoing.textSelectionKnobColor
                }
                
                let textSelectionNode = TextSelectionNode(theme: TextSelectionTheme(selection: selectionColor, knob: knobColor, isDark: item.presentationData.theme.theme.overallDarkAppearance), strings: item.presentationData.strings, textNode: self.textNode.textNode, updateIsActive: { [weak self] value in
                    self?.updateIsTextSelectionActive?(value)
                }, present: { [weak self] c, a in
                    guard let self, let item = self.item else {
                        return
                    }
                    
                    if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .reply = info {
                        item.controllerInteraction.presentControllerInCurrent(c, a)
                    } else {
                        item.controllerInteraction.presentGlobalOverlayController(c, a)
                    }
                }, rootNode: { [weak rootNode] in
                    return rootNode
                }, performAction: { [weak self] text, action in
                    guard let strongSelf = self, let item = strongSelf.item else {
                        return
                    }
                    item.controllerInteraction.performTextSelectionAction(item.message, true, text, action)
                })
                textSelectionNode.updateRange = { [weak self] selectionRange in
                    guard let strongSelf = self else {
                        return
                    }
                    if !strongSelf.displayContentsUnderSpoilers.value, let textLayout = strongSelf.textNode.textNode.cachedLayout, textLayout.segments.contains(where: { !$0.spoilers.isEmpty }), let selectionRange {
                        for segment in textLayout.segments {
                            for (spoilerRange, _) in segment.spoilers {
                                if let intersection = selectionRange.intersection(spoilerRange), intersection.length > 0 {
                                    strongSelf.updateDisplayContentsUnderSpoilers(value: true, at: nil)
                                    return
                                }
                            }
                        }
                    }
                    if let textSelectionState = strongSelf.textSelectionState {
                        textSelectionState.set(.single(strongSelf.getSelectionState(range: selectionRange)))
                    }
                }
                
                let enableCopy = (!item.associatedData.isCopyProtectionEnabled && !item.message.isCopyProtected()) || item.message.id.peerId.isVerificationCodes
                textSelectionNode.enableCopy = enableCopy
                
                var enableQuote = !item.message.text.isEmpty
                var enableOtherActions = true
                if let subject = item.associatedData.subject, case let .messageOptions(_, _, info) = subject, case .reply = info {
                    enableOtherActions = false
                } else if item.controllerInteraction.canSetupReply(item.message) == .reply {
                    //enableOtherActions = false
                }
                
                if !item.controllerInteraction.canSendMessages() && !enableCopy {
                    enableQuote = false
                }
                if item.message.id.peerId.namespace == Namespaces.Peer.SecretChat || item.message.id.peerId.isVerificationCodes {
                    enableQuote = false
                }
                if item.message.containsSecretMedia {
                    enableQuote = false
                }
                if item.associatedData.translateToLanguage != nil {
                    enableQuote = false
                }
                
                textSelectionNode.enableQuote = enableQuote
                textSelectionNode.enableTranslate = enableOtherActions
                textSelectionNode.enableShare = enableOtherActions && enableCopy
                textSelectionNode.menuSkipCoordnateConversion = !enableOtherActions
                self.textSelectionNode = textSelectionNode
                self.containerNode.addSubnode(textSelectionNode)
                self.containerNode.insertSubnode(textSelectionNode.highlightAreaNode, belowSubnode: self.textNode.textNode)
                textSelectionNode.frame = self.textNode.textNode.frame
                textSelectionNode.highlightAreaNode.frame = self.textNode.textNode.frame
            }
        } else {
            if let textSelectionNode = self.textSelectionNode {
                self.textSelectionNode = nil
                self.updateIsTextSelectionActive?(false)
                textSelectionNode.highlightAreaNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
                textSelectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak textSelectionNode] _ in
                    textSelectionNode?.highlightAreaNode.removeFromSupernode()
                    textSelectionNode?.removeFromSupernode()
                })
            }
            
            if self.displayContentsUnderSpoilers.value {
                self.updateDisplayContentsUnderSpoilers(value: false, at: nil)
            }
        }
    }
    
    private func updateDisplayContentsUnderSpoilers(value: Bool, at location: CGPoint?) {
        if self.displayContentsUnderSpoilers.value == value {
            return
        }
        self.displayContentsUnderSpoilers = (value, location)
        if let item = self.item {
            item.controllerInteraction.requestMessageUpdate(item.message.id, false)
        }
    }
    
    override public func reactionTargetView(value: MessageReaction.Reaction) -> UIView? {
        if let statusNode = self.statusNode, !statusNode.isHidden {
            return statusNode.reactionView(value: value)
        }
        return nil
    }
    
    override public func messageEffectTargetView() -> UIView? {
        if let statusNode = self.statusNode, !statusNode.isHidden {
            return statusNode.messageEffectTargetView()
        }
        return nil
    }
    
    override public func getStatusNode() -> ASDisplayNode? {
        return self.statusNode
    }

    public func animateFrom(sourceView: UIView, scrollOffset: CGFloat, widthDifference: CGFloat, transition: CombinedTransition) {
        self.containerNode.view.addSubview(sourceView)

        sourceView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.1, removeOnCompletion: false, completion: { [weak sourceView] _ in
            sourceView?.removeFromSuperview()
        })
        self.textNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.08)

        let offset = CGPoint(
            x: sourceView.frame.minX - (self.textNode.textNode.frame.minX - 0.0),
            y: sourceView.frame.minY - (self.textNode.textNode.frame.minY - 3.0) - scrollOffset
        )

        transition.vertical.animatePositionAdditive(node: self.textNode.textNode, offset: offset)
        transition.updatePosition(layer: sourceView.layer, position: CGPoint(x: sourceView.layer.position.x - offset.x, y: sourceView.layer.position.y - offset.y))

        if let statusNode = self.statusNode {
            statusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
            transition.horizontal.animatePositionAdditive(node: statusNode, offset: CGPoint(x: -widthDifference, y: 0.0))
        }
    }
    
    public func beginTextSelection(range: NSRange?, displayMenu: Bool = true) {
        guard let textSelectionNode = self.textSelectionNode else {
            return
        }
        guard let string = self.textNode.textNode.cachedLayout?.attributedString else {
            return
        }
        let nsString = string.string as NSString
        let range = range ?? NSRange(location: 0, length: nsString.length)
        textSelectionNode.setSelection(range: range, displayMenu: displayMenu)
    }
    
    public func cancelTextSelection() {
        guard let textSelectionNode = self.textSelectionNode else {
            return
        }
        textSelectionNode.cancelSelection()
    }
    
    private func getSelectionState(range: NSRange?) -> ChatControllerSubject.MessageOptionsInfo.SelectionState {
        var quote: ChatControllerSubject.MessageOptionsInfo.Quote?
        if let item = self.item, let range, let selection = self.getCurrentTextSelection(customRange: range) {
            quote = ChatControllerSubject.MessageOptionsInfo.Quote(messageId: item.message.id, text: selection.text, offset: selection.offset)
        }
        return ChatControllerSubject.MessageOptionsInfo.SelectionState(canQuote: true, quote: quote)
    }
    
    public func getCurrentTextSelection(customRange: NSRange? = nil) -> (text: String, entities: [MessageTextEntity], offset: Int)? {
        guard let textSelectionNode = self.textSelectionNode else {
            return nil
        }
        guard let range = customRange ?? textSelectionNode.getSelection() else {
            return nil
        }
        guard let item = self.item else {
            return nil
        }
        guard let string = self.textNode.attributedString else {
            return nil
        }
        
        let nsString = string.string as NSString
        let substring = nsString.substring(with: range)
        let offset = range.location
        
        var entities: [MessageTextEntity] = []
        if let textEntitiesAttribute = item.message.textEntitiesAttribute {
            entities = messageTextEntitiesInRange(entities: textEntitiesAttribute.entities, range: range, onlyQuoteable: true)
        }
        
        return (substring, entities, offset)
    }
    
    public func animateClippingTransition(offset: CGFloat, animation: ListViewItemUpdateAnimation) {
        self.containerNode.clipsToBounds = true
        self.containerNode.bounds = CGRect(origin: CGPoint(x: 0.0, y: offset), size: self.containerNode.bounds.size)
        self.containerNode.alpha = 0.0
        animation.animator.updateAlpha(layer: self.containerNode.layer, alpha: 1.0, completion: nil)
        animation.animator.updateBounds(layer: self.containerNode.layer, bounds: CGRect(origin: CGPoint(), size: self.containerNode.bounds.size), completion: { [weak self] completed in
            guard let self, completed else {
                return
            }
            self.containerNode.clipsToBounds = false
        })
    }
}
