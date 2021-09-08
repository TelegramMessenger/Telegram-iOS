import Foundation
import Postbox
import SwiftSignalKit


private func localIdForResource(_ resource: MediaResource) -> Int64? {
    if let resource = resource as? LocalFileMediaResource {
        return resource.fileId
    }
    return nil
}

private final class MessageMediaPreuploadManagerUploadContext {
    let disposable = MetaDisposable()
    var progress: Float?
    var result: MultipartUploadResult?
    let subscribers = Bag<(MultipartUploadResult) -> Void>()
    
    deinit {
        self.disposable.dispose()
    }
}

private final class MessageMediaPreuploadManagerContext {
    private let queue: Queue
    
    private var uploadContexts: [Int64: MessageMediaPreuploadManagerUploadContext] = [:]
    
    init(queue: Queue) {
        self.queue = queue
        
        assert(self.queue.isCurrent())
    }
    
    func add(network: Network, postbox: Postbox, id: Int64, encrypt: Bool, tag: MediaResourceFetchTag?, source: Signal<MediaResourceData, NoError>, onComplete: (()->Void)? = nil) {
        let context = MessageMediaPreuploadManagerUploadContext()
        self.uploadContexts[id] = context
        let queue = self.queue
        context.disposable.set(multipartUpload(network: network, postbox: postbox, source: .custom(source), encrypt: encrypt, tag: tag, hintFileSize: nil, hintFileIsLarge: false, forceNoBigParts: false).start(next: { [weak self] next in
            queue.async {
                if let strongSelf = self, let context = strongSelf.uploadContexts[id] {
                    switch next {
                        case let .progress(value):
                            print("progress")
                            context.progress = value
                        default:
                            print("result")
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
    
    func upload(network: Network, postbox: Postbox, source: MultipartUploadSource, encrypt: Bool, tag: MediaResourceFetchTag?, hintFileSize: Int?, hintFileIsLarge: Bool) -> Signal<MultipartUploadResult, MultipartUploadError> {
        let queue = self.queue
        return Signal { [weak self] subscriber in
            if let strongSelf = self {
                if case let .resource(resource) = source, let id = localIdForResource(resource.resource), let context = strongSelf.uploadContexts[id] {
                    if let result = context.result {
                        subscriber.putNext(.progress(1.0))
                        subscriber.putNext(result)
                        subscriber.putCompletion()
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
                            }
                        }
                    }
                } else {
                    return multipartUpload(network: network, postbox: postbox, source: source, encrypt: encrypt, tag: tag, hintFileSize: hintFileSize, hintFileIsLarge: hintFileIsLarge, forceNoBigParts: false).start(next: { next in
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
    
    init() {
        let queue = Queue()
        self.impl = QueueLocalObject<MessageMediaPreuploadManagerContext>(queue: queue, generate: {
            return MessageMediaPreuploadManagerContext(queue: queue)
        })
    }
    
    func add(network: Network, postbox: Postbox, id: Int64, encrypt: Bool, tag: MediaResourceFetchTag?, source: Signal<MediaResourceData, NoError>, onComplete:(()->Void)? = nil) {
        self.impl.with { context in
            context.add(network: network, postbox: postbox, id: id, encrypt: encrypt, tag: tag, source: source, onComplete: onComplete)
        }
    }
    
    func upload(network: Network, postbox: Postbox, source: MultipartUploadSource, encrypt: Bool, tag: MediaResourceFetchTag?, hintFileSize: Int?, hintFileIsLarge: Bool) -> Signal<MultipartUploadResult, MultipartUploadError> {
        return Signal<Signal<MultipartUploadResult, MultipartUploadError>, MultipartUploadError> { subscriber in
            self.impl.with { context in
                subscriber.putNext(context.upload(network: network, postbox: postbox, source: source, encrypt: encrypt, tag: tag, hintFileSize: hintFileSize, hintFileIsLarge: hintFileIsLarge))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
        |> switchToLatest
    }
}
