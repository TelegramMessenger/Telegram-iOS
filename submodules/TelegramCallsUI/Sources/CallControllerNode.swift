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

private final class IncomingVideoNode: ASDisplayNode {
    private let videoView: UIView
    private var effectView: UIVisualEffectView?
    private var isBlurred: Bool = false
    
    init(videoView: UIView) {
        self.videoView = videoView
        
        super.init()
        
        self.view.addSubview(self.videoView)
    }
    
    func updateLayout(size: CGSize) {
        self.videoView.frame = CGRect(origin: CGPoint(), size: size)
    }
    
    func updateIsBlurred(isBlurred: Bool) {
        if self.isBlurred == isBlurred {
            return
        }
        self.isBlurred = isBlurred
        
        if isBlurred {
            if self.effectView == nil {
                let effectView = UIVisualEffectView()
                self.effectView = effectView
                effectView.frame = self.videoView.frame
                self.view.addSubview(effectView)
            }
            UIView.animate(withDuration: 0.3, animations: {
                self.effectView?.effect = UIBlurEffect(style: .dark)
            })
        } else if let effectView = self.effectView {
            UIView.animate(withDuration: 0.3, animations: {
                effectView.effect = nil
            })
        }
    }
}

private final class OutgoingVideoNode: ASDisplayNode {
    private let videoTransformContainer: ASDisplayNode
    private let videoView: UIView
    private let buttonNode: HighlightTrackingButtonNode
    
    private var effectView: UIVisualEffectView?
    private var isBlurred: Bool = false
    private var isExpanded: Bool = false
    
    var tapped: (() -> Void)?
    
    init(videoView: UIView) {
        self.videoTransformContainer = ASDisplayNode()
        self.videoTransformContainer.clipsToBounds = true
        self.videoView = videoView
        self.videoView.layer.transform = CATransform3DMakeScale(-1.0, 1.0, 1.0)
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        super.init()
        
        self.videoTransformContainer.view.addSubview(self.videoView)
        self.addSubnode(self.videoTransformContainer)
        //self.addSubnode(self.buttonNode)
        
        self.buttonNode.addTarget(self, action: #selector(self.buttonPressed), forControlEvents: .touchUpInside)
    }
    
    @objc func buttonPressed() {
        self.tapped?()
    }
    
    func updateLayout(size: CGSize, isExpanded: Bool, transition: ContainedViewLayoutTransition) {
        let videoFrame = CGRect(origin: CGPoint(), size: size)
        self.buttonNode.frame = videoFrame
        self.isExpanded = isExpanded
        
        let previousVideoFrame = self.videoTransformContainer.frame
        self.videoTransformContainer.frame = videoFrame
        if transition.isAnimated && !videoFrame.height.isZero && !previousVideoFrame.height.isZero {
            transition.animatePositionAdditive(node: self.videoTransformContainer, offset: CGPoint(x: previousVideoFrame.midX - videoFrame.midX, y: previousVideoFrame.midY - videoFrame.midY))
            transition.animateTransformScale(node: self.videoTransformContainer, from: previousVideoFrame.height / videoFrame.height)
        }
        
        self.videoView.frame = videoFrame
        
        transition.updateCornerRadius(layer: self.videoTransformContainer.layer, cornerRadius: isExpanded ? 0.0 : 16.0)
        if let effectView = self.effectView {
            transition.updateCornerRadius(layer: effectView.layer, cornerRadius: isExpanded ? 0.0 : 16.0)
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
                effectView.layer.cornerRadius = self.isExpanded ? 0.0 : 16.0
                self.effectView = effectView
                effectView.frame = self.videoView.frame
                self.view.addSubview(effectView)
            }
            UIView.animate(withDuration: 0.3, animations: {
                self.effectView?.effect = UIBlurEffect(style: .dark)
            })
        } else if let effectView = self.effectView {
            UIView.animate(withDuration: 0.3, animations: {
                effectView.effect = nil
            })
        }
    }
}

final class CallControllerNode: ASDisplayNode {
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
    
    private let containerNode: ASDisplayNode
    
