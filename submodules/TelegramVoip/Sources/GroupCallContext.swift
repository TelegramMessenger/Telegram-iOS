import Foundation
import SwiftSignalKit
import TgVoipWebrtc
import TelegramCore
import Postbox

final class ContextQueueImpl: NSObject, OngoingCallThreadLocalContextQueueWebrtc {
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

enum BroadcastPartSubject {
    case audio
    case video(channelId: Int32, quality: OngoingGroupCallContext.VideoChannel.Quality)
}

protocol BroadcastPartSource: AnyObject {
    func requestTime(completion: @escaping (Int64) -> Void) -> Disposable
    func requestPart(timestampMilliseconds: Int64, durationMilliseconds: Int64, subject: BroadcastPartSubject, completion: @escaping (OngoingGroupCallBroadcastPart) -> Void, rejoinNeeded: @escaping () -> Void) -> Disposable
}

final class NetworkBroadcastPartSource: BroadcastPartSource {
    private let queue: Queue
    private let engine: TelegramEngine
    private let callId: Int64
    private let accessHash: Int64
    private let isExternalStream: Bool
    private var dataSource: AudioBroadcastDataSource?
    
    #if DEBUG
    private let debugDumpDirectory = TempBox.shared.tempDirectory()
    #endif
    
    init(queue: Queue, engine: TelegramEngine, callId: Int64, accessHash: Int64, isExternalStream: Bool) {
        self.queue = queue
        self.engine = engine
        self.callId = callId
        self.accessHash = accessHash
        self.isExternalStream = isExternalStream
    }

    func requestTime(completion: @escaping (Int64) -> Void) -> Disposable {
        if self.isExternalStream {
            let dataSource: Signal<AudioBroadcastDataSource?, NoError>
            if let dataSourceValue = self.dataSource {
                dataSource = .single(dataSourceValue)
            } else {
                dataSource = self.engine.calls.getAudioBroadcastDataSource(callId: self.callId, accessHash: self.accessHash)
            }
            
            let engine = self.engine
            let callId = self.callId
            let accessHash = self.accessHash
            
            return (dataSource
            |> deliverOn(self.queue)
            |> mapToSignal { [weak self] dataSource -> Signal<EngineCallStreamState?, NoError> in
                if let dataSource = dataSource {
                    self?.dataSource = dataSource
                    return engine.calls.requestStreamState(dataSource: dataSource, callId: callId, accessHash: accessHash)
                } else {
                    return .single(nil)
                }
            }
            |> deliverOn(self.queue)).start(next: { result in
                if let channel = result?.channels.first {
                    completion(channel.latestTimestamp)
                } else {
                    completion(0)
                }
            })
        } else {
            return self.engine.calls.serverTime().start(next: { result in
                completion(result)
            })
        }
    }

