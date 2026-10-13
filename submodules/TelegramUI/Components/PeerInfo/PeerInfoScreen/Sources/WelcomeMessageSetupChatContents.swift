import Foundation
import SwiftSignalKit
import TelegramCore
import AccountContext

final class WelcomeMessageSetupChatContents: ChatCustomContentsProtocol {
    private final class Impl {
        let queue: Queue
        let context: AccountContext
        let peerId: EnginePeer.Id

        private(set) var currentHistoryView: EngineRawMessageHistoryView?
        let historyViewStream = ValuePipe<(EngineRawMessageHistoryView, EngineViewUpdateType)>()

        private var historyViewDisposable: Disposable?
        private var refreshDisposable: Disposable?

        init(queue: Queue, context: AccountContext, peerId: EnginePeer.Id) {
            self.queue = queue
            self.context = context
            self.peerId = peerId

            self.historyViewDisposable = (context.account.viewTracker.welcomeMessagesViewForLocation(peerId: peerId)
            |> deliverOn(queue)).startStrict(next: { [weak self] view, update, _ in
                guard let self else {
                    return
                }
                self.currentHistoryView = view
                self.historyViewStream.putNext((view, update))
            })

            self.refreshDisposable = context.engine.messages.refreshWelcomeMessages(peerId: peerId).start()
        }

        deinit {
            self.historyViewDisposable?.dispose()
            self.refreshDisposable?.dispose()
        }

        func enqueueMessages(messages: [EnqueueMessage]) {
            let _ = (TelegramCore.enqueueWelcomeMessages(account: self.context.account, peerId: self.peerId, messages: messages)
            |> deliverOn(self.queue)).startStandalone()
        }

        func deleteMessages(ids: [EngineMessage.Id]) {
            let _ = (self.context.engine.messages.deleteMessagesInteractively(messageIds: ids, type: .forEveryone)
            |> then(self.context.engine.messages.refreshWelcomeMessages(peerId: self.peerId))).startStandalone()
        }
    }

    let kind: ChatCustomContentsKind = .welcomeMessages

    var historyView: Signal<(EngineRawMessageHistoryView, EngineViewUpdateType), NoError> {
        return self.impl.signalWith({ impl, subscriber in
            if let currentHistoryView = impl.currentHistoryView {
                subscriber.putNext((currentHistoryView, .Initial))
            }
            return impl.historyViewStream.signal().start(next: subscriber.putNext)
        })
    }

    let messageLimit: Int?

    private let queue: Queue
    private let impl: QueueLocalObject<Impl>

    init(context: AccountContext, peerId: EnginePeer.Id) {
        if let value = context.currentAppConfiguration.with({ $0 }).data?["ephemeral_welcome_messages_max"] as? Double {
            self.messageLimit = max(0, Int(value))
        } else {
            self.messageLimit = 5
        }

        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, context: context, peerId: peerId)
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
    }

    func quickReplyUpdateShortcut(value: String) {
    }

    func businessLinkUpdate(message: String, entities: [MessageTextEntity], title: String?) {
    }

    func loadMore() {
    }

    func hashtagSearchUpdate(query: String) {
    }

    var hashtagSearchResultsUpdate: ((SearchMessagesResult, SearchMessagesState)) -> Void = { _ in }
}
