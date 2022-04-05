import Foundation
import SwiftSignalKit
import TgVoipWebrtc
import TelegramCore

public final class WrappedMediaStreamingContext {
    private final class Impl {
        let queue: Queue
        let context: MediaStreamingContext
        
        private let broadcastPartsSource = Atomic<BroadcastPartSource?>(value: nil)
        
        init(queue: Queue, rejoinNeeded: @escaping () -> Void) {
            self.queue = queue
            
            var getBroadcastPartsSource: (() -> BroadcastPartSource?)?
            
            self.context = MediaStreamingContext(
                queue: ContextQueueImpl(queue: queue),
                requestCurrentTime: { completion in
                    let disposable = MetaDisposable()

                    queue.async {
                        if let source = getBroadcastPartsSource?() {
                            disposable.set(source.requestTime(completion: completion))
                        } else {
                            completion(0)
                        }
                    }

                    return OngoingGroupCallBroadcastPartTaskImpl(disposable: disposable)
                },
                requestAudioBroadcastPart: { timestampMilliseconds, durationMilliseconds, completion in
                    let disposable = MetaDisposable()
                    
                    queue.async {
                        disposable.set(getBroadcastPartsSource?()?.requestPart(timestampMilliseconds: timestampMilliseconds, durationMilliseconds: durationMilliseconds, subject: .audio, completion: completion, rejoinNeeded: {
                            rejoinNeeded()
                        }))
                    }
                    
                    return OngoingGroupCallBroadcastPartTaskImpl(disposable: disposable)
                },
                requestVideoBroadcastPart: { timestampMilliseconds, durationMilliseconds, channelId, quality, completion in
                    let disposable = MetaDisposable()

                    queue.async {
                        let mappedQuality: OngoingGroupCallContext.VideoChannel.Quality
                        switch quality {
                        case .thumbnail:
                            mappedQuality = .thumbnail
                        case .medium:
                            mappedQuality = .medium
                        case .full:
                            mappedQuality = .full
                        @unknown default:
                            mappedQuality = .thumbnail
                        }
                        disposable.set(getBroadcastPartsSource?()?.requestPart(timestampMilliseconds: timestampMilliseconds, durationMilliseconds: durationMilliseconds, subject: .video(channelId: channelId, quality: mappedQuality), completion: completion, rejoinNeeded: {
                            rejoinNeeded()
                        }))
                    }

                    return OngoingGroupCallBroadcastPartTaskImpl(disposable: disposable)
                }
            )
            
            let broadcastPartsSource = self.broadcastPartsSource
            getBroadcastPartsSource = {
                return broadcastPartsSource.with { $0 }
            }
        }
        
        deinit {
        }
        
        func setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData?) {
            if let audioStreamData = audioStreamData {
                let broadcastPartsSource = NetworkBroadcastPartSource(queue: self.queue, engine: audioStreamData.engine, callId: audioStreamData.callId, accessHash: audioStreamData.accessHash, isExternalStream: audioStreamData.isExternalStream)
                let _ = self.broadcastPartsSource.swap(broadcastPartsSource)
                self.context.start()
            }
        }

        func video() -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
            let queue = self.queue
            return Signal { [weak self] subscriber in
                let disposable = MetaDisposable()

                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    let innerDisposable = strongSelf.context.addVideoOutput() { videoFrameData in
                        subscriber.putNext(OngoingGroupCallContext.VideoFrameData(frameData: videoFrameData))
                    }
                    disposable.set(ActionDisposable {
                        innerDisposable.dispose()
                    })
                }

                return disposable
            }
        }
    }
    
    private let queue = Queue()
    private let impl: QueueLocalObject<Impl>
    
    public init(rejoinNeeded: @escaping () -> Void) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, rejoinNeeded: rejoinNeeded)
        })
    }
    
    public func setAudioStreamData(audioStreamData: OngoingGroupCallContext.AudioStreamData?) {
        self.impl.with { impl in
            impl.setAudioStreamData(audioStreamData: audioStreamData)
        }
    }

    public func video() -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.video().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
}