    func requestPart(timestampMilliseconds: Int64, durationMilliseconds: Int64, subject: BroadcastPartSubject, completion: @escaping (OngoingGroupCallBroadcastPart) -> Void, rejoinNeeded: @escaping () -> Void) -> Disposable {
        let timestampIdMilliseconds: Int64
        if timestampMilliseconds != 0 {
            timestampIdMilliseconds = timestampMilliseconds
        } else {
            timestampIdMilliseconds = (Int64((Date().timeIntervalSince1970) * 1000.0) / durationMilliseconds) * durationMilliseconds
        }
        
        let dataSource: Signal<AudioBroadcastDataSource?, NoError>
        if let dataSourceValue = self.dataSource {
            dataSource = .single(dataSourceValue)
        } else {
            dataSource = self.engine.calls.getAudioBroadcastDataSource(callId: self.callId, accessHash: self.accessHash)
        }

        let callId = self.callId
        let accessHash = self.accessHash
        let engine = self.engine
        
        let queue = self.queue
        let signal = dataSource
        |> deliverOn(self.queue)
        |> mapToSignal { [weak self] dataSource -> Signal<GetAudioBroadcastPartResult?, NoError> in
            if let dataSource = dataSource {
                self?.dataSource = dataSource
                switch subject {
                case .audio:
                    return engine.calls.getAudioBroadcastPart(dataSource: dataSource, callId: callId, accessHash: accessHash, timestampIdMilliseconds: timestampIdMilliseconds, durationMilliseconds: durationMilliseconds)
                    |> map(Optional.init)
                case let .video(channelId, quality):
                    let mappedQuality: Int32
                    switch quality {
                    case .thumbnail:
                        mappedQuality = 0
                    case .medium:
                        mappedQuality = 1
                    case .full:
                        mappedQuality = 2
                    }
                    return engine.calls.getVideoBroadcastPart(dataSource: dataSource, callId: callId, accessHash: accessHash, timestampIdMilliseconds: timestampIdMilliseconds, durationMilliseconds: durationMilliseconds, channelId: channelId, quality: mappedQuality)
                    |> map(Optional.init)
                }
            } else {
                return .single(nil)
                |> delay(2.0, queue: queue)
            }
        }
        |> deliverOn(self.queue)
            
        /*#if DEBUG
        let debugDumpDirectory = self.debugDumpDirectory
        #endif*/
        return signal.start(next: { result in
            guard let result = result else {
                completion(OngoingGroupCallBroadcastPart(timestampMilliseconds: timestampIdMilliseconds, responseTimestamp: Double(timestampIdMilliseconds), status: .notReady, oggData: Data()))
                return
            }
            let part: OngoingGroupCallBroadcastPart
            switch result.status {
            case let .data(dataValue):
                /*#if DEBUG
                let tempFilePath = debugDumpDirectory.path + "/\(timestampMilliseconds).mp4"
                let _ = try? dataValue.subdata(in: 32 ..< dataValue.count).write(to: URL(fileURLWithPath: tempFilePath))
                print("Dump stream part: \(tempFilePath)")
                #endif*/
                part = OngoingGroupCallBroadcastPart(timestampMilliseconds: timestampIdMilliseconds, responseTimestamp: result.responseTimestamp, status: .success, oggData: dataValue)
            case .notReady:
                part = OngoingGroupCallBroadcastPart(timestampMilliseconds: timestampIdMilliseconds, responseTimestamp: result.responseTimestamp, status: .notReady, oggData: Data())
            case .resyncNeeded:
                part = OngoingGroupCallBroadcastPart(timestampMilliseconds: timestampIdMilliseconds, responseTimestamp: result.responseTimestamp, status: .resyncNeeded, oggData: Data())
            case .rejoinNeeded:
                rejoinNeeded()
                return
            }
            
            completion(part)
        })
    }
}

final class OngoingGroupCallBroadcastPartTaskImpl: NSObject, OngoingGroupCallBroadcastPartTask {
    private let disposable: Disposable?
    
    init(disposable: Disposable?) {
        self.disposable = disposable
    }
    
    func cancel() {
        self.disposable?.dispose()
    }
}

public final class OngoingGroupCallContext {
    public struct AudioStreamData {
        public var engine: TelegramEngine
        public var callId: Int64
        public var accessHash: Int64
        public var isExternalStream: Bool
        
        public init(engine: TelegramEngine, callId: Int64, accessHash: Int64, isExternalStream: Bool) {
            self.engine = engine
            self.callId = callId
            self.accessHash = accessHash
            self.isExternalStream = isExternalStream
        }
    }
    
    public enum ConnectionMode {
        case none
        case rtc
        case broadcast
    }
    
    public enum VideoContentType {
        case none
        case generic
        case screencast
    }
    
    public struct NetworkState: Equatable {
        public var isConnected: Bool
        public var isTransitioningFromBroadcastToRtc: Bool
        
        public init(isConnected: Bool, isTransitioningFromBroadcastToRtc: Bool) {
            self.isConnected = isConnected
            self.isTransitioningFromBroadcastToRtc = isTransitioningFromBroadcastToRtc
        }
    }
    
    public enum AudioLevelKey: Hashable {
        case local
        case source(UInt32)
    }

    public struct MediaChannelDescription {
        public enum Kind {
            case audio
            case video
        }

        public var kind: Kind
        public var audioSsrc: UInt32
        public var videoDescription: String?

        public init(kind: Kind, audioSsrc: UInt32, videoDescription: String?) {
            self.kind = kind
            self.audioSsrc = audioSsrc
            self.videoDescription = videoDescription
        }
    }

