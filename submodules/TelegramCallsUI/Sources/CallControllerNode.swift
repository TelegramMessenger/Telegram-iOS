import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramPresentationData
import TelegramUIPreferences
import TelegramAudio
import AccountContext
import LocalizedPeerData
import PhotoResources
import CallsEmoji

private func interpolateFrame(from fromValue: CGRect, to toValue: CGRect, t: CGFloat) -> CGRect {
    return CGRect(x: floorToScreenPixels(toValue.origin.x * t + fromValue.origin.x * (1.0 - t)), y: floorToScreenPixels(toValue.origin.y * t + fromValue.origin.y * (1.0 - t)), width: floorToScreenPixels(toValue.size.width * t + fromValue.size.width * (1.0 - t)), height: floorToScreenPixels(toValue.size.height * t + fromValue.size.height * (1.0 - t)))
}

private func interpolate(from: CGFloat, to: CGFloat, value: CGFloat) -> CGFloat {
    return (1.0 - value) * from + value * to
}

private final class CallVideoNode: ASDisplayNode {
    private let videoTransformContainer: ASDisplayNode
    private let videoView: PresentationCallVideoView
    
    private var effectView: UIVisualEffectView?
    private var isBlurred: Bool = false
    private var currentCornerRadius: CGFloat = 0.0
    
    private let isReadyUpdated: () -> Void
    private(set) var isReady: Bool = false
    private var isReadyTimer: SwiftSignalKit.Timer?
    
    init(videoView: PresentationCallVideoView, isReadyUpdated: @escaping () -> Void) {
        self.isReadyUpdated = isReadyUpdated
        
        self.videoTransformContainer = ASDisplayNode()
        self.videoTransformContainer.clipsToBounds = true
        self.videoView = videoView
        self.videoView.view.layer.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        
        super.init()
        
        self.videoTransformContainer.view.addSubview(self.videoView.view)
        self.addSubnode(self.videoTransformContainer)
        
        self.videoView.setOnFirstFrameReceived { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.isReady {
                strongSelf.isReady = true
                strongSelf.isReadyTimer?.invalidate()
                strongSelf.isReadyUpdated()
            }
        }
        
        self.isReadyTimer = SwiftSignalKit.Timer(timeout: 3.0, repeat: false, completion: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if !strongSelf.isReady {
                strongSelf.isReady = true
                strongSelf.isReadyUpdated()
            }
        }, queue: .mainQueue())
        self.isReadyTimer?.start()
    }
    
    deinit {
        self.isReadyTimer?.invalidate()
    }
    
    func updateLayout(size: CGSize, cornerRadius: CGFloat, transition: ContainedViewLayoutTransition) {
        let videoFrame = CGRect(origin: CGPoint(), size: size)
        self.currentCornerRadius = cornerRadius
        
        let previousVideoFrame = self.videoTransformContainer.frame
        self.videoTransformContainer.frame = videoFrame
        if transition.isAnimated && !videoFrame.height.isZero && !previousVideoFrame.height.isZero {
            transition.animatePositionAdditive(node: self.videoTransformContainer, offset: CGPoint(x: previousVideoFrame.midX - videoFrame.midX, y: previousVideoFrame.midY - videoFrame.midY))
            transition.animateTransformScale(node: self.videoTransformContainer, from: previousVideoFrame.height / videoFrame.height)
        }
        
        self.videoView.view.frame = videoFrame
        
        if let effectView = self.effectView {
            effectView.frame = videoFrame
            transition.animatePositionAdditive(layer: effectView.layer, offset: CGPoint(x: previousVideoFrame.midX - videoFrame.midX, y: previousVideoFrame.midY - videoFrame.midY))
            transition.animateTransformScale(view: effectView, from: previousVideoFrame.height / videoFrame.height)
        }
        
        transition.updateCornerRadius(layer: self.videoTransformContainer.layer, cornerRadius: self.currentCornerRadius)
        if let effectView = self.effectView {
            transition.updateCornerRadius(layer: effectView.layer, cornerRadius: self.currentCornerRadius)
        }
    }
    
    func updateIsBlurred(isBlurred: Bool) {
        if self.isBlurred == isBlurred {
            return
        }
        self.isBlurred = isBlurred
        
        if isBlurred {
            if self.effectView == nil {
                let effectView = UIVisualEffectView()
                effectView.clipsToBounds = true
                effectView.layer.cornerRadius = self.currentCornerRadius
                self.effectView = effectView
                effectView.frame = self.videoView.view.frame
                self.view.addSubview(effectView)
            }
            UIView.animate(withDuration: 0.3, animations: {
                self.effectView?.effect = UIBlurEffect(style: .dark)
            })
        } else if let effectView = self.effectView {
            self.effectView = nil
            UIView.animate(withDuration: 0.3, animations: {
                effectView.effect = nil
            }, completion: { [weak effectView] _ in
                effectView?.removeFromSuperview()
            })
        }
    }
}

final class CallControllerNode: ViewControllerTracingNode, CallControllerNodeProtocol {
    private enum VideoNodeCorner {
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
    private let sharedContext: SharedAccountContext
    private let account: Account
    
    private let statusBar: StatusBar
    
    private var presentationData: PresentationData
    private var peer: Peer?
    private let debugInfo: Signal<(String, String), NoError>
    private var forceReportRating = false
    private let easyDebugAccess: Bool
    private let call: PresentationCall
    
    private let containerTransformationNode: ASDisplayNode
    private let containerNode: ASDisplayNode
    
    private let imageNode: TransformImageNode
    private let dimNode: ASDisplayNode
    
    private var incomingVideoNodeValue: CallVideoNode?
    private var incomingVideoViewRequested: Bool = false
    private var outgoingVideoNodeValue: CallVideoNode?
    private var outgoingVideoViewRequested: Bool = false
    
    private var expandedVideoNode: CallVideoNode?
    private var minimizedVideoNode: CallVideoNode?
    private var disableAnimationForExpandedVideoOnce: Bool = false
    private var animationForExpandedVideoSnapshotView: UIView? = nil
    
    private var outgoingVideoNodeCorner: VideoNodeCorner = .bottomRight
    private let backButtonArrowNode: ASImageNode
    private let backButtonNode: HighlightableButtonNode
    private let statusNode: CallControllerStatusNode
    private let videoPausedNode: ImmediateTextNode
    private let buttonsNode: CallControllerButtonsNode
    private var keyPreviewNode: CallControllerKeyPreviewNode?
    
    private var debugNode: CallDebugNode?
    
