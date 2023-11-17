import Foundation
import UIKit
import Display
import MetalEngine
import ComponentFlow
import SwiftSignalKit

public final class PrivateCallScreen: OverlayMaskContainerView {
    public struct State: Equatable {
        public struct SignalInfo: Equatable {
            public var quality: Double
            
            public init(quality: Double) {
                self.quality = quality
            }
        }
        
        public struct ActiveState: Equatable {
            public var startTime: Double
            public var signalInfo: SignalInfo
            public var emojiKey: [String]
            
            public init(startTime: Double, signalInfo: SignalInfo, emojiKey: [String]) {
                self.startTime = startTime
                self.signalInfo = signalInfo
                self.emojiKey = emojiKey
            }
        }
        
        public struct TerminatedState: Equatable {
            public var duration: Double
            
            public init(duration: Double) {
                self.duration = duration
            }
        }
        
        public enum LifecycleState: Equatable {
            case connecting
            case ringing
            case exchangingKeys
            case active(ActiveState)
            case terminated(TerminatedState)
        }
        
        public enum AudioOutput: Equatable {
            case internalSpeaker
            case speaker
        }
        
        public var lifecycleState: LifecycleState
        public var name: String
        public var avatarImage: UIImage?
        public var audioOutput: AudioOutput
        public var isMicrophoneMuted: Bool
        public var localVideo: VideoSource?
        public var remoteVideo: VideoSource?
        
        public init(
            lifecycleState: LifecycleState,
            name: String,
            avatarImage: UIImage?,
            audioOutput: AudioOutput,
            isMicrophoneMuted: Bool,
            localVideo: VideoSource?,
            remoteVideo: VideoSource?
        ) {
            self.lifecycleState = lifecycleState
            self.name = name
            self.avatarImage = avatarImage
            self.audioOutput = audioOutput
            self.isMicrophoneMuted = isMicrophoneMuted
            self.localVideo = localVideo
            self.remoteVideo = remoteVideo
        }
        
