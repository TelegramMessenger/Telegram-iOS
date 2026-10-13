import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit
import Emoji

public enum EnqueueMessageGrouping {
    case none
    case auto
}

public enum EngineMessageReplyInnerSubject: Codable, Equatable {
    case todoItem(Int32)
    case pollOption(Data)

    private enum CodingKeys: String, CodingKey {
        case type = "t"
        case value = "v"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Int32.self, forKey: .type)
        switch type {
        case 0:
            self = .todoItem(try container.decode(Int32.self, forKey: .value))
        case 1:
            self = .pollOption(try container.decode(Data.self, forKey: .value))
        default:
            self = .todoItem(try container.decode(Int32.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .todoItem(id):
            try container.encode(Int32(0), forKey: .type)
            try container.encode(id, forKey: .value)
        case let .pollOption(data):
            try container.encode(Int32(1), forKey: .type)
            try container.encode(data, forKey: .value)
        }
    }
}

public struct EngineMessageReplyQuote: Codable, Equatable {
    private enum CodingKeys: String, CodingKey {
        case text = "t"
        case entities = "e"
        case media = "m"
        case offset = "o"
    }
    
    public var text: String
    public var offset: Int?
    public var entities: [MessageTextEntity]
    public var media: Media?
    
    public init(text: String, offset: Int?, entities: [MessageTextEntity], media: Media?) {
        self.text = text
        self.offset = offset
        self.entities = entities
        self.media = media
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.text = try container.decode(String.self, forKey: .text)
        self.offset = (try container.decodeIfPresent(Int32.self, forKey: .offset)).flatMap(Int.init)
        self.entities = try container.decode([MessageTextEntity].self, forKey: .entities)
        
        if let mediaData = try container.decodeIfPresent(Data.self, forKey: .media) {
            self.media = PostboxDecoder(buffer: MemoryBuffer(data: mediaData)).decodeRootObject() as? Media
        } else {
            self.media = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(self.text, forKey: .text)
        try container.encodeIfPresent(self.offset.flatMap(Int32.init(clamping:)), forKey: .offset)
        try container.encode(self.entities, forKey: .entities)
        if let media = self.media {
            let mediaEncoder = PostboxEncoder()
            mediaEncoder.encodeRootObject(media)
            try container.encode(mediaEncoder.makeData(), forKey: .media)
        }
    }
    
    public static func ==(lhs: EngineMessageReplyQuote, rhs: EngineMessageReplyQuote) -> Bool {
        if lhs.text != rhs.text {
            return false
        }
        if lhs.offset != rhs.offset {
            return false
        }
        if lhs.entities != rhs.entities {
            return false
        }
        if let lhsMedia = lhs.media, let rhsMedia = rhs.media {
            if !lhsMedia.isEqual(to: rhsMedia) {
                return false
            }
        } else {
            if (lhs.media == nil) != (rhs.media == nil) {
                return false
            }
        }
        return true
    }
}

public struct EngineMessageReplySubject: Codable, Equatable {
    public var messageId: EngineMessage.Id
    public var quote: EngineMessageReplyQuote?
    public var innerSubject: EngineMessageReplyInnerSubject?
    
    public init(messageId: EngineMessage.Id, quote: EngineMessageReplyQuote?, innerSubject: EngineMessageReplyInnerSubject?) {
        self.messageId = messageId
        self.quote = quote
        self.innerSubject = innerSubject
    }
}

public enum EnqueueMessage {
    case message(text: String, attributes: [MessageAttribute], inlineStickers: [MediaId: Media], mediaReference: AnyMediaReference?, threadId: Int64?, replyToMessageId: EngineMessageReplySubject?, replyToStoryId: StoryId?, localGroupingKey: Int64?, correlationId: Int64?, bubbleUpEmojiOrStickersets: [ItemCollectionId])
    case forward(source: MessageId, threadId: Int64?, grouping: EnqueueMessageGrouping, attributes: [MessageAttribute], correlationId: Int64?)
    
    public func withUpdatedReplyToMessageId(_ replyToMessageId: EngineMessageReplySubject?) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId, _, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return self
        }
    }
    
    public func withUpdatedReplyToStoryId(_ replyToStoryId: StoryId?) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, _, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return self
        }
    }
    
    public func withUpdatedAttributes(_ f: ([MessageAttribute]) -> [MessageAttribute]) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId: threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: f(attributes), inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case let .forward(source, threadId, grouping, attributes, correlationId):
            return .forward(source: source, threadId: threadId, grouping: grouping, attributes: f(attributes), correlationId: correlationId)
        }
    }
    
    public func withUpdatedGroupingKey(_ f: (Int64?) -> Int64?) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: f(localGroupingKey), correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return self
        }
    }

    public func withUpdatedCorrelationId(_ value: Int64?) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, _, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: value, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case let .forward(source, threadId, grouping, attributes, _):
            return .forward(source: source, threadId: threadId, grouping: grouping, attributes: attributes, correlationId: value)
        }
    }
    
    public func withUpdatedThreadId(_ threadId: Int64?) -> EnqueueMessage {
        switch self {
        case let .message(text, attributes, inlineStickers, mediaReference, _, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            return .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case let .forward(source, _, grouping, attributes, correlationId):
            return .forward(source: source, threadId: threadId, grouping: grouping, attributes: attributes, correlationId: correlationId)
        }
    }
    
    public var groupingKey: Int64? {
        if case let .message(_, _, _, _, _, _, _, localGroupingKey, _, _) = self {
            return localGroupingKey
        } else {
            return nil
        }
    }
    
    public var attributes: [MessageAttribute] {
        switch self {
        case let .message(_, attributes, _, _, _, _, _, _, _, _):
            return attributes
        case let .forward(_, _, _, attributes, _):
            return attributes
        }
    }
}

private extension EnqueueMessage {
    var correlationId: Int64? {
        switch self {
        case let .message(_, _, _, _, _, _, _, _, correlationId, _):
            return correlationId
        case let .forward(_, _, _, _, correlationId):
            return correlationId
        }
    }
    
    var bubbleUpEmojiOrStickersets: [ItemCollectionId] {
        switch self {
        case let .message(_, _, _, _, _, _, _, _, _, bubbleUpEmojiOrStickersets):
            return bubbleUpEmojiOrStickersets
        case .forward:
            return []
        }
    }
}

func augmentMediaWithReference(_ mediaReference: AnyMediaReference) -> Media {
    if let file = mediaReference.media as? TelegramMediaFile {
        if file.partialReference != nil {
            return file
        } else {
            return file.withUpdatedPartialReference(mediaReference.partial)
        }
    } else if let image = mediaReference.media as? TelegramMediaImage {
        if image.partialReference != nil {
            return image
        } else {
            return image.withUpdatedPartialReference(mediaReference.partial)
        }
    } else {
        return mediaReference.media
    }
}

private func convertForwardedMediaForSecretChat(_ media: Media) -> Media {
    if let file = media as? TelegramMediaFile {
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: Int64.random(in: Int64.min ... Int64.max)), partialReference: file.partialReference, resource: file.resource, previewRepresentations: file.previewRepresentations, videoThumbnails: file.videoThumbnails, immediateThumbnailData: file.immediateThumbnailData, mimeType: file.mimeType, size: file.size, attributes: file.attributes, alternativeRepresentations: [])
    } else if let image = media as? TelegramMediaImage {
        return TelegramMediaImage(imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)), representations: image.representations, immediateThumbnailData: image.immediateThumbnailData, reference: image.reference, partialReference: image.partialReference, flags: [])
    } else {
        return media
    }
}