    private var keyTextData: (Data, String)?
    private let keyButtonNode: HighlightableButtonNode
    
    private var validLayout: (ContainerViewLayout, CGFloat)?
    
    var isMuted: Bool = false {
        didSet {
            self.buttonsNode.isMuted = self.isMuted
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
            }
        }
    }
    
    private var shouldStayHiddenUntilConnection: Bool = false
    
    private var audioOutputState: ([AudioSessionOutput], currentOutput: AudioSessionOutput?)?
    private var callState: PresentationCallState?
    
    var toggleMute: (() -> Void)?
    var setCurrentAudioOutput: ((AudioSessionOutput) -> Void)?
    var beginAudioOuputSelection: (() -> Void)?
    var acceptCall: (() -> Void)?
    var endCall: (() -> Void)?
    var setIsVideoPaused: ((Bool) -> Void)?
    var back: (() -> Void)?
    var presentCallRating: ((CallId) -> Void)?
    var callEnded: ((Bool) -> Void)?
    var dismissedInteractively: (() -> Void)?
    
    private var buttonsMode: CallControllerButtonsMode?
    
    private var isUIHidden: Bool = false
    private var isVideoPaused: Bool = false
    
    private enum PictureInPictureGestureState {
        case none
        case collapsing(didSelectCorner: Bool)
        case dragging(initialPosition: CGPoint, draggingPosition: CGPoint)
    }
    
    private var pictureInPictureGestureState: PictureInPictureGestureState = .none
    private var pictureInPictureCorner: VideoNodeCorner = .topRight
    private var pictureInPictureTransitionFraction: CGFloat = 0.0
    
    init(sharedContext: SharedAccountContext, account: Account, presentationData: PresentationData, statusBar: StatusBar, debugInfo: Signal<(String, String), NoError>, shouldStayHiddenUntilConnection: Bool = false, easyDebugAccess: Bool, call: PresentationCall) {
        self.sharedContext = sharedContext
        self.account = account
        self.presentationData = presentationData
        self.statusBar = statusBar
        self.debugInfo = debugInfo
        self.shouldStayHiddenUntilConnection = shouldStayHiddenUntilConnection
        self.easyDebugAccess = easyDebugAccess
        self.call = call
        
        self.containerTransformationNode = ASDisplayNode()
        self.containerTransformationNode.clipsToBounds = true
        
        self.containerNode = ASDisplayNode()
        if self.shouldStayHiddenUntilConnection {
            self.containerNode.alpha = 0.0
        }
        
        self.imageNode = TransformImageNode()
        self.imageNode.contentAnimations = [.subsequentUpdates]
        self.dimNode = ASDisplayNode()
        self.dimNode.isUserInteractionEnabled = false
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.4)
        
        self.backButtonArrowNode = ASImageNode()
        self.backButtonArrowNode.displayWithoutProcessing = true
        self.backButtonArrowNode.displaysAsynchronously = false
        self.backButtonArrowNode.image = NavigationBarTheme.generateBackArrowImage(color: .white)
        self.backButtonNode = HighlightableButtonNode()
        
        self.statusNode = CallControllerStatusNode()
        
        self.videoPausedNode = ImmediateTextNode()
        self.videoPausedNode.alpha = 0.0
        
        self.buttonsNode = CallControllerButtonsNode(strings: self.presentationData.strings)
        self.keyButtonNode = HighlightableButtonNode()
        
        super.init()
        
        self.containerNode.backgroundColor = .black
        
        self.addSubnode(self.containerTransformationNode)
        self.containerTransformationNode.addSubnode(self.containerNode)
        
