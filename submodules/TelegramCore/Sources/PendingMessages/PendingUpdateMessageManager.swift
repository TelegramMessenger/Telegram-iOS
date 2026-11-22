import Foundation
import SwiftSignalKit
import Postbox

public enum PendingUpdateMessageResult {
    case applied
    case unconfirmed
    case failed(RequestEditMessageError)
    case cancelled
    case superseded
    case interrupted
}

struct PendingUpdateMessageRequest {
    let messageId: MessageId
    let value: ChatUpdatingMessageMedia
    let inlineStickers: [MediaId: Media]
    let webpagePreviewAttribute: WebpagePreviewMessageAttribute?
}

private final class PendingUpdateMessageContext {
    var value: ChatUpdatingMessageMedia
    let disposable: Disposable
    private var completion: ((PendingUpdateMessageResult) -> Void)?
    
    init(value: ChatUpdatingMessageMedia, disposable: Disposable, completion: ((PendingUpdateMessageResult) -> Void)?) {
        self.value = value
        self.disposable = disposable
        self.completion = completion
    }

    func complete(_ result: PendingUpdateMessageResult) {
        let completion = self.completion
        self.completion = nil
        completion?(result)
    }
}

final class PendingUpdateMessageManagerImpl {
    let queue: Queue
    private let makeRequest: (PendingUpdateMessageRequest, TransformOutgoingMessageMedia?) -> Signal<RequestEditMessageResult, RequestEditMessageError>

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
    
    convenience init(queue: Queue, postbox: Postbox, network: Network, stateManager: AccountStateManager, messageMediaPreuploadManager: MessageMediaPreuploadManager, mediaReferenceRevalidationContext: MediaReferenceRevalidationContext) {
        self.init(queue: queue, makeRequest: { request, transformOutgoingMessageMedia in
            return requestEditMessage(accountPeerId: stateManager.accountPeerId, postbox: postbox, network: network, stateManager: stateManager, transformOutgoingMessageMedia: transformOutgoingMessageMedia, messageMediaPreuploadManager: messageMediaPreuploadManager, mediaReferenceRevalidationContext: mediaReferenceRevalidationContext, messageId: request.messageId, text: request.value.text, media: request.value.media, entities: request.value.entities, richText: request.value.richText, inlineStickers: request.inlineStickers, webpagePreviewAttribute: request.webpagePreviewAttribute, disableUrlPreview: request.value.disableUrlPreview, scheduleInfoAttribute: nil, invertMediaAttribute: request.value.invertMediaAttribute)
        })
    }

    init(queue: Queue, makeRequest: @escaping (PendingUpdateMessageRequest, TransformOutgoingMessageMedia?) -> Signal<RequestEditMessageResult, RequestEditMessageError>) {
        self.queue = queue
        self.makeRequest = makeRequest
        self.updatingMessageMediaPromise.set(.single(self.updatingMessageMediaValue))
    }

    deinit {
        for (_, context) in self.contexts {
            context.disposable.dispose()
            context.complete(.interrupted)
        }
    }
    
    private func updateValues() {
        self.updatingMessageMediaValue = self.contexts.mapValues { context in
            return context.value
        }
    }
    
    func add(messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, richText: RichTextMessageAttribute?, inlineStickers: [MediaId: Media], webpagePreviewAttribute: WebpagePreviewMessageAttribute?, invertMediaAttribute: InvertMediaMessageAttribute?, disableUrlPreview: Bool, completion: ((PendingUpdateMessageResult) -> Void)? = nil) {
        let previous = self.contexts.removeValue(forKey: messageId)
        previous?.disposable.dispose()
        
        let disposable = MetaDisposable()
        let context = PendingUpdateMessageContext(value: ChatUpdatingMessageMedia(text: text, entities: entities, disableUrlPreview: disableUrlPreview, media: media, invertMediaAttribute: invertMediaAttribute, richText: richText, progress: 0.0), disposable: disposable, completion: completion)
        self.contexts[messageId] = context
        // Publish the optimistic value immediately. Otherwise it only becomes visible on the first
        // `.progress`/`.done` event from `requestEditMessage` — which, for a media-bearing rich edit,
        // does not arrive until the inline-media upload finishes (the `uploadedRichMessage` resolver
        // swallows progress and runs the upload before the `uploadedMedia` chain), leaving the pending
        // edit invisible for the whole upload window.
        self.updateValues()

        let queue = self.queue
        let request = PendingUpdateMessageRequest(messageId: messageId, value: context.value, inlineStickers: inlineStickers, webpagePreviewAttribute: webpagePreviewAttribute)
        disposable.set((self.makeRequest(request, self.transformOutgoingMessageMedia)
        |> deliverOn(self.queue)).start(next: { [weak self, weak context] value in
            queue.async {
                guard let strongSelf = self, let initialContext = context else {
                    return
                }
                if let context = strongSelf.contexts[messageId], context === initialContext {
                    switch value {
                    case let .done(applied):
                        strongSelf.contexts.removeValue(forKey: messageId)
                        context.disposable.dispose()
                        strongSelf.updateValues()
                        context.complete(applied ? .applied : .unconfirmed)
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
                guard let context = strongSelf.contexts[messageId], context === initialContext else { return }
                strongSelf.contexts.removeValue(forKey: messageId)
                context.disposable.dispose()
                strongSelf.updateValues()
                strongSelf.errorsPipe.putNext((messageId, error))
                context.complete(.failed(error))
            }
        }, completed: { [weak self, weak context] in
            queue.async {
                guard let self, let context, self.contexts[messageId] === context else { return }
                self.contexts.removeValue(forKey: messageId)
                context.disposable.dispose()
                self.updateValues()
                context.complete(.unconfirmed)
            }
        }))
        previous?.complete(.superseded)
    }

    func cancel(messageId: MessageId) {
        if let context = self.contexts[messageId] {
            self.contexts.removeValue(forKey: messageId)
            context.disposable.dispose()
            
            self.updateValues()
            context.complete(.cancelled)
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
    
    public func add(messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, richText: RichTextMessageAttribute?, inlineStickers: [MediaId: Media], webpagePreviewAttribute: WebpagePreviewMessageAttribute? = nil, invertMediaAttribute: InvertMediaMessageAttribute? = nil, disableUrlPreview: Bool = false) {
        self.impl.with { impl in
            impl.add(messageId: messageId, text: text, media: media, entities: entities, richText: richText, inlineStickers: inlineStickers, webpagePreviewAttribute: webpagePreviewAttribute, invertMediaAttribute: invertMediaAttribute, disableUrlPreview: disableUrlPreview)
        }
    }
    
    public func add(messageId: MessageId, text: String, media: RequestEditMessageMedia, entities: TextEntitiesMessageAttribute?, richText: RichTextMessageAttribute?, inlineStickers: [MediaId: Media], webpagePreviewAttribute: WebpagePreviewMessageAttribute? = nil, invertMediaAttribute: InvertMediaMessageAttribute? = nil, disableUrlPreview: Bool = false, completion: @escaping (PendingUpdateMessageResult) -> Void) {
        self.impl.with { impl in
            impl.add(messageId: messageId, text: text, media: media, entities: entities, richText: richText, inlineStickers: inlineStickers, webpagePreviewAttribute: webpagePreviewAttribute, invertMediaAttribute: invertMediaAttribute, disableUrlPreview: disableUrlPreview, completion: completion)
        }
    }

    public func cancel(messageId: MessageId) {
        self.impl.with { impl in
            impl.cancel(messageId: messageId)
        }
    }
}