private func filterMessageAttributesForOutgoingMessage(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.filter { attribute in
        switch attribute {
        case _ as TextEntitiesMessageAttribute:
            return true
        case _ as RichTextMessageAttribute:
            return true
        case _ as InlineBotMessageAttribute:
            return true
        case _ as OutgoingMessageInfoAttribute:
            return false
        case _ as OutgoingContentInfoMessageAttribute:
            return true
        case _ as ReplyMarkupMessageAttribute:
            return true
        case _ as OutgoingChatContextResultMessageAttribute:
            return true
        case _ as AutoremoveTimeoutMessageAttribute:
            return true
        case _ as NotificationInfoMessageAttribute:
            return true
        case _ as OutgoingScheduleInfoMessageAttribute:
            return true
        case _ as OutgoingQuickReplyMessageAttribute:
            return true
        case _ as EmbeddedMediaStickersMessageAttribute:
            return true
        case _ as EmojiSearchQueryMessageAttribute:
            return true
        case _ as ForwardOptionsMessageAttribute:
            return true
        case _ as SendAsMessageAttribute:
            return true
        case _ as MediaSpoilerMessageAttribute:
            return true
        case _ as WebpagePreviewMessageAttribute:
            return true
        case _ as InvertMediaMessageAttribute:
            return true
        case _ as EffectMessageAttribute:
            return true
        case _ as ForwardVideoTimestampAttribute:
            return true
        case _ as PaidStarsMessageAttribute:
            return true
        case _ as SuggestedPostMessageAttribute:
            return true
        case _ as EphemeralOutgoingMessageAttribute:
            assertionFailure("EphemeralOutgoingMessageAttribute must be routed before normal outgoing enqueue")
            return false
        default:
            return false
        }
    }
}

/// The attributes an outgoing message stores for the ones it was requested with. A media timer is
/// requested as `AutoremoveTimeoutMessageAttribute`: a secret chat stores it as-is in place of the
/// chat's own timer, any other chat stores it as `AutoclearTimeoutMessageAttribute` beside the chat's
/// auto-delete period (`peerAutoremoveTimeout`).
func outgoingMessageAttributes(requestedAttributes: [MessageAttribute], isSecretChat: Bool, peerAutoremoveTimeout: Int32?) -> [MessageAttribute] {
    var peerAutoremoveTimeout = peerAutoremoveTimeout
    var attributes: [MessageAttribute] = []
    for attribute in filterMessageAttributesForOutgoingMessage(requestedAttributes) {
        if let attribute = attribute as? AutoremoveTimeoutMessageAttribute {
            if isSecretChat {
                peerAutoremoveTimeout = nil
                attributes.append(attribute)
            } else {
                attributes.append(AutoclearTimeoutMessageAttribute(timeout: attribute.timeout, countdownBeginTime: nil))
            }
        } else {
            attributes.append(attribute)
        }
    }
    if let peerAutoremoveTimeout = peerAutoremoveTimeout {
        attributes.append(AutoremoveTimeoutMessageAttribute(timeout: peerAutoremoveTimeout, countdownBeginTime: nil))
    }
    return attributes
}

/// What a resent message requests in place of `attribute`, which the failed message stores in the
/// form `outgoingMessageAttributes` produced; nil when it is not requested again.
func resentMessageRequestedAttribute(_ attribute: MessageAttribute, isSecretChat: Bool) -> MessageAttribute? {
    if attribute is PaidStarsMessageAttribute {
        return nil
    }
    if let attribute = attribute as? AutoclearTimeoutMessageAttribute {
        // The media timer of a cloud chat, which is requested in its autoremove form.
        return AutoremoveTimeoutMessageAttribute(timeout: attribute.timeout, countdownBeginTime: nil)
    }
    if attribute is AutoremoveTimeoutMessageAttribute && !isSecretChat {
        // The chat's auto-delete period, derived again when the message is enqueued. Requested, it
        // would become a media timer.
        return nil
    }
    return attribute
}

/// What a forward requests when the server cannot forward it and it is sent as a copy, a new message
/// with the source's content: the source is not a cloud message, or the destination is a secret chat.
/// The copy takes the source's content and the forward's own attributes, which say how and where it
/// is sent. Nothing else the source stores is requested: its timer belongs to its chat and would
/// become a media timer in a cloud chat or override a secret chat's own, and its paid stars, send-as
/// peer and schedule are the source chat's. `hidesCaption` drops the formatting of a caption the
/// forward hides.
func forwardCopyRequestedAttributes(sourceAttributes: [MessageAttribute], forwardAttributes: [MessageAttribute], hidesCaption: Bool) -> [MessageAttribute] {
    let contentAttributes = sourceAttributes.filter { attribute in
        switch attribute {
        case _ as TextEntitiesMessageAttribute:
            return !hidesCaption
        case _ as RichTextMessageAttribute:
            return true
        case _ as InlineBotMessageAttribute:
            return true
        case _ as OutgoingContentInfoMessageAttribute:
            return true
        case _ as ReplyMarkupMessageAttribute:
            return true
        case _ as OutgoingChatContextResultMessageAttribute:
            return true
        case _ as EmbeddedMediaStickersMessageAttribute:
            return true
        case _ as EmojiSearchQueryMessageAttribute:
            return true
        case _ as MediaSpoilerMessageAttribute:
            return true
        case _ as WebpagePreviewMessageAttribute:
            return true
        case _ as InvertMediaMessageAttribute:
            return true
        default:
            return false
        }
    }
    return contentAttributes + forwardAttributes
}

/// The attributes a forwarded message stores from the forward's request and from its source: one of
/// each kind, the request's where both have one. A resent forward requests what the failed one
/// stored, which already includes the source's; and the sender reads the last paid stars a message
/// stores, which must be the destination's price rather than what the source was paid.
func forwardedMessageAttributes(requestedAttributes: [MessageAttribute], sourceAttributes: [MessageAttribute], forwardedMessageIds: Set<MessageId>?) -> [MessageAttribute] {
    let requested = filterMessageAttributesForForwardedMessage(requestedAttributes)
    let requestedKinds = Set(requested.map { ObjectIdentifier(type(of: $0)) })
    let source = filterMessageAttributesForForwardedMessage(sourceAttributes, forwardedMessageIds: forwardedMessageIds).filter { attribute in
        return !requestedKinds.contains(ObjectIdentifier(type(of: attribute)))
    }
    return requested + source
}

/// The local grouping key of a forwarded message: an album stays one album, under a key of its own
/// so it does not join the source's.
func forwardGroupingKey(grouping: EnqueueMessageGrouping, sourceGroupingKey: Int64?, generatedKeys: inout [Int64: Int64]) -> Int64? {
    switch grouping {
    case .none:
        return nil
    case .auto:
        guard let sourceGroupingKey = sourceGroupingKey else {
            return nil
        }
        if let generatedKey = generatedKeys[sourceGroupingKey] {
            return generatedKey
        }
        let generatedKey = Int64.random(in: Int64.min ... Int64.max)
        generatedKeys[sourceGroupingKey] = generatedKey
        return generatedKey
    }
}

private func filterMessageAttributesForEphemeralOutgoingMessage(_ attributes: [MessageAttribute]) -> [MessageAttribute] {
    return attributes.filter { attribute in
        switch attribute {
        case _ as TextEntitiesMessageAttribute:
            return true
        case _ as RichTextMessageAttribute:
            return true
        case _ as EmbeddedMediaStickersMessageAttribute:
            return true
        case _ as EmojiSearchQueryMessageAttribute:
            return true
        case _ as MediaSpoilerMessageAttribute:
            return true
        case _ as WebpagePreviewMessageAttribute:
            return true
        case _ as InvertMediaMessageAttribute:
            return true
        case _ as ForwardVideoTimestampAttribute:
            return true
        default:
            return false
        }
    }
}

private func transientEphemeralOutgoingAttribute(_ attributes: [MessageAttribute]) -> EphemeralOutgoingMessageAttribute? {
    for attribute in attributes {
        if let attribute = attribute as? EphemeralOutgoingMessageAttribute, attribute.randomId == 0, attribute.state == .sending {
            return attribute
        }
    }
    return nil
}

