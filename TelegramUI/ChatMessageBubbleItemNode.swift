import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore

private func contentNodeMessagesAndClassesForItem(_ item: ChatMessageItem) -> [(Message, AnyClass)] {
    var result: [(Message, AnyClass)] = []
    var skipText = false
    var addFinalText = false
    
    for message in item.content {
        inner: for media in message.media {
            if let _ = media as? TelegramMediaImage {
                result.append((message, ChatMessageMediaBubbleContentNode.self))
            } else if let file = media as? TelegramMediaFile {
                if file.isVideo || (file.isAnimated && file.dimensions != nil) {
                    result.append((message, ChatMessageMediaBubbleContentNode.self))
                } else {
                    result.append((message, ChatMessageFileBubbleContentNode.self))
                }
            } else if let action = media as? TelegramMediaAction, case .phoneCall = action.action {
                result.append((message, ChatMessageCallBubbleContentNode.self))
            } else if let _ = media as? TelegramMediaMap {
                result.append((message, ChatMessageMapBubbleContentNode.self))
            } else if let _ = media as? TelegramMediaGame {
                skipText = true
                result.append((message, ChatMessageGameBubbleContentNode.self))
                break inner
            } else if let _ = media as? TelegramMediaInvoice {
                skipText = true
                result.append((message, ChatMessageInvoiceBubbleContentNode.self))
                break inner
            } else if let _ = media as? TelegramMediaContact {
                result.append((message, ChatMessageContactBubbleContentNode.self))
            }
        }
        
        if !message.text.isEmpty {
            if !skipText {
                if case .group = item.content {
                    addFinalText = true
                    skipText = true
                } else {
                    result.append((message, ChatMessageTextBubbleContentNode.self))
                }
            } else {
                if case .group = item.content {
                    addFinalText = false
                }
            }
        }
        
        inner: for media in message.media {
            if let webpage = media as? TelegramMediaWebpage {
                if case .Loaded = webpage.content {
                    result.append((message, ChatMessageWebpageBubbleContentNode.self))
                }
                break inner
            }
        }
    }
    
    if addFinalText && !item.content.firstMessage.text.isEmpty {
        result.append((item.content.firstMessage, ChatMessageTextBubbleContentNode.self))
    }
    
    if let additionalContent = item.additionalContent {
        switch additionalContent {
            case let .eventLogPreviousMessage(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousMessageContentNode.self))
            case let .eventLogPreviousDescription(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousDescriptionContentNode.self))
            case let .eventLogPreviousLink(previousMessage):
                result.append((previousMessage, ChatMessageEventLogPreviousLinkContentNode.self))
        }
    }
    
    return result
}

private let nameFont: UIFont = {
    if #available(iOS 8.2, *) {
        return UIFont.systemFont(ofSize: 14.0, weight: UIFont.Weight.medium)
    } else {
        return CTFontCreateWithName("HelveticaNeue-Medium" as CFString, 14.0, nil)
    }
}()

private let inlineBotPrefixFont = Font.regular(14.0)
private let inlineBotNameFont = nameFont

private let chatMessagePeerIdColors: [UIColor] = [
    UIColor(rgb: 0xfc5c51),
    UIColor(rgb: 0xfa790f),
    UIColor(rgb: 0x895dd5),
    UIColor(rgb: 0x0fb297),
    UIColor(rgb: 0x00c0c2),
    UIColor(rgb: 0x3ca5ec),
    UIColor(rgb: 0x3d72ed)
]

class ChatMessageBubbleItemNode: ChatMessageItemView {
    private let backgroundNode: ChatMessageBackground
    private var transitionClippingNode: ASDisplayNode?
    
    private var selectionNode: ChatMessageSelectionNode?
    private var swipeToReplyNode: ChatMessageSwipeToReplyNode?
    private var swipeToReplyFeedback: HapticFeedback?
    
    private var nameNode: TextNode?
    private var forwardInfoNode: ChatMessageForwardInfoNode?
    private var replyInfoNode: ChatMessageReplyInfoNode?
    
    private var contentNodes: [ChatMessageBubbleContentNode] = []
    private var mosaicStatusNode: ChatMessageDateAndStatusNode?
    private var actionButtonsNode: ChatMessageActionButtonsNode?
    
    private var shareButtonNode: HighlightableButtonNode?
    
    private var backgroundType: ChatMessageBackgroundType?
    private var highlightedState: Bool = false
    
    private var backgroundFrameTransition: (CGRect, CGRect)?
    
    private var currentSwipeToReplyTranslation: CGFloat = 0.0
    
    private var appliedItem: ChatMessageItem?
    
    override var visibility: ListViewItemNodeVisibility {
        didSet {
            if self.visibility != oldValue {
                for contentNode in self.contentNodes {
                    contentNode.visibility = self.visibility
                }
            }
        }
    }
    