        self.backButtonNode.setTitle(presentationData.strings.Common_Back, with: Font.regular(17.0), with: .white, for: [])
        self.backButtonNode.hitTestSlop = UIEdgeInsets(top: -8.0, left: -20.0, bottom: -8.0, right: -8.0)
        self.backButtonNode.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self {
                if highlighted {
                    strongSelf.backButtonNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backButtonArrowNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backButtonNode.alpha = 0.4
                    strongSelf.backButtonArrowNode.alpha = 0.4
                } else {
                    strongSelf.backButtonNode.alpha = 1.0
                    strongSelf.backButtonArrowNode.alpha = 1.0
                    strongSelf.backButtonNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    strongSelf.backButtonArrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                }
            }
        }
        
        self.containerNode.addSubnode(self.imageNode)
        self.containerNode.addSubnode(self.dimNode)
        self.containerNode.addSubnode(self.statusNode)
        self.containerNode.addSubnode(self.videoPausedNode)
        self.containerNode.addSubnode(self.buttonsNode)
        self.containerNode.addSubnode(self.keyButtonNode)
        self.containerNode.addSubnode(self.backButtonArrowNode)
        self.containerNode.addSubnode(self.backButtonNode)
        
        self.buttonsNode.mute = { [weak self] in
            self?.toggleMute?()
        }
        
        self.buttonsNode.speaker = { [weak self] in
            self?.beginAudioOuputSelection?()
        }
        
        self.buttonsNode.end = { [weak self] in
            self?.endCall?()
        }
        
        self.buttonsNode.accept = { [weak self] in
            guard let strongSelf = self, let callState = strongSelf.callState else {
                return
            }
            switch callState.state {
            case .active, .connecting, .reconnecting:
                strongSelf.call.acceptVideo()
            case .ringing:
                strongSelf.acceptCall?()
            default:
                break
            }
        }
        
        self.buttonsNode.toggleVideo = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.outgoingVideoNodeValue == nil {
                strongSelf.call.requestVideo()
            } else {
                strongSelf.isVideoPaused = !strongSelf.isVideoPaused
                strongSelf.outgoingVideoNodeValue?.updateIsBlurred(isBlurred: strongSelf.isVideoPaused)
                strongSelf.buttonsNode.isCameraPaused = strongSelf.isVideoPaused
                strongSelf.setIsVideoPaused?(strongSelf.isVideoPaused)
                
                if let (layout, navigationBarHeight) = strongSelf.validLayout {
                    strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                }
            }
        }
        
        self.buttonsNode.rotateCamera = { [weak self] in
            self?.call.switchVideoCamera()
        }
        
        self.keyButtonNode.addTarget(self, action: #selector(self.keyPressed), forControlEvents: .touchUpInside)
        
        self.backButtonNode.addTarget(self, action: #selector(self.backPressed), forControlEvents: .touchUpInside)
    }
    
    override func didLoad() {
        super.didLoad()
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        self.view.addGestureRecognizer(panRecognizer)
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:)))
        self.view.addGestureRecognizer(tapRecognizer)
    }
    
    func updatePeer(accountPeer: Peer, peer: Peer, hasOther: Bool) {
        if !arePeersEqual(self.peer, peer) {
            self.peer = peer
            if let peerReference = PeerReference(peer), !peer.profileImageRepresentations.isEmpty {
                let representations: [ImageRepresentationWithReference] = peer.profileImageRepresentations.map({ ImageRepresentationWithReference(representation: $0, reference: .avatar(peer: peerReference, resource: $0.resource)) })
                self.imageNode.setSignal(chatAvatarGalleryPhoto(account: self.account, representations: representations, immediateThumbnailData: nil, autoFetchFullSize: true))
                self.dimNode.isHidden = false
            } else {
                self.imageNode.setSignal(callDefaultBackground())
                self.dimNode.isHidden = true
            }
            
            self.statusNode.title = peer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)
            if hasOther {
                self.statusNode.subtitle = self.presentationData.strings.Call_AnsweringWithAccount(accountPeer.displayTitle(strings: self.presentationData.strings, displayOrder: self.presentationData.nameDisplayOrder)).0
                
                if let callState = callState {
                    self.updateCallState(callState)
                }
            }
            
            self.videoPausedNode.attributedText = NSAttributedString(string: self.presentationData.strings.Call_RemoteVideoPaused(peer.compactDisplayTitle).0, font: Font.regular(17.0), textColor: .white)
            
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
    }
    
    func updateAudioOutputs(availableOutputs: [AudioSessionOutput], currentOutput: AudioSessionOutput?) {
        if self.audioOutputState?.0 != availableOutputs || self.audioOutputState?.1 != currentOutput {
            self.audioOutputState = (availableOutputs, currentOutput)
            self.updateButtonsMode()
        }
    }
    
    func updateCallState(_ callState: PresentationCallState) {
        self.callState = callState
        
        let statusValue: CallControllerStatusValue
        var statusReception: Int32?
        
        switch callState.videoState {
        case .active:
            if !self.incomingVideoViewRequested {
                self.incomingVideoViewRequested = true
                self.call.makeIncomingVideoView(completion: { [weak self] incomingVideoView in
                    guard let strongSelf = self else {
                        return
                    }
                    if let incomingVideoView = incomingVideoView {
                        let incomingVideoNode = CallVideoNode(videoView: incomingVideoView, isReadyUpdated: {
                            guard let strongSelf = self else {
                                return
                            }
                            if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.5, curve: .spring))
                            }
                        })
                        strongSelf.incomingVideoNodeValue = incomingVideoNode
                        strongSelf.expandedVideoNode = incomingVideoNode
                        strongSelf.containerNode.insertSubnode(incomingVideoNode, aboveSubnode: strongSelf.dimNode)
                        if let (layout, navigationBarHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.5, curve: .spring))
                        }
                    }
                })
            }
        default:
            break
        }
        
        switch callState.videoState {
        case .active, .outgoingRequested, .incomingRequested:
            if !self.outgoingVideoViewRequested {
                self.outgoingVideoViewRequested = true
                self.call.makeOutgoingVideoView(completion: { [weak self] outgoingVideoView in
                    guard let strongSelf = self else {
                        return
                    }
                    if let outgoingVideoView = outgoingVideoView {
                        outgoingVideoView.view.backgroundColor = .black
                        outgoingVideoView.view.clipsToBounds = true
                        if let audioOutputState = strongSelf.audioOutputState, let currentOutput = audioOutputState.currentOutput {
                            switch currentOutput {
                            case .speaker, .builtin:
                                break
                            default:
                                strongSelf.setCurrentAudioOutput?(.speaker)
                            }
                        }
                        let outgoingVideoNode = CallVideoNode(videoView: outgoingVideoView, isReadyUpdated: {})
                        strongSelf.outgoingVideoNodeValue = outgoingVideoNode
                        strongSelf.minimizedVideoNode = outgoingVideoNode
                        if let expandedVideoNode = strongSelf.expandedVideoNode {
                            strongSelf.containerNode.insertSubnode(outgoingVideoNode, aboveSubnode: expandedVideoNode)
                        } else {
                            strongSelf.containerNode.insertSubnode(outgoingVideoNode, aboveSubnode: strongSelf.dimNode)
                        }
                        if let (layout, navigationBarHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                        }
                    }
                })
            }
        default:
            break
        }
        
        if let incomingVideoNode = self.incomingVideoNodeValue {
            switch callState.state {
            case .terminating, .terminated:
                break
            default:
                let isActive: Bool
                switch callState.remoteVideoState {
                case .inactive:
                    isActive = false
                case .active:
                    isActive = true
                }
                incomingVideoNode.updateIsBlurred(isBlurred: !isActive)
                if isActive != self.videoPausedNode.alpha.isZero {
                    if isActive {
                        self.videoPausedNode.alpha = 0.0
                        self.videoPausedNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3)
                    } else {
                        self.videoPausedNode.alpha = 1.0
                        self.videoPausedNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                }
            }
        }
        
        switch callState.state {
            case .waiting, .connecting:
                statusValue = .text(string: self.presentationData.strings.Call_StatusConnecting, displayLogo: false)
            case let .requesting(ringing):
                if ringing {
                    statusValue = .text(string: self.presentationData.strings.Call_StatusRinging, displayLogo: false)
                } else {
                    statusValue = .text(string: self.presentationData.strings.Call_StatusRequesting, displayLogo: false)
                }
            case .terminating:
                statusValue = .text(string: self.presentationData.strings.Call_StatusEnded, displayLogo: false)
            case let .terminated(_, reason, _):
                if let reason = reason {
                    switch reason {
                        case let .ended(type):
                            switch type {
                                case .busy:
                                    statusValue = .text(string: self.presentationData.strings.Call_StatusBusy, displayLogo: false)
                                case .hungUp, .missed:
                                    statusValue = .text(string: self.presentationData.strings.Call_StatusEnded, displayLogo: false)
                            }
                        case .error:
                            statusValue = .text(string: self.presentationData.strings.Call_StatusFailed, displayLogo: false)
                    }
                } else {
                    statusValue = .text(string: self.presentationData.strings.Call_StatusEnded, displayLogo: false)
                }
            case .ringing:
                var text: String
                if self.call.isVideo {
                    text = self.presentationData.strings.Call_IncomingVideoCall
                } else {
                    text = self.presentationData.strings.Call_IncomingVoiceCall
                }
                if !self.statusNode.subtitle.isEmpty {
                    text += "\n\(self.statusNode.subtitle)"
                }
                statusValue = .text(string: text, displayLogo: true)
            case .active(let timestamp, let reception, let keyVisualHash), .reconnecting(let timestamp, let reception, let keyVisualHash):
                let strings = self.presentationData.strings
                var isReconnecting = false
                if case .reconnecting = callState.state {
                    isReconnecting = true
                }
                if self.keyTextData?.0 != keyVisualHash {
                    let text = stringForEmojiHashOfData(keyVisualHash, 4)!
                    self.keyTextData = (keyVisualHash, text)
                    
                    self.keyButtonNode.setAttributedTitle(NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: Font.regular(22.0), NSAttributedString.Key.kern: 2.5 as NSNumber]), for: [])
                    
                    let keyTextSize = self.keyButtonNode.measure(CGSize(width: 200.0, height: 200.0))
                    self.keyButtonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    self.keyButtonNode.frame = CGRect(origin: self.keyButtonNode.frame.origin, size: keyTextSize)
                    
                    if let (layout, navigationBarHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    }
                }
                switch callState.videoState {
                case .notAvailable, .active, .possible:
                    statusValue = .timer({ value in
                        if isReconnecting {
                            return strings.Call_StatusConnecting
                        } else {
                            return value
                        }
                    }, timestamp)
                    statusReception = reception
                case .incomingRequested:
                    var text: String
                    text = self.presentationData.strings.Call_IncomingVideoCall
                    if !self.statusNode.subtitle.isEmpty {
                        text += "\n\(self.statusNode.subtitle)"
                    }
                    statusValue = .text(string: text, displayLogo: true)
                case .outgoingRequested:
                    statusValue = .text(string: self.presentationData.strings.Call_StatusRequesting, displayLogo: false)
                }
        }
        if self.shouldStayHiddenUntilConnection {
            switch callState.state {
                case .connecting, .active:
                    self.containerNode.alpha = 1.0
                default:
                    break
            }
        }
        self.statusNode.status = statusValue
        self.statusNode.reception = statusReception
        
        if let callState = self.callState {
            switch callState.state {
            case .active, .connecting, .reconnecting:
                break
            default:
                self.isUIHidden = false
            }
        }
        
        self.updateButtonsMode()
        
        if case let .terminated(id, _, reportRating) = callState.state, let callId = id {
            let presentRating = reportRating || self.forceReportRating
            if presentRating {
                self.presentCallRating?(callId)
            }
            self.callEnded?(presentRating)
        }
    }
    
    private var buttonsTerminationMode: CallControllerButtonsMode?
    
    private func updateButtonsMode() {
        guard let callState = self.callState else {
            return
        }
        
        var mode: CallControllerButtonsSpeakerMode = .none
        if let (availableOutputs, maybeCurrentOutput) = self.audioOutputState, let currentOutput = maybeCurrentOutput {
            switch currentOutput {
                case .builtin:
                    mode = .builtin
                case .speaker:
                    mode = .speaker
                case .headphones:
                    mode = .headphones
                case .port:
                    mode = .bluetooth
            }
            if availableOutputs.count <= 1 {
                mode = .none
            }
        }
        let mappedVideoState: CallControllerButtonsMode.VideoState
        switch callState.videoState {
        case .notAvailable:
            mappedVideoState = .notAvailable
        case .possible:
            mappedVideoState = .possible
        case .outgoingRequested:
            mappedVideoState = .outgoingRequested
        case .incomingRequested:
            mappedVideoState = .incomingRequested
        case .active:
            mappedVideoState = .active
        }
        
        switch callState.state {
        case .ringing:
            self.buttonsMode = .incoming(speakerMode: mode, videoState: mappedVideoState)
            self.buttonsTerminationMode = buttonsMode
        case .waiting, .requesting:
            self.buttonsMode = .outgoingRinging(speakerMode: mode, videoState: mappedVideoState)
            self.buttonsTerminationMode = buttonsMode
        case .active, .connecting, .reconnecting:
            self.buttonsMode = .active(speakerMode: mode, videoState: mappedVideoState)
            self.buttonsTerminationMode = buttonsMode
        case .terminating, .terminated:
            if let buttonsTerminationMode = self.buttonsTerminationMode {
                self.buttonsMode = buttonsTerminationMode
            } else {
                self.buttonsMode = .active(speakerMode: mode, videoState: mappedVideoState)
            }
        }
        
        if let (layout, navigationHeight) = self.validLayout {
            self.pictureInPictureTransitionFraction = 0.0
            
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.3, curve: .spring))
        }
    }
    
    func animateIn() {
        var bounds = self.bounds
        bounds.origin = CGPoint()
        self.bounds = bounds
        self.layer.removeAnimation(forKey: "bounds")
        self.statusBar.layer.removeAnimation(forKey: "opacity")
        self.containerNode.layer.removeAnimation(forKey: "opacity")
        self.containerNode.layer.removeAnimation(forKey: "scale")
        self.statusBar.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
        if !self.shouldStayHiddenUntilConnection {
            self.containerNode.layer.animateScale(from: 1.04, to: 1.0, duration: 0.3)
            self.containerNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        }
    }
    
    func animateOut(completion: @escaping () -> Void) {
        self.statusBar.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
        if !self.shouldStayHiddenUntilConnection || self.containerNode.alpha > 0.0 {
            self.containerNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, removeOnCompletion: false)
            self.containerNode.layer.animateScale(from: 1.0, to: 1.04, duration: 0.3, removeOnCompletion: false, completion: { _ in
                completion()
            })
        } else {
            completion()
        }
    }
    
    func expandFromPipIfPossible() {
        if self.pictureInPictureTransitionFraction.isEqual(to: 1.0), let (layout, navigationHeight) = self.validLayout {
            self.pictureInPictureTransitionFraction = 0.0
            
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring))
        }
    }
    
    private func calculatePreviewVideoRect(layout: ContainerViewLayout, navigationHeight: CGFloat) -> CGRect {
        var uiDisplayTransition: CGFloat = self.isUIHidden ? 0.0 : 1.0
        uiDisplayTransition *= 1.0 - self.pictureInPictureTransitionFraction
        
        let buttonsHeight: CGFloat = self.buttonsNode.bounds.height
        
        var fullInsets = layout.insets(options: .statusBar)
        
        var cleanInsets = fullInsets
        cleanInsets.bottom = layout.intrinsicInsets.bottom
        cleanInsets.left = 20.0
        cleanInsets.right = 20.0
        
        fullInsets.top += 44.0 + 8.0
        fullInsets.bottom = buttonsHeight + 27.0
        fullInsets.left = 20.0
        fullInsets.right = 20.0
        
        var insets: UIEdgeInsets = self.isUIHidden ? cleanInsets : fullInsets
        
        let expandedInset: CGFloat = 16.0
        
        insets.top = interpolate(from: expandedInset, to: insets.top, value: 1.0 - self.pictureInPictureTransitionFraction)
        insets.bottom = interpolate(from: expandedInset, to: insets.bottom, value: 1.0 - self.pictureInPictureTransitionFraction)
        insets.left = interpolate(from: expandedInset, to: insets.left, value: 1.0 - self.pictureInPictureTransitionFraction)
        insets.right = interpolate(from: expandedInset, to: insets.right, value: 1.0 - self.pictureInPictureTransitionFraction)
        
        let previewVideoSide = interpolate(from: 350.0, to: 200.0, value: 1.0 - self.pictureInPictureTransitionFraction)
        let previewVideoSize = layout.size.aspectFitted(CGSize(width: previewVideoSide, height: previewVideoSide))
        let previewVideoY: CGFloat
        let previewVideoX: CGFloat
        
        switch self.outgoingVideoNodeCorner {
        case .topLeft:
            previewVideoX = insets.left
            previewVideoY = insets.top
        case .topRight:
            previewVideoX = layout.size.width - previewVideoSize.width - insets.right
            previewVideoY = insets.top
        case .bottomLeft:
            previewVideoX = insets.left
            previewVideoY = layout.size.height - insets.bottom - previewVideoSize.height
        case .bottomRight:
            previewVideoX = layout.size.width - previewVideoSize.width - insets.right
            previewVideoY = layout.size.height - insets.bottom - previewVideoSize.height
        }
        
        return CGRect(origin: CGPoint(x: previewVideoX, y: previewVideoY), size: previewVideoSize)
    }
    
    private func calculatePictureInPictureContainerRect(layout: ContainerViewLayout, navigationHeight: CGFloat) -> CGRect {
        let pictureInPictureTopInset: CGFloat = layout.insets(options: .statusBar).top + 44.0 + 8.0
        let pictureInPictureSideInset: CGFloat = 8.0
        let pictureInPictureSize = layout.size.fitted(CGSize(width: 240.0, height: 240.0))
        let pictureInPictureBottomInset: CGFloat = layout.insets(options: .input).bottom + 44.0 + 8.0
        
        let containerPictureInPictureFrame: CGRect
        switch self.pictureInPictureCorner {
        case .topLeft:
            containerPictureInPictureFrame = CGRect(origin: CGPoint(x: pictureInPictureSideInset, y: pictureInPictureTopInset), size: pictureInPictureSize)
        case .topRight:
            containerPictureInPictureFrame = CGRect(origin: CGPoint(x: layout.size.width -  pictureInPictureSideInset - pictureInPictureSize.width, y: pictureInPictureTopInset), size: pictureInPictureSize)
        case .bottomLeft:
            containerPictureInPictureFrame = CGRect(origin: CGPoint(x: pictureInPictureSideInset, y: layout.size.height - pictureInPictureBottomInset - pictureInPictureSize.height), size: pictureInPictureSize)
        case .bottomRight:
            containerPictureInPictureFrame = CGRect(origin: CGPoint(x: layout.size.width -  pictureInPictureSideInset - pictureInPictureSize.width, y: layout.size.height - pictureInPictureBottomInset - pictureInPictureSize.height), size: pictureInPictureSize)
        }
        return containerPictureInPictureFrame
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        var uiDisplayTransition: CGFloat = self.isUIHidden ? 0.0 : 1.0
        uiDisplayTransition *= 1.0 - self.pictureInPictureTransitionFraction
        
        let buttonsHeight: CGFloat
        if let buttonsMode = self.buttonsMode {
            buttonsHeight = self.buttonsNode.updateLayout(strings: self.presentationData.strings, mode: buttonsMode, constrainedWidth: layout.size.width, bottomInset: layout.intrinsicInsets.bottom, transition: transition)
        } else {
            buttonsHeight = 0.0
        }
        let defaultButtonsOriginY = layout.size.height - buttonsHeight
        let buttonsOriginY = interpolate(from: layout.size.height + 10.0, to: defaultButtonsOriginY, value: uiDisplayTransition)
        
        var overlayAlpha: CGFloat = uiDisplayTransition
        
        switch self.callState?.state {
        case .terminated, .terminating:
            overlayAlpha *= 0.5
        default:
            break
        }
        
        let containerFullScreenFrame = CGRect(origin: CGPoint(), size: layout.size)
        let containerPictureInPictureFrame = self.calculatePictureInPictureContainerRect(layout: layout, navigationHeight: navigationBarHeight)
        
        let containerFrame = interpolateFrame(from: containerFullScreenFrame, to: containerPictureInPictureFrame, t: self.pictureInPictureTransitionFraction)
        
        transition.updateFrame(node: self.containerTransformationNode, frame: containerFrame)
        transition.updateSublayerTransformScale(node: self.containerTransformationNode, scale: min(1.0, containerFrame.width / layout.size.width * 1.01))
        transition.updateCornerRadius(layer: self.containerTransformationNode.layer, cornerRadius: self.pictureInPictureTransitionFraction * 10.0)
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(x: (containerFrame.width - layout.size.width) / 2.0, y: floor(containerFrame.height - layout.size.height) / 2.0), size: layout.size))
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        if let keyPreviewNode = self.keyPreviewNode {
            transition.updateFrame(node: keyPreviewNode, frame: CGRect(origin: CGPoint(), size: layout.size))
            keyPreviewNode.updateLayout(size: layout.size, transition: .immediate)
        }
        
        transition.updateFrame(node: self.imageNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: CGSize(width: 640.0, height: 640.0).aspectFilled(layout.size), boundingSize: layout.size, intrinsicInsets: UIEdgeInsets())
        let apply = self.imageNode.asyncLayout()(arguments)
        apply()
        
        let navigationOffset: CGFloat = max(20.0, layout.safeInsets.top)
        
        let backSize = self.backButtonNode.measure(CGSize(width: 320.0, height: 100.0))
        if let image = self.backButtonArrowNode.image {
            transition.updateFrame(node: self.backButtonArrowNode, frame: CGRect(origin: CGPoint(x: 10.0, y: navigationOffset + 11.0), size: image.size))
        }
        transition.updateFrame(node: self.backButtonNode, frame: CGRect(origin: CGPoint(x: 29.0, y: navigationOffset + 11.0), size: backSize))
        
        transition.updateAlpha(node: self.backButtonArrowNode, alpha: overlayAlpha)
        transition.updateAlpha(node: self.backButtonNode, alpha: overlayAlpha)
        
        var statusOffset: CGFloat
        if layout.metrics.widthClass == .regular && layout.metrics.heightClass == .regular {
            if layout.size.height.isEqual(to: 1366.0) {
                statusOffset = 160.0
            } else {
                statusOffset = 120.0
            }
        } else {
            if layout.size.height.isEqual(to: 736.0) {
                statusOffset = 80.0
            } else if layout.size.width.isEqual(to: 320.0) {
                statusOffset = 60.0
            } else {
                statusOffset = 64.0
            }
        }
        
        statusOffset += layout.safeInsets.top
        
        let statusHeight = self.statusNode.updateLayout(constrainedWidth: layout.size.width, transition: transition)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: 0.0, y: statusOffset), size: CGSize(width: layout.size.width, height: statusHeight)))
        transition.updateAlpha(node: self.statusNode, alpha: overlayAlpha)
        
        let videoPausedSize = self.videoPausedNode.updateLayout(CGSize(width: layout.size.width - 16.0, height: 100.0))
        transition.updateFrame(node: self.videoPausedNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - videoPausedSize.width) / 2.0), y: floor((layout.size.height - videoPausedSize.height) / 2.0)), size: videoPausedSize))
        
        transition.updateFrame(node: self.buttonsNode, frame: CGRect(origin: CGPoint(x: 0.0, y: buttonsOriginY), size: CGSize(width: layout.size.width, height: buttonsHeight)))
        transition.updateAlpha(node: self.buttonsNode, alpha: overlayAlpha)
        
        let fullscreenVideoFrame = CGRect(origin: CGPoint(), size: layout.size)
        let previewVideoFrame = self.calculatePreviewVideoRect(layout: layout, navigationHeight: navigationBarHeight)
        
        if let expandedVideoNode = self.expandedVideoNode {
            var expandedVideoTransition = transition
            if expandedVideoNode.frame.isEmpty || self.disableAnimationForExpandedVideoOnce {
                expandedVideoTransition = .immediate
                self.disableAnimationForExpandedVideoOnce = false
            }
            expandedVideoTransition.updateFrame(node: expandedVideoNode, frame: fullscreenVideoFrame)
            expandedVideoNode.updateLayout(size: expandedVideoNode.frame.size, cornerRadius: 0.0, transition: expandedVideoTransition)
        }
        if let minimizedVideoNode = self.minimizedVideoNode {
            var minimizedVideoTransition = transition
            if minimizedVideoNode.frame.isEmpty {
                minimizedVideoTransition = .immediate
            }
            if let expandedVideoNode = self.expandedVideoNode, expandedVideoNode.isReady {
                if self.minimizedVideoDraggingPosition == nil {
                    if let animationForExpandedVideoSnapshotView = self.animationForExpandedVideoSnapshotView {
                        self.containerNode.view.addSubview(animationForExpandedVideoSnapshotView)
                        transition.updateAlpha(layer: animationForExpandedVideoSnapshotView.layer, alpha: 0.0, completion: { [weak animationForExpandedVideoSnapshotView] _ in
                            animationForExpandedVideoSnapshotView?.removeFromSuperview()
                        })
                        transition.updateTransformScale(layer: animationForExpandedVideoSnapshotView.layer, scale: previewVideoFrame.width / fullscreenVideoFrame.width)
                        
                        transition.updatePosition(layer: animationForExpandedVideoSnapshotView.layer, position: CGPoint(x: previewVideoFrame.minX + previewVideoFrame.center.x /  fullscreenVideoFrame.width * previewVideoFrame.width, y: previewVideoFrame.minY + previewVideoFrame.center.y / fullscreenVideoFrame.height * previewVideoFrame.height))
                        self.animationForExpandedVideoSnapshotView = nil
                    }
                    minimizedVideoTransition.updateFrame(node: minimizedVideoNode, frame: previewVideoFrame)
                    minimizedVideoNode.updateLayout(size: minimizedVideoNode.frame.size, cornerRadius: interpolate(from: 14.0, to: 24.0, value: self.pictureInPictureTransitionFraction), transition: minimizedVideoTransition)
                }
            } else {
                minimizedVideoNode.frame = fullscreenVideoFrame
                minimizedVideoNode.updateLayout(size: layout.size, cornerRadius: 0.0, transition: minimizedVideoTransition)
            }
            self.animationForExpandedVideoSnapshotView = nil
        }
        
        let keyTextSize = self.keyButtonNode.frame.size
        transition.updateFrame(node: self.keyButtonNode, frame: CGRect(origin: CGPoint(x: layout.size.width - keyTextSize.width - 8.0, y: navigationOffset + 8.0), size: keyTextSize))
        transition.updateAlpha(node: self.keyButtonNode, alpha: overlayAlpha)
        
        if let debugNode = self.debugNode {
            transition.updateFrame(node: debugNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        }
    }
    
    @objc func keyPressed() {
        if self.keyPreviewNode == nil, let keyText = self.keyTextData?.1, let peer = self.peer {
            let keyPreviewNode = CallControllerKeyPreviewNode(keyText: keyText, infoText: self.presentationData.strings.Call_EmojiDescription(peer.compactDisplayTitle).0.replacingOccurrences(of: "%%", with: "%"), dismiss: { [weak self] in
                if let _ = self?.keyPreviewNode {
                    self?.backPressed()
                }
            })
            
            self.containerNode.insertSubnode(keyPreviewNode, belowSubnode: self.statusNode)
            self.keyPreviewNode = keyPreviewNode
            
            if let (validLayout, _) = self.validLayout {
                keyPreviewNode.updateLayout(size: validLayout.size, transition: .immediate)
                
                self.keyButtonNode.isHidden = true
                keyPreviewNode.animateIn(from: self.keyButtonNode.frame, fromNode: self.keyButtonNode)
            }
        }
    }
    
    @objc func backPressed() {
        if let keyPreviewNode = self.keyPreviewNode {
            self.keyPreviewNode = nil
            keyPreviewNode.animateOut(to: self.keyButtonNode.frame, toNode: self.keyButtonNode, completion: { [weak self, weak keyPreviewNode] in
                self?.keyButtonNode.isHidden = false
                keyPreviewNode?.removeFromSupernode()
            })
        } else {
            self.back?()
        }
    }
    
    private var debugTapCounter: (Double, Int) = (0.0, 0)
    
    @objc func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            if !self.pictureInPictureTransitionFraction.isZero {
                if let (layout, navigationHeight) = self.validLayout {
                    self.pictureInPictureTransitionFraction = 0.0
                    
                    self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring))
                }
            } else if let _ = self.keyPreviewNode {
                self.backPressed()
            } else {
                if let expandedVideoNode = self.expandedVideoNode, let minimizedVideoNode = self.minimizedVideoNode {
                    let point = recognizer.location(in: recognizer.view)
                    if minimizedVideoNode.frame.contains(point) {
                        let copyView = minimizedVideoNode.view.snapshotView(afterScreenUpdates: false)
                        copyView?.frame = minimizedVideoNode.frame
                        self.expandedVideoNode = minimizedVideoNode
                        self.minimizedVideoNode = expandedVideoNode
                        if let supernode = expandedVideoNode.supernode {
                            supernode.insertSubnode(expandedVideoNode, aboveSubnode: minimizedVideoNode)
                        }
                        if let (layout, navigationBarHeight) = self.validLayout {
                            self.disableAnimationForExpandedVideoOnce = true
                            self.animationForExpandedVideoSnapshotView = copyView
                            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                        }
                    } else {
                        var updated = false
                        if let callState = self.callState {
                            switch callState.state {
                            case .active, .connecting, .reconnecting:
                                self.isUIHidden = !self.isUIHidden
                                updated = true
                            default:
                                break
                            }
                        }
                        if updated, let (layout, navigationBarHeight) = self.validLayout {
                            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
                        }
                    }
                } else {
                    let point = recognizer.location(in: recognizer.view)
                    if self.statusNode.frame.contains(point) {
                        if self.easyDebugAccess {
                            self.presentDebugNode()
                        } else {
                            let timestamp = CACurrentMediaTime()
                            if self.debugTapCounter.0 < timestamp - 0.75 {
                                self.debugTapCounter.0 = timestamp
                                self.debugTapCounter.1 = 0
                            }
                            
                            if self.debugTapCounter.0 >= timestamp - 0.75 {
                                self.debugTapCounter.0 = timestamp
                                self.debugTapCounter.1 += 1
                            }
                            
                            if self.debugTapCounter.1 >= 10 {
                                self.debugTapCounter.1 = 0
                                
                                self.presentDebugNode()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func presentDebugNode() {
        guard self.debugNode == nil else {
            return
        }
        
        self.forceReportRating = true
        
        let debugNode = CallDebugNode(signal: self.debugInfo)
        debugNode.dismiss = { [weak self] in
            if let strongSelf = self {
                strongSelf.debugNode?.removeFromSupernode()
                strongSelf.debugNode = nil
            }
        }
        self.addSubnode(debugNode)
        self.debugNode = debugNode
        
        if let (layout, navigationBarHeight) = self.validLayout {
            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
        }
    }
    
    private var minimizedVideoInitialPosition: CGPoint?
    private var minimizedVideoDraggingPosition: CGPoint?
    
    private func nodeLocationForPosition(layout: ContainerViewLayout, position: CGPoint, velocity: CGPoint) -> VideoNodeCorner {
        let layoutInsets = UIEdgeInsets()
        var result = CGPoint()
        if position.x < layout.size.width / 2.0 {
            result.x = 0.0
        } else {
            result.x = 1.0
        }
        if position.y < layoutInsets.top + (layout.size.height - layoutInsets.bottom - layoutInsets.top) / 2.0 {
            result.y = 0.0
        } else {
            result.y = 1.0
        }
        
        let currentPosition = result
        
        let angleEpsilon: CGFloat = 30.0
        var shouldHide = false
        
        if (velocity.x * velocity.x + velocity.y * velocity.y) >= 500.0 * 500.0 {
            let x = velocity.x
            let y = velocity.y
            
            var angle = atan2(y, x) * 180.0 / CGFloat.pi * -1.0
            if angle < 0.0 {
                angle += 360.0
            }
            
            if currentPosition.x.isZero && currentPosition.y.isZero {
                if ((angle > 0 && angle < 90 - angleEpsilon) || angle > 360 - angleEpsilon) {
                    result.x = 1.0
                    result.y = 0.0
                } else if (angle > 180 + angleEpsilon && angle < 270 + angleEpsilon) {
                    result.x = 0.0
                    result.y = 1.0
                } else if (angle > 270 + angleEpsilon && angle < 360 - angleEpsilon) {
                    result.x = 1.0
                    result.y = 1.0
                } else {
                    shouldHide = true
                }
            } else if !currentPosition.x.isZero && currentPosition.y.isZero {
                if (angle > 90 + angleEpsilon && angle < 180 + angleEpsilon) {
                    result.x = 0.0
                    result.y = 0.0
                }
                else if (angle > 270 - angleEpsilon && angle < 360 - angleEpsilon) {
                    result.x = 1.0
                    result.y = 1.0
                }
                else if (angle > 180 + angleEpsilon && angle < 270 - angleEpsilon) {
                    result.x = 0.0
                    result.y = 1.0
                }
                else {
                    shouldHide = true
                }
            } else if currentPosition.x.isZero && !currentPosition.y.isZero {
                if (angle > 90 - angleEpsilon && angle < 180 - angleEpsilon) {
                    result.x = 0.0
                    result.y = 0.0
                }
                else if (angle < angleEpsilon || angle > 270 + angleEpsilon) {
                    result.x = 1.0
                    result.y = 1.0
                }
                else if (angle > angleEpsilon && angle < 90 - angleEpsilon) {
                    result.x = 1.0
                    result.y = 0.0
                }
                else if (!shouldHide) {
                    shouldHide = true
                }
            } else if !currentPosition.x.isZero && !currentPosition.y.isZero {
                if (angle > angleEpsilon && angle < 90 + angleEpsilon) {
                    result.x = 1.0
                    result.y = 0.0
                }
                else if (angle > 180 - angleEpsilon && angle < 270 - angleEpsilon) {
                    result.x = 0.0
                    result.y = 1.0
                }
                else if (angle > 90 + angleEpsilon && angle < 180 - angleEpsilon) {
                    result.x = 0.0
                    result.y = 0.0
                }
                else if (!shouldHide) {
                    shouldHide = true
                }
            }
        }
        
        if result.x.isZero {
            if result.y.isZero {
                return .topLeft
            } else {
                return .bottomLeft
            }
        } else {
            if result.y.isZero {
                return .topRight
            } else {
                return .bottomRight
            }
        }
    }
    
    @objc private func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                let location = recognizer.location(in: self.view)
                if self.self.pictureInPictureTransitionFraction.isZero, let _ = self.expandedVideoNode, let minimizedVideoNode = self.minimizedVideoNode, minimizedVideoNode.frame.contains(location) {
                    self.minimizedVideoInitialPosition = minimizedVideoNode.position
                } else {
                    self.minimizedVideoInitialPosition = nil
                    if !self.pictureInPictureTransitionFraction.isZero {
                        self.pictureInPictureGestureState = .dragging(initialPosition: self.containerTransformationNode.position, draggingPosition: self.containerTransformationNode.position)
                    } else {
                        self.pictureInPictureGestureState = .collapsing(didSelectCorner: false)
                    }
                }
            case .changed:
                if let minimizedVideoNode = self.minimizedVideoNode, let minimizedVideoInitialPosition = self.minimizedVideoInitialPosition {
                    let translation = recognizer.translation(in: self.view)
                    let minimizedVideoDraggingPosition = CGPoint(x: minimizedVideoInitialPosition.x + translation.x, y: minimizedVideoInitialPosition.y + translation.y)
                    self.minimizedVideoDraggingPosition = minimizedVideoDraggingPosition
                    minimizedVideoNode.position = minimizedVideoDraggingPosition
                } else {
                    switch self.pictureInPictureGestureState {
                    case .none:
                        let offset = recognizer.translation(in: self.view).y
                        var bounds = self.bounds
                        bounds.origin.y = -offset
                        self.bounds = bounds
                    case let .collapsing(didSelectCorner):
                        if let (layout, navigationHeight) = self.validLayout {
                            let offset = recognizer.translation(in: self.view)
                            if !didSelectCorner {
                                self.pictureInPictureGestureState = .collapsing(didSelectCorner: true)
                                if offset.x < 0.0 {
                                    self.pictureInPictureCorner = .topLeft
                                } else {
                                    self.pictureInPictureCorner = .topRight
                                }
                            }
                            let maxOffset: CGFloat = min(300.0, layout.size.height / 2.0)
                            
                            let offsetTransition = max(0.0, min(1.0, abs(offset.y) / maxOffset))
                            self.pictureInPictureTransitionFraction = offsetTransition
                            switch self.pictureInPictureCorner {
                            case .topRight, .bottomRight:
                                self.pictureInPictureCorner = offset.y < 0.0 ? .topRight : .bottomRight
                            case .topLeft, .bottomLeft:
                                self.pictureInPictureCorner = offset.y < 0.0 ? .topLeft : .bottomLeft
                            }
                            
                            self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .immediate)
                        }
                    case .dragging(let initialPosition, var draggingPosition):
                        let translation = recognizer.translation(in: self.view)
                        draggingPosition.x = initialPosition.x + translation.x
                        draggingPosition.y = initialPosition.y + translation.y
                        self.pictureInPictureGestureState = .dragging(initialPosition: initialPosition, draggingPosition: draggingPosition)
                        self.containerTransformationNode.position = draggingPosition
                    }
                }
            case .cancelled, .ended:
                if let minimizedVideoNode = self.minimizedVideoNode, let _ = self.minimizedVideoInitialPosition, let minimizedVideoDraggingPosition = self.minimizedVideoDraggingPosition {
                    self.minimizedVideoInitialPosition = nil
                    self.minimizedVideoDraggingPosition = nil
                    
                    if let (layout, navigationHeight) = self.validLayout {
                        self.outgoingVideoNodeCorner = self.nodeLocationForPosition(layout: layout, position: minimizedVideoDraggingPosition, velocity: recognizer.velocity(in: self.view))
                        
                        let videoFrame = self.calculatePreviewVideoRect(layout: layout, navigationHeight: navigationHeight)
                        minimizedVideoNode.frame = videoFrame
                        minimizedVideoNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: minimizedVideoDraggingPosition.x - videoFrame.midX, y: minimizedVideoDraggingPosition.y - videoFrame.midY)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, delay: 0.0, initialVelocity: 0.0, damping: 110.0, removeOnCompletion: true, additive: true, completion: nil)
                    }
                } else {
                    switch self.pictureInPictureGestureState {
                    case .none:
                        let velocity = recognizer.velocity(in: self.view).y
                        if abs(velocity) < 100.0 {
                            var bounds = self.bounds
                            let previous = bounds
                            bounds.origin = CGPoint()
                            self.bounds = bounds
                            self.layer.animateBounds(from: previous, to: bounds, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
                        } else {
                            var bounds = self.bounds
                            let previous = bounds
                            bounds.origin = CGPoint(x: 0.0, y: velocity > 0.0 ? -bounds.height: bounds.height)
                            self.bounds = bounds
                            self.layer.animateBounds(from: previous, to: bounds, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeOut.rawValue, completion: { [weak self] _ in
                                self?.dismissedInteractively?()
                            })
                        }
                    case .collapsing:
                        self.pictureInPictureGestureState = .none
                        let velocity = recognizer.velocity(in: self.view).y
                        if abs(velocity) < 100.0 {
                            if let (layout, navigationHeight) = self.validLayout {
                                self.pictureInPictureTransitionFraction = 0.0
                                
                                self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring))
                            }
                        } else {
                            if let (layout, navigationHeight) = self.validLayout {
                                self.pictureInPictureTransitionFraction = 1.0
                                
                                self.containerLayoutUpdated(layout, navigationBarHeight: navigationHeight, transition: .animated(duration: 0.4, curve: .spring))
                            }
                        }
                    case let .dragging(initialPosition, _):
                        self.pictureInPictureGestureState = .none
                        if let (layout, navigationHeight) = self.validLayout {
                            let translation = recognizer.translation(in: self.view)
                            let draggingPosition = CGPoint(x: initialPosition.x + translation.x, y: initialPosition.y + translation.y)
                            self.pictureInPictureCorner = self.nodeLocationForPosition(layout: layout, position: draggingPosition, velocity: recognizer.velocity(in: self.view))
                            
                            let containerFrame = self.calculatePictureInPictureContainerRect(layout: layout, navigationHeight: navigationHeight)
                            self.containerTransformationNode.frame = containerFrame
                            containerTransformationNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: draggingPosition.x - containerFrame.midX, y: draggingPosition.y - containerFrame.midY)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, delay: 0.0, initialVelocity: 0.0, damping: 110.0, removeOnCompletion: true, additive: true, completion: nil)
                        }
                    }
                }
            default:
                break
        }
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if self.containerTransformationNode.frame.contains(point) {
            return self.containerTransformationNode.view.hitTest(self.view.convert(point, to: self.containerTransformationNode.view), with: event)
        }
        return nil
    }
}
