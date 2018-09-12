import Foundation
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore

private let titleFont = Font.regular(13.0)
private let titleBoldFont = Font.bold(13.0)

private func peerMentionAttributes(primaryTextColor: UIColor, peerId: PeerId) -> MarkdownAttributeSet {
    return MarkdownAttributeSet(font: titleBoldFont, textColor: primaryTextColor, additionalAttributes: [TelegramTextAttributes.PeerMention: TelegramPeerMention(peerId: peerId, mention: "")])
}

private func peerMentionsAttributes(primaryTextColor: UIColor, peerIds: [(Int, PeerId?)]) -> [Int: MarkdownAttributeSet] {
    var result: [Int: MarkdownAttributeSet] = [:]
    for (index, peerId) in peerIds {
        if let peerId = peerId {
            result[index] = peerMentionAttributes(primaryTextColor: primaryTextColor, peerId: peerId)
        }
    }
    return result
}

private func attributedServiceMessageString(theme: PresentationTheme, strings: PresentationStrings, message: Message, accountPeerId: PeerId) -> NSAttributedString? {
    return universalServiceMessageString(theme: theme, strings: strings, message: message, accountPeerId: accountPeerId)
}

func plainServiceMessageString(strings: PresentationStrings, message: Message, accountPeerId: PeerId) -> String? {
    return universalServiceMessageString(theme: nil, strings: strings, message: message, accountPeerId: accountPeerId)?.string
}

