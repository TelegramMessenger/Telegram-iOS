import Foundation
import UIKit
import Postbox
import TelegramCore
import SwiftSignalKit
import Display
import AVFoundation
import TelegramVoip
import TelegramAudio
import TelegramUIPreferences
import TelegramPresentationData
import DeviceAccess
import UniversalMediaPlayer
import AccountContext
import DeviceProximity

final class PresentationCallToneRenderer {
    let queue: Queue
    
    let tone: PresentationCallTone
    
    private let toneRenderer: MediaPlayerAudioRenderer
    private var toneRendererAudioSession: MediaPlayerAudioSessionCustomControl?
    private var toneRendererAudioSessionActivated = false
    private let audioLevelPipe = ValuePipe<Float>()
    
    init(tone: PresentationCallTone, completed: (() -> Void)? = nil) {
        let queue = Queue.mainQueue()
        self.queue = queue
        
        self.tone = tone
        
        var controlImpl: ((MediaPlayerAudioSessionCustomControl) -> Disposable)?
        
        self.toneRenderer = MediaPlayerAudioRenderer(audioSession: .custom({ control in
            return controlImpl?(control) ?? EmptyDisposable
        }), playAndRecord: false, useVoiceProcessingMode: true, ambient: false, forceAudioToSpeaker: false, baseRate: 1.0, audioLevelPipe: self.audioLevelPipe, updatedRate: {}, audioPaused: {})
        
        controlImpl = { [weak self] control in
            queue.async {
                if let strongSelf = self {
                    strongSelf.toneRendererAudioSession = control
                    if strongSelf.toneRendererAudioSessionActivated {
                        control.activate()
                    }
                }
            }
            return ActionDisposable {
            }
        }
        
        let toneDataOffset = Atomic<Int>(value: 0)
        
        let toneData = Atomic<Data?>(value: nil)
        let reportedCompletion = Atomic<Bool>(value: false)
        
        self.toneRenderer.beginRequestingFrames(queue: DispatchQueue.global(), takeFrame: {
            var data = toneData.with { $0 }
            if data == nil {
                data = presentationCallToneData(tone)
                if data != nil {
                    let _ = toneData.swap(data)
                }
            }
            
            guard let toneData = data else {
                if !reportedCompletion.swap(true) {
                    completed?()
                }
                return .finished
            }
            
            let toneDataMaxOffset: Int?
            if let loopCount = tone.loopCount {
                toneDataMaxOffset = (data?.count ?? 0) * loopCount
            } else {
                toneDataMaxOffset = nil
            }
            
            let frameSize = 44100
            
            var takeOffset: Int?
            let _ = toneDataOffset.modify { current in
                takeOffset = current
                return current + frameSize
            }
            
            if let takeOffset = takeOffset {
                if let toneDataMaxOffset = toneDataMaxOffset, takeOffset >= toneDataMaxOffset {
                    if !reportedCompletion.swap(true) {
                        Queue.mainQueue().after(1.0, {
                            completed?()
                        })
                    }
                    return .finished
                }
                
                var blockBuffer: CMBlockBuffer?
                
                let bytes = malloc(frameSize)!
                toneData.withUnsafeBytes { dataBuffer -> Void in
                    guard let dataBytes = dataBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return
                    }
                    var takenCount = 0
                    while takenCount < frameSize {
                        let dataOffset = (takeOffset + takenCount) % toneData.count
                        let dataCount = min(frameSize - takenCount, toneData.count - dataOffset)
                        //print("take from \(dataOffset) count: \(dataCount)")
                        memcpy(bytes.advanced(by: takenCount), dataBytes.advanced(by: dataOffset), dataCount)
                        takenCount += dataCount
                        
                        if let toneDataMaxOffset = toneDataMaxOffset, takeOffset + takenCount >= toneDataMaxOffset {
                            break
                        }
                    }
                    
                    if takenCount < frameSize {
                        //print("fill with zeros from \(takenCount) count: \(frameSize - takenCount)")
                        memset(bytes.advanced(by: takenCount), 0, frameSize - takenCount)
                    }
                }
                
                /*if let toneDataMaxOffset = toneDataMaxOffset, takeOffset + frameSize > toneDataMaxOffset {
                    let validCount = max(0, toneDataMaxOffset - takeOffset)
                    memset(bytes.advanced(by: validCount), 0, frameSize - validCount)
                    print("clear from \(validCount) count: \(frameSize - validCount)")
                }*/
                
                let status = CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: bytes, blockLength: frameSize, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: frameSize, flags: 0, blockBufferOut: &blockBuffer)
                if status != noErr {
                    if !reportedCompletion.swap(true) {
                        completed?()
                    }
                    return .finished
                }
                
                let sampleCount = frameSize / 2
                
                let pts = CMTime(value: Int64(takeOffset / 2), timescale: 44100)
                var timingInfo = CMSampleTimingInfo(duration: CMTime(value: Int64(sampleCount), timescale: 44100), presentationTimeStamp: pts, decodeTimeStamp: pts)
                var sampleBuffer: CMSampleBuffer?
                var sampleSize = frameSize
                guard CMSampleBufferCreate(allocator: nil, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: nil, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sampleBuffer) == noErr else {
                    if !reportedCompletion.swap(true) {
                        completed?()
                    }
                    return .finished
                }
                
                if let sampleBuffer = sampleBuffer {
                    return .frame(MediaTrackFrame(type: .audio, sampleBuffer: sampleBuffer, resetDecoder: false, decoded: true))
                } else {
                    if !reportedCompletion.swap(true) {
                        completed?()
                    }
                    return .finished
                }
            } else {
                if !reportedCompletion.swap(true) {
                    completed?()
                }
                return .finished
            }
        })
        self.toneRenderer.start()
        self.toneRenderer.setRate(1.0)
    }
    
    deinit {
        assert(self.queue.isCurrent())
        self.toneRenderer.stop()
    }
    
    func setAudioSessionActive(_ value: Bool) {
        if self.toneRendererAudioSessionActivated != value {
            self.toneRendererAudioSessionActivated = value
            if let control = self.toneRendererAudioSession {
                if value {
                    self.toneRenderer.setRate(1.0)
                    control.activate()
                } else {
                    self.toneRenderer.setRate(0.0)
                    control.deactivate()
                }
            }
        }
    }
}

