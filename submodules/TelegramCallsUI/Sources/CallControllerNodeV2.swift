import Foundation
import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import Postbox
import TelegramAudio
import AccountContext
import TelegramPresentationData
import SwiftSignalKit
import CallScreen
import ComponentDisplayAdapters
import ComponentFlow
import CallsEmoji
import AvatarNode
import TinyThumbnail
import ImageBlur
import TelegramVoip
import MetalEngine
import DeviceAccess
import LibYuvBinding

final class CallControllerNodeV2: ViewControllerTracingNode, CallControllerNodeProtocol {
    private struct PanGestureState {
        var offsetFraction: CGFloat
        
        init(offsetFraction: CGFloat) {
            self.offsetFraction = offsetFraction
        }
    }
    
    private let sharedContext: SharedAccountContext
    private let account: Account
    private let presentationData: PresentationData
    private let statusBar: StatusBar
    private let call: PresentationCall
    
    private let containerView: UIView
    private let callScreen: PrivateCallScreen
    private var callScreenState: PrivateCallScreen.State?
    
    let isReady = Promise<Bool>()
    private var didInitializeIsReady: Bool = false
    
    private var callStartTimestamp: Double?
    private var smoothSignalQuality: Double?
    private var smoothSignalQualityTarget: Double?
    
    private var callState: PresentationCallState?
    var isMuted: Bool = false
    
    var toggleMute: (() -> Void)?
    var setCurrentAudioOutput: ((AudioSessionOutput) -> Void)?
    var beginAudioOuputSelection: ((Bool) -> Void)?
    var acceptCall: (() -> Void)?
    var endCall: (() -> Void)?
    var back: (() -> Void)?
    var presentCallRating: ((CallId, Bool) -> Void)?
    var present: ((ViewController) -> Void)?
    var callEnded: ((Bool) -> Void)?
    var willBeDismissedInteractively: (() -> Void)?
    var dismissedInteractively: (() -> Void)?
    var dismissAllTooltips: (() -> Void)?
    var restoreUIForPictureInPicture: ((@escaping (Bool) -> Void) -> Void)?
    var conferenceAddParticipant: (() -> Void)?
    
    private var emojiKey: (data: Data, resolvedKey: [String])?
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?
    
    private var currentPeer: EnginePeer?
    private var peerAvatarDisposable: Disposable?
    
    private var availableAudioOutputs: [AudioSessionOutput]?
    private var currentAudioOutput: AudioSessionOutput?
    private var isMicrophoneMutedDisposable: Disposable?
    private var audioLevelDisposable: Disposable?
    private var audioOutputCheckTimer: Foundation.Timer?
    
    private var applicationInForegroundDisposable: Disposable?
    
    private var localVideo: AdaptedCallVideoSource?
    private var remoteVideo: AdaptedCallVideoSource?
    
    private var panGestureState: PanGestureState?
    private var notifyDismissedInteractivelyOnPanGestureApply: Bool = false
    
    private var signalQualityTimer: Foundation.Timer?
    
    init(
        sharedContext: SharedAccountContext,
        account: Account,
        presentationData: PresentationData,
        statusBar: StatusBar,
        debugInfo: Signal<(String, String), NoError>,
        easyDebugAccess: Bool,
        call: PresentationCall
    ) {
        self.sharedContext = sharedContext
        self.account = account
        self.presentationData = presentationData
        self.statusBar = statusBar
        self.call = call
        
        self.containerView = UIView()
        self.containerView.clipsToBounds = true
        self.callScreen = PrivateCallScreen()
        
        super.init()
        
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.callScreen)
        
        self.callScreen.speakerAction = { [weak self] in
            guard let self else {
                return
            }
            self.beginAudioOuputSelection?(false)
        }
        self.callScreen.videoAction = { [weak self] in
            guard let self else {
                return
            }
            self.toggleVideo()
        }
        self.callScreen.flipCameraAction = { [weak self] in
            guard let self else {
                return
            }
            self.call.switchVideoCamera()
        }
        self.callScreen.microhoneMuteAction = { [weak self] in
            guard let self else {
                return
            }
            
            self.call.toggleIsMuted()
        }
        self.callScreen.endCallAction = { [weak self] in
            guard let self else {
                return
            }
            self.endCall?()
        }
        self.callScreen.backAction = { [weak self] in
            guard let self else {
                return
            }
            self.back?()
            self.callScreen.beginPictureInPictureIfPossible()
        }
        self.callScreen.closeAction = { [weak self] in
            guard let self else {
                return
            }
            self.dismissedInteractively?()
        }
        self.callScreen.restoreUIForPictureInPicture = { [weak self] completion in
            guard let self else {
                completion(false)
                return
            }
            self.restoreUIForPictureInPicture?(completion)
        }
        self.callScreen.conferenceAddParticipant = { [weak self] in
            guard let self else {
                return
            }
            self.conferenceAddParticipant?()
        }

