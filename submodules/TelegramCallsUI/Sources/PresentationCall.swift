import Foundation
import Postbox
import TelegramCore
import SyncCore
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

private final class PresentationCallToneRenderer {
    let queue: Queue
    
    let tone: PresentationCallTone
    
    private let toneRenderer: MediaPlayerAudioRenderer
    private var toneRendererAudioSession: MediaPlayerAudioSessionCustomControl?
    private var toneRendererAudioSessionActivated = false
    
    init(tone: PresentationCallTone) {
        let queue = Queue.mainQueue()
        self.queue = queue
        
        self.tone = tone
        
        var controlImpl: ((MediaPlayerAudioSessionCustomControl) -> Disposable)?
        
        self.toneRenderer = MediaPlayerAudioRenderer(audioSession: .custom({ control in
            return controlImpl?(control) ?? EmptyDisposable
        }), playAndRecord: false, forceAudioToSpeaker: false, baseRate: 1.0, updatedRate: {}, audioPaused: {})
        
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
        
        self.toneRenderer.beginRequestingFrames(queue: DispatchQueue.global(), takeFrame: {
            var data = toneData.with { $0 }
            if data == nil {
                data = presentationCallToneData(tone)
                if data != nil {
                    let _ = toneData.swap(data)
                }
            }
            
            guard let toneData = data else {
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
                    return .finished
                }
                
                var blockBuffer: CMBlockBuffer?
                
                let bytes = malloc(frameSize)!
                toneData.withUnsafeBytes { (dataBytes: UnsafePointer<UInt8>) -> Void in
                    var takenCount = 0
                    while takenCount < frameSize {
                        let dataOffset = (takeOffset + takenCount) % toneData.count
                        let dataCount = min(frameSize, toneData.count - dataOffset)
                        memcpy(bytes, dataBytes.advanced(by: dataOffset), dataCount)
                        takenCount += dataCount
                    }
                }
                
                if let toneDataMaxOffset = toneDataMaxOffset, takeOffset + frameSize > toneDataMaxOffset {
                    let validCount = max(0, toneDataMaxOffset - takeOffset)
                    memset(bytes.advanced(by: validCount), 0, frameSize - validCount)
                }
                
                let status = CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: bytes, blockLength: frameSize, blockAllocator: nil, customBlockSource: nil, offsetToData: 0, dataLength: frameSize, flags: 0, blockBufferOut: &blockBuffer)
                if status != noErr {
                    return .finished
                }
                
                let sampleCount = frameSize / 2
                
                let pts = CMTime(value: Int64(takeOffset / 2), timescale: 44100)
                var timingInfo = CMSampleTimingInfo(duration: CMTime(value: Int64(sampleCount), timescale: 44100), presentationTimeStamp: pts, decodeTimeStamp: pts)
                var sampleBuffer: CMSampleBuffer?
                var sampleSize = frameSize
                guard CMSampleBufferCreate(allocator: nil, dataBuffer: blockBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: nil, sampleCount: 1, sampleTimingEntryCount: 1, sampleTimingArray: &timingInfo, sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize, sampleBufferOut: &sampleBuffer) == noErr else {
                    return .finished
                }
                
                if let sampleBuffer = sampleBuffer {
                    return .frame(MediaTrackFrame(type: .audio, sampleBuffer: sampleBuffer, resetDecoder: false, decoded: true))
                } else {
                    return .finished
                }
            } else {
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
    public let account: Account
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
    public let peer: Peer?
    
    private var sessionState: CallSession?
    private var callContextState: OngoingCallContextState?
    private var ongoingContext: OngoingCallContext
    private var ongoingContextStateDisposable: Disposable?
    private var reception: Int32?
    private var receptionDisposable: Disposable?
    private var reportedIncomingCall = false
    
    private var callWasActive = false
    private var shouldPresentCallRating = false
    
    private var sessionStateDisposable: Disposable?
    
    private let statePromise = ValuePromise<PresentationCallState>(.waiting, ignoreRepeated: true)
    public var state: Signal<PresentationCallState, NoError> {
        return self.statePromise.get()
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
    
    init(account: Account, audioSession: ManagedAudioSession, callSessionManager: CallSessionManager, callKitIntegration: CallKitIntegration?, serializedData: String?, dataSaving: VoiceCallDataSaving, derivedState: VoipDerivedState, getDeviceAccessData: @escaping () -> (presentationData: PresentationData, present: (ViewController, Any?) -> Void, openSettings: () -> Void), initialState: CallSession?, internalId: CallSessionInternalId, peerId: PeerId, isOutgoing: Bool, peer: Peer?, proxyServer: ProxyServerSettings?, currentNetworkType: NetworkType, updatedNetworkType: Signal<NetworkType, NoError>) {
        self.account = account
        self.audioSession = audioSession
        self.callSessionManager = callSessionManager
        self.callKitIntegration = callKitIntegration
        self.getDeviceAccessData = getDeviceAccessData
        
        self.internalId = internalId
        self.peerId = peerId
        self.isOutgoing = isOutgoing
        self.peer = peer
        
        self.ongoingContext = OngoingCallContext(account: account, callSessionManager: self.callSessionManager, internalId: self.internalId, proxyServer: proxyServer, initialNetworkType: currentNetworkType, updatedNetworkType: updatedNetworkType, serializedData: serializedData, dataSaving: dataSaving, derivedState: derivedState)
        
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
        
        self.ongoingContextStateDisposable = (self.ongoingContext.state
        |> deliverOnMainQueue).start(next: { [weak self] contextState in
            if let strongSelf = self {
                if let sessionState = strongSelf.sessionState {
                    strongSelf.updateSessionState(sessionState: sessionState, callContextState: contextState, reception: strongSelf.reception, audioSessionControl: strongSelf.audioSessionControl)
                } else {
                    strongSelf.callContextState = contextState
                }
            }
        })
        
        self.receptionDisposable = (self.ongoingContext.reception
        |> deliverOnMainQueue).start(next: { [weak self] reception in
            if let strongSelf = self {
                if let sessionState = strongSelf.sessionState {
                    strongSelf.updateSessionState(sessionState: sessionState, callContextState: strongSelf.callContextState, reception: reception, audioSessionControl: strongSelf.audioSessionControl)
                } else {
                    strongSelf.reception = reception
                }
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
        }, deactivate: { [weak self] in
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
                                if let strongSelf = self, let audioSessionControl = strongSelf.audioSessionControl {
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
    }
    
    deinit {
        self.audioSessionShouldBeActiveDisposable?.dispose()
        self.audioSessionActiveDisposable?.dispose()
        self.sessionStateDisposable?.dispose()
        self.ongoingContextStateDisposable?.dispose()
        self.receptionDisposable?.dispose()
        self.audioSessionDisposable?.dispose()
        
        if let dropCallKitCallTimer = self.dropCallKitCallTimer {
            dropCallKitCallTimer.invalidate()
            if !self.droppedCall {
                self.callKitIntegration?.dropCall(uuid: self.internalId)
            }
        }
    }
    
    private func updateSessionState(sessionState: CallSession, callContextState: OngoingCallContextState?, reception: Int32?, audioSessionControl: ManagedAudioSessionControl?) {
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
                case .terminated:
                    wasTerminated = true
                default:
                    break
            }
        }
        
        if let audioSessionControl = audioSessionControl, previous == nil || previousControl == nil {
            audioSessionControl.setOutputMode(.custom(self.currentAudioOutputValue))
            audioSessionControl.setup(synchronous: true)
        }
        
        switch sessionState.state {
            case .ringing:
                presentationState = .ringing
                if previous == nil || previousControl == nil {
                    if !self.reportedIncomingCall {
                        self.reportedIncomingCall = true
                        self.callKitIntegration?.reportIncomingCall(uuid: self.internalId, handle: "\(self.peerId.id)", displayTitle: self.peer?.debugDisplayTitle ?? "Unknown", completion: { [weak self] error in
                            if let error = error {
                                if error.domain == "com.apple.CallKit.error.incomingcall" && (error.code == -3 || error.code == 3) {
                                    Logger.shared.log("PresentationCall", "reportIncomingCall device in DND mode")
                                    Queue.mainQueue().async {
                                        if let strongSelf = self {
                                            strongSelf.callSessionManager.drop(internalId: strongSelf.internalId, reason: .busy, debugLog: .single(nil))
                                        }
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
                        })
                    }
                }
            case .accepting:
                self.callWasActive = true
                presentationState = .connecting(nil)
            case .dropping:
                presentationState = .terminating
            case let .terminated(id, reason, options):
                presentationState = .terminated(id, reason, self.callWasActive && (options.contains(.reportRating) || self.shouldPresentCallRating))
            case let .requesting(ringing):
                presentationState = .requesting(ringing)
            case let .active(_, _, keyVisualHash, _, _, _):
                self.callWasActive = true
                if let callContextState = callContextState {
                    switch callContextState {
                        case .initializing:
                            presentationState = .connecting(keyVisualHash)
                        case .failed:
                            presentationState = nil
                            self.callSessionManager.drop(internalId: self.internalId, reason: .disconnect, debugLog: .single(nil))
                        case .connected:
                            let timestamp: Double
                            if let activeTimestamp = self.activeTimestamp {
                                timestamp = activeTimestamp
                            } else {
                                timestamp = CFAbsoluteTimeGetCurrent()
                                self.activeTimestamp = timestamp
                            }
                            presentationState = .active(timestamp, reception, keyVisualHash)
                    }
                } else {
                    presentationState = .connecting(keyVisualHash)
                }
        }
        
        switch sessionState.state {
            case .requesting:
                if let _ = audioSessionControl {
                    self.audioSessionShouldBeActive.set(true)
                }
            case let .active(id, key, _, connections, maxLayer, allowsP2P):
                self.audioSessionShouldBeActive.set(true)
                if let _ = audioSessionControl, !wasActive || previousControl == nil {
                    let logName = "\(id.id)_\(id.accessHash)"
                    self.ongoingContext.start(key: key, isOutgoing: sessionState.isOutgoing, connections: connections, maxLayer: maxLayer, allowP2P: allowsP2P, audioSessionActive: self.audioSessionActive.get(), logName: logName)
                    if sessionState.isOutgoing {
                        self.callKitIntegration?.reportOutgoingCallConnected(uuid: sessionState.id, at: Date())
                    }
                }
            case let .terminated(id, _, options):
                self.audioSessionShouldBeActive.set(true)
                if wasActive {
                    let debugLogValue = Promise<String?>()
                    self.ongoingContext.stop(callId: id, sendDebugLogs: options.contains(.sendDebugLogs), debugLogValue: debugLogValue)
                }
            default:
                self.audioSessionShouldBeActive.set(false)
                if wasActive {
                    let debugLogValue = Promise<String?>()
                    self.ongoingContext.stop(debugLogValue: debugLogValue)
                }
        }
        if case .terminated = sessionState.state, !wasTerminated {
            if !self.didSetCanBeRemoved {
                self.didSetCanBeRemoved = true
                self.canBeRemovedPromise.set(.single(true) |> delay(2.4, queue: Queue.mainQueue()))
            }
            self.hungUpPromise.set(true)
            if sessionState.isOutgoing {
                if !self.droppedCall && self.dropCallKitCallTimer == nil {
                    let dropCallKitCallTimer = SwiftSignalKit.Timer(timeout: 2.4, repeat: false, completion: { [weak self] in
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
            self.updateTone(presentationState, previous: previous)
        }
        
        if !self.shouldPresentCallRating {
            self.ongoingContext.needsRating { needsRating in
                self.shouldPresentCallRating = needsRating
            }
        }
    }
    
    private func updateTone(_ state: PresentationCallState, previous: CallSession?) {
        var tone: PresentationCallTone?
        if let previous = previous {
            switch previous.state {
                case .accepting, .active, .dropping, .requesting:
                    switch state {
                        case .connecting:
                            if case .requesting = previous.state {
                                tone = .ringing
                            } else {
                                tone = .connecting
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
                strongSelf.callSessionManager.accept(internalId: strongSelf.internalId)
                strongSelf.callKitIntegration?.answerCall(uuid: strongSelf.internalId)
            } else {
                let _ = strongSelf.hangUp().start()
            }
        })
    }
    
    public func hangUp() -> Signal<Bool, NoError> {
        let debugLogValue = Promise<String?>()
        self.callSessionManager.drop(internalId: self.internalId, reason: .hangUp, debugLog: debugLogValue.get())
        self.ongoingContext.stop(debugLogValue: debugLogValue)
        
        return self.hungUpPromise.get()
    }
    
    public func rejectBusy() {
        self.callSessionManager.drop(internalId: self.internalId, reason: .busy, debugLog: .single(nil))
        let debugLog = Promise<String?>()
        self.ongoingContext.stop(debugLogValue: debugLog)
    }
    
    public func toggleIsMuted() {
        self.setIsMuted(!self.isMutedValue)
    }
    
    public func setIsMuted(_ value: Bool) {
        self.isMutedValue = value
        self.isMutedPromise.set(self.isMutedValue)
        self.ongoingContext.setIsMuted(self.isMutedValue)
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
        return self.ongoingContext.debugInfo()
    }
}
