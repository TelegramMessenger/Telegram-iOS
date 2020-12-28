import Foundation
import SwiftSignalKit
import TgVoipWebrtc

private final class ContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueueWebrtc {
    private let queue: Queue
    
    init(queue: Queue) {
        self.queue = queue
        
        super.init()
    }
    
    func dispatch(_ f: @escaping () -> Void) {
        self.queue.async {
            f()
        }
    }
    
    func dispatch(after seconds: Double, block f: @escaping () -> Void) {
        self.queue.after(seconds, f)
    }
    
    func isCurrent() -> Bool {
        return self.queue.isCurrent()
    }
}

public final class OngoingGroupCallContext {
    public enum NetworkState {
        case connecting
        case connected
    }
    
    public enum AudioLevelKey: Hashable {
        case local
        case source(UInt32)
    }
    
    private final class Impl {
        let queue: Queue
        let context: GroupCallThreadLocalContext
        
        let sessionId = UInt32.random(in: 0 ..< UInt32(Int32.max))
        
        let joinPayload = Promise<(String, UInt32)>()
        let networkState = ValuePromise<NetworkState>(.connecting, ignoreRepeated: true)
        let isMuted = ValuePromise<Bool>(true, ignoreRepeated: true)
        let audioLevels = ValuePipe<[(AudioLevelKey, Float, Bool)]>()
        
        init(queue: Queue, inputDeviceId: String, outputDeviceId: String) {
            self.queue = queue
            
            var networkStateUpdatedImpl: ((GroupCallNetworkState) -> Void)?
            var audioLevelsUpdatedImpl: (([NSNumber]) -> Void)?
            
            self.context = GroupCallThreadLocalContext(
                queue: ContextQueueImpl(queue: queue),
                networkStateUpdated: { state in
                    networkStateUpdatedImpl?(state)
                },
                audioLevelsUpdated: { levels in
                    audioLevelsUpdatedImpl?(levels)
                },
                inputDeviceId: inputDeviceId,
                outputDeviceId: outputDeviceId
            )
            
            let queue = self.queue
            
            networkStateUpdatedImpl = { [weak self] state in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    let mappedState: NetworkState
                    switch state {
                    case .connecting:
                        mappedState = .connecting
                    case .connected:
                        mappedState = .connected
                    @unknown default:
                        mappedState = .connecting
                    }
                    strongSelf.networkState.set(mappedState)
                }
            }
            
            let audioLevels = self.audioLevels
            audioLevelsUpdatedImpl = { levels in
                var mappedLevels: [(AudioLevelKey, Float, Bool)] = []
                var i = 0
                while i < levels.count {
                    let uintValue = levels[i].uint32Value
                    let key: AudioLevelKey
                    if uintValue == 0 {
                        key = .local
                    } else {
                        key = .source(uintValue)
                    }
                    mappedLevels.append((key, levels[i + 1].floatValue, levels[i + 2].boolValue))
                    i += 3
                }
                queue.async {
                    audioLevels.putNext(mappedLevels)
                }
            }
            
            self.context.emitJoinPayload({ [weak self] payload, ssrc in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.joinPayload.set(.single((payload, ssrc)))
                }
            })
        }
        
        func setJoinResponse(payload: String, ssrcs: [UInt32]) {
            self.context.setJoinResponsePayload(payload)
            self.addSsrcs(ssrcs: ssrcs)
        }
        
        func addSsrcs(ssrcs: [UInt32]) {
        }
        
        func removeSsrcs(ssrcs: [UInt32]) {
            if ssrcs.isEmpty {
                return
            }
            self.context.removeSsrcs(ssrcs.map { ssrc in
                return ssrc as NSNumber
            })
        }
        
        func setVolume(ssrc: UInt32, volume: Double) {
            self.context.setVolumeForSsrc(ssrc, volume: volume)
        }
        
        func stop() {
            self.context.stop()
        }
        
        func setIsMuted(_ isMuted: Bool) {
            self.isMuted.set(isMuted)
            self.context.setIsMuted(isMuted)
        }
        
        func switchAudioInput(_ deviceId: String) {
            self.context.switchAudioInput(deviceId)
        }
        func switchAudioOutput(_ deviceId: String) {
            self.context.switchAudioOutput(deviceId)
        }
    }
    
    private let queue = Queue()
    private let impl: QueueLocalObject<Impl>
    
    public var joinPayload: Signal<(String, UInt32), NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.joinPayload.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public var networkState: Signal<NetworkState, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.networkState.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public var audioLevels: Signal<[(AudioLevelKey, Float, Bool)], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.audioLevels.signal().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public var isMuted: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isMuted.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public init(inputDeviceId: String = "", outputDeviceId: String = "") {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, inputDeviceId: inputDeviceId, outputDeviceId: outputDeviceId)
        })
    }
    
    public func setIsMuted(_ isMuted: Bool) {
        self.impl.with { impl in
            impl.setIsMuted(isMuted)
        }
    }
    
    public func switchAudioInput(_ deviceId: String) {
        self.impl.with { impl in
            impl.switchAudioInput(deviceId)
        }
    }
    public func switchAudioOutput(_ deviceId: String) {
        self.impl.with { impl in
            impl.switchAudioOutput(deviceId)
        }
    }
    public func setJoinResponse(payload: String, ssrcs: [UInt32]) {
        self.impl.with { impl in
            impl.setJoinResponse(payload: payload, ssrcs: ssrcs)
        }
    }
    
    public func addSsrcs(ssrcs: [UInt32]) {
        self.impl.with { impl in
            impl.addSsrcs(ssrcs: ssrcs)
        }
    }
    
    public func removeSsrcs(ssrcs: [UInt32]) {
        self.impl.with { impl in
            impl.removeSsrcs(ssrcs: ssrcs)
        }
    }
    
    public func setVolume(ssrc: UInt32, volume: Double) {
        self.impl.with { impl in
            impl.setVolume(ssrc: ssrc, volume: volume)
        }
    }
    
    public func stop() {
        self.impl.with { impl in
            impl.stop()
        }
    }
}
