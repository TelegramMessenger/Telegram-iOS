import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

public final class PostSuggestionsChatContents: ChatCustomContentsProtocol {
    private final class Impl {
        let queue: Queue
        let context: AccountContext
        
        private var peerId: EnginePeer.Id
        
        private(set) var mergedHistoryView: MessageHistoryView?
        private var sourceHistoryView: MessageHistoryView?
        
        private var historyViewDisposable: Disposable?
        private var pendingHistoryViewDisposable: Disposable?
        let historyViewStream = ValuePipe<(MessageHistoryView, ViewUpdateType)>()
        private var nextUpdateIsHoleFill: Bool = false
        
        init(queue: Queue, context: AccountContext, peerId: EnginePeer.Id) {
            self.queue = queue
            self.context = context
            self.peerId = peerId
            
            self.updateHistoryViewRequest(reload: false)
        }
        
        deinit {
            self.historyViewDisposable?.dispose()
            self.pendingHistoryViewDisposable?.dispose()
        }
        
        private func updateHistoryViewRequest(reload: Bool) {
            self.pendingHistoryViewDisposable?.dispose()
            self.pendingHistoryViewDisposable = nil
            
            if self.historyViewDisposable == nil || reload {
                self.historyViewDisposable?.dispose()
                
                self.historyViewDisposable = (self.context.account.viewTracker.postSuggestionsViewForLocation(peerId: self.peerId)
                |> deliverOn(self.queue)).start(next: { [weak self] view, update, _ in
                    guard let self else {
                        return
                    }
                    if update == .FillHole {
                        self.nextUpdateIsHoleFill = true
                        self.updateHistoryViewRequest(reload: true)
                        return
                    }
                    
                    let nextUpdateIsHoleFill = self.nextUpdateIsHoleFill
                    self.nextUpdateIsHoleFill = false
                    
                    self.sourceHistoryView = view
                    
                    self.updateHistoryView(updateType: nextUpdateIsHoleFill ? .FillHole : .Generic)
                })
            }
        }
        
        private func updateHistoryView(updateType: ViewUpdateType) {
            var entries = self.sourceHistoryView?.entries ?? []
            entries.sort(by: { $0.message.index < $1.message.index })
            
            let mergedHistoryView = MessageHistoryView(tag: nil, namespaces: .just(Namespaces.Message.allSuggestedPost), entries: entries, holeEarlier: false, holeLater: false, isLoading: false)
            self.mergedHistoryView = mergedHistoryView
            
            self.historyViewStream.putNext((mergedHistoryView, updateType))
        }
        
        func enqueueMessages(messages: [EnqueueMessage]) {
            let _ = (TelegramCore.enqueueMessages(account: self.context.account, peerId: self.peerId, messages: messages.compactMap { message -> EnqueueMessage? in
                if !message.attributes.contains(where: { $0 is OutgoingSuggestedPostMessageAttribute }) {
                    return nil
                }
                return message
            })
            |> deliverOn(self.queue)).startStandalone()
        }

        func deleteMessages(ids: [EngineMessage.Id]) {
            let _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: ids, type: .forEveryone).startStandalone()
        }
        
        func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
        }
    }
    
    public let peerId: EnginePeer.Id
    public var kind: ChatCustomContentsKind

    public var historyView: Signal<(MessageHistoryView, ViewUpdateType), NoError> {
        return self.impl.signalWith({ impl, subscriber in
            if let mergedHistoryView = impl.mergedHistoryView {
                subscriber.putNext((mergedHistoryView, .Initial))
            }
            return impl.historyViewStream.signal().start(next: subscriber.putNext)
        })
    }
    
    public var messageLimit: Int? {
        return 20
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    public init(context: AccountContext, peerId: EnginePeer.Id) {
        self.peerId = peerId
        self.kind = .postSuggestions(price: StarsAmount(value: 250, nanos: 0))
        
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, context: context, peerId: peerId)
        })
    }
    
    public func enqueueMessages(messages: [EnqueueMessage]) {
        self.impl.with { impl in
            impl.enqueueMessages(messages: messages)
        }
    }

    public func deleteMessages(ids: [EngineMessage.Id]) {
        self.impl.with { impl in
            impl.deleteMessages(ids: ids)
        }
    }
    
    public func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
        self.impl.with { impl in
            impl.editMessage(id: id, text: text, media: media, entities: entities, webpagePreviewAttribute: webpagePreviewAttribute, disableUrlPreview: disableUrlPreview)
        }
    }
    
    public func quickReplyUpdateShortcut(value: String) {
    }
    
    public func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {
    }
    
    public func loadMore() {
    }
    
    public func hashtagSearchUpdate(query: String) {
    }
    
    public var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
}