public final class PresentationCallImpl: PresentationCall {
    public let context: AccountContext
    private let audioSession: ManagedAudioSession
    private let callSessionManager: CallSessionManager
    private let callKitIntegration: CallKitIntegration?
    public var isIntegratedWithCallKit: Bool {
        return self.callKitIntegration != nil
    }
    
    private let getDeviceAccessData: () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void)
    
    public let internalId: CallSessionInternalId
    public let peerId: PeerId
    public let isOutgoing: Bool
    public var isVideo: Bool
    public var isVideoPossible: Bool
    private let enableStunMarking: Bool
    private let enableTCP: Bool
    public let preferredVideoCodec: String?
    public let peer: Peer?
    
    private let serializedData: String?
    private let dataSaving: VoiceCallDataSaving
    private let derivedState: VoipDerivedState
    private let proxyServer: ProxyServerSettings?
    private let auxiliaryServers: [OngoingCallContext.AuxiliaryServer]
    private let currentNetworkType: NetworkType
    private let updatedNetworkType: Signal<NetworkType, NoError>
    
    private var sessionState: CallSession?
    private var callContextState: OngoingCallContextState?
    private var ongoingContext: OngoingCallContext?
    private var ongoingContextStateDisposable: Disposable?
    private var requestedVideoAspect: Float?
    private var reception: Int32?
    private var receptionDisposable: Disposable?
    private var audioLevelDisposable: Disposable?
    private var reportedIncomingCall = false
    
    private var batteryLevelDisposable: Disposable?
    
    private var callWasActive = false
    private var shouldPresentCallRating = false
    
    private var previousVideoState: PresentationCallState.VideoState?
    private var previousRemoteVideoState: PresentationCallState.RemoteVideoState?
    private var previousRemoteAudioState: PresentationCallState.RemoteAudioState?
    private var previousRemoteBatteryLevel: PresentationCallState.RemoteBatteryLevel?
    
    private var sessionStateDisposable: Disposable?
    
    private let statePromise = ValuePromise<PresentationCallState>()
    public var state: Signal<PresentationCallState, NoError> {
        return self.statePromise.get()
    }
    
    private let audioLevelPromise = ValuePromise<Float>(0.0)
    public var audioLevel: Signal<Float, NoError> {
        return self.audioLevelPromise.get()
    }
    
    private let isMutedPromise = ValuePromise<Bool>(false)
    private var isMutedValue = false
    public var isMuted: Signal<Bool, NoError> {
        return self.isMutedPromise.get()
    }
    
    private let audioOutputStatePromise = Promise<([AudioSessionOutput], AudioSessionOutput?)>(([], nil))
    private var audioOutputStateValue: ([AudioSessionOutput], AudioSessionOutput?) = ([], nil)
    private var currentAudioOutputValue: AudioSessionOutput = .builtin
    public var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> {
        return self.audioOutputStatePromise.get()
    }
    
    private let debugInfoValue = Promise<(String, String)>(("", ""))
    
    private let canBeRemovedPromise = Promise<Bool>(false)
    private var didSetCanBeRemoved = false
    public var canBeRemoved: Signal<Bool, NoError> {
        return self.canBeRemovedPromise.get()
    }
    
    private let hungUpPromise = ValuePromise<Bool>()
    
    private var activeTimestamp: Double?
    
    private var audioSessionControl: ManagedAudioSessionControl?
    private var audioSessionDisposable: Disposable?
    private let audioSessionShouldBeActive = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var audioSessionShouldBeActiveDisposable: Disposable?
    private let audioSessionActive = Promise<Bool>(false)
    private var audioSessionActiveDisposable: Disposable?
    private var isAudioSessionActive = false
    
    private var toneRenderer: PresentationCallToneRenderer?
    
    private var droppedCall = false
    private var dropCallKitCallTimer: SwiftSignalKit.Timer?
    
    private var useFrontCamera: Bool = true
    private var videoCapturer: OngoingCallVideoCapturer?

    private var screencastBufferServerContext: IpcGroupCallBufferAppContext?
    private var screencastCapturer: OngoingCallVideoCapturer?
    private var isScreencastActive: Bool = false
    
    private var proximityManagerIndex: Int?

    private let screencastFramesDisposable = MetaDisposable()
    private let screencastAudioDataDisposable = MetaDisposable()
    private let screencastStateDisposable = MetaDisposable()
    
    init(
        context: AccountContext,
        audioSession: ManagedAudioSession,
        callSessionManager: CallSessionManager,
        callKitIntegration: CallKitIntegration?,
        serializedData: String?,
        dataSaving: VoiceCallDataSaving,
        derivedState: VoipDerivedState,
        getDeviceAccessData: @escaping () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void),
        initialState: CallSession?,
        internalId: CallSessionInternalId,
        peerId: PeerId,
        isOutgoing: Bool,
        peer: Peer?,
        proxyServer: ProxyServerSettings?,
        auxiliaryServers: [CallAuxiliaryServer],
        currentNetworkType: NetworkType,
        updatedNetworkType: Signal<NetworkType, NoError>,
        startWithVideo: Bool,
        isVideoPossible: Bool,
        enableStunMarking: Bool,
        enableTCP: Bool,
        preferredVideoCodec: String?
    ) {
        self.context = context
        self.audioSession = audioSession
        self.callSessionManager = callSessionManager
        self.callKitIntegration = callKitIntegration
        self.getDeviceAccessData = getDeviceAccessData
        self.auxiliaryServers = auxiliaryServers.map { server -> OngoingCallContext.AuxiliaryServer in
            let mappedConnection: OngoingCallContext.AuxiliaryServer.Connection
            switch server.connection {
            case .stun:
                mappedConnection = .stun
            case let .turn(username, password):
                mappedConnection = .turn(username: username, password: password)
            }
            return OngoingCallContext.AuxiliaryServer(
                host: server.host,
                port: server.port,
                connection: mappedConnection
            )
        }
        
        self.internalId = internalId
        self.peerId = peerId
        self.isOutgoing = isOutgoing
        self.isVideo = initialState?.type == .video
        self.isVideoPossible = isVideoPossible
        self.enableStunMarking = enableStunMarking
        self.enableTCP = enableTCP
        self.preferredVideoCodec = preferredVideoCodec
        self.peer = peer
        self.isVideo = startWithVideo
        if self.isVideo {
            self.videoCapturer = OngoingCallVideoCapturer()
            self.statePromise.set(PresentationCallState(state: isOutgoing ? .waiting : .ringing, videoState: .active(isScreencast: self.isScreencastActive), remoteVideoState: .inactive, remoteAudioState: .active, remoteBatteryLevel: .normal))
        } else {
            self.statePromise.set(PresentationCallState(state: isOutgoing ? .waiting : .ringing, videoState: self.isVideoPossible ? .inactive : .notAvailable, remoteVideoState: .inactive, remoteAudioState: .active, remoteBatteryLevel: .normal))
        }
        
        self.serializedData = serializedData
        self.dataSaving = dataSaving
        self.derivedState = derivedState
        self.proxyServer = proxyServer
        self.currentNetworkType = currentNetworkType
        self.updatedNetworkType = updatedNetworkType
        
        var didReceiveAudioOutputs = false
        
        var callSessionState: Signal<CallSession, NoError> = .complete()
        if let initialState = initialState {
            callSessionState = .single(initialState)
        }
        callSessionState = callSessionState
        |> then(callSessionManager.callState(internalId: internalId))
        
        self.sessionStateDisposable = (callSessionState
        |> deliverOnMainQueue).start(next: { [weak self] sessionState in
            if let strongSelf = self {
                strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, reception: strongSelf.reception, audioSessionControl: strongSelf.audioSessionControl)
            }
        })
        
        self.audioSessionDisposable = audioSession.push(audioSessionType: .voiceCall, manualActivate: { [weak self] control in
            Queue.mainQueue().async {
                if let strongSelf = self {
                    if let sessionState = strongSelf.sessionState {
                        strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, reception: strongSelf.reception, audioSessionControl: control)
                    } else {
                        strongSelf.audioSessionControl = control
                    }
                }
            }
        }, deactivate: { [weak self] _ in
            return Signal { subscriber in
                Queue.mainQueue().async {
                    if let strongSelf = self {
                        strongSelf.updateIsAudioSessionActive(false)
                        if let sessionState = strongSelf.sessionState {
                            strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, reception: strongSelf.reception, audioSessionControl: nil)
                        } else {
                            strongSelf.audioSessionControl = nil
                        }
                    }
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }, availableOutputsChanged: { [weak self] availableOutputs, currentOutput in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.audioOutputStateValue = (availableOutputs, currentOutput)
                
                var signal: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> = .single((availableOutputs, currentOutput))
                if !didReceiveAudioOutputs {
                    didReceiveAudioOutputs = true
                    if currentOutput == .speaker {
                        signal = .single((availableOutputs, .builtin))
                        |> then(
                            signal
                            |> delay(1.0, queue: Queue.mainQueue())
                        )
                    }
                }
                strongSelf.audioOutputStatePromise.set(signal)
            }
        })
        
        self.audioSessionShouldBeActiveDisposable = (self.audioSessionShouldBeActive.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                if value {
                    if let audioSessionControl = strongSelf.audioSessionControl {
                        let audioSessionActive: Signal<Bool, NoError>
                        if let callKitIntegration = strongSelf.callKitIntegration {
                            audioSessionActive = callKitIntegration.audioSessionActive
                            |> filter { $0 }
                            |> timeout(2.0, queue: Queue.mainQueue(), alternate: Signal { subscriber in
                                if let strongSelf = self, let _ = strongSelf.audioSessionControl {
                                    //audioSessionControl.activate({ _ in })
                                }
                                subscriber.putNext(true)
                                subscriber.putCompletion()
                                return EmptyDisposable
                            })
                        } else {
                            audioSessionControl.activate({ _ in })
                            audioSessionActive = .single(true)
                        }
                        strongSelf.audioSessionActive.set(audioSessionActive)
                    } else {
                        strongSelf.audioSessionActive.set(.single(false))
                    }
                } else {
                    strongSelf.audioSessionActive.set(.single(false))
                }
            }
        })
        
        self.audioSessionActiveDisposable = (self.audioSessionActive.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateIsAudioSessionActive(value)
            }
        })

        let screencastCapturer = OngoingCallVideoCapturer(isCustom: true)
        self.screencastCapturer = screencastCapturer

        self.resetScreencastContext()
        
        if callKitIntegration == nil {
            self.proximityManagerIndex = DeviceProximityManager.shared().add { _ in
            }
        }
    }
    
    deinit {
        self.audioSessionShouldBeActiveDisposable?.dispose()
        self.audioSessionActiveDisposable?.dispose()
        self.sessionStateDisposable?.dispose()
        self.ongoingContextStateDisposable?.dispose()
        self.receptionDisposable?.dispose()
        self.audioLevelDisposable?.dispose()
        self.batteryLevelDisposable?.dispose()
        self.audioSessionDisposable?.dispose()
        self.screencastFramesDisposable.dispose()
        self.screencastAudioDataDisposable.dispose()
        self.screencastStateDisposable.dispose()
        
        if let dropCallKitCallTimer = self.dropCallKitCallTimer {
            dropCallKitCallTimer.invalidate()
            if !self.droppedCall {
                self.callKitIntegration?.dropCall(uuid: self.internalId)
            }
        }
        
        if let proximityManagerIndex = self.proximityManagerIndex {
            DeviceProximityManager.shared().remove(proximityManagerIndex)
        }
    }
    
    private func updateSessionState(sessionState: CallSession, callContextState: OngoingCallContextState?, reception: Int32?, audioSessionControl: ManagedAudioSessionControl?) {
        if case .video = sessionState.type {
            self.isVideo = true
        }
        let previous = self.sessionState
        let previousControl = self.audioSessionControl
        self.sessionState = sessionState
        self.callContextState = callContextState
        self.reception = reception
        self.audioSessionControl = audioSessionControl
        
        if previousControl != nil && audioSessionControl == nil {
            print("updateSessionState \(sessionState.state) \(audioSessionControl != nil)")
        }
        
        let presentationState: PresentationCallState?
        
        var wasActive = false
        var wasTerminated = false
        if let previous = previous {
            switch previous.state {
                case .active:
                    wasActive = true
                case .terminated, .dropping:
                    wasTerminated = true
                default:
                    break
            }
        }
        
        if let audioSessionControl = audioSessionControl, previous == nil || previousControl == nil {
            audioSessionControl.setOutputMode(.custom(self.currentAudioOutputValue))
            audioSessionControl.setup(synchronous: true)
        }
        
        let mappedVideoState: PresentationCallState.VideoState
        let mappedRemoteVideoState: PresentationCallState.RemoteVideoState
        let mappedRemoteAudioState: PresentationCallState.RemoteAudioState
        let mappedRemoteBatteryLevel: PresentationCallState.RemoteBatteryLevel
        if let callContextState = callContextState {
            switch callContextState.videoState {
            case .notAvailable:
                mappedVideoState = .notAvailable
            case .active:
                mappedVideoState = .active(isScreencast: self.isScreencastActive)
            case .inactive:
                mappedVideoState = .inactive
            case .paused:
                mappedVideoState = .paused(isScreencast: self.isScreencastActive)
            }
            switch callContextState.remoteVideoState {
            case .inactive:
                mappedRemoteVideoState = .inactive
            case .active:
                mappedRemoteVideoState = .active
            case .paused:
                mappedRemoteVideoState = .paused
            }
            switch callContextState.remoteAudioState {
            case .active:
                mappedRemoteAudioState = .active
            case .muted:
                mappedRemoteAudioState = .muted
            }
            switch callContextState.remoteBatteryLevel {
            case .normal:
                mappedRemoteBatteryLevel = .normal
            case .low:
                mappedRemoteBatteryLevel = .low
            }
            self.previousVideoState = mappedVideoState
            self.previousRemoteVideoState = mappedRemoteVideoState
            self.previousRemoteAudioState = mappedRemoteAudioState
            self.previousRemoteBatteryLevel = mappedRemoteBatteryLevel
        } else {
            if let previousVideoState = self.previousVideoState {
                mappedVideoState = previousVideoState
            } else {
                if self.isVideo {
                    mappedVideoState = .active(isScreencast: self.isScreencastActive)
                } else if self.isVideoPossible && sessionState.isVideoPossible {
                    mappedVideoState = .inactive
                } else {
                    mappedVideoState = .notAvailable
                }
            }
            mappedRemoteVideoState = .inactive
            if let previousRemoteAudioState = self.previousRemoteAudioState {
                mappedRemoteAudioState = previousRemoteAudioState
            } else {
                mappedRemoteAudioState = .active
            }
            if let previousRemoteBatteryLevel = self.previousRemoteBatteryLevel {
                mappedRemoteBatteryLevel = previousRemoteBatteryLevel
            } else {
                mappedRemoteBatteryLevel = .normal
            }
        }
        
        switch sessionState.state {
            case .ringing:
                presentationState = PresentationCallState(state: .ringing, videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
                if previous == nil || previousControl == nil {
                    if !self.reportedIncomingCall, let stableId = sessionState.stableId {
                        self.reportedIncomingCall = true
                        self.callKitIntegration?.reportIncomingCall(
                            uuid: self.internalId,
                            stableId: stableId,
                            handle: "\(self.peerId.id._internalGetInt64Value())",
                            isVideo: sessionState.type == .video,
                            displayTitle: self.peer?.debugDisplayTitle ?? "Unknown",
                            completion: { [weak self] error in
                                if let error = error {
                                    if error.domain == "com.apple.CallKit.error.incomingcall" && (error.code == -3 || error.code == 3) {
                                        Logger.shared.log("PresentationCall", "reportIncomingCall device in DND mode")
                                        Queue.mainQueue().async {
                                            /*if let strongSelf = self {
                                                strongSelf.callSessionManager.drop(internalId: strongSelf.internalId, reason: .busy, debugLog: .single(nil))
                                            }*/
                                        }
                                    } else {
                                        Logger.shared.log("PresentationCall", "reportIncomingCall error \(error)")
                                        Queue.mainQueue().async {
                                            if let strongSelf = self {
                                                strongSelf.callSessionManager.drop(internalId: strongSelf.internalId, reason: .hangUp, debugLog: .single(nil))
                                            }
                                        }
                                    }
                                }
                            }
                        )
                    }
                }
            case .accepting:
                self.callWasActive = true
                presentationState = PresentationCallState(state: .connecting(nil), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
            case let .dropping(reason):
                presentationState = PresentationCallState(state: .terminating(reason), videoState: mappedVideoState, remoteVideoState: .inactive, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
            case let .terminated(id, reason, options):
                presentationState = PresentationCallState(state: .terminated(id, reason, self.callWasActive && (options.contains(.reportRating) || self.shouldPresentCallRating)), videoState: mappedVideoState, remoteVideoState: .inactive, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
            case let .requesting(ringing):
                presentationState = PresentationCallState(state: .requesting(ringing), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
            case let .active(_, _, keyVisualHash, _, _, _, _):
                self.callWasActive = true
                if let callContextState = callContextState {
                    switch callContextState.state {
                        case .initializing:
                            presentationState = PresentationCallState(state: .connecting(keyVisualHash), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
                        case .failed:
                            presentationState = PresentationCallState(state: .terminating(.error(.disconnected)), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
                            self.callSessionManager.drop(internalId: self.internalId, reason: .disconnect, debugLog: .single(nil))
                        case .connected:
                            let timestamp: Double
                            if let activeTimestamp = self.activeTimestamp {
                                timestamp = activeTimestamp
                            } else {
                                timestamp = CFAbsoluteTimeGetCurrent()
                                self.activeTimestamp = timestamp
                            }
                            presentationState = PresentationCallState(state: .active(timestamp, reception, keyVisualHash), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
                        case .reconnecting:
                            let timestamp: Double
                            if let activeTimestamp = self.activeTimestamp {
                                timestamp = activeTimestamp
                            } else {
                                timestamp = CFAbsoluteTimeGetCurrent()
                                self.activeTimestamp = timestamp
                            }
                            presentationState = PresentationCallState(state: .reconnecting(timestamp, reception, keyVisualHash), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
                    }
                } else {
                    presentationState = PresentationCallState(state: .connecting(keyVisualHash), videoState: mappedVideoState, remoteVideoState: mappedRemoteVideoState, remoteAudioState: mappedRemoteAudioState, remoteBatteryLevel: mappedRemoteBatteryLevel)
                }
        }
        
        switch sessionState.state {
            case .requesting:
                if let _ = audioSessionControl {
                    self.audioSessionShouldBeActive.set(true)
                }
            case let .active(id, key, _, connections, maxLayer, version, allowsP2P):
                self.audioSessionShouldBeActive.set(true)
                if let _ = audioSessionControl, !wasActive || previousControl == nil {
                    let logName = "\(id.id)_\(id.accessHash)"

                    let updatedConnections = connections
                    
                    let ongoingContext = OngoingCallContext(account: self.context.account, callSessionManager: self.callSessionManager, internalId: self.internalId, proxyServer: proxyServer, initialNetworkType: self.currentNetworkType, updatedNetworkType: self.updatedNetworkType, serializedData: self.serializedData, dataSaving: dataSaving, derivedState: self.derivedState, key: key, isOutgoing: sessionState.isOutgoing, video: self.videoCapturer, connections: updatedConnections, maxLayer: maxLayer, version: version, allowP2P: allowsP2P, enableTCP: self.enableTCP, enableStunMarking: self.enableStunMarking, audioSessionActive: self.audioSessionActive.get(), logName: logName, preferredVideoCodec: self.preferredVideoCodec)
                    self.ongoingContext = ongoingContext
                    ongoingContext.setIsMuted(self.isMutedValue)
                    if let requestedVideoAspect = self.requestedVideoAspect {
                        ongoingContext.setRequestedVideoAspect(requestedVideoAspect)
                    }
                    
                    self.debugInfoValue.set(ongoingContext.debugInfo())
                    
                    self.ongoingContextStateDisposable = (ongoingContext.state
                    |> deliverOnMainQueue).start(next: { [weak self] contextState in
                        if let strongSelf = self {
                            if let sessionState = strongSelf.sessionState {
                                strongSelf.updateSessionState(sessionState: sessionState, callContextState: contextState, reception: strongSelf.reception, audioSessionControl: strongSelf.audioSessionControl)
                            } else {
                                strongSelf.callContextState = contextState
                            }
                        }
                    })
                    
                    self.receptionDisposable = (ongoingContext.reception
                    |> deliverOnMainQueue).start(next: { [weak self] reception in
                        if let strongSelf = self {
                            if let sessionState = strongSelf.sessionState {
                                strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, reception: reception, audioSessionControl: strongSelf.audioSessionControl)
                            } else {
                                strongSelf.reception = reception
                            }
                        }
                    })
                    
                    self.audioLevelDisposable = (ongoingContext.audioLevel
                    |> deliverOnMainQueue).start(next: { [weak self] level in
                        if let strongSelf = self {
                            strongSelf.audioLevelPromise.set(level)
                        }
                    })
                    
                    func batteryLevelIsLowSignal() -> Signal<Bool, NoError> {
                        return Signal { subscriber in
                            let device = UIDevice.current
                            device.isBatteryMonitoringEnabled = true
                            
                            var previousBatteryLevelIsLow = false
                            let timer = SwiftSignalKit.Timer(timeout: 30.0, repeat: true, completion: {
                                let batteryLevelIsLow = device.batteryLevel >= 0.0 && device.batteryLevel < 0.1 && device.batteryState != .charging
                                if batteryLevelIsLow != previousBatteryLevelIsLow {
                                    previousBatteryLevelIsLow = batteryLevelIsLow
                                    subscriber.putNext(batteryLevelIsLow)
                                }
                            }, queue: Queue.mainQueue())
                            timer.start()
                            
                            return ActionDisposable {
                                device.isBatteryMonitoringEnabled = false
                                timer.invalidate()
                            }
                        }
                    }
                    
                    self.batteryLevelDisposable = (batteryLevelIsLowSignal()
                    |> deliverOnMainQueue).start(next: { [weak self] batteryLevelIsLow in
                        if let strongSelf = self, let ongoingContext = strongSelf.ongoingContext {
                            ongoingContext.setIsLowBatteryLevel(batteryLevelIsLow)
                        }
                    })
                    
                    if sessionState.isOutgoing {
                        self.callKitIntegration?.reportOutgoingCallConnected(uuid: sessionState.id, at: Date())
                    }
                }
            case let .terminated(id, _, options):
                self.audioSessionShouldBeActive.set(true)
                if wasActive {
                    let debugLogValue = Promise<String?>()
                    self.ongoingContext?.stop(callId: id, sendDebugLogs: options.contains(.sendDebugLogs), debugLogValue: debugLogValue)
                }
            default:
                self.audioSessionShouldBeActive.set(false)
                if wasActive {
                    let debugLogValue = Promise<String?>()
                    self.ongoingContext?.stop(debugLogValue: debugLogValue)
                }
        }
        var terminating = false
        if case .terminated = sessionState.state {
            terminating = true
        } else if case .dropping = sessionState.state {
            terminating = true
        }
        
        if terminating, !wasTerminated {
            if !self.didSetCanBeRemoved {
                self.didSetCanBeRemoved = true
                self.canBeRemovedPromise.set(.single(true) |> delay(2.0, queue: Queue.mainQueue()))
            }
            self.hungUpPromise.set(true)
            if sessionState.isOutgoing {
                if !self.droppedCall && self.dropCallKitCallTimer == nil {
                    let dropCallKitCallTimer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.dropCallKitCallTimer = nil
                            if !strongSelf.droppedCall {
                                strongSelf.droppedCall = true
                                strongSelf.callKitIntegration?.dropCall(uuid: strongSelf.internalId)
                            }
                        }
                    }, queue: Queue.mainQueue())
                    self.dropCallKitCallTimer = dropCallKitCallTimer
                    dropCallKitCallTimer.start()
                }
            } else {
                self.callKitIntegration?.dropCall(uuid: self.internalId)
            }
        }
        if let presentationState = presentationState {
            self.statePromise.set(presentationState)
            self.updateTone(presentationState, callContextState: callContextState, previous: previous)
        }
    }
    
    private func updateTone(_ state: PresentationCallState, callContextState: OngoingCallContextState?, previous: CallSession?) {
        var tone: PresentationCallTone?
        if let callContextState = callContextState, case .reconnecting = callContextState.state {
            if !self.isVideo {
                tone = .connecting
            }
        } else if let previous = previous {
            switch previous.state {
                case .accepting, .active, .dropping, .requesting:
                    switch state.state {
                        case .connecting:
                            if case .requesting = previous.state {
                                tone = .ringing
                            } else {
                                if !self.isVideo {
                                    tone = .connecting
                                }
                            }
                        case .requesting(true):
                            tone = .ringing
                        case let .terminated(_, reason, _):
                            if let reason = reason {
                                switch reason {
                                    case let .ended(type):
                                        switch type {
                                            case .busy:
                                                tone = .busy
                                            case .hungUp, .missed:
                                                tone = .ended
                                        }
                                    case .error:
                                        tone = .failed
                                }
                            }
                        default:
                            break
                    }
                default:
                    break
            }
        }
        if tone != self.toneRenderer?.tone {
            if let tone = tone {
                let toneRenderer = PresentationCallToneRenderer(tone: tone)
                self.toneRenderer = toneRenderer
                toneRenderer.setAudioSessionActive(self.isAudioSessionActive)
            } else {
                self.toneRenderer = nil
            }
        }
    }
    
    private func updateIsAudioSessionActive(_ value: Bool) {
        if self.isAudioSessionActive != value {
            self.isAudioSessionActive = value
            self.toneRenderer?.setAudioSessionActive(value)
        }
    }
    
    public func answer() {
        let (presentationData, present, openSettings) = self.getDeviceAccessData()
        
        DeviceAccess.authorizeAccess(to: .microphone(.voiceCall), presentationData: presentationData, present: { c, a in
            present(c, a)
        }, openSettings: {
            openSettings()
        }, { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if value {
                if strongSelf.isVideo {
                    DeviceAccess.authorizeAccess(to: .camera(.videoCall), presentationData: presentationData, present: { c, a in
                        present(c, a)
                    }, openSettings: {
                        openSettings()
                    }, { [weak self] value in
                        guard let strongSelf = self else {
                            return
                        }
                        if value {
                            strongSelf.callSessionManager.accept(internalId: strongSelf.internalId)
                            strongSelf.callKitIntegration?.answerCall(uuid: strongSelf.internalId)
                        } else {
                            let _ = strongSelf.hangUp().start()
                        }
                    })
                } else {
                    strongSelf.callSessionManager.accept(internalId: strongSelf.internalId)
                    strongSelf.callKitIntegration?.answerCall(uuid: strongSelf.internalId)
                }
            } else {
                let _ = strongSelf.hangUp().start()
            }
        })
    }
    
    public func hangUp() -> Signal<Bool, NoError> {
        let debugLogValue = Promise<String?>()
        self.callSessionManager.drop(internalId: self.internalId, reason: .hangUp, debugLog: debugLogValue.get())
        self.ongoingContext?.stop(debugLogValue: debugLogValue)
        
        return self.hungUpPromise.get()
    }
    
    public func rejectBusy() {
        self.callSessionManager.drop(internalId: self.internalId, reason: .busy, debugLog: .single(nil))
        let debugLog = Promise<String?>()
        self.ongoingContext?.stop(debugLogValue: debugLog)
    }
    
    public func toggleIsMuted() {
        self.setIsMuted(!self.isMutedValue)
    }
    
    public func setIsMuted(_ value: Bool) {
        self.isMutedValue = value
        self.isMutedPromise.set(self.isMutedValue)
        self.ongoingContext?.setIsMuted(self.isMutedValue)
    }
    
    public func requestVideo() {
        if self.videoCapturer == nil {
            let videoCapturer = OngoingCallVideoCapturer()
            self.videoCapturer = videoCapturer
        }
        if let videoCapturer = self.videoCapturer {
            self.ongoingContext?.requestVideo(videoCapturer)
        }
    }
    
    public func setRequestedVideoAspect(_ aspect: Float) {
        self.requestedVideoAspect = aspect
        self.ongoingContext?.setRequestedVideoAspect(aspect)
    }
    
    public func disableVideo() {
        if let _ = self.videoCapturer {
            self.videoCapturer = nil
            self.ongoingContext?.disableVideo()
        }
    }

    private func resetScreencastContext() {
        let basePath = self.context.sharedContext.basePath + "/broadcast-coordination"
        let screencastBufferServerContext = IpcGroupCallBufferAppContext(basePath: basePath)
        self.screencastBufferServerContext = screencastBufferServerContext

        self.screencastFramesDisposable.set((screencastBufferServerContext.frames
        |> deliverOnMainQueue).start(next: { [weak screencastCapturer] screencastFrame in
            guard let screencastCapturer = screencastCapturer else {
                return
            }
            screencastCapturer.injectPixelBuffer(screencastFrame.0, rotation: screencastFrame.1)
        }))
        self.screencastAudioDataDisposable.set((screencastBufferServerContext.audioData
        |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let strongSelf = self else {
                return
            }
            strongSelf.ongoingContext?.addExternalAudioData(data: data)
        }))
        self.screencastStateDisposable.set((screencastBufferServerContext.isActive
        |> distinctUntilChanged
        |> deliverOnMainQueue).start(next: { [weak self] isActive in
            guard let strongSelf = self else {
                return
            }
            if isActive {
                strongSelf.requestScreencast()
            } else {
                strongSelf.disableScreencast(reset: false)
            }
        }))
    }

    private func requestScreencast() {
        self.disableVideo()

        if let screencastCapturer = self.screencastCapturer {
            self.isScreencastActive = true
            self.ongoingContext?.requestVideo(screencastCapturer)
        }
    }

    func disableScreencast(reset: Bool = true) {
        if self.isScreencastActive {
            if let _ = self.videoCapturer {
                self.videoCapturer = nil
            }
            self.isScreencastActive = false
            self.ongoingContext?.disableVideo()
            if reset {
                self.resetScreencastContext()
            }
        }
    }
    
    public func setOutgoingVideoIsPaused(_ isPaused: Bool) {
        self.videoCapturer?.setIsVideoEnabled(!isPaused)
    }
    
    public func setCurrentAudioOutput(_ output: AudioSessionOutput) {
        guard self.currentAudioOutputValue != output else {
            return
        }
        self.currentAudioOutputValue = output
        
        self.audioOutputStatePromise.set(.single((self.audioOutputStateValue.0, output))
        |> then(
            .single(self.audioOutputStateValue)
            |> delay(1.0, queue: Queue.mainQueue())
        ))
        
        if let audioSessionControl = self.audioSessionControl {
            audioSessionControl.setOutputMode(.custom(output))
        }
    }
    
    public func debugInfo() -> Signal<(String, String), NoError> {
        return self.debugInfoValue.get()
    }
    
    public func makeIncomingVideoView(completion: @escaping (PresentationCallVideoView?) -> Void) {
        self.ongoingContext?.makeIncomingVideoView(completion: { view in
            if let view = view {
                let setOnFirstFrameReceived = view.setOnFirstFrameReceived
                let setOnOrientationUpdated = view.setOnOrientationUpdated
                let setOnIsMirroredUpdated = view.setOnIsMirroredUpdated
                let updateIsEnabled = view.updateIsEnabled
                completion(PresentationCallVideoView(
                    holder: view,
                    view: view.view,
                    setOnFirstFrameReceived: { f in
                        setOnFirstFrameReceived(f)
                    },
                    getOrientation: { [weak view] in
                        if let view = view {
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch view.getOrientation() {
                            case .rotation0:
                                mappedValue = .rotation0
                            case .rotation90:
                                mappedValue = .rotation90
                            case .rotation180:
                                mappedValue = .rotation180
                            case .rotation270:
                                mappedValue = .rotation270
                            }
                            return mappedValue
                        } else {
                            return .rotation0
                        }
                    },
                    getAspect: { [weak view] in
                        if let view = view {
                            return view.getAspect()
                        } else {
                            return 0.0
                        }
                    },
                    setOnOrientationUpdated: { f in
                        setOnOrientationUpdated { value, aspect in
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch value {
                            case .rotation0:
                                mappedValue = .rotation0
                            case .rotation90:
                                mappedValue = .rotation90
                            case .rotation180:
                                mappedValue = .rotation180
                            case .rotation270:
                                mappedValue = .rotation270
                            }
                            f?(mappedValue, aspect)
                        }
                    },
                    setOnIsMirroredUpdated: { f in
                        setOnIsMirroredUpdated { value in
                            f?(value)
                        }
                    },
                    updateIsEnabled: { value in
                        updateIsEnabled(value)
                    }
                ))
            } else {
                completion(nil)
            }
        })
    }
    
    public func makeOutgoingVideoView(completion: @escaping (PresentationCallVideoView?) -> Void) {
        if self.videoCapturer == nil {
            let videoCapturer = OngoingCallVideoCapturer()
            self.videoCapturer = videoCapturer
        }
        
        self.videoCapturer?.makeOutgoingVideoView(requestClone: false, completion: { view, _ in
            if let view = view {
                let setOnFirstFrameReceived = view.setOnFirstFrameReceived
                let setOnOrientationUpdated = view.setOnOrientationUpdated
                let setOnIsMirroredUpdated = view.setOnIsMirroredUpdated
                let updateIsEnabled = view.updateIsEnabled
                completion(PresentationCallVideoView(
                    holder: view,
                    view: view.view,
                    setOnFirstFrameReceived: { f in
                        setOnFirstFrameReceived(f)
                    },
                    getOrientation: { [weak view] in
                        if let view = view {
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch view.getOrientation() {
                            case .rotation0:
                                mappedValue = .rotation0
                            case .rotation90:
                                mappedValue = .rotation90
                            case .rotation180:
                                mappedValue = .rotation180
                            case .rotation270:
                                mappedValue = .rotation270
                            }
                            return mappedValue
                        } else {
                            return .rotation0
                        }
                    },
                    getAspect: { [weak view] in
                        if let view = view {
                            return view.getAspect()
                        } else {
                            return 0.0
                        }
                    },
                    setOnOrientationUpdated: { f in
                        setOnOrientationUpdated { value, aspect in
                            let mappedValue: PresentationCallVideoView.Orientation
                            switch value {
                            case .rotation0:
                                mappedValue = .rotation0
                            case .rotation90:
                                mappedValue = .rotation90
                            case .rotation180:
                                mappedValue = .rotation180
                            case .rotation270:
                                mappedValue = .rotation270
                            }
                            f?(mappedValue, aspect)
                        }
                    },
                    setOnIsMirroredUpdated: { f in
                        setOnIsMirroredUpdated { value in
                            f?(value)
                        }
                    },
                    updateIsEnabled: { value in
                        updateIsEnabled(value)
                    }
                ))
            } else {
                completion(nil)
            }
        })
    }
    
    public func switchVideoCamera() {
        self.useFrontCamera = !self.useFrontCamera
        self.videoCapturer?.switchVideoInput(isFront: self.useFrontCamera)
    }
}