    public struct VideoChannel: Equatable {
        public enum Quality {
            case thumbnail
            case medium
            case full
        }

        public struct SsrcGroup: Equatable {
            public var semantics: String
            public var ssrcs: [UInt32]

            public init(semantics: String, ssrcs: [UInt32]) {
                self.semantics = semantics
                self.ssrcs = ssrcs
            }
        }

        public var audioSsrc: UInt32
        public var endpointId: String
        public var ssrcGroups: [SsrcGroup]
        public var minQuality: Quality
        public var maxQuality: Quality

        public init(audioSsrc: UInt32, endpointId: String, ssrcGroups: [SsrcGroup], minQuality: Quality, maxQuality: Quality) {
            self.audioSsrc = audioSsrc
            self.endpointId = endpointId
            self.ssrcGroups = ssrcGroups
            self.minQuality = minQuality
            self.maxQuality = maxQuality
        }
    }

    public final class VideoFrameData {
        public final class NativeBuffer {
            public let pixelBuffer: CVPixelBuffer

            init(pixelBuffer: CVPixelBuffer) {
                self.pixelBuffer = pixelBuffer
            }
        }

        public final class NV12Buffer {
            private let wrapped: CallVideoFrameNV12Buffer

            public var width: Int {
                return Int(self.wrapped.width)
            }

            public var height: Int {
                return Int(self.wrapped.height)
            }

            public var y: Data {
                return self.wrapped.y
            }

            public var strideY: Int {
                return Int(self.wrapped.strideY)
            }

            public var uv: Data {
                return self.wrapped.uv
            }

            public var strideUV: Int {
                return Int(self.wrapped.strideUV)
            }

            init(wrapped: CallVideoFrameNV12Buffer) {
                self.wrapped = wrapped
            }
        }

        public final class I420Buffer {
            private let wrapped: CallVideoFrameI420Buffer

            public var width: Int {
                return Int(self.wrapped.width)
            }

            public var height: Int {
                return Int(self.wrapped.height)
            }

            public var y: Data {
                return self.wrapped.y
            }

            public var strideY: Int {
                return Int(self.wrapped.strideY)
            }

            public var u: Data {
                return self.wrapped.u
            }

            public var strideU: Int {
                return Int(self.wrapped.strideU)
            }

            public var v: Data {
                return self.wrapped.v
            }

            public var strideV: Int {
                return Int(self.wrapped.strideV)
            }

            init(wrapped: CallVideoFrameI420Buffer) {
                self.wrapped = wrapped
            }
        }

        public enum Buffer {
            case native(NativeBuffer)
            case nv12(NV12Buffer)
            case i420(I420Buffer)
        }

        public let buffer: Buffer
        public let width: Int
        public let height: Int
        public let orientation: OngoingCallVideoOrientation
        public let mirrorHorizontally: Bool
        public let mirrorVertically: Bool

        init(frameData: CallVideoFrameData) {
            if let nativeBuffer = frameData.buffer as? CallVideoFrameNativePixelBuffer {
                self.buffer = .native(NativeBuffer(pixelBuffer: nativeBuffer.pixelBuffer))
            } else if let nv12Buffer = frameData.buffer as? CallVideoFrameNV12Buffer {
                self.buffer = .nv12(NV12Buffer(wrapped: nv12Buffer))
            } else if let i420Buffer = frameData.buffer as? CallVideoFrameI420Buffer {
                self.buffer = .i420(I420Buffer(wrapped: i420Buffer))
            } else {
                preconditionFailure()
            }

            self.width = Int(frameData.width)
            self.height = Int(frameData.height)
            self.orientation = OngoingCallVideoOrientation(frameData.orientation)
            self.mirrorHorizontally = frameData.mirrorHorizontally
            self.mirrorVertically = frameData.mirrorVertically
        }
    }

    public struct Stats {
        public struct IncomingVideoStats {
            public var receivingQuality: Int
            public var availableQuality: Int
        }

        public var incomingVideoStats: [String: IncomingVideoStats]
    }
    
    private final class Impl {
        let queue: Queue
        let context: GroupCallThreadLocalContext
        
        let sessionId = UInt32.random(in: 0 ..< UInt32(Int32.max))
        
