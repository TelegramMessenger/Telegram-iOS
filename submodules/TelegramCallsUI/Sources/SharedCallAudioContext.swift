import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramVoip
import TelegramAudio
import DeviceProximity

public final class SharedCallAudioContext {
    private static weak var current: SharedCallAudioContext? 

    let audioDevice: OngoingCallContext.AudioDevice?
    let callKitIntegration: CallKitIntegration?
    
    /// What the owning call asked for: the loudspeaker unless a headset is connected.
    private let wantsSpeakerByDefault: Bool
    /// The current reading of that request. Guessed from the cached headset flag at construction
    /// and revised once the session reports the real route under the call's category (see
    /// `resolveInitialOutput`), because the cached flag can be stale in either direction and a
    /// paired headset is not the current route until the call's category is set.
    private var defaultToSpeaker: Bool
    
    private var audioSessionDisposable: Disposable?
    private var audioSessionShouldBeActiveDisposable: Disposable?
    private var isAudioSessionActiveDisposable: Disposable?
    private var audioOutputStateDisposable: Disposable?
    
    private(set) var audioSessionControl: ManagedAudioSessionControl?
    
    private let isAudioSessionActivePromise = Promise<Bool>(false)
    private var isAudioSessionActive: Signal<Bool, NoError> {
        return self.isAudioSessionActivePromise.get()
    }
    
    private let audioOutputStatePromise = Promise<([AudioSessionOutput], AudioSessionOutput?)>(([], nil))
    private var audioOutputStateValue: ([AudioSessionOutput], AudioSessionOutput?) = ([], nil)
    public private(set) var currentAudioOutputValue: AudioSessionOutput = .builtin
    private var didSetCurrentAudioOutputValue: Bool = false
    var audioOutputState: Signal<([AudioSessionOutput], AudioSessionOutput?), NoError> {
        return self.audioOutputStatePromise.get()
    }
    
    private let audioSessionShouldBeActive = Promise<Bool>(true)
    private var initialSetupTimer: Foundation.Timer?
    
    /// True between construction and the moment the speaker default has actually been applied.
    /// See `acceptReportedAudioOutput`.
    private var isInitialOutputPending: Bool = false
    
    private var proximityManagerIndex: Int?
    
    /// Set by the owning call once it has terminated for good (see `markCallFinished`). A finished
    /// context is retired the moment the next context is created instead of living on until its
    /// call object is released, which is at least 2 s after termination.
    private var isCallFinished: Bool = false
    private var isRetired: Bool = false

    /// Server killswitch that puts the call audio device back on its pre-2026-09-05 code paths:
    /// one-shot device start without result checks or retries, unconditional forwarding of every
    /// audio-session state value to RTCAudioSession, no retirement of the previous call's device
    /// when the next call starts, RTCAudioSession allowed to deactivate the AVAudioSession, and
    /// unconditional reuse of an existing context by a group call (see `get`).
    /// Presence of the key is what matters, as with the other `ios_killswitch_` keys.
    static let legacyBehaviorKillswitchKey = "ios_killswitch_disable_call_audio_device_fixes"
    
    static func isLegacyBehaviorEnabled(appConfiguration: AppConfiguration) -> Bool {
        return appConfiguration.data?[self.legacyBehaviorKillswitchKey] != nil
    }

    static func get(audioSession: ManagedAudioSession, callKitIntegration: CallKitIntegration?, defaultToSpeaker: Bool = false, reuseCurrent: Bool = false, enableMicrophone: Bool = true, legacyBehavior: Bool = false) -> SharedCallAudioContext {
        // Devices read the switch at creation, so it must be applied before the context is built.
        OngoingCallContext.AudioDevice.setLegacyBehaviorEnabled(legacyBehavior)
        
        // A context created for a CallKit call follows that call's activation cycle through
        // CallKitIntegration.audioSessionActive, and a caller without CallKit integration has no
        // way to re-activate it: once CallKit deactivates the finished call, the reused device
        // stays stopped and the group call is silent. (Invisible on the simulator, where no call
        // has CallKit integration.) So reuse only across callers with the same integration; a
        // CallKit-bound context is retired below like any other finished context, and the new
        // context activates through ManagedAudioSession. The killswitch restores unconditional
        // reuse.
        if let current = self.current, reuseCurrent, legacyBehavior || current.callKitIntegration === callKitIntegration {
            // The reused context was configured for the call that created it (a 1:1 audio call
            // defaults to the receiver), so without this the caller's defaultToSpeaker is dropped
            // and a group call silently inherits the earpiece.
            if defaultToSpeaker && !audioSession.getIsHeadsetPluggedIn() {
                current.switchToSpeakerIfBuiltin()
            }
            // It now belongs to a live call again; the previous owner's termination must not let a
            // later context retire it.
            current.isCallFinished = false
            return current
        }
        let previous = self.current
        let context = SharedCallAudioContext(audioSession: audioSession, callKitIntegration: callKitIntegration, defaultToSpeaker: defaultToSpeaker, enableMicrophone: enableMicrophone)
        self.current = context
        // A finished call's device kept running until its PresentationCallImpl was released and
        // kept following the process-wide CallKit activation signal. A redial inside that window
        // restarted it next to the new device (two Voice-Processing units), and the second start is
        // the one that fails. Retire it after the new holder has been pushed, so ManagedAudioSession
        // never sees an empty holder list in between (that would deactivate the real session).
        if !legacyBehavior, let previous, previous.isCallFinished {
            previous.retire()
        }
        return context
    }
    
