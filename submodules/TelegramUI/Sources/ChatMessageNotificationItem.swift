import Foundation
import UIKit
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import AvatarNode
import AccountContext
import LocalizedPeerData
import StickerResources
import PhotoResources
import TelegramStringFormatting
import TextFormat
import InvisibleInkDustNode

public final class ChatMessageNotificationItem: NotificationItem {
    let context: AccountContext
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let nameDisplayOrder: PresentationPersonNameOrder
    let messages: [Message]
    let tapAction: () -> Bool
    let expandAction: (@escaping () -> (ASDisplayNode?, () -> Void)) -> Void
    
    public var groupingKey: AnyHashable? {
        return messages.first?.id.peerId
    }
    
    public init(context: AccountContext, strings: PresentationStrings, dateTimeFormat: PresentationDateTimeFormat, nameDisplayOrder: PresentationPersonNameOrder, messages: [Message], tapAction: @escaping () -> Bool, expandAction: @escaping (() -> (ASDisplayNode?, () -> Void)) -> Void) {
        self.context = context
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.nameDisplayOrder = nameDisplayOrder
        self.messages = messages
        self.tapAction = tapAction
        self.expandAction = expandAction
    }
    
    public func node(compact: Bool) -> NotificationItemNode {
        let node = ChatMessageNotificationItemNode()
        node.setupItem(self, compact: compact)
        return node
    }
    
    public func tapped(_ take: @escaping () -> (ASDisplayNode?, () -> Void)) {
        if self.tapAction() {
            self.expandAction(take)
        }
    }
    
    public func canBeExpanded() -> Bool {
        return true
    }
    
    public func expand(_ take: @escaping () -> (ASDisplayNode?, () -> Void)) {
        self.expandAction(take)
    }
}

private let compactAvatarFont = avatarPlaceholderFont(size: 20.0)
private let avatarFont = avatarPlaceholderFont(size: 24.0)

final class ChatMessageNotificationItemNode: NotificationItemNode {
    private var item: ChatMessageNotificationItem?
    
    private let avatarNode: AvatarNode
    private let titleIconNode: ASImageNode
    private let titleNode: TextNode
    private let textNode: TextNode
    private var dustNode: InvisibleInkDustNode?
    private let imageNode: TransformImageNode
    
    private var titleAttributedText: NSAttributedString?
    private var textAttributedText: NSAttributedString?
    
    private var compact: Bool?
    private var validLayout: CGFloat?
    
