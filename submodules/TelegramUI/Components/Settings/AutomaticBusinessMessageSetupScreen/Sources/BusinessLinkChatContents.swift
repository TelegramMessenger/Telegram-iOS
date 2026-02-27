import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

final class BusinessLinkChatContents: ChatCustomContentsProtocol {
    private final class Impl {
        let queue: Queue
        let context: AccountContext
        
        init(queue: Queue, context: AccountContext) {
            self.queue = queue
            self.context = context
        }
        
        deinit {
        }
        
        func enqueueMessages(messages: [EnqueueMessage]) {
        }

        func deleteMessages(ids: [EngineMessage.Id]) {
        }
        
        func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
        }
    }
    
    var kind: ChatCustomContentsKind

    var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        let view = MessageHistoryView(tag: nil, namespaces: .just(Namespaces.Message.allQuickReply), entries: [], holeEarlier: false, holeLater: false, isLoading: false)

        return .single((view, .Initial))
    }
    
    var messageLimit: Int? {
        return 20
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(context: AccountContext, kind: ChatCustomContentsKind) {
        self.kind = kind
        
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, context: context)
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
    
    func quickReplyUpdateShortcut(value: String) {
    }
    
    func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {
        if case let .businessLinkSetup(link) = self.kind {
            self.kind = .businessLinkSetup(link: TelegramBusinessChatLinks.Link(
                url: link.url,
                message: message,
                entities: entities,
                title: title,
                viewCount: link.viewCount
            ))
        }
    }
    
    func loadMore() {
    }
    
    func hashtagSearchUpdate(query: String) {   
    }
    
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
}
