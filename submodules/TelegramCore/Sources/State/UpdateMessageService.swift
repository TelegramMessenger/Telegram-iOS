import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

class UpdateMessageService: NSObject, MTMessageService {
    var peerId: PeerId!
    let pipe: ValuePipe<[UpdateGroup]> = ValuePipe()
    var mtProto: MTProto?
    
    override init() {
        super.init()
    }
    
    convenience init(peerId: PeerId) {
        self.init()
        self.peerId = peerId
    }
    
    func mtProtoWillAdd(_ mtProto: MTProto!) {
        self.mtProto = mtProto
    }
    
    func mtProtoDidChangeSession(_ mtProto: MTProto!) {
        self.pipe.putNext([.reset])
    }
    
    func mtProtoServerDidChangeSession(_ mtProto: MTProto!, firstValidMessageId: Int64, otherValidMessageIds: [Any]!) {
        self.pipe.putNext([.reset])
    }
    
    func putNext(_ groups: [UpdateGroup]) {
        self.pipe.putNext(groups)
    }
    
    func mtProto(_ mtProto: MTProto!, receivedMessage message: MTIncomingMessage!, authInfoSelector: MTDatacenterAuthInfoSelector, networkType: Int32) {
        if let updates = (message.body as? BoxedMessage)?.body as? Api.Updates {
            self.addUpdates(updates)
        }
    }
    
    func addUpdates(_ updates: Api.Updates) {
        switch updates {
            case let .updates(updatesData):
                let (updates, users, chats, date, seq) = (updatesData.updates, updatesData.users, updatesData.chats, updatesData.date, updatesData.seq)
                let groups = groupUpdates(updates, users: users, chats: chats, date: date, seqRange: seq == 0 ? nil : (seq, 1))
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case let .updatesCombined(updatesCombinedData):
                let (updates, users, chats, date, seqStart, seq) = (updatesCombinedData.updates, updatesCombinedData.users, updatesCombinedData.chats, updatesCombinedData.date, updatesCombinedData.seqStart, updatesCombinedData.seq)
                let groups = groupUpdates(updates, users: users, chats: chats, date: date, seqRange: seq == 0 ? nil : (seq, seq - seqStart))
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case let .updateShort(updateShortData):
                let (update, date) = (updateShortData.update, updateShortData.date)
                let groups = groupUpdates([update], users: [], chats: [], date: date, seqRange: nil)
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case let .updateShortChatMessage(updateShortChatMessageData):
                let (flags, id, fromId, chatId, message, pts, ptsCount, date, fwdFrom, viaBotId, replyHeader, entities, ttlPeriod) = (updateShortChatMessageData.flags, updateShortChatMessageData.id, updateShortChatMessageData.fromId, updateShortChatMessageData.chatId, updateShortChatMessageData.message, updateShortChatMessageData.pts, updateShortChatMessageData.ptsCount, updateShortChatMessageData.date, updateShortChatMessageData.fwdFrom, updateShortChatMessageData.viaBotId, updateShortChatMessageData.replyTo, updateShortChatMessageData.entities, updateShortChatMessageData.ttlPeriod)
                let generatedMessage = Api.Message.message(.init(flags: flags, flags2: 0, id: id, fromId: .peerUser(.init(userId: fromId)), fromBoostsApplied: nil, peerId: Api.Peer.peerChat(.init(chatId: chatId)), savedPeerId: nil, fwdFrom: fwdFrom, viaBotId: viaBotId, viaBusinessBotId: nil, replyTo: replyHeader, date: date, message: message, media: Api.MessageMedia.messageMediaEmpty, replyMarkup: nil, entities: entities, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: ttlPeriod, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil))
                let update = Api.Update.updateNewMessage(.init(message: generatedMessage, pts: pts, ptsCount: ptsCount))
                let groups = groupUpdates([update], users: [], chats: [], date: date, seqRange: nil)
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case let .updateShortMessage(updateShortMessageData):
                let (flags, id, userId, message, pts, ptsCount, date, fwdFrom, viaBotId, replyHeader, entities, ttlPeriod) = (updateShortMessageData.flags, updateShortMessageData.id, updateShortMessageData.userId, updateShortMessageData.message, updateShortMessageData.pts, updateShortMessageData.ptsCount, updateShortMessageData.date, updateShortMessageData.fwdFrom, updateShortMessageData.viaBotId, updateShortMessageData.replyTo, updateShortMessageData.entities, updateShortMessageData.ttlPeriod)
                let generatedFromId: Api.Peer
                if (Int(flags) & 1 << 1) != 0 {
                    generatedFromId = Api.Peer.peerUser(.init(userId: self.peerId.id._internalGetInt64Value()))
                } else {
                    generatedFromId = Api.Peer.peerUser(.init(userId: userId))
                }

                let generatedPeerId = Api.Peer.peerUser(.init(userId: userId))

                let generatedMessage = Api.Message.message(.init(flags: flags, flags2: 0, id: id, fromId: generatedFromId, fromBoostsApplied: nil, peerId: generatedPeerId, savedPeerId: nil, fwdFrom: fwdFrom, viaBotId: viaBotId, viaBusinessBotId: nil, replyTo: replyHeader, date: date, message: message, media: Api.MessageMedia.messageMediaEmpty, replyMarkup: nil, entities: entities, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: ttlPeriod, quickReplyShortcutId: nil, effect: nil, factcheck: nil, reportDeliveryUntilDate: nil, paidMessageStars: nil, suggestedPost: nil, scheduleRepeatPeriod: nil, summaryFromLanguage: nil))
                let update = Api.Update.updateNewMessage(.init(message: generatedMessage, pts: pts, ptsCount: ptsCount))
                let groups = groupUpdates([update], users: [], chats: [], date: date, seqRange: nil)
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case .updatesTooLong:
                self.pipe.putNext([.reset])
            case let .updateShortSentMessage(updateShortSentMessageData):
                let (pts, ptsCount) = (updateShortSentMessageData.pts, updateShortSentMessageData.ptsCount)
                self.pipe.putNext([.updatePts(pts: pts, ptsCount: ptsCount)])
        }
    }
}