    /// The owning call has terminated for good. Lets the next `get` retire this context.
    func markCallFinished() {
        self.isCallFinished = true
    }
    
    private func retire() {
        if self.isRetired {
            return
        }
        self.isRetired = true
        
        self.initialSetupTimer?.invalidate()
        self.initialSetupTimer = nil
        self.audioSessionShouldBeActiveDisposable?.dispose()
        self.audioSessionShouldBeActiveDisposable = nil
        self.isAudioSessionActiveDisposable?.dispose()
        self.isAudioSessionActiveDisposable = nil
        self.audioOutputStateDisposable?.dispose()
        self.audioOutputStateDisposable = nil
        
        self.audioDevice?.stop()
        
        // Release the ManagedAudioSession holder now rather than at deinit, so the replacing
        // context's holder is activated (and its device started) without waiting for this
        // call object to go away.
        self.audioSessionDisposable?.dispose()
        self.audioSessionDisposable = nil
    }
    
    private init(audioSession: ManagedAudioSession, callKitIntegration: CallKitIntegration?, defaultToSpeaker: Bool = false, enableMicrophone: Bool = true) {
        self.callKitIntegration = callKitIntegration
        
        // Align the shared WebRTC audio session configuration with the one ManagedAudioSession
        // installs for .voiceCall. When the two differ, the audio device module calls
        // setCategory:withOptions: as it starts, which resets overrideOutputAudioPort and drops the
        // call back to the receiver (and also loses mixWithOthers / allowBluetoothA2DP for the rest
        // of the call). CallKit calls got this via CallKitIntegration.reportIncomingCall; group
        // calls have no CallKit integration and were left with the stock configuration.
        // Streams pass enableMicrophone: false, which makes the device module skip the category
        // block entirely, so they need no alignment.
        if enableMicrophone {
            OngoingCallContext.setupSharedAudioSessionConfiguration()
        }
        
        self.audioDevice = OngoingCallContext.AudioDevice.create(enableSystemMute: false, enableMicrophone: enableMicrophone)
        
        self.wantsSpeakerByDefault = defaultToSpeaker
        var defaultToSpeaker = defaultToSpeaker
        if audioSession.getIsHeadsetPluggedIn() {
            defaultToSpeaker = false
        }
        
        self.defaultToSpeaker = defaultToSpeaker
        
        if defaultToSpeaker {
            self.didSetCurrentAudioOutputValue = true
            self.currentAudioOutputValue = .speaker
        }
        if callKitIntegration == nil {
            // The decision is deferred to activation whenever the speaker was asked for, whatever
            // the cached flag said: it can claim a headset that has since been disconnected just
            // as well as miss one that is connected.
            self.isInitialOutputPending = self.wantsSpeakerByDefault
        } else {
            self.isInitialOutputPending = defaultToSpeaker
        }
        
        var didReceiveAudioOutputs = false
        self.audioSessionDisposable = audioSession.push(audioSessionType: enableMicrophone ? .voiceCall : .play(mixWithOthers: true), manualActivate: { [weak self] control in
            Queue.mainQueue().async {
                guard let self, !self.isRetired else {
                    return
                }
                let previousControl = self.audioSessionControl
                self.audioSessionControl = control
                
                if previousControl == nil, let audioSessionControl = self.audioSessionControl {
                    if let callKitIntegration = self.callKitIntegration {
                        if self.didSetCurrentAudioOutputValue {
                            callKitIntegration.applyVoiceChatOutputMode(outputMode: .custom(self.currentAudioOutputValue))
                        }
                    } else {
                        if self.isInitialOutputPending {
                            // Forcing the speaker here would tear down a headset route before
                            // anything has looked at it (the log of the 2026-09-18 report shows
                            // exactly that: a 500 ms speaker override on top of connected
                            // AirPods). Let the system route first; activation below reports
                            // what the route is under the call's category, and the speaker is
                            // applied only if no headset is in it.
                            audioSessionControl.setOutputMode(.system)
                        } else {
                            audioSessionControl.setOutputMode(.custom(self.currentAudioOutputValue))
                        }
                        audioSessionControl.setup(synchronous: true)
                    }
                    
                    let audioSessionActive: Signal<Bool, NoError>
                    if let callKitIntegration = self.callKitIntegration {
                        audioSessionActive = callKitIntegration.audioSessionActive
                    } else {
                        audioSessionControl.activate({ [weak self] state in
                            Queue.mainQueue().async {
                                guard let self, !self.isRetired else {
                                    return
                                }
                                self.resolveInitialOutput(isHeadsetConnected: state.isHeadsetConnected)
                            }
                        })
                        audioSessionActive = .single(true)
                    }
                    self.isAudioSessionActivePromise.set(audioSessionActive)
                    
                    // While the decision is deferred, nothing may re-apply the speaker until
                    // activation has reported the route: a Bluetooth activation can outlast the
                    // timer, and the timer would then force the speaker over the headset.
                    // `resolveInitialOutput` arms it once it has chosen the speaker.
                    if !self.isInitialOutputPending || self.callKitIntegration != nil {
                        self.scheduleSpeakerReapply()
                    }
                }
            }
        }, deactivate: { [weak self] _ in
            return Signal { subscriber in
                Queue.mainQueue().async {
                    if let self {
                        self.isAudioSessionActivePromise.set(.single(false))
                        self.audioSessionControl = nil
                        self.isInitialOutputPending = false
                    }
                    subscriber.putCompletion()
                }
                return EmptyDisposable
            }
        }, availableOutputsChanged: { [weak self] availableOutputs, currentOutput in
            Queue.mainQueue().async {
                guard let self else {
                    return
                }
                self.audioOutputStateValue = (availableOutputs, currentOutput)
                if let currentOutput = currentOutput, self.acceptReportedAudioOutput(currentOutput) {
                    self.currentAudioOutputValue = currentOutput
                    self.didSetCurrentAudioOutputValue = true
                    self.updateProximityMonitoring()
                }
                
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
                self.audioOutputStatePromise.set(signal)
            }
        })
        
        self.audioSessionShouldBeActive.set(.single(true))
        self.audioSessionShouldBeActiveDisposable = (self.audioSessionShouldBeActive.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            if value {
                if let audioSessionControl = self.audioSessionControl {
                    let audioSessionActive: Signal<Bool, NoError>
                    if let callKitIntegration = self.callKitIntegration {
                        audioSessionActive = callKitIntegration.audioSessionActive
                    } else {
                        audioSessionControl.activate({ _ in })
                        audioSessionActive = .single(true)
                    }
                    self.isAudioSessionActivePromise.set(audioSessionActive)
                } else {
                    self.isAudioSessionActivePromise.set(.single(false))
                }
            } else {
                self.isAudioSessionActivePromise.set(.single(false))
            }
        })
        