    override init() {
        self.avatarNode = AvatarNode(font: avatarFont)
        
        self.titleNode = TextNode()
        self.titleNode.isUserInteractionEnabled = false
        
        self.titleIconNode = ASImageNode()
        self.titleIconNode.isLayerBacked = true
        self.titleIconNode.displayWithoutProcessing = true
        self.titleIconNode.displaysAsynchronously = false
        
        self.textNode = TextNode()
        self.textNode.isUserInteractionEnabled = false
        
        self.imageNode = TransformImageNode()
        
        super.init()
        
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleIconNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.imageNode)
    }
    
    func setupItem(_ item: ChatMessageNotificationItem, compact: Bool) {
        self.item = item
        self.compact = compact
        if compact {
            self.avatarNode.font = compactAvatarFont
        }
        let presentationData = item.context.sharedContext.currentPresentationData.with { $0 }
        
        var isReminder = false
        var isScheduled = false
        var title: String?
        if let firstMessage = item.messages.first, let peer = messageMainPeer(EngineMessage(firstMessage)) {
            if case let .channel(channel) = peer, case .broadcast = channel.info {
                title = peer.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
            } else if let author = firstMessage.author {
                if firstMessage.id.peerId.isReplies, let _ = firstMessage.sourceReference, let effectiveAuthor = firstMessage.forwardInfo?.author {
                    title = EnginePeer(effectiveAuthor).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder) + "@" + peer.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                } else if author.id != peer.id {
                    if author.id == item.context.account.peerId {
                        title = presentationData.strings.DialogList_You + "@" + peer.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                    } else {
                        title = EnginePeer(author).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder) + "@" + peer.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                    }
                } else {
                    title = peer.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                    for attribute in firstMessage.attributes {
                        if let attribute = attribute as? SourceReferenceMessageAttribute {
                            if let sourcePeer = firstMessage.peers[attribute.messageId.peerId] {
                                title = EnginePeer(sourcePeer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder) + "@" + peer.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            }
                            break
                        }
                    }
                }
            } else {
                title = peer.displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
            }
            
            if let _ = title, firstMessage.flags.contains(.WasScheduled) {
                if let author = firstMessage.author, author.id == peer.id, author.id == item.context.account.peerId {
                    isReminder = true
                } else {
                    isScheduled = true
                }
            }
            var avatarPeer = peer
            if firstMessage.id.peerId.isReplies, let author = firstMessage.forwardInfo?.author {
                avatarPeer = EnginePeer(author)
            }
            self.avatarNode.setPeer(context: item.context, theme: presentationData.theme, peer: avatarPeer, overrideImage: peer.id == item.context.account.peerId ? .savedMessagesIcon : nil, emptyColor: presentationData.theme.list.mediaPlaceholderColor)
        }
        
        var updatedMedia: Media?
        var imageDimensions: CGSize?
        var isRound = false
        var messageText: String
        var messageEntities: [MessageTextEntity]?
        if item.messages.first?.id.peerId.namespace == Namespaces.Peer.SecretChat {
            messageText = item.strings.PUSH_ENCRYPTED_MESSAGE("").string
        } else if item.messages.count == 1 {
            let message = item.messages[0]
            for media in message.media {
                if let image = media as? TelegramMediaImage {
                    updatedMedia = image
                    if let representation = largestRepresentationForPhoto(image) {
                        imageDimensions = representation.dimensions.cgSize
                    }
                    break
                } else if let file = media as? TelegramMediaFile {
                    updatedMedia = file
                    if let representation = largestImageRepresentation(file.previewRepresentations) {
                        imageDimensions = representation.dimensions.cgSize
                    }
                    isRound = file.isInstantVideo
                    break
                }
            }
            if message.containsSecretMedia {
                imageDimensions = nil
            }
            let (textString, _, isText) = descriptionStringForMessage(contentSettings: item.context.currentContentSettings.with { $0 }, message: EngineMessage(message), strings: item.strings, nameDisplayOrder: item.nameDisplayOrder, dateTimeFormat: item.dateTimeFormat, accountPeerId: item.context.account.peerId)
            if isText {
                messageText = message.text
                messageEntities = message.textEntitiesAttribute?.entities.filter { entity in
                    if case .Spoiler = entity.type {
                        return true
                    } else {
                        return false
                    }
                }
                if messageEntities?.count == 0 {
                    messageEntities = nil
                    messageText = textString
                }
            } else {
                messageText = textString
            }
        } else if item.messages.count > 1, let peer = item.messages[0].peers[item.messages[0].id.peerId] {
            var displayAuthor = true
            if let channel = peer as? TelegramChannel {
                switch channel.info {
                    case .group:
                        displayAuthor = true
                    case .broadcast:
                        displayAuthor = false
                }
            } else if let _ = peer as? TelegramUser {
                displayAuthor = false
            }
            
            if item.messages[0].forwardInfo != nil && item.messages[0].sourceReference == nil {
                if let author = item.messages[0].author, displayAuthor {
                    if !isReminder {
                        title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                    }
                    messageText = presentationData.strings.PUSH_CHAT_MESSAGE_FWDS_TEXT(Int32(item.messages.count)).replacingOccurrences(of: "{author}", with: EnginePeer(author).compactDisplayTitle)
                } else {
                    title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                    messageText = presentationData.strings.PUSH_MESSAGE_FWDS_TEXT(Int32(item.messages.count))
                }
            } else if item.messages[0].groupingKey != nil {
                var kind = messageContentKind(contentSettings: item.context.currentContentSettings.with { $0 }, message: EngineMessage(item.messages[0]), strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat, accountPeerId: item.context.account.peerId).key
                for i in 1 ..< item.messages.count {
                    let nextKind = messageContentKind(contentSettings: item.context.currentContentSettings.with { $0 }, message: EngineMessage(item.messages[i]), strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, dateTimeFormat: presentationData.dateTimeFormat, accountPeerId: item.context.account.peerId)
                    if kind != nextKind.key {
                        kind = .text
                        break
                    }
                }
                var isChannel = false
                var isGroup = false
                if let peer = peer as? TelegramChannel {
                    if case .broadcast = peer.info {
                        isChannel = true
                    } else {
                        isGroup = true
                    }
                } else if item.messages[0].id.peerId.namespace == Namespaces.Peer.CloudGroup {
                    isGroup = true
                }
                if isChannel {
                    switch kind {
                        case .image:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_CHANNEL_MESSAGE_PHOTOS_TEXT(Int32(item.messages.count))
                        case .video:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_CHANNEL_MESSAGE_VIDEOS_TEXT(Int32(item.messages.count))
                        case .file:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_CHANNEL_MESSAGE_DOCS_TEXT(Int32(item.messages.count))
                        default:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_CHANNEL_MESSAGES_TEXT(Int32(item.messages.count))
                    }
                } else if isGroup, var author = item.messages[0].author {
                    if let sourceReference = item.messages[0].sourceReference, let sourcePeer = item.messages[0].peers[sourceReference.messageId.peerId] {
                        author = sourcePeer
                    }
                    switch kind {
                        case .image:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_CHAT_MESSAGE_PHOTOS_TEXT(Int32(item.messages.count)).replacingOccurrences(of: "{author}", with: EnginePeer(author).compactDisplayTitle)
                        case .video:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_CHAT_MESSAGE_VIDEOS_TEXT(Int32(item.messages.count)).replacingOccurrences(of: "{author}", with: EnginePeer(author).compactDisplayTitle)
                        case .file:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_CHAT_MESSAGE_DOCS_TEXT(Int32(item.messages.count)).replacingOccurrences(of: "{author}", with: EnginePeer(author).compactDisplayTitle)
                        default:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_CHAT_MESSAGES_TEXT(Int32(item.messages.count)).replacingOccurrences(of: "{author}", with: EnginePeer(author).compactDisplayTitle)
                    }
                } else {
                    switch kind {
                        case .image:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_MESSAGE_PHOTOS_TEXT(Int32(item.messages.count))
                        case .video:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_MESSAGE_VIDEOS_TEXT(Int32(item.messages.count))
                        case .file:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_MESSAGE_FILES_TEXT(Int32(item.messages.count))
                        default:
                            title = EnginePeer(peer).displayTitle(strings: item.strings, displayOrder: item.nameDisplayOrder)
                            messageText = presentationData.strings.PUSH_MESSAGES_TEXT(Int32(item.messages.count))
                    }
                }
            } else {
                messageText = ""
            }
        } else {
            messageText = ""
        }
        
        if isReminder {
            title = presentationData.strings.ScheduledMessages_ReminderNotification
        } else if isScheduled, let currentTitle = title {
            title = "📅 \(currentTitle)"
        }
        
        let textFont = compact ? Font.regular(15.0) : Font.regular(16.0)
        let textColor = presentationData.theme.inAppNotification.primaryTextColor
        var attributedMessageText: NSAttributedString
        if let messageEntities = messageEntities {
            attributedMessageText = stringWithAppliedEntities(messageText, entities: messageEntities, baseColor: textColor, linkColor: textColor, baseFont: textFont, linkFont: textFont, boldFont: textFont, italicFont: textFont, boldItalicFont: textFont, fixedFont: textFont, blockQuoteFont: textFont, underlineLinks: false)
        } else {
            attributedMessageText = NSAttributedString(string: messageText.replacingOccurrences(of: "\n\n", with: " "), font: textFont, textColor: textColor)
        }
                
        self.titleAttributedText = NSAttributedString(string: title ?? "", font: compact ? Font.semibold(15.0) : Font.semibold(16.0), textColor: presentationData.theme.inAppNotification.primaryTextColor)
        
        let imageNodeLayout = self.imageNode.asyncLayout()
        var applyImage: (() -> Void)?
        if let imageDimensions = imageDimensions {
            let boundingSize = CGSize(width: 55.0, height: 55.0)
            var radius: CGFloat = 6.0
            if isRound {
                radius = floor(boundingSize.width / 2.0)
            }
            applyImage = imageNodeLayout(TransformImageArguments(corners: ImageCorners(radius: radius), imageSize: imageDimensions.aspectFilled(boundingSize), boundingSize: boundingSize, intrinsicInsets: UIEdgeInsets()))
        }
        
        var updateImageSignal: Signal<(TransformImageArguments) -> DrawingContext?, NoError>?
        if let firstMessage = item.messages.first, let updatedMedia = updatedMedia, imageDimensions != nil {
            if let image = updatedMedia as? TelegramMediaImage {
                updateImageSignal = mediaGridMessagePhoto(account: item.context.account, photoReference: .message(message: MessageReference(firstMessage), media: image))
            } else if let file = updatedMedia as? TelegramMediaFile {
                if file.isSticker {
                    updateImageSignal = chatMessageSticker(account: item.context.account, file: file, small: true, fetched: true)
                } else if file.isVideo {
                    updateImageSignal = mediaGridMessageVideo(postbox: item.context.account.postbox, videoReference: .message(message: MessageReference(firstMessage), media: file), autoFetchFullSizeThumbnail: true)
                }
            }
        }
        
        if let applyImage = applyImage {
            applyImage()
            self.imageNode.isHidden = false
        } else {
            self.imageNode.isHidden = true
        }
        
        if let updateImageSignal = updateImageSignal {
            self.imageNode.setSignal(updateImageSignal)
        }
        
        self.textAttributedText = attributedMessageText
        
        if let width = self.validLayout {
            let _ = self.updateLayout(width: width, transition: .immediate)
        }
    }
    
    override func updateLayout(width: CGFloat, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = width
        let compact = self.compact ?? false
        
        let panelHeight: CGFloat = compact ? 64.0 : 74.0
        let imageSize: CGSize = compact ? CGSize(width: 44.0, height: 44.0) : CGSize(width: 54.0, height: 54.0)
        let imageSpacing: CGFloat = compact ? 19.0 : 23.0
        let leftInset: CGFloat = imageSize.width + imageSpacing
        var rightInset: CGFloat = 8.0
        
        if !self.imageNode.isHidden {
            rightInset += imageSize.width + 8.0
        }
        
        transition.updateFrame(node: self.avatarNode, frame: CGRect(origin: CGPoint(x: 10.0, y: (panelHeight - imageSize.height) / 2.0), size: imageSize))
        
        var titleInset: CGFloat = 0.0
        if let image = self.titleIconNode.image {
            titleInset += image.size.width + 4.0
        }
        
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let (titleLayout, titleApply) = makeTitleLayout(TextNodeLayoutArguments(attributedString: self.titleAttributedText, backgroundColor: nil, maximumNumberOfLines: 1, truncationType: .end, constrainedSize: CGSize(width: width - leftInset - rightInset - titleInset, height: CGFloat.greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let _ = titleApply()
        
        let makeTextLayout = TextNode.asyncLayout(self.textNode)
        let (textLayout, textApply) = makeTextLayout(TextNodeLayoutArguments(attributedString: self.textAttributedText, backgroundColor: nil, maximumNumberOfLines: 2, truncationType: .end, constrainedSize: CGSize(width: width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude), alignment: .left, lineSpacing: 0.0, cutout: nil, insets: UIEdgeInsets()))
        let _ = titleApply()
        let _ = textApply()
                
        let textSpacing: CGFloat = 1.0
        
        let titleFrame = CGRect(origin: CGPoint(x: leftInset + titleInset, y: 1.0 + floor((panelHeight - textLayout.size.height - titleLayout.size.height - textSpacing) / 2.0)), size: titleLayout.size)
        transition.updateFrame(node: self.titleNode, frame: titleFrame)
        
        if let image = self.titleIconNode.image {
            transition.updateFrame(node: self.titleIconNode, frame: CGRect(origin: CGPoint(x: leftInset + 1.0, y: titleFrame.minY + 3.0), size: image.size))
        }
        
        let textFrame = CGRect(origin: CGPoint(x: leftInset, y: titleFrame.maxY + textSpacing), size: textLayout.size)
        transition.updateFrame(node: self.textNode, frame: textFrame)
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(x: width - 10.0 - imageSize.width, y: (panelHeight - imageSize.height) / 2.0), size: imageSize))
        
        if !textLayout.spoilers.isEmpty, let presentationData = self.item?.context.sharedContext.currentPresentationData.with({ $0 }) {
            let dustNode: InvisibleInkDustNode
            if let current = self.dustNode {
                dustNode = current
            } else {
                dustNode = InvisibleInkDustNode(textNode: nil)
                dustNode.isUserInteractionEnabled = false
                self.dustNode = dustNode
                self.insertSubnode(dustNode, aboveSubnode: self.textNode)
            }
            dustNode.frame = textFrame.insetBy(dx: -3.0, dy: -3.0).offsetBy(dx: 0.0, dy: 3.0)
            dustNode.update(size: dustNode.frame.size, color: presentationData.theme.inAppNotification.primaryTextColor, textColor: presentationData.theme.inAppNotification.primaryTextColor, rects: textLayout.spoilers.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) }, wordRects: textLayout.spoilerWords.map { $0.1.offsetBy(dx: 3.0, dy: 3.0).insetBy(dx: 1.0, dy: 1.0) })
        } else if let dustNode = self.dustNode {
            dustNode.removeFromSupernode()
            self.dustNode = nil
        }
        
        return panelHeight
    }
}
