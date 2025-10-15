import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import AccountContext
import LocalizedPeerData
import ContextUI
import ChatListUI
import TelegramPresentationData
import SwiftSignalKit
import ChatControllerInteraction
import ChatMessageItemCommon
import TextFormat
import ChatMessageItem
import ChatMessageTransitionNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode
import LottieMetal

public func chatMessageItemLayoutConstants(_ constants: (ChatMessageItemLayoutConstants, ChatMessageItemLayoutConstants), params: ListViewItemLayoutParams, presentationData: ChatPresentationData) -> ChatMessageItemLayoutConstants {
    var result: ChatMessageItemLayoutConstants
    if params.width > 680.0 {
        result = constants.1
    } else {
        result = constants.0
    }
    result.image.defaultCornerRadius = presentationData.chatBubbleCorners.mainRadius
    result.image.mergedCornerRadius = (presentationData.chatBubbleCorners.mergeBubbleCorners && result.image.defaultCornerRadius >= 10.0) ?  presentationData.chatBubbleCorners.auxiliaryRadius : presentationData.chatBubbleCorners.mainRadius
    let minRadius: CGFloat = 4.0
    let maxRadius: CGFloat = 16.0
    let radiusTransition = (presentationData.chatBubbleCorners.mainRadius - minRadius) / (maxRadius - minRadius)
    let minInset: CGFloat = result.text.bubbleInsets.left
    let maxInset: CGFloat = 11.0
    let textInset: CGFloat = min(maxInset, ceil(maxInset * radiusTransition + minInset * (1.0 - radiusTransition)))
    result.text.bubbleInsets.left = textInset
    result.text.bubbleInsets.right = textInset
    result.instantVideo.dimensions = params.width > 320.0 ? constants.1.instantVideo.dimensions : constants.0.instantVideo.dimensions
    return result
}

public enum ChatMessageItemBottomNeighbor {
    case none
    case merged(semi: Bool)
}

private let voiceMessageDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .spellOut
    formatter.allowedUnits = [.minute, .second]
    return formatter
}()

private let musicDurationFormatter: DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.unitsStyle = .spellOut
    formatter.allowedUnits = [.hour, .minute, .second]
    return formatter
}()

private let fileSizeFormatter: ByteCountFormatter = {
    let formatter = ByteCountFormatter()
    formatter.allowsNonnumericFormatting = true
    return formatter
}()

public enum ChatMessageAccessibilityCustomActionType {
    case reply
    case options
}

public final class ChatMessageAccessibilityCustomAction: UIAccessibilityCustomAction {
    public let action: ChatMessageAccessibilityCustomActionType
    
    public init(name: String, target: Any?, selector: Selector, action: ChatMessageAccessibilityCustomActionType) {
        self.action = action
        
        super.init(name: name, target: target, selector: selector)
    }
}

public final class ChatMessageAccessibilityData {
    public let label: String?
    public let value: String?
    public let hint: String?
    public let traits: UIAccessibilityTraits
    public let customActions: [ChatMessageAccessibilityCustomAction]?
    public let singleUrl: String?
    