        var enableVideoSharpening = false
        if let data = call.context.currentAppConfiguration.with({ $0 }).data, let value = data["ios_call_video_sharpening"] as? Double {
            enableVideoSharpening = value != 0.0
        }
        
        self.callScreenState = PrivateCallScreen.State(
            strings: presentationData.strings,
            lifecycleState: .connecting,
            name: " ",
            shortName: " ",
            avatarImage: nil,
            audioOutput: .internalSpeaker,
            isLocalAudioMuted: false,
            isRemoteAudioMuted: false,
            localVideo: nil,
            remoteVideo: nil,
            isRemoteBatteryLow: false,
            isEnergySavingEnabled: !self.sharedContext.energyUsageSettings.fullTranslucency,
            isConferencePossible: false,
            enableVideoSharpening: enableVideoSharpening
        )
        
        self.isMicrophoneMutedDisposable = (call.isMuted
        |> deliverOnMainQueue).startStrict(next: { [weak self] isMuted in
            guard let self, var callScreenState = self.callScreenState else {
                return
            }
            self.isMuted = isMuted
            if callScreenState.isLocalAudioMuted != isMuted {
                callScreenState.isLocalAudioMuted = isMuted
                self.callScreenState = callScreenState
                self.update(transition: .animated(duration: 0.3, curve: .spring))
            }
        })
        
        self.audioLevelDisposable = (call.audioLevel
        |> deliverOnMainQueue).start(next: { [weak self] audioLevel in
            guard let self else {
                return
            }
            self.callScreen.addIncomingAudioLevel(value: audioLevel)
        })
        
