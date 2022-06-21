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
    
    func mtProto(_ mtProto: MTProto!, receivedMessage message: MTIncomingMessage!, authInfoSelector: MTDatacenterAuthInfoSelector) {
        if let updates = (message.body as? BoxedMessage)?.body as? Api.Updates {
            self.addUpdates(updates)
        }
    }
    
    func addUpdates(_ updates: Api.Updates) {
        switch updates {
            case let .updates(updates, users, chats, date, seq):
                let groups = groupUpdates(updates, users: users, chats: chats, date: date, seqRange: seq == 0 ? nil : (seq, 1))
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case let .updatesCombined(updates, users, chats, date, seqStart, seq):
                let groups = groupUpdates(updates, users: users, chats: chats, date: date, seqRange: seq == 0 ? nil : (seq, seq - seqStart))
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case let .updateShort(update, date):
                let groups = groupUpdates([update], users: [], chats: [], date: date, seqRange: nil)
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case let .updateShortChatMessage(flags, id, fromId, chatId, message, pts, ptsCount, date, fwdFrom, viaBotId, replyHeader, entities, ttlPeriod):
                let generatedMessage = Api.Message.message(flags: flags, id: id, fromId: .peerUser(userId: fromId), peerId: Api.Peer.peerChat(chatId: chatId), fwdFrom: fwdFrom, viaBotId: viaBotId, replyTo: replyHeader, date: date, message: message, media: Api.MessageMedia.messageMediaEmpty, replyMarkup: nil, entities: entities, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: ttlPeriod)
                let update = Api.Update.updateNewMessage(message: generatedMessage, pts: pts, ptsCount: ptsCount)
                let groups = groupUpdates([update], users: [], chats: [], date: date, seqRange: nil)
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case let .updateShortMessage(flags, id, userId, message, pts, ptsCount, date, fwdFrom, viaBotId, replyHeader, entities, ttlPeriod):
                let generatedFromId: Api.Peer
                if (Int(flags) & 1 << 1) != 0 {
                    generatedFromId = Api.Peer.peerUser(userId: self.peerId.id._internalGetInt64Value())
                } else {
                    generatedFromId = Api.Peer.peerUser(userId: userId)
                }
                
                let generatedPeerId = Api.Peer.peerUser(userId: userId)
                
                let generatedMessage = Api.Message.message(flags: flags, id: id, fromId: generatedFromId, peerId: generatedPeerId, fwdFrom: fwdFrom, viaBotId: viaBotId, replyTo: replyHeader, date: date, message: message, media: Api.MessageMedia.messageMediaEmpty, replyMarkup: nil, entities: entities, views: nil, forwards: nil, replies: nil, editDate: nil, postAuthor: nil, groupedId: nil, reactions: nil, restrictionReason: nil, ttlPeriod: ttlPeriod)
                let update = Api.Update.updateNewMessage(message: generatedMessage, pts: pts, ptsCount: ptsCount)
                let groups = groupUpdates([update], users: [], chats: [], date: date, seqRange: nil)
                if groups.count != 0 {
                    self.putNext(groups)
                }
            case .updatesTooLong:
                self.pipe.putNext([.reset])
            case let .updateShortSentMessage(_, _, pts, ptsCount, _, _, _, _):
                self.pipe.putNext([.updatePts(pts: pts, ptsCount: ptsCount)])
        }
    }
}