private func ephemeralReplyTargetBotPeerId(transaction: Transaction, accountPeerId: PeerId, replySubject: EngineMessageReplySubject) -> PeerId? {
    guard replySubject.messageId.namespace == Namespaces.Message.EphemeralLocal, replySubject.messageId.id > 0, let replyMessage = transaction.getMessage(replySubject.messageId) else {
        return nil
    }

    if replyMessage.flags.contains(.Incoming) {
        guard let authorId = replyMessage.author?.id, authorId != accountPeerId else {
            return nil
        }
        return authorId
    }

    if let attribute = replyMessage.attributes.first(where: { $0 is EphemeralMessageAttribute }) as? EphemeralMessageAttribute, attribute.receiverId != 0 {
        return PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(attribute.receiverId))
    }

    return nil
}

private func ephemeralBotPeerIdForEnqueuedMessage(transaction: Transaction, accountPeerId: PeerId, message: EnqueueMessage) -> PeerId? {
    switch message {
    case let .message(_, attributes, _, _, _, replyToMessageId, _, _, _, _):
        if let attribute = transientEphemeralOutgoingAttribute(attributes) {
            return attribute.botPeerId
        }
        if let replyToMessageId, replyToMessageId.messageId.namespace == Namespaces.Message.EphemeralLocal {
            return ephemeralReplyTargetBotPeerId(transaction: transaction, accountPeerId: accountPeerId, replySubject: replyToMessageId)
        }
        return nil
    case .forward:
        return nil
    }
}

private func replyMessageAttributeForEphemeralOutgoingMessage(transaction: Transaction, peerId: PeerId, replySubject: EngineMessageReplySubject?) -> ReplyMessageAttribute? {
    guard let replySubject else {
        return nil
    }

    if replySubject.messageId.namespace == Namespaces.Message.EphemeralLocal {
        guard replySubject.messageId.id > 0 else {
            return nil
        }
        return ReplyMessageAttribute(messageId: replySubject.messageId, threadMessageId: nil, quote: nil, isQuote: false, innerSubject: nil)
    }

    guard replySubject.messageId.namespace == Namespaces.Message.Cloud else {
        return nil
    }

    var threadMessageId: MessageId?
    var quote = replySubject.quote
    let isQuote = quote != nil
    if let replyMessage = transaction.getMessage(replySubject.messageId) {
        if replyMessage.id.namespace == Namespaces.Message.Cloud, let threadId = replyMessage.threadId {
            threadMessageId = MessageId(peerId: replyMessage.id.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))
        }
        if quote == nil, replySubject.messageId.peerId != peerId {
            let nsText = replyMessage.text as NSString
            var replyMedia: Media?
            for media in replyMessage.media {
                switch media {
                case _ as TelegramMediaImage, _ as TelegramMediaFile:
                    replyMedia = media
                default:
                    break
                }
            }
            quote = EngineMessageReplyQuote(text: replyMessage.text, offset: nil, entities: messageTextEntitiesInRange(entities: replyMessage.textEntitiesAttribute?.entities ?? [], range: NSRange(location: 0, length: nsText.length), onlyQuoteable: true), media: replyMedia)
        }
    }

    return ReplyMessageAttribute(messageId: replySubject.messageId, threadMessageId: threadMessageId, quote: quote, isQuote: isQuote, innerSubject: replySubject.innerSubject)
}

private func generateEphemeralOutgoingRandomId() -> Int64 {
    while true {
        let value = Int64.random(in: Int64.min ... Int64.max)
        if value != 0 {
            return value
        }
    }
}

private func enqueueEphemeralOutgoingMessage(transaction: Transaction, account: Account, peerId: PeerId, transformedMedia: Bool, message: EnqueueMessage, botPeerId: PeerId, isWelcomeTemplate: Bool = false) -> MessageId? {
    guard case let .message(text, requestedAttributes, inlineStickers, mediaReference, threadId, replyToMessageId, _, _, correlationId, bubbleUpEmojiOrStickersets) = message else {
        return nil
    }
    guard transaction.getPeer(peerId).flatMap(apiInputPeer) != nil else {
        return nil
    }
    if !isWelcomeTemplate && transaction.getPeer(botPeerId).flatMap(apiInputUser) == nil {
        return nil
    }

    for (_, file) in inlineStickers {
        transaction.storeMediaIfNotPresent(media: file)
    }

    var flags = StoreMessageFlags()
    flags.insert(.Sending)
    if isWelcomeTemplate {
        flags.insert(.Incoming)
    }

    let randomId = generateEphemeralOutgoingRandomId()
    var infoFlags = OutgoingMessageInfoFlags()
    if transformedMedia {
        infoFlags.insert(.transformedMedia)
    }

    var partialReference: PartialMediaReference?
    if let mediaReference {
        partialReference = mediaReference.partial
    }

    var attributes: [MessageAttribute] = filterMessageAttributesForEphemeralOutgoingMessage(requestedAttributes)
    attributes.append(OutgoingMessageInfoAttribute(uniqueId: randomId, flags: infoFlags, acknowledged: false, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets, partialReference: partialReference))
    attributes.append(EphemeralOutgoingMessageAttribute(botPeerId: botPeerId, randomId: randomId, state: .sending, isWelcomeTemplate: isWelcomeTemplate))

    if let replyAttribute = replyMessageAttributeForEphemeralOutgoingMessage(transaction: transaction, peerId: peerId, replySubject: replyToMessageId) {
        attributes.append(replyAttribute)
    }

    var mediaList: [Media] = []
    if let mediaReference {
        mediaList.append(augmentMediaWithReference(mediaReference))
    }

    if let file = mediaReference?.media as? TelegramMediaFile, file.isVoice || file.isInstantVideo {
        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup {
            attributes.append(ConsumableContentMessageAttribute(consumed: false))
        }
    }

    let localId = generateEphemeralLocalMessageId(peerId: peerId, transaction: transaction, namespace: isWelcomeTemplate ? Namespaces.Message.WelcomeMessageLocal : Namespaces.Message.EphemeralLocal)
    var timestamp = Int32(account.network.context.globalTime())
    if isWelcomeTemplate {
        timestamp += 1
    }
    let storeMessage = StoreMessage(id: localId, customStableId: nil, globallyUniqueId: randomId, groupingKey: nil, threadId: threadId, timestamp: timestamp, flags: flags, tags: [], globalTags: [], localTags: [], forwardInfo: nil, authorId: isWelcomeTemplate ? peerId : account.peerId, text: text, attributes: attributes, media: mediaList)
    let _ = transaction.addMessages([storeMessage], location: .Random)

    return localId
}

private func filterMessageAttributesForForwardedMessage(_ attributes: [MessageAttribute], forwardedMessageIds: Set<MessageId>? = nil) -> [MessageAttribute] {
    return attributes.filter { attribute in
        switch attribute {
            case _ as TextEntitiesMessageAttribute:
                return true
            case _ as RichTextMessageAttribute:
                return true
            case _ as InlineBotMessageAttribute:
                return true
            case _ as NotificationInfoMessageAttribute:
                return true
            case _ as OutgoingScheduleInfoMessageAttribute:
                return true
            case _ as OutgoingQuickReplyMessageAttribute:
                return true
            case _ as ForwardOptionsMessageAttribute:
                return true
            case _ as SendAsMessageAttribute:
                return true
            case _ as MediaSpoilerMessageAttribute:
                return true
            case _ as InvertMediaMessageAttribute:
                return true
            case _ as PaidStarsMessageAttribute:
                return true
            case let attribute as ReplyMessageAttribute:
                if attribute.quote != nil {
                    return true
                }
                if let forwardedMessageIds = forwardedMessageIds {
                    return forwardedMessageIds.contains(attribute.messageId)
                } else {
                    return false
                }
            default:
                return false
        }
    }
}