        self.view.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:))))
        
        self.signalQualityTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
            guard let self else {
                return
            }
            if let smoothSignalQuality = self.smoothSignalQuality, let smoothSignalQualityTarget = self.smoothSignalQualityTarget {
                let updatedSmoothSignalQuality = (smoothSignalQuality + smoothSignalQualityTarget) * 0.5
                if abs(updatedSmoothSignalQuality - smoothSignalQuality) > 0.001 {
                    self.smoothSignalQuality = updatedSmoothSignalQuality
                    
                    if let callState = self.callState {
                        self.updateCallState(callState)
                    }
                }
            }
        })
        
        self.applicationInForegroundDisposable = (self.sharedContext.applicationBindings.applicationInForeground
        |> filter { $0 }
        |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
            guard let self else {
                return
            }
            if self.callScreen.isPictureInPictureRequested {
                Queue.mainQueue().after(0.5, { [weak self] in
                    guard let self else {
                        return
                    }
                    if self.callScreen.isPictureInPictureRequested && !self.callScreen.restoreFromPictureInPictureIfPossible() {
                        Queue.mainQueue().after(0.2, { [weak self] in
                            guard let self else {
                                return
                            }
                            if self.callScreen.isPictureInPictureRequested && !self.callScreen.restoreFromPictureInPictureIfPossible() {
                                Queue.mainQueue().after(0.3, { [weak self] in
                                    guard let self else {
                                        return
                                    }
                                    if self.callScreen.isPictureInPictureRequested && !self.callScreen.restoreFromPictureInPictureIfPossible() {
                                    }
                                })
                            }
                        })
                    }
                })
            }
        })
    }
    
    deinit {
        self.peerAvatarDisposable?.dispose()
        self.isMicrophoneMutedDisposable?.dispose()
        self.audioLevelDisposable?.dispose()
        self.audioOutputCheckTimer?.invalidate()
        self.signalQualityTimer?.invalidate()
        self.applicationInForegroundDisposable?.dispose()
    }
    
    func updateAudioOutputs(availableOutputs: [AudioSessionOutput], currentOutput: AudioSessionOutput?) {
        self.availableAudioOutputs = availableOutputs
        self.currentAudioOutput = currentOutput
        
        if var callScreenState = self.callScreenState {
            let mappedOutput: PrivateCallScreen.State.AudioOutput
            if let currentOutput {
                switch currentOutput {
                case .builtin:
                    mappedOutput = .internalSpeaker
                case .speaker:
                    mappedOutput = .speaker
                case .headphones:
                    mappedOutput = .headphones
                case let .port(port):
                    switch port.type {
                    case .wired:
                        mappedOutput = .headphones
                    default:
                        let portName = port.name.lowercased()
                        if portName.contains("airpods pro") {
                            mappedOutput = .airpodsPro
                        } else if portName.contains("airpods max") {
                            mappedOutput = .airpodsMax
                        } else if portName.contains("airpods") {
                            mappedOutput = .airpods
                        } else {
                            mappedOutput = .bluetooth
                        }
                    }
                }
            } else {
                mappedOutput = .internalSpeaker
            }
            
            if callScreenState.audioOutput != mappedOutput {
                callScreenState.audioOutput = mappedOutput
                self.callScreenState = callScreenState
                self.update(transition: .animated(duration: 0.3, curve: .spring))
                
                self.setupAudioOutputForVideoIfNeeded()
            }
        }
    }
    
    private func toggleVideo() {
        guard let callState = self.callState else {
            return
        }
        switch callState.state {
        case .active:
            switch callState.videoState {
            case .active(let isScreencast, _), .paused(let isScreencast, _):
                let _ = isScreencast
                self.call.disableVideo()
            default:
                DeviceAccess.authorizeAccess(to: .camera(.videoCall), onlyCheck: true, presentationData: self.presentationData, present: { [weak self] c, a in
                    if let strongSelf = self {
                        strongSelf.present?(c)
                    }
                }, openSettings: { [weak self] in
                    self?.sharedContext.applicationBindings.openSettings()
                }, _: { [weak self] ready in
                    guard let self, ready else {
                        return
                    }
                    let proceed = { [weak self] in
                        guard let self else {
                            return
                        }
                        /*switch callState.videoState {
                        case .inactive:
                            self.isRequestingVideo = true
                            self.updateButtonsMode()
                        default:
                            break
                        }*/
                        self.call.requestVideo()
                    }
                    
                    self.call.makeOutgoingVideoView(completion: { [weak self] outgoingVideoView in
                        guard let self else {
                            return
                        }
                        
                        if let outgoingVideoView = outgoingVideoView {
                            outgoingVideoView.view.backgroundColor = .black
                            outgoingVideoView.view.clipsToBounds = true
                            
                            var updateLayoutImpl: ((ContainerViewLayout, CGFloat) -> Void)?
                            
                            let outgoingVideoNode = CallVideoNode(videoView: outgoingVideoView, displayPlaceholderUntilReady: true, disabledText: nil, assumeReadyAfterTimeout: true, isReadyUpdated: { [weak self] in
                                guard let self, let (layout, navigationBarHeight) = self.validLayout else {
                                    return
                                }
                                updateLayoutImpl?(layout, navigationBarHeight)
                            }, orientationUpdated: { [weak self] in
                                guard let self, let (layout, navigationBarHeight) = self.validLayout else {
                                    return
                                }
                                updateLayoutImpl?(layout, navigationBarHeight)
                            }, isFlippedUpdated: { [weak self] _ in
                                guard let self, let (layout, navigationBarHeight) = self.validLayout else {
                                    return
                                }
                                updateLayoutImpl?(layout, navigationBarHeight)
                            })
                            
                            let controller = VoiceChatCameraPreviewController(sharedContext: self.sharedContext, cameraNode: outgoingVideoNode, shareCamera: { _, _ in
                                proceed()
                            }, switchCamera: { [weak self] in
                                Queue.mainQueue().after(0.1) {
                                    self?.call.switchVideoCamera()
                                }
                            })
                            self.present?(controller)
                            
                            updateLayoutImpl = { [weak controller] layout, navigationBarHeight in
                                controller?.containerLayoutUpdated(layout, transition: .immediate)
                            }
                        }
                    })
                })
            }
        default:
            break
        }
    }
    
    private func resolvedEmojiKey(data: Data) -> [String] {
        if let emojiKey = self.emojiKey, emojiKey.data == data {
            return emojiKey.resolvedKey
        }
        let resolvedKey = stringForEmojiHashOfData(data, 4) ?? []
        self.emojiKey = (data, resolvedKey)
        return resolvedKey
    }
    
    func updateCallState(_ callState: PresentationCallState) {
        self.callState = callState
        
        let mappedLifecycleState: PrivateCallScreen.State.LifecycleState
        switch callState.state {
        case .waiting:
            mappedLifecycleState = .requesting
        case .ringing:
            mappedLifecycleState = .ringing
        case let .requesting(isRinging):
            if isRinging {
                mappedLifecycleState = .ringing
            } else {
                mappedLifecycleState = .requesting
            }
        case .connecting:
            mappedLifecycleState = .connecting
        case let .active(startTime, signalQuality, keyData):
            var signalQuality = signalQuality.flatMap(Int.init)
            self.smoothSignalQualityTarget = Double(signalQuality ?? 4)
            
            if let smoothSignalQuality = self.smoothSignalQuality {
                signalQuality = Int(round(smoothSignalQuality))
            } else {
                signalQuality = 4
            }
            
            self.callStartTimestamp = startTime
            
            let _ = keyData
            mappedLifecycleState = .active(PrivateCallScreen.State.ActiveState(
                startTime: startTime + kCFAbsoluteTimeIntervalSince1970,
                signalInfo: PrivateCallScreen.State.SignalInfo(quality: Double(signalQuality ?? 0) / 4.0),
                emojiKey: self.resolvedEmojiKey(data: keyData)
            ))
        case let .reconnecting(startTime, _, keyData):
            self.smoothSignalQuality = nil
            self.smoothSignalQualityTarget = nil
            
            if self.callStartTimestamp != nil {
                mappedLifecycleState = .active(PrivateCallScreen.State.ActiveState(
                    startTime: startTime + kCFAbsoluteTimeIntervalSince1970,
                    signalInfo: PrivateCallScreen.State.SignalInfo(quality: 0.0),
                    emojiKey: self.resolvedEmojiKey(data: keyData)
                ))
            } else {
                mappedLifecycleState = .connecting
            }
        case .terminating(let reason), .terminated(_, let reason, _):
            let duration: Double
            if let callStartTimestamp = self.callStartTimestamp {
                duration = CFAbsoluteTimeGetCurrent() - callStartTimestamp
            } else {
                duration = 0.0
            }
            
            let mappedReason: PrivateCallScreen.State.TerminatedState.Reason
            if let reason {
                switch reason {
                case let .ended(type):
                    switch type {
                    case .missed:
                        if self.call.isOutgoing {
                            mappedReason = .hangUp
                        } else {
                            mappedReason = .missed
                        }
                    case .busy:
                        mappedReason = .busy
                    case .hungUp, .switchedToConference:
                        if self.callStartTimestamp != nil {
                            mappedReason = .hangUp
                        } else {
                            mappedReason = .declined
                        }
                    }
                case .error:
                    mappedReason = .failed
                }
            } else {
                mappedReason = .hangUp
            }
            
            mappedLifecycleState = .terminated(PrivateCallScreen.State.TerminatedState(duration: duration, reason: mappedReason))
        }
        
        switch callState.state {
        case .terminating, .terminated:
            self.localVideo = nil
            self.remoteVideo = nil
        default:
            switch callState.videoState {
            case .active(let isScreencast, _), .paused(let isScreencast, _):
                if isScreencast {
                    self.localVideo = nil
                } else {
                    if self.localVideo == nil {
                        if let call = self.call as? PresentationCallImpl, let videoStreamSignal = call.video(isIncoming: false) {
                            self.localVideo = AdaptedCallVideoSource(videoStreamSignal: videoStreamSignal)
                        }
                    }
                }
            case .inactive, .notAvailable:
                self.localVideo = nil
            }
            
            switch callState.remoteVideoState {
            case .active, .paused:
                if self.remoteVideo == nil {
                    if let call = self.call as? PresentationCallImpl, let videoStreamSignal = call.video(isIncoming: true) {
                        self.remoteVideo = AdaptedCallVideoSource(videoStreamSignal: videoStreamSignal)
                    }
                }
            case .inactive:
                self.remoteVideo = nil
            }
        }
        
        if var callScreenState = self.callScreenState {
            if callScreenState.remoteVideo == nil && self.remoteVideo != nil {
                if let call = self.call as? PresentationCallImpl, let sharedAudioContext = call.sharedAudioContext, case .builtin = sharedAudioContext.currentAudioOutputValue {
                    call.playRemoteCameraTone()
                }
            }
            
            callScreenState.lifecycleState = mappedLifecycleState
            callScreenState.remoteVideo = self.remoteVideo
            callScreenState.localVideo = self.localVideo
            
            switch callState.remoteBatteryLevel {
            case .low:
                callScreenState.isRemoteBatteryLow = true
            case .normal:
                callScreenState.isRemoteBatteryLow = false
            }
            
            switch callState.remoteAudioState {
            case .muted:
                callScreenState.isRemoteAudioMuted = true
            case .active:
                callScreenState.isRemoteAudioMuted = false
            }

            callScreenState.isConferencePossible = callState.supportsConferenceCalls
            
            if self.callScreenState != callScreenState {
                self.callScreenState = callScreenState
                self.update(transition: .animated(duration: 0.35, curve: .spring))
            }
            
            self.setupAudioOutputForVideoIfNeeded()
        }
        
        if case let .terminated(_, _, reportRating) = callState.state {
            self.callEnded?(reportRating)
        }
        
        if !self.didInitializeIsReady {
            self.didInitializeIsReady = true
            
            if let localVideo = self.localVideo {
                self.isReady.set(Signal { subscriber in
                    return localVideo.addOnUpdated {
                        subscriber.putNext(true)
                        subscriber.putCompletion()
                    }
                })
            } else {
                self.isReady.set(.single(true))
            }
        }
    }
    
    private func setupAudioOutputForVideoIfNeeded() {
        guard let callScreenState = self.callScreenState, let currentAudioOutput = self.currentAudioOutput else {
            return
        }
        if callScreenState.localVideo != nil || callScreenState.remoteVideo != nil {
            switch currentAudioOutput {
            case .headphones, .speaker:
                break
            case let .port(port) where port.type == .bluetooth || port.type == .wired:
                break
            default:
                self.setCurrentAudioOutput?(.speaker)
            }
            
            if self.audioOutputCheckTimer == nil {
                self.audioOutputCheckTimer = Foundation.Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] _ in
                    guard let self else {
                        return
                    }
                    self.setupAudioOutputForVideoIfNeeded()
                })
            }
        } else {
            if let audioOutputCheckTimer = self.audioOutputCheckTimer {
                self.audioOutputCheckTimer = nil
                audioOutputCheckTimer.invalidate()
            }
        }
    }
    
    func updatePeer(accountPeer: Peer, peer: Peer, hasOther: Bool) {
        self.updatePeer(peer: EnginePeer(peer))
    }
    
    private func updatePeer(peer: EnginePeer) {
        guard var callScreenState = self.callScreenState else {
            return
        }
        callScreenState.name = peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)
        callScreenState.shortName = peer.compactDisplayTitle
        
        if (self.currentPeer?.smallProfileImage != peer.smallProfileImage) || self.callScreenState?.avatarImage == nil {
            self.peerAvatarDisposable?.dispose()
            
            let size = CGSize(width: 128.0, height: 128.0)
            if let representation = peer.largeProfileImage, let signal = peerAvatarImage(account: self.call.context.account, peerReference: PeerReference(peer._asPeer()), authorOfMessage: nil, representation: representation, displayDimensions: size, synchronousLoad: self.callScreenState?.avatarImage == nil) {
                self.peerAvatarDisposable = (signal
                |> deliverOnMainQueue).startStrict(next: { [weak self] imageVersions in
                    guard let self else {
                        return
                    }
                    let image = imageVersions?.0
                    if let image {
                        callScreenState.avatarImage = image
                        self.callScreenState = callScreenState
                        self.update(transition: .immediate)
                    }
                })
            } else {
                let image = generateImage(size, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    drawPeerAvatarLetters(context: context, size: size, font: avatarPlaceholderFont(size: 50.0), letters: peer.displayLetters, peerId: peer.id, nameColor: peer.nameColor)
                })!
                callScreenState.avatarImage = image
                self.callScreenState = callScreenState
                self.update(transition: .immediate)
            }
        }
        self.currentPeer = peer
        
        if callScreenState != self.callScreenState {
            self.callScreenState = callScreenState
            self.update(transition: .immediate)
        }
    }

    func animateIn() {
        self.panGestureState = nil
        self.update(transition: .immediate)
        
        if !self.containerView.alpha.isZero {
            var bounds = self.bounds
            bounds.origin = CGPoint()
            self.bounds = bounds
            self.layer.removeAnimation(forKey: "bounds")
            self.statusBar.layer.removeAnimation(forKey: "opacity")
            self.containerView.layer.removeAnimation(forKey: "opacity")
            self.containerView.layer.removeAnimation(forKey: "scale")
            self.statusBar.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            
            self.containerView.layer.animateScale(from: 1.04, to: 1.0, duration: 0.3)
            self.containerView.layer.allowsGroupOpacity = true
            self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak self] _ in
                guard let self else {
                    return
                }
                self.containerView.layer.allowsGroupOpacity = false
            })
        }
        
        let _ = self.callScreen.restoreFromPictureInPictureIfPossible()
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.statusBar.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        if self.containerView.alpha > 0.0 {
            self.containerView.layer.allowsGroupOpacity = true
            self.containerView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false, completion: { [weak self] _ in
                self?.containerView.layer.allowsGroupOpacity = false
            })
            self.containerView.layer.animateScale(from: 1.0, to: 1.04, duration: 0.3, removeOnCompletion: false, completion: { _ in
                completion()
            })
        } else {
            completion()
        }
    }
    
    func animateOutToGroupChat(completion: @escaping () -> Void) -> CallController.AnimateOutToGroupChat {
        self.callScreen.animateOutToGroupChat(completion: completion)
        
        let takeSource = self.callScreen.takeIncomingVideoLayer()
        return CallController.AnimateOutToGroupChat(
            containerView: self.containerView,
            incomingPeerId: (takeSource?.1 ?? true) ? self.call.peerId : self.call.context.account.peerId,
            incomingVideoLayer: takeSource?.0.0,
            incomingVideoPlaceholder: takeSource?.0.1
        )
    }
    
    func expandFromPipIfPossible() {
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began, .changed:
            if !self.bounds.height.isZero && !self.notifyDismissedInteractivelyOnPanGestureApply {
                let translation = recognizer.translation(in: self.view)
                self.panGestureState = PanGestureState(offsetFraction: translation.y / self.bounds.height)
                self.update(transition: .immediate)
            }
        case .cancelled, .ended:
            if !self.bounds.height.isZero {
                let translation = recognizer.translation(in: self.view)
                let panGestureState = PanGestureState(offsetFraction: translation.y / self.bounds.height)
                
                let velocity = recognizer.velocity(in: self.view)
                
                self.panGestureState = nil
                if abs(panGestureState.offsetFraction) > 0.6 || abs(velocity.y) >= 100.0 {
                    self.panGestureState = PanGestureState(offsetFraction: panGestureState.offsetFraction < 0.0 ? -1.0 : 1.0)
                    self.notifyDismissedInteractivelyOnPanGestureApply = true
                    self.willBeDismissedInteractively?()
                    self.callScreen.beginPictureInPictureIfPossible()
                }
                
                self.update(transition: .animated(duration: 0.4, curve: .spring))
            }
        default:
            break
        }
    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        var containerOffset: CGFloat = 0.0
        if let panGestureState = self.panGestureState {
            containerOffset = panGestureState.offsetFraction * layout.size.height
            self.containerView.layer.cornerRadius = layout.deviceMetrics.screenCornerRadius
        }
        
        transition.updateFrame(view: self.containerView, frame: CGRect(origin: CGPoint(x: 0.0, y: containerOffset), size: layout.size), completion: { [weak self] completed in
            guard let self, completed else {
                return
            }
            if self.panGestureState == nil {
                self.containerView.layer.cornerRadius = 0.0
            }
            if self.notifyDismissedInteractivelyOnPanGestureApply {
                self.notifyDismissedInteractivelyOnPanGestureApply = false
                self.dismissedInteractively?()
            }
        })
        transition.updateFrame(view: self.callScreen, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        if var callScreenState = self.callScreenState {
            if case .terminated = callScreenState.lifecycleState {
                callScreenState.isLocalAudioMuted = false
                callScreenState.isRemoteAudioMuted = false
                callScreenState.isRemoteBatteryLow = false
                callScreenState.localVideo = nil
                callScreenState.remoteVideo = nil
            }
            self.callScreen.update(
                size: layout.size,
                insets: layout.insets(options: [.statusBar]),
                interfaceOrientation: layout.metrics.orientation ?? .portrait,
                screenCornerRadius: layout.deviceMetrics.screenCornerRadius,
                state: callScreenState,
                transition: ComponentTransition(transition)
            )
        }
    }
}

