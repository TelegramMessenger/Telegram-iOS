import Postbox
import FlatBuffers
import FlatSerialization

public extension PeerId {
    init(flatBuffersObject: TelegramCore_PeerId) {
        self.init(namespace: PeerId.Namespace._internalFromInt32Value(flatBuffersObject.namespace), id: PeerId.Id._internalFromInt64Value(flatBuffersObject.id))
    }
}

public extension MessageId {
    init(flatBuffersObject: TelegramCore_MessageId) {
        self.init(peerId: PeerId(flatBuffersObject: flatBuffersObject.peerId), namespace: flatBuffersObject.namespace, id: flatBuffersObject.id)
    }
}

public extension MessageReference {
    init(flatBuffersObject: TelegramCore_MessageReference) throws {
        self.init(content: .message(
            peer: try PeerReference(flatBuffersObject: flatBuffersObject.peer),
            author: try flatBuffersObject.author.flatMap { try PeerReference(flatBuffersObject: $0) },
            id: MessageId(flatBuffersObject: flatBuffersObject.messageId),
            timestamp: flatBuffersObject.timestamp,
            incoming: flatBuffersObject.incoming,
            secret: flatBuffersObject.secret,
            threadId: flatBuffersObject.threadId == Int64.min ? nil : flatBuffersObject.threadId)
        )
    }
    
    func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset? {
        switch self.content {
        case let .message(peer, author, id, timestamp, incoming, secret, threadId):
            let peerOffset = peer.encodeToFlatBuffers(builder: &builder)
            let authorOffset = author.flatMap { $0.encodeToFlatBuffers(builder: &builder) }
            
            let start = TelegramCore_MessageReference.startMessageReference(&builder)
            
            TelegramCore_MessageReference.add(peer: peerOffset, &builder)
            if let authorOffset {
                TelegramCore_MessageReference.add(author: authorOffset, &builder)
            }
            TelegramCore_MessageReference.add(messageId: TelegramCore_MessageId(peerId: TelegramCore_PeerId(namespace: id.peerId.namespace._internalGetInt32Value(), id: id.peerId.id._internalGetInt64Value()), namespace: id.namespace, id: id.id), &builder)
            TelegramCore_MessageReference.add(timestamp: timestamp, &builder)
            TelegramCore_MessageReference.add(incoming: incoming, &builder)
            TelegramCore_MessageReference.add(secret: secret, &builder)
            TelegramCore_MessageReference.add(threadId: threadId ?? Int64.min, &builder)
            
            return TelegramCore_MessageReference.endMessageReference(&builder, start: start)
        case .none:
            return nil
        }
    }
}

public extension WebpageReference {
    init(flatBuffersObject: TelegramCore_WebpageReference) throws {
        self.init(content: .webPage(id: flatBuffersObject.webpageId, url: flatBuffersObject.url))
    }
    
    func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset? {
        switch self.content {
        case let .webPage(id, url):
            let urlOffset = builder.create(string: url)
            
            let start = TelegramCore_WebpageReference.startWebpageReference(&builder)
            
            TelegramCore_WebpageReference.add(webpageId: id, &builder)
            TelegramCore_WebpageReference.add(url: urlOffset, &builder)
            
            return TelegramCore_WebpageReference.endWebpageReference(&builder, start: start)
        case .none:
            return nil
        }
    }
}

public extension PartialMediaReference {
    init(flatBuffersObject: TelegramCore_PartialMediaReference) throws {
        switch flatBuffersObject.valueType {
        case .partialmediareferenceMessage:
            guard let value = flatBuffersObject.value(type: TelegramCore_PartialMediaReference_Message.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            if let message = value.message {
                self = .message(message: try MessageReference(flatBuffersObject: message))
            } else {
                self = .message(message: MessageReference(content: .none))
            }
        case .partialmediareferenceWebpage:
            guard let value = flatBuffersObject.value(type: TelegramCore_PartialMediaReference_WebPage.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            if let webPage = value.webPage {
                self = .webPage(webPage: try WebpageReference(flatBuffersObject: webPage))
            } else {
                self = .webPage(webPage: WebpageReference(content: .none))
            }
        case .partialmediareferenceStickerpack:
            guard let value = flatBuffersObject.value(type: TelegramCore_PartialMediaReference_StickerPack.self) else {
                throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
            }
            self = .stickerPack(stickerPack: try StickerPackReference(flatBuffersObject: value.stickerPack))
        case .partialmediareferenceSavedgif:
            self = .savedGif
        case .partialmediareferenceSavedsticker:
            self = .savedSticker
        case .partialmediareferenceRecentsticker:
            self = .recentSticker
        case .none_:
            throw FlatBuffersError.missingRequiredField(file: #file, line: #line)
        }
    }
    
    func encodeToFlatBuffers(builder: inout FlatBufferBuilder) -> Offset {
        switch self {
        case let .message(message):
            let messageOffset = message.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_PartialMediaReference_Message.startPartialMediaReference_Message(&builder)
            if let messageOffset {
                TelegramCore_PartialMediaReference_Message.add(message: messageOffset, &builder)
            }
            return TelegramCore_PartialMediaReference_Message.endPartialMediaReference_Message(&builder, start: start)
        case let .webPage(webPage):
            let webpageOffset = webPage.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_PartialMediaReference_WebPage.startPartialMediaReference_WebPage(&builder)
            if let webpageOffset {
                TelegramCore_PartialMediaReference_WebPage.add(webPage: webpageOffset, &builder)
            }
            return TelegramCore_PartialMediaReference_WebPage.endPartialMediaReference_WebPage(&builder, start: start)
        case let .stickerPack(stickerPack):
            let stickerPackOffset = stickerPack.encodeToFlatBuffers(builder: &builder)
            let start = TelegramCore_PartialMediaReference_StickerPack.startPartialMediaReference_StickerPack(&builder)
            TelegramCore_PartialMediaReference_StickerPack.add(stickerPack: stickerPackOffset, &builder)
            return TelegramCore_PartialMediaReference_StickerPack.endPartialMediaReference_StickerPack(&builder, start: start)
        case .savedGif:
            let start = TelegramCore_PartialMediaReference_SavedGif.startPartialMediaReference_SavedGif(&builder)
            return TelegramCore_PartialMediaReference_SavedGif.endPartialMediaReference_SavedGif(&builder, start: start)
        case .savedSticker:
            let start = TelegramCore_PartialMediaReference_SavedSticker.startPartialMediaReference_SavedSticker(&builder)
            return TelegramCore_PartialMediaReference_SavedSticker.endPartialMediaReference_SavedSticker(&builder, start: start)
        case .recentSticker:
            let start = TelegramCore_PartialMediaReference_RecentSticker.startPartialMediaReference_RecentSticker(&builder)
            return TelegramCore_PartialMediaReference_RecentSticker.endPartialMediaReference_RecentSticker(&builder, start: start)
        }
    }
}