    public init(item: ChatMessageItem, isSelected: Bool?) {
        var hint: String?
        var traits: UIAccessibilityTraits = []
        var singleUrl: String?
        
        var customActions: [ChatMessageAccessibilityCustomAction] = []
        
        let isIncoming = item.message.effectivelyIncoming(item.context.account.peerId)
        var announceIncomingAuthors = false
        if let peer = item.message.peers[item.message.id.peerId] {
            if peer is TelegramGroup {
                announceIncomingAuthors = true
            } else if let channel = peer as? TelegramChannel, case .group = channel.info {
                announceIncomingAuthors = true
            }
        }
        
        let dataForMessage: (Message, Bool) -> (String, String) = { message, isReply -> (String, String) in
            var label: String = ""
            var value: String = ""
            
            if let chatPeer = message.peers[item.message.id.peerId] {
                let authorName = message.author.flatMap(EnginePeer.init)?.displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                
                let (_, _, messageText, _, _) = chatListItemStrings(strings: item.presentationData.strings, nameDisplayOrder: item.presentationData.nameDisplayOrder, dateTimeFormat: item.presentationData.dateTimeFormat, contentSettings: item.context.currentContentSettings.with { $0 }, messages: [EngineMessage(message)], chatPeer: EngineRenderedPeer(peer: EnginePeer(chatPeer)), accountPeerId: item.context.account.peerId)
                
                var text = messageText
                
                loop: for media in message.media {
                    if let _ = media as? TelegramMediaImage {
                        traits.insert(.image)
                        if isIncoming {
                            if announceIncomingAuthors, let authorName = authorName {
                                label = item.presentationData.strings.VoiceOver_Chat_PhotoFrom(authorName).string
                            } else {
                                label = item.presentationData.strings.VoiceOver_Chat_Photo
                            }
                        } else {
                            label = item.presentationData.strings.VoiceOver_Chat_YourPhoto
                        }
                        text = ""
                        if !message.text.isEmpty {
                            text.append("\n")
                            
                            text.append(item.presentationData.strings.VoiceOver_Chat_Caption(message.text).string)
                        }
                    } else if let file = media as? TelegramMediaFile {
                        var isSpecialFile = false
                        
                        let isVideo = file.isInstantVideo
                        
                        for attribute in file.attributes {
                            switch attribute {
                                case let .Sticker(displayText, _, _):
                                    isSpecialFile = true
                                    text = displayText
                                    if file.mimeType == "application/x-tgsticker" {
                                        if isIncoming {
                                            if announceIncomingAuthors, let authorName = authorName {
                                                label = item.presentationData.strings.VoiceOver_Chat_AnimatedStickerFrom(authorName).string
                                            } else {
                                                label = item.presentationData.strings.VoiceOver_Chat_AnimatedSticker
                                            }
                                        } else {
                                            label = item.presentationData.strings.VoiceOver_Chat_YourAnimatedSticker
                                        }
                                    } else {
                                        if isIncoming {
                                            if announceIncomingAuthors, let authorName = authorName {
                                                label = item.presentationData.strings.VoiceOver_Chat_StickerFrom(authorName).string
                                            } else {
                                                label = item.presentationData.strings.VoiceOver_Chat_Sticker
                                            }
                                        } else {
                                            label = item.presentationData.strings.VoiceOver_Chat_YourSticker
                                        }
                                    }
                                case let .Audio(isVoice, duration, title, performer, _):
                                    if isVideo {
                                        continue
                                    }
                                    isSpecialFile = true
                                    if isSelected == nil {
                                        hint = item.presentationData.strings.VoiceOver_Chat_PlayHint
                                    }
                                    traits.insert(.startsMediaSession)
                                    if isVoice {
                                        let durationString = voiceMessageDurationFormatter.string(from: Double(duration)) ?? ""
                                        if isIncoming {
                                            if announceIncomingAuthors, let authorName = authorName {
                                                label = item.presentationData.strings.VoiceOver_Chat_VoiceMessageFrom(authorName).string
                                            } else {
                                                label = item.presentationData.strings.VoiceOver_Chat_VoiceMessage
                                            }
                                        } else {
                                            label = item.presentationData.strings.VoiceOver_Chat_YourVoiceMessage
                                        }
                                        text = item.presentationData.strings.VoiceOver_Chat_Duration(durationString).string
                                    } else {
                                        let durationString = musicDurationFormatter.string(from: Double(duration)) ?? ""
                                        if isIncoming {
                                            if announceIncomingAuthors, let authorName = authorName {
                                                label = item.presentationData.strings.VoiceOver_Chat_MusicFrom(authorName).string
                                            } else {
                                                label = item.presentationData.strings.VoiceOver_Chat_Music
                                            }
                                        } else {
                                            label = item.presentationData.strings.VoiceOver_Chat_YourMusic
                                        }
                                        let performer = performer ?? "Unknown"
                                        let title = title ?? "Unknown"
                                        
                                        text = item.presentationData.strings.VoiceOver_Chat_MusicTitle(title, performer).string
                                        text.append(item.presentationData.strings.VoiceOver_Chat_Duration(durationString).string)
                                    }
                                case let .Video(duration, _, flags, _, _, _):
                                    isSpecialFile = true
                                    if isSelected == nil {
                                        hint = item.presentationData.strings.VoiceOver_Chat_PlayHint
                                    }
                                    traits.insert(.startsMediaSession)
                                    let durationString = voiceMessageDurationFormatter.string(from: Double(duration)) ?? ""
                                    if flags.contains(.instantRoundVideo) {
                                        if isIncoming {
                                            if announceIncomingAuthors, let authorName = authorName {
                                                label = item.presentationData.strings.VoiceOver_Chat_VideoMessageFrom(authorName).string
                                            } else {
                                                label = item.presentationData.strings.VoiceOver_Chat_VideoMessage
                                            }
                                        } else {
                                            label = item.presentationData.strings.VoiceOver_Chat_YourVideoMessage
                                        }
                                    } else {
                                        if isIncoming {
                                            if announceIncomingAuthors, let authorName = authorName {
                                                label = item.presentationData.strings.VoiceOver_Chat_VideoFrom(authorName).string
                                            } else {
                                                label = item.presentationData.strings.VoiceOver_Chat_Video
                                            }
                                        } else {
                                            label = item.presentationData.strings.VoiceOver_Chat_YourVideo
                                        }
                                    }
                                    text = item.presentationData.strings.VoiceOver_Chat_Duration(durationString).string
                                default:
                                    break
                            }
                        }
                        if !isSpecialFile {
                            if isSelected == nil {
                                hint = item.presentationData.strings.VoiceOver_Chat_OpenHint
                            }
                            let sizeString = fileSizeFormatter.string(fromByteCount: Int64(file.size ?? 0))
                            if isIncoming {
                                if announceIncomingAuthors, let authorName = authorName {
                                    label = item.presentationData.strings.VoiceOver_Chat_FileFrom(authorName).string
                                } else {
                                    label = item.presentationData.strings.VoiceOver_Chat_File
                                }
                            } else {
                                label = item.presentationData.strings.VoiceOver_Chat_YourFile
                            }
                            text = "\(file.fileName ?? ""). "
                            text.append(item.presentationData.strings.VoiceOver_Chat_Size(sizeString).string)
                        }
                        if !message.text.isEmpty {
                            text.append("\n")
                            text.append(item.presentationData.strings.VoiceOver_Chat_Caption(message.text).string)
                        }
                        break loop
                    } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                        var contentText = item.presentationData.strings.VoiceOver_Chat_PagePreview + ". "
                        if let title = content.title, !title.isEmpty {
                            contentText.append(item.presentationData.strings.VoiceOver_Chat_Title(title).string)
                            contentText.append(". ")
                        }
                        if let text = content.text, !text.isEmpty {
                            contentText.append(text)
                        }
                        text = "\(message.text)\n\(contentText)"
                    } else if let contact = media as? TelegramMediaContact {
                        if isIncoming {
                            if announceIncomingAuthors, let authorName = authorName {
                                label = item.presentationData.strings.VoiceOver_Chat_ContactFrom(authorName).string
                            } else {
                                label = item.presentationData.strings.VoiceOver_Chat_Contact
                            }
                        } else {
                            label = item.presentationData.strings.VoiceOver_Chat_YourContact
                        }
                        var displayName = ""
                        if !contact.firstName.isEmpty {
                            displayName.append(contact.firstName)
                        }
                        if !contact.lastName.isEmpty {
                            if !displayName.isEmpty {
                                displayName.append(" ")
                            }
                            displayName.append(contact.lastName)
                        }
                        var phoneNumbersString = ""
                        var phoneNumberCount = 0
                        var emailAddressesString = ""
                        var emailAddressCount = 0
                        var organizationString = ""
                        if let vCard = contact.vCardData, let vCardData = vCard.data(using: .utf8), let contactData = DeviceContactExtendedData(vcard: vCardData) {
                            if displayName.isEmpty && !contactData.organization.isEmpty {
                                displayName = contactData.organization
                            }
                            if !contactData.basicData.phoneNumbers.isEmpty {
                                for phone in contactData.basicData.phoneNumbers {
                                    if !phoneNumbersString.isEmpty {
                                        phoneNumbersString.append(", ")
                                    }
                                    for c in phone.value {
                                        phoneNumbersString.append(c)
                                        phoneNumbersString.append(" ")
                                    }
                                    phoneNumberCount += 1
                                }
                            } else {
                                for c in contact.phoneNumber {
                                    phoneNumbersString.append(c)
                                    phoneNumbersString.append(" ")
                                }
                                phoneNumberCount += 1
                            }
                            
                            for email in contactData.emailAddresses {
                                if !emailAddressesString.isEmpty {
                                    emailAddressesString.append(", ")
                                }
                                emailAddressesString.append("\(email.value)")
                                emailAddressCount += 1
                            }
                            if !contactData.organization.isEmpty && displayName != contactData.organization {
                                organizationString = contactData.organization
                            }
                        } else {
                            phoneNumbersString.append("\(contact.phoneNumber)")
                        }
                        text = "\(displayName)."
                        if !phoneNumbersString.isEmpty {
                            if phoneNumberCount > 1 {
                                text.append(item.presentationData.strings.VoiceOver_Chat_ContactPhoneNumberCount(Int32(phoneNumberCount)))
                                text.append(": ")
                            } else {
                                text.append(item.presentationData.strings.VoiceOver_Chat_ContactPhoneNumber)
                            }
                            text.append("\(phoneNumbersString). ")
                        }
                        if !emailAddressesString.isEmpty {
                            if emailAddressCount > 1 {
                                text.append(item.presentationData.strings.VoiceOver_Chat_ContactEmailCount(Int32(emailAddressCount)))
                                text.append(": ")
                            } else {
                                text.append(item.presentationData.strings.VoiceOver_Chat_ContactEmail)
                                text.append(": ")
                            }
                            text.append("\(emailAddressesString). ")
                        }
                        if !organizationString.isEmpty {
                            text.append(item.presentationData.strings.VoiceOver_Chat_ContactOrganization(organizationString).string)
                            text.append(".")
                        }
                    } else if let poll = media as? TelegramMediaPoll {
                        if isIncoming {
                            if announceIncomingAuthors, let authorName = authorName {
                                label = item.presentationData.strings.VoiceOver_Chat_AnonymousPollFrom(authorName).string
                            } else {
                                label = item.presentationData.strings.VoiceOver_Chat_AnonymousPoll
                            }
                        } else {
                            label = item.presentationData.strings.VoiceOver_Chat_YourAnonymousPoll
                        }
                        
                        var optionVoterCount: [Int: Int32] = [:]
                        var maxOptionVoterCount: Int32 = 0
                        var totalVoterCount: Int32 = 0
                        let voters: [TelegramMediaPollOptionVoters]?
                        if poll.isClosed {
                            voters = poll.results.voters ?? []
                        } else {
                            voters = poll.results.voters
                        }
                        var selectedOptionId: Data?
                        if let voters = voters, let totalVoters = poll.results.totalVoters {
                            var didVote = false
                            for voter in voters {
                                if voter.selected {
                                    didVote = true
                                    selectedOptionId = voter.opaqueIdentifier
                                }
                            }
                            totalVoterCount = totalVoters
                            if didVote || poll.isClosed {
                                for i in 0 ..< poll.options.count {
                                    inner: for optionVoters in voters {
                                        if optionVoters.opaqueIdentifier == poll.options[i].opaqueIdentifier {
                                            optionVoterCount[i] = optionVoters.count
                                            maxOptionVoterCount = max(maxOptionVoterCount, optionVoters.count)
                                            break inner
                                        }
                                    }
                                }
                            }
                        }
                        
                        var optionVoterCounts: [Int]
                        if totalVoterCount != 0 {
                            optionVoterCounts = countNicePercent(votes: (0 ..< poll.options.count).map({ Int(optionVoterCount[$0] ?? 0) }), total: Int(totalVoterCount))
                        } else {
                            optionVoterCounts = Array(repeating: 0, count: poll.options.count)
                        }
                        
                        text = item.presentationData.strings.VoiceOver_Chat_Title(poll.text).string
                        text.append(". ")
                        
                        text.append(item.presentationData.strings.VoiceOver_Chat_PollOptionCount(Int32(poll.options.count)))
                        text.append(": ")
                        var optionsText = ""
                        for i in 0 ..< poll.options.count {
                            let option = poll.options[i]
                            
                            if !optionsText.isEmpty {
                                optionsText.append(", ")
                            }
                            optionsText.append(option.text)
                            if let selectedOptionId = selectedOptionId, selectedOptionId == option.opaqueIdentifier {
                                optionsText.append(", ")
                                optionsText.append(item.presentationData.strings.VoiceOver_Chat_OptionSelected)
                            }
                            
                            if let _ = optionVoterCount[i] {
                                if maxOptionVoterCount != 0 && totalVoterCount != 0 {
                                    optionsText.append(", \(optionVoterCounts[i])%")
                                }
                            }
                        }
                        text.append("\(optionsText). ")
                        if totalVoterCount != 0 {
                            text.append(item.presentationData.strings.VoiceOver_Chat_PollVotes(Int32(totalVoterCount)))
                        } else {
                            text.append(item.presentationData.strings.VoiceOver_Chat_PollNoVotes)
                        }
                        if poll.isClosed {
                            text.append(item.presentationData.strings.VoiceOver_Chat_PollFinalResults)
                        }
                    }
                }
                
                var result = ""
                
                if let isSelected = isSelected {
                    if isSelected {
                        result += item.presentationData.strings.VoiceOver_Chat_Selected
                        result += "\n"
                    }
                    traits.insert(.startsMediaSession)
                }
                
                result += "\(text)"
                
                let dateString = DateFormatter.localizedString(from: Date(timeIntervalSince1970: Double(message.timestamp)), dateStyle: .medium, timeStyle: .short)
                
                result += "\n\(dateString)"
                if !isIncoming && !isReply {
                    result += "\n"
                    if item.sending {
                        result += item.presentationData.strings.VoiceOver_Chat_Sending
                    } else if item.failed {
                        result += item.presentationData.strings.VoiceOver_Chat_Failed
                    } else {
                        if item.read {
                            if announceIncomingAuthors {
                                result += item.presentationData.strings.VoiceOver_Chat_SeenByRecipients
                            } else {
                                result += item.presentationData.strings.VoiceOver_Chat_SeenByRecipient
                            }
                        }
                        for attribute in message.attributes {
                            if let attribute = attribute as? ConsumableContentMessageAttribute {
                                if !attribute.consumed {
                                    if announceIncomingAuthors {
                                        result += item.presentationData.strings.VoiceOver_Chat_NotPlayedByRecipients
                                    } else {
                                        result += item.presentationData.strings.VoiceOver_Chat_NotPlayedByRecipient
                                    }
                                } else {
                                    if announceIncomingAuthors {
                                        result += item.presentationData.strings.VoiceOver_Chat_PlayedByRecipients
                                    } else {
                                        result += item.presentationData.strings.VoiceOver_Chat_PlayedByRecipient
                                    }
                                }
                            }
                        }
                    }
                }
                value = result
            } else {
                value = ""
            }
            
            if label.isEmpty {
                if let author = message.author {
                    if isIncoming {
                        label = EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    } else {
                        label = item.presentationData.strings.VoiceOver_Chat_YourMessage
                    }
                } else {
                    label = item.presentationData.strings.VoiceOver_Chat_Message
                }
            }
            
            return (label, value)
        }
        