private func copyI420BufferToNV12Buffer(buffer: OngoingGroupCallContext.VideoFrameData.I420Buffer, pixelBuffer: CVPixelBuffer) -> Bool {
    guard CVPixelBufferGetPixelFormatType(pixelBuffer) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange else {
        return false
    }
    guard CVPixelBufferGetWidthOfPlane(pixelBuffer, 0) == buffer.width else {
        return false
    }
    guard CVPixelBufferGetHeightOfPlane(pixelBuffer, 0) == buffer.height else {
        return false
    }

    let cvRet = CVPixelBufferLockBaseAddress(pixelBuffer, [])
    if cvRet != kCVReturnSuccess {
        return false
    }
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
    }

    guard let dstY = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else {
        return false
    }
    let dstStrideY = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

    guard let dstUV = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
        return false
    }
    let dstStrideUV = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)

    buffer.y.withUnsafeBytes { srcYBuffer in
        guard let srcY = srcYBuffer.baseAddress else {
            return
        }
        buffer.u.withUnsafeBytes { srcUBuffer in
            guard let srcU = srcUBuffer.baseAddress else {
                return
            }
            buffer.v.withUnsafeBytes { srcVBuffer in
                guard let srcV = srcVBuffer.baseAddress else {
                    return
                }
                libyuv_I420ToNV12(
                    srcY.assumingMemoryBound(to: UInt8.self),
                    Int32(buffer.strideY),
                    srcU.assumingMemoryBound(to: UInt8.self),
                    Int32(buffer.strideU),
                    srcV.assumingMemoryBound(to: UInt8.self),
                    Int32(buffer.strideV),
                    dstY.assumingMemoryBound(to: UInt8.self),
                    Int32(dstStrideY),
                    dstUV.assumingMemoryBound(to: UInt8.self),
                    Int32(dstStrideUV),
                    Int32(buffer.width),
                    Int32(buffer.height)
                )
            }
        }
    }

    return true
}

