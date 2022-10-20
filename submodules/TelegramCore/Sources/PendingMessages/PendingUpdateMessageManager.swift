import Foundation
import SwiftSignalKit
import Postbox

private final class PendingUpdateMessageContext {
    var value: ChatUpdatingMessageMedia
    let disposable: Disposable
    
    init(value: ChatUpdatingMessageMedia, disposable: Disposable) {
        self.value = value
        self.disposable = disposable
    }
}

private final class PendingUpdateMessageManagerImpl {
    let queue: Queue
    let postbox: Postbox
    let network: Network
    let stateManager: AccountStateManager
    let messageMediaPreuploadManager: MessageMediaPreuploadManager
    let mediaReferenceRevalidationContext: MediaReferenceRevalidationContext
    
    var transformOutgoingMessageMedia: TransformOutgoingMessageMedia?
    
    private var updatingMessageMediaValue: [MessageId: ChatUpdatingMessageMedia] = [:] {
        didSet {
            if self.updatingMessageMediaValue != oldValue {
                self.updatingMessageMediaPromise.set(.single(self.updatingMessageMediaValue))
            }
        }
    }
    private let updatingMessageMediaPromise = Promise<[MessageId: ChatUpdatingMessageMedia]>()
    var updatingMessageMedia: Signal<[MessageId: ChatUpdatingMessageMedia], NoError> {
        return self.updatingMessageMediaPromise.get()
    }
    
    private var contexts: [MessageId: PendingUpdateMessageContext] = [:]
    
    private let errorsPipe = ValuePipe<(MessageId, RequestEditMessageError)>()
    var errors: Signal<(MessageId, RequestEditMessageError), NoError> {
        return self.errorsPipe.signal()
    }
    
    init(queue: Queue, postbox: Postbox, network: Network, stateManager: AccountStateManager, messageMediaPreuploadManager: MessageMediaPreuploadManager, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext) {
        self.queue = queue
        self.postbox = postbox
        self.network = network
        self.stateManager = stateManager
        self.messageMediaPreuploadManager = messageMediaPreuploadManager
        self.mediaReferenceRevalidationContext = mediaReferenceRevalidationContext
        
        self.updatingMessageMediaPromise.set(.single(self.updatingMessageMediaValue))
    }
    
    deinit {
        for (_, context) in self.contexts {
            context.disposable.dispose()
        }
    }
    
    private func updateValues() {
        self.updatingMessageMediaValue = self.contexts.mapValues { context in
            return context.value
        }
    }
    
    func add(messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, inlineStickers: [MediaId: Media], disableUrlPreview: Bool) {
        if let context = self.contexts[messageId] {
            self.contexts.removeValue(forKey: messageId)
            context.disposable.dispose()
        }
        
        let disposable = MetaDisposable()
        let context = PendingUpdateMessageContext(value: ChatUpdatingMessageMedia(text: text, entities: entities, disableUrlPreview: disableUrlPreview, media: media, progress: 0.0), disposable: disposable)
        self.contexts[messageId] = context
        
        let queue = self.queue
        disposable.set((requestEditMessage(postbox: self.postbox, network: self.network, stateManager: self.stateManager, transformOutgoingMessageMedia: self.transformOutgoingMessageMedia, messageMediaPreuploadManager: self.messageMediaPreuploadManager, mediaReferenceRevalidationContext: self.mediaReferenceRevalidationContext, messageId: messageId, text: text, media: media, entities: entities, inlineStickers: inlineStickers, disableUrlPreview: disableUrlPreview, scheduleTime: nil)
        |> deliverOn(self.queue)).start(next: { [weak self, weak context] value in
            queue.async {
                guard let strongSelf = self, let initialContext = context else {
                    return
                }
                if let context = strongSelf.contexts[messageId], context === initialContext {
                    switch value {
                    case .done:
                        strongSelf.contexts.removeValue(forKey: messageId)
                        context.disposable.dispose()
                        strongSelf.updateValues()
                    case let .progress(progress):
                        context.value = context.value.withProgress(progress)
                        strongSelf.updateValues()
                    }
                }
            }
        }, error: { [weak self, weak context] error in
            queue.async {
                guard let strongSelf = self, let initialContext = context else {
                    return
                }
                if let context = strongSelf.contexts[messageId], context === initialContext {
                    strongSelf.contexts.removeValue(forKey: messageId)
                    context.disposable.dispose()
                    strongSelf.updateValues()
                }
                
                strongSelf.errorsPipe.putNext((messageId, error))
            }
        }))
    }
    
    func cancel(messageId: MessageId) {
        if let context = self.contexts[messageId] {
            self.contexts.removeValue(forKey: messageId)
            context.disposable.dispose()
            
            self.updateValues()
        }
    }
}

public final class PendingUpdateMessageManager {
    private let queue = Queue()
    private let impl: QueueLocalObject<PendingUpdateMessageManagerImpl>
    
    var transformOutgoingMessageMedia: TransformOutgoingMessageMedia? {
        didSet {
            let transformOutgoingMessageMedia = self.transformOutgoingMessageMedia
            self.impl.with { impl in
                impl.transformOutgoingMessageMedia = transformOutgoingMessageMedia
            }
        }
    }
    
    public var updatingMessageMedia: Signal<[MessageId: ChatUpdatingMessageMedia], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.updatingMessageMedia.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public var errors: Signal<(MessageId, RequestEditMessageError), NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.errors.start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    init(postbox: Postbox, network: Network, stateManager: AccountStateManager, messageMediaPreuploadManager: MessageMediaPreuploadManager, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return PendingUpdateMessageManagerImpl(queue: queue, postbox: postbox, network: network, stateManager: stateManager, messageMediaPreuploadManager: messageMediaPreuploadManager, mediaReferenceRevalidationContext: mediaReferenceRevalidationContext)
        })
    }
    
    public func add(messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, inlineStickers: [MediaId: Media], disableUrlPreview: Bool = false) {
        self.impl.with { impl in
            impl.add(messageId: messageId, text: text, media: media, entities: entities, inlineStickers: inlineStickers, disableUrlPreview: disableUrlPreview)
        }
    }
    
    public func cancel(messageId: MessageId) {
        self.impl.with { impl in
            impl.cancel(messageId: messageId)
        }
    }
}
