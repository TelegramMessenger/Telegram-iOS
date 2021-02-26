import Foundation
import SwiftSignalKit
import TgVoipWebrtc
import UniversalMediaPlayer
import AppBundle
import OpusBinding

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

private final class DemoBroadcastPacketSource {
    private let queue: Queue
    
    private let packetsPipe = ValuePipe<[OngoingGroupCallBroadcastPacket]>()
    var packets: Signal<[OngoingGroupCallBroadcastPacket], NoError> {
        return self.packetsPipe.signal()
    }
    
    private var timer: SwiftSignalKit.Timer?
    
    private var enqueuedPackets: [OngoingGroupCallBroadcastPacket] = []
    private var delayTimer: SwiftSignalKit.Timer?
    
    private var nextIndex: Int = 0
    
    init(queue: Queue) {
        self.queue = queue
        
        self.emitPacketAndStartTimer()
    }
    
    deinit {
        self.timer?.invalidate()
        self.delayTimer?.invalidate()
    }
    
    private func emitPacketAndStartTimer() {
        let demoPacketCount = 200
        let index = self.nextIndex % demoPacketCount
        self.nextIndex += 1
        
        var packets: [OngoingGroupCallBroadcastPacket] = []
        
        let fileName = String(format: "%04d", index)
        if let path = getAppBundle().path(forResource: fileName, ofType: "ogg") {
            let source = SoftwareAudioSource(path: path)
            while true {
                if let frame = source.readFrame() {
                    packets.append(OngoingGroupCallBroadcastPacket(numSamples: Int32(frame.count / 2), data: frame))
                } else {
                    break
                }
            }
        }
        
        if !packets.isEmpty {
            self.enqueuedPackets.append(contentsOf: packets)
            self.startDelayTimer()
        }
        
        let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: false, completion: { [weak self] in
            self?.emitPacketAndStartTimer()
        }, queue: self.queue)
        self.timer = timer
        timer.start()
    }
    
    private func startDelayTimer() {
        let delayTimer = SwiftSignalKit.Timer(timeout: Double.random(in: 0.1 ... 0.3), repeat: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let packets = strongSelf.enqueuedPackets
            strongSelf.enqueuedPackets.removeAll()
            if !packets.isEmpty {
                strongSelf.packetsPipe.putNext(packets)
            }
        }, queue: self.queue)
        self.delayTimer = delayTimer
        delayTimer.start()
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
        
        let videoSources = ValuePromise<Set<UInt32>>(Set(), ignoreRepeated: true)
        
        private var broadcastPacketSource: DemoBroadcastPacketSource?
        private var broadcastPacketsDisposable: Disposable?
        
        init(queue: Queue, inputDeviceId: String, outputDeviceId: String, video: OngoingCallVideoCapturer?, participantDescriptionsRequired: @escaping (Set<UInt32>) -> Void, demoAudioStream: Bool) {
            self.queue = queue
            
            var networkStateUpdatedImpl: ((GroupCallNetworkState) -> Void)?
            var audioLevelsUpdatedImpl: (([NSNumber]) -> Void)?
            
            let videoSources = self.videoSources
            self.context = GroupCallThreadLocalContext(
                queue: ContextQueueImpl(queue: queue),
                networkStateUpdated: { state in
                    networkStateUpdatedImpl?(state)
                },
                audioLevelsUpdated: { levels in
                    audioLevelsUpdatedImpl?(levels)
                },
                inputDeviceId: inputDeviceId,
                outputDeviceId: outputDeviceId,
                videoCapturer: video?.impl,
                incomingVideoSourcesUpdated: { ssrcs in
                    videoSources.set(Set(ssrcs.map { $0.uint32Value }))
                },
                participantDescriptionsRequired: { ssrcs in
                    participantDescriptionsRequired(Set(ssrcs.map { $0.uint32Value }))
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
            
            if demoAudioStream {
                let broadcastPacketSource = DemoBroadcastPacketSource(queue: queue)
                self.broadcastPacketSource = broadcastPacketSource
                self.broadcastPacketsDisposable = (broadcastPacketSource.packets
                |> deliverOn(queue)).start(next: { [weak self] packets in
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.context.add(packets)
                })
            }
            
            /*var packets: [OngoingGroupCallBroadcastPacket] = []
            for i in 0 ..< 200 {
                let fileName = String(format: "%04d", i)
                if let path = getAppBundle().path(forResource: fileName, ofType: "ogg") {
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)) {
                        if let frames = OggOpusReader.extractFrames(data) {
                            for frame in frames {
                                packets.append(OngoingGroupCallBroadcastPacket(numSamples: frame.numSamples, data: frame.data))
                            }
                        }
                    }
                    continue
                    
                    let source = SoftwareAudioSource(path: path)
                    while true {
                        if let (frame, numSamples) = source.readEncodedFrame() {
                            if numSamples != 960 {
                                continue
                            }
                            packets.append(OngoingGroupCallBroadcastPacket(numSamples: Int32(numSamples), data: frame))
                        } else {
                            break
                        }
                        /*if let frame = source.readFrame() {
                            packets.append(frame)
                        } else {
                            break
                        }*/
                    }
                }
            }
            context.add(packets);*/
        }
        
        deinit {
            self.broadcastPacketsDisposable?.dispose()
        }
        
        func setJoinResponse(payload: String, participants: [(UInt32, String?)]) {
            self.context.setJoinResponsePayload(payload, participants: participants.map { participant -> OngoingGroupCallParticipantDescription in
                return OngoingGroupCallParticipantDescription(audioSsrc: participant.0, jsonParams: participant.1)
            })
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
        
        func setFullSizeVideoSsrc(ssrc: UInt32?) {
            self.context.setFullSizeVideoSsrc(ssrc ?? 0)
        }
        
        func addParticipants(participants: [(UInt32, String?)]) {
            if participants.isEmpty {
                return
            }
            self.context.addParticipants(participants.map { participant -> OngoingGroupCallParticipantDescription in
                return OngoingGroupCallParticipantDescription(audioSsrc: participant.0, jsonParams: participant.1)
            })
        }
        
        func stop() {
            self.context.stop()
        }
        
        func setIsMuted(_ isMuted: Bool) {
            self.isMuted.set(isMuted)
            self.context.setIsMuted(isMuted)
        }
        
        func requestVideo(_ capturer: OngoingCallVideoCapturer?) {
            let queue = self.queue
            self.context.requestVideo(capturer?.impl, completion: { [weak self] payload, ssrc in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.joinPayload.set(.single((payload, ssrc)))
                }
            })
        }
        
        public func disableVideo() {
            let queue = self.queue
            self.context.disableVideo({ [weak self] payload, ssrc in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.joinPayload.set(.single((payload, ssrc)))
                }
            })
        }
        
        func switchAudioInput(_ deviceId: String) {
            self.context.switchAudioInput(deviceId)
        }
        
        func switchAudioOutput(_ deviceId: String) {
            self.context.switchAudioOutput(deviceId)
        }
        
        func makeIncomingVideoView(source: UInt32, completion: @escaping (OngoingCallContextPresentationCallVideoView?) -> Void) {
            self.context.makeIncomingVideoView(withSsrc: source, completion: { view in
                if let view = view {
                    #if os(iOS)
                    completion(OngoingCallContextPresentationCallVideoView(
                        view: view,
                        setOnFirstFrameReceived: { [weak view] f in
                            view?.setOnFirstFrameReceived(f)
                        },
                        getOrientation: { [weak view] in
                            if let view = view {
                                return OngoingCallVideoOrientation(view.orientation)
                            } else {
                                return .rotation0
                            }
                        },
                        getAspect: { [weak view] in
                            if let view = view {
                                return view.aspect
                            } else {
                                return 0.0
                            }
                        },
                        setOnOrientationUpdated: { [weak view] f in
                            view?.setOnOrientationUpdated { value, aspect in
                                f?(OngoingCallVideoOrientation(value), aspect)
                            }
                        },
                        setOnIsMirroredUpdated: { [weak view] f in
                            view?.setOnIsMirroredUpdated { value in
                                f?(value)
                            }
                        }
                    ))
                    #else
                    completion(OngoingCallContextPresentationCallVideoView(
                        view: view,
                        setOnFirstFrameReceived: { [weak view] f in
                            view?.setOnFirstFrameReceived(f)
                        },
                        getOrientation: { [weak view] in
                            if let view = view {
                                return OngoingCallVideoOrientation(view.orientation)
                            } else {
                                return .rotation0
                            }
                        },
                        getAspect: { [weak view] in
                            if let view = view {
                                return view.aspect
                            } else {
                                return 0.0
                            }
                        },
                        setOnOrientationUpdated: { [weak view] f in
                            view?.setOnOrientationUpdated { value, aspect in
                                f?(OngoingCallVideoOrientation(value), aspect)
                            }
                        }, setVideoContentMode: { [weak view] mode in
                            view?.setVideoContentMode(mode)
                        },
                        setOnIsMirroredUpdated: { [weak view] f in
                            view?.setOnIsMirroredUpdated { value in
                                f?(value)
                            }
                        }
                    ))
                    #endif
                } else {
                    completion(nil)
                }
            })
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
    
    public var videoSources: Signal<Set<UInt32>, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.videoSources.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public init(inputDeviceId: String = "", outputDeviceId: String = "", video: OngoingCallVideoCapturer?, participantDescriptionsRequired: @escaping (Set<UInt32>) -> Void, demoAudioStream: Bool) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, inputDeviceId: inputDeviceId, outputDeviceId: outputDeviceId, video: video, participantDescriptionsRequired: participantDescriptionsRequired, demoAudioStream: demoAudioStream)
        })
    }
    
    public func setIsMuted(_ isMuted: Bool) {
        self.impl.with { impl in
            impl.setIsMuted(isMuted)
        }
    }
    
    public func requestVideo(_ capturer: OngoingCallVideoCapturer?) {
        self.impl.with { impl in
            impl.requestVideo(capturer)
        }
    }
    
    public func disableVideo() {
        self.impl.with { impl in
            impl.disableVideo()
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
    public func setJoinResponse(payload: String, participants: [(UInt32, String?)]) {
        self.impl.with { impl in
            impl.setJoinResponse(payload: payload, participants: participants)
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
    
    public func setFullSizeVideoSsrc(ssrc: UInt32?) {
        self.impl.with { impl in
            impl.setFullSizeVideoSsrc(ssrc: ssrc)
        }
    }
    
    public func addParticipants(participants: [(UInt32, String?)]) {
        self.impl.with { impl in
            impl.addParticipants(participants: participants)
        }
    }
    
    public func stop() {
        self.impl.with { impl in
            impl.stop()
        }
    }
    
    public func makeIncomingVideoView(source: UInt32, completion: @escaping (OngoingCallContextPresentationCallVideoView?) -> Void) {
        self.impl.with { impl in
            impl.makeIncomingVideoView(source: source, completion: completion)
        }
    }
}
