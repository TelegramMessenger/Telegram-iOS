import Foundation
import UIKit
import SwiftSignalKit
import Postbox
import TelegramCore
import FFMpegBinding

public func preloadVideoResource(postbox: Postbox, resourceReference: MediaResourceReference, duration: Double) -> Signal<Never, NoError> {
    return Signal { subscriber in
        let queue = Queue()
        let disposable = MetaDisposable()
        queue.async {
            let maximumFetchSize = 2 * 1024 * 1024 + 128 * 1024
            //let maximumFetchSize = 128
            let sourceImpl = FFMpegMediaFrameSource(queue: queue, postbox: postbox, resourceReference: resourceReference, tempFilePath: nil, streamable: true, video: true, preferSoftwareDecoding: false, fetchAutomatically: true, maximumFetchSize: maximumFetchSize)
            let source = QueueLocalObject(queue: queue, generate: {
                return sourceImpl
            })
            let signal = sourceImpl.seek(timestamp: 0.0)
            |> deliverOn(queue)
            |> mapToSignal { result -> Signal<Never, MediaFrameSourceSeekError> in
                let result = result.syncWith({ $0 })
                if let videoBuffer = result.buffers.videoBuffer {
                    let impl = source.syncWith({ $0 })
                    
                    return impl.ensureHasFrames(until: min(duration, videoBuffer.duration.seconds))
                    |> ignoreValues
                    |> castError(MediaFrameSourceSeekError.self)
                } else {
                    return .complete()
                }
            }
            disposable.set(signal.start(error: { _ in
                subscriber.putCompletion()
            }, completed: {
                subscriber.putCompletion()
            }))
        }
        return disposable
    }
}