    required init() {
        self.backgroundNode = ChatMessageBackground()
        
        super.init(layerBacked: false)
        
        self.addSubnode(self.backgroundNode)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        for node in self.subnodes {
            if node !== self.accessoryItemNode {
                node.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.backgroundNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        self.nameNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.forwardInfoNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.replyInfoNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        for contentNode in self.contentNodes {
            contentNode.animateAdded(currentTimestamp, duration: duration)
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { [weak self] point in
            if let strongSelf = self {
                if let shareButtonNode = strongSelf.shareButtonNode, shareButtonNode.frame.contains(point) {
                    return .fail
                }
                
                if let avatarNode = strongSelf.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                
                if let nameNode = strongSelf.nameNode, nameNode.frame.contains(point) {
                    if let item = strongSelf.item {
                        for attribute in item.message.attributes {
                            if let _ = attribute as? InlineBotMessageAttribute {
                                return .waitForSingleTap
                            }
                        }
                    }
                }
                if let replyInfoNode = strongSelf.replyInfoNode, replyInfoNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                if let forwardInfoNode = strongSelf.forwardInfoNode, forwardInfoNode.frame.contains(point) {
                    return .waitForSingleTap
                }
                for contentNode in strongSelf.contentNodes {
                    let tapAction = contentNode.tapActionAtPoint(CGPoint(x: point.x - contentNode.frame.minX, y: point.y - contentNode.frame.minY))
                    switch tapAction {
                        case .none:
                            break
                        case .ignore:
                            return .fail
                        case .url, .peerMention, .textMention, .botCommand, .hashtag, .instantPage, .call:
                            return .waitForSingleTap
                        case .holdToPreviewSecretMedia:
                            return .waitForHold(timeout: 0.12, acceptTap: false)
                    }
                }
                if !strongSelf.backgroundNode.frame.contains(point) {
                    return .waitForSingleTap
                }
            }
            
            return .waitForDoubleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                for contentNode in strongSelf.contentNodes {
                    var translatedPoint: CGPoint?
                    if let point = point, contentNode.frame.insetBy(dx: -4.0, dy: -4.0).contains(point) {
                        translatedPoint = CGPoint(x: point.x - contentNode.frame.minX, y: point.y - contentNode.frame.minY)
                    }
                    contentNode.updateTouchesAtPoint(translatedPoint)
                }
            }
        }
        self.view.addGestureRecognizer(recognizer)
        
        let replyRecognizer = ChatSwipeToReplyRecognizer(target: self, action: #selector(self.swipeToReplyGesture(_:)))
        replyRecognizer.shouldBegin = { [weak self] in
            if let strongSelf = self, let item = strongSelf.item {
                if strongSelf.selectionNode != nil {
                    return false
                }
                return item.controllerInteraction.canSetupReply(item.message)
            }
            return false
        }
        self.view.addGestureRecognizer(replyRecognizer)
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        var currentContentClassesPropertiesAndLayouts: [(Message, AnyClass, Bool, (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))))] = []
        for contentNode in self.contentNodes {
            if let message = contentNode.item?.message {
                currentContentClassesPropertiesAndLayouts.append((message, type(of: contentNode) as AnyClass, contentNode.supportsMosaic, contentNode.asyncLayoutContent()))
            }
        }
        
        let authorNameLayout = TextNode.asyncLayout(self.nameNode)
        let forwardInfoLayout = ChatMessageForwardInfoNode.asyncLayout(self.forwardInfoNode)
        let replyInfoLayout = ChatMessageReplyInfoNode.asyncLayout(self.replyInfoNode)
        let actionButtonsLayout = ChatMessageActionButtonsNode.asyncLayout(self.actionButtonsNode)
        
        let mosaicStatusLayout = ChatMessageDateAndStatusNode.asyncLayout(self.mosaicStatusNode)
        
        let currentShareButtonNode = self.shareButtonNode
        
        let layoutConstants = self.layoutConstants
        
        let currentItem = self.appliedItem
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            let baseWidth = params.width - params.leftInset - params.rightInset
            
            let content = item.content
            let firstMessage = content.firstMessage
            let incoming = item.content.effectivelyIncoming(item.account.peerId)
            
            var effectiveAuthor: Peer?
            var ignoreForward = false
            let displayAuthorInfo: Bool
            
            let avatarInset: CGFloat
            var hasAvatar = false
            
            var allowFullWidth = false
            switch item.chatLocation {
                case let .peer(peerId):
                    if item.message.id.peerId == item.account.peerId {
                        if let forwardInfo = item.content.firstMessage.forwardInfo {
                            ignoreForward = true
                            effectiveAuthor = forwardInfo.author
                        }
                        displayAuthorInfo = !mergedTop.merged && incoming && effectiveAuthor != nil
                    } else {
                        effectiveAuthor = firstMessage.author
                        displayAuthorInfo = !mergedTop.merged && incoming && peerId.isGroupOrChannel &&  effectiveAuthor != nil
                    }
                
                    if peerId != item.account.peerId {
                        if peerId.isGroupOrChannel && effectiveAuthor != nil {
                            var isBroadcastChannel = false
                            if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                                isBroadcastChannel = true
                                allowFullWidth = true
                            }
                            
                            if !isBroadcastChannel {
                                hasAvatar = true
                            }
                        }
                    } else if incoming {
                        hasAvatar = true
                    }
                case .group:
                    allowFullWidth = true
                    hasAvatar = true
                    displayAuthorInfo = true
            }
            
            if let forwardInfo = item.content.firstMessage.forwardInfo, forwardInfo.source == nil, forwardInfo.author.id.namespace == Namespaces.Peer.CloudUser {
                for media in item.content.firstMessage.media {
                    if let file = media as? TelegramMediaFile, file.isMusic {
                        ignoreForward = true
                        break
                    }
                }
            }
            
            if hasAvatar {
                avatarInset = layoutConstants.avatarDiameter
            } else {
                avatarInset = 0.0
            }
            
            var needShareButton = false
            if item.message.id.peerId == item.account.peerId {
                for attribute in item.content.firstMessage.attributes {
                    if let _ = attribute as? SourceReferenceMessageAttribute {
                        needShareButton = true
                        break
                    }
                }
            } else if item.message.effectivelyIncoming(item.account.peerId) {
                if let peer = item.message.peers[item.message.id.peerId] {
                    if let channel = peer as? TelegramChannel {
                        if case .broadcast = channel.info {
                            needShareButton = true
                        }
                    }
                }
                if !needShareButton, let author = item.message.author as? TelegramUser, let _ = author.botInfo {
                    needShareButton = true
                }
                if !needShareButton {
                    loop: for media in item.message.media {
                        if media is TelegramMediaGame || media is TelegramMediaInvoice {
                            needShareButton = true
                            break loop
                        } else if let media = media as? TelegramMediaWebpage, case .Loaded = media.content {
                            needShareButton = true
                            break loop
                        }
                    }
                }
            }
            
            var tmpWidth: CGFloat
            if allowFullWidth {
                tmpWidth = baseWidth
                if needShareButton {
                    tmpWidth -= 38.0
                }
            } else {
                tmpWidth = layoutConstants.bubble.maximumWidthFill.widthFor(baseWidth)
                if needShareButton && tmpWidth + 32.0 > baseWidth {
                    tmpWidth = baseWidth - 32.0
                }
            }
            let maximumContentWidth = floor(tmpWidth - layoutConstants.bubble.edgeInset - layoutConstants.bubble.edgeInset - layoutConstants.bubble.contentInsets.left - layoutConstants.bubble.contentInsets.right - avatarInset)
            
            var contentPropertiesAndPrepareLayouts: [(Message, Bool, (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, CGSize?, CGFloat, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))))] = []
            var addedContentNodes: [ChatMessageBubbleContentNode]?
            
            let contentNodeMessagesAndClasses = contentNodeMessagesAndClassesForItem(item)
            for (contentNodeMessage, contentNodeClass) in contentNodeMessagesAndClasses {
                var found = false
                for (currentMessage, currentClass, supportsMosaic, currentLayout) in currentContentClassesPropertiesAndLayouts {
                    if currentClass == contentNodeClass && currentMessage.stableId == contentNodeMessage.stableId {
                        contentPropertiesAndPrepareLayouts.append((contentNodeMessage, supportsMosaic, currentLayout))
                        found = true
                        break
                    }
                }
                if !found {
                    let contentNode = (contentNodeClass as! ChatMessageBubbleContentNode.Type).init()
                    contentPropertiesAndPrepareLayouts.append((contentNodeMessage, contentNode.supportsMosaic, contentNode.asyncLayoutContent()))
                    if addedContentNodes == nil {
                        addedContentNodes = [contentNode]
                    } else {
                        addedContentNodes!.append(contentNode)
                    }
                }
            }
            
            var authorNameString: String?
            var inlineBotNameString: String?
            var replyMessage: Message?
            var replyMarkup: ReplyMarkupMessageAttribute?
            var authorNameColor: UIColor?
            
            for attribute in firstMessage.attributes {
                if let attribute = attribute as? InlineBotMessageAttribute {
                    if let peerId = attribute.peerId, let bot = firstMessage.peers[peerId] as? TelegramUser {
                        inlineBotNameString = bot.username
                    } else {
                        inlineBotNameString = attribute.title
                    }
                } else if let attribute = attribute as? ReplyMessageAttribute {
                    replyMessage = firstMessage.associatedMessages[attribute.messageId]
                } else if let attribute = attribute as? ReplyMarkupMessageAttribute, attribute.flags.contains(.inline), !attribute.rows.isEmpty {
                    replyMarkup = attribute
                }
            }
            
            var contentPropertiesAndLayouts: [(CGSize?, ChatMessageBubbleContentProperties, ChatMessageBubblePreparePosition, (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void)))] = []
            
            let topNodeMergeStatus: ChatMessageBubbleMergeStatus = mergedTop.merged ? (incoming ? .Left : .Right) : .None(incoming ? .Incoming : .Outgoing)
            let bottomNodeMergeStatus: ChatMessageBubbleMergeStatus = mergedBottom.merged ? (incoming ? .Left : .Right) : .None(incoming ? .Incoming : .Outgoing)
            
            var canPossiblyHideBackground = false
            if case .color = item.presentationData.wallpaper {
                canPossiblyHideBackground = true
            }
            
            var maximumNodeWidth = maximumContentWidth
            
            let contentNodeCount = contentPropertiesAndPrepareLayouts.count
            
            let read: Bool
            switch item.content {
                case let .message(_, value, _):
                    read = value
                case let .group(messages):
                    read = messages[0].1
            }
            
            var mosaicStartIndex: Int?
            var mosaicRange: Range<Int>?
            for i in 0 ..< contentPropertiesAndPrepareLayouts.count {
                if contentPropertiesAndPrepareLayouts[i].1 {
                    if mosaicStartIndex == nil {
                        mosaicStartIndex = i
                    }
                } else if let mosaicStartIndexValue = mosaicStartIndex {
                    if mosaicStartIndexValue < i - 1 {
                        mosaicRange = mosaicStartIndexValue ..< i
                    }
                    mosaicStartIndex = nil
                }
            }
            if let mosaicStartIndex = mosaicStartIndex {
                if mosaicStartIndex < contentPropertiesAndPrepareLayouts.count - 1 {
                    mosaicRange = mosaicStartIndex ..< contentPropertiesAndPrepareLayouts.count
                }
            }
            
            var index = 0
            for (message, _, prepareLayout) in contentPropertiesAndPrepareLayouts {
                let topPosition: ChatMessageBubbleRelativePosition
                let bottomPosition: ChatMessageBubbleRelativePosition
                
                topPosition = .Neighbour
                bottomPosition = .Neighbour
                
                let prepareContentPosition: ChatMessageBubblePreparePosition
                if let mosaicRange = mosaicRange, mosaicRange.contains(index) {
                    prepareContentPosition = .mosaic(top: .None(.None(.Incoming)), bottom: index == (mosaicRange.upperBound - 1) ? bottomPosition : .None(.None(.Incoming)))
                } else {
                    let refinedBottomPosition: ChatMessageBubbleRelativePosition
                    if index == contentPropertiesAndPrepareLayouts.count - 1 {
                        refinedBottomPosition = .None(.Left)
                    } else {
                        refinedBottomPosition = bottomPosition
                    }
                    prepareContentPosition = .linear(top: topPosition, bottom: refinedBottomPosition)
                }
                
                let contentItem = ChatMessageBubbleContentItem(account: item.account, controllerInteraction: item.controllerInteraction, message: message, read: read, presentationData: item.presentationData)
                
                var itemSelection: Bool?
                if case .mosaic = prepareContentPosition {
                    switch content {
                        case .message:
                            break
                        case let .group(messages):
                            for (m, _, selection) in messages {
                                if m.id == message.id {
                                    switch selection {
                                        case .none:
                                            break
                                        case let .selectable(selected):
                                            itemSelection = selected
                                    }
                                    break
                                }
                            }
                    }
                }
                
                let (properties, unboundSize, maxNodeWidth, nodeLayout) = prepareLayout(contentItem, layoutConstants, prepareContentPosition, itemSelection, CGSize(width: maximumContentWidth, height: CGFloat.greatestFiniteMagnitude))
                maximumNodeWidth = min(maximumNodeWidth, maxNodeWidth)
                
                contentPropertiesAndLayouts.append((unboundSize, properties, prepareContentPosition, nodeLayout))
                
                if !properties.hidesBackgroundForEmptyWallpapers {
                    canPossiblyHideBackground = false
                }
                
                index += 1
            }
            
            var initialDisplayHeader = true
            if inlineBotNameString == nil && (ignoreForward || firstMessage.forwardInfo == nil) && replyMessage == nil {
                if let first = contentPropertiesAndLayouts.first, first.1.hidesSimpleAuthorHeader {
                    initialDisplayHeader = false
                }
            }
            
            if initialDisplayHeader && displayAuthorInfo {
                if let peer = firstMessage.peers[firstMessage.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                    authorNameString = peer.displayTitle
                    authorNameColor = chatMessagePeerIdColors[Int(peer.id.id % 7)]
                } else if let effectiveAuthor = effectiveAuthor {
                    authorNameString = effectiveAuthor.displayTitle
                    authorNameColor = chatMessagePeerIdColors[Int(effectiveAuthor.id.id % 7)]
                }
                if let rawAuthorNameColor = authorNameColor {
                    var dimColors = false
                    switch item.presentationData.theme.name {
                        case .builtin(.nightAccent), .builtin(.nightGrayscale):
                            dimColors = true
                        default:
                            break
                    }
                    if dimColors {
                        var hue: CGFloat = 0.0
                        var saturation: CGFloat = 0.0
                        var brightness: CGFloat = 0.0
                        rawAuthorNameColor.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)
                        authorNameColor = UIColor(hue: hue, saturation: saturation * 0.7, brightness: min(1.0, brightness * 1.2), alpha: 1.0)
                    }
                }
            }
            
            var displayHeader = false
            if initialDisplayHeader {
                if authorNameString != nil {
                    displayHeader = true
                }
                if inlineBotNameString != nil {
                    displayHeader = true
                }
                if firstMessage.forwardInfo != nil {
                    displayHeader = true
                }
                if replyMessage != nil {
                    displayHeader = true
                }
            }
            
            let firstNodeTopPosition: ChatMessageBubbleRelativePosition
            if displayHeader {
                firstNodeTopPosition = .Neighbour
            } else {
                firstNodeTopPosition = .None(topNodeMergeStatus)
            }
            let lastNodeTopPosition: ChatMessageBubbleRelativePosition = .None(bottomNodeMergeStatus)
            
            var calculatedGroupFramesAndSize: ([(CGRect, MosaicItemPosition)], CGSize)?
            var mosaicStatusSizeAndApply: (CGSize, (Bool) -> ChatMessageDateAndStatusNode)?
            
            if let mosaicRange = mosaicRange {
                let maxSize = layoutConstants.image.maxDimensions.fittedToWidthOrSmaller(maximumContentWidth - layoutConstants.image.bubbleInsets.left - layoutConstants.image.bubbleInsets.right)
                let (innerFramesAndPositions, innerSize) = chatMessageBubbleMosaicLayout(maxSize: maxSize, itemSizes: contentPropertiesAndLayouts[mosaicRange].map { $0.0 ?? CGSize(width: 256.0, height: 256.0) })
                
                let framesAndPositions = innerFramesAndPositions.map { ($0.0.offsetBy(dx: layoutConstants.image.bubbleInsets.left, dy: layoutConstants.image.bubbleInsets.top), $0.1) }
                
                let size = CGSize(width: innerSize.width + layoutConstants.image.bubbleInsets.left + layoutConstants.image.bubbleInsets.right, height: innerSize.height + layoutConstants.image.bubbleInsets.top + layoutConstants.image.bubbleInsets.bottom)
                
                calculatedGroupFramesAndSize = (framesAndPositions, size)
                
                maximumNodeWidth = size.width
                
                if mosaicRange.upperBound == contentPropertiesAndLayouts.count {
                    let message = item.content.firstMessage
                    
                    var edited = false
                    var sentViaBot = false
                    var viewCount: Int?
                    for attribute in message.attributes {
                        if let _ = attribute as? EditedMessageAttribute {
                            edited = true
                        } else if let attribute = attribute as? ViewCountMessageAttribute {
                            viewCount = attribute.count
                        } else if let _ = attribute as? InlineBotMessageAttribute {
                            sentViaBot = true
                        }
                    }
                    if let author = message.author as? TelegramUser, author.botInfo != nil {
                        sentViaBot = true
                    }
                    
                    let dateText = stringForMessageTimestampStatus(message: message, timeFormat: item.presentationData.timeFormat, strings: item.presentationData.strings)
                    
                    let statusType: ChatMessageDateAndStatusType
                    if message.effectivelyIncoming(item.account.peerId) {
                        statusType = .ImageIncoming
                    } else {
                        if message.flags.contains(.Failed) {
                            statusType = .ImageOutgoing(.Failed)
                        } else if message.flags.isSending {
                            statusType = .ImageOutgoing(.Sending)
                        } else {
                            statusType = .ImageOutgoing(.Sent(read: item.read))
                        }
                    }
                    
                    mosaicStatusSizeAndApply = mosaicStatusLayout(item.presentationData.theme, item.presentationData.strings, edited && !sentViaBot, viewCount, dateText, statusType, CGSize(width: 200.0, height: CGFloat.greatestFiniteMagnitude))
                }
            }
            
            var headerSize = CGSize()
            
            var nameNodeOriginY: CGFloat = 0.0
            var nameNodeSizeApply: (CGSize, () -> TextNode?) = (CGSize(), { nil })
            
            var replyInfoOriginY: CGFloat = 0.0
            var replyInfoSizeApply: (CGSize, () -> ChatMessageReplyInfoNode?) = (CGSize(), { nil })
            
            var forwardInfoOriginY: CGFloat = 0.0
            var forwardInfoSizeApply: (CGSize, () -> ChatMessageForwardInfoNode?) = (CGSize(), { nil })
            
            if displayHeader {
                if authorNameString != nil || inlineBotNameString != nil {
                    if headerSize.height.isZero {
                        headerSize.height += 5.0
                    }
                    
                    let inlineBotNameColor = incoming ? item.presentationData.theme.chat.bubble.incomingAccentTextColor : item.presentationData.theme.chat.bubble.outgoingAccentTextColor
                    
                    let attributedString: NSAttributedString
                    if let authorNameString = authorNameString, let authorNameColor = authorNameColor, let inlineBotNameString = inlineBotNameString {
                        
                        let mutableString = NSMutableAttributedString(string: "\(authorNameString) ", attributes: [NSAttributedStringKey.font: nameFont, NSAttributedStringKey.foregroundColor: authorNameColor])
                        let bodyAttributes = MarkdownAttributeSet(font: nameFont, textColor: inlineBotNameColor)
                        let boldAttributes = MarkdownAttributeSet(font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                        let botString = addAttributesToStringWithRanges(item.presentationData.strings.Conversation_MessageViaUser("@\(inlineBotNameString)"), body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                        mutableString.append(botString)
                        attributedString = mutableString
                    } else if let authorNameString = authorNameString, let authorNameColor = authorNameColor {
                        attributedString = NSAttributedString(string: authorNameString, font: nameFont, textColor: authorNameColor)
                    } else if let inlineBotNameString = inlineBotNameString {
                        let bodyAttributes = MarkdownAttributeSet(font: inlineBotPrefixFont, textColor: inlineBotNameColor)
                        let boldAttributes = MarkdownAttributeSet(font: nameFont, textColor: inlineBotNameColor)
                        attributedString = addAttributesToStringWithRanges(item.presentationData.strings.Conversation_MessageViaUser("@\(inlineBotNameString)"), body: bodyAttributes, argumentAttributes: [0: boldAttributes])
                    } else {
                        attributedString = NSAttributedString(string: "", font: nameFont, textColor: inlineBotNameColor)
                    }
                    
                    let sizeAndApply = authorNameLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude), alignment: .natural, cutout: nil, insets: UIEdgeInsets()))
                    nameNodeSizeApply = (sizeAndApply.0.size, {
                        return sizeAndApply.1()
                    })
                    nameNodeOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, nameNodeSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += nameNodeSizeApply.0.height
                }
                
                if !ignoreForward, let forwardInfo = firstMessage.forwardInfo {
                    if headerSize.height.isZero {
                        headerSize.height += 5.0
                    }
                    let forwardSource: Peer
                    let forwardAuthorSignature: String?
                    
                    if let source = forwardInfo.source {
                        forwardSource = source
                        if let authorSignature = forwardInfo.authorSignature {
                            forwardAuthorSignature = authorSignature
                        } else if forwardInfo.author.id != source.id {
                            forwardAuthorSignature = forwardInfo.author.displayTitle
                        } else {
                            forwardAuthorSignature = nil
                        }
                    } else {
                        forwardSource = forwardInfo.author
                        forwardAuthorSignature = nil
                    }
                    let sizeAndApply = forwardInfoLayout(item.presentationData.theme, item.presentationData.strings, .bubble(incoming: incoming), forwardSource, forwardAuthorSignature, CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude))
                    forwardInfoSizeApply = (sizeAndApply.0, { sizeAndApply.1() })
                    
                    forwardInfoOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, forwardInfoSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += forwardInfoSizeApply.0.height
                }
                
                if let replyMessage = replyMessage {
                    if headerSize.height.isZero {
                        headerSize.height += 6.0
                    } else {
                        headerSize.height += 2.0
                    }
                    let sizeAndApply = replyInfoLayout(item.presentationData.theme, item.presentationData.strings, item.account, .bubble(incoming: incoming), replyMessage, CGSize(width: maximumNodeWidth - layoutConstants.text.bubbleInsets.left - layoutConstants.text.bubbleInsets.right, height: CGFloat.greatestFiniteMagnitude))
                    replyInfoSizeApply = (sizeAndApply.0, { sizeAndApply.1() })
                    
                    replyInfoOriginY = headerSize.height
                    headerSize.width = max(headerSize.width, replyInfoSizeApply.0.width + layoutConstants.text.bubbleInsets.left + layoutConstants.text.bubbleInsets.right)
                    headerSize.height += replyInfoSizeApply.0.height + 2.0
                }
                
                if !headerSize.height.isZero {
                    headerSize.height -= 5.0
                }
            }
            
            let hideBackground = canPossiblyHideBackground && !displayHeader
            
            var removedContentNodeIndices: [Int]?
            findRemoved: for i in 0 ..< currentContentClassesPropertiesAndLayouts.count {
                let currentMessage = currentContentClassesPropertiesAndLayouts[i].0
                let currentClass: AnyClass = currentContentClassesPropertiesAndLayouts[i].1
                for (contentNodeMessage, contentNodeClass) in contentNodeMessagesAndClasses {
                    if currentClass == contentNodeClass && currentMessage.stableId == contentNodeMessage.stableId {
                        continue findRemoved
                    }
                }
                if removedContentNodeIndices == nil {
                    removedContentNodeIndices = [i]
                } else {
                    removedContentNodeIndices!.append(i)
                }
            }
            
            var contentNodePropertiesAndFinalize: [(ChatMessageBubbleContentProperties, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))] = []
            
            var maxContentWidth: CGFloat = headerSize.width
            
            var actionButtonsFinalize: ((CGFloat) -> (CGSize, (_ animated: Bool) -> ChatMessageActionButtonsNode))?
            if let replyMarkup = replyMarkup {
                let (minWidth, buttonsLayout) = actionButtonsLayout(item.account, item.presentationData.theme, item.presentationData.strings, replyMarkup, item.message, maximumNodeWidth)
                maxContentWidth = max(maxContentWidth, minWidth)
                actionButtonsFinalize = buttonsLayout
            }
            
            for i in 0 ..< contentPropertiesAndLayouts.count {
                let (_, contentNodeProperties, preparePosition, contentNodeLayout) = contentPropertiesAndLayouts[i]
                
                if let mosaicRange = mosaicRange, mosaicRange.contains(i), let (framesAndPositions, size) = calculatedGroupFramesAndSize {
                    let mosaicIndex = i - mosaicRange.lowerBound
                    
                    let position = framesAndPositions[mosaicIndex].1
                    
                    let topLeft: ChatMessageBubbleContentMosaicNeighbor
                    let topRight: ChatMessageBubbleContentMosaicNeighbor
                    let bottomLeft: ChatMessageBubbleContentMosaicNeighbor
                    let bottomRight: ChatMessageBubbleContentMosaicNeighbor
                    
                    switch firstNodeTopPosition {
                        case .Neighbour:
                            topLeft = .merged
                            topRight = .merged
                        case let .None(status):
                            if position.contains(.top) && position.contains(.left) {
                                switch status {
                                case .Left:
                                    topLeft = .merged
                                case .Right:
                                    topLeft = .none(tail: false)
                                case .None:
                                    topLeft = .none(tail: false)
                                }
                            } else {
                                topLeft = .merged
                            }
                            
                            if position.contains(.top) && position.contains(.right) {
                                switch status {
                                case .Left:
                                    topRight = .none(tail: false)
                                case .Right:
                                    topRight = .merged
                                case .None:
                                    topRight = .none(tail: false)
                                }
                            } else {
                                topRight = .merged
                            }
                    }
                    
                    let lastMosaicBottomPosition: ChatMessageBubbleRelativePosition
                    if mosaicRange.upperBound - 1 == contentNodeCount - 1 {
                        lastMosaicBottomPosition = lastNodeTopPosition
                    } else {
                        lastMosaicBottomPosition = .Neighbour
                    }
                    
                    if position.contains(.bottom), case .Neighbour = lastMosaicBottomPosition {
                        bottomLeft = .merged
                        bottomRight = .merged
                    } else {
                        switch lastNodeTopPosition {
                            case .Neighbour:
                                bottomLeft = .merged
                                bottomRight = .merged
                            case let .None(status):
                                if position.contains(.bottom) && position.contains(.left) {
                                    switch status {
                                    case .Left:
                                        bottomLeft = .merged
                                    case .Right:
                                        bottomLeft = .none(tail: false)
                                    case let .None(tailStatus):
                                        if case .Incoming = tailStatus {
                                            bottomLeft = .none(tail: true)
                                        } else {
                                            bottomLeft = .none(tail: false)
                                        }
                                    }
                                } else {
                                    bottomLeft = .merged
                                }
                                
                                if position.contains(.bottom) && position.contains(.right) {
                                    switch status {
                                    case .Left:
                                        bottomRight = .none(tail: false)
                                    case .Right:
                                        bottomRight = .merged
                                    case let .None(tailStatus):
                                        if case .Outgoing = tailStatus {
                                            bottomRight = .none(tail: true)
                                        } else {
                                            bottomRight = .none(tail: false)
                                        }
                                    }
                                } else {
                                    bottomRight = .merged
                                }
                        }
                    }
                    
                    let (_, contentNodeFinalize) = contentNodeLayout(framesAndPositions[mosaicIndex].0.size, .mosaic(position: ChatMessageBubbleContentMosaicPosition(topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)))
                    
                    contentNodePropertiesAndFinalize.append((contentNodeProperties, contentNodeFinalize))
                    
                    maxContentWidth = max(maxContentWidth, size.width)
                } else {
                    let contentPosition: ChatMessageBubbleContentPosition
                    switch preparePosition {
                        case .linear:
                            let topPosition: ChatMessageBubbleRelativePosition
                            let bottomPosition: ChatMessageBubbleRelativePosition

                            if i == 0 {
                                topPosition = firstNodeTopPosition
                            } else {
                                topPosition = .Neighbour
                            }
                            
                            if i == contentNodeCount - 1 {
                                bottomPosition = lastNodeTopPosition
                            } else {
                                bottomPosition = .Neighbour
                            }
                        
                            contentPosition = .linear(top: topPosition, bottom: bottomPosition)
                        case .mosaic:
                            assertionFailure()
                            contentPosition = .linear(top: .Neighbour, bottom: .Neighbour)
                    }
                    let (contentNodeWidth, contentNodeFinalize) = contentNodeLayout(CGSize(width: maximumNodeWidth, height: CGFloat.greatestFiniteMagnitude), contentPosition)
                    #if DEBUG
                    if contentNodeWidth > maximumNodeWidth {
                        print("\(contentNodeWidth) > \(maximumNodeWidth)")
                    }
                    #endif
                    maxContentWidth = max(maxContentWidth, contentNodeWidth)
                    
                    contentNodePropertiesAndFinalize.append((contentNodeProperties, contentNodeFinalize))
                }
            }
            
            var contentSize = CGSize(width: maxContentWidth, height: 0.0)
            var contentNodeFramesPropertiesAndApply: [(CGRect, ChatMessageBubbleContentProperties, (ListViewItemUpdateAnimation) -> Void)] = []
            var contentNodesHeight: CGFloat = 0.0
            var mosaicStatusOrigin: CGPoint?
            for i in 0 ..< contentNodePropertiesAndFinalize.count {
                let (properties, finalize) = contentNodePropertiesAndFinalize[i]
                
                if let mosaicRange = mosaicRange, mosaicRange.contains(i), let (framesAndPositions, size) = calculatedGroupFramesAndSize {
                    let mosaicIndex = i - mosaicRange.lowerBound
                    
                    if mosaicIndex == 0 {
                        if !headerSize.height.isZero {
                            contentNodesHeight += 7.0
                        }
                    }
                    
                    let (_, apply) = finalize(maxContentWidth)
                    let contentNodeFrame = framesAndPositions[mosaicIndex].0.offsetBy(dx: 0.0, dy: contentNodesHeight)
                    contentNodeFramesPropertiesAndApply.append((contentNodeFrame, properties, apply))
                    
                    if mosaicIndex == mosaicRange.upperBound - 1 {
                        contentNodesHeight += size.height
                        
                        mosaicStatusOrigin = contentNodeFrame.bottomRight
                    }
                } else {
                    if i == 0 && !headerSize.height.isZero {
                        contentNodesHeight += properties.headerSpacing
                    }
                    
                    let (size, apply) = finalize(maxContentWidth)
                    contentNodeFramesPropertiesAndApply.append((CGRect(origin: CGPoint(x: 0.0, y: contentNodesHeight), size: size), properties, apply))
                    
                    contentNodesHeight += size.height
                }
            }
            contentSize.height += contentNodesHeight
            
            var actionButtonsSizeAndApply: (CGSize, (Bool) -> ChatMessageActionButtonsNode)?
            if let actionButtonsFinalize = actionButtonsFinalize {
                actionButtonsSizeAndApply = actionButtonsFinalize(maxContentWidth)
            }
            
            let layoutBubbleSize = CGSize(width: max(contentSize.width, headerSize.width) + layoutConstants.bubble.contentInsets.left + layoutConstants.bubble.contentInsets.right, height: max(layoutConstants.bubble.minimumSize.height, headerSize.height + contentSize.height + layoutConstants.bubble.contentInsets.top + layoutConstants.bubble.contentInsets.bottom))
            
            let backgroundFrame = CGRect(origin: CGPoint(x: incoming ? (params.leftInset + layoutConstants.bubble.edgeInset + avatarInset) : (params.width - params.rightInset - layoutBubbleSize.width - layoutConstants.bubble.edgeInset), y: 0.0), size: layoutBubbleSize)
            
            let contentOrigin = CGPoint(x: backgroundFrame.origin.x + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.origin.y + layoutConstants.bubble.contentInsets.top + headerSize.height)

            var layoutSize = CGSize(width: params.width, height: layoutBubbleSize.height)
            if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                layoutSize.height += actionButtonsSizeAndApply.0.height
            }
            
            var layoutInsets = UIEdgeInsets(top: mergedTop.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, left: 0.0, bottom: mergedBottom.merged ? layoutConstants.bubble.mergedSpacing : layoutConstants.bubble.defaultSpacing, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            var updatedShareButtonBackground: UIImage?
            
            var updatedShareButtonNode: HighlightableButtonNode?
            if needShareButton {
                if currentShareButtonNode != nil {
                    updatedShareButtonNode = currentShareButtonNode
                    if item.presentationData.theme !== currentItem?.presentationData.theme {
                        if item.message.id.peerId == item.account.peerId {
                            updatedShareButtonBackground = PresentationResourcesChat.chatBubbleNavigateButtonImage(item.presentationData.theme)
                        } else {
                            updatedShareButtonBackground = PresentationResourcesChat.chatBubbleShareButtonImage(item.presentationData.theme)
                        }
                    }
                } else {
                    let buttonNode = HighlightableButtonNode()
                    let buttonIcon: UIImage?
                    if item.message.id.peerId == item.account.peerId {
                        buttonIcon = PresentationResourcesChat.chatBubbleNavigateButtonImage(item.presentationData.theme)
                    } else {
                        buttonIcon = PresentationResourcesChat.chatBubbleShareButtonImage(item.presentationData.theme)
                    }
                    buttonNode.setBackgroundImage(buttonIcon, for: [.normal])
                    updatedShareButtonNode = buttonNode
                }
            }
            
            let layout = ListViewItemNodeLayout(contentSize: layoutSize, insets: layoutInsets)
            
            let graphics = PresentationResourcesChat.principalGraphics(item.presentationData.theme)
            
            var updatedMergedTop = mergedBottom
            var updatedMergedBottom = mergedTop
            if mosaicRange == nil {
                if contentNodePropertiesAndFinalize.first?.0.forceFullCorners ?? false {
                    updatedMergedTop = .semanticallyMerged
                }
                if headerSize.height.isZero && contentNodePropertiesAndFinalize.first?.0.forceFullCorners ?? false {
                    updatedMergedBottom = .none
                }
            }
            
            return (layout, { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.appliedItem = item
                    
                    var transition: ContainedViewLayoutTransition = .immediate
                    if case let .System(duration) = animation {
                        transition = .animated(duration: duration, curve: .spring)
                    }
                    
                    var forceBackgroundSide = false
                    if actionButtonsSizeAndApply != nil {
                        forceBackgroundSide = true
                    } else if case .semanticallyMerged = updatedMergedTop {
                        forceBackgroundSide = true
                    }
                    let mergeType = ChatMessageBackgroundMergeType(top: updatedMergedTop == .fullyMerged, bottom: updatedMergedBottom == .fullyMerged, side: forceBackgroundSide)
                    let backgroundType: ChatMessageBackgroundType
                    if hideBackground {
                        backgroundType = .none
                    } else if !incoming {
                        backgroundType = .outgoing(mergeType)
                    } else {
                        backgroundType = .incoming(mergeType)
                    }
                    strongSelf.backgroundNode.setType(type: backgroundType, highlighted: strongSelf.highlightedState, graphics: graphics, transition: transition)
                    
                    strongSelf.backgroundType = backgroundType
                    
                    if let nameNode = nameNodeSizeApply.1() {
                        strongSelf.nameNode = nameNode
                        if nameNode.supernode == nil {
                            if !nameNode.isNodeLoaded {
                                nameNode.isLayerBacked = true
                            }
                            strongSelf.addSubnode(nameNode)
                        }
                        nameNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + nameNodeOriginY), size: nameNodeSizeApply.0)
                    } else {
                        strongSelf.nameNode?.removeFromSupernode()
                        strongSelf.nameNode = nil
                    }
                    
                    if let forwardInfoNode = forwardInfoSizeApply.1() {
                        strongSelf.forwardInfoNode = forwardInfoNode
                        var animateFrame = true
                        if forwardInfoNode.supernode == nil {
                            strongSelf.addSubnode(forwardInfoNode)
                            animateFrame = false
                        }
                        let previousForwardInfoNodeFrame = forwardInfoNode.frame
                        forwardInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + forwardInfoOriginY), size: forwardInfoSizeApply.0)
                        if case let .System(duration) = animation {
                            if animateFrame {
                                forwardInfoNode.layer.animateFrame(from: previousForwardInfoNodeFrame, to: forwardInfoNode.frame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else {
                        strongSelf.forwardInfoNode?.removeFromSupernode()
                        strongSelf.forwardInfoNode = nil
                    }
                    
                    if let replyInfoNode = replyInfoSizeApply.1() {
                        strongSelf.replyInfoNode = replyInfoNode
                        var animateFrame = true
                        if replyInfoNode.supernode == nil {
                            strongSelf.addSubnode(replyInfoNode)
                            animateFrame = false
                        }
                        let previousReplyInfoNodeFrame = replyInfoNode.frame
                        replyInfoNode.frame = CGRect(origin: CGPoint(x: contentOrigin.x + layoutConstants.text.bubbleInsets.left, y: layoutConstants.bubble.contentInsets.top + replyInfoOriginY), size: replyInfoSizeApply.0)
                        if case let .System(duration) = animation {
                            if animateFrame {
                                replyInfoNode.layer.animateFrame(from: previousReplyInfoNodeFrame, to: replyInfoNode.frame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else {
                        strongSelf.replyInfoNode?.removeFromSupernode()
                        strongSelf.replyInfoNode = nil
                    }
                    
                    if removedContentNodeIndices?.count ?? 0 != 0 || addedContentNodes?.count ?? 0 != 0 {
                        var updatedContentNodes = strongSelf.contentNodes
                        
                        if let removedContentNodeIndices = removedContentNodeIndices {
                            for index in removedContentNodeIndices.reversed() {
                                let node = updatedContentNodes[index]
                                if animation.isAnimated {
                                    node.animateRemovalFromBubble(0.2, completion: { [weak node] in
                                        node?.removeFromSupernode()
                                    })
                                } else {
                                    node.removeFromSupernode()
                                }
                                let _ = updatedContentNodes.remove(at: index)
                            }
                        }
                        
                        if let addedContentNodes = addedContentNodes {
                            for contentNode in addedContentNodes {
                                updatedContentNodes.append(contentNode)
                                strongSelf.addSubnode(contentNode)
                                
                                contentNode.visibility = strongSelf.visibility
                            }
                        }
                        
                        strongSelf.contentNodes = updatedContentNodes
                    }
                    
                    var contentNodeIndex = 0
                    for (relativeFrame, _, apply) in contentNodeFramesPropertiesAndApply {
                        apply(animation)
                        
                        let contentNode = strongSelf.contentNodes[contentNodeIndex]
                        let contentNodeFrame = relativeFrame.offsetBy(dx: contentOrigin.x, dy: contentOrigin.y)
                        let previousContentNodeFrame = contentNode.frame
                        contentNode.frame = contentNodeFrame
                        
                        if case let .System(duration) = animation {
                            var animateFrame = false
                            var animateAlpha = false
                            if let addedContentNodes = addedContentNodes {
                                if !addedContentNodes.contains(where: { $0 === contentNode }) {
                                    animateFrame = true
                                } else {
                                    animateAlpha = true
                                }
                            } else {
                                animateFrame = true
                            }
                            
                            if animateFrame {
                                contentNode.layer.animateFrame(from: previousContentNodeFrame, to: contentNodeFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            } else if animateAlpha {
                                contentNode.animateInsertionIntoBubble(duration)
                                var previousAlignedContentNodeFrame = contentNodeFrame
                                previousAlignedContentNodeFrame.origin.x += backgroundFrame.size.width - strongSelf.backgroundNode.frame.size.width
                                contentNode.layer.animateFrame(from: previousAlignedContentNodeFrame, to: contentNodeFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                        contentNodeIndex += 1
                    }
                    
                    if let mosaicStatusOrigin = mosaicStatusOrigin, let (size, apply) = mosaicStatusSizeAndApply {
                        let mosaicStatusNode = apply(false)
                        if mosaicStatusNode !== strongSelf.mosaicStatusNode {
                            strongSelf.mosaicStatusNode?.removeFromSupernode()
                            strongSelf.mosaicStatusNode = mosaicStatusNode
                            strongSelf.addSubnode(mosaicStatusNode)
                        }
                        let absoluteOrigin = mosaicStatusOrigin.offsetBy(dx: contentOrigin.x, dy: contentOrigin.y)
                        mosaicStatusNode.frame = CGRect(origin: CGPoint(x: absoluteOrigin.x - layoutConstants.image.statusInsets.right - size.width, y: absoluteOrigin.y - layoutConstants.image.statusInsets.bottom - size.height), size: size)
                    } else if let mosaicStatusNode = strongSelf.mosaicStatusNode {
                        strongSelf.mosaicStatusNode = nil
                        mosaicStatusNode.removeFromSupernode()
                    }
                    
                    if let updatedShareButtonNode = updatedShareButtonNode {
                        if updatedShareButtonNode !== strongSelf.shareButtonNode {
                            if let shareButtonNode = strongSelf.shareButtonNode {
                                shareButtonNode.removeFromSupernode()
                            }
                            strongSelf.shareButtonNode = updatedShareButtonNode
                            strongSelf.addSubnode(updatedShareButtonNode)
                            updatedShareButtonNode.addTarget(strongSelf, action: #selector(strongSelf.shareButtonPressed), forControlEvents: .touchUpInside)
                        }
                        if let updatedShareButtonBackground = updatedShareButtonBackground {
                            strongSelf.shareButtonNode?.setBackgroundImage(updatedShareButtonBackground, for: [.normal])
                        }
                    } else if let shareButtonNode = strongSelf.shareButtonNode {
                        shareButtonNode.removeFromSupernode()
                        strongSelf.shareButtonNode = nil
                    }
                    
                    if case .System = animation {
                        if !strongSelf.backgroundNode.frame.equalTo(backgroundFrame) {
                            strongSelf.backgroundFrameTransition = (strongSelf.backgroundNode.frame, backgroundFrame)
                            strongSelf.enableTransitionClippingNode()
                        }
                        if let shareButtonNode = strongSelf.shareButtonNode {
                            let currentBackgroundFrame = strongSelf.backgroundNode.frame
                            shareButtonNode.frame = CGRect(origin: CGPoint(x: currentBackgroundFrame.maxX + 8.0, y: currentBackgroundFrame.maxY - 30.0), size: CGSize(width: 29.0, height: 29.0))
                        }
                    } else {
                        if let _ = strongSelf.backgroundFrameTransition {
                            strongSelf.animateFrameTransition(1.0, backgroundFrame.size.height)
                            strongSelf.backgroundFrameTransition = nil
                        }
                        strongSelf.backgroundNode.frame = backgroundFrame
                        if let shareButtonNode = strongSelf.shareButtonNode {
                            shareButtonNode.frame = CGRect(origin: CGPoint(x: backgroundFrame.maxX + 8.0, y: backgroundFrame.maxY - 30.0), size: CGSize(width: 29.0, height: 29.0))
                        }
                        strongSelf.disableTransitionClippingNode()
                    }
                    let offset: CGFloat = params.leftInset + (incoming ? 42.0 : 0.0)
                    strongSelf.selectionNode?.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: params.width, height: layout.size.height))
                    
                    if let actionButtonsSizeAndApply = actionButtonsSizeAndApply {
                        var animated = false
                        if let _ = strongSelf.actionButtonsNode {
                            if case .System = animation {
                                animated = true
                            }
                        }
                        let actionButtonsNode = actionButtonsSizeAndApply.1(animated)
                        let previousFrame = actionButtonsNode.frame
                        let actionButtonsFrame = CGRect(origin: CGPoint(x: backgroundFrame.minX + (incoming ? layoutConstants.bubble.contentInsets.left : layoutConstants.bubble.contentInsets.right), y: backgroundFrame.maxY), size: actionButtonsSizeAndApply.0)
                        actionButtonsNode.frame = actionButtonsFrame
                        if actionButtonsNode !== strongSelf.actionButtonsNode {
                            strongSelf.actionButtonsNode = actionButtonsNode
                            actionButtonsNode.buttonPressed = { button in
                                if let strongSelf = self {
                                    strongSelf.performMessageButtonAction(button: button)
                                }
                            }
                            strongSelf.addSubnode(actionButtonsNode)
                        } else {
                            if case let .System(duration) = animation {
                                actionButtonsNode.layer.animateFrame(from: previousFrame, to: actionButtonsFrame, duration: duration, timingFunction: kCAMediaTimingFunctionSpring)
                            }
                        }
                    } else if let actionButtonsNode = strongSelf.actionButtonsNode {
                        actionButtonsNode.removeFromSupernode()
                        strongSelf.actionButtonsNode = nil
                    }
                }
            })
        }
    }
    
    private func addContentNode(node: ChatMessageBubbleContentNode) {
        if let transitionClippingNode = self.transitionClippingNode {
            transitionClippingNode.addSubnode(node)
        } else {
            self.addSubnode(node)
        }
    }
    
    private func enableTransitionClippingNode() {
        if self.transitionClippingNode == nil {
            let node = ASDisplayNode()
            node.clipsToBounds = true
            var backgroundFrame = self.backgroundNode.frame
            backgroundFrame = backgroundFrame.insetBy(dx: 0.0, dy: 1.0)
            node.frame = backgroundFrame
            node.bounds = CGRect(origin: CGPoint(x: backgroundFrame.origin.x, y: backgroundFrame.origin.y), size: backgroundFrame.size)
            if let forwardInfoNode = self.forwardInfoNode {
                node.addSubnode(forwardInfoNode)
            }
            if let replyInfoNode = self.replyInfoNode {
                node.addSubnode(replyInfoNode)
            }
            for contentNode in self.contentNodes {
                node.addSubnode(contentNode)
            }
            self.addSubnode(node)
            self.transitionClippingNode = node
        }
    }
    
    private func disableTransitionClippingNode() {
        if let transitionClippingNode = self.transitionClippingNode {
            if let forwardInfoNode = self.forwardInfoNode {
                self.addSubnode(forwardInfoNode)
            }
            if let replyInfoNode = self.replyInfoNode {
                self.addSubnode(replyInfoNode)
            }
            for contentNode in self.contentNodes {
                self.addSubnode(contentNode)
            }
            transitionClippingNode.removeFromSupernode()
            self.transitionClippingNode = nil
        }
    }
    
    override func shouldAnimateHorizontalFrameTransition() -> Bool {
        if let _ = self.backgroundFrameTransition {
            return true
        } else {
            return false
        }
    }
    
    override func animateFrameTransition(_ progress: CGFloat, _ currentValue: CGFloat) {
        super.animateFrameTransition(progress, currentValue)
        
        if let backgroundFrameTransition = self.backgroundFrameTransition {
            let backgroundFrame = CGRect.interpolator()(backgroundFrameTransition.0, backgroundFrameTransition.1, progress) as! CGRect
            self.backgroundNode.frame = backgroundFrame
            
            if let shareButtonNode = self.shareButtonNode {
                shareButtonNode.frame = CGRect(origin: CGPoint(x: backgroundFrame.maxX + 8.0, y: backgroundFrame.maxY - 30.0), size: CGSize(width: 29.0, height: 29.0))
            }
            
            if let transitionClippingNode = self.transitionClippingNode {
                var fixedBackgroundFrame = backgroundFrame
                fixedBackgroundFrame = fixedBackgroundFrame.insetBy(dx: 0.0, dy: self.backgroundNode.type == ChatMessageBackgroundType.none ? 0.0 : 1.0)
                
                transitionClippingNode.frame = fixedBackgroundFrame
                transitionClippingNode.bounds = CGRect(origin: CGPoint(x: fixedBackgroundFrame.origin.x, y: fixedBackgroundFrame.origin.y), size: fixedBackgroundFrame.size)
                
                if progress >= 1.0 - CGFloat.ulpOfOne {
                    self.disableTransitionClippingNode()
                }
            }
            
            if CGFloat(1.0).isLessThanOrEqualTo(progress) {
                self.backgroundFrameTransition = nil
            }
        }
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .began:
                if let (gesture, _) = recognizer.lastRecognizedGestureAndLocation, case .hold = gesture {
                    if let item = self.item, item.message.containsSecretMedia {
                        item.controllerInteraction.openSecretMessagePreview(item.message.id)
                    }
                }
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(location) {
                                
                                if let item = self.item, let author = item.content.firstMessage.author {
                                    item.controllerInteraction.openPeer(item.effectiveAuthorId ?? author.id, .info, item.message)
                                }
                                return
                            }
                            
                            if let nameNode = self.nameNode, nameNode.frame.contains(location) {
                                if let item = self.item {
                                    for attribute in item.message.attributes {
                                        if let attribute = attribute as? InlineBotMessageAttribute {
                                            var botAddressName: String?
                                            if let peerId = attribute.peerId, let botPeer = item.message.peers[peerId], let addressName = botPeer.addressName {
                                                botAddressName = addressName
                                            } else {
                                                botAddressName = attribute.title
                                            }
                                            
                                            if let botAddressName = botAddressName {
                                                item.controllerInteraction.updateInputState { textInputState in
                                                    return ChatTextInputState(inputText: NSAttributedString(string: "@" + botAddressName + " "))
                                                }
                                            }
                                            return
                                        }
                                    }
                                }
                            } else if let replyInfoNode = self.replyInfoNode, replyInfoNode.frame.contains(location) {
                                if let item = self.item {
                                    for attribute in item.message.attributes {
                                        if let attribute = attribute as? ReplyMessageAttribute {
                                            item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId)
                                            return
                                        }
                                    }
                                }
                            }
                            if let forwardInfoNode = self.forwardInfoNode, forwardInfoNode.frame.contains(location) {
                                if let item = self.item, let forwardInfo = item.message.forwardInfo {
                                    if let sourceMessageId = forwardInfo.sourceMessageId {
                                        item.controllerInteraction.navigateToMessage(item.message.id, sourceMessageId)
                                    } else {
                                        item.controllerInteraction.openPeer(forwardInfo.source?.id ?? forwardInfo.author.id, .chat(textInputState: nil, messageId: nil), nil)
                                    }
                                    return
                                }
                            }
                            var foundTapAction = false
                            loop: for contentNode in self.contentNodes {
                                let tapAction = contentNode.tapActionAtPoint(CGPoint(x: location.x - contentNode.frame.minX, y: location.y - contentNode.frame.minY))
                                switch tapAction {
                                    case .none, .ignore:
                                        break
                                    case let .url(url):
                                        foundTapAction = true
                                        self.item?.controllerInteraction.openUrl(url)
                                        break loop
                                    case let .peerMention(peerId, _):
                                        foundTapAction = true
                                        self.item?.controllerInteraction.openPeer(peerId, .chat(textInputState: nil, messageId: nil), nil)
                                        break loop
                                    case let .textMention(name):
                                        foundTapAction = true
                                        self.item?.controllerInteraction.openPeerMention(name)
                                        break loop
                                    case let .botCommand(command):
                                        foundTapAction = true
                                        if let item = self.item {
                                        item.controllerInteraction.sendBotCommand(item.message.id, command)
                                        }
                                        break loop
                                    case let .hashtag(peerName, hashtag):
                                        foundTapAction = true
                                        self.item?.controllerInteraction.openHashtag(peerName, hashtag)
                                        break loop
                                    case .instantPage:
                                        foundTapAction = true
                                        if let item = self.item {
                                            item.controllerInteraction.openInstantPage(item.message)
                                        }
                                        break loop
                                    case .holdToPreviewSecretMedia:
                                        foundTapAction = true
                                    case let .call(peerId):
                                        foundTapAction = true
                                        self.item?.controllerInteraction.callPeer(peerId)
                                        break loop
                                }
                            }
                            if !foundTapAction {
                                self.item?.controllerInteraction.clickThroughMessage()
                            }
                        case .longTap, .doubleTap:
                            if let item = self.item, self.backgroundNode.frame.contains(location) {
                                var foundTapAction = false
                                var tapMessage: Message? = item.content.firstMessage
                                loop: for contentNode in self.contentNodes {
                                    if !contentNode.frame.contains(location) {
                                        continue loop
                                    }
                                    tapMessage = contentNode.item?.message
                                    let tapAction = contentNode.tapActionAtPoint(CGPoint(x: location.x - contentNode.frame.minX, y: location.y - contentNode.frame.minY))
                                    switch tapAction {
                                        case .none, .ignore:
                                            break
                                        case let .url(url):
                                            foundTapAction = true
                                            item.controllerInteraction.longTap(.url(url))
                                            break loop
                                        case let .peerMention(peerId, mention):
                                            foundTapAction = true
                                            item.controllerInteraction.longTap(.peerMention(peerId, mention))
                                            break loop
                                        case let .textMention(name):
                                            foundTapAction = true
                                            item.controllerInteraction.longTap(.mention(name))
                                            break loop
                                        case let .botCommand(command):
                                            foundTapAction = true
                                            item.controllerInteraction.longTap(.command(command))
                                            break loop
                                        case let .hashtag(_, hashtag):
                                            foundTapAction = true
                                            item.controllerInteraction.longTap(.hashtag(hashtag))
                                            break loop
                                        case .instantPage:
                                            break
                                        case .holdToPreviewSecretMedia:
                                            break
                                        case .call:
                                            break
                                    }
                                }
                                if !foundTapAction, let tapMessage = tapMessage {
                                    item.controllerInteraction.openMessageContextMenu(tapMessage, self, self.backgroundNode.frame)
                                }
                            }
                        case .hold:
                            if let item = self.item, item.message.containsSecretMedia {
                                item.controllerInteraction.closeSecretMessagePreview()
                            }
                    }
                }
            case .cancelled:
                if let item = self.item, item.message.containsSecretMedia {
                    item.controllerInteraction.closeSecretMessagePreview()
                }
            default:
                break
        }
    }
    
    private func traceSelectionNodes(parent: ASDisplayNode, point: CGPoint) -> ASDisplayNode? {
        if let parent = parent as? GridMessageSelectionNode, parent.bounds.contains(point) {
            return parent
        } else {
            for subnode in parent.subnodes {
                let subnodeFrame = subnode.frame
                if let result = traceSelectionNodes(parent: subnode, point: point.offsetBy(dx: -subnodeFrame.minX, dy: -subnodeFrame.minY)) {
                    return result
                }
            }
            return nil
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if !self.bounds.contains(point) {
            return nil
        }
        
        if let shareButtonNode = self.shareButtonNode, shareButtonNode.frame.contains(point) {
            return shareButtonNode.view
        }
        
        if let avatarNode = self.accessoryItemNode as? ChatMessageAvatarAccessoryItemNode, avatarNode.frame.contains(point) {
            return self.view
        }
        
        if let selectionNode = self.selectionNode {
            if let result = self.traceSelectionNodes(parent: self, point: point.offsetBy(dx: -42.0, dy: 0.0)) {
                return result.view
            }
            
            var selectionNodeFrame = selectionNode.frame
            selectionNodeFrame.origin.x -= 42.0
            selectionNodeFrame.size.width += 42.0 * 2.0
            if selectionNodeFrame.contains(point) {
                return selectionNode.view
            } else {
                return nil
            }
        }
        
        if !self.backgroundNode.frame.contains(point) {
            if self.actionButtonsNode == nil || !self.actionButtonsNode!.frame.contains(point) {
                //return nil
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    override func transitionNode(id: MessageId, media: Media) -> (ASDisplayNode, () -> UIView?)? {
        for contentNode in self.contentNodes {
            if let result = contentNode.transitionNode(messageId: id, media: media) {
                return result
            }
        }
        return nil
    }
    
    override func peekPreviewContent(at point: CGPoint) -> (Message, ChatMessagePeekPreviewContent)? {
        for contentNode in self.contentNodes {
            let frame = contentNode.frame
            if let result = contentNode.peekPreviewContent(at: point.offsetBy(dx: -frame.minX, dy: -frame.minY)) {
                return result
            }
        }
        return nil
    }
    
    override func updateHiddenMedia() {
        var hasHiddenMosaicStatus = false
        if let item = self.item {
            for contentNode in self.contentNodes {
                if let contentItem = contentNode.item {
                    if contentNode.updateHiddenMedia(item.controllerInteraction.hiddenMedia[contentItem.message.id]) {
                        if let mosaicStatusNode = self.mosaicStatusNode, mosaicStatusNode.frame.intersects(contentNode.frame) {
                            hasHiddenMosaicStatus = true
                        }
                    }
                }
            }
        }
        
        if let mosaicStatusNode = self.mosaicStatusNode {
            if mosaicStatusNode.alpha.isZero != hasHiddenMosaicStatus {
                if hasHiddenMosaicStatus {
                    mosaicStatusNode.alpha = 0.0
                } else {
                    mosaicStatusNode.alpha = 1.0
                    mosaicStatusNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    override func updateAutomaticMediaDownloadSettings() {
        if let item = self.item {
            for contentNode in self.contentNodes {
                contentNode.updateAutomaticMediaDownloadSettings(item.controllerInteraction.automaticMediaDownloadSettings)
            }
        }
    }
    
    override func updateSelectionState(animated: Bool) {
        guard let item = self.item else {
            return
        }
        
        if let selectionState = item.controllerInteraction.selectionState {
            var selected = false
            var incoming = true
            
            switch item.content {
                case let .message(message, _, _):
                    selected = selectionState.selectedIds.contains(message.id)
                case let .group(messages: messages):
                    var allSelected = !messages.isEmpty
                    for (message, _, _) in messages {
                        if !selectionState.selectedIds.contains(message.id) {
                            allSelected = false
                            break
                        }
                    }
                    selected = allSelected
            }
            
            incoming = item.message.effectivelyIncoming(item.account.peerId)
            
            let offset: CGFloat = incoming ? 42.0 : 0.0
            
            if let selectionNode = self.selectionNode {
                selectionNode.updateSelected(selected, animated: animated)
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
            } else {
                let selectionNode = ChatMessageSelectionNode(theme: item.presentationData.theme, toggle: { [weak self] value in
                    if let strongSelf = self, let item = strongSelf.item {
                        switch item.content {
                            case let .message(message, _, _):
                            item.controllerInteraction.toggleMessagesSelection([message.id], value)
                            case let .group(messages):
                                item.controllerInteraction.toggleMessagesSelection(messages.map { $0.0.id }, value)
                        }
                    }
                })
                
                selectionNode.frame = CGRect(origin: CGPoint(x: -offset, y: 0.0), size: CGSize(width: self.contentBounds.size.width, height: self.contentBounds.size.height))
                self.addSubnode(selectionNode)
                self.selectionNode = selectionNode
                selectionNode.updateSelected(selected, animated: false)
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DMakeTranslation(offset, 0.0, 0.0);
                if animated {
                    selectionNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4)
                    
                    if !incoming {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: CGPoint(x: position.x - 42.0, y: position.y), to: position, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
                    }
                }
            }
        } else {
            if let selectionNode = self.selectionNode {
                self.selectionNode = nil
                let previousSubnodeTransform = self.subnodeTransform
                self.subnodeTransform = CATransform3DIdentity
                if animated {
                    self.layer.animate(from: NSValue(caTransform3D: previousSubnodeTransform), to: NSValue(caTransform3D: self.subnodeTransform), keyPath: "sublayerTransform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.4, completion: { [weak selectionNode]_ in
                        selectionNode?.removeFromSupernode()
                    })
                    selectionNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
                    if CGFloat(0.0).isLessThanOrEqualTo(selectionNode.frame.origin.x) {
                        let position = selectionNode.layer.position
                        selectionNode.layer.animatePosition(from: position, to: CGPoint(x: position.x - 42.0, y: position.y), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                    }
                } else {
                    selectionNode.removeFromSupernode()
                }
            }
        }
    }
    
    override func updateHighlightedState(animated: Bool) {
        super.updateHighlightedState(animated: animated)
        
        if let item = self.item {
            var highlighted = false
            if let highlightedState = item.controllerInteraction.highlightedState {
                for message in item.content {
                    if highlightedState.messageStableId == message.stableId {
                        highlighted = true
                        break
                    }
                }
            }
            
            if self.highlightedState != highlighted {
                self.highlightedState = highlighted
                if let backgroundType = self.backgroundType {
                    let graphics = PresentationResourcesChat.principalGraphics(item.presentationData.theme)
                    
                    if highlighted {
                        self.backgroundNode.setType(type: backgroundType, highlighted: true, graphics: graphics, transition: .immediate)
                    } else {
                        if let previousContents = self.backgroundNode.layer.contents, animated {
                            self.backgroundNode.setType(type: backgroundType, highlighted: false, graphics: graphics, transition: .immediate)
                            
                            if let updatedContents = self.backgroundNode.layer.contents {
                                self.backgroundNode.layer.animate(from: previousContents as AnyObject, to: updatedContents as AnyObject, keyPath: "contents", timingFunction: kCAMediaTimingFunctionEaseInEaseOut, duration: 0.42)
                            }
                        } else {
                            self.backgroundNode.setType(type: backgroundType, highlighted: false, graphics: graphics, transition: .immediate)
                        }
                    }
                }
            }
        }
    }
    
    private func performMessageButtonAction(button: ReplyMarkupButton) {
        if let item = self.item {
            switch button.action {
                case .text:
                    item.controllerInteraction.sendMessage(button.title)
                case let .url(url):
                    item.controllerInteraction.openUrl(url)
                case .requestMap:
                    item.controllerInteraction.shareCurrentLocation()
                case .requestPhone:
                    item.controllerInteraction.shareAccountContact()
                case .openWebApp:
                    item.controllerInteraction.requestMessageActionCallback(item.message.id, nil, true)
                case let .callback(data):
                    item.controllerInteraction.requestMessageActionCallback(item.message.id, data, false)
                case let .switchInline(samePeer, query):
                    var botPeer: Peer?
                    
                    var found = false
                    for attribute in item.message.attributes {
                        if let attribute = attribute as? InlineBotMessageAttribute {
                            if let peerId = attribute.peerId {
                                botPeer = item.message.peers[peerId]
                                found = true
                            }
                        }
                    }
                    if !found {
                        botPeer = item.message.author
                    }
                    
                    var peerId: PeerId?
                    if samePeer {
                        peerId = item.message.id.peerId
                    }
                    if let botPeer = botPeer, let addressName = botPeer.addressName {
                        item.controllerInteraction.openPeer(peerId, .chat(textInputState: ChatTextInputState(inputText: NSAttributedString(string: "@\(addressName) \(query)")), messageId: nil), nil)
                    }
                case .payment:
                    item.controllerInteraction.openCheckoutOrReceipt(item.message.id)
            }
        }
    }
    
    @objc func shareButtonPressed() {
        if let item = self.item {
            if item.content.firstMessage.id.peerId == item.account.peerId {
                for attribute in item.content.firstMessage.attributes {
                    if let attribute = attribute as? SourceReferenceMessageAttribute {
                        item.controllerInteraction.navigateToMessage(item.content.firstMessage.id, attribute.messageId)
                        break
                    }
                }
            } else {
                item.controllerInteraction.openMessageShareMenu(item.message.id)
            }
        }
    }
    
    @objc func swipeToReplyGesture(_ recognizer: ChatSwipeToReplyRecognizer) {
        switch recognizer.state {
            case .began:
                self.currentSwipeToReplyTranslation = 0.0
                if self.swipeToReplyFeedback == nil {
                    self.swipeToReplyFeedback = HapticFeedback()
                    self.swipeToReplyFeedback?.prepareImpact()
                }
                (self.view.window as? WindowHost)?.cancelInteractiveKeyboardGestures()
            case .changed:
                let translation = recognizer.translation(in: self.view)
                var animateReplyNodeIn = false
                if (translation.x < -45.0) != (self.currentSwipeToReplyTranslation < -45.0) {
                    if translation.x < -45.0, self.swipeToReplyNode == nil, let item = self.item {
                        self.swipeToReplyFeedback?.impact()
                        
                        let swipeToReplyNode = ChatMessageSwipeToReplyNode(fillColor: item.presentationData.theme.chat.bubble.shareButtonFillColor, strokeColor: item.presentationData.theme.chat.bubble.shareButtonStrokeColor, foregroundColor: item.presentationData.theme.chat.bubble.shareButtonForegroundColor)
                        self.swipeToReplyNode = swipeToReplyNode
                        self.addSubnode(swipeToReplyNode)
                        animateReplyNodeIn = true
                    }
                }
                self.currentSwipeToReplyTranslation = translation.x
                var bounds = self.bounds
                bounds.origin.x = -translation.x
                self.bounds = bounds
            
                if let swipeToReplyNode = self.swipeToReplyNode {
                    swipeToReplyNode.frame = CGRect(origin: CGPoint(x: bounds.size.width, y: floor((self.contentSize.height - 33.0) / 2.0)), size: CGSize(width: 33.0, height: 33.0))
                    if animateReplyNodeIn {
                        swipeToReplyNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.12)
                        swipeToReplyNode.layer.animateSpring(from: 0.1 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.4)
                    }
                }
            case .cancelled, .ended:
                self.swipeToReplyFeedback = nil
                
                let translation = recognizer.translation(in: self.view)
                if case .ended = recognizer.state, translation.x < -45.0 {
                    if let item = self.item {
                        item.controllerInteraction.setupReply(item.message.id)
                    }
                }
                var bounds = self.bounds
                let previousBounds = bounds
                bounds.origin.x = 0.0
                self.bounds = bounds
                self.layer.animateBounds(from: previousBounds, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                if let swipeToReplyNode = self.swipeToReplyNode {
                    self.swipeToReplyNode = nil
                    swipeToReplyNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak swipeToReplyNode] _ in
                        swipeToReplyNode?.removeFromSupernode()
                    })
                    swipeToReplyNode.layer.animateScale(from: 1.0, to: 0.2, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
                }
            default:
                break
        }
    }
}