final class AdaptedCallVideoSource: VideoSource {
    final class I420DataBuffer: Output.DataBuffer {
        private let buffer: OngoingGroupCallContext.VideoFrameData.I420Buffer
        
        override var pixelBuffer: CVPixelBuffer? {
            let ioSurfaceProperties = NSMutableDictionary()
            let options = NSMutableDictionary()
            options.setObject(ioSurfaceProperties, forKey: kCVPixelBufferIOSurfacePropertiesKey as NSString)
            
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferCreate(
                kCFAllocatorDefault,
                self.buffer.width,
                self.buffer.height,
                kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                options,
                &pixelBuffer
            )
            if let pixelBuffer, copyI420BufferToNV12Buffer(buffer: buffer, pixelBuffer: pixelBuffer) {
                return pixelBuffer
            } else {
                return nil
            }
        }
        
        init(buffer: OngoingGroupCallContext.VideoFrameData.I420Buffer) {
            self.buffer = buffer
            
            super.init()
        }
    }
    
    final class PixelBufferPool {
        let width: Int
        let height: Int
        let pool: CVPixelBufferPool
        
        init?(width: Int, height: Int) {
            self.width = width
            self.height = height
            
            let bufferOptions: [String: Any] = [
                kCVPixelBufferPoolMinimumBufferCountKey as String: 4 as NSNumber
            ]
            let pixelBufferOptions: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as NSNumber,
                kCVPixelBufferWidthKey as String: width as NSNumber,
                kCVPixelBufferHeightKey as String: height as NSNumber,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as NSDictionary
            ]
            
