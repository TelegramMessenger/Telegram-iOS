import Foundation
import TelegramCore
import TelegramVoip
import SwiftSignalKit

protocol ScreencastContext: AnyObject {
    func addExternalAudioData(data: Data)
    func stop(account: Account, reportCallId: CallId?)
    func setRTCJoinResponse(clientParams: String)
}

protocol ScreencastIPCContext: AnyObject {
    var isActive: Signal<Bool, NoError> { get }
    
    func requestScreencast() -> Signal<(String, UInt32), NoError>?
    func setJoinResponse(clientParams: String)
    func disableScreencast(account: Account)
}

final class ScreencastInProcessIPCContext: ScreencastIPCContext {
    private let isConference: Bool
    private let e2eContext: ConferenceCallE2EContext?
    
    private let screencastBufferServerContext: IpcGroupCallBufferAppContext
    private var screencastCallContext: ScreencastContext?
    private let screencastCapturer: OngoingCallVideoCapturer
    private var screencastFramesDisposable: Disposable?
    private var screencastAudioDataDisposable: Disposable?
    
    var isActive: Signal<Bool, NoError> {
        return self.screencastBufferServerContext.isActive
    }
    
    init(basePath: String, isConference: Bool, e2eContext: ConferenceCallE2EContext?) {
        self.isConference = isConference
        self.e2eContext = e2eContext
        
        let screencastBufferServerContext = IpcGroupCallBufferAppContext(basePath: basePath + "/broadcast-coordination")
        self.screencastBufferServerContext = screencastBufferServerContext
        let screencastCapturer = OngoingCallVideoCapturer(isCustom: true)
        self.screencastCapturer = screencastCapturer
        self.screencastFramesDisposable = (screencastBufferServerContext.frames
        |> deliverOnMainQueue).start(next: { [weak screencastCapturer] screencastFrame in
            guard let screencastCapturer = screencastCapturer else {
                return
            }
            guard let sampleBuffer = sampleBufferFromPixelBuffer(pixelBuffer: screencastFrame.0) else {
                return
            }
            screencastCapturer.injectSampleBuffer(sampleBuffer, rotation: screencastFrame.1, completion: {})
        })
        self.screencastAudioDataDisposable = (screencastBufferServerContext.audioData
        |> deliverOnMainQueue).start(next: { [weak self] data in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                self.screencastCallContext?.addExternalAudioData(data: data)
            }
        })
    }
    
    deinit {
        self.screencastFramesDisposable?.dispose()
        self.screencastAudioDataDisposable?.dispose()
    }
    
    func requestScreencast() -> Signal<(String, UInt32), NoError>? {
        if self.screencastCallContext == nil {
            var encryptionContext: OngoingGroupCallEncryptionContext?
            if let e2eContext = self.e2eContext {
                encryptionContext = OngoingGroupCallEncryptionContextImpl(e2eCall: e2eContext.state, channelId: 1)
            } else if self.isConference {
                // Prevent non-encrypted conference calls
                encryptionContext = OngoingGroupCallEncryptionContextImpl(e2eCall: Atomic(value: ConferenceCallE2EContext.ContextStateHolder()), channelId: 1)
            }

            let screencastCallContext = InProcessScreencastContext(
                context: OngoingGroupCallContext(
                    audioSessionActive: .single(true),
                    video: self.screencastCapturer,
                    requestMediaChannelDescriptions: { _, _ in EmptyDisposable },
                    rejoinNeeded: { },
                    outgoingAudioBitrateKbit: nil,
                    videoContentType: .screencast,
                    enableNoiseSuppression: false,
                    disableAudioInput: true,
                    enableSystemMute: false,
                    prioritizeVP8: false,
                    logPath: "",
                    onMutedSpeechActivityDetected: { _ in },
                    isConference: self.isConference,
                    audioIsActiveByDefault: true,
                    isStream: false,
                    sharedAudioDevice: nil,
                    encryptionContext: encryptionContext
                )
            )
            self.screencastCallContext = screencastCallContext
            return screencastCallContext.joinPayload
        } else {
            return nil
        }
    }
    
    func setJoinResponse(clientParams: String) {
        if let screencastCallContext = self.screencastCallContext {
            screencastCallContext.setRTCJoinResponse(clientParams: clientParams)
        }
    }
    
    func disableScreencast(account: Account) {
        if let screencastCallContext = self.screencastCallContext {
            self.screencastCallContext = nil
            screencastCallContext.stop(account: account, reportCallId: nil)
            
            self.screencastBufferServerContext.stopScreencast()
        }
    }
}

final class ScreencastEmbeddedIPCContext: ScreencastIPCContext {
    private let serverContext: IpcGroupCallEmbeddedAppContext
    
    var isActive: Signal<Bool, NoError> {
        return self.serverContext.isActive
    }
    
    init(basePath: String) {
        self.serverContext = IpcGroupCallEmbeddedAppContext(basePath: basePath + "/embedded-broadcast-coordination")
    }
    
    func requestScreencast() -> Signal<(String, UInt32), NoError>? {
        if let id = self.serverContext.startScreencast() {
            return self.serverContext.joinPayload
            |> filter { joinPayload -> Bool in
                return joinPayload.id == id
            }
            |> map { joinPayload -> (String, UInt32) in
                return (joinPayload.data, joinPayload.ssrc)
            }
        } else {
            return nil
        }
    }
    
    func setJoinResponse(clientParams: String) {
        self.serverContext.joinResponse = IpcGroupCallEmbeddedAppContext.JoinResponse(data: clientParams)
    }
    
    func disableScreencast(account: Account) {
        self.serverContext.stopScreencast()
    }
}

private final class InProcessScreencastContext: ScreencastContext {
    private let context: OngoingGroupCallContext
    
    var joinPayload: Signal<(String, UInt32), NoError> {
        return self.context.joinPayload
    }
    
    init(context: OngoingGroupCallContext) {
        self.context = context
    }
    
    func addExternalAudioData(data: Data) {
        self.context.addExternalAudioData(data: data)
    }
    
    func stop(account: Account, reportCallId: CallId?) {
        self.context.stop(account: account, reportCallId: reportCallId, debugLog: Promise())
    }
    
    func setRTCJoinResponse(clientParams: String) {
        self.context.setConnectionMode(.rtc, keepBroadcastConnectedIfWasEnabled: false, isUnifiedBroadcast: false)
        self.context.setJoinResponse(payload: clientParams)
    }
}