func opportunisticallyTransformMessageWithMedia(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia, mediaReference: AnyMediaReference, userInteractive: Bool) -> Signal<AnyMediaReference?, NoError> {
    return transformOutgoingMessageMedia(postbox, network, mediaReference, userInteractive)
    |> timeout(2.0, queue: Queue.concurrentDefaultQueue(), alternate: .single(nil))
}

private func forwardedMessageToBeReuploaded(transaction: Transaction, id: MessageId) -> Message? {
    if let message = transaction.getMessage(id) {
        if message.id.namespace != Namespaces.Message.Cloud && !Namespaces.Message.allEphemeral.contains(message.id.namespace) {
            return message
        } else {
            return nil
        }
    } else {
        return nil
    }
}

private func opportunisticallyTransformOutgoingMedia(network: Network, postbox: Postbox, transformOutgoingMessageMedia: TransformOutgoingMessageMedia, messages: [EnqueueMessage], userInteractive: Bool) -> Signal<[(Bool, EnqueueMessage)], NoError> {
    var hasMedia = false
    loop: for message in messages {
        switch message {
            case let .message(_, _, _, mediaReference, _, _, _, _, _, _):
                if mediaReference != nil {
                    hasMedia = true
                    break loop
                }
            case .forward:
                break
        }
    }
    
    if !hasMedia {
        return .single(messages.map { (true, $0) })
    }
    
    var signals: [Signal<(Bool, EnqueueMessage), NoError>] = []
    for message in messages {
        switch message {
            case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
                if let mediaReference = mediaReference {
                    signals.append(opportunisticallyTransformMessageWithMedia(network: network, postbox: postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, mediaReference: mediaReference, userInteractive: userInteractive)
                    |> map { result -> (Bool, EnqueueMessage) in
                        return (result != nil, .message(text: text, attributes: attributes, inlineStickers: inlineStickers, mediaReference: result ?? mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets))
                    })
                } else {
                    signals.append(.single((false, message)))
                }
            case .forward:
                signals.append(.single((false, message)))
        }
    }
    return combineLatest(signals)
}

public func enqueueMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {
    let signal: Signal<[(Bool, EnqueueMessage)], NoError>
    if let transformOutgoingMessageMedia = account.transformOutgoingMessageMedia {
        signal = opportunisticallyTransformOutgoingMedia(network: account.network, postbox: account.postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messages: messages, userInteractive: true)
    } else {
        signal = .single(messages.map { (false, $0) })
    }
    return signal
    |> mapToSignal { messages -> Signal<[MessageId?], NoError> in
        return account.postbox.transaction { transaction -> ([MessageId?], [MessageId]) in
            var resultIds = Array<MessageId?>(repeating: nil, count: messages.count)
            var ephemeralMessageIds: [MessageId] = []
            var normalMessages: [(Bool, EnqueueMessage)] = []
            var normalMessageIndices: [Int] = []

            for i in 0 ..< messages.count {
                let (transformedMedia, message) = messages[i]
                if let botPeerId = ephemeralBotPeerIdForEnqueuedMessage(transaction: transaction, accountPeerId: account.peerId, message: message) {
                    if let messageId = enqueueEphemeralOutgoingMessage(transaction: transaction, account: account, peerId: peerId, transformedMedia: transformedMedia, message: message, botPeerId: botPeerId) {
                        resultIds[i] = messageId
                        ephemeralMessageIds.append(messageId)
                    }
                } else {
                    normalMessages.append((transformedMedia, message))
                    normalMessageIndices.append(i)
                }
            }

            if !normalMessages.isEmpty {
                let normalIds = enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: normalMessages)
                for i in 0 ..< min(normalIds.count, normalMessageIndices.count) {
                    resultIds[normalMessageIndices[i]] = normalIds[i]
                }
            }

            return (resultIds, ephemeralMessageIds)
        }
        |> map { resultIds, ephemeralMessageIds -> [MessageId?] in
            for messageId in ephemeralMessageIds {
                let _ = _internal_sendEphemeralOutgoingMessage(account: account, messageId: messageId).startStandalone()
            }
            return resultIds
        }
    }
}

public func enqueueWelcomeMessages(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError> {
    let signal: Signal<[(Bool, EnqueueMessage)], NoError>
    if let transformOutgoingMessageMedia = account.transformOutgoingMessageMedia {
        signal = opportunisticallyTransformOutgoingMedia(network: account.network, postbox: account.postbox, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messages: messages, userInteractive: true)
    } else {
        signal = .single(messages.map { (false, $0) })
    }
    return signal
    |> mapToSignal { messages -> Signal<[MessageId?], NoError> in
        return account.postbox.transaction { transaction -> ([MessageId?], [MessageId]) in
            var resultIds = Array<MessageId?>(repeating: nil, count: messages.count)
            var pendingMessageIds: [MessageId] = []
            for i in 0 ..< messages.count {
                let (transformedMedia, message) = messages[i]
                if let messageId = enqueueEphemeralOutgoingMessage(transaction: transaction, account: account, peerId: peerId, transformedMedia: transformedMedia, message: message, botPeerId: peerId, isWelcomeTemplate: true) {
                    resultIds[i] = messageId
                    pendingMessageIds.append(messageId)
                }
            }
            return (resultIds, pendingMessageIds)
        }
        |> map { resultIds, pendingMessageIds -> [MessageId?] in
            for messageId in pendingMessageIds {
                let _ = _internal_sendEphemeralOutgoingMessage(account: account, messageId: messageId).startStandalone()
            }
            return resultIds
        }
    }
}

public func resendMessages(account: Account, messageIds: [MessageId]) -> Signal<Void, NoError> {
    return account.postbox.transaction { transaction -> Void in
        var removeMessageIds: [MessageId] = []
        for (peerId, ids) in messagesIdsGroupedByPeerId(messageIds) {
            var sendPaidMessageStars: StarsAmount?
            let peer = transaction.getPeer(peerId)
            if let user = peer as? TelegramUser, user.flags.contains(.requireStars) {
                if let cachedUserData = transaction.getPeerCachedData(peerId: user.id) as? CachedUserData {
                    sendPaidMessageStars = cachedUserData.sendPaidMessageStars
                }
            } else if let channel = peer as? TelegramChannel {
                if channel.flags.contains(.isCreator) || channel.adminRights != nil {
                } else {
                    sendPaidMessageStars = channel.sendPaidMessageStars
                }
            }
            
            var messages: [EnqueueMessage] = []
            for id in ids {
                if let message = transaction.getMessage(id), !message.flags.contains(.Incoming) {
                    removeMessageIds.append(id)
                    
                    var filteredAttributes: [MessageAttribute] = []
                    var replyToMessageId: EngineMessageReplySubject?
                    var replyToStoryId: StoryId?
                    var bubbleUpEmojiOrStickersets: [ItemCollectionId] = []
                    var forwardSource: MessageId?
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? ReplyMessageAttribute {
                            replyToMessageId = EngineMessageReplySubject(messageId: attribute.messageId, quote: attribute.quote, innerSubject: attribute.innerSubject)
                        } else if let attribute = attribute as? ReplyStoryAttribute {
                            replyToStoryId = attribute.storyId
                        } else if let attribute = attribute as? OutgoingMessageInfoAttribute {
                            bubbleUpEmojiOrStickersets = attribute.bubbleUpEmojiOrStickersets
                            continue inner
                        } else if let attribute = attribute as? ForwardSourceInfoAttribute {
                            forwardSource = attribute.messageId
                        } else if let attribute = resentMessageRequestedAttribute(attribute, isSecretChat: peerId.namespace == Namespaces.Peer.SecretChat) {
                            filteredAttributes.append(attribute)
                        }
                    }
                    
                    if let sendPaidMessageStars {
                        filteredAttributes.append(PaidStarsMessageAttribute(stars: sendPaidMessageStars, postponeSending: false))
                    }

                    if let forwardSource = forwardSource {
                        messages.append(.forward(source: forwardSource, threadId: nil, grouping: .auto, attributes: filteredAttributes, correlationId: nil))
                    } else {
                        messages.append(.message(text: message.text, attributes: filteredAttributes, inlineStickers: [:], mediaReference: message.media.first.flatMap(AnyMediaReference.standalone), threadId: message.threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: message.groupingKey, correlationId: nil, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets))
                    }
                }
            }
            let _ = enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: messages.map { (false, $0) })
        }
        _internal_deleteMessages(transaction: transaction, mediaBox: account.postbox.mediaBox, ids: removeMessageIds, deleteMedia: false)
    }
}