        self.isAudioSessionActiveDisposable = (self.isAudioSessionActive
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            self.audioDevice?.setIsAudioSessionActive(value)
        })
        
        self.audioOutputStateDisposable = (self.audioOutputStatePromise.get()
        |> deliverOnMainQueue).start(next: { [weak self] value in
            guard let self else {
                return
            }
            self.audioOutputStateValue = value
            if let currentOutput = value.1, self.acceptReportedAudioOutput(currentOutput) {
                self.currentAudioOutputValue = currentOutput
                self.updateProximityMonitoring()
            }
        })
    }
    
    deinit {
        self.audioSessionDisposable?.dispose()
        self.audioSessionShouldBeActiveDisposable?.dispose()
        self.isAudioSessionActiveDisposable?.dispose()
        self.audioOutputStateDisposable?.dispose()
        self.initialSetupTimer?.invalidate()
        
        if let proximityManagerIndex = self.proximityManagerIndex {
            DeviceProximityManager.shared().remove(proximityManagerIndex)
        }
    }
    
    /// Re-applies the speaker default half a second later. The audio device module starts after
    /// activation and its own session configuration used to reset `overrideOutputAudioPort`; this
    /// is the only code that puts the speaker back afterwards.
    private func scheduleSpeakerReapply() {
        self.initialSetupTimer?.invalidate()
        let initialSetupTimer = Foundation.Timer(timeInterval: 0.5, repeats: false, block: { [weak self] _ in
            guard let self else {
                return
            }
            
            self.isInitialOutputPending = false
            
            if self.defaultToSpeaker, let audioSessionControl = self.audioSessionControl {
                self.currentAudioOutputValue = .speaker
                self.didSetCurrentAudioOutputValue = true
                
                if let callKitIntegration = self.callKitIntegration {
                    if self.didSetCurrentAudioOutputValue {
                        callKitIntegration.applyVoiceChatOutputMode(outputMode: .custom(self.currentAudioOutputValue))
                    }
                } else {
                    audioSessionControl.setOutputMode(.custom(self.currentAudioOutputValue))
                    audioSessionControl.setup(synchronous: true)
                }
                
                self.updateProximityMonitoring()
            }
        })
        self.initialSetupTimer = initialSetupTimer
        // Timer(timeInterval:repeats:block:) returns an *unscheduled* timer. Without adding it
        // to a run loop it never fires.
        RunLoop.main.add(initialSetupTimer, forMode: .common)
    }
    
    func setCurrentAudioOutput(_ output: AudioSessionOutput) {
        self.initialSetupTimer?.invalidate()
        self.initialSetupTimer = nil
        self.isInitialOutputPending = false
        
        guard self.currentAudioOutputValue != output else {
            return
        }
        self.currentAudioOutputValue = output
        self.didSetCurrentAudioOutputValue = true
        
        self.audioOutputStatePromise.set(.single((self.audioOutputStateValue.0, output))
        |> then(
            .single(self.audioOutputStateValue)
            |> delay(1.0, queue: Queue.mainQueue())
        ))
        
        if let audioSessionControl = self.audioSessionControl {
            if let callKitIntegration = self.callKitIntegration {
                callKitIntegration.applyVoiceChatOutputMode(outputMode: .custom(self.currentAudioOutputValue))
            } else {
                audioSessionControl.setOutputMode(.custom(output))
            }
        }
    }
    
    public func switchToSpeakerIfBuiltin() {
        if case .builtin = self.currentAudioOutputValue {
            self.setCurrentAudioOutput(.speaker)
        }
    }
    
    /// The audio session reports the route as it was *before* the call configured it: the
    /// `availableOutputsChanged` hop that follows activation is queued ahead of the block that
    /// applies our output mode, and under the pre-call category `availableInputs` is nil, so the
    /// snapshot is always `.builtin`. While the speaker default is still pending that report says
    /// nothing about where audio will actually go, and accepting it would discard the default and
    /// switch on proximity monitoring. Any other route (headphones, bluetooth, a real speaker
    /// reading) is a genuine observation and ends the pending window.
    private func acceptReportedAudioOutput(_ output: AudioSessionOutput) -> Bool {
        if self.isInitialOutputPending {
            switch output {
            case .builtin:
                return false
            case .speaker:
                // A real speaker reading (an iPad has no receiver) is worth showing, but the
                // speaker default is still to be applied by `resolveInitialOutput`.
                break
            case .headphones, .port:
                // The session routed the call to a headset the cached flag did not know about.
                // Without this the re-apply timer would still force the speaker over it.
                self.isInitialOutputPending = false
                self.defaultToSpeaker = false
            }
        }
        return true
    }
    
    /// Runs when the audio session has activated under the call's category, which is the first
    /// moment the route can be trusted. Decides the initial output unless a route report or an
    /// explicit selection already has.
    private func resolveInitialOutput(isHeadsetConnected: Bool) {
        guard self.isInitialOutputPending else {
            return
        }
        self.isInitialOutputPending = false
        
        if isHeadsetConnected {
            self.defaultToSpeaker = false
            // The route report that accompanies activation normally names the headset already.
            // If it was skipped as unchanged, the value must still stop claiming a built-in
            // output, for the UI (which reads `audioOutputState`) as much as for this object.
            if !self.currentAudioOutputValue.isHeadset {
                self.currentAudioOutputValue = .headphones
                self.audioOutputStateValue = (self.audioOutputStateValue.0, .headphones)
                self.audioOutputStatePromise.set(.single(self.audioOutputStateValue))
            }
            self.didSetCurrentAudioOutputValue = true
            self.updateProximityMonitoring()
        } else if self.wantsSpeakerByDefault, let audioSessionControl = self.audioSessionControl {
            self.defaultToSpeaker = true
            self.currentAudioOutputValue = .speaker
            self.didSetCurrentAudioOutputValue = true
            audioSessionControl.setOutputMode(.custom(.speaker))
            self.updateProximityMonitoring()
            self.scheduleSpeakerReapply()
        }
    }
    
    private func updateProximityMonitoring() {
        var shouldMonitorProximity = false
        switch self.currentAudioOutputValue {
        case .builtin:
            shouldMonitorProximity = true
        default:
            break
        }
        
        if shouldMonitorProximity {
            if self.proximityManagerIndex == nil {
                self.proximityManagerIndex = DeviceProximityManager.shared().add { _ in
                }
            }
        } else {
            if let proximityManagerIndex = self.proximityManagerIndex {
                self.proximityManagerIndex = nil
                DeviceProximityManager.shared().remove(proximityManagerIndex)
            }
        }
    }
}

private extension AudioSessionOutput {
    /// Headphones or an external port (Bluetooth, wired adapter): a route the speaker default
    /// must never override.
    var isHeadset: Bool {
        switch self {
        case .headphones, .port:
            return true
        case .builtin, .speaker:
            return false
        }
    }
}
