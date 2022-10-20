import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import FFMpegBinding

public enum FramePreviewResult {
    case image(UIImage)
    case waitingForData
}

public protocol FramePreview {
    var generatedFrames: Signal<FramePreviewResult, NoError> { get }

    func generateFrame(at timestamp: Double)
    func cancelPendingFrames()
}

private final class FramePreviewContext {
    let source: UniversalSoftwareVideoSource
    
    init(source: UniversalSoftwareVideoSource) {
        self.source = source
    }
}

private func initializedPreviewContext(queue: Queue, postbox: Postbox, fileReference: FileMediaReference) -> Signal<QueueLocalObject<FramePreviewContext>, NoError> {
    return Signal { subscriber in
        let source = UniversalSoftwareVideoSource(mediaBox: postbox.mediaBox, fileReference: fileReference)
        let readyDisposable = (source.ready
        |> filter { $0 }).start(next: { _ in
            subscriber.putNext(QueueLocalObject(queue: queue, generate: {
                return FramePreviewContext(source: source)
            }))
        })
        
        return ActionDisposable {
            readyDisposable.dispose()
        }
    }
}

private final class MediaPlayerFramePreviewImpl {
    private let queue: Queue
    private let context: Promise<QueueLocalObject<FramePreviewContext>>
    private let currentFrameDisposable = MetaDisposable()
    private var currentFrameTimestamp: Double?
    private var nextFrameTimestamp: Double?
    fileprivate let framePipe = ValuePipe<FramePreviewResult>()
    
    init(queue: Queue, postbox: Postbox, fileReference: FileMediaReference) {
        self.queue = queue
        self.context = Promise()
        self.context.set(initializedPreviewContext(queue: queue, postbox: postbox, fileReference: fileReference))
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.currentFrameDisposable.dispose()
    }
    
    func generateFrame(at timestamp: Double) {
        if self.currentFrameTimestamp != nil {
            self.nextFrameTimestamp = timestamp
            return
        }
        self.currentFrameTimestamp = timestamp
        
        let queue = self.queue
        let takeDisposable = MetaDisposable()
        let disposable = (self.context.get()
        |> take(1)).start(next: { [weak self] context in
            queue.justDispatch {
                guard context.queue === queue else {
                    return
                }
                context.with { context in
                    let disposable = context.source.takeFrame(at: timestamp).start(next: { result in
                        queue.async {
                            guard let strongSelf = self else {
                                return
                            }
                            switch result {
                            case .waitingForData:
                                strongSelf.framePipe.putNext(.waitingForData)
                            case let .image(image):
                                if let image = image {
                                    strongSelf.framePipe.putNext(.image(image))
                                }
                                strongSelf.currentFrameTimestamp = nil
                                if let nextFrameTimestamp = strongSelf.nextFrameTimestamp {
                                    strongSelf.nextFrameTimestamp = nil
                                    strongSelf.generateFrame(at: nextFrameTimestamp)
                                }
                            }
                        }
                    })
                    takeDisposable.set(disposable)
                }
            }
        })
        self.currentFrameDisposable.set(ActionDisposable {
            queue.async {
                takeDisposable.dispose()
                disposable.dispose()
            }
        })
    }
    
    func cancelPendingFrames() {
        self.nextFrameTimestamp = nil
        self.currentFrameTimestamp = nil
        self.currentFrameDisposable.set(nil)
    }
}

public final class MediaPlayerFramePreview: FramePreview {
    private let queue: Queue
    private let impl: QueueLocalObject<MediaPlayerFramePreviewImpl>
    
    public var generatedFrames: Signal<FramePreviewResult, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.framePipe.signal().start(next: { result in
                    subscriber.putNext(result)
                }))
            }
            return disposable
        }
    }
    
    public init(postbox: Postbox, fileReference: FileMediaReference) {
        let queue = Queue()
        self.queue = queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return MediaPlayerFramePreviewImpl(queue: queue, postbox: postbox, fileReference: fileReference)
        })
    }
    
    public func generateFrame(at timestamp: Double) {
        self.impl.with { impl in
            impl.generateFrame(at: timestamp)
        }
    }
    
    public func cancelPendingFrames() {
        self.impl.with { impl in
            impl.cancelPendingFrames()
        }
    }
}