        public static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.lifecycleState != rhs.lifecycleState {
                return false
            }
            if lhs.name != rhs.name {
                return false
            }
            if lhs.avatarImage != rhs.avatarImage {
                return false
            }
            if lhs.audioOutput != rhs.audioOutput {
                return false
            }
            if lhs.isMicrophoneMuted != rhs.isMicrophoneMuted {
                return false
            }
            if lhs.localVideo !== rhs.localVideo {
                return false
            }
            if lhs.remoteVideo !== rhs.remoteVideo {
                return false
            }
            return true
        }
    }
    
    private struct Params: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
        var screenCornerRadius: CGFloat
        var state: State
        
        init(size: CGSize, insets: UIEdgeInsets, screenCornerRadius: CGFloat, state: State) {
            self.size = size
            self.insets = insets
            self.screenCornerRadius = screenCornerRadius
            self.state = state
        }
    }
    
    private var params: Params?
    
    private let backgroundLayer: CallBackgroundLayer
    private let overlayContentsView: UIView
    private let buttonGroupView: ButtonGroupView
    private let blobLayer: CallBlobsLayer
    private let avatarLayer: AvatarLayer
    private let titleView: TextView
    
    private var statusView: StatusView
    private var weakSignalView: WeakSignalView?
    
    private var emojiView: KeyEmojiView?
    
    private var localVideoContainerView: VideoContainerView?
    private var remoteVideoContainerView: VideoContainerView?
    
    private var activeRemoteVideoSource: VideoSource?
    private var waitingForFirstRemoteVideoFrameDisposable: Disposable?
    
    private var activeLocalVideoSource: VideoSource?
    private var waitingForFirstLocalVideoFrameDisposable: Disposable?
    
    private var processedInitialAudioLevelBump: Bool = false
    private var audioLevelBump: Float = 0.0
    
    private var targetAudioLevel: Float = 0.0
    private var audioLevel: Float = 0.0
    private var audioLevelUpdateSubscription: SharedDisplayLinkDriver.Link?
    
    public var speakerAction: (() -> Void)?
    public var flipCameraAction: (() -> Void)?
    public var videoAction: (() -> Void)?
    public var microhoneMuteAction: (() -> Void)?
    public var endCallAction: (() -> Void)?
    
    public override init(frame: CGRect) {
        self.overlayContentsView = UIView()
        self.overlayContentsView.isUserInteractionEnabled = false
        
        self.backgroundLayer = CallBackgroundLayer()
        
        self.buttonGroupView = ButtonGroupView()
        
        self.blobLayer = CallBlobsLayer()
        self.avatarLayer = AvatarLayer()
        
        self.titleView = TextView()
        self.statusView = StatusView()
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.backgroundLayer)
        self.overlayContentsView.layer.addSublayer(self.backgroundLayer.blurredLayer)
        
        self.layer.addSublayer(self.blobLayer)
        self.layer.addSublayer(self.avatarLayer)
        
        self.overlayContentsView.mask = self.maskContents
        self.addSubview(self.overlayContentsView)
        
        self.addSubview(self.buttonGroupView)
        
        self.addSubview(self.titleView)
        
        self.addSubview(self.statusView)
        self.statusView.requestLayout = { [weak self] in
            self?.update(transition: .immediate)
        }
        
        (self.layer as? SimpleLayer)?.didEnterHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.audioLevelUpdateSubscription = SharedDisplayLinkDriver.shared.add { [weak self] _ in
                guard let self else {
                    return
                }
                self.attenuateAudioLevelStep()
            }
        }
        (self.layer as? SimpleLayer)?.didExitHierarchy = { [weak self] in
            guard let self else {
                return
            }
            self.audioLevelUpdateSubscription = nil
        }
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    deinit {
        self.waitingForFirstRemoteVideoFrameDisposable?.dispose()
        self.waitingForFirstLocalVideoFrameDisposable?.dispose()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        
        return result
    }
    
    public func addIncomingAudioLevel(value: Float) {
        self.targetAudioLevel = value
    }
    
    private func attenuateAudioLevelStep() {
        self.audioLevel = self.audioLevel * 0.8 + (self.targetAudioLevel + self.audioLevelBump) * 0.2
        if self.audioLevel <= 0.01 {
            self.audioLevel = 0.0
        }
        self.updateAudioLevel()
    }
    
    private func updateAudioLevel() {
        if self.activeRemoteVideoSource == nil && self.activeLocalVideoSource == nil {
            let additionalAvatarScale = CGFloat(max(0.0, min(self.audioLevel, 5.0)) * 0.05)
            self.avatarLayer.transform = CATransform3DMakeScale(1.0 + additionalAvatarScale, 1.0 + additionalAvatarScale, 1.0)
            
            if let params = self.params, case .terminated = params.state.lifecycleState {
            } else {
                let blobAmplificationFactor: CGFloat = 2.0
                self.blobLayer.transform = CATransform3DMakeScale(1.0 + additionalAvatarScale * blobAmplificationFactor, 1.0 + additionalAvatarScale * blobAmplificationFactor, 1.0)
            }
        }
    }
    
    public func update(size: CGSize, insets: UIEdgeInsets, screenCornerRadius: CGFloat, state: State, transition: Transition) {
        let params = Params(size: size, insets: insets, screenCornerRadius: screenCornerRadius, state: state)
        if self.params == params {
            return
        }
        
        if self.params?.state.remoteVideo !== params.state.remoteVideo {
            self.waitingForFirstRemoteVideoFrameDisposable?.dispose()
            
            if let remoteVideo = params.state.remoteVideo {
                if remoteVideo.currentOutput != nil {
                    self.activeRemoteVideoSource = remoteVideo
                } else {
                    let firstVideoFrameSignal = Signal<Never, NoError> { subscriber in
                        remoteVideo.updated = { [weak remoteVideo] in
                            guard let remoteVideo else {
                                subscriber.putCompletion()
                                return
                            }
                            if remoteVideo.currentOutput != nil {
                                subscriber.putCompletion()
                            }
                        }
                        
                        return EmptyDisposable
                    }
                    var shouldUpdate = false
                    self.waitingForFirstRemoteVideoFrameDisposable = (firstVideoFrameSignal
                    |> timeout(4.0, queue: .mainQueue(), alternate: .complete())
                    |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.activeRemoteVideoSource = remoteVideo
                        if shouldUpdate {
                            self.update(transition: .spring(duration: 0.3))
                        }
                    })
                    shouldUpdate = true
                }
            } else {
                self.activeRemoteVideoSource = nil
            }
        }
        if self.params?.state.localVideo !== params.state.localVideo {
            self.waitingForFirstLocalVideoFrameDisposable?.dispose()
            
            if let localVideo = params.state.localVideo {
                if localVideo.currentOutput != nil {
                    self.activeLocalVideoSource = localVideo
                } else {
                    let firstVideoFrameSignal = Signal<Never, NoError> { subscriber in
                        localVideo.updated = { [weak localVideo] in
                            guard let localVideo else {
                                subscriber.putCompletion()
                                return
                            }
                            if localVideo.currentOutput != nil {
                                subscriber.putCompletion()
                            }
                        }
                        
                        return EmptyDisposable
                    }
                    var shouldUpdate = false
                    self.waitingForFirstLocalVideoFrameDisposable = (firstVideoFrameSignal
                    |> timeout(4.0, queue: .mainQueue(), alternate: .complete())
                    |> deliverOnMainQueue).startStrict(completed: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.activeLocalVideoSource = localVideo
                        if shouldUpdate {
                            self.update(transition: .spring(duration: 0.3))
                        }
                    })
                    shouldUpdate = true
                }
            } else {
                self.activeLocalVideoSource = nil
            }
        }
        
        self.params = params
        self.updateInternal(params: params, transition: transition)
    }
    
    private func update(transition: Transition) {
        guard let params = self.params else {
            return
        }
        self.updateInternal(params: params, transition: transition)
    }
    
    private func updateInternal(params: Params, transition: Transition) {
        let backgroundFrame = CGRect(origin: CGPoint(), size: params.size)
        
        let aspect: CGFloat = params.size.width / params.size.height
        let sizeNorm: CGFloat = 64.0
        let renderingSize = CGSize(width: floor(sizeNorm * aspect), height: sizeNorm)
        let edgeSize: Int = 2
        
        let primaryVideoSource: VideoSource?
        let secondaryVideoSource: VideoSource?
        if let activeRemoteVideoSource = self.activeRemoteVideoSource, let activeLocalVideoSource = self.activeLocalVideoSource {
            primaryVideoSource = activeRemoteVideoSource
            secondaryVideoSource = activeLocalVideoSource
        } else if let activeRemoteVideoSource = self.activeRemoteVideoSource {
            primaryVideoSource = activeRemoteVideoSource
            secondaryVideoSource = nil
        } else if let activeLocalVideoSource = self.activeLocalVideoSource {
            primaryVideoSource = activeLocalVideoSource
            secondaryVideoSource = nil
        } else {
            primaryVideoSource = nil
            secondaryVideoSource = nil
        }
        
        let havePrimaryVideo = self.activeRemoteVideoSource != nil || self.activeLocalVideoSource != nil
        
        let visualBackgroundFrame = backgroundFrame.insetBy(dx: -CGFloat(edgeSize) / renderingSize.width * backgroundFrame.width, dy: -CGFloat(edgeSize) / renderingSize.height * backgroundFrame.height)
        
        self.backgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(renderingSize.width) + edgeSize * 2, height: Int(renderingSize.height) + edgeSize * 2))
        transition.setFrame(layer: self.backgroundLayer, frame: visualBackgroundFrame)
        transition.setFrame(layer: self.backgroundLayer.blurredLayer, frame: visualBackgroundFrame)
        
        let backgroundStateIndex: Int
        switch params.state.lifecycleState {
        case .connecting:
            backgroundStateIndex = 0
        case .ringing:
            backgroundStateIndex = 0
        case .exchangingKeys:
            backgroundStateIndex = 0
        case let .active(activeState):
            if activeState.signalInfo.quality <= 0.2 {
                backgroundStateIndex = 2
            } else {
                backgroundStateIndex = 1
            }
        case .terminated:
            backgroundStateIndex = 0
        }
        self.backgroundLayer.update(stateIndex: backgroundStateIndex, transition: transition)
        
        transition.setFrame(view: self.buttonGroupView, frame: CGRect(origin: CGPoint(), size: params.size))
        
        var buttons: [ButtonGroupView.Button] = [
            ButtonGroupView.Button(content: .video(isActive: params.state.localVideo != nil), action: { [weak self] in
                guard let self else {
                    return
                }
                self.videoAction?()
            }),
            ButtonGroupView.Button(content: .microphone(isMuted: params.state.isMicrophoneMuted), action: { [weak self] in
                guard let self else {
                    return
                }
                self.microhoneMuteAction?()
            }),
            ButtonGroupView.Button(content: .end, action: { [weak self] in
                guard let self else {
                    return
                }
                self.endCallAction?()
            })
        ]
        if self.activeLocalVideoSource != nil {
            buttons.insert(ButtonGroupView.Button(content: .flipCamera, action: { [weak self] in
                guard let self else {
                    return
                }
                self.flipCameraAction?()
            }), at: 0)
        } else {
            buttons.insert(ButtonGroupView.Button(content: .speaker(isActive: params.state.audioOutput != .internalSpeaker), action: { [weak self] in
                guard let self else {
                    return
                }
                self.speakerAction?()
            }), at: 0)
        }
        self.buttonGroupView.update(size: params.size, buttons: buttons, transition: transition)
        
        if case let .active(activeState) = params.state.lifecycleState {
            let emojiView: KeyEmojiView
            var emojiTransition = transition
            if let current = self.emojiView {
                emojiView = current
            } else {
                emojiTransition = transition.withAnimation(.none)
                emojiView = KeyEmojiView(emoji: activeState.emojiKey)
                self.emojiView = emojiView
            }
            if emojiView.superview == nil {
                self.addSubview(emojiView)
                if !transition.animation.isImmediate {
                    emojiView.animateIn()
                }
            }
            emojiTransition.setFrame(view: emojiView, frame: CGRect(origin: CGPoint(x: params.size.width - params.insets.right - 12.0 - emojiView.size.width, y: params.insets.top + 27.0), size: emojiView.size))
        } else {
            if let emojiView = self.emojiView {
                self.emojiView = nil
                transition.setAlpha(view: emojiView, alpha: 0.0, completion: { [weak emojiView] _ in
                    emojiView?.removeFromSuperview()
                })
            }
        }
        
        let collapsedAvatarSize: CGFloat = 136.0
        let blobSize: CGFloat = collapsedAvatarSize + 40.0
        
        let collapsedAvatarFrame = CGRect(origin: CGPoint(x: floor((params.size.width - collapsedAvatarSize) * 0.5), y: 222.0), size: CGSize(width: collapsedAvatarSize, height: collapsedAvatarSize))
        let expandedAvatarFrame = CGRect(origin: CGPoint(), size: params.size)
        let expandedVideoFrame = CGRect(origin: CGPoint(), size: params.size)
        let avatarFrame = havePrimaryVideo ? expandedAvatarFrame : collapsedAvatarFrame
        let avatarCornerRadius = havePrimaryVideo ? params.screenCornerRadius : collapsedAvatarSize * 0.5
        
        let minimizedVideoInsets = UIEdgeInsets(top: 124.0, left: 12.0, bottom: 178.0, right: 12.0)
        
        if let primaryVideoSource {
            let remoteVideoContainerView: VideoContainerView
            if let current = self.remoteVideoContainerView {
                remoteVideoContainerView = current
            } else {
                remoteVideoContainerView = VideoContainerView(frame: CGRect())
                self.remoteVideoContainerView = remoteVideoContainerView
                self.insertSubview(remoteVideoContainerView, belowSubview: self.overlayContentsView)
                self.overlayContentsView.layer.addSublayer(remoteVideoContainerView.blurredContainerLayer)
                
                remoteVideoContainerView.layer.position = self.avatarLayer.position
                remoteVideoContainerView.layer.bounds = self.avatarLayer.bounds
                remoteVideoContainerView.alpha = 0.0
                remoteVideoContainerView.blurredContainerLayer.position = self.avatarLayer.position
                remoteVideoContainerView.blurredContainerLayer.bounds = self.avatarLayer.bounds
                remoteVideoContainerView.blurredContainerLayer.opacity = 0.0
                remoteVideoContainerView.update(size: self.avatarLayer.bounds.size, insets: minimizedVideoInsets, cornerRadius: self.avatarLayer.params?.cornerRadius ?? 0.0, isMinimized: false, isAnimatingOut: false, transition: .immediate)
            }
            
            if remoteVideoContainerView.video !== primaryVideoSource {
                remoteVideoContainerView.video = primaryVideoSource
            }
            
            transition.setPosition(view: remoteVideoContainerView, position: expandedVideoFrame.center)
            transition.setBounds(view: remoteVideoContainerView, bounds: CGRect(origin: CGPoint(), size: expandedVideoFrame.size))
            transition.setAlpha(view: remoteVideoContainerView, alpha: 1.0)
            transition.setPosition(layer: remoteVideoContainerView.blurredContainerLayer, position: expandedVideoFrame.center)
            transition.setBounds(layer: remoteVideoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: expandedVideoFrame.size))
            transition.setAlpha(layer: remoteVideoContainerView.blurredContainerLayer, alpha: 1.0)
            remoteVideoContainerView.update(size: expandedVideoFrame.size, insets: minimizedVideoInsets, cornerRadius: params.screenCornerRadius, isMinimized: false, isAnimatingOut: false, transition: transition)
        } else {
            if let remoteVideoContainerView = self.remoteVideoContainerView {
                remoteVideoContainerView.update(size: avatarFrame.size, insets: minimizedVideoInsets, cornerRadius: avatarCornerRadius, isMinimized: false, isAnimatingOut: true, transition: transition)
                transition.setPosition(layer: remoteVideoContainerView.blurredContainerLayer, position: avatarFrame.center)
                transition.setBounds(layer: remoteVideoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                transition.setAlpha(layer: remoteVideoContainerView.blurredContainerLayer, alpha: 0.0)
                transition.setPosition(view: remoteVideoContainerView, position: avatarFrame.center)
                transition.setBounds(view: remoteVideoContainerView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                if remoteVideoContainerView.alpha != 0.0 {
                    transition.setAlpha(view: remoteVideoContainerView, alpha: 0.0, completion: { [weak self, weak remoteVideoContainerView] completed in
                        guard let self, let remoteVideoContainerView, completed else {
                            return
                        }
                        remoteVideoContainerView.removeFromSuperview()
                        remoteVideoContainerView.blurredContainerLayer.removeFromSuperlayer()
                        if self.remoteVideoContainerView === remoteVideoContainerView {
                            self.remoteVideoContainerView = nil
                        }
                    })
                }
            }
        }
        
        if let secondaryVideoSource {
            let localVideoContainerView: VideoContainerView
            if let current = self.localVideoContainerView {
                localVideoContainerView = current
            } else {
                localVideoContainerView = VideoContainerView(frame: CGRect())
                self.localVideoContainerView = localVideoContainerView
                self.insertSubview(localVideoContainerView, belowSubview: self.overlayContentsView)
                self.overlayContentsView.layer.addSublayer(localVideoContainerView.blurredContainerLayer)
                
                localVideoContainerView.layer.position = self.avatarLayer.position
                localVideoContainerView.layer.bounds = self.avatarLayer.bounds
                localVideoContainerView.alpha = 0.0
                localVideoContainerView.blurredContainerLayer.position = self.avatarLayer.position
                localVideoContainerView.blurredContainerLayer.bounds = self.avatarLayer.bounds
                localVideoContainerView.blurredContainerLayer.opacity = 0.0
                localVideoContainerView.update(size: self.avatarLayer.bounds.size, insets: minimizedVideoInsets, cornerRadius: self.avatarLayer.params?.cornerRadius ?? 0.0, isMinimized: true, isAnimatingOut: false, transition: .immediate)
            }
            
            if localVideoContainerView.video !== secondaryVideoSource {
                localVideoContainerView.video = secondaryVideoSource
            }
            
            transition.setPosition(view: localVideoContainerView, position: expandedVideoFrame.center)
            transition.setBounds(view: localVideoContainerView, bounds: CGRect(origin: CGPoint(), size: expandedVideoFrame.size))
            transition.setAlpha(view: localVideoContainerView, alpha: 1.0)
            transition.setPosition(layer: localVideoContainerView.blurredContainerLayer, position: expandedVideoFrame.center)
            transition.setBounds(layer: localVideoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: expandedVideoFrame.size))
            transition.setAlpha(layer: localVideoContainerView.blurredContainerLayer, alpha: 1.0)
            localVideoContainerView.update(size: expandedVideoFrame.size, insets: minimizedVideoInsets, cornerRadius: params.screenCornerRadius, isMinimized: true, isAnimatingOut: false, transition: transition)
        } else {
            if let localVideoContainerView = self.localVideoContainerView {
                localVideoContainerView.update(size: avatarFrame.size, insets: minimizedVideoInsets, cornerRadius: avatarCornerRadius, isMinimized: false, isAnimatingOut: true, transition: transition)
                transition.setPosition(layer: localVideoContainerView.blurredContainerLayer, position: avatarFrame.center)
                transition.setBounds(layer: localVideoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                transition.setAlpha(layer: localVideoContainerView.blurredContainerLayer, alpha: 0.0)
                transition.setPosition(view: localVideoContainerView, position: avatarFrame.center)
                transition.setBounds(view: localVideoContainerView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                if localVideoContainerView.alpha != 0.0 {
                    transition.setAlpha(view: localVideoContainerView, alpha: 0.0, completion: { [weak self, weak localVideoContainerView] completed in
                        guard let self, let localVideoContainerView, completed else {
                            return
                        }
                        localVideoContainerView.removeFromSuperview()
                        localVideoContainerView.blurredContainerLayer.removeFromSuperlayer()
                        if self.localVideoContainerView === localVideoContainerView {
                            self.localVideoContainerView = nil
                        }
                    })
                }
            }
        }
        
        if self.avatarLayer.image !== params.state.avatarImage {
            self.avatarLayer.image = params.state.avatarImage
        }
        transition.setPosition(layer: self.avatarLayer, position: avatarFrame.center)
        transition.setBounds(layer: self.avatarLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
        self.avatarLayer.update(size: collapsedAvatarFrame.size, isExpanded:havePrimaryVideo, cornerRadius: avatarCornerRadius, transition: transition)
        
        let blobFrame = CGRect(origin: CGPoint(x: floor(avatarFrame.midX - blobSize * 0.5), y: floor(avatarFrame.midY - blobSize * 0.5)), size: CGSize(width: blobSize, height: blobSize))
        transition.setPosition(layer: self.blobLayer, position: CGPoint(x: blobFrame.midX, y: blobFrame.midY))
        transition.setBounds(layer: self.blobLayer, bounds: CGRect(origin: CGPoint(), size: blobFrame.size))
        
        let titleString: String
        switch params.state.lifecycleState {
        case .terminated:
            titleString = "Call Ended"
            if !transition.animation.isImmediate {
                transition.withAnimation(.curve(duration: 0.3, curve: .easeInOut)).setScale(layer: self.blobLayer, scale: 0.3)
            } else {
                transition.setScale(layer: self.blobLayer, scale: 0.3)
            }
            transition.setAlpha(layer: self.blobLayer, alpha: 0.0)
        default:
            titleString = params.state.name
            transition.setAlpha(layer: self.blobLayer, alpha: 1.0)
        }
        
        let titleSize = self.titleView.update(
            string: titleString,
            fontSize: !havePrimaryVideo ? 28.0 : 17.0,
            fontWeight: !havePrimaryVideo ? 0.0 : 0.25,
            color: .white,
            constrainedWidth: params.size.width - 16.0 * 2.0,
            transition: transition
        )
        let titleFrame = CGRect(
            origin: CGPoint(
                x: (params.size.width - titleSize.width) * 0.5,
                y: !havePrimaryVideo ? collapsedAvatarFrame.maxY + 39.0 : params.insets.top + 17.0
            ),
            size: titleSize
        )
        transition.setFrame(view: self.titleView, frame: titleFrame)
        
        let statusState: StatusView.State
        switch params.state.lifecycleState {
        case .connecting:
            statusState = .waiting(.requesting)
        case .ringing:
            statusState = .waiting(.ringing)
        case .exchangingKeys:
            statusState = .waiting(.generatingKeys)
        case let .active(activeState):
            statusState = .active(StatusView.ActiveState(startTimestamp: activeState.startTime, signalStrength: activeState.signalInfo.quality))
            
            if !self.processedInitialAudioLevelBump {
                self.processedInitialAudioLevelBump = true
                self.audioLevelBump = 2.0
                DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.2, execute: { [weak self] in
                    guard let self else {
                        return
                    }
                    self.audioLevelBump = 0.0
                })
            }
        case let .terminated(terminatedState):
            self.processedInitialAudioLevelBump = false
            statusState = .terminated(StatusView.TerminatedState(duration: terminatedState.duration))
        }
        
        if let previousState = self.statusView.state, previousState.key != statusState.key {
            let previousStatusView = self.statusView
            if !transition.animation.isImmediate {
                transition.setPosition(view: previousStatusView, position: CGPoint(x: previousStatusView.center.x, y: previousStatusView.center.y - 5.0))
                transition.setScale(view: previousStatusView, scale: 0.5)
                Transition.easeInOut(duration: 0.1).setAlpha(view: previousStatusView, alpha: 0.0, completion: { [weak previousStatusView] _ in
                    previousStatusView?.removeFromSuperview()
                })
            } else {
                previousStatusView.removeFromSuperview()
            }
                
            self.statusView = StatusView()
            self.insertSubview(self.statusView, aboveSubview: previousStatusView)
            self.statusView.requestLayout = { [weak self] in
                self?.update(transition: .immediate)
            }
        }
        
        let statusSize = self.statusView.update(state: statusState, transition: .immediate)
        let statusFrame = CGRect(
            origin: CGPoint(
                x: (params.size.width - statusSize.width) * 0.5,
                y: titleFrame.maxY + (havePrimaryVideo ? 0.0 : 4.0)
            ),
            size: statusSize
        )
        if self.statusView.bounds.isEmpty {
            self.statusView.frame = statusFrame
            
            if !transition.animation.isImmediate {
                transition.animatePosition(view: self.statusView, from: CGPoint(x: 0.0, y: 5.0), to: CGPoint(), additive: true)
                transition.animateScale(view: self.statusView, from: 0.5, to: 1.0)
                Transition.easeInOut(duration: 0.15).animateAlpha(view: self.statusView, from: 0.0, to: 1.0)
            }
        } else {
            transition.setFrame(view: self.statusView, frame: statusFrame)
        }
        
        if case let .active(activeState) = params.state.lifecycleState, activeState.signalInfo.quality <= 0.2 {
            let weakSignalView: WeakSignalView
            if let current = self.weakSignalView {
                weakSignalView = current
            } else {
                weakSignalView = WeakSignalView()
                self.weakSignalView = weakSignalView
                self.addSubview(weakSignalView)
            }
            let weakSignalSize = weakSignalView.update(constrainedSize: CGSize(width: params.size.width - 32.0, height: 100.0))
            let weakSignalFrame = CGRect(origin: CGPoint(x: floor((params.size.width - weakSignalSize.width) * 0.5), y: statusFrame.maxY + (havePrimaryVideo ? 12.0 : 12.0)), size: weakSignalSize)
            if weakSignalView.bounds.isEmpty {
                weakSignalView.frame = weakSignalFrame
                if !transition.animation.isImmediate {
                    Transition.immediate.setScale(view: weakSignalView, scale: 0.001)
                    weakSignalView.alpha = 0.0
                    transition.setScaleWithSpring(view: weakSignalView, scale: 1.0)
                    transition.setAlpha(view: weakSignalView, alpha: 1.0)
                }
            } else {
                transition.setFrame(view: weakSignalView, frame: weakSignalFrame)
            }
        } else {
            if let weakSignalView = self.weakSignalView {
                self.weakSignalView = nil
                transition.setScale(view: weakSignalView, scale: 0.001)
                transition.setAlpha(view: weakSignalView, alpha: 0.0, completion: { [weak weakSignalView] _ in
                    weakSignalView?.removeFromSuperview()
                })
            }
        }
    }
}