    private let imageNode: TransformImageNode
    private let dimNode: ASDisplayNode
    private var incomingVideoNode: IncomingVideoNode?
    private var incomingVideoViewRequested: Bool = false
    private var outgoingVideoNode: OutgoingVideoNode?
    private var outgoingVideoViewRequested: Bool = false
    private var outgoingVideoExplicitelyFullscreen: Bool = false
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
    
    private var isUIHidden: Bool = false
    private var isVideoPaused: Bool = false
    
    init(sharedContext: SharedAccountContext, account: Account, presentationData: PresentationData, statusBar: StatusBar, debugInfo: Signal<(String, String), NoError>, shouldStayHiddenUntilConnection: Bool = false, easyDebugAccess: Bool, call: PresentationCall) {
        self.sharedContext = sharedContext
        self.account = account
        self.presentationData = presentationData
        self.statusBar = statusBar
        self.debugInfo = debugInfo
        self.shouldStayHiddenUntilConnection = shouldStayHiddenUntilConnection
        self.easyDebugAccess = easyDebugAccess
        self.call = call
        
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
        
        self.setViewBlock({
            return UITracingLayerView()
        })
        
        self.containerNode.backgroundColor = .black
        
        self.addSubnode(self.containerNode)
        
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
            self?.acceptCall?()
        }
        
        self.buttonsNode.toggleVideo = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.isVideoPaused = !strongSelf.isVideoPaused
            strongSelf.outgoingVideoNode?.updateIsBlurred(isBlurred: strongSelf.isVideoPaused)
            strongSelf.buttonsNode.isCameraPaused = strongSelf.isVideoPaused
            strongSelf.setIsVideoPaused?(strongSelf.isVideoPaused)
            
