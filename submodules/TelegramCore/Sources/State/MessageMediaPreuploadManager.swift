import Foundation
import Postbox
import SwiftSignalKit
import MediaPreuploadRegistry


func localIdForResource(_ resource: MediaResource) -> Int64? {
    if let resource = resource as? LocalFileMediaResource {
        return resource.fileId
    }
    return nil
}

private final class MessageMediaPreuploadManagerUploadContext {
    let disposable = MetaDisposable()
    let graceTimer = MetaDisposable()
    var progress: Float?
    var result: MultipartUploadResult?
    let subscribers = Bag<(MultipartUploadResult) -> Void>()

    deinit {
        self.disposable.dispose()
        self.graceTimer.dispose()
    }
}

private final class MessageMediaPreuploadManagerContext {
    private let queue: Queue

    private var uploadContexts: [Int64: MessageMediaPreuploadManagerUploadContext] = [:]

    init(queue: Queue) {
        self.queue = queue

        assert(self.queue.isCurrent())
    }

    // Someone became interested again: cancel any pending grace-cancel.
    private func cancelGrace(_ context: MessageMediaPreuploadManagerUploadContext) {
        context.graceTimer.set(nil)
    }

    // Called after a holder/subscriber leaves the Bag. If no one is interested,
    // start a 1s timer; if still empty when it fires, cancel the upload and evict.
    private func scheduleGraceIfEmpty(id: Int64) {
        guard let context = self.uploadContexts[id] else {
            return
        }
        if context.subscribers.isEmpty {
            let queue = self.queue
            context.graceTimer.set((Signal<Void, NoError>.single(())
            |> delay(1.0, queue: queue)).start(next: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let context = strongSelf.uploadContexts[id], context.subscribers.isEmpty {
                    context.disposable.dispose()
                    strongSelf.uploadContexts.removeValue(forKey: id)
                }
            }))
        }
    }

    func add(network: Network, postbox: Postbox, id: Int64, encrypt: Bool, tag: MediaResourceFetchTag?, source: Signal<EngineMediaResource.ResourceData, NoError>, onComplete: (()->Void)? = nil) -> Disposable {
        let queue = self.queue
        let context: MessageMediaPreuploadManagerUploadContext
        if let existing = self.uploadContexts[id] {
            // A live (or in-grace) upload already exists for this resource: reuse it,
            // don't restart. A new holder revives a context that was in its grace window.
            context = existing
            self.cancelGrace(context)
        } else {
            context = MessageMediaPreuploadManagerUploadContext()
            self.uploadContexts[id] = context
            context.disposable.set(multipartUpload(network: network, postbox: postbox, source: .custom(source |> map { data in
                return MediaResourceData(
                    path: data.path,
                    offset: 0,
                    size: data.availableSize,
                    complete: data.isComplete
                )
            }), encrypt: encrypt, tag: tag, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false).start(next: { [weak self] next in
                queue.async {
                    if let strongSelf = self, let context = strongSelf.uploadContexts[id] {
                        switch next {
                            case let .progress(value):
                                context.progress = value
                            default:
                                context.result = next
                                onComplete?()
                        }
                        for subscriber in context.subscribers.copyItems() {
                            subscriber(next)
                        }
                    }
                }
            }))
        }
        // The "need" holder occupies a Bag slot (the refcount) but ignores results.
        let index = context.subscribers.add({ _ in })
        return ActionDisposable { [weak self] in
            queue.async {
                guard let strongSelf = self, let context = strongSelf.uploadContexts[id] else {
                    return
                }
                context.subscribers.remove(index)
                strongSelf.scheduleGraceIfEmpty(id: id)
            }
        }
    }

    func upload(network: Network, postbox: Postbox, source: MultipartUploadSource, encrypt: Bool, tag: MediaResourceFetchTag?, hintFileSize: Int64?, hintFileIsLarge: Bool, forceNoBigParts: Bool) -> Signal<MultipartUploadResult, MultipartUploadError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                if case let .resource(resource) = source, let id = localIdForResource(resource.resource), let context = strongSelf.uploadContexts[id] {
                    strongSelf.cancelGrace(context)
                    if let result = context.result {
                        subscriber.putNext(.progress(1.0))
                        subscriber.putNext(result)
                        subscriber.putCompletion()
                        // No Bag entry added; if nothing else is interested, resume grace.
                        strongSelf.scheduleGraceIfEmpty(id: id)
                        return EmptyDisposable
                    } else if let progress = context.progress {
                        subscriber.putNext(.progress(progress))
                    }
                    let index = context.subscribers.add({ next in
                        subscriber.putNext(next)
                        switch next {
                            case .inputFile, .inputSecretFile:
                                subscriber.putCompletion()
                            case .progress:
                                break
                        }
                    })
                    return ActionDisposable {
                        queue.async {
                            if let strongSelf = self, let context = strongSelf.uploadContexts[id] {
                                context.subscribers.remove(index)
                                strongSelf.scheduleGraceIfEmpty(id: id)
                            }
                        }
                    }
                } else {
                    return multipartUpload(network: network, postbox: postbox, source: source, encrypt: encrypt, tag: tag, hintFileSize: hintFileSize, hintFileIsLarge: hintFileIsLarge, forceNoBigParts: forceNoBigParts).start(next: { next in
                        subscriber.putNext(next)
                    }, error: { error in
                        subscriber.putError(error)
                    }, completed: {
                        subscriber.putCompletion()
                    })
                }
            } else {
                subscriber.putError(.generic)
                return EmptyDisposable
            }
        } |> runOn(self.queue)
    }
}

final class MessageMediaPreuploadManager {
    private let impl: QueueLocalObject<MessageMediaPreuploadManagerContext>

    /// Media-level pre-upload: keyed by `MediaId`, parks a CLOUD `EngineMedia`.
    /// Sits above `impl`'s byte-level contexts — a media context's byte step goes through
    /// `upload(...)`, so the two share one transfer wherever `localIdForResource` resolves.
    let mediaRegistry: PreuploadRegistry<MediaId, EngineMedia>

    init() {
        let queue = Queue()
        self.impl = QueueLocalObject<MessageMediaPreuploadManagerContext>(queue: queue, generate: {
            return MessageMediaPreuploadManagerContext(queue: queue)
        })
        self.mediaRegistry = PreuploadRegistry<MediaId, EngineMedia>(scheduler: QueuePreuploadScheduler(queue: queue))
    }

    @discardableResult
    func add(network: Network, postbox: Postbox, id: Int64, encrypt: Bool, tag: MediaResourceFetchTag?, source: Signal<EngineMediaResource.ResourceData, NoError>, onComplete:(()->Void)? = nil) -> Disposable {
        let disposable = MetaDisposable()
        self.impl.with { context in
            disposable.set(context.add(network: network, postbox: postbox, id: id, encrypt: encrypt, tag: tag, source: source, onComplete: onComplete))
        }
        return disposable
    }

    func upload(network: Network, postbox: Postbox, source: MultipartUploadSource, encrypt: Bool, tag: MediaResourceFetchTag?, hintFileSize: Int64?, hintFileIsLarge: Bool, forceNoBigParts: Bool) -> Signal<MultipartUploadResult, MultipartUploadError> {
        return Signal<Signal<MultipartUploadResult, MultipartUploadError>, MultipartUploadError> { subscriber in
            self.impl.with { context in
                subscriber.putNext(context.upload(network: network, postbox: postbox, source: source, encrypt: encrypt, tag: tag, hintFileSize: hintFileSize, hintFileIsLarge: hintFileIsLarge, forceNoBigParts: forceNoBigParts))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
        |> switchToLatest
    }
}
