import Foundation
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

final class CallControllerNodeV2: ViewControllerTracingNode, CallControllerNodeProtocol {
    private let sharedContext: SharedAccountContext
    private let account: Account
    private let presentationData: PresentationData
    private let statusBar: StatusBar
    private let call: PresentationCall
    
    private let containerView: UIView
    private let callScreen: PrivateCallScreen
    private var callScreenState: PrivateCallScreen.State?
    
    private var shouldStayHiddenUntilConnection: Bool = false
    
    private var callStartTimestamp: Double?
    
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
    var dismissedInteractively: (() -> Void)?
    var dismissAllTooltips: (() -> Void)?
    
    private var emojiKey: (data: Data, resolvedKey: [String])?
    private var validLayout: (layout: ContainerViewLayout, navigationBarHeight: CGFloat)?
    
    private var currentPeer: EnginePeer?
    private var peerAvatarDisposable: Disposable?
    
    private var availableAudioOutputs: [AudioSessionOutput]?
    private var isMicrophoneMutedDisposable: Disposable?
    private var audioLevelDisposable: Disposable?
    
    private var remoteVideo: AdaptedCallVideoSource?
    
    init(
        sharedContext: SharedAccountContext,
        account: Account,
        presentationData: PresentationData,
        statusBar: StatusBar,
        debugInfo: Signal<(String, String), NoError>,
        shouldStayHiddenUntilConnection: Bool = false,
        easyDebugAccess: Bool,
        call: PresentationCall
    ) {
        self.sharedContext = sharedContext
        self.account = account
        self.presentationData = presentationData
        self.statusBar = statusBar
        self.call = call
        
        self.containerView = UIView()
        self.callScreen = PrivateCallScreen()
        
        self.shouldStayHiddenUntilConnection = shouldStayHiddenUntilConnection
        
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
            let _ = self
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
        
        self.callScreenState = PrivateCallScreen.State(
            lifecycleState: .connecting,
            name: " ",
            avatarImage: nil,
            audioOutput: .internalSpeaker,
            isMicrophoneMuted: false,
            localVideo: nil,
            remoteVideo: nil
        )
        if let peer = call.peer {
            self.updatePeer(peer: peer)
        }
        
        self.isMicrophoneMutedDisposable = (call.isMuted
        |> deliverOnMainQueue).startStrict(next: { [weak self] isMuted in
            guard let self, var callScreenState = self.callScreenState else {
                return
            }
            self.isMuted = isMuted
            if callScreenState.isMicrophoneMuted != isMuted {
                callScreenState.isMicrophoneMuted = isMuted
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
    }
    
    deinit {
        self.peerAvatarDisposable?.dispose()
        self.isMicrophoneMutedDisposable?.dispose()
        self.audioLevelDisposable?.dispose()
    }
    
    func updateAudioOutputs(availableOutputs: [AudioSessionOutput], currentOutput: AudioSessionOutput?) {
        self.availableAudioOutputs = availableOutputs
        
        if var callScreenState = self.callScreenState {
            let mappedOutput: PrivateCallScreen.State.AudioOutput
            if let currentOutput {
                switch currentOutput {
                case .builtin:
                    mappedOutput = .internalSpeaker
                case .speaker:
                    mappedOutput = .speaker
                case .headphones, .port:
                    mappedOutput = .speaker
                }
            } else {
                mappedOutput = .internalSpeaker
            }
            
            if callScreenState.audioOutput != mappedOutput {
                callScreenState.audioOutput = mappedOutput
                self.callScreenState = callScreenState
                self.update(transition: .animated(duration: 0.3, curve: .spring))
            }
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
        let mappedLifecycleState: PrivateCallScreen.State.LifecycleState
        switch callState.state {
        case .waiting:
            mappedLifecycleState = .connecting
        case .ringing:
            mappedLifecycleState = .ringing
        case let .requesting(isRinging):
            if isRinging {
                mappedLifecycleState = .ringing
            } else {
                mappedLifecycleState = .connecting
            }
        case let .connecting(keyData):
            let _ = keyData
            mappedLifecycleState = .exchangingKeys
        case let .active(startTime, signalQuality, keyData):
            self.callStartTimestamp = startTime
            
            let _ = keyData
            mappedLifecycleState = .active(PrivateCallScreen.State.ActiveState(
                startTime: startTime + kCFAbsoluteTimeIntervalSince1970,
                signalInfo: PrivateCallScreen.State.SignalInfo(quality: Double(signalQuality ?? 0) / 4.0),
                emojiKey: self.resolvedEmojiKey(data: keyData)
            ))
        case let .reconnecting(startTime, _, keyData):
            let _ = keyData
            mappedLifecycleState = .active(PrivateCallScreen.State.ActiveState(
                startTime: startTime + kCFAbsoluteTimeIntervalSince1970,
                signalInfo: PrivateCallScreen.State.SignalInfo(quality: 0.0),
                emojiKey: self.resolvedEmojiKey(data: keyData)
            ))
        case .terminating, .terminated:
            let duration: Double
            if let callStartTimestamp = self.callStartTimestamp {
                duration = CFAbsoluteTimeGetCurrent() - callStartTimestamp
            } else {
                duration = 0.0
            }
            mappedLifecycleState = .terminated(PrivateCallScreen.State.TerminatedState(duration: duration))
        }
        
        switch callState.remoteVideoState {
        case .active, .paused:
            if self.remoteVideo == nil, let call = self.call as? PresentationCallImpl, let videoStreamSignal = call.video(isIncoming: true) {
                self.remoteVideo = AdaptedCallVideoSource(videoStreamSignal: videoStreamSignal)
            }
        case .inactive:
            self.remoteVideo = nil
        }
        
        if var callScreenState = self.callScreenState {
            callScreenState.lifecycleState = mappedLifecycleState
            callScreenState.remoteVideo = self.remoteVideo
            
            if self.callScreenState != callScreenState {
                self.callScreenState = callScreenState
                self.update(transition: .animated(duration: 0.35, curve: .spring))
            }
        }
        
        if case let .terminated(_, _, reportRating) = callState.state {
            self.callEnded?(reportRating)
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
        
        if self.currentPeer?.smallProfileImage != peer.smallProfileImage {
            self.peerAvatarDisposable?.dispose()
            
            if let smallProfileImage = peer.largeProfileImage, let peerReference = PeerReference(peer._asPeer()) {
                if let thumbnailImage = smallProfileImage.immediateThumbnailData.flatMap(decodeTinyThumbnail).flatMap(UIImage.init(data:)), let cgImage = thumbnailImage.cgImage {
                    callScreenState.avatarImage = generateImage(CGSize(width: 128.0, height: 128.0), contextGenerator: { size, context in
                        context.draw(cgImage, in: CGRect(origin: CGPoint(), size: size))
                    }, scale: 1.0).flatMap { image in
                        return blurredImage(image, radius: 10.0)
                    }
                }
                
                let postbox = self.call.context.account.postbox
                self.peerAvatarDisposable = (Signal<UIImage?, NoError> { subscriber in
                    let fetchDisposable = fetchedMediaResource(mediaBox: postbox.mediaBox, userLocation: .other, userContentType: .avatar, reference: .avatar(peer: peerReference, resource: smallProfileImage.resource)).start()
                    let dataDisposable = postbox.mediaBox.resourceData(smallProfileImage.resource).start(next: { data in
                        if data.complete, let image = UIImage(contentsOfFile: data.path)?.precomposed() {
                            subscriber.putNext(image)
                            subscriber.putCompletion()
                        }
                    })
                    
                    return ActionDisposable {
                        fetchDisposable.dispose()
                        dataDisposable.dispose()
                    }
                }
                |> deliverOnMainQueue).start(next: { [weak self] image in
                    guard let self else {
                        return
                    }
                    if var callScreenState = self.callScreenState {
                        callScreenState.avatarImage = image
                        self.callScreenState = callScreenState
                        self.update(transition: .immediate)
                    }
                })
            } else {
                self.peerAvatarDisposable?.dispose()
                self.peerAvatarDisposable = nil
                
                callScreenState.avatarImage = generateImage(CGSize(width: 512, height: 512), scale: 1.0, rotatedContext: { size, context in
                    context.clear(CGRect(origin: CGPoint(), size: size))
                    drawPeerAvatarLetters(context: context, size: size, font: Font.semibold(20.0), letters: peer.displayLetters, peerId: peer.id, nameColor: peer.nameColor)
                })
            }
        }
        self.currentPeer = peer
        
        if callScreenState != self.callScreenState {
            self.callScreenState = callScreenState
            self.update(transition: .immediate)
        }
    }

    func animateIn() {
        if !self.containerView.alpha.isZero {
            var bounds = self.bounds
            bounds.origin = CGPoint()
            self.bounds = bounds
            self.layer.removeAnimation(forKey: "bounds")
            self.statusBar.layer.removeAnimation(forKey: "opacity")
            self.containerView.layer.removeAnimation(forKey: "opacity")
            self.containerView.layer.removeAnimation(forKey: "scale")
            self.statusBar.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
            
            if !self.shouldStayHiddenUntilConnection {
                self.containerView.layer.animateScale(from: 1.04, to: 1.0, duration: 0.3)
                self.containerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            }
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.statusBar.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        if !self.shouldStayHiddenUntilConnection || self.containerView.alpha > 0.0 {
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
    
    func expandFromPipIfPossible() {

    }
    
    private func update(transition: ContainedViewLayoutTransition) {
        guard let (layout, navigationBarHeight) = self.validLayout else {
            return
        }
        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        transition.updateFrame(view: self.containerView, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(view: self.callScreen, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        if let callScreenState = self.callScreenState {
            self.callScreen.update(
                size: layout.size,
                insets: layout.insets(options: [.statusBar]),
                screenCornerRadius: layout.deviceMetrics.screenCornerRadius,
                state: callScreenState,
                transition: Transition(transition)
            )
        }
    }
}

private final class AdaptedCallVideoSource: VideoSource {
    private static let queue = Queue(name: "AdaptedCallVideoSource")
    var updated: (() -> Void)?
    private(set) var currentOutput: Output?
    
    private var textureCache: CVMetalTextureCache?
    private var videoFrameDisposable: Disposable?
    
    init(videoStreamSignal: Signal<OngoingGroupCallContext.VideoFrameData, NoError>) {
        CVMetalTextureCacheCreate(nil, nil, MetalEngine.shared.device, nil, &self.textureCache)
        
        self.videoFrameDisposable = (videoStreamSignal
        |> deliverOnMainQueue).start(next: { [weak self] videoFrameData in
            guard let self, let textureCache = self.textureCache else {
                return
            }
            
            let rotationAngle: Float
            switch videoFrameData.orientation {
            case .rotation0:
                rotationAngle = 0.0
            case .rotation90:
                rotationAngle = Float.pi * 0.5
            case .rotation180:
                rotationAngle = Float.pi
            case .rotation270:
                rotationAngle = Float.pi * 3.0 / 2.0
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
                    
                    output = Output(y: yTexture, uv: uvTexture, rotationAngle: rotationAngle, sourceId: videoFrameData.mirrorHorizontally || videoFrameData.mirrorVertically ? 1 : 0)
                default:
                    return
                }
                
                DispatchQueue.main.async {
                    guard let self else {
                        return
                    }
                    self.currentOutput = output
                    self.updated?()
                }
            }
        })
    }
    
    deinit {
        self.videoFrameDisposable?.dispose()
    }
}
