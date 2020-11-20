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
    
    public struct MemberState: Equatable {
        public var isSpeaking: Bool
    }
    
    private final class Impl {
        let queue: Queue
        let context: GroupCallThreadLocalContext
        
        let sessionId = UInt32.random(in: 0 ..< UInt32(Int32.max))
        var mainStreamAudioSsrc: UInt32?
        var otherSsrcs: [UInt32] = []
        
        let joinPayload = Promise<(String, UInt32)>()
        let networkState = ValuePromise<NetworkState>(.connecting, ignoreRepeated: true)
        let isMuted = ValuePromise<Bool>(true, ignoreRepeated: true)
        let memberStates = ValuePromise<[UInt32: MemberState]>([:], ignoreRepeated: true)
        let audioLevels = ValuePipe<[(UInt32, Float)]>()
        
        init(queue: Queue) {
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
                }
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
                var mappedLevels: [(UInt32, Float)] = []
                var i = 0
                while i < levels.count {
                    mappedLevels.append((levels[i].uint32Value, levels[i + 1].floatValue))
                    i += 2
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
                    strongSelf.mainStreamAudioSsrc = ssrc
                    strongSelf.joinPayload.set(.single((payload, ssrc)))
                }
            })
        }
        
        func setJoinResponse(payload: String, ssrcs: [UInt32]) {
            self.context.setJoinResponsePayload(payload)
            self.addSsrcs(ssrcs: ssrcs)
        }
        
        func addSsrcs(ssrcs: [UInt32]) {
            if ssrcs.isEmpty {
                return
            }
            guard let mainStreamAudioSsrc = self.mainStreamAudioSsrc else {
                return
            }
            let mappedSsrcs = ssrcs
            var otherSsrcs = self.otherSsrcs
            for ssrc in mappedSsrcs {
                if ssrc == mainStreamAudioSsrc {
                    continue
                }
                if !otherSsrcs.contains(ssrc) {
                    otherSsrcs.append(ssrc)
                }
            }
            if self.otherSsrcs != otherSsrcs {
                self.otherSsrcs = otherSsrcs
                var memberStatesValue: [UInt32: MemberState] = [:]
                for ssrc in otherSsrcs {
                    memberStatesValue[ssrc] = MemberState(isSpeaking: false)
                }
                self.memberStates.set(memberStatesValue)
                
                self.context.setSsrcs(self.otherSsrcs.map { ssrc in
                    return ssrc as NSNumber
                })
            }
        }
        
        func removeSsrcs(ssrcs: [UInt32]) {
            if ssrcs.isEmpty {
                return
            }
            guard let mainStreamAudioSsrc = self.mainStreamAudioSsrc else {
                return
            }
            var otherSsrcs = self.otherSsrcs.filter { ssrc in
                return !ssrcs.contains(ssrc)
            }
            if self.otherSsrcs != otherSsrcs {
                self.otherSsrcs = otherSsrcs
                var memberStatesValue: [UInt32: MemberState] = [:]
                for ssrc in otherSsrcs {
                    memberStatesValue[ssrc] = MemberState(isSpeaking: false)
                }
                self.memberStates.set(memberStatesValue)
                
                self.context.setSsrcs(self.otherSsrcs.map { ssrc in
                    return ssrc as NSNumber
                })
            }
        }
        
        func stop() {
            self.context.stop()
        }
        
        func setIsMuted(_ isMuted: Bool) {
            self.isMuted.set(isMuted)
            self.context.setIsMuted(isMuted)
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
    
    public var memberStates: Signal<[UInt32: MemberState], NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.memberStates.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public var audioLevels: Signal<[(UInt32, Float)], NoError> {
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
    
    public init() {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue)
        })
    }
    
    public func setIsMuted(_ isMuted: Bool) {
        self.impl.with { impl in
            impl.setIsMuted(isMuted)
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
    
    public func stop() {
        self.impl.with { impl in
            impl.stop()
        }
    }
}
