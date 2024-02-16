import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

final class GreetingMessageSetupChatContents: ChatCustomContentsProtocol {
    private final class Impl {
        let queue: Queue
        let context: AccountContext
        
        private var messages: [Message] = []
        private var nextMessageId: Int32 = 1000
        let messagesPromise = Promise<[Message]>([])
        
        private var nextGroupingId: UInt32 = 0
        private var groupingKeyToGroupId: [Int64: UInt32] = [:]
        
        init(queue: Queue, context: AccountContext, messages: [EngineMessage]) {
            self.queue = queue
            self.context = context
            self.messages = messages.map { $0._asMessage() }
            self.notifyMessagesUpdated()
            
            if let maxMessageId = messages.map(\.id).max() {
                self.nextMessageId = maxMessageId.id + 1
            }
            if let maxGroupingId = messages.compactMap(\.groupInfo?.stableId).max() {
                self.nextGroupingId = maxGroupingId + 1
            }
        }
        
        deinit {
        }
        
        private func notifyMessagesUpdated() {
            self.messages.sort(by: { $0.index > $1.index })
            self.messagesPromise.set(.single(self.messages))
        }
        
        func enqueueMessages(messages: [EnqueueMessage]) {
            for message in messages {
                switch message {
                case let .message(text, attributes, _, mediaReference, _, _, _, localGroupingKey, correlationId, _):
                    let _ = attributes
                    let _ = mediaReference
                    let _ = correlationId
                    
                    let messageId = self.nextMessageId
                    self.nextMessageId += 1
                    
                    var attributes: [MessageAttribute] = []
                    attributes.append(OutgoingMessageInfoAttribute(
                        uniqueId: Int64.random(in: Int64.min ... Int64.max),
                        flags: [],
                        acknowledged: true,
                        correlationId: correlationId, 
                        bubbleUpEmojiOrStickersets: []
                    ))
                    
                    var media: [Media] = []
                    if let mediaReference {
                        media.append(mediaReference.media)
                    }
                    
                    let mappedMessage = Message(
                        stableId: UInt32(messageId),
                        stableVersion: 0,
                        id: MessageId(
                            peerId: PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(0)),
                            namespace: Namespaces.Message.Local,
                            id: Int32(messageId)
                        ),
                        globallyUniqueId: nil,
                        groupingKey: localGroupingKey,
                        groupInfo: localGroupingKey.flatMap { value in
                            if let current = self.groupingKeyToGroupId[value] {
                                return MessageGroupInfo(stableId: current)
                            } else {
                                let groupId = self.nextGroupingId
                                self.nextGroupingId += 1
                                self.groupingKeyToGroupId[value] = groupId
                                return MessageGroupInfo(stableId: groupId)
                            }
                        },
                        threadId: nil,
                        timestamp: messageId,
                        flags: [],
                        tags: [],
                        globalTags: [],
                        localTags: [],
                        customTags: [],
                        forwardInfo: nil,
                        author: nil,
                        text: text,
                        attributes: attributes,
                        media: media,
                        peers: SimpleDictionary(),
                        associatedMessages: SimpleDictionary(),
                        associatedMessageIds: [],
                        associatedMedia: [:],
                        associatedThreadInfo: nil,
                        associatedStories: [:]
                    )
                    self.messages.append(mappedMessage)
                case .forward:
                    break
                }
            }
            self.notifyMessagesUpdated()
        }

        func deleteMessages(ids: [EngineMessage.Id]) {
            self.messages = self.messages.filter({ !ids.contains($0.id) })
            self.notifyMessagesUpdated()
        }
        
        func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
            guard let index = self.messages.firstIndex(where: { $0.id == id }) else {
                return
            }
            let originalMessage = self.messages[index]
            
            var mappedMedia = originalMessage.media
            switch media {
            case .keep:
                break
            case let .update(value):
                mappedMedia = [value.media]
            }
            
            var mappedAtrributes = originalMessage.attributes
            mappedAtrributes.removeAll(where: { $0 is TextEntitiesMessageAttribute })
            if let entities {
                mappedAtrributes.append(entities)
            }
            
            let mappedMessage = Message(
                stableId: originalMessage.stableId,
                stableVersion: originalMessage.stableVersion + 1,
                id: originalMessage.id,
                globallyUniqueId: originalMessage.globallyUniqueId,
                groupingKey: originalMessage.groupingKey,
                groupInfo: originalMessage.groupInfo,
                threadId: originalMessage.threadId,
                timestamp: originalMessage.timestamp,
                flags: originalMessage.flags,
                tags: originalMessage.tags,
                globalTags: originalMessage.globalTags,
                localTags: originalMessage.localTags,
                customTags: originalMessage.customTags,
                forwardInfo: originalMessage.forwardInfo,
                author: originalMessage.author,
                text: text,
                attributes: mappedAtrributes,
                media: mappedMedia,
                peers: originalMessage.peers,
                associatedMessages: originalMessage.associatedMessages,
                associatedMessageIds: originalMessage.associatedMessageIds,
                associatedMedia: originalMessage.associatedMedia,
                associatedThreadInfo: originalMessage.associatedThreadInfo,
                associatedStories: originalMessage.associatedStories
            )
            
            self.messages[index] = mappedMessage
            self.notifyMessagesUpdated()
        }
    }
    
    let kind: ChatCustomContentsKind

    var messages: Signal<[Message], NoError> {
        return self.impl.signalWith({ impl, subscriber in
            return impl.messagesPromise.get().start(next: subscriber.putNext)
        })
    }
    
    var messageLimit: Int? {
        return 20
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(context: AccountContext, messages: [EngineMessage], kind: ChatCustomContentsKind) {
        self.kind = kind
        
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, context: context, messages: messages)
        })
    }
    
    func enqueueMessages(messages: [EnqueueMessage]) {
        self.impl.with { impl in
            impl.enqueueMessages(messages: messages)
        }
    }

    func deleteMessages(ids: [EngineMessage.Id]) {
        self.impl.with { impl in
            impl.deleteMessages(ids: ids)
        }
    }
    
    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
        self.impl.with { impl in
            impl.editMessage(id: id, text: text, media: media, entities: entities, webpagePreviewAttribute: webpagePreviewAttribute, disableUrlPreview: disableUrlPreview)
        }
    }
}