private func universalServiceMessageString(theme: PresentationTheme?, strings: PresentationStrings, message: Message, accountPeerId: PeerId) -> NSAttributedString? {
    var attributedString: NSAttributedString?
    
    let theme = theme?.chat.serviceMessage
    
    let primaryTextColor = theme?.serviceMessagePrimaryTextColor ?? UIColor.black
    
    let bodyAttributes = MarkdownAttributeSet(font: titleFont, textColor: primaryTextColor, additionalAttributes: [:])
    
    for media in message.media {
        if let action = media as? TelegramMediaAction {
            let authorName = message.author?.displayTitle ?? ""
            
            var isChannel = false
            if message.id.peerId.namespace == Namespaces.Peer.CloudChannel, let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                isChannel = true
            }
            
            switch action.action {
                case let .groupCreated(title):
                    if isChannel {
                        attributedString = NSAttributedString(string: strings.Notification_CreatedChannel, font: titleFont, textColor: primaryTextColor)
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_CreatedChatWithTitle(authorName, title), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                case let .addedMembers(peerIds):
                    if let peerId = peerIds.first, peerId == message.author?.id {
                        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedChannel(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, peerId)]))
                        } else {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedChat(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, peerId)]))
                        }
                    } else {
                        var attributePeerIds: [(Int, PeerId?)] = [(0, message.author?.id)]
                        if peerIds.count == 1 {
                            attributePeerIds.append((1, peerIds.first))
                        }
                        attributedString = addAttributesToStringWithRanges(strings.Notification_Invited(authorName, peerDisplayTitles(peerIds, message.peers)), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                case let .removedMembers(peerIds):
                    if peerIds.first == message.author?.id {
                        if let peer = message.peers[message.id.peerId] as? TelegramChannel, case .broadcast = peer.info {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_LeftChannel(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        } else {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_LeftChat(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        }
                    } else {
                        var attributePeerIds: [(Int, PeerId?)] = [(0, message.author?.id)]
                        if peerIds.count == 1 {
                            attributePeerIds.append((1, peerIds.first))
                        }
                        attributedString = addAttributesToStringWithRanges(strings.Notification_Kicked(authorName, peerDisplayTitles(peerIds, message.peers)), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                case let .photoUpdated(image):
                    if authorName.isEmpty || isChannel {
                        if isChannel {
                            if image != nil {
                                attributedString = NSAttributedString(string: strings.Channel_MessagePhotoUpdated, font: titleFont, textColor: primaryTextColor)
                            } else {
                                attributedString = NSAttributedString(string: strings.Channel_MessagePhotoRemoved, font: titleFont, textColor: primaryTextColor)
                            }
                        } else {
                            if image != nil {
                                attributedString = NSAttributedString(string: strings.Group_MessagePhotoUpdated, font: titleFont, textColor: primaryTextColor)
                            } else {
                                attributedString = NSAttributedString(string: strings.Group_MessagePhotoRemoved, font: titleFont, textColor: primaryTextColor)
                            }
                        }
                    } else {
                        if image != nil {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupPhoto(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        } else {
                            attributedString = addAttributesToStringWithRanges(strings.Notification_RemovedGroupPhoto(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        }
                    }
                case let .titleUpdated(title):
                    if authorName.isEmpty || isChannel {
                        attributedString = NSAttributedString(string: strings.Channel_MessageTitleUpdated(title).0, font: titleFont, textColor: primaryTextColor)
                    } else {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_ChangedGroupName(authorName, title), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                case .pinnedMessageUpdated:
                    enum PinnnedMediaType {
                        case text(String)
                        case game
                        case photo
                        case video
                        case round
                        case audio
                        case file
                        case gif
                        case sticker
                        case location
                        case contact
                        case deleted
                    }
                    
                    var pinnedMessage: Message?
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                            pinnedMessage = message
                        }
                    }
                    
                    var type: PinnnedMediaType
                    if let pinnedMessage = pinnedMessage {
                        type = .text(pinnedMessage.text)
                        inner: for media in pinnedMessage.media {
                            if media is TelegramMediaGame {
                                type = .game
                                break inner
                            }
                            if let _ = media as? TelegramMediaImage {
                                type = .photo
                            } else if let file = media as? TelegramMediaFile {
                                type = .file
                                if file.isAnimated {
                                    type = .gif
                                } else {
                                    for attribute in file.attributes {
                                        switch attribute {
                                        case let .Video(_, _, flags):
                                            if flags.contains(.instantRoundVideo) {
                                                type = .round
                                            } else {
                                                type = .video
                                            }
                                            break inner
                                        case let .Audio(isVoice, _, _, _, _):
                                            if isVoice {
                                                type = .audio
                                            } else {
                                                type = .file
                                            }
                                            break inner
                                        case .Sticker:
                                            type = .sticker
                                            break inner
                                        case .Animated:
                                            break
                                        default:
                                            break
                                        }
                                    }
                                }
                            } else if let _ = media as? TelegramMediaMap {
                                type = .location
                            } else if let _ = media as? TelegramMediaContact {
                                type = .contact
                            }
                        }
                    } else {
                        type = .deleted
                    }
                    
                    switch type {
                        case let .text(text):
                            var clippedText = text.replacingOccurrences(of: "\n", with: " ")
                            if clippedText.count > 14 {
                                clippedText = "\(clippedText[...clippedText.index(clippedText.startIndex, offsetBy: 14)])..."
                            }
                            let textWithRanges: (String, [(Int, NSRange)])
                            if clippedText.isEmpty {
                                textWithRanges = strings.PINNED_NOTEXT(authorName)
                            } else {
                                textWithRanges = strings.Notification_PinnedTextMessage(authorName, clippedText)
                            }
                            attributedString = addAttributesToStringWithRanges(textWithRanges, body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .game:
                            attributedString = addAttributesToStringWithRanges(strings.PINNED_GAME(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .photo:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedPhotoMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .video:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedVideoMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .round:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedRoundMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .audio:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedAudioMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .file:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedDocumentMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .gif:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedAnimationMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .sticker:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedStickerMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .location:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedLocationMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .contact:
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedContactMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                        case .deleted:
                            attributedString = addAttributesToStringWithRanges(strings.PINNED_NOTEXT(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                    }
                case .joinedByLink:
                    attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedGroupByLink(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
                case .channelMigratedFromGroup, .groupMigratedToChannel:
                    attributedString = NSAttributedString(string: strings.Notification_ChannelMigratedFrom, font: titleFont, textColor: primaryTextColor)
                case let .messageAutoremoveTimeoutUpdated(timeout):
                    if timeout > 0 {
                        let timeValue = timeIntervalString(strings: strings, value: timeout)
                        
                        let string: String
                        if message.author?.id == accountPeerId {
                            string = strings.Notification_MessageLifetimeChangedOutgoing(timeValue).0
                        } else {
                            let authorString: String
                            if let author = messageMainPeer(message) {
                                authorString = author.compactDisplayTitle
                            } else {
                                authorString = ""
                            }
                            string = strings.Notification_MessageLifetimeChanged(authorString, timeValue).0
                        }
                        attributedString = NSAttributedString(string: string, font: titleFont, textColor: primaryTextColor)
                    } else {
                        let string: String
                        if message.author?.id == accountPeerId {
                            string = strings.Notification_MessageLifetimeRemovedOutgoing
                        } else {
                            let authorString: String
                            if let author = messageMainPeer(message) {
                                authorString = author.compactDisplayTitle
                            } else {
                                authorString = ""
                            }
                            string = strings.Notification_MessageLifetimeRemoved(authorString).0
                        }
                        attributedString = NSAttributedString(string: string, font: titleFont, textColor: primaryTextColor)
                    }
                case .historyCleared:
                    break
                case .historyScreenshot:
                    let text: String
                    if message.effectivelyIncoming(accountPeerId) {
                        text = strings.Notification_SecretChatMessageScreenshot(message.author?.compactDisplayTitle ?? "").0
                    } else {
                        text = strings.Notification_SecretChatMessageScreenshotSelf
                    }
                    attributedString = NSAttributedString(string: text, font: titleFont, textColor: primaryTextColor)
                case let .gameScore(gameId: _, score):
                    var gameTitle: String?
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                            for media in message.media {
                                if let game = media as? TelegramMediaGame {
                                    gameTitle = game.title
                                    break inner
                                }
                            }
                        }
                    }
                    
                    var baseString: String
                    if message.author?.id == accountPeerId {
                        if let _ = gameTitle {
                            baseString = strings.ServiceMessage_GameScoreSelfExtended(score)
                        } else {
                            baseString = strings.ServiceMessage_GameScoreSelfSimple(score)
                        }
                    } else {
                        if let _ = gameTitle {
                            baseString = strings.ServiceMessage_GameScoreExtended(score)
                        } else {
                            baseString = strings.ServiceMessage_GameScoreSimple(score)
                        }
                    }
                    let baseStringValue = baseString as NSString
                    var ranges: [(Int, NSRange)] = []
                    if baseStringValue.range(of: "{name}").location != NSNotFound {
                        ranges.append((0, baseStringValue.range(of: "{name}")))
                    }
                    if baseStringValue.range(of: "{game}").location != NSNotFound {
                        ranges.append((1, baseStringValue.range(of: "{game}")))
                    }
                    ranges.sort(by: { $0.1.location < $1.1.location })
                    
                    var argumentAttributes = peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)])
                    argumentAttributes[1] = MarkdownAttributeSet(font: titleBoldFont, textColor: primaryTextColor, additionalAttributes: [:])
                    attributedString = addAttributesToStringWithRanges(formatWithArgumentRanges(baseString, ranges, [authorName, gameTitle ?? ""]), body: bodyAttributes, argumentAttributes: argumentAttributes)
                case let .paymentSent(currency, totalAmount):
                    var invoiceMessage: Message?
                    for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute, let message = message.associatedMessages[attribute.messageId] {
                            invoiceMessage = message
                        }
                    }
                    
                    var invoiceTitle: String?
                    if let invoiceMessage = invoiceMessage {
                        for media in invoiceMessage.media {
                            if let invoice = media as? TelegramMediaInvoice {
                                invoiceTitle = invoice.title
                            }
                        }
                    }
                    
                    if let invoiceTitle = invoiceTitle {
                        let botString: String
                        if let peer = messageMainPeer(message) {
                            botString = peer.compactDisplayTitle
                        } else {
                            botString = ""
                        }
                        let mutableString = NSMutableAttributedString()
                        mutableString.append(NSAttributedString(string: strings.Notification_PaymentSent, font: titleFont, textColor: primaryTextColor))
                        
                        var range = NSRange(location: NSNotFound, length: 0)
                        
                        range = (mutableString.string as NSString).range(of: "{amount}")
                        if range.location != NSNotFound {
                            mutableString.replaceCharacters(in: range, with: NSAttributedString(string: formatCurrencyAmount(totalAmount, currency: currency), font: titleBoldFont, textColor: primaryTextColor))
                        }
                        range = (mutableString.string as NSString).range(of: "{name}")
                        if range.location != NSNotFound {
                            mutableString.replaceCharacters(in: range, with: NSAttributedString(string: botString, font: titleBoldFont, textColor: primaryTextColor))
                        }
                        range = (mutableString.string as NSString).range(of: "{title}")
                        if range.location != NSNotFound {
                            mutableString.replaceCharacters(in: range, with: NSAttributedString(string: invoiceTitle, font: titleFont, textColor: primaryTextColor))
                        }
                        attributedString = mutableString
                    } else {
                        attributedString = NSAttributedString(string: strings.Message_PaymentSent(formatCurrencyAmount(totalAmount, currency: currency)).0, font: titleFont, textColor: primaryTextColor)
                    }
                case let .phoneCall(_, discardReason, _):
                    var titleString: String
                    let incoming: Bool
                    if message.flags.contains(.Incoming) {
                        titleString = strings.Notification_CallIncoming
                        incoming = true
                    } else {
                        titleString = strings.Notification_CallOutgoing
                        incoming = false
                    }
                    if let discardReason = discardReason {
                        switch discardReason {
                            case .busy, .disconnect:
                                titleString = strings.Notification_CallCanceled
                            case .missed:
                                titleString = incoming ? strings.Notification_CallMissed : strings.Notification_CallCanceled
                            case .hangup:
                                break
                        }
                    }
                    attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
                case let .customText(text, entities):
                    attributedString = stringWithAppliedEntities(text, entities: entities, baseColor: primaryTextColor, linkColor: primaryTextColor, baseFont: titleFont, linkFont: titleBoldFont, boldFont: titleBoldFont, italicFont: titleFont, fixedFont: titleFont)
                case let .botDomainAccessGranted(domain):
                    attributedString = NSAttributedString(string: strings.AuthSessions_Message(domain).0, font: titleFont, textColor: primaryTextColor)
                case let .botSentSecureValues(types):
                    var typesString = ""
                    var hasIdentity = false
                    var hasAddress = false
                    for type in types {
                        if !typesString.isEmpty {
                            typesString.append(", ")
                        }
                        switch type {
                            case .personalDetails:
                                typesString.append(strings.Notification_PassportValuePersonalDetails)
                            case .passport, .internalPassport, .driversLicense, .idCard:
                                if !hasIdentity {
                                    typesString.append(strings.Notification_PassportValueProofOfIdentity)
                                    hasIdentity = true
                                }
                            case .address:
                                typesString.append(strings.Notification_PassportValueAddress)
                            case .bankStatement, .utilityBill, .rentalAgreement, .passportRegistration, .temporaryRegistration:
                                if !hasAddress {
                                    typesString.append(strings.Notification_PassportValueProofOfAddress)
                                    hasAddress = true
                                }
                            case .phone:
                                typesString.append(strings.Notification_PassportValuePhone)
                            case .email:
                                typesString.append(strings.Notification_PassportValueEmail)
                        }
                    }
                    attributedString = NSAttributedString(string: strings.Notification_PassportValuesSentMessage(message.author?.compactDisplayTitle ?? "", typesString).0, font: titleFont, textColor: primaryTextColor)
                case .unknown:
                    attributedString = nil
            }
            
            break
        } else if let expiredMedia = media as? TelegramMediaExpiredContent {
            switch expiredMedia.data {
                case .image:
                    attributedString = NSAttributedString(string: strings.Message_ImageExpired, font: titleFont, textColor: primaryTextColor)
                case .file:
                    attributedString = NSAttributedString(string: strings.Message_VideoExpired, font: titleFont, textColor: primaryTextColor)
            }
        }
    }
    
    return attributedString
}

class ChatMessageActionBubbleContentNode: ChatMessageBubbleContentNode {
    let labelNode: TextNode
    let filledBackgroundNode: LinkHighlightingNode
    var linkHighlightingNode: LinkHighlightingNode?
    fileprivate var imageNode: TransformImageNode?
    private let fetchDisposable = MetaDisposable()
    
    required init() {
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.displaysAsynchronously = true
        
        self.filledBackgroundNode = LinkHighlightingNode(color: .clear)
        
        super.init()
        
        self.addSubnode(self.filledBackgroundNode)
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
    
    override func transitionNode(messageId: MessageId, media: Media) -> (ASDisplayNode, () -> UIView?)? {
        if let imageNode = self.imageNode, self.item?.message.id == messageId {
            return (imageNode, { [weak imageNode] in
                return imageNode?.view.snapshotContentTree(unhide: true)
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
        return mediaHidden
    }
    
    override func asyncLayoutContent() -> (_ item: ChatMessageBubbleContentItem, _ layoutConstants: ChatMessageItemLayoutConstants, _ preparePosition: ChatMessageBubblePreparePosition, _ messageSelection: Bool?, _ constrainedSize: CGSize) -> (ChatMessageBubbleContentProperties, unboundSize: CGSize?, maxWidth: CGFloat, layout: (CGSize, ChatMessageBubbleContentPosition) -> (CGFloat, (CGFloat) -> (CGSize, (ListViewItemUpdateAnimation) -> Void))) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        
        let backgroundLayout = self.filledBackgroundNode.asyncLayout()
        
        return { item, layoutConstants, _, _, _ in
            let contentProperties = ChatMessageBubbleContentProperties(hidesSimpleAuthorHeader: true, headerSpacing: 0.0, hidesBackground: .always, forceFullCorners: false, forceAlignment: .center)
            
            return (contentProperties, nil, CGFloat.greatestFiniteMagnitude, { constrainedSize, position in
                let attributedString = attributedServiceMessageString(theme: item.presentationData.theme.theme, strings: item.presentationData.strings, message: item.message, accountPeerId: item.account.peerId)
            
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
                
                
               
                let imageSize = CGSize(width: 70.0, height: 70.0)
                
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
            
                
                let backgroundApply = backgroundLayout(item.presentationData.theme.theme.chat.serviceMessage.serviceMessageFillColor, labelRects, 10.0, 10.0, 0.0)
            
                var backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
                let layoutInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
                
                if let _ = image {
                    backgroundSize.height += imageSize.height + 10
                }
                
                return (backgroundSize.width, { boundingWidth in
                    return (backgroundSize, { [weak self] animation in
                        if let strongSelf = self {
                            strongSelf.item = item
                            
                            if let image = image {
                                let imageNode: TransformImageNode
                                if let current = strongSelf.imageNode {
                                    imageNode = current
                                } else {
                                    imageNode = TransformImageNode()
                                    strongSelf.imageNode = imageNode
                                    strongSelf.insertSubnode(imageNode, at: 0)
                                    let arguments = TransformImageArguments(corners: ImageCorners(radius: imageSize.width / 2), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                                    let apply = imageNode.asyncLayout()(arguments)
                                    apply()
                                    
                                }
                                strongSelf.fetchDisposable.set(chatMessagePhotoInteractiveFetched(account: item.account, photoReference: .message(message: MessageReference(item.message), media: image)).start())
                                let updateImageSignal = chatMessagePhoto(postbox: item.account.postbox, photoReference: .message(message: MessageReference(item.message), media: image))

                                imageNode.setSignal(updateImageSignal)
                                
                                imageNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((backgroundSize.width - imageSize.width) / 2.0), y: labelLayout.size.height + 10 + 2), size: imageSize)
                            } else if let imageNode = strongSelf.imageNode {
                                imageNode.removeFromSupernode()
                                strongSelf.imageNode = nil
                            }
                            
                            let _ = apply()
                            let _ = backgroundApply()
                            
                            let labelFrame = CGRect(origin: CGPoint(x: 8.0, y: image != nil ? 2 : floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
                            strongSelf.labelNode.frame = labelFrame
                            strongSelf.filledBackgroundNode.frame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
                        }
                    })
                })
            })
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
                        if let _ = attributes[NSAttributedStringKey(rawValue: name)] {
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
                    linkHighlightingNode = LinkHighlightingNode(color: item.presentationData.theme.theme.chat.serviceMessage.serviceMessageLinkHighlightColor)
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

    override func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.labelNode.frame
        if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)) {
            if let url = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.URL)] as? String {
                var concealed = true
                if let attributeText = self.labelNode.attributeSubstring(name: TelegramTextAttributes.URL, index: index) {
                    concealed = !doesUrlMatchText(url: url, text: attributeText)
                }
                return .url(url: url, concealed: concealed)
            } else if let peerMention = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return .peerMention(peerMention.peerId, peerMention.mention)
            } else if let peerName = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .textMention(peerName)
            } else if let botCommand = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return .botCommand(botCommand)
            } else if let hashtag = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            }
        }
        if let imageNode = imageNode, imageNode.frame.contains(point) {
            return .openMessage
        }
        
        if self.filledBackgroundNode.frame.contains(point.offsetBy(dx: 0.0, dy: -10.0)) {
            return .openMessage
        } else {
            return .none
        }
    }
}
