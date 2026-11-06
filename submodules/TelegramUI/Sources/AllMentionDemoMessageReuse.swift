import Foundation
import Postbox
import TelegramCore
import TelegramUIPreferences
import TextFormat

/// Edits and forwards are not new collective calls. A queued edit may request
/// a future call only through the explicit composer entity, never a raw token.
enum AllMentionDemoMessageReuse {
    static func edit(transaction: Transaction, peerId: PeerId, id: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?) {
        guard id.peerId == peerId else { return }
        let permission = allMentionGroupPermission(transaction: transaction, peerId: peerId)
        transaction.updateMessage(id, update: { original in
            let wasCollective = original.attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.contains { $0.entities.contains { $0.type == .Custom(type: ApplicationSpecificEntityType.AllMention) } }
            let canRetainIntent = id.namespace == Namespaces.Message.ScheduledCloud ? permission : wasCollective
            let requested = entities?.entities ?? []
            let updatedEntities = canRetainIntent
                ? allMentionEntitiesForScheduledDemoDelivery(text: text, entities: requested)
                : allMentionEntitiesForLocalDemo(text: text, entities: requested, isEnabled: false)
            var attributes = original.attributes.filter { !($0 is TextEntitiesMessageAttribute) && !($0 is WebpagePreviewMessageAttribute) && !($0 is EditedMessageAttribute) }
            if !updatedEntities.isEmpty { attributes.append(TextEntitiesMessageAttribute(entities: updatedEntities)) }
            if let webpagePreviewAttribute { attributes.append(webpagePreviewAttribute) }
            if id.namespace == Namespaces.Message.Cloud {
                attributes.append(EditedMessageAttribute(date: Int32(Date().timeIntervalSince1970), isHidden: false))
            }
            let updatedMedia: [Media]
            switch media {
            case .keep: updatedMedia = original.media
            case let .update(reference): updatedMedia = [reference.media]
            }
            return .update(StoreMessage(id: original.id, customStableId: nil, globallyUniqueId: original.globallyUniqueId, groupingKey: original.groupingKey, threadId: original.threadId, timestamp: original.timestamp, flags: StoreMessageFlags(original.flags), tags: original.tags, globalTags: original.globalTags, localTags: original.localTags, forwardInfo: original.forwardInfo.flatMap(StoreMessageForwardInfo.init), authorId: original.author?.id, text: text, attributes: attributes, media: updatedMedia))
        })
    }

    static func forward(original: Message, id: MessageId, threadId: Int64?, timestamp: Int32, authorId: PeerId, attributes outgoing: [MessageAttribute], correlationId: Int64?) -> StoreMessage {
        let options = outgoing.compactMap { $0 as? ForwardOptionsMessageAttribute }.first
        let hideCaption = options?.hideCaptions == true && original.media.contains { $0 is TelegramMediaImage || $0 is TelegramMediaFile }
        let text = hideCaption ? "" : original.text
        let sourceEntities = original.attributes.compactMap { $0 as? TextEntitiesMessageAttribute }.flatMap { $0.entities }
        let entities = hideCaption ? [] : allMentionEntitiesForLocalDemo(text: text, entities: sourceEntities, isEnabled: false)
        // Copy text formatting, not the source's mention, delivery, read or effect
        // attributes. Only this new forward's explicit transport options survive.
        var attributes = allMentionLocalOutgoingAttributes(outgoing, keepSchedule: id.namespace == Namespaces.Message.ScheduledCloud).filter { !($0 is TextEntitiesMessageAttribute) && !($0 is ConsumablePersonalMentionMessageAttribute) }
        if !entities.isEmpty { attributes.append(TextEntitiesMessageAttribute(entities: entities)) }
        attributes.append(OutgoingMessageInfoAttribute(uniqueId: Int64.random(in: 1 ..< Int64.max), flags: [], acknowledged: true, correlationId: correlationId, bubbleUpEmojiOrStickersets: [], partialReference: nil))
        let forwardInfo: StoreMessageForwardInfo?
        if options?.hideNames == true {
            forwardInfo = nil
        } else if let originalInfo = original.forwardInfo {
            forwardInfo = StoreMessageForwardInfo(originalInfo)
        } else {
            forwardInfo = StoreMessageForwardInfo(authorId: original.author?.id, sourceId: nil, sourceMessageId: nil, date: original.timestamp, authorSignature: nil, psaType: nil, flags: [])
        }
        if id.namespace == Namespaces.Message.ScheduledCloud {
            // Queue dates can be reordered. Postbox, not the date-sorted top id,
            // allocates ids so another forward cannot overwrite an earlier one.
            return StoreMessage(peerId: id.peerId, namespace: id.namespace, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: text, attributes: attributes, media: original.media)
        }
        return StoreMessage(id: id, customStableId: nil, globallyUniqueId: nil, groupingKey: nil, threadId: threadId, timestamp: timestamp, flags: [.TopIndexable, .ReactionsArePossible], tags: [], globalTags: [], localTags: [], forwardInfo: forwardInfo, authorId: authorId, text: text, attributes: attributes, media: original.media)
    }
}
