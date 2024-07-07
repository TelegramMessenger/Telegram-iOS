import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

final class HashtagSearchGlobalChatContents: ChatCustomContentsProtocol {
    private final class Impl {
        let queue: Queue
        let context: AccountContext
        
        fileprivate var query: String {
            didSet {
                if self.query != oldValue {
                    self.updateHistoryViewRequest(reload: true)
                }
            }
        }
        private let publicPosts: Bool
        private var currentSearchState: SearchMessagesState?
        
        private(set) var mergedHistoryView: MessageHistoryView?
        private var sourceHistoryView: MessageHistoryView?
        
        private var historyViewDisposable: Disposable?
        let historyViewStream = ValuePipe<(MessageHistoryView, ViewUpdateType)>()
        private var nextUpdateIsHoleFill: Bool = false
        
        var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
        
        let isSearchingPromise = ValuePromise<Bool>(true)
        
        init(queue: Queue, context: AccountContext, query: String, publicPosts: Bool) {
            self.queue = queue
            self.context = context
            self.query = query
            self.publicPosts = publicPosts
            
            self.updateHistoryViewRequest(reload: false)
        }
        
        deinit {
            self.historyViewDisposable?.dispose()
        }
        
        private func updateHistoryViewRequest(reload: Bool) {
            guard self.historyViewDisposable == nil || reload else {
                return
            }
            self.historyViewDisposable?.dispose()
            
            let search: Signal<(SearchMessagesResult, SearchMessagesState), NoError>
            if self.publicPosts {
                search = self.context.engine.messages.searchHashtagPosts(hashtag: self.query, state: nil)
            } else {
                search = self.context.engine.messages.searchMessages(location: .general(scope: .everywhere, tags: nil, minDate: nil, maxDate: nil), query: self.query, state: nil)
            }
            
            self.isSearchingPromise.set(true)
            self.historyViewDisposable = (search
            |> deliverOn(self.queue)).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                let updateType: ViewUpdateType = .Initial
                
                let historyView = MessageHistoryView(tag: nil, namespaces: .just(Set([Namespaces.Message.Cloud])), entries: result.0.messages.reversed().map { MessageHistoryEntry(message: $0, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)) }, holeEarlier: !result.0.completed, holeLater: false, isLoading: false)
                self.sourceHistoryView = historyView
                self.updateHistoryView(updateType: updateType)
                                
                Queue.mainQueue().async {
                    self.currentSearchState = result.1
                    
                    self.hashtagSearchResultsUpdate(result)
                }
                
                self.historyViewDisposable?.dispose()
                self.historyViewDisposable = nil
                
                self.isSearchingPromise.set(false)
            })
        }
        
        private func updateHistoryView(updateType: ViewUpdateType) {
            var entries = self.sourceHistoryView?.entries ?? []
            entries.sort(by: { $0.message.index < $1.message.index })
            
            let mergedHistoryView = MessageHistoryView(tag: nil, namespaces: .just(Set([Namespaces.Message.Cloud])), entries: entries, holeEarlier: self.sourceHistoryView?.holeEarlier ?? false, holeLater: false, isLoading: false)
            self.mergedHistoryView = mergedHistoryView
            
            self.historyViewStream.putNext((mergedHistoryView, updateType))
        }
        
        func loadMore() {
            guard self.historyViewDisposable == nil, let currentSearchState = self.currentSearchState, let sourceHistoryView = self.sourceHistoryView, sourceHistoryView.holeEarlier else {
                return
            }
            
            let search: Signal<(SearchMessagesResult, SearchMessagesState), NoError>
            if self.publicPosts {
                search = self.context.engine.messages.searchHashtagPosts(hashtag: self.query, state: self.currentSearchState)
            } else {
                search = self.context.engine.messages.searchMessages(location: .general(scope: .everywhere, tags: nil, minDate: nil, maxDate: nil), query: self.query, state: currentSearchState)
            }
            
            self.historyViewDisposable?.dispose()
            self.historyViewDisposable = (search
            |> deliverOn(self.queue)).startStrict(next: { [weak self] result in
                guard let self else {
                    return
                }
                
                let updateType: ViewUpdateType = .FillHole
                
                let historyView = MessageHistoryView(tag: nil, namespaces: .just(Set([Namespaces.Message.Cloud])), entries: result.0.messages.reversed().map { MessageHistoryEntry(message: $0, isRead: false, location: nil, monthLocation: nil, attributes: MutableMessageHistoryEntryAttributes(authorIsContact: false)) }, holeEarlier: !result.0.completed, holeLater: false, isLoading: false)
                self.sourceHistoryView = historyView
                                                     
                self.updateHistoryView(updateType: updateType)
                
                Queue.mainQueue().async {
                    self.currentSearchState = result.1
                    
                    self.hashtagSearchResultsUpdate(result)
                }
                
                self.historyViewDisposable?.dispose()
                self.historyViewDisposable = nil
            })
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
        return self.impl.signalWith({ impl, subscriber in
            if let mergedHistoryView = impl.mergedHistoryView {
                subscriber.putNext((mergedHistoryView, .Initial))
            }
            return impl.historyViewStream.signal().start(next: subscriber.putNext)
        })
    }
    
    var searching: Signal<Bool, NoError> {
        return self.impl.signalWith({ impl, subscriber in
            return impl.isSearchingPromise.get().start(next: subscriber.putNext)
        })
    }
    
    var messageLimit: Int? {
        return nil
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(context: AccountContext, query: String, publicPosts: Bool) {
        self.kind = .hashTagSearch(publicPosts: publicPosts)
        
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, context: context, query: query, publicPosts: publicPosts)
        })
    }
    
    func enqueueMessages(messages: [EnqueueMessage]) {
        
    }

    func deleteMessages(ids: [EngineMessage.Id]) {

    }
    
    func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {

    }
    
    func quickReplyUpdateShortcut(value: String) {
        
    }
    
    func businessLinkUpdate(message: String, entities: [TelegramCore.MessageTextEntity], title: String?) {
        
    }
    
    func loadMore() {
        self.impl.with { impl in
            impl.loadMore()
        }
    }
    
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in } {
        didSet {
            self.impl.with { impl in
                impl.hashtagSearchResultsUpdate = self.hashtagSearchResultsUpdate
            }
        }
    }
    
    func hashtagSearchUpdate(query: String) {
        self.impl.with { impl in
            impl.query = query
        }
    }
}