            if let (layout, navigationBarHeight) = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
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
                self.imageNode.setSignal(chatAvatarGalleryPhoto(account: self.account, representations: representations, autoFetchFullSize: true))
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
                        let incomingVideoNode = IncomingVideoNode(videoView: incomingVideoView)
                        strongSelf.incomingVideoNode = incomingVideoNode
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
        case .active, .activeOutgoing:
            if !self.outgoingVideoViewRequested {
                self.outgoingVideoViewRequested = true
                self.call.makeOutgoingVideoView(completion: { [weak self] outgoingVideoView in
                    guard let strongSelf = self else {
                        return
                    }
                    if let outgoingVideoView = outgoingVideoView {
                        outgoingVideoView.backgroundColor = .black
                        outgoingVideoView.clipsToBounds = true
                        if let audioOutputState = strongSelf.audioOutputState, let currentOutput = audioOutputState.currentOutput {
                            switch currentOutput {
                            case .speaker, .builtin:
                                break
                            default:
                                strongSelf.setCurrentAudioOutput?(.speaker)
                            }
                        }
                        let outgoingVideoNode = OutgoingVideoNode(videoView: outgoingVideoView)
                        strongSelf.outgoingVideoNode = outgoingVideoNode
                        if let incomingVideoNode = strongSelf.incomingVideoNode {
                            strongSelf.containerNode.insertSubnode(outgoingVideoNode, aboveSubnode: incomingVideoNode)
                        } else {
                            strongSelf.containerNode.insertSubnode(outgoingVideoNode, aboveSubnode: strongSelf.dimNode)
                        }
                        if let (layout, navigationBarHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                        }
                        /*outgoingVideoNode.tapped = {
                            guard let strongSelf = self else {
                                return
                            }
                            strongSelf.outgoingVideoExplicitelyFullscreen = !strongSelf.outgoingVideoExplicitelyFullscreen
                            if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.4, curve: .spring))
                            }
                        }*/
                    }
                })
            }
        default:
            break
        }
        
        if let incomingVideoNode = self.incomingVideoNode {
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
        
        switch callState.state {
            case .waiting, .connecting:
                statusValue = .text(self.presentationData.strings.Call_StatusConnecting)
            case let .requesting(ringing):
                if ringing {
                    statusValue = .text(self.presentationData.strings.Call_StatusRinging)
                } else {
                    statusValue = .text(self.presentationData.strings.Call_StatusRequesting)
                }
            case .terminating:
                statusValue = .text(self.presentationData.strings.Call_StatusEnded)
            case let .terminated(_, reason, _):
                if let reason = reason {
                    switch reason {
                        case let .ended(type):
                            switch type {
                                case .busy:
                                    statusValue = .text(self.presentationData.strings.Call_StatusBusy)
                                case .hungUp, .missed:
                                    statusValue = .text(self.presentationData.strings.Call_StatusEnded)
                            }
                        case .error:
                            statusValue = .text(self.presentationData.strings.Call_StatusFailed)
                    }
                } else {
                    statusValue = .text(self.presentationData.strings.Call_StatusEnded)
                }
            case .ringing:
                var text = self.presentationData.strings.Call_StatusIncoming
                if !self.statusNode.subtitle.isEmpty {
                    text += "\n\(self.statusNode.subtitle)"
                }
                statusValue = .text(text)
            case .active(let timestamp, let reception, let keyVisualHash), .reconnecting(let timestamp, let reception, let keyVisualHash):
                let strings = self.presentationData.strings
                var isReconnecting = false
                if case .reconnecting = callState.state {
                    isReconnecting = true
                }
                statusValue = .timer({ value in
                    if isReconnecting {
                        return strings.Call_StatusConnecting
                    } else {
                        return value
                    }
                }, timestamp)
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
                statusReception = reception
        }
        switch callState.state {
            case .terminated, .terminating:
                if !self.statusNode.alpha.isEqual(to: 0.5) {
                    self.statusNode.alpha = 0.5
                    self.buttonsNode.alpha = 0.5
                    self.keyButtonNode.alpha = 0.5
                    self.backButtonArrowNode.alpha = 0.5
                    self.backButtonNode.alpha = 0.5
                    
                    self.statusNode.layer.animateAlpha(from: 1.0, to: 0.5, duration: 0.25)
                    self.buttonsNode.layer.animateAlpha(from: 1.0, to: 0.5, duration: 0.25)
                    self.keyButtonNode.layer.animateAlpha(from: 1.0, to: 0.5, duration: 0.25)
                }
            default:
                if !self.statusNode.alpha.isEqual(to: 1.0) {
                    self.statusNode.alpha = 1.0
                    self.buttonsNode.alpha = 1.0
                    self.keyButtonNode.alpha = 1.0
                    self.backButtonArrowNode.alpha = 1.0
                    self.backButtonNode.alpha = 1.0
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
        case .available:
            mappedVideoState = .available(true)
        case .active:
            mappedVideoState = .active
        case .activeOutgoing:
            mappedVideoState = .active
        }
        
        switch callState.state {
        case .ringing:
            let buttonsMode: CallControllerButtonsMode = .incoming(speakerMode: mode, videoState: mappedVideoState)
            self.buttonsNode.updateMode(strings: self.presentationData.strings, mode: buttonsMode)
            self.buttonsTerminationMode = buttonsMode
        case .waiting, .requesting:
            let buttonsMode: CallControllerButtonsMode = .outgoingRinging(speakerMode: mode, videoState: mappedVideoState)
            self.buttonsNode.updateMode(strings: self.presentationData.strings, mode: buttonsMode)
            self.buttonsTerminationMode = buttonsMode
        case .active, .connecting, .reconnecting:
            let buttonsMode: CallControllerButtonsMode = .active(speakerMode: mode, videoState: mappedVideoState)
            self.buttonsNode.updateMode(strings: self.presentationData.strings, mode: buttonsMode)
            self.buttonsTerminationMode = buttonsMode
        case .terminating, .terminated:
            if let buttonsTerminationMode = self.buttonsTerminationMode {
                self.buttonsNode.updateMode(strings: self.presentationData.strings, mode: buttonsTerminationMode)
            } else {
                self.buttonsNode.updateMode(strings: self.presentationData.strings, mode: .active(speakerMode: mode, videoState: mappedVideoState))
            }
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
    
    private func calculatePreviewVideoRect(layout: ContainerViewLayout, navigationHeight: CGFloat) -> CGRect {
        let buttonsHeight: CGFloat = 190.0
        let buttonsOffset: CGFloat
        if layout.size.width.isEqual(to: 320.0) {
            if layout.size.height.isEqual(to: 480.0) {
                buttonsOffset = 60.0
            } else {
                buttonsOffset = 73.0
            }
        } else {
            buttonsOffset = 83.0
        }
        
        let buttonsOriginY: CGFloat
        if self.isUIHidden {
            buttonsOriginY = layout.size.height + 40.0 - 80.0
        } else {
            buttonsOriginY = layout.size.height - (buttonsOffset - 40.0) - buttonsHeight - layout.intrinsicInsets.bottom
        }
        
        let previewVideoSize = layout.size.aspectFitted(CGSize(width: 200.0, height: 200.0))
        let previewVideoY: CGFloat
        let previewVideoX: CGFloat
        
        switch self.outgoingVideoNodeCorner {
        case .topLeft:
            previewVideoX = 20.0
            if self.isUIHidden {
                previewVideoY = layout.insets(options: .statusBar).top + 8.0
            } else {
                previewVideoY = layout.insets(options: .statusBar).top + 44.0 + 8.0
            }
        case .topRight:
            previewVideoX = layout.size.width - previewVideoSize.width - 20.0
            if self.isUIHidden {
                previewVideoY = layout.insets(options: .statusBar).top + 8.0
            } else {
                previewVideoY = layout.insets(options: .statusBar).top + 44.0 + 8.0
            }
        case .bottomLeft:
            previewVideoX = 20.0
            if self.isUIHidden {
                previewVideoY = layout.size.height - layout.intrinsicInsets.bottom - 8.0 - previewVideoSize.height
            } else {
                previewVideoY = buttonsOriginY + 100.0 - previewVideoSize.height
            }
        case .bottomRight:
            previewVideoX = layout.size.width - previewVideoSize.width - 20.0
            if self.isUIHidden {
                previewVideoY = layout.size.height - layout.intrinsicInsets.bottom - 8.0 - previewVideoSize.height
            } else {
                previewVideoY = buttonsOriginY + 100.0 - previewVideoSize.height
            }
        }
        
        return CGRect(origin: CGPoint(x: previewVideoX, y: previewVideoY), size: previewVideoSize)
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        self.validLayout = (layout, navigationBarHeight)
        
        let overlayAlpha: CGFloat = self.isUIHidden ? 0.0 : 1.0
        
        transition.updateFrame(node: self.containerNode, frame: CGRect(origin: CGPoint(), size: layout.size))
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
        
        let buttonsHeight: CGFloat = 190.0
        let buttonsOffset: CGFloat
        if layout.size.width.isEqual(to: 320.0) {
            if layout.size.height.isEqual(to: 480.0) {
                buttonsOffset = 60.0
            } else {
                buttonsOffset = 73.0
            }
        } else {
            buttonsOffset = 83.0
        }
        
        let statusHeight = self.statusNode.updateLayout(constrainedWidth: layout.size.width, transition: transition)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: 0.0, y: statusOffset), size: CGSize(width: layout.size.width, height: statusHeight)))
        transition.updateAlpha(node: self.statusNode, alpha: overlayAlpha)
        
        let videoPausedSize = self.videoPausedNode.updateLayout(CGSize(width: layout.size.width - 16.0, height: 100.0))
        transition.updateFrame(node: self.videoPausedNode, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - videoPausedSize.width) / 2.0), y: floor((layout.size.height - videoPausedSize.height) / 2.0)), size: videoPausedSize))
        
        self.buttonsNode.updateLayout(strings: self.presentationData.strings, constrainedWidth: layout.size.width, transition: transition)
        let buttonsOriginY: CGFloat
        if self.isUIHidden {
            buttonsOriginY = layout.size.height + 40.0 - 80.0
        } else {
            buttonsOriginY = layout.size.height - (buttonsOffset - 40.0) - buttonsHeight - layout.intrinsicInsets.bottom
        }
        transition.updateFrame(node: self.buttonsNode, frame: CGRect(origin: CGPoint(x: 0.0, y: buttonsOriginY), size: CGSize(width: layout.size.width, height: buttonsHeight)))
        transition.updateAlpha(node: self.buttonsNode, alpha: overlayAlpha)
        
        let fullscreenVideoFrame = CGRect(origin: CGPoint(), size: layout.size)
        
        let previewVideoFrame = self.calculatePreviewVideoRect(layout: layout, navigationHeight: navigationBarHeight)
        
        if let incomingVideoNode = self.incomingVideoNode {
            var incomingVideoTransition = transition
            if incomingVideoNode.frame.isEmpty {
                incomingVideoTransition = .immediate
            }
            if self.outgoingVideoExplicitelyFullscreen {
                incomingVideoTransition.updateFrame(node: incomingVideoNode, frame: previewVideoFrame)
            } else {
                incomingVideoTransition.updateFrame(node: incomingVideoNode, frame: fullscreenVideoFrame)
            }
            incomingVideoNode.updateLayout(size: incomingVideoNode.frame.size)
        }
        if let outgoingVideoNode = self.outgoingVideoNode {
            var outgoingVideoTransition = transition
            if outgoingVideoNode.frame.isEmpty {
                outgoingVideoTransition = .immediate
            }
            if self.incomingVideoNode == nil {
                outgoingVideoNode.frame = fullscreenVideoFrame
                outgoingVideoNode.updateLayout(size: layout.size, isExpanded: true, transition: outgoingVideoTransition)
            } else {
                if self.minimizedVideoDraggingPosition == nil {
                    if self.outgoingVideoExplicitelyFullscreen {
                        outgoingVideoTransition.updateFrame(node: outgoingVideoNode, frame: fullscreenVideoFrame)
                    } else {
                        outgoingVideoTransition.updateFrame(node: outgoingVideoNode, frame: previewVideoFrame)
                    }
                    outgoingVideoNode.updateLayout(size: outgoingVideoNode.frame.size, isExpanded: self.outgoingVideoExplicitelyFullscreen, transition: outgoingVideoTransition)
                }
            }
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
            if let _ = self.keyPreviewNode {
                self.backPressed()
            } else {
                if self.incomingVideoNode != nil || self.outgoingVideoNode != nil {
                    self.isUIHidden = !self.isUIHidden
                    if let (layout, navigationBarHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.3, curve: .easeInOut))
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
                //let translation = recognizer.translation(in: self.view)
                //location.x += translation.x
                //location.y += translation.y
                if let _ = self.incomingVideoNode, let outgoingVideoNode = self.outgoingVideoNode, outgoingVideoNode.frame.contains(location) {
                    self.minimizedVideoInitialPosition = outgoingVideoNode.position
                } else {
                    self.minimizedVideoInitialPosition = nil
                }
            case .changed:
                if let outgoingVideoNode = self.outgoingVideoNode, let minimizedVideoInitialPosition = self.minimizedVideoInitialPosition {
                    let translation = recognizer.translation(in: self.view)
                    let minimizedVideoDraggingPosition = CGPoint(x: minimizedVideoInitialPosition.x + translation.x, y: minimizedVideoInitialPosition.y + translation.y)
                    self.minimizedVideoDraggingPosition = minimizedVideoDraggingPosition
                    outgoingVideoNode.position = minimizedVideoDraggingPosition
                } else {
                    let offset = recognizer.translation(in: self.view).y
                    var bounds = self.bounds
                    bounds.origin.y = -offset
                    self.bounds = bounds
                }
            case .cancelled, .ended:
                if let outgoingVideoNode = self.outgoingVideoNode, let _ = self.minimizedVideoInitialPosition, let minimizedVideoDraggingPosition = self.minimizedVideoDraggingPosition {
                    self.minimizedVideoInitialPosition = nil
                    self.minimizedVideoDraggingPosition = nil
                    
                    if let (layout, navigationHeight) = self.validLayout {
                        self.outgoingVideoNodeCorner = self.nodeLocationForPosition(layout: layout, position: minimizedVideoDraggingPosition, velocity: recognizer.velocity(in: self.view))
                        
                        let videoFrame = self.calculatePreviewVideoRect(layout: layout, navigationHeight: navigationHeight)
                        outgoingVideoNode.frame = videoFrame
                        outgoingVideoNode.layer.animateSpring(from: NSValue(cgPoint: CGPoint(x: minimizedVideoDraggingPosition.x - videoFrame.midX, y: minimizedVideoDraggingPosition.y - videoFrame.midY)), to: NSValue(cgPoint: CGPoint()), keyPath: "position", duration: 0.5, delay: 0.0, initialVelocity: 0.0, damping: 110.0, removeOnCompletion: true, additive: true, completion: nil)
                    }
                } else {
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
                }
            default:
                break
        }
    }
}