func enqueueMessages(transaction: Transaction, account: Account, peerId: PeerId, messages: [(Bool, EnqueueMessage)], disableAutoremove: Bool = false, transformGroupingKeysWithPeerId: Bool = false) -> [MessageId?] {
    /**
     * If it is a support account, mark messages as read here as they are
     * not marked as read when chat is opened.
     **/
    if account.isSupportUser {
        let namespace: MessageId.Namespace
        if peerId.namespace == Namespaces.Peer.SecretChat {
            namespace = Namespaces.Message.SecretIncoming
        } else {
            namespace = Namespaces.Message.Cloud
        }
        if let index = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: namespace) {
            let _ = transaction.applyInteractiveReadMaxIndex(index)
        }
    }
    
    var forwardedMessageIds = Set<MessageId>()
    for (_, message) in messages {
        if case let .forward(sourceId, _, _, _, _) = message {
            forwardedMessageIds.insert(sourceId)
        }
    }
    
    var localGroupingKeyBySourceKey: [Int64: Int64] = [:]
    
    var updatedMessages: [(Bool, EnqueueMessage)] = []
    outer: for (transformedMedia, message) in messages {
        var updatedMessage = message
        if transformGroupingKeysWithPeerId {
            updatedMessage = updatedMessage.withUpdatedGroupingKey { groupingKey -> Int64? in
                if let groupingKey = groupingKey {
                    return groupingKey &+ peerId.toInt64()
                } else {
                    return nil
                }
            }
        }
        
        switch message {
            case let .message(_, attributes, _, _, threadId, replyToMessageId, _, _, _, _):
                if let replyToMessageId = replyToMessageId, (replyToMessageId.messageId.peerId != peerId && peerId.namespace == Namespaces.Peer.SecretChat), let replyMessage = transaction.getMessage(replyToMessageId.messageId) {
                    var canBeForwarded = true
                    if replyMessage.id.namespace != Namespaces.Message.Cloud {
                        canBeForwarded = false
                    }
                    inner: for media in replyMessage.media {
                        if media is TelegramMediaAction {
                            canBeForwarded = false
                            break inner
                        }
                    }
                    if canBeForwarded {
                        updatedMessages.append((true, .forward(source: replyToMessageId.messageId, threadId: threadId, grouping: .none, attributes: attributes, correlationId: nil)))
                    }
                }
            case let .forward(sourceId, threadId, grouping, forwardAttributes, _):
                if let sourceMessage = forwardedMessageToBeReuploaded(transaction: transaction, id: sourceId) {
                    var mediaReference: AnyMediaReference?
                    if sourceMessage.id.peerId.namespace == Namespaces.Peer.SecretChat {
                        if let media = sourceMessage.media.first {
                            mediaReference = .standalone(media: media)
                        }
                    }
                    var text = sourceMessage.text
                    var hidesCaption = false
                    if let media = mediaReference?.media, media is TelegramMediaImage || media is TelegramMediaFile, forwardAttributes.contains(where: { ($0 as? ForwardOptionsMessageAttribute)?.hideCaptions == true }) {
                        text = ""
                        hidesCaption = true
                    }
                    updatedMessages.append((transformedMedia, .message(text: text, attributes: forwardCopyRequestedAttributes(sourceAttributes: sourceMessage.attributes, forwardAttributes: forwardAttributes, hidesCaption: hidesCaption), inlineStickers: [:], mediaReference: mediaReference, threadId: threadId, replyToMessageId: threadId.flatMap { EngineMessageReplySubject(messageId: MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: $0)), quote: nil, innerSubject: nil) }, replyToStoryId: nil, localGroupingKey: forwardGroupingKey(grouping: grouping, sourceGroupingKey: sourceMessage.groupingKey, generatedKeys: &localGroupingKeyBySourceKey), correlationId: nil, bubbleUpEmojiOrStickersets: [])))
                    continue outer
                }
        }
        updatedMessages.append((transformedMedia, updatedMessage))
    }
    
    if let peer = transaction.getPeer(peerId), let accountPeer = transaction.getPeer(account.peerId) {
        let peerPresence = transaction.getPeerPresence(peerId: peerId)
        
        var storeMessages: [StoreMessage] = []
        var timestamp = Int32(account.network.context.globalTime())
        switch peerId.namespace {
            case Namespaces.Peer.CloudChannel, Namespaces.Peer.CloudGroup, Namespaces.Peer.CloudUser:
                if let topIndex = transaction.getTopPeerMessageIndex(peerId: peerId, namespace: Namespaces.Message.Cloud) {
                    timestamp = max(timestamp, topIndex.timestamp)
                }
            default:
                break
        }
        
        var addedHashtags: [String] = []
        var emojiItems: [RecentEmojiItem] = []
        
        var globallyUniqueIds: [Int64] = []
        for (transformedMedia, message) in updatedMessages {
            if case let .message(_, requestedAttributes, _, _, _, replyToMessageId, _, _, _, _) = message {
                if requestedAttributes.contains(where: { $0 is EphemeralOutgoingMessageAttribute }) {
                    assertionFailure("Ephemeral outgoing messages must be routed before normal enqueue")
                    continue
                }
                if replyToMessageId?.messageId.namespace == Namespaces.Message.EphemeralLocal {
                    assertionFailure("Normal outgoing messages must not reply to EphemeralLocal")
                    continue
                }
            } else if case let .forward(_, _, _, requestedAttributes, _) = message, requestedAttributes.contains(where: { $0 is EphemeralOutgoingMessageAttribute }) {
                assertionFailure("Ephemeral outgoing forwards are not supported")
                continue
            }

            var attributes: [MessageAttribute] = []
            var flags = StoreMessageFlags()
            flags.insert(.Unsent)
            
            var randomId: Int64 = 0
            arc4random_buf(&randomId, 8)
            var infoFlags = OutgoingMessageInfoFlags()
            if transformedMedia {
                infoFlags.insert(.transformedMedia)
            }
            
            var partialReference: PartialMediaReference?
            if case let .message(_, _, _, mediaReference, _, _, _, _, _, _) = message {
                partialReference = mediaReference?.partial
            }
            attributes.append(OutgoingMessageInfoAttribute(uniqueId: randomId, flags: infoFlags, acknowledged: false, correlationId: message.correlationId, bubbleUpEmojiOrStickersets: message.bubbleUpEmojiOrStickersets, partialReference: partialReference))
            globallyUniqueIds.append(randomId)
            
            switch message {
                case let .message(text, requestedAttributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, _, _):
                    for (_, file) in inlineStickers {
                        transaction.storeMediaIfNotPresent(media: file)
                    }
                
                    for emoji in text.emojis {
                        if emoji.isSingleEmoji {
                            if !emojiItems.contains(where: { $0.content == .text(emoji) }) {
                                emojiItems.append(RecentEmojiItem(.text(emoji)))
                            }
                        }
                    }
                
                    var peerAutoremoveTimeout: Int32?
                    if let peer = peer as? TelegramSecretChat {
                        var isAction = false
                        if let _ = mediaReference?.media as? TelegramMediaAction {
                            isAction = true
                        }
                        if !disableAutoremove, let messageAutoremoveTimeout = peer.messageAutoremoveTimeout, !isAction {
                            peerAutoremoveTimeout = messageAutoremoveTimeout
                        }
                    } else if let cachedData = transaction.getPeerCachedData(peerId: peer.id), !disableAutoremove {
                        var isScheduled = false
                        for attribute in requestedAttributes {
                            if let _ = attribute as? OutgoingScheduleInfoMessageAttribute {
                                isScheduled = true
                            }
                        }
                        
                        if !isScheduled {
                            var messageAutoremoveTimeout: Int32?
                            if let cachedData = cachedData as? CachedUserData {
                                if case let .known(value) = cachedData.autoremoveTimeout {
                                    messageAutoremoveTimeout = value?.effectiveValue
                                }
                            } else if let cachedData = cachedData as? CachedGroupData {
                                if case let .known(value) = cachedData.autoremoveTimeout {
                                    messageAutoremoveTimeout = value?.effectiveValue
                                }
                            } else if let cachedData = cachedData as? CachedChannelData {
                                if case let .known(value) = cachedData.autoremoveTimeout {
                                    messageAutoremoveTimeout = value?.effectiveValue
                                }
                            }
                            
                            if let messageAutoremoveTimeout = messageAutoremoveTimeout {
                                peerAutoremoveTimeout = messageAutoremoveTimeout
                            }
                        }
                    }
                    
                    attributes.append(contentsOf: outgoingMessageAttributes(requestedAttributes: requestedAttributes, isSecretChat: peer is TelegramSecretChat, peerAutoremoveTimeout: peerAutoremoveTimeout))

                    if let replyToMessageId = replyToMessageId {
                        var threadMessageId: MessageId?
                        var quote = replyToMessageId.quote
                        let isQuote = quote != nil
                        if let replyMessage = transaction.getMessage(replyToMessageId.messageId) {
                            if replyMessage.id.namespace == Namespaces.Message.Cloud, let threadId = replyMessage.threadId {
                                threadMessageId = MessageId(peerId: replyMessage.id.peerId, namespace: Namespaces.Message.Cloud, id: Int32(clamping: threadId))
                            }
                            if quote == nil, replyToMessageId.messageId.peerId != peerId {
                                let nsText = replyMessage.text as NSString
                                var replyMedia: Media?
                                for m in replyMessage.media {
                                    switch m {
                                    case _ as TelegramMediaImage, _ as TelegramMediaFile:
                                        replyMedia = m
                                    default:
                                        break
                                    }
                                }
                                quote = EngineMessageReplyQuote(text: replyMessage.text, offset: nil, entities: messageTextEntitiesInRange(entities: replyMessage.textEntitiesAttribute?.entities ?? [], range: NSRange(location: 0, length: nsText.length), onlyQuoteable: true), media: replyMedia)
                            }
                        }
                        attributes.append(ReplyMessageAttribute(messageId: replyToMessageId.messageId, threadMessageId: threadMessageId, quote: quote, isQuote: isQuote, innerSubject: replyToMessageId.innerSubject))
                    }
                    if let replyToStoryId = replyToStoryId {
                        attributes.append(ReplyStoryAttribute(storyId: replyToStoryId))
                    }
                    var mediaList: [Media] = []
                    if let mediaReference = mediaReference {
                        let augmentedMedia = augmentMediaWithReference(mediaReference)
                        mediaList.append(augmentedMedia)
                    }
                    
                    if let file = mediaReference?.media as? TelegramMediaFile, file.isVoice || file.isInstantVideo {
                        if peerId.namespace == Namespaces.Peer.CloudUser || peerId.namespace == Namespaces.Peer.CloudGroup || peerId.namespace == Namespaces.Peer.SecretChat {
                            attributes.append(ConsumableContentMessageAttribute(consumed: false))
                        }
                    }
                    
                    var entitiesAttribute: TextEntitiesMessageAttribute?
                    for attribute in attributes {
                        if let attribute = attribute as? TextEntitiesMessageAttribute {
                            entitiesAttribute = attribute
                            var maybeNsText: NSString?
                            for entity in attribute.entities {
                                if case .Hashtag = entity.type {
                                    let nsText: NSString
                                    if let maybeNsText = maybeNsText {
                                        nsText = maybeNsText
                                    } else {
                                        nsText = text as NSString
                                        maybeNsText = nsText
                                    }
                                    var entityRange = NSRange(location: entity.range.lowerBound, length: entity.range.upperBound - entity.range.lowerBound)
                                    if entityRange.location + entityRange.length > nsText.length {
                                        entityRange.location = max(0, nsText.length - entityRange.length)
                                        entityRange.length = nsText.length - entityRange.location
                                    }
                                    if entityRange.length > 1 {
                                        entityRange.location += 1
                                        entityRange.length -= 1
                                        let hashtag = nsText.substring(with: entityRange)
                                        addedHashtags.append(hashtag)
                                    }
                                } else if case let .CustomEmoji(_, fileId) = entity.type {
                                    let mediaId = MediaId(namespace: Namespaces.Media.CloudFile, id: fileId)
                                    if let file = inlineStickers[mediaId] as? TelegramMediaFile {
                                        emojiItems.append(RecentEmojiItem(.file(file)))
                                    } else if let file = transaction.getMedia(mediaId) as? TelegramMediaFile {
                                        emojiItems.append(RecentEmojiItem(.file(file)))
                                    }
                                }
                            }
                            break
                        }
                    }
                                    
                    let (tags, globalTags) = tagsForStoreMessage(incoming: false, attributes: attributes, media: mediaList, textEntities: entitiesAttribute?.entities, isPinned: false)
                    
                    var localTags: LocalMessageTags = []
                    for media in mediaList {
                        if let media = media as? TelegramMediaMap, media.liveBroadcastingTimeout != nil {
                            localTags.insert(.OutgoingLiveLocation)
                        }
                    }
                    
                    var messageNamespace = Namespaces.Message.Local
                    var effectiveTimestamp = timestamp
                    var sendAsPeer: Peer?
                    for attribute in attributes {
                        if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                            if attribute.scheduleTime == scheduleWhenOnlineTimestamp, let presence = peerPresence as? TelegramUserPresence, case let .present(statusTimestamp) = presence.status, statusTimestamp >= timestamp {
                            } else {
                                messageNamespace = Namespaces.Message.ScheduledLocal
                                effectiveTimestamp = attribute.scheduleTime
                            }
                        } else if attribute is OutgoingQuickReplyMessageAttribute {
                            messageNamespace = Namespaces.Message.QuickReplyLocal
                            effectiveTimestamp = 0
                        } else if let attribute = attribute as? SendAsMessageAttribute {
                            if let peer = transaction.getPeer(attribute.peerId) {
                                sendAsPeer = peer
                            }
                        }
                    }
                
                    var authorId: PeerId?
                    if let sendAsPeer = sendAsPeer {
                        if let peer = peer as? TelegramChannel, case let .broadcast(info) = peer.info {
                            if info.flags.contains(.messagesShouldHaveProfiles) {
                                authorId = sendAsPeer.id
                            } else {
                                authorId = peer.id
                            }
                        } else {
                            authorId = sendAsPeer.id
                        }
                    } else if let peer = peer as? TelegramChannel {
                        if case .broadcast = peer.info {
                            authorId = peer.id
                        } else if case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
                            authorId = peer.id
                        } else {
                            authorId = account.peerId
                        }
                    }  else {
                        authorId = account.peerId
                    }
                    
                    if messageNamespace != Namespaces.Message.ScheduledLocal {
                        attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                    }
                    if messageNamespace != Namespaces.Message.QuickReplyLocal {
                        attributes.removeAll(where: { $0 is OutgoingQuickReplyMessageAttribute })
                    }
                                        
                    if let peer = peer as? TelegramChannel {
                        switch peer.info {
                            case let .broadcast(info):
                                if messageNamespace != Namespaces.Message.ScheduledLocal && messageNamespace != Namespaces.Message.QuickReplyLocal {
                                    attributes.append(ViewCountMessageAttribute(count: 1))
                                }
                                if info.flags.contains(.messagesShouldHaveProfiles) {
                                    if sendAsPeer == nil {
                                        authorId = account.peerId
                                    }
                                }
                                if info.flags.contains(.messagesShouldHaveSignatures) {
                                    if let sendAsPeer {
                                        if sendAsPeer.id == peerId {
                                        } else {
                                            attributes.append(AuthorSignatureMessageAttribute(signature: sendAsPeer.debugDisplayTitle))
                                        }
                                    } else {
                                        attributes.append(AuthorSignatureMessageAttribute(signature: accountPeer.debugDisplayTitle))
                                    }
                                }
                            case .group:
                                break
                        }
                    }
                    
                    var threadId: Int64? = threadId
                    if threadId == nil {
                        if let replyToMessageId = replyToMessageId {
                            if let message = transaction.getMessage(replyToMessageId.messageId) {
                                if let threadIdValue = message.threadId {
                                    if threadIdValue == 1 {
                                        if let peer = transaction.getPeer(message.id.peerId), peer.isForum {
                                            threadId = threadIdValue
                                        } else {
                                            if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info {
                                                threadId = Int64(replyToMessageId.messageId.id)
                                            }
                                        }
                                    } else {
                                        threadId = threadIdValue
                                    }
                                } else if let channel = message.peers[message.id.peerId] as? TelegramChannel, case .group = channel.info {
                                    threadId = Int64(replyToMessageId.messageId.id)
                                }
                            }
                        }
                    }
                
                    if threadId == nil, let peer = transaction.getPeer(peerId), (peer is TelegramChannel), peer.isForum {
                        threadId = 1
                    }
                    
                    storeMessages.append(StoreMessage(peerId: peerId, namespace: messageNamespace, customStableId: nil, globallyUniqueId: randomId, groupingKey: localGroupingKey, threadId: threadId, timestamp: effectiveTimestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: localTags, forwardInfo: nil, authorId: authorId, text: text, attributes: attributes, media: mediaList))
                case let .forward(source, threadId, grouping, requestedAttributes, _):
                    let sourceMessage = transaction.getMessage(source)
                    if let sourceMessage = sourceMessage, let author = sourceMessage.author ?? sourceMessage.peers[sourceMessage.id.peerId] {
                        var messageText = sourceMessage.text
                        
                        if let peer = peer as? TelegramSecretChat {
                            var isAction = false
                            for media in sourceMessage.media {
                                if let _ = media as? TelegramMediaAction {
                                    isAction = true
                                }
                            }
                            if !disableAutoremove, let messageAutoremoveTimeout = peer.messageAutoremoveTimeout, !isAction {
                                attributes.append(AutoremoveTimeoutMessageAttribute(timeout: messageAutoremoveTimeout, countdownBeginTime: nil))
                            }
                        } else if let cachedData = transaction.getPeerCachedData(peerId: peer.id), !disableAutoremove {
                            var isScheduled = false
                            for attribute in attributes {
                                if let _ = attribute as? OutgoingScheduleInfoMessageAttribute {
                                    isScheduled = true
                                    break
                                }
                            }
                            
                            if !isScheduled {
                                var messageAutoremoveTimeout: Int32?
                                if let cachedData = cachedData as? CachedUserData {
                                    if case let .known(value) = cachedData.autoremoveTimeout {
                                        messageAutoremoveTimeout = value?.effectiveValue
                                    }
                                } else if let cachedData = cachedData as? CachedGroupData {
                                    if case let .known(value) = cachedData.autoremoveTimeout {
                                        messageAutoremoveTimeout = value?.effectiveValue
                                    }
                                } else if let cachedData = cachedData as? CachedChannelData {
                                    if case let .known(value) = cachedData.autoremoveTimeout {
                                        messageAutoremoveTimeout = value?.effectiveValue
                                    }
                                }
                                
                                if let messageAutoremoveTimeout = messageAutoremoveTimeout {
                                    attributes.append(AutoremoveTimeoutMessageAttribute(timeout: messageAutoremoveTimeout, countdownBeginTime: nil))
                                }
                            }
                        }
                        
                        var forwardInfo: StoreMessageForwardInfo?
                        
                        var hideSendersNames = false
                        var hideCaptions = false
                        for attribute in requestedAttributes {
                            if let attribute = attribute as? ForwardOptionsMessageAttribute {
                                hideSendersNames = attribute.hideNames
                                hideCaptions = attribute.hideCaptions
                                break
                            }
                        }
                        
                        var hidesCaption = false
                        if hideCaptions {
                            for media in sourceMessage.media {
                                if media is TelegramMediaImage || media is TelegramMediaFile {
                                    messageText = ""
                                    hidesCaption = true
                                    break
                                }
                            }
                        }
                        
                        if (sourceMessage.id.namespace == Namespaces.Message.Cloud || Namespaces.Message.allEphemeral.contains(sourceMessage.id.namespace)) && peerId.namespace != Namespaces.Peer.SecretChat {
                            attributes.append(ForwardSourceInfoAttribute(messageId: sourceMessage.id))
                        
                            if sourceMessage.id.namespace == Namespaces.Message.Cloud && peerId == account.peerId {
                                attributes.append(SourceReferenceMessageAttribute(messageId: sourceMessage.id))
                            }
                            
                            attributes.append(contentsOf: forwardedMessageAttributes(requestedAttributes: requestedAttributes, sourceAttributes: sourceMessage.attributes, forwardedMessageIds: forwardedMessageIds))

                            let ephemeralParams = ephemeralForwardParams(sourceMessage)
                            let ephemeralBotPeerId = ephemeralParams?.botPeerId
                            if sourceMessage.id.namespace == Namespaces.Message.EphemeralLocal {
                                attributes.removeAll(where: { $0 is InlineBotMessageAttribute })
                            } else if sourceMessage.id.namespace == Namespaces.Message.EphemeralAnchored, let inlineBotPeerId = ephemeralParams?.inlineBotPeerId, !attributes.contains(where: { $0 is InlineBotMessageAttribute }) {
                                attributes.append(InlineBotMessageAttribute(peerId: inlineBotPeerId, title: nil))
                            }
                            
                            var sourceReplyMarkup: ReplyMarkupMessageAttribute? = nil
                            var sourceSentViaBot = ephemeralBotPeerId != nil
                            for attribute in attributes {
                                if let attribute = attribute as? ReplyMarkupMessageAttribute {
                                    sourceReplyMarkup = attribute
                                } else if let _ = attribute as? InlineBotMessageAttribute {
                                    sourceSentViaBot = true
                                }
                            }
                            
                            if let sourceReplyMarkup = sourceReplyMarkup {
                                var rows: [ReplyMarkupRow] = []
                                loop: for row in sourceReplyMarkup.rows {
                                    var buttons: [ReplyMarkupButton] = []
                                    for button in row.buttons {
                                        if case .url = button.action {
                                            buttons.append(button)
                                        } else if case .urlAuth = button.action {
                                            buttons.append(button)
                                        } else if case let .switchInline(samePeer, query, peerTypes) = button.action, sourceSentViaBot {
                                            let samePeer = samePeer && peerId == sourceMessage.id.peerId
                                            let updatedButton = ReplyMarkupButton(title: button.titleWhenForwarded ?? button.title, titleWhenForwarded: button.titleWhenForwarded,  action: .switchInline(samePeer: samePeer, query: query, peerTypes: peerTypes), style: button.style)
                                            buttons.append(updatedButton)
                                        } else {
                                            rows.removeAll()
                                            break loop
                                        }
                                    }
                                    rows.append(ReplyMarkupRow(buttons: buttons))
                                }
                                
                                if !rows.isEmpty {
                                    attributes.append(ReplyMarkupMessageAttribute(rows: rows, flags: sourceReplyMarkup.flags, placeholder: sourceReplyMarkup.placeholder))
                                }
                            }
                            
                            if hideSendersNames {
                                
                            } else if sourceMessage.id.namespace == Namespaces.Message.EphemeralLocal {
                                forwardInfo = StoreMessageForwardInfo(authorId: ephemeralParams?.authorId ?? author.id, sourceId: nil, sourceMessageId: nil, date: sourceMessage.timestamp, authorSignature: nil, psaType: nil, flags: [])
                            } else if let sourceForwardInfo = sourceMessage.forwardInfo {
                                forwardInfo = StoreMessageForwardInfo(authorId: sourceForwardInfo.author?.id, sourceId: sourceForwardInfo.source?.id, sourceMessageId: sourceForwardInfo.sourceMessageId, date: sourceForwardInfo.date, authorSignature: sourceForwardInfo.authorSignature, psaType: nil, flags: [])
                            } else {
                                if sourceMessage.id.peerId != account.peerId {
                                    var sourceId = ephemeralParams?.sourceId
                                    var sourceMessageId = ephemeralParams?.sourceMessageId
                                    if ephemeralParams == nil, case let .channel(peer) = messageMainPeer(EngineMessage(sourceMessage)), case .broadcast = peer.info {
                                        sourceId = peer.id
                                        sourceMessageId = sourceMessage.id
                                    }

                                    var authorSignature: String?
                                    for attribute in sourceMessage.attributes {
                                        if let attribute = attribute as? AuthorSignatureMessageAttribute {
                                            authorSignature = attribute.signature
                                            break
                                        }
                                    }

                                    let psaType: String? = nil

                                    let forwardAuthorId = ephemeralParams?.authorId ?? author.id
                                    forwardInfo = StoreMessageForwardInfo(authorId: forwardAuthorId, sourceId: sourceId, sourceMessageId: sourceMessageId, date: sourceMessage.timestamp, authorSignature: authorSignature, psaType: psaType, flags: [])
                                } else {
                                    forwardInfo = nil
                                }
                            }
                            
                            for attribute in requestedAttributes {
                                if attribute is ForwardVideoTimestampAttribute {
                                    attributes.append(attribute)
                                }
                            }
                        } else {
                            // A copy into a secret chat, whose own timer is already in `attributes`. The requested
                            // attributes are not necessarily the forward's own: a reply that quotes another chat's
                            // message becomes a forward carrying the reply's attributes.
                            attributes.append(contentsOf: filterMessageAttributesForOutgoingMessage(forwardCopyRequestedAttributes(sourceAttributes: sourceMessage.attributes, forwardAttributes: [], hidesCaption: hidesCaption)))
                        }
                                                
                        var messageNamespace = Namespaces.Message.Local
                        var entitiesAttribute: TextEntitiesMessageAttribute?
                        var effectiveTimestamp = timestamp
                        var sendAsPeer: Peer?
                        var threadId: Int64? = threadId
                        for attribute in attributes {
                            if let attribute = attribute as? TextEntitiesMessageAttribute {
                                entitiesAttribute = attribute
                            } else if let attribute = attribute as? OutgoingScheduleInfoMessageAttribute {
                                if attribute.scheduleTime == scheduleWhenOnlineTimestamp, let presence = peerPresence as? TelegramUserPresence, case let .present(statusTimestamp) = presence.status, statusTimestamp >= timestamp {
                                } else {
                                    messageNamespace = Namespaces.Message.ScheduledLocal
                                    effectiveTimestamp = attribute.scheduleTime
                                }
                            } else if attribute is OutgoingQuickReplyMessageAttribute {
                                messageNamespace = Namespaces.Message.QuickReplyLocal
                                effectiveTimestamp = 0
                            } else if let attribute = attribute as? ReplyMessageAttribute {
                                if let threadMessageId = attribute.threadMessageId {
                                    threadId = Int64(threadMessageId.id)
                                }
                            } else if let attribute = attribute as? SendAsMessageAttribute {
                                if let peer = transaction.getPeer(attribute.peerId) {
                                    sendAsPeer = peer
                                }
                            }
                        }
                        
                        let authorId: PeerId?
                        if let sendAsPeer = sendAsPeer {
                            authorId = sendAsPeer.id
                        } else if let peer = peer as? TelegramChannel {
                            if case .broadcast = peer.info {
                                authorId = peer.id
                            } else if case .group = peer.info, peer.hasPermission(.canBeAnonymous) {
                                authorId = peer.id
                            } else {
                                authorId = account.peerId
                            }
                        }  else {
                            authorId = account.peerId
                        }
                        
                        if messageNamespace != Namespaces.Message.ScheduledLocal {
                            attributes.removeAll(where: { $0 is OutgoingScheduleInfoMessageAttribute })
                        }
                        if messageNamespace != Namespaces.Message.QuickReplyLocal {
                            attributes.removeAll(where: { $0 is OutgoingQuickReplyMessageAttribute })
                        }
                        
                        let (tags, globalTags) = tagsForStoreMessage(incoming: false, attributes: attributes, media: sourceMessage.media, textEntities: entitiesAttribute?.entities, isPinned: false)
                        
                        let localGroupingKey = forwardGroupingKey(grouping: grouping, sourceGroupingKey: sourceMessage.groupingKey, generatedKeys: &localGroupingKeyBySourceKey)
                        
                        var augmentedMediaList = sourceMessage.media.map { media -> Media in
                            return augmentMediaWithReference(.message(message: MessageReference(sourceMessage), media: media))
                        }
                        
                        if peerId.namespace == Namespaces.Peer.SecretChat {
                            augmentedMediaList = augmentedMediaList.map(convertForwardedMediaForSecretChat)
                        }
                        
                        if threadId == nil, let peer = transaction.getPeer(peerId), peer.isForum {
                            threadId = 1
                        }
                                                
                        storeMessages.append(StoreMessage(peerId: peerId, namespace: messageNamespace, customStableId: nil, globallyUniqueId: randomId, groupingKey: localGroupingKey, threadId: threadId, timestamp: effectiveTimestamp, flags: flags, tags: tags, globalTags: globalTags, localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: messageText, attributes: attributes, media: augmentedMediaList))
                    }
            }
        }
        var messageIds: [MessageId?] = []
        if !storeMessages.isEmpty {
            for emojiItem in emojiItems {
                if let entry = CodableEntry(emojiItem) {
                    let id: RecentEmojiItemId
                    switch emojiItem.content {
                    case let .file(file):
                        id = RecentEmojiItemId(file.fileId)
                    case let .text(text):
                        id = RecentEmojiItemId(text)
                    }
                    transaction.addOrMoveToFirstPositionOrderedItemListItem(collectionId: Namespaces.OrderedItemList.LocalRecentEmoji, item: OrderedItemListEntry(id: id.rawValue, contents: entry), removeTailIfCountExceeds: 20)
                }
            }
            
            let globallyUniqueIdToMessageId = transaction.addMessages(storeMessages, location: .Random)
            for globallyUniqueId in globallyUniqueIds {
                messageIds.append(globallyUniqueIdToMessageId[globallyUniqueId])
            }
            
            if peerId.namespace == Namespaces.Peer.CloudUser {
                if case .notIncluded = transaction.getPeerChatListInclusion(peerId) {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: nil, minTimestamp: nil))
                }
            }
        }
        for hashtag in addedHashtags {
            addRecentlyUsedHashtag(transaction: transaction, string: hashtag)
        }
        return messageIds
    } else {
        return []
    }
}