        var (label, value) = dataForMessage(item.message, false)
        var replyValue: String?
        
        for attribute in item.message.attributes {
            if let attribute = attribute as? TextEntitiesMessageAttribute {
                var hasUrls = false
                loop: for entity in attribute.entities {
                    switch entity.type {
                        case .Url:
                            if hasUrls {
                                singleUrl = nil
                                break loop
                            } else {
                                if let range = Range<String.Index>(NSRange(location: entity.range.lowerBound, length: entity.range.count), in: item.message.text) {
                                    singleUrl = String(item.message.text[range])
                                    hasUrls = true
                                }
                            }
                        case let .TextUrl(url):
                            if hasUrls {
                                singleUrl = nil
                                break loop
                            } else {
                                singleUrl = url
                                hasUrls = true
                            }
                        default:
                            break
                    }
                }
            } else if let attribute = attribute as? ReplyMessageAttribute, let replyMessage = item.message.associatedMessages[attribute.messageId] {
                var replyLabel: String
                if replyMessage.flags.contains(.Incoming) {
                    if let author = replyMessage.author {
                        replyLabel = item.presentationData.strings.VoiceOver_Chat_ReplyFrom(EnginePeer(author).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)).string
                    } else {
                        replyLabel = item.presentationData.strings.VoiceOver_Chat_Reply
                    }
                } else {
                    replyLabel = item.presentationData.strings.VoiceOver_Chat_ReplyToYourMessage
                }
                
                let (_, replyMessageValue) = dataForMessage(replyMessage, true)
                replyValue = replyMessageValue
                
                label = "\(replyLabel) . \(label)"
            }
        }
        
        if hint == nil && singleUrl != nil {
            hint = item.presentationData.strings.VoiceOver_Chat_OpenLinkHint
        }
        
        if let forwardInfo = item.message.forwardInfo {
            let forwardLabel: String
            if let author = forwardInfo.author, author.id == item.context.account.peerId {
                forwardLabel = item.presentationData.strings.VoiceOver_Chat_ForwardedFromYou
            } else {
                let peerString: String
                if let peer = forwardInfo.author {
                    if let authorName = forwardInfo.authorSignature {
                        peerString = "\(EnginePeer(peer).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)) (\(authorName))"
                    } else {
                        peerString = EnginePeer(peer).displayTitle(strings: item.presentationData.strings, displayOrder: item.presentationData.nameDisplayOrder)
                    }
                } else if let authorName = forwardInfo.authorSignature {
                    peerString = authorName
                } else {
                    peerString = ""
                }
                forwardLabel = item.presentationData.strings.VoiceOver_Chat_ForwardedFrom(peerString).string
            }
            label = "\(forwardLabel). \(label)"
        }
        
        if isSelected == nil {
            var canReply = item.controllerInteraction.canSetupReply(item.message) == .reply
            for media in item.content.firstMessage.media {
                if let _ = media as? TelegramMediaExpiredContent {
                    canReply = false
                }
                else if let media = media as? TelegramMediaAction {
                    if case .phoneCall = media.action {
                    } else if case .conferenceCall = media.action {
                    } else {
                        canReply = false
                    }
                }
            }
            
            if canReply {
                customActions.append(ChatMessageAccessibilityCustomAction(name: item.presentationData.strings.VoiceOver_MessageContextReply, target: nil, selector: #selector(self.noop), action: .reply))
            }
            customActions.append(ChatMessageAccessibilityCustomAction(name: item.presentationData.strings.VoiceOver_MessageContextOpenMessageMenu, target: nil, selector: #selector(self.noop), action: .options))
        }
        
        if let replyValue {
            value = "\(value). \(item.presentationData.strings.VoiceOver_Chat_ReplyingToMessage(replyValue).string)"
        }
        
        self.label = label
        self.value = value
        self.hint = hint
        self.traits = traits
        self.customActions = customActions.isEmpty ? nil : customActions
        self.singleUrl = singleUrl
    }
    
    @objc private func noop() {
    }
}

public enum InternalBubbleTapAction {
    public struct Action {
        public var action: () -> Void
        public var contextMenuOnLongPress: Bool
        
        public init(_ action: @escaping () -> Void, contextMenuOnLongPress: Bool = false) {
            self.action = action
            self.contextMenuOnLongPress = contextMenuOnLongPress
        }
    }
    
    public struct OpenContextMenu {
        public var tapMessage: Message
        public var selectAll: Bool
        public var subFrame: CGRect
        public var disableDefaultPressAnimation: Bool
        
        public init(tapMessage: Message, selectAll: Bool, subFrame: CGRect, disableDefaultPressAnimation: Bool = false) {
            self.tapMessage = tapMessage
            self.selectAll = selectAll
            self.subFrame = subFrame
            self.disableDefaultPressAnimation = disableDefaultPressAnimation
        }
    }
    
    case action(Action)
    case optionalAction(() -> Void)
    case openContextMenu(OpenContextMenu)
}

open class ChatMessageItemView: ListViewItemNode, ChatMessageItemNodeProtocol {
    public let layoutConstants = (ChatMessageItemLayoutConstants.compact, ChatMessageItemLayoutConstants.regular)
    
    open var item: ChatMessageItem?
    open var accessibilityData: ChatMessageAccessibilityData?
    open var safeInsets = UIEdgeInsets()
    
    open var awaitingAppliedReaction: (MessageReaction.Reaction?, () -> Void)?
    
    private var fetchEffectDisposable: Disposable?
    
    public var playedEffectAnimation: Bool = false
    public var effectAnimationNodes: [ChatMessageTransitionNode.DecorationItemNode] = []
    
    public required init(rotated: Bool) {
        super.init(layerBacked: false, dynamicBounce: true, rotated: rotated)
        if rotated {
            self.transform = CATransform3DMakeRotation(CGFloat.pi, 0.0, 0.0, 1.0)
        }
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.fetchEffectDisposable?.dispose()
    }
    
    override open func reuse() {
        super.reuse()
        
        self.item = nil
        self.frame = CGRect()
    }
    
    open func setupItem(_ item: ChatMessageItem, synchronousLoad: Bool) {
        self.item = item
    }
    
    open func updateAccessibilityData(_ accessibilityData: ChatMessageAccessibilityData) {
        self.accessibilityData = accessibilityData
    }
    
    override open func layoutForParams(_ params: ListViewItemLayoutParams, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        if let item = item as? ChatMessageItem {
            let doLayout = self.asyncLayout()
            let merged = item.mergedWithItems(top: previousItem, bottom: nextItem, isRotated: item.controllerInteraction.chatIsRotated)
            let (layout, apply) = doLayout(item, params, merged.top, merged.bottom, merged.dateAtBottom)
            self.contentSize = layout.contentSize
            self.insets = layout.insets
            apply(.None, ListViewItemApply(isOnScreen: false), false)
        }
    }
    
    open func cancelInsertionAnimations() {
    }
    
    override open func animateInsertion(_ currentTimestamp: Double, duration: Double, options: ListViewItemAnimationOptions) {
        if options.short {
            //self.layer.animateBoundsOriginYAdditive(from: -self.bounds.size.height, to: 0.0, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring)
        } else {
            self.transitionOffset = options.invertOffsetDirection ? self.bounds.size.height * 1.4 : -self.bounds.size.height * 1.6
            self.addTransitionOffsetAnimation(0.0, duration: duration, beginAt: currentTimestamp)
        }
    }
    
    open func asyncLayout() -> (_ item: ChatMessageItem, _ params: ListViewItemLayoutParams, _ mergedTop: ChatMessageMerge, _ mergedBottom: ChatMessageMerge, _ dateHeaderAtBottom: ChatMessageHeaderSpec) -> (ListViewItemNodeLayout, (ListViewItemUpdateAnimation, ListViewItemApply, Bool) -> Void) {
        return { _, _, _, _, _ in
            return (ListViewItemNodeLayout(contentSize: CGSize(width: 32.0, height: 32.0), insets: UIEdgeInsets()), { _, _, _ in
                
            })
        }
    }
    
    public func matchesMessage(id: MessageId) -> Bool {
        if let item = self.item {
            for (message, _) in item.content {
                if message.id == id {
                    return true
                }
            }
        }
        return false
    }
    
    public func messages() -> [Message] {
        guard let item = self.item else {
            return []
        }
        var messages: [Message] = []
        for (message, _) in item.content {
            messages.append(message)
        }
        return messages
    }
    
    open func transitionNode(id: MessageId, media: Media, adjustRect: Bool) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        return nil
    }
    
    open func makeContentSnapshot() -> (UIImage, CGRect)? {
        return nil
    }
    
    open func getMessageContextSourceNode(stableId: UInt32?) -> ContextExtractedContentContainingNode? {
        return nil
    }
    
    open func updateHiddenMedia() {
    }
    
    open func updateSelectionState(animated: Bool) {
    }
    
    open func updateSearchTextHighlightState() {
    }
    
    open func updateHighlightedState(animated: Bool) {
        var isHighlightedInOverlay = false
        if let item = self.item, let contextHighlightedState = item.controllerInteraction.contextHighlightedState {
            switch item.content {
                case let .message(message, _, _, _, _):
                    if contextHighlightedState.messageStableId == message.stableId {
                        isHighlightedInOverlay = true
                    }
                case let .group(messages):
                    for (message, _, _, _, _) in messages {
                        if contextHighlightedState.messageStableId == message.stableId {
                            isHighlightedInOverlay = true
                            break
                        }
                    }
            }
        }
        self.isHighlightedInOverlay = isHighlightedInOverlay
    }
    
    open func updateAutomaticMediaDownloadSettings() {
    }
    
    open func updateStickerSettings(forceStopAnimations: Bool) {
    }
    
    open func playMediaWithSound() -> ((Double?) -> Void, Bool, Bool, Bool, ASDisplayNode?)? {
        return nil
    }
    
    override open func headers() -> [ListViewItemHeader]? {
        if let item = self.item {
            return item.headers
        } else {
            return nil
        }
    }
    
    public func performMessageButtonAction(button: ReplyMarkupButton, progress: Promise<Bool>?) {
        if let item = self.item {
            switch button.action {
                case .text:
                    item.controllerInteraction.sendMessage(button.title)
                case let .url(url):
                    var concealed = true
                    if url.hasPrefix("tg://") {
                        concealed = false
                    }
                item.controllerInteraction.openUrl(ChatControllerInteraction.OpenUrl(url: url, concealed: concealed, progress: progress))
                case .requestMap:
                    item.controllerInteraction.shareCurrentLocation()
                case .requestPhone:
                    item.controllerInteraction.shareAccountContact()
                case .openWebApp:
                    item.controllerInteraction.requestMessageActionCallback(item.message, nil, true, false, progress)
                case let .callback(requiresPassword, data):
                    item.controllerInteraction.requestMessageActionCallback(item.message, data, false, requiresPassword, progress)
                case let .switchInline(samePeer, query, peerTypes):
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
                        item.controllerInteraction.activateSwitchInline(peerId, "@\(addressName) \(query)", peerTypes)
                    }
                case .payment:
                    item.controllerInteraction.openCheckoutOrReceipt(item.message.id, nil)
                case let .urlAuth(url, buttonId):
                    item.controllerInteraction.requestMessageActionUrlAuth(url, .message(id: item.message.id, buttonId: buttonId))
                case .setupPoll:
                    break
                case let .openUserProfile(peerId):
                    let _ = (item.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                    |> deliverOnMainQueue).startStandalone(next: { peer in
                        if let peer = peer {
                            item.controllerInteraction.openPeer(peer, .info(nil), nil, .default)
                        }
                    })
                case let .openWebView(url, simple):
                    item.controllerInteraction.openWebView(button.title, url, simple, .generic)
                case .requestPeer:
                    break
                case let .copyText(payload):
                    item.controllerInteraction.copyText(payload)
            }
        }
    }
    
    open func presentMessageButtonContextMenu(button: ReplyMarkupButton) {
        if let item = self.item {
            switch button.action {
                case let .url(url):
                    item.controllerInteraction.longTap(.url(url), ChatControllerInteraction.LongTapParams(message: item.message))
                default:
                    break
            }
        }
    }
    
    open func openMessageContextMenu() {
    }
    
    open func makeProgress() -> Promise<Bool>? {
        return nil
    }
    
    open func targetReactionView(value: MessageReaction.Reaction) -> UIView? {
        return nil
    }
    
    open func targetForStoryTransition(id: StoryId) -> UIView? {
        return nil
    }
    
    open func getStatusNode() -> ASDisplayNode? {
        return nil
    }

    private var attachedAvatarNodeOffset: CGFloat = 0.0
    private var attachedAvatarNodeIsHidden: Bool = false
    
    private var attachedDateHeader: (hasDate: Bool, hasPeer: Bool) = (false, false)

    override open func attachedHeaderNodesUpdated() {
        if !self.attachedAvatarNodeOffset.isZero {
            self.updateAttachedAvatarNodeOffset(offset: self.attachedAvatarNodeOffset, transition: .immediate)
        } else {
            for headerNode in self.attachedHeaderNodes {
                if let headerNode = headerNode as? ChatMessageAvatarHeaderNode {
                    headerNode.updateSelectionState(animated: false)
                }
            }
        }
        
        for headerNode in self.attachedHeaderNodes {
            if let headerNode = headerNode as? ChatMessageAvatarHeaderNode {
                headerNode.updateAvatarIsHidden(isHidden: self.attachedAvatarNodeIsHidden, transition: .immediate)
            }
        }
        
        for headerNode in self.attachedHeaderNodes {
            if let headerNode = headerNode as? ChatMessageDateHeaderNode {
                headerNode.updateItem(hasDate: self.attachedDateHeader.hasDate, hasPeer: self.attachedDateHeader.hasPeer)
            }
        }
    }

    open func updateAttachedAvatarNodeOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        self.attachedAvatarNodeOffset = offset
        for headerNode in self.attachedHeaderNodes {
            if let headerNode = headerNode as? ChatMessageAvatarHeaderNode {
                transition.updateSublayerTransformOffset(layer: headerNode.layer, offset: CGPoint(x: offset, y: 0.0))
            }
        }
    }
    
    open func updateAttachedAvatarNodeIsHidden(isHidden: Bool, transition: ContainedViewLayoutTransition) {
        self.attachedAvatarNodeIsHidden = isHidden
        for headerNode in self.attachedHeaderNodes {
            if let headerNode = headerNode as? ChatMessageAvatarHeaderNode {
                headerNode.updateAvatarIsHidden(isHidden: self.attachedAvatarNodeIsHidden, transition: transition)
            }
        }
    }
    
    open func updateAttachedDateHeader(hasDate: Bool, hasPeer: Bool) {
        self.attachedDateHeader = (hasDate, hasPeer)
        for headerNode in self.attachedHeaderNodes {
            if let headerNode = headerNode as? ChatMessageDateHeaderNode {
                headerNode.updateItem(hasDate: hasDate, hasPeer: hasPeer)
            }
        }
    }
    
    open func unreadMessageRangeUpdated() {
    }
    
    open func contentFrame() -> CGRect {
        return self.bounds
    }
    
    private func playEffectAnimation(effect: AvailableMessageEffects.MessageEffect, force: Bool) {
        guard let item = self.item else {
            return
        }
        if self.playedEffectAnimation && !force {
            return
        }
        self.playedEffectAnimation = true
        
        if let effectAnimation = effect.effectAnimation?._parse() {
            self.playEffectAnimation(resource: effectAnimation.resource)
            if self.fetchEffectDisposable == nil {
                self.fetchEffectDisposable = freeMediaFileResourceInteractiveFetched(account: item.context.account, userLocation: .other, fileReference: .standalone(media: effectAnimation), resource: effectAnimation.resource).startStrict()
            }
        } else {
            let effectSticker = effect.effectSticker._parse()
            if let effectFile = effectSticker.videoThumbnails.first {
                self.playEffectAnimation(resource: effectFile.resource)
                if self.fetchEffectDisposable == nil {
                    self.fetchEffectDisposable = freeMediaFileResourceInteractiveFetched(account: item.context.account, userLocation: .other, fileReference: .standalone(media: effectSticker), resource: effectFile.resource).startStrict()
                }
            }
        }
    }
    
    open func messageEffectTargetView() -> UIView? {
        return nil
    }
    
    private func playEffectAnimation(resource: MediaResource) {
        guard let item = self.item else {
            return
        }
        guard let transitionNode = item.controllerInteraction.getMessageTransitionNode() as? ChatMessageTransitionNode else {
            return
        }
        
        let source = AnimatedStickerResourceSource(account: item.context.account, resource: resource, fitzModifier: nil)
        
        let animationSize = CGSize(width: 380.0, height: 380.0)
        let animationNodeFrame: CGRect
        
        guard let messageEffectView = self.messageEffectTargetView() else {
            return
        }
        
        animationNodeFrame = animationSize.centered(around: messageEffectView.convert(messageEffectView.bounds, to: self.view).center)
        
        if self.effectAnimationNodes.count >= 2 {
            return
        }
        
        let incomingMessage = item.message.effectivelyIncoming(item.context.account.peerId)

        do {
            let pathPrefix = item.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(resource.id)
            
            let additionalAnimationNode: AnimatedStickerNode
            var effectiveScale: CGFloat = 1.0
            #if targetEnvironment(simulator)
            additionalAnimationNode = DirectAnimatedStickerNode()
            effectiveScale = 1.4
            #else
            additionalAnimationNode = DirectAnimatedStickerNode()
            effectiveScale = 1.4
            /*if "".isEmpty {
                additionalAnimationNode = DirectAnimatedStickerNode()
                effectiveScale = 1.4
            } else {
                additionalAnimationNode = LottieMetalAnimatedStickerNode()
            }*/
            #endif
            additionalAnimationNode.updateLayout(size: animationSize)
            additionalAnimationNode.setup(source: source, width: Int(animationSize.width * effectiveScale), height: Int(animationSize.height * effectiveScale), playbackMode: .once, mode: .direct(cachePathPrefix: pathPrefix))
            var animationFrame: CGRect
            let offsetScale: CGFloat = 0.3
            animationFrame = animationNodeFrame.offsetBy(dx: incomingMessage ? animationNodeFrame.width * offsetScale : -animationNodeFrame.width * offsetScale, dy: -10.0)
            
            animationFrame = animationFrame.offsetBy(dx: 0.0, dy: self.insets.top)
            additionalAnimationNode.frame = animationFrame
            if incomingMessage {
                additionalAnimationNode.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
            }

            let decorationNode = transitionNode.add(decorationView: additionalAnimationNode.view, itemNode: self, aboveEverything: true)
            additionalAnimationNode.completed = { [weak self, weak decorationNode, weak transitionNode] _ in
                guard let decorationNode = decorationNode else {
                    return
                }
                self?.effectAnimationNodes.removeAll(where: { $0 === decorationNode })
                transitionNode?.remove(decorationNode: decorationNode)
            }
            additionalAnimationNode.isPlayingChanged = { [weak self, weak decorationNode, weak transitionNode] isPlaying in
                if !isPlaying {
                    guard let decorationNode = decorationNode else {
                        return
                    }
                    self?.effectAnimationNodes.removeAll(where: { $0 === decorationNode })
                    transitionNode?.remove(decorationNode: decorationNode)
                }
            }

            self.effectAnimationNodes.append(decorationNode)

            additionalAnimationNode.visibility = true
        }
    }
    
    public func removeEffectAnimations() {
        for decorationNode in self.effectAnimationNodes {
            if let additionalAnimationNode = decorationNode.contentView.asyncdisplaykit_node as? AnimatedStickerNode {
                additionalAnimationNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak additionalAnimationNode] _ in
                    additionalAnimationNode?.visibility = false
                })
            }
        }
    }
    
    public func currentMessageEffect() -> AvailableMessageEffects.MessageEffect? {
        guard let item = self.item else {
            return nil
        }
        var messageEffect: AvailableMessageEffects.MessageEffect?
        for attribute in item.message.attributes {
            if let attribute = attribute as? EffectMessageAttribute {
                if let availableMessageEffects = item.associatedData.availableMessageEffects {
                    for effect in availableMessageEffects.messageEffects {
                        if effect.id == attribute.id {
                            messageEffect = effect
                            break
                        }
                    }
                }
                break
            }
        }
        return messageEffect
    }
    
    public func playMessageEffect(force: Bool) {
        if let messageEffect = self.currentMessageEffect() {
            self.playEffectAnimation(effect: messageEffect, force: force)
        }
    }
}
