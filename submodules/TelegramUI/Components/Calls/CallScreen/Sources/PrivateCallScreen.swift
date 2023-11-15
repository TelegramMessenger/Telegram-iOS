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
    
    private var videoContainerView: VideoContainerView?
    
    private var activeRemoteVideoSource: VideoSource?
    private var waitingForFirstVideoFrameDisposable: Disposable?
    
    private var processedInitialAudioLevelBump: Bool = false
    private var audioLevelBump: Float = 0.0
    
    private var targetAudioLevel: Float = 0.0
    private var audioLevel: Float = 0.0
    private var audioLevelUpdateSubscription: SharedDisplayLinkDriver.Link?
    
    public var speakerAction: (() -> Void)?
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
        
        self.overlayContentsView.mask = self.maskContents
        self.addSubview(self.overlayContentsView)
        
        self.addSubview(self.buttonGroupView)
        
        self.layer.addSublayer(self.blobLayer)
        self.layer.addSublayer(self.avatarLayer)
        
        self.addSubview(self.titleView)
        
        self.addSubview(self.statusView)
        self.statusView.requestLayout = { [weak self] in
            self?.update(transition: .immediate)
        }
        
        self.audioLevelUpdateSubscription = SharedDisplayLinkDriver.shared.add(needsHighestFramerate: false, { [weak self] in
            guard let self else {
                return
            }
            self.attenuateAudioLevelStep()
        })
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    deinit {
        self.waitingForFirstVideoFrameDisposable?.dispose()
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
        if self.activeRemoteVideoSource == nil {
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
            self.waitingForFirstVideoFrameDisposable?.dispose()
            
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
                    self.waitingForFirstVideoFrameDisposable = (firstVideoFrameSignal
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
        
        let buttons: [ButtonGroupView.Button] = [
            ButtonGroupView.Button(content: .speaker(isActive: params.state.audioOutput != .internalSpeaker), action: { [weak self] in
                guard let self else {
                    return
                }
                self.speakerAction?()
            }),
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
                emojiView.removeFromSuperview()
            }
        }
        
        let collapsedAvatarSize: CGFloat = 136.0
        let blobSize: CGFloat = collapsedAvatarSize + 40.0
        
        let collapsedAvatarFrame = CGRect(origin: CGPoint(x: floor((params.size.width - collapsedAvatarSize) * 0.5), y: 222.0), size: CGSize(width: collapsedAvatarSize, height: collapsedAvatarSize))
        let expandedAvatarFrame = CGRect(origin: CGPoint(), size: params.size)
        let avatarFrame = self.activeRemoteVideoSource != nil ? expandedAvatarFrame : collapsedAvatarFrame
        let avatarCornerRadius = self.activeRemoteVideoSource != nil ? params.screenCornerRadius : collapsedAvatarSize * 0.5
        
        if let activeRemoteVideoSource = self.activeRemoteVideoSource {
            let videoContainerView: VideoContainerView
            if let current = self.videoContainerView {
                videoContainerView = current
            } else {
                videoContainerView = VideoContainerView(frame: CGRect())
                self.videoContainerView = videoContainerView
                self.insertSubview(videoContainerView, belowSubview: self.titleView)
                self.overlayContentsView.layer.addSublayer(videoContainerView.blurredContainerLayer)
                
                videoContainerView.layer.position = self.avatarLayer.position
                videoContainerView.layer.bounds = self.avatarLayer.bounds
                videoContainerView.alpha = 0.0
                videoContainerView.blurredContainerLayer.position = self.avatarLayer.position
                videoContainerView.blurredContainerLayer.bounds = self.avatarLayer.bounds
                videoContainerView.blurredContainerLayer.opacity = 0.0
                videoContainerView.update(size: self.avatarLayer.bounds.size, cornerRadius: self.avatarLayer.params?.cornerRadius ?? 0.0, isExpanded: false, transition: .immediate)
            }
            
            if videoContainerView.video !== activeRemoteVideoSource {
                videoContainerView.video = activeRemoteVideoSource
            }
            
            transition.setPosition(view: videoContainerView, position: avatarFrame.center)
            transition.setBounds(view: videoContainerView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            transition.setAlpha(view: videoContainerView, alpha: 1.0)
            transition.setPosition(layer: videoContainerView.blurredContainerLayer, position: avatarFrame.center)
            transition.setBounds(layer: videoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            transition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 1.0)
            videoContainerView.update(size: avatarFrame.size, cornerRadius: avatarCornerRadius, isExpanded: self.activeRemoteVideoSource != nil, transition: transition)
        } else {
            if let videoContainerView = self.videoContainerView {
                videoContainerView.update(size: avatarFrame.size, cornerRadius: avatarCornerRadius, isExpanded: self.activeRemoteVideoSource != nil, transition: transition)
                transition.setPosition(layer: videoContainerView.blurredContainerLayer, position: avatarFrame.center)
                transition.setBounds(layer: videoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                transition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 0.0)
                transition.setPosition(view: videoContainerView, position: avatarFrame.center)
                transition.setBounds(view: videoContainerView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                if videoContainerView.alpha != 0.0 {
                    transition.setAlpha(view: videoContainerView, alpha: 0.0, completion: { [weak self, weak videoContainerView] completed in
                        guard let self, let videoContainerView, completed else {
                            return
                        }
                        videoContainerView.removeFromSuperview()
                        videoContainerView.blurredContainerLayer.removeFromSuperlayer()
                        if self.videoContainerView === videoContainerView {
                            self.videoContainerView = nil
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
        self.avatarLayer.update(size: collapsedAvatarFrame.size, isExpanded: self.activeRemoteVideoSource != nil, cornerRadius: avatarCornerRadius, transition: transition)
        
        let blobFrame = CGRect(origin: CGPoint(x: floor(avatarFrame.midX - blobSize * 0.5), y: floor(avatarFrame.midY - blobSize * 0.5)), size: CGSize(width: blobSize, height: blobSize))
        transition.setPosition(layer: self.blobLayer, position: CGPoint(x: blobFrame.midX, y: blobFrame.midY))
        transition.setBounds(layer: self.blobLayer, bounds: CGRect(origin: CGPoint(), size: blobFrame.size))
        
        let titleString: String
        switch params.state.lifecycleState {
        case .terminated:
            titleString = "Call Ended"
            transition.setScale(layer: self.blobLayer, scale: 0.001)
            transition.setAlpha(layer: self.blobLayer, alpha: 0.0)
        default:
            titleString = params.state.name
        }
        
        let titleSize = self.titleView.update(
            string: titleString,
            fontSize: self.activeRemoteVideoSource == nil ? 28.0 : 17.0,
            fontWeight: self.activeRemoteVideoSource == nil ? 0.0 : 0.25,
            color: .white,
            constrainedWidth: params.size.width - 16.0 * 2.0,
            transition: transition
        )
        let titleFrame = CGRect(
            origin: CGPoint(
                x: (params.size.width - titleSize.width) * 0.5,
                y: self.activeRemoteVideoSource == nil ? collapsedAvatarFrame.maxY + 39.0 : params.insets.top + 17.0
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
                y: titleFrame.maxY + (self.activeRemoteVideoSource != nil ? 0.0 : 4.0)
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
        
        if "".isEmpty {//} case let .active(activeState) = params.state.lifecycleState, activeState.signalInfo.quality <= 0.2 {
            let weakSignalView: WeakSignalView
            if let current = self.weakSignalView {
                weakSignalView = current
            } else {
                weakSignalView = WeakSignalView()
                self.weakSignalView = weakSignalView
                self.addSubview(weakSignalView)
            }
            let weakSignalSize = weakSignalView.update(constrainedSize: CGSize(width: params.size.width - 32.0, height: 100.0))
            let weakSignalFrame = CGRect(origin: CGPoint(x: floor((params.size.width - weakSignalSize.width) * 0.5), y: statusFrame.maxY + (self.activeRemoteVideoSource != nil ? 4.0 : 4.0)), size: weakSignalSize)
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
