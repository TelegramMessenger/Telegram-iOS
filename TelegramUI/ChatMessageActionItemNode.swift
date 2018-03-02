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
                        attributedString = addAttributesToStringWithRanges(strings.Notification_JoinedChat(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, peerId)]))
                    } else {
                        var attributePeerIds: [(Int, PeerId?)] = [(0, message.author?.id)]
                        if peerIds.count == 1 {
                            attributePeerIds.append((1, peerIds.first))
                        }
                        attributedString = addAttributesToStringWithRanges(strings.Notification_Invited(authorName, peerDisplayTitles(peerIds, message.peers)), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: attributePeerIds))
                    }
                case let .removedMembers(peerIds):
                    if peerIds.first == message.author?.id {
                        attributedString = addAttributesToStringWithRanges(strings.Notification_LeftChat(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
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
                                        case let .Audio(isVoice, _, performer, title, _):
                                            if isVoice {
                                                type = .audio
                                            } else {
                                                let descriptionString: String
                                                if let title = title, let performer = performer, !title.isEmpty, !performer.isEmpty {
                                                    descriptionString = title + " — " + performer
                                                } else if let title = title, !title.isEmpty {
                                                    descriptionString = title
                                                } else if let performer = performer, !performer.isEmpty {
                                                    descriptionString = performer
                                                } else if let fileName = file.fileName {
                                                    descriptionString = fileName
                                                } else {
                                                    descriptionString = strings.Message_Audio
                                                }
                                                type = .text(descriptionString)
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
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedTextMessage(authorName, clippedText), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
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
                            attributedString = addAttributesToStringWithRanges(strings.Notification_PinnedDeletedMessage(authorName), body: bodyAttributes, argumentAttributes: peerMentionsAttributes(primaryTextColor: primaryTextColor, peerIds: [(0, message.author?.id)]))
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
                    attributedString = NSAttributedString(string: strings.Notification_SecretChatScreenshot, font: titleFont, textColor: primaryTextColor)
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
                    if message.flags.contains(.Incoming) {
                        titleString = strings.Notification_CallIncoming
                    } else {
                        titleString = strings.Notification_CallOutgoing
                    }
                    if let discardReason = discardReason {
                        switch discardReason {
                            case .busy, .disconnect:
                                titleString = strings.Notification_CallCanceled
                            case .missed:
                                titleString = strings.Notification_CallMissed
                            case .hangup:
                                break
                        }
                    }
                    attributedString = NSAttributedString(string: titleString, font: titleFont, textColor: primaryTextColor)
                case let .customText(text, entities):
                    attributedString = stringWithAppliedEntities(text, entities: entities, baseColor: primaryTextColor, linkColor: primaryTextColor, baseFont: titleFont, linkFont: titleBoldFont, boldFont: titleBoldFont, italicFont: titleFont, fixedFont: titleFont)
                case let .botDomainAccessGranted(domain):
                    attributedString = NSAttributedString(string: "Granted access to \(domain)", font: titleFont, textColor: primaryTextColor)
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

class ChatMessageActionItemNode: ChatMessageItemView {
    let labelNode: TextNode
    let filledBackgroundNode: LinkHighlightingNode
    var linkHighlightingNode: LinkHighlightingNode?
    
    private let fetchDisposable = MetaDisposable()
    
    private var appliedItem: ChatMessageItem?
    
    required init() {
        self.labelNode = TextNode()
        self.labelNode.isLayerBacked = true
        self.labelNode.displaysAsynchronously = true
        
        self.filledBackgroundNode = LinkHighlightingNode(color: .clear)
        
        super.init(layerBacked: false)
        
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
        
        let recognizer = TapLongTapOrDoubleTapGestureRecognizer(target: self, action: #selector(self.tapLongTapOrDoubleTapGesture(_:)))
        recognizer.tapActionAtPoint = { _ in
            return .waitForSingleTap
        }
        recognizer.highlight = { [weak self] point in
            if let strongSelf = self {
                strongSelf.updateTouchesAtPoint(point)
            }
        }
        self.view.addGestureRecognizer(recognizer)
    }
    
    override func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: Bool) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation) -> Void) {
        let makeLabelLayout = TextNode.asyncLayout(self.labelNode)
        let layoutConstants = self.layoutConstants
        
        let backgroundLayout = self.filledBackgroundNode.asyncLayout()
        
        return { item, params, mergedTop, mergedBottom, dateHeaderAtBottom in
            let attributedString = attributedServiceMessageString(theme: item.presentationData.theme, strings: item.presentationData.strings, message: item.message, accountPeerId: item.account.peerId)
            
            let (labelLayout, apply) = makeLabelLayout(TextNodeLayoutArguments(attributedString: attributedString, backgroundColor: nil, maximumNumberOfLines: 0, truncationType: .end, constrainedSize: CGSize(width: params.width - params.leftInset - params.rightInset - 32.0, height: CGFloat.greatestFiniteMagnitude), alignment: .center, cutout: nil, insets: UIEdgeInsets()))
            
            var labelRects = labelLayout.linesRects()
            if labelRects.count > 1 {
                let sortedIndices = (0 ..< labelRects.count).sorted(by: { labelRects[$0].width > labelRects[$1].width })
                for i in 0 ..< sortedIndices.count {
                    let index = sortedIndices[i]
                    for j in -1 ... 1 {
                        if j != 0 && index + j >= 0 && index + j < sortedIndices.count {
                            if abs(labelRects[index + j].width - labelRects[index].width) < 40.0 {
                                labelRects[index + j].size.width = max(labelRects[index + j].width, labelRects[index].width)
                            }
                        }
                    }
                }
            }
            for i in 0 ..< labelRects.count {
                /*if i != 0 && i != labelRects.count - 1 {
                    if labelRects[i - 1].width > labelRects[i].width && labelRects[i + 1].width > labelRects[i].width {
                        if abs(labelRects[i - 1].width - labelRects[i].width) < abs(labelRects[i + 1].width - labelRects[i].width) {
                            labelRects[i].size.width = labelRects[i - 1].width
                        } else {
                            labelRects[i].size.width = labelRects[i + 1].width
                        }
                    }
                }*/
                
                labelRects[i] = labelRects[i].insetBy(dx: -6.0, dy: floor((labelRects[i].height - 20.0) / 2.0))
                labelRects[i].size.height = 20.0
                labelRects[i].origin.x = floor((labelLayout.size.width - labelRects[i].width) / 2.0)
            }
            
            let backgroundApply = backgroundLayout(item.presentationData.theme.chat.serviceMessage.serviceMessageFillColor, labelRects, 10.0, 10.0, 0.0)
            
            let backgroundSize = CGSize(width: labelLayout.size.width + 8.0 + 8.0, height: labelLayout.size.height + 4.0)
            var layoutInsets = UIEdgeInsets(top: 4.0, left: 0.0, bottom: 4.0, right: 0.0)
            if dateHeaderAtBottom {
                layoutInsets.top += layoutConstants.timestampHeaderHeight
            }
            
            return (ListViewItemNodeLayout(contentSize: CGSize(width: params.width, height: labelLayout.size.height + 4.0), insets: layoutInsets), { [weak self] animation in
                if let strongSelf = self {
                    strongSelf.appliedItem = item
                    
                    let _ = apply()
                    let _ = backgroundApply()
                    
                    let labelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((params.width - labelLayout.size.width) / 2.0), y: floorToScreenPixels((backgroundSize.height - labelLayout.size.height) / 2.0) - 1.0), size: labelLayout.size)
                    strongSelf.labelNode.frame = labelFrame
                    strongSelf.filledBackgroundNode.frame = labelFrame.offsetBy(dx: 0.0, dy: -11.0)
                }
            })
        }
    }
    
    override func animateInsertion(_ currentTimestamp: Double, duration: Double, short: Bool) {
        super.animateInsertion(currentTimestamp, duration: duration, short: short)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateAdded(_ currentTimestamp: Double, duration: Double) {
        super.animateAdded(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    override func animateRemoved(_ currentTimestamp: Double, duration: Double) {
        super.animateRemoved(currentTimestamp, duration: duration)
        
        self.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    @objc func tapLongTapOrDoubleTapGesture(_ recognizer: TapLongTapOrDoubleTapGestureRecognizer) {
        switch recognizer.state {
            case .began:
                break
            case .ended:
                if let (gesture, location) = recognizer.lastRecognizedGestureAndLocation {
                    switch gesture {
                        case .tap:
                            var foundTapAction = false
                            let tapAction = self.tapActionAtPoint(location)
                            switch tapAction {
                                case .none, .ignore:
                                    break
                                case let .url(url):
                                    foundTapAction = true
                                    self.item?.controllerInteraction.openUrl(url)
                                case let .peerMention(peerId, _):
                                    foundTapAction = true
                                    self.item?.controllerInteraction.openPeer(peerId, .info, nil)
                                case let .textMention(name):
                                    foundTapAction = true
                                    self.item?.controllerInteraction.openPeerMention(name)
                                case let .botCommand(command):
                                    foundTapAction = true
                                    if let item = self.item {
                                        item.controllerInteraction.sendBotCommand(item.message.id, command)
                                    }
                                case let .hashtag(peerName, hashtag):
                                    foundTapAction = true
                                    self.item?.controllerInteraction.openHashtag(peerName, hashtag)
                                case .instantPage:
                                    foundTapAction = true
                                    if let item = self.item {
                                        item.controllerInteraction.openInstantPage(item.message)
                                    }
                                case .holdToPreviewSecretMedia:
                                    foundTapAction = true
                                case let .call(peerId):
                                    foundTapAction = true
                                    self.item?.controllerInteraction.callPeer(peerId)
                            }
                            if !foundTapAction {
                                if let item = self.item {
                                    for attribute in item.message.attributes {
                                        if let attribute = attribute as? ReplyMessageAttribute {
                                            item.controllerInteraction.navigateToMessage(item.message.id, attribute.messageId)
                                            foundTapAction = true
                                            break
                                        }
                                    }
                                }
                            }
                            if !foundTapAction {
                                self.item?.controllerInteraction.clickThroughMessage()
                            }
                        case .longTap, .doubleTap:
                            if let item = self.item, self.labelNode.frame.contains(location) {
                                var foundTapAction = false
                                let tapAction = self.tapActionAtPoint(location)
                                switch tapAction {
                                    case .none, .ignore:
                                        break
                                    case let .url(url):
                                        foundTapAction = true
                                        item.controllerInteraction.longTap(.url(url))
                                    case let .peerMention(peerId, mention):
                                        foundTapAction = true
                                        item.controllerInteraction.longTap(.peerMention(peerId, mention))
                                    case let .textMention(name):
                                        foundTapAction = true
                                        item.controllerInteraction.longTap(.mention(name))
                                    case let .botCommand(command):
                                        foundTapAction = true
                                        item.controllerInteraction.longTap(.command(command))
                                    case let .hashtag(_, hashtag):
                                        foundTapAction = true
                                        item.controllerInteraction.longTap(.hashtag(hashtag))
                                    case .instantPage:
                                        break
                                    case .holdToPreviewSecretMedia:
                                        break
                                    case .call:
                                        break
                                }
                                
                                if !foundTapAction {
                                    item.controllerInteraction.openMessageContextMenu(item.message, self, self.filledBackgroundNode.frame)
                                }
                            }
                        case .hold:
                            break
                    }
                }
            case .cancelled:
                break
            default:
                break
        }
    }
    
    private func updateTouchesAtPoint(_ point: CGPoint?) {
        if let item = self.item {
            var rects: [(CGRect, CGRect)]?
            let textNodeFrame = self.labelNode.frame
            if let point = point {
                if let (index, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)) {
                    let possibleNames: [String] = [
                        TelegramTextAttributes.Url,
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
                    linkHighlightingNode = LinkHighlightingNode(color: item.presentationData.theme.chat.serviceMessage.serviceMessageLinkHighlightColor)
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

    private func tapActionAtPoint(_ point: CGPoint) -> ChatMessageBubbleContentTapAction {
        let textNodeFrame = self.labelNode.frame
        if let (_, attributes) = self.labelNode.attributesAtPoint(CGPoint(x: point.x - textNodeFrame.minX, y: point.y - textNodeFrame.minY - 10.0)) {
            if let url = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.Url)] as? String {
                return .url(url)
            } else if let peerMention = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerMention)] as? TelegramPeerMention {
                return .peerMention(peerMention.peerId, peerMention.mention)
            } else if let peerName = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.PeerTextMention)] as? String {
                return .textMention(peerName)
            } else if let botCommand = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.BotCommand)] as? String {
                return .botCommand(botCommand)
            } else if let hashtag = attributes[NSAttributedStringKey(rawValue: TelegramTextAttributes.Hashtag)] as? TelegramHashtag {
                return .hashtag(hashtag.peerName, hashtag.hashtag)
            } else {
                return .none
            }
        } else {
            return .none
        }
    }
}
