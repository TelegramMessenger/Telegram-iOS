import Foundation
import Postbox

extension TelegramMediaWidget {
    /// The widget with its states changed as `updateMessageWidgetData` or a polled shared state says (widget-sandbox
    /// v0.2); a shared state that changes takes `publicDataHash` with it (2026-10-27 schema). Every other field as it is.
    func withUpdatedState(chatData: MessageWidgetDataChange, publicData: MessageWidgetDataChange, publicDataHash: Int64?) -> TelegramMediaWidget {
        var updatedChatData = self.chatData
        if case let .set(value) = chatData {
            updatedChatData = value
        }
        var updatedPublicData = self.publicData
        var updatedPublicDataHash = self.publicDataHash
        if case let .set(value) = publicData {
            updatedPublicData = value
            updatedPublicDataHash = publicDataHash
        }
        return TelegramMediaWidget(width: self.width, height: self.height, payload: self.payload, isCopy: self.isCopy, canQuery: self.canQuery, backgroundQuery: self.backgroundQuery, chatData: updatedChatData, publicData: updatedPublicData, publicDataHash: updatedPublicDataHash, widgetId: self.widgetId)
    }
}

/// The stored message `message` with its widget media replaced by `widget`: a full rebuild, since
/// `StoreMessage(updating:attributes:tags:)` keeps the stored media (as the extended-media replay rebuilds).
func storeMessageReplacingWidget(_ message: Message, widget: TelegramMediaWidget) -> StoreMessage {
    var storeForwardInfo: StoreMessageForwardInfo?
    if let forwardInfo = message.forwardInfo {
        storeForwardInfo = StoreMessageForwardInfo(authorId: forwardInfo.author?.id, sourceId: forwardInfo.source?.id, sourceMessageId: forwardInfo.sourceMessageId, date: forwardInfo.date, authorSignature: forwardInfo.authorSignature, psaType: forwardInfo.psaType, flags: forwardInfo.flags)
    }
    let media = message.media.map { media -> Media in
        return media is TelegramMediaWidget ? widget : media
    }
    return StoreMessage(id: message.id, customStableId: nil, globallyUniqueId: message.globallyUniqueId, groupingKey: message.groupingKey, threadId: message.threadId, timestamp: message.timestamp, flags: StoreMessageFlags(message.flags), tags: message.tags, globalTags: message.globalTags, localTags: message.localTags, forwardInfo: storeForwardInfo, authorId: message.author?.id, text: message.text, attributes: message.attributes, media: media)
}