        let joinPayload = Promise<(String, UInt32)>()
        let networkState = ValuePromise<NetworkState>(NetworkState(isConnected: false, isTransitioningFromBroadcastToRtc: false), ignoreRepeated: true)
        let isMuted = ValuePromise<Bool>(true, ignoreRepeated: true)
        let isNoiseSuppressionEnabled = ValuePromise<Bool>(true, ignoreRepeated: true)
        let audioLevels = ValuePipe<[(AudioLevelKey, Float, Bool)]>()

        private var currentRequestedVideoChannels: [VideoChannel] = []
        
        private let broadcastPartsSource = Atomic<BroadcastPartSource?>(value: nil)
        
        init(queue: Queue, inputDeviceId: String, outputDeviceId: String, video: OngoingCallVideoCapturer?, requestMediaChannelDescriptions: @escaping (Set<UInt32>, @escaping ([MediaChannelDescription]) -> Void) -> Disposable, rejoinNeeded: @escaping () -> Void, outgoingAudioBitrateKbit: Int32?, videoContentType: VideoContentType, enableNoiseSuppression: Bool, disableAudioInput: Bool, preferX264: Bool) {
            self.queue = queue
            
            var networkStateUpdatedImpl: ((GroupCallNetworkState) -> Void)?
            var audioLevelsUpdatedImpl: (([NSNumber]) -> Void)?
            
            let _videoContentType: OngoingGroupCallVideoContentType
            switch videoContentType {
            case .generic:
                _videoContentType = .generic
            case .screencast:
                _videoContentType = .screencast
            case .none:
                _videoContentType = .none
            }
            
            var getBroadcastPartsSource: (() -> BroadcastPartSource?)?

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
                requestMediaChannelDescriptions: { ssrcs, completion in
                    final class OngoingGroupCallMediaChannelDescriptionTaskImpl : NSObject, OngoingGroupCallMediaChannelDescriptionTask {
                        private let disposable: Disposable

                        init(disposable: Disposable) {
                            self.disposable = disposable
                        }

                        func cancel() {
                            self.disposable.dispose()
                        }
                    }

                    let disposable = requestMediaChannelDescriptions(Set(ssrcs.map { $0.uint32Value }), { channels in
                        completion(channels.map { channel -> OngoingGroupCallMediaChannelDescription in
                            let mappedType: OngoingGroupCallMediaChannelType
                            switch channel.kind {
                            case .audio:
                                mappedType = .audio
                            case .video:
                                mappedType = .video
                            }
                            return OngoingGroupCallMediaChannelDescription(
                                type: mappedType,
                                audioSsrc: channel.audioSsrc,
                                videoDescription: channel.videoDescription
                            )
                        })
                    })

                    return OngoingGroupCallMediaChannelDescriptionTaskImpl(disposable: disposable)
                },
                requestCurrentTime: { completion in
                    let disposable = MetaDisposable()

                    queue.async {
                        disposable.set(getBroadcastPartsSource?()?.requestTime(completion: completion))
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
                },
                outgoingAudioBitrateKbit: outgoingAudioBitrateKbit ?? 32,
                videoContentType: _videoContentType,
                enableNoiseSuppression: enableNoiseSuppression,
                disableAudioInput: disableAudioInput,
                preferX264: preferX264
            )
            
            let queue = self.queue
            
            let broadcastPartsSource = self.broadcastPartsSource
            getBroadcastPartsSource = {
                return broadcastPartsSource.with { $0 }
            }
            
            networkStateUpdatedImpl = { [weak self] state in
                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    strongSelf.networkState.set(NetworkState(isConnected: state.isConnected, isTransitioningFromBroadcastToRtc: state.isTransitioningFromBroadcastToRtc))
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
        
        deinit {
        }
        
        func setJoinResponse(payload: String) {
            self.context.setJoinResponsePayload(payload)
        }
        
        func setAudioStreamData(audioStreamData: AudioStreamData?) {
            if let audioStreamData = audioStreamData {
                let broadcastPartsSource = NetworkBroadcastPartSource(queue: self.queue, engine: audioStreamData.engine, callId: audioStreamData.callId, accessHash: audioStreamData.accessHash, isExternalStream: audioStreamData.isExternalStream)
                let _ = self.broadcastPartsSource.swap(broadcastPartsSource)
            }
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

        func removeIncomingVideoSource(_ ssrc: UInt32) {
            self.context.removeIncomingVideoSource(ssrc)
        }
        
        func setVolume(ssrc: UInt32, volume: Double) {
            self.context.setVolumeForSsrc(ssrc, volume: volume)
        }

        func setRequestedVideoChannels(_ channels: [VideoChannel]) {
            if self.currentRequestedVideoChannels != channels {
                self.currentRequestedVideoChannels = channels

                self.context.setRequestedVideoChannels(channels.map { channel -> OngoingGroupCallRequestedVideoChannel in
                    let mappedMinQuality: OngoingGroupCallRequestedVideoQuality
                    switch channel.minQuality {
                    case .thumbnail:
                        mappedMinQuality = .thumbnail
                    case .medium:
                        mappedMinQuality = .medium
                    case .full:
                        mappedMinQuality = .full
                    }
                    let mappedMaxQuality: OngoingGroupCallRequestedVideoQuality
                    switch channel.maxQuality {
                    case .thumbnail:
                        mappedMaxQuality = .thumbnail
                    case .medium:
                        mappedMaxQuality = .medium
                    case .full:
                        mappedMaxQuality = .full
                    }
                    return OngoingGroupCallRequestedVideoChannel(
                        audioSsrc: channel.audioSsrc,
                        endpointId: channel.endpointId,
                        ssrcGroups: channel.ssrcGroups.map { group in
                            return OngoingGroupCallSsrcGroup(
                                semantics: group.semantics,
                                ssrcs: group.ssrcs.map { $0 as NSNumber })
                        },
                        minQuality: mappedMinQuality,
                        maxQuality: mappedMaxQuality
                    )
                })
            }
        }
        
        func stop() {
            self.context.stop()
        }
        
        func setConnectionMode(_ connectionMode: ConnectionMode, keepBroadcastConnectedIfWasEnabled: Bool, isUnifiedBroadcast: Bool) {
            let mappedConnectionMode: OngoingCallConnectionMode
            switch connectionMode {
            case .none:
                mappedConnectionMode = .none
            case .rtc:
                mappedConnectionMode = .rtc
            case .broadcast:
                mappedConnectionMode = .broadcast
            }
            self.context.setConnectionMode(mappedConnectionMode, keepBroadcastConnectedIfWasEnabled: keepBroadcastConnectedIfWasEnabled, isUnifiedBroadcast: isUnifiedBroadcast)
            
            if (mappedConnectionMode != .rtc) {
                self.joinPayload.set(.never())
                
                let queue = self.queue
                self.context.emitJoinPayload({ [weak self] payload, ssrc in
                    queue.async {
                        guard let strongSelf = self else {
                            return
                        }
                        strongSelf.joinPayload.set(.single((payload, ssrc)))
                    }
                })
            }
        }
        
        func setIsMuted(_ isMuted: Bool) {
            self.isMuted.set(isMuted)
            self.context.setIsMuted(isMuted)
        }

        func setIsNoiseSuppressionEnabled(_ isNoiseSuppressionEnabled: Bool) {
            self.isNoiseSuppressionEnabled.set(isNoiseSuppressionEnabled)
            self.context.setIsNoiseSuppressionEnabled(isNoiseSuppressionEnabled)
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
        
        func makeIncomingVideoView(endpointId: String, requestClone: Bool, completion: @escaping (OngoingCallContextPresentationCallVideoView?, OngoingCallContextPresentationCallVideoView?) -> Void) {
            self.context.makeIncomingVideoView(withEndpointId: endpointId, requestClone: requestClone, completion: { mainView, cloneView in
                if let mainView = mainView {
                    #if os(iOS)
                    let mainVideoView = OngoingCallContextPresentationCallVideoView(
                        view: mainView,
                        setOnFirstFrameReceived: { [weak mainView] f in
                            mainView?.setOnFirstFrameReceived(f)
                        },
                        getOrientation: { [weak mainView] in
                            if let mainView = mainView {
                                return OngoingCallVideoOrientation(mainView.orientation)
                            } else {
                                return .rotation0
                            }
                        },
                        getAspect: { [weak mainView] in
                            if let mainView = mainView {
                                return mainView.aspect
                            } else {
                                return 0.0
                            }
                        },
                        setOnOrientationUpdated: { [weak mainView] f in
                            mainView?.setOnOrientationUpdated { value, aspect in
                                f?(OngoingCallVideoOrientation(value), aspect)
                            }
                        },
                        setOnIsMirroredUpdated: { [weak mainView] f in
                            mainView?.setOnIsMirroredUpdated { value in
                                f?(value)
                            }
                        },
                        updateIsEnabled: { [weak mainView] value in
                            mainView?.updateIsEnabled(value)
                        }
                    )
                    var cloneVideoView: OngoingCallContextPresentationCallVideoView?
                    if let cloneView = cloneView {
                        cloneVideoView = OngoingCallContextPresentationCallVideoView(
                            view: cloneView,
                            setOnFirstFrameReceived: { [weak cloneView] f in
                                cloneView?.setOnFirstFrameReceived(f)
                            },
                            getOrientation: { [weak cloneView] in
                                if let cloneView = cloneView {
                                    return OngoingCallVideoOrientation(cloneView.orientation)
                                } else {
                                    return .rotation0
                                }
                            },
                            getAspect: { [weak cloneView] in
                                if let cloneView = cloneView {
                                    return cloneView.aspect
                                } else {
                                    return 0.0
                                }
                            },
                            setOnOrientationUpdated: { [weak cloneView] f in
                                cloneView?.setOnOrientationUpdated { value, aspect in
                                    f?(OngoingCallVideoOrientation(value), aspect)
                                }
                            },
                            setOnIsMirroredUpdated: { [weak cloneView] f in
                                cloneView?.setOnIsMirroredUpdated { value in
                                    f?(value)
                                }
                            },
                            updateIsEnabled: { [weak cloneView] value in
                                cloneView?.updateIsEnabled(value)
                            }
                        )
                    }
                    completion(mainVideoView, cloneVideoView)
                    #else
                    let mainVideoView = OngoingCallContextPresentationCallVideoView(
                        view: mainView,
                        setOnFirstFrameReceived: { [weak mainView] f in
                            mainView?.setOnFirstFrameReceived(f)
                        },
                        getOrientation: { [weak mainView] in
                            if let mainView = mainView {
                                return OngoingCallVideoOrientation(mainView.orientation)
                            } else {
                                return .rotation0
                            }
                        },
                        getAspect: { [weak mainView] in
                            if let mainView = mainView {
                                return mainView.aspect
                            } else {
                                return 0.0
                            }
                        },
                        setOnOrientationUpdated: { [weak mainView] f in
                            mainView?.setOnOrientationUpdated { value, aspect in
                                f?(OngoingCallVideoOrientation(value), aspect)
                            }
                        }, setVideoContentMode: { [weak mainView] mode in
                            mainView?.setVideoContentMode(mode)
                        },
                        setOnIsMirroredUpdated: { [weak mainView] f in
                            mainView?.setOnIsMirroredUpdated { value in
                                f?(value)
                            }
                        }, setIsPaused: { [weak mainView] paused in
                            mainView?.setIsPaused(paused)
                        }, renderToSize: { [weak mainView] size, animated in
                            mainView?.render(to: size, animated: animated)
                        }
                    )
                    completion(mainVideoView, nil)
                    #endif
                } else {
                    completion(nil, nil)
                }
            })
        }

        func video(endpointId: String) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
            let queue = self.queue
            return Signal { [weak self] subscriber in
                let disposable = MetaDisposable()

                queue.async {
                    guard let strongSelf = self else {
                        return
                    }
                    let innerDisposable = strongSelf.context.addVideoOutput(withEndpointId: endpointId) { videoFrameData in
                        subscriber.putNext(OngoingGroupCallContext.VideoFrameData(frameData: videoFrameData))
                    }
                    disposable.set(ActionDisposable {
                        innerDisposable.dispose()
                    })
                }

                return disposable
            }
        }

        func addExternalAudioData(data: Data) {
            self.context.addExternalAudioData(data)
        }

        func getStats(completion: @escaping (Stats) -> Void) {
            self.context.getStats({ stats in
                var incomingVideoStats: [String: Stats.IncomingVideoStats] = [:]
                for (key, value) in stats.incomingVideoStats {
                    incomingVideoStats[key] = Stats.IncomingVideoStats(receivingQuality: Int(value.receivingQuality), availableQuality: Int(value.availableQuality))
                }
                completion(Stats(incomingVideoStats: incomingVideoStats))
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

    public var isNoiseSuppressionEnabled: Signal<Bool, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.isNoiseSuppressionEnabled.get().start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }
    
    public init(inputDeviceId: String = "", outputDeviceId: String = "", video: OngoingCallVideoCapturer?, requestMediaChannelDescriptions: @escaping (Set<UInt32>, @escaping ([MediaChannelDescription]) -> Void) -> Disposable, rejoinNeeded: @escaping () -> Void, outgoingAudioBitrateKbit: Int32?, videoContentType: VideoContentType, enableNoiseSuppression: Bool, disableAudioInput: Bool, preferX264: Bool) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return Impl(queue: queue, inputDeviceId: inputDeviceId, outputDeviceId: outputDeviceId, video: video, requestMediaChannelDescriptions: requestMediaChannelDescriptions, rejoinNeeded: rejoinNeeded, outgoingAudioBitrateKbit: outgoingAudioBitrateKbit, videoContentType: videoContentType, enableNoiseSuppression: enableNoiseSuppression, disableAudioInput: disableAudioInput, preferX264: preferX264)
        })
    }
    
    public func setConnectionMode(_ connectionMode: ConnectionMode, keepBroadcastConnectedIfWasEnabled: Bool, isUnifiedBroadcast: Bool) {
        self.impl.with { impl in
            impl.setConnectionMode(connectionMode, keepBroadcastConnectedIfWasEnabled: keepBroadcastConnectedIfWasEnabled, isUnifiedBroadcast: isUnifiedBroadcast)
        }
    }
    
    public func setIsMuted(_ isMuted: Bool) {
        self.impl.with { impl in
            impl.setIsMuted(isMuted)
        }
    }

    public func setIsNoiseSuppressionEnabled(_ isNoiseSuppressionEnabled: Bool) {
        self.impl.with { impl in
            impl.setIsNoiseSuppressionEnabled(isNoiseSuppressionEnabled)
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
    
    public func setJoinResponse(payload: String) {
        self.impl.with { impl in
            impl.setJoinResponse(payload: payload)
        }
    }
    
    public func setAudioStreamData(audioStreamData: AudioStreamData?) {
        self.impl.with { impl in
            impl.setAudioStreamData(audioStreamData: audioStreamData)
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

    public func removeIncomingVideoSource(_ ssrc: UInt32) {
        self.impl.with { impl in
            impl.removeIncomingVideoSource(ssrc)
        }
    }
    
    public func setVolume(ssrc: UInt32, volume: Double) {
        self.impl.with { impl in
            impl.setVolume(ssrc: ssrc, volume: volume)
        }
    }

    public func setRequestedVideoChannels(_ channels: [VideoChannel]) {
        self.impl.with { impl in
            impl.setRequestedVideoChannels(channels)
        }
    }
    
    public func stop() {
        self.impl.with { impl in
            impl.stop()
        }
    }
    
    public func makeIncomingVideoView(endpointId: String, requestClone: Bool, completion: @escaping (OngoingCallContextPresentationCallVideoView?, OngoingCallContextPresentationCallVideoView?) -> Void) {
        self.impl.with { impl in
            impl.makeIncomingVideoView(endpointId: endpointId, requestClone: requestClone, completion: completion)
        }
    }

    public func video(endpointId: String) -> Signal<OngoingGroupCallContext.VideoFrameData, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.video(endpointId: endpointId).start(next: { value in
                    subscriber.putNext(value)
                }))
            }
            return disposable
        }
    }

    public func addExternalAudioData(data: Data) {
        self.impl.with { impl in
            impl.addExternalAudioData(data: data)
        }
    }

    public func getStats(completion: @escaping (Stats) -> Void) {
        self.impl.with { impl in
            impl.getStats(completion: completion)
        }
    }
}
