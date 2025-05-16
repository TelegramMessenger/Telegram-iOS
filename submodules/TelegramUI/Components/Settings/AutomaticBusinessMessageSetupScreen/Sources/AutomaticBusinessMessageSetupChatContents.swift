import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import AccountContext

final class AutomaticBusinessMessageSetupChatContents: ChatCustomContentsProtocol {
    private final class PendingMessageContext {
        let disposable = MetaDisposable()
        var message: Message?
        
        init() {
        }
    }
    
    private final class Impl {
        let queue: Queue
        let context: AccountContext
        
        private var shortcut: String
        private var shortcutId: Int32?
        
        private(set) var mergedHistoryView: MessageHistoryView?
        private var sourceHistoryView: MessageHistoryView?
        
        private var pendingMessages: [PendingMessageContext] = []
        private var historyViewDisposable: Disposable?
        private var pendingHistoryViewDisposable: Disposable?
        let historyViewStream = ValuePipe<(MessageHistoryView, ViewUpdateType)>()
        private var nextUpdateIsHoleFill: Bool = false
        
        init(queue: Queue, context: AccountContext, shortcut: String, shortcutId: Int32?) {
            self.queue = queue
            self.context = context
            self.shortcut = shortcut
            self.shortcutId = shortcutId
            
            self.updateHistoryViewRequest(reload: false)
        }
        
        deinit {
            for context in self.pendingMessages {
                context.disposable.dispose()
            }
            self.historyViewDisposable?.dispose()
            self.pendingHistoryViewDisposable?.dispose()
        }
        
        private func updateHistoryViewRequest(reload: Bool) {
            if let shortcutId = self.shortcutId {
                self.pendingHistoryViewDisposable?.dispose()
                self.pendingHistoryViewDisposable = nil
                
                if self.historyViewDisposable == nil || reload {
                    self.historyViewDisposable?.dispose()
                    
                    self.historyViewDisposable = (self.context.account.viewTracker.quickReplyMessagesViewForLocation(quickReplyId: shortcutId)
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
                        
                        if !view.entries.contains(where: { $0.message.id.namespace == Namespaces.Message.QuickReplyCloud }) {
                            self.shortcutId = nil
                        }
                        
                        self.updateHistoryView(updateType: nextUpdateIsHoleFill ? .FillHole : .Generic)
                    })
                }
            } else {
                self.historyViewDisposable?.dispose()
                self.historyViewDisposable = nil
                
                self.pendingHistoryViewDisposable = (self.context.account.viewTracker.pendingQuickReplyMessagesViewForLocation(shortcut: self.shortcut)
                |> deliverOn(self.queue)).start(next: { [weak self] view, _, _ in
                    guard let self else {
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
            for pendingMessage in self.pendingMessages {
                if let message = pendingMessage.message {
                    if !entries.contains(where: { $0.message.stableId == message.stableId }) {
                        entries.append(MessageHistoryEntry(
                            message: message,
                            isRead: true,
                            location: nil,
                            monthLocation: nil,
                            attributes: MutableMessageHistoryEntryAttributes(
                                authorIsContact: false
                            )
                        ))
                    }
                }
            }
            entries.sort(by: { $0.message.index < $1.message.index })
            
            let mergedHistoryView = MessageHistoryView(tag: nil, namespaces: .just(Namespaces.Message.allQuickReply), entries: entries, holeEarlier: false, holeLater: false, isLoading: false)
            self.mergedHistoryView = mergedHistoryView
            
            self.historyViewStream.putNext((mergedHistoryView, updateType))
        }
        
        func enqueueMessages(messages: [EnqueueMessage]) {
            let threadId = self.shortcutId.flatMap(Int64.init)
            let _ = (TelegramCore.enqueueMessages(account: self.context.account, peerId: self.context.account.peerId, messages: messages.map { message in
                return message.withUpdatedThreadId(threadId).withUpdatedAttributes { attributes in
                    var attributes = attributes
                    attributes.removeAll(where: { $0 is OutgoingQuickReplyMessageAttribute })
                    attributes.append(OutgoingQuickReplyMessageAttribute(shortcut: self.shortcut))
                    return attributes
                }
            })
            |> deliverOn(self.queue)).startStandalone(next: { [weak self] result in
                guard let self else {
                    return
                }
                if self.shortcutId != nil {
                    return
                }
                for id in result {
                    if let id {
                        let pendingMessage = PendingMessageContext()
                        self.pendingMessages.append(pendingMessage)
                        pendingMessage.disposable.set((
                            self.context.account.postbox.messageView(id)
                            |> deliverOn(self.queue)
                        ).startStrict(next: { [weak self, weak pendingMessage] messageView in
                            guard let self else {
                                return
                            }
                            guard let pendingMessage else {
                                return
                            }
                            pendingMessage.message = messageView.message
                            if let message = pendingMessage.message, message.id.namespace == Namespaces.Message.QuickReplyCloud, let threadId = message.threadId {
                                self.shortcutId = Int32(clamping: threadId)
                                self.updateHistoryViewRequest(reload: true)
                            } else {
                                self.updateHistoryView(updateType: .Generic)
                            }
                        }))
                    }
                }
            })
        }

        func deleteMessages(ids: [EngineMessage.Id]) {
            let _ = self.context.engine.messages.deleteMessagesInteractively(messageIds: ids, type: .forEveryone).startStandalone()
        }
        
        func editMessage(id: EngineMessage.Id, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, webpagePreviewAttribute: WebpagePreviewMessageAttribute?, disableUrlPreview: Bool) {
        }
        
        func quickReplyUpdateShortcut(value: String) {
            self.shortcut = value
            if let shortcutId = self.shortcutId {
                self.context.engine.accountData.editMessageShortcut(id: shortcutId, shortcut: value)
            }
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
    
    var messageLimit: Int? {
        return 20
    }
    
    private let queue: Queue
    private let impl: QueueLocalObject<Impl>
    
    init(context: AccountContext, kind: ChatCustomContentsKind, shortcutId: Int32?) {
        self.kind = kind
        
        let initialShortcut: String
        switch kind {
        case let .quickReplyMessageInput(shortcut, _):
            initialShortcut = shortcut
        case .businessLinkSetup:
            initialShortcut = ""
        case .hashTagSearch:
            initialShortcut = ""
        }
        
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, context: context, shortcut: initialShortcut, shortcutId: shortcutId)
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
        switch self.kind {
        case let .quickReplyMessageInput(_, shortcutType):
            self.kind = .quickReplyMessageInput(shortcut: value, shortcutType: shortcutType)
            self.impl.with { impl in
                impl.quickReplyUpdateShortcut(value: value)
            }
        case .businessLinkSetup:
            break
        case .hashTagSearch:
            break
        }
    }
    
    func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {
    }
    
    func loadMore() {
    }
    
    func hashtagSearchUpdate(query: String) {
    }
    
    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
}