            var pool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(nil, bufferOptions as CFDictionary, pixelBufferOptions as CFDictionary, &pool)
            guard let pool else {
                return nil
            }
            self.pool = pool
        }
    }
    
    final class PixelBufferPoolState {
        var pool: PixelBufferPool?
    }
    
    private static let queue = Queue(name: "AdaptedCallVideoSource")
    private var onUpdatedListeners = Bag<() -> Void>()
    private(set) var currentOutput: Output?
    
    private var textureCache: CVMetalTextureCache?
    private var pixelBufferPoolState: QueueLocalObject<PixelBufferPoolState>
    
    private var videoFrameDisposable: Disposable?
    
    init(videoStreamSignal: Signal<OngoingGroupCallContext.VideoFrameData, NoError>) {
        let pixelBufferPoolState = QueueLocalObject(queue: AdaptedCallVideoSource.queue, generate: {
            return PixelBufferPoolState()
        })
        self.pixelBufferPoolState = pixelBufferPoolState
        
        CVMetalTextureCacheCreate(nil, nil, MetalEngine.shared.device, nil, &self.textureCache)
        
        self.videoFrameDisposable = (videoStreamSignal
        |> deliverOnMainQueue).start(next: { [weak self] videoFrameData in
            guard let self, let textureCache = self.textureCache else {
                return
            }
            
            let rotationAngle: Float
            switch videoFrameData.deviceRelativeOrientation ?? videoFrameData.orientation {
            case .rotation0:
                rotationAngle = 0.0
            case .rotation90:
                rotationAngle = Float.pi * 0.5
            case .rotation180:
                rotationAngle = Float.pi
            case .rotation270:
                rotationAngle = Float.pi * 3.0 / 2.0
            }
            
            let followsDeviceOrientation = videoFrameData.deviceRelativeOrientation != nil
            
            var mirrorDirection: Output.MirrorDirection = []
            
            var sourceId: Int = 0
            if videoFrameData.mirrorHorizontally || videoFrameData.mirrorVertically {
                sourceId = 1
            }
            
            if let deviceRelativeOrientation = videoFrameData.deviceRelativeOrientation, deviceRelativeOrientation != videoFrameData.orientation {
                let shouldMirror = videoFrameData.mirrorHorizontally || videoFrameData.mirrorVertically
                
                var mirrorHorizontally = false
                var mirrorVertically = false
                
                if shouldMirror {
                    switch deviceRelativeOrientation {
                    case .rotation0:
                        mirrorHorizontally = true
                    case .rotation90:
                        mirrorVertically = true
                    case .rotation180:
                        mirrorHorizontally = true
                    case .rotation270:
                        mirrorVertically = true
                    }
                }
                
                if mirrorHorizontally {
                    mirrorDirection.insert(.horizontal)
                }
                if mirrorVertically {
                    mirrorDirection.insert(.vertical)
                }
            } else {
                if videoFrameData.mirrorHorizontally {
                    mirrorDirection.insert(.horizontal)
                }
                if videoFrameData.mirrorVertically {
                    mirrorDirection.insert(.vertical)
                }
            }
            
            AdaptedCallVideoSource.queue.async { [weak self] in
                let output: Output
                switch videoFrameData.buffer {
                case let .native(nativeBuffer):
                    let width = CVPixelBufferGetWidth(nativeBuffer.pixelBuffer)
                    let height = CVPixelBufferGetHeight(nativeBuffer.pixelBuffer)
                    
                    var cvMetalTextureY: CVMetalTexture?
                    var status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, nativeBuffer.pixelBuffer, nil, .r8Unorm, width, height, 0, &cvMetalTextureY)
                    guard status == kCVReturnSuccess, let yTexture = CVMetalTextureGetTexture(cvMetalTextureY!) else {
                        return
                    }
                    var cvMetalTextureUV: CVMetalTexture?
                    status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, nativeBuffer.pixelBuffer, nil, .rg8Unorm, width / 2, height / 2, 1, &cvMetalTextureUV)
                    guard status == kCVReturnSuccess, let uvTexture = CVMetalTextureGetTexture(cvMetalTextureUV!) else {
                        return
                    }
                    
                    output = Output(
                        resolution: CGSize(width: CGFloat(yTexture.width), height: CGFloat(yTexture.height)),
                        textureLayout: .biPlanar(Output.BiPlanarTextureLayout(
                            y: yTexture,
                            uv: uvTexture
                        )),
                        dataBuffer: Output.NativeDataBuffer(pixelBuffer: nativeBuffer.pixelBuffer),
                        rotationAngle: rotationAngle,
                        followsDeviceOrientation: followsDeviceOrientation,
                        mirrorDirection: mirrorDirection,
                        sourceId: sourceId
                    )
                case let .i420(i420Buffer):
                    guard let pixelBufferPoolState = pixelBufferPoolState.unsafeGet() else {
                        return
                    }
                    
                    let width = i420Buffer.width
                    let height = i420Buffer.height
                    
                    let pool: PixelBufferPool?
                    if let current = pixelBufferPoolState.pool, current.width == width, current.height == height {
                        pool = current
                    } else {
                        pool = PixelBufferPool(width: width, height: height)
                        pixelBufferPoolState.pool = pool
                    }
                    guard let pool else {
                        return
                    }
                    
                    let auxAttributes: [String: Any] = [kCVPixelBufferPoolAllocationThresholdKey as String: 5 as NSNumber]
                    var pixelBuffer: CVPixelBuffer?
                    let result = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool.pool, auxAttributes as CFDictionary, &pixelBuffer)
                    if result == kCVReturnWouldExceedAllocationThreshold {
                        print("kCVReturnWouldExceedAllocationThreshold, dropping frame")
                        return
                    }
                    guard let pixelBuffer else {
                        return
                    }
                    
                    if !copyI420BufferToNV12Buffer(buffer: i420Buffer, pixelBuffer: pixelBuffer) {
                        return
                    }
                    
                    var cvMetalTextureY: CVMetalTexture?
                    var status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .r8Unorm, width, height, 0, &cvMetalTextureY)
                    guard status == kCVReturnSuccess, let yTexture = CVMetalTextureGetTexture(cvMetalTextureY!) else {
                        return
                    }
                    var cvMetalTextureUV: CVMetalTexture?
                    status = CVMetalTextureCacheCreateTextureFromImage(nil, textureCache, pixelBuffer, nil, .rg8Unorm, width / 2, height / 2, 1, &cvMetalTextureUV)
                    guard status == kCVReturnSuccess, let uvTexture = CVMetalTextureGetTexture(cvMetalTextureUV!) else {
                        return
                    }
                    
                    output = Output(
                        resolution: CGSize(width: CGFloat(yTexture.width), height: CGFloat(yTexture.height)),
                        textureLayout: .biPlanar(Output.BiPlanarTextureLayout(
                            y: yTexture,
                            uv: uvTexture
                        )),
                        dataBuffer: Output.NativeDataBuffer(pixelBuffer: pixelBuffer),
                        rotationAngle: rotationAngle,
                        followsDeviceOrientation: followsDeviceOrientation,
                        mirrorDirection: mirrorDirection,
                        sourceId: sourceId
                    )
                default:
                    return
                }
                
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.currentOutput = output
                    for onUpdated in self.onUpdatedListeners.copyItems() {
                        onUpdated()
                    }
                }
            }
        })
    }
    
    func addOnUpdated(_ f: @escaping () -> Void) -> Disposable {
        let index = self.onUpdatedListeners.add(f)
        
        return ActionDisposable { [weak self] in
            DispatchQueue.main.async {
                guard let self else {
                    return
                }
                self.onUpdatedListeners.remove(index)
            }
        }
    }
    
    deinit {
        self.videoFrameDisposable?.dispose()
    }
}
