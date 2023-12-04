import Foundation
import UIKit
import Display
import MetalEngine
import ComponentFlow
import SwiftSignalKit

/*private final class EdgeTestLayer: MetalEngineSubjectLayer, MetalEngineSubject {
    final class RenderState: RenderToLayerState {
        let pipelineState: MTLRenderPipelineState
        
        required init?(device: MTLDevice) {
            guard let library = metalLibrary(device: device) else {
                return nil
            }
            guard let vertexFunction = library.makeFunction(name: "edgeTestVertex"), let fragmentFunction = library.makeFunction(name: "edgeTestFragment") else {
                return nil
            }
            
            let pipelineDescriptor = MTLRenderPipelineDescriptor()
            pipelineDescriptor.vertexFunction = vertexFunction
            pipelineDescriptor.fragmentFunction = fragmentFunction
            pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            pipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            pipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            pipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            pipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .one
            
            guard let pipelineState = try? device.makeRenderPipelineState(descriptor: pipelineDescriptor) else {
                return nil
            }
            self.pipelineState = pipelineState
        }
    }
    
    var internalData: MetalEngineSubjectInternalData?
    
    func update(context: MetalEngineSubjectContext) {
        context.renderToLayer(spec: RenderLayerSpec(size: RenderSize(width: 300, height: 300), edgeInset: 100), state: RenderState.self, layer: self, commands: { encoder, placement in
            let effectiveRect = placement.effectiveRect
            
            var rect = SIMD4<Float>(Float(effectiveRect.minX), Float(effectiveRect.minY), Float(effectiveRect.width * 0.5), Float(effectiveRect.height))
            encoder.setVertexBytes(&rect, length: 4 * 4, index: 0)
            
            var color = SIMD4<Float>(1.0, 0.0, 0.0, 1.0)
            encoder.setFragmentBytes(&color, length: 4 * 4, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        })
    }
}*/

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
        public var shortName: String
        public var avatarImage: UIImage?
        public var audioOutput: AudioOutput
        public var isMicrophoneMuted: Bool
        public var localVideo: VideoSource?
        public var remoteVideo: VideoSource?
        public var isRemoteBatteryLow: Bool
        
        public init(
            lifecycleState: LifecycleState,
            name: String,
            shortName: String,
            avatarImage: UIImage?,
            audioOutput: AudioOutput,
            isMicrophoneMuted: Bool,
            localVideo: VideoSource?,
            remoteVideo: VideoSource?,
            isRemoteBatteryLow: Bool
        ) {
            self.lifecycleState = lifecycleState
            self.name = name
            self.shortName = shortName
            self.avatarImage = avatarImage
            self.audioOutput = audioOutput
            self.isMicrophoneMuted = isMicrophoneMuted
            self.localVideo = localVideo
            self.remoteVideo = remoteVideo
            self.isRemoteBatteryLow = isRemoteBatteryLow
        }
        
        public static func ==(lhs: State, rhs: State) -> Bool {
            if lhs.lifecycleState != rhs.lifecycleState {
                return false
            }
            if lhs.name != rhs.name {
                return false
            }
            if lhs.shortName != rhs.shortName {
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
            if lhs.isRemoteBatteryLow != rhs.isRemoteBatteryLow {
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
    private let blobTransformLayer: SimpleLayer
    private let blobBackgroundLayer: CALayer
    private let blobLayer: CallBlobsLayer
    private let avatarTransformLayer: SimpleLayer
    private let avatarLayer: AvatarLayer
    private let titleView: TextView
    private let backButtonView: BackButtonView
    
    private var statusView: StatusView
    private var weakSignalView: WeakSignalView?
    
    private var emojiView: KeyEmojiView?
    private var emojiTooltipView: EmojiTooltipView?
    private var emojiExpandedInfoView: EmojiExpandedInfoView?
    
    private let videoContainerBackgroundView: RoundedCornersView
    private let overlayContentsVideoContainerBackgroundView: RoundedCornersView
    
    private var videoContainerViews: [VideoContainerView] = []
    
    private var activeRemoteVideoSource: VideoSource?
    private var waitingForFirstRemoteVideoFrameDisposable: Disposable?
    
    private var activeLocalVideoSource: VideoSource?
    private var waitingForFirstLocalVideoFrameDisposable: Disposable?
    
    private var canAnimateAudioLevel: Bool = false
    private var displayEmojiTooltip: Bool = false
    private var isEmojiKeyExpanded: Bool = false
    private var areControlsHidden: Bool = false
    private var swapLocalAndRemoteVideo: Bool = false
    
    private var processedInitialAudioLevelBump: Bool = false
    private var audioLevelBump: Float = 0.0
    
    private var currentAvatarAudioScale: CGFloat = 1.0
    private var targetAudioLevel: Float = 0.0
    private var audioLevel: Float = 0.0
    private var audioLevelUpdateSubscription: SharedDisplayLinkDriver.Link?
    
    public var speakerAction: (() -> Void)?
    public var flipCameraAction: (() -> Void)?
    public var videoAction: (() -> Void)?
    public var microhoneMuteAction: (() -> Void)?
    public var endCallAction: (() -> Void)?
    public var backAction: (() -> Void)?
    
    public override init(frame: CGRect) {
        self.overlayContentsView = UIView()
        self.overlayContentsView.isUserInteractionEnabled = false
        
        self.backgroundLayer = CallBackgroundLayer()
        
        self.buttonGroupView = ButtonGroupView()
        
        self.blobTransformLayer = SimpleLayer()
        self.blobBackgroundLayer = self.backgroundLayer.externalBlurredLayer
        self.blobLayer = CallBlobsLayer()
        self.blobBackgroundLayer.mask = self.blobTransformLayer
        
        self.avatarTransformLayer = SimpleLayer()
        self.avatarLayer = AvatarLayer()
        
        self.videoContainerBackgroundView = RoundedCornersView(color: .black)
        self.overlayContentsVideoContainerBackgroundView = RoundedCornersView(color: UIColor(white: 0.1, alpha: 1.0))
        
        self.titleView = TextView()
        self.statusView = StatusView()
        
        self.backButtonView = BackButtonView(text: "Back")
        
        super.init(frame: frame)
        
        self.clipsToBounds = true
        
        self.layer.addSublayer(self.backgroundLayer)
        self.overlayContentsView.layer.addSublayer(self.backgroundLayer.blurredLayer)
        
        self.overlayContentsView.addSubview(self.overlayContentsVideoContainerBackgroundView)
        
        self.layer.addSublayer(self.blobBackgroundLayer)
        self.blobTransformLayer.addSublayer(self.blobLayer)
        
        self.avatarTransformLayer.addSublayer(self.avatarLayer)
        self.layer.addSublayer(self.avatarTransformLayer)
        
        /*let edgeTestLayer = EdgeTestLayer()
        edgeTestLayer.frame = CGRect(origin: CGPoint(x: 20.0, y: 100.0), size: CGSize(width: 100.0, height: 100.0))
        self.layer.addSublayer(edgeTestLayer)*/
        
        self.addSubview(self.videoContainerBackgroundView)
        
        self.overlayContentsView.mask = self.maskContents
        self.addSubview(self.overlayContentsView)
        
        self.addSubview(self.buttonGroupView)
        
        self.addSubview(self.titleView)
        
        self.addSubview(self.statusView)
        self.statusView.requestLayout = { [weak self] in
            self?.update(transition: .immediate)
        }
        
        self.addSubview(self.backButtonView)
        
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
        
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.tapGesture(_:))))
        
        self.backButtonView.pressAction = { [weak self] in
            guard let self else {
                return
            }
            self.backAction?()
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
        
        if let emojiExpandedInfoView = self.emojiExpandedInfoView, self.isEmojiKeyExpanded {
            if !result.isDescendant(of: emojiExpandedInfoView) {
                return emojiExpandedInfoView
            }
        }
        
        return result
    }
    
    public func addIncomingAudioLevel(value: Float) {
        if self.canAnimateAudioLevel {
            self.targetAudioLevel = value
        } else {
            self.targetAudioLevel = 0.0
        }
    }
    
    private func attenuateAudioLevelStep() {
        self.audioLevel = self.audioLevel * 0.8 + (self.targetAudioLevel + self.audioLevelBump) * 0.2
        if self.audioLevel <= 0.01 {
            self.audioLevel = 0.0
        }
        self.updateAudioLevel()
    }
    
    private func updateAudioLevel() {
        if self.canAnimateAudioLevel {
            let additionalAvatarScale = CGFloat(max(0.0, min(self.audioLevel, 5.0)) * 0.05)
            self.currentAvatarAudioScale = 1.0 + additionalAvatarScale
            self.avatarTransformLayer.transform = CATransform3DMakeScale(self.currentAvatarAudioScale, self.currentAvatarAudioScale, 1.0)
            
            if let params = self.params, case .terminated = params.state.lifecycleState {
            } else {
                let blobAmplificationFactor: CGFloat = 2.0
                self.blobTransformLayer.transform = CATransform3DMakeScale(1.0 + additionalAvatarScale * blobAmplificationFactor, 1.0 + additionalAvatarScale * blobAmplificationFactor, 1.0)
            }
        }
    }
    
    @objc private func tapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            var update = false
            
            if self.displayEmojiTooltip {
                self.displayEmojiTooltip = false
                update = true
            }
            
            if self.activeRemoteVideoSource != nil || self.activeLocalVideoSource != nil {
                self.areControlsHidden = !self.areControlsHidden
                update = true
            }
            
            if update {
                self.update(transition: .spring(duration: 0.4))
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
                        return remoteVideo.addOnUpdated { [weak remoteVideo] in
                            guard let remoteVideo else {
                                subscriber.putCompletion()
                                return
                            }
                            if remoteVideo.currentOutput != nil {
                                subscriber.putCompletion()
                            }
                        }
                    }
                    var shouldUpdate = false
                    self.waitingForFirstRemoteVideoFrameDisposable = (firstVideoFrameSignal
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
                        return localVideo.addOnUpdated { [weak localVideo] in
                            guard let localVideo else {
                                subscriber.putCompletion()
                                return
                            }
                            if localVideo.currentOutput != nil {
                                subscriber.putCompletion()
                            }
                        }
                    }
                    var shouldUpdate = false
                    self.waitingForFirstLocalVideoFrameDisposable = (firstVideoFrameSignal
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
        
        if self.activeRemoteVideoSource == nil && self.activeLocalVideoSource == nil {
            self.areControlsHidden = false
        }
        
        if let previousParams = self.params, case .active = params.state.lifecycleState {
            switch previousParams.state.lifecycleState {
            case .connecting, .exchangingKeys, .ringing:
                self.displayEmojiTooltip = true
            default:
                break
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
        let genericAlphaTransition: Transition
        switch transition.animation {
        case .none:
            genericAlphaTransition = .immediate
        case let .curve(duration, _):
            genericAlphaTransition = .easeInOut(duration: min(0.3, duration))
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(), size: params.size)
        
        var activeVideoSources: [(VideoContainerView.Key, VideoSource)] = []
        if self.swapLocalAndRemoteVideo {
            if let activeLocalVideoSource = self.activeLocalVideoSource {
                activeVideoSources.append((.background, activeLocalVideoSource))
            }
            if let activeRemoteVideoSource = self.activeRemoteVideoSource {
                activeVideoSources.append((.foreground, activeRemoteVideoSource))
            }
        } else {
            if let activeRemoteVideoSource = self.activeRemoteVideoSource {
                activeVideoSources.append((.background, activeRemoteVideoSource))
            }
            if let activeLocalVideoSource = self.activeLocalVideoSource {
                activeVideoSources.append((.foreground, activeLocalVideoSource))
            }
        }
        let havePrimaryVideo = !activeVideoSources.isEmpty
        
        let currentAreControlsHidden = havePrimaryVideo && self.areControlsHidden
        
        let backgroundAspect: CGFloat = params.size.width / params.size.height
        let backgroundSizeNorm: CGFloat = 64.0
        let backgroundRenderingSize = CGSize(width: floor(backgroundSizeNorm * backgroundAspect), height: backgroundSizeNorm)
        let visualBackgroundFrame = backgroundFrame
        self.backgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(backgroundRenderingSize.width), height: Int(backgroundRenderingSize.height)), edgeInset: 8)
        transition.setFrame(layer: self.backgroundLayer, frame: visualBackgroundFrame)
        transition.setFrame(layer: self.backgroundLayer.blurredLayer, frame: visualBackgroundFrame)
        transition.setFrame(layer: self.blobBackgroundLayer, frame: visualBackgroundFrame)
        
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
        
        var notices: [ButtonGroupView.Notice] = []
        if params.state.isMicrophoneMuted {
            notices.append(ButtonGroupView.Notice(id: AnyHashable(0 as Int), text: "Your microphone is turned off"))
        }
        if params.state.remoteVideo != nil && params.state.localVideo == nil {
            notices.append(ButtonGroupView.Notice(id: AnyHashable(1 as Int), text: "Your camera is turned off"))
        }
        if params.state.isRemoteBatteryLow {
            notices.append(ButtonGroupView.Notice(id: AnyHashable(2 as Int), text: "\(params.state.shortName)'s battery is low"))
        }
        
        let contentBottomInset = self.buttonGroupView.update(size: params.size, insets: params.insets, controlsHidden: currentAreControlsHidden, buttons: buttons, notices: notices, transition: transition)
        
        var expandedEmojiKeyRect: CGRect?
        if self.isEmojiKeyExpanded {
            let emojiExpandedInfoView: EmojiExpandedInfoView
            var emojiExpandedInfoTransition = transition
            let alphaTransition: Transition
            if let current = self.emojiExpandedInfoView {
                emojiExpandedInfoView = current
                alphaTransition = genericAlphaTransition
            } else {
                emojiExpandedInfoTransition = emojiExpandedInfoTransition.withAnimation(.none)
                if !genericAlphaTransition.animation.isImmediate {
                    alphaTransition = genericAlphaTransition.withAnimation(.curve(duration: 0.1, curve: .easeInOut))
                } else {
                    alphaTransition = genericAlphaTransition
                }
                
                emojiExpandedInfoView = EmojiExpandedInfoView(title: "This call is end-to-end encrypted", text: "If the emoji on \(params.state.shortName)'s screen are the same, this call is 100% secure.")
                self.emojiExpandedInfoView = emojiExpandedInfoView
                emojiExpandedInfoView.alpha = 0.0
                Transition.immediate.setScale(view: emojiExpandedInfoView, scale: 0.5)
                emojiExpandedInfoView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.1)
                if let emojiView = self.emojiView {
                    self.insertSubview(emojiExpandedInfoView, belowSubview: emojiView)
                } else {
                    self.addSubview(emojiExpandedInfoView)
                }
                
                emojiExpandedInfoView.closeAction = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.isEmojiKeyExpanded = false
                    self.update(transition: .spring(duration: 0.4))
                }
            }
            
            let emojiExpandedInfoSize = emojiExpandedInfoView.update(constrainedWidth: params.size.width - (params.insets.left + 16.0) * 2.0, transition: emojiExpandedInfoTransition)
            let emojiExpandedInfoFrame = CGRect(origin: CGPoint(x: floor((params.size.width - emojiExpandedInfoSize.width) * 0.5), y: params.insets.top + 73.0), size: emojiExpandedInfoSize)
            emojiExpandedInfoTransition.setPosition(view: emojiExpandedInfoView, position: CGPoint(x: emojiExpandedInfoFrame.minX + emojiExpandedInfoView.layer.anchorPoint.x * emojiExpandedInfoFrame.width, y: emojiExpandedInfoFrame.minY + emojiExpandedInfoView.layer.anchorPoint.y * emojiExpandedInfoFrame.height))
            emojiExpandedInfoTransition.setBounds(view: emojiExpandedInfoView, bounds: CGRect(origin: CGPoint(), size: emojiExpandedInfoFrame.size))
            
            alphaTransition.setAlpha(view: emojiExpandedInfoView, alpha: 1.0)
            transition.setScale(view: emojiExpandedInfoView, scale: 1.0)
            
            expandedEmojiKeyRect = emojiExpandedInfoFrame
        } else {
            if let emojiExpandedInfoView = self.emojiExpandedInfoView {
                self.emojiExpandedInfoView = nil
                
                let alphaTransition: Transition
                if !genericAlphaTransition.animation.isImmediate {
                    alphaTransition = genericAlphaTransition.withAnimation(.curve(duration: 0.1, curve: .easeInOut))
                } else {
                    alphaTransition = genericAlphaTransition
                }
                
                alphaTransition.setAlpha(view: emojiExpandedInfoView, alpha: 0.0, completion: { [weak emojiExpandedInfoView] _ in
                    emojiExpandedInfoView?.removeFromSuperview()
                })
                transition.setScale(view: emojiExpandedInfoView, scale: 0.5)
            }
        }
        
        let backButtonY: CGFloat
        if currentAreControlsHidden {
            backButtonY = -self.backButtonView.size.height - 12.0
        } else {
            backButtonY = params.insets.top + 12.0
        }
        let backButtonFrame = CGRect(origin: CGPoint(x: params.insets.left + 10.0, y: backButtonY), size: self.backButtonView.size)
        transition.setFrame(view: self.backButtonView, frame: backButtonFrame)
        transition.setAlpha(view: self.backButtonView, alpha: currentAreControlsHidden ? 0.0 : 1.0)
        
        if case let .active(activeState) = params.state.lifecycleState {
            let emojiView: KeyEmojiView
            var emojiTransition = transition
            var emojiAlphaTransition = genericAlphaTransition
            if let current = self.emojiView {
                emojiView = current
            } else {
                emojiTransition = transition.withAnimation(.none)
                emojiAlphaTransition = genericAlphaTransition.withAnimation(.none)
                emojiView = KeyEmojiView(emoji: activeState.emojiKey)
                self.emojiView = emojiView
                emojiView.pressAction = { [weak self] in
                    guard let self else {
                        return
                    }
                    if !self.isEmojiKeyExpanded {
                        self.isEmojiKeyExpanded = true
                        self.displayEmojiTooltip = false
                        self.update(transition: .spring(duration: 0.4))
                    }
                }
            }
            if emojiView.superview == nil {
                self.addSubview(emojiView)
                if !transition.animation.isImmediate {
                    emojiView.animateIn()
                }
            }
            emojiView.isUserInteractionEnabled = !self.isEmojiKeyExpanded
            
            let emojiViewWasExpanded = emojiView.isExpanded
            let emojiViewSize = emojiView.update(isExpanded: self.isEmojiKeyExpanded, transition: emojiTransition)
            
            if self.isEmojiKeyExpanded {
                let emojiViewFrame = CGRect(origin: CGPoint(x: floor((params.size.width - emojiViewSize.width) * 0.5), y: params.insets.top + 93.0), size: emojiViewSize)
                
                if case let .curve(duration, curve) = transition.animation, let emojiViewWasExpanded, !emojiViewWasExpanded {
                    let distance = CGPoint(x: emojiViewFrame.midX - emojiView.center.x, y: emojiViewFrame.midY - emojiView.center.y)
                    let positionKeyframes = generateParabollicMotionKeyframes(from: emojiView.center, to: emojiViewFrame.center, elevation: -distance.y * 0.8, duration: duration, curve: curve, reverse: false)
                    emojiView.center = emojiViewFrame.center
                    emojiView.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: duration, keyPath: "position", additive: false)
                } else {
                    emojiTransition.setPosition(view: emojiView, position: emojiViewFrame.center)
                }
                emojiTransition.setBounds(view: emojiView, bounds: CGRect(origin: CGPoint(), size: emojiViewFrame.size))
                
                if let emojiTooltipView = self.emojiTooltipView {
                    self.emojiTooltipView = nil
                    emojiTooltipView.animateOut(completion: { [weak emojiTooltipView] in
                        emojiTooltipView?.removeFromSuperview()
                    })
                }
            } else {
                let emojiY: CGFloat
                if currentAreControlsHidden {
                    emojiY = -8.0 - emojiViewSize.height
                } else {
                    emojiY = params.insets.top + 12.0
                }
                let emojiViewFrame = CGRect(origin: CGPoint(x: params.size.width - params.insets.right - 12.0 - emojiViewSize.width, y: emojiY), size: emojiViewSize)
                
                if case let .curve(duration, curve) = transition.animation, let emojiViewWasExpanded, emojiViewWasExpanded {
                    let distance = CGPoint(x: emojiViewFrame.midX - emojiView.center.x, y: emojiViewFrame.midY - emojiView.center.y)
                    let positionKeyframes = generateParabollicMotionKeyframes(from: emojiViewFrame.center, to: emojiView.center, elevation: distance.y * 0.8, duration: duration, curve: curve, reverse: true)
                    emojiView.center = emojiViewFrame.center
                    emojiView.layer.animateKeyframes(values: positionKeyframes.map { NSValue(cgPoint: $0) }, duration: duration, keyPath: "position", additive: false)
                } else {
                    emojiTransition.setPosition(view: emojiView, position: emojiViewFrame.center)
                }
                emojiTransition.setBounds(view: emojiView, bounds: CGRect(origin: CGPoint(), size: emojiViewFrame.size))
                emojiAlphaTransition.setAlpha(view: emojiView, alpha: currentAreControlsHidden ? 0.0 : 1.0)
                
                if self.displayEmojiTooltip {
                    let emojiTooltipView: EmojiTooltipView
                    var emojiTooltipTransition = transition
                    var animateIn = false
                    if let current = self.emojiTooltipView {
                        emojiTooltipView = current
                    } else {
                        emojiTooltipTransition = emojiTooltipTransition.withAnimation(.none)
                        emojiTooltipView = EmojiTooltipView(text: "Encryption key of this call")
                        animateIn = true
                        self.emojiTooltipView = emojiTooltipView
                        self.addSubview(emojiTooltipView)
                    }
                    
                    let emojiTooltipSize = emojiTooltipView.update(constrainedWidth: params.size.width - 32.0 * 2.0, subjectWidth: emojiViewSize.width - 20.0)
                    let emojiTooltipFrame = CGRect(origin: CGPoint(x: emojiViewFrame.maxX - emojiTooltipSize.width, y: emojiViewFrame.maxY + 8.0), size: emojiTooltipSize)
                    emojiTooltipTransition.setFrame(view: emojiTooltipView, frame: emojiTooltipFrame)
                    
                    if animateIn && !transition.animation.isImmediate {
                        emojiTooltipView.animateIn()
                    }
                } else if let emojiTooltipView = self.emojiTooltipView {
                    self.emojiTooltipView = nil
                    emojiTooltipView.animateOut(completion: { [weak emojiTooltipView] in
                        emojiTooltipView?.removeFromSuperview()
                    })
                }
            }
            
            emojiAlphaTransition.setAlpha(view: emojiView, alpha: 1.0)
        } else {
            if let emojiView = self.emojiView {
                self.emojiView = nil
                genericAlphaTransition.setAlpha(view: emojiView, alpha: 0.0, completion: { [weak emojiView] _ in
                    emojiView?.removeFromSuperview()
                })
            }
            if let emojiTooltipView = self.emojiTooltipView {
                self.emojiTooltipView = nil
                emojiTooltipView.animateOut(completion: { [weak emojiTooltipView] in
                    emojiTooltipView?.removeFromSuperview()
                })
            }
        }
        
        let collapsedAvatarSize: CGFloat = 136.0
        let blobSize: CGFloat = collapsedAvatarSize + 40.0
        
        let collapsedAvatarFrame = CGRect(origin: CGPoint(x: floor((params.size.width - collapsedAvatarSize) * 0.5), y: max(params.insets.top + 8.0, floor(params.size.height * 0.49) - 39.0 - collapsedAvatarSize)), size: CGSize(width: collapsedAvatarSize, height: collapsedAvatarSize))
        let expandedAvatarFrame = CGRect(origin: CGPoint(), size: params.size)
        let expandedVideoFrame = CGRect(origin: CGPoint(), size: params.size)
        let avatarFrame = havePrimaryVideo ? expandedAvatarFrame : collapsedAvatarFrame
        let avatarCornerRadius = havePrimaryVideo ? params.screenCornerRadius : collapsedAvatarSize * 0.5
        
        var minimizedVideoInsets = UIEdgeInsets()
        minimizedVideoInsets.top = params.insets.top + (currentAreControlsHidden ? 0.0 : 60.0)
        minimizedVideoInsets.left = params.insets.left + 12.0
        minimizedVideoInsets.right = params.insets.right + 12.0
        minimizedVideoInsets.bottom = contentBottomInset + 12.0
        
        var validVideoContainerKeys: [VideoContainerView.Key] = []
        for i in 0 ..< activeVideoSources.count {
            let (videoContainerKey, videoSource) = activeVideoSources[i]
            validVideoContainerKeys.append(videoContainerKey)
            
            var animateIn = false
            let videoContainerView: VideoContainerView
            if let current = self.videoContainerViews.first(where: { $0.key == videoContainerKey }) {
                videoContainerView = current
            } else {
                animateIn = true
                videoContainerView = VideoContainerView(key: videoContainerKey)
                switch videoContainerKey {
                case .foreground:
                    self.overlayContentsView.layer.addSublayer(videoContainerView.blurredContainerLayer)
                    
                    self.insertSubview(videoContainerView, belowSubview: self.overlayContentsView)
                    self.videoContainerViews.append(videoContainerView)
                case .background:
                    if !self.videoContainerViews.isEmpty {
                        self.overlayContentsView.layer.insertSublayer(videoContainerView.blurredContainerLayer, below: self.videoContainerViews[0].blurredContainerLayer)
                        
                        self.insertSubview(videoContainerView, belowSubview: self.videoContainerViews[0])
                        self.videoContainerViews.insert(videoContainerView, at: 0)
                    } else {
                        self.overlayContentsView.layer.addSublayer(videoContainerView.blurredContainerLayer)
                        
                        self.insertSubview(videoContainerView, belowSubview: self.overlayContentsView)
                        self.videoContainerViews.append(videoContainerView)
                    }
                }
                
                videoContainerView.pressAction = { [weak self] in
                    guard let self else {
                        return
                    }
                    self.swapLocalAndRemoteVideo = !self.swapLocalAndRemoteVideo
                    self.update(transition: .easeInOut(duration: 0.25))
                }
            }
            
            if videoContainerView.video !== videoSource {
                videoContainerView.video = videoSource
            }
            
            let videoContainerTransition = transition
            if animateIn {
                if i == 0 && self.videoContainerViews.count == 1 {
                    videoContainerView.layer.position = self.avatarTransformLayer.position
                    videoContainerView.layer.bounds = self.avatarTransformLayer.bounds
                    videoContainerView.alpha = 0.0
                    videoContainerView.blurredContainerLayer.position = self.avatarTransformLayer.position
                    videoContainerView.blurredContainerLayer.bounds = self.avatarTransformLayer.bounds
                    videoContainerView.blurredContainerLayer.opacity = 0.0
                    videoContainerView.update(size: self.avatarTransformLayer.bounds.size, insets: minimizedVideoInsets, cornerRadius: self.avatarLayer.params?.cornerRadius ?? 0.0, controlsHidden: currentAreControlsHidden, isMinimized: false, isAnimatedOut: true, transition: .immediate)
                    Transition.immediate.setScale(view: videoContainerView, scale: self.currentAvatarAudioScale)
                    Transition.immediate.setScale(view: self.videoContainerBackgroundView, scale: self.currentAvatarAudioScale)
                } else {
                    videoContainerView.layer.position = expandedVideoFrame.center
                    videoContainerView.layer.bounds = CGRect(origin: CGPoint(), size: expandedVideoFrame.size)
                    videoContainerView.alpha = 0.0
                    videoContainerView.blurredContainerLayer.position = expandedVideoFrame.center
                    videoContainerView.blurredContainerLayer.bounds = CGRect(origin: CGPoint(), size: expandedVideoFrame.size)
                    videoContainerView.blurredContainerLayer.opacity = 0.0
                    videoContainerView.update(size: self.avatarTransformLayer.bounds.size, insets: minimizedVideoInsets, cornerRadius: params.screenCornerRadius, controlsHidden: currentAreControlsHidden, isMinimized: i != 0, isAnimatedOut: i != 0, transition: .immediate)
                }
            }
            
            videoContainerTransition.setPosition(view: videoContainerView, position: expandedVideoFrame.center)
            videoContainerTransition.setBounds(view: videoContainerView, bounds: CGRect(origin: CGPoint(), size: expandedVideoFrame.size))
            videoContainerTransition.setScale(view: videoContainerView, scale: 1.0)
            videoContainerTransition.setPosition(layer: videoContainerView.blurredContainerLayer, position: expandedVideoFrame.center)
            videoContainerTransition.setBounds(layer: videoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: expandedVideoFrame.size))
            videoContainerTransition.setScale(layer: videoContainerView.blurredContainerLayer, scale: 1.0)
            videoContainerView.update(size: expandedVideoFrame.size, insets: minimizedVideoInsets, cornerRadius: params.screenCornerRadius, controlsHidden: currentAreControlsHidden, isMinimized: i != 0, isAnimatedOut: false, transition: videoContainerTransition)
            
            let alphaTransition: Transition
            switch transition.animation {
            case .none:
                alphaTransition = .immediate
            case let .curve(duration, _):
                if animateIn {
                    if i == 0 {
                        if self.videoContainerViews.count > 1 && self.videoContainerViews[1].isFillingBounds {
                            alphaTransition = .immediate
                        } else {
                            alphaTransition = transition
                        }
                    } else {
                        alphaTransition = .easeInOut(duration: min(0.1, duration))
                    }
                } else {
                    alphaTransition = transition
                }
            }
            
            alphaTransition.setAlpha(view: videoContainerView, alpha: 1.0)
            alphaTransition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 1.0)
        }
        
        var removedVideoContainerIndices: [Int] = []
        for i in 0 ..< self.videoContainerViews.count {
            let videoContainerView = self.videoContainerViews[i]
            if !validVideoContainerKeys.contains(videoContainerView.key) {
                removedVideoContainerIndices.append(i)
                
                if self.videoContainerViews.count == 1 || (i == 0 && !havePrimaryVideo) {
                    let alphaTransition: Transition = genericAlphaTransition
                    
                    videoContainerView.update(size: avatarFrame.size, insets: minimizedVideoInsets, cornerRadius: avatarCornerRadius, controlsHidden: currentAreControlsHidden, isMinimized: false, isAnimatedOut: true, transition: transition)
                    transition.setPosition(layer: videoContainerView.blurredContainerLayer, position: avatarFrame.center)
                    transition.setBounds(layer: videoContainerView.blurredContainerLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                    transition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 0.0)
                    transition.setPosition(view: videoContainerView, position: avatarFrame.center)
                    transition.setBounds(view: videoContainerView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
                    if videoContainerView.alpha != 0.0 {
                        alphaTransition.setAlpha(view: videoContainerView, alpha: 0.0, completion: { [weak videoContainerView] _ in
                            guard let videoContainerView else {
                                return
                            }
                            videoContainerView.removeFromSuperview()
                            videoContainerView.blurredContainerLayer.removeFromSuperlayer()
                        })
                        alphaTransition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 0.0)
                    }
                } else if i == 0 {
                    let alphaTransition = genericAlphaTransition
                    
                    alphaTransition.setAlpha(view: videoContainerView, alpha: 0.0, completion: { [weak videoContainerView] _ in
                        guard let videoContainerView else {
                            return
                        }
                        videoContainerView.removeFromSuperview()
                        videoContainerView.blurredContainerLayer.removeFromSuperlayer()
                    })
                    alphaTransition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 0.0)
                } else {
                    let alphaTransition = genericAlphaTransition
                    
                    alphaTransition.setAlpha(view: videoContainerView, alpha: 0.0, completion: { [weak videoContainerView] _ in
                        guard let videoContainerView else {
                            return
                        }
                        videoContainerView.removeFromSuperview()
                        videoContainerView.blurredContainerLayer.removeFromSuperlayer()
                    })
                    alphaTransition.setAlpha(layer: videoContainerView.blurredContainerLayer, alpha: 0.0)
                    
                    videoContainerView.update(size: params.size, insets: minimizedVideoInsets, cornerRadius: params.screenCornerRadius, controlsHidden: currentAreControlsHidden, isMinimized: true, isAnimatedOut: true, transition: transition)
                }
            }
        }
        for index in removedVideoContainerIndices.reversed() {
            self.videoContainerViews.remove(at: index)
        }
        
        if self.avatarLayer.image !== params.state.avatarImage {
            self.avatarLayer.image = params.state.avatarImage
        }
        
        transition.setPosition(layer: self.avatarTransformLayer, position: avatarFrame.center)
        transition.setBounds(layer: self.avatarTransformLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
        transition.setPosition(layer: self.avatarLayer, position: CGPoint(x: avatarFrame.width * 0.5, y: avatarFrame.height * 0.5))
        
        if havePrimaryVideo != self.avatarLayer.params?.isExpanded {
            if havePrimaryVideo {
                self.canAnimateAudioLevel = false
                self.audioLevel = 0.0
                self.currentAvatarAudioScale = 1.0
                transition.setScale(layer: self.avatarTransformLayer, scale: 1.0)
                transition.setScale(layer: self.blobTransformLayer, scale: 1.0)
            }
            transition.setBounds(layer: self.avatarLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size), completion: { [weak self] completed in
                guard let self, let params = self.params, completed else {
                    return
                }
                if !havePrimaryVideo {
                    switch params.state.lifecycleState {
                    case .terminated:
                        break
                    default:
                        self.canAnimateAudioLevel = true
                    }
                }
            })
        } else {
            transition.setBounds(layer: self.avatarLayer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
        }
        
        var expandedEmojiKeyOverlapsAvatar = false
        if let expandedEmojiKeyRect, collapsedAvatarFrame.insetBy(dx: -40.0, dy: -40.0).intersects(expandedEmojiKeyRect) {
            expandedEmojiKeyOverlapsAvatar = true
        }
        
        self.avatarLayer.update(size: collapsedAvatarFrame.size, isExpanded: havePrimaryVideo, cornerRadius: avatarCornerRadius, transition: transition)
        transition.setAlpha(layer: self.avatarLayer, alpha: (expandedEmojiKeyOverlapsAvatar && !havePrimaryVideo) ? 0.0 : 1.0)
        transition.setScale(layer: self.avatarLayer, scale: expandedEmojiKeyOverlapsAvatar ? 0.001 : 1.0)
        
        transition.setPosition(view: self.videoContainerBackgroundView, position: avatarFrame.center)
        transition.setBounds(view: self.videoContainerBackgroundView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
        transition.setScale(view: self.videoContainerBackgroundView, scale: 1.0)
        transition.setAlpha(view: self.videoContainerBackgroundView, alpha: havePrimaryVideo ? 1.0 : 0.0)
        self.videoContainerBackgroundView.update(cornerRadius: havePrimaryVideo ? params.screenCornerRadius : avatarCornerRadius, transition: transition)
        
        transition.setPosition(view: self.overlayContentsVideoContainerBackgroundView, position: avatarFrame.center)
        transition.setBounds(view: self.overlayContentsVideoContainerBackgroundView, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
        transition.setAlpha(view: self.overlayContentsVideoContainerBackgroundView, alpha: havePrimaryVideo ? 1.0 : 0.0)
        self.overlayContentsVideoContainerBackgroundView.update(cornerRadius: havePrimaryVideo ? params.screenCornerRadius : avatarCornerRadius, transition: transition)
        
        let blobFrame = CGRect(origin: CGPoint(x: floor(avatarFrame.midX - blobSize * 0.5), y: floor(avatarFrame.midY - blobSize * 0.5)), size: CGSize(width: blobSize, height: blobSize))
        transition.setPosition(layer: self.blobTransformLayer, position: CGPoint(x: blobFrame.midX, y: blobFrame.midY))
        transition.setBounds(layer: self.blobTransformLayer, bounds: CGRect(origin: CGPoint(), size: blobFrame.size))
        transition.setPosition(layer: self.blobLayer, position: CGPoint(x: blobFrame.width * 0.5, y: blobFrame.height * 0.5))
        transition.setBounds(layer: self.blobLayer, bounds: CGRect(origin: CGPoint(), size: blobFrame.size))
        
        let titleString: String
        switch params.state.lifecycleState {
        case .terminated:
            self.titleView.contentMode = .center
            titleString = "Call Ended"
            genericAlphaTransition.setScale(layer: self.blobLayer, scale: 0.3)
            genericAlphaTransition.setAlpha(layer: self.blobLayer, alpha: 0.0)
            self.canAnimateAudioLevel = false
            self.audioLevel = 0.0
            self.currentAvatarAudioScale = 1.0
            transition.setScale(layer: self.avatarTransformLayer, scale: 1.0)
            transition.setScale(layer: self.blobTransformLayer, scale: 1.0)
        default:
            self.titleView.contentMode = .scaleToFill
            titleString = params.state.name
            genericAlphaTransition.setAlpha(layer: self.blobLayer, alpha: (expandedEmojiKeyOverlapsAvatar && !havePrimaryVideo) ? 0.0 : 1.0)
            transition.setScale(layer: self.blobLayer, scale: expandedEmojiKeyOverlapsAvatar ? 0.001 : 1.0)
        }
        
        let titleSize = self.titleView.update(
            string: titleString,
            fontSize: !havePrimaryVideo ? 28.0 : 17.0,
            fontWeight: !havePrimaryVideo ? 0.0 : 0.25,
            color: .white,
            constrainedWidth: params.size.width - 16.0 * 2.0,
            transition: transition
        )
        
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
        
        let titleY: CGFloat
        if currentAreControlsHidden {
            titleY = -8.0 - titleSize.height - statusSize.height
        } else if havePrimaryVideo {
            titleY = params.insets.top + 2.0
        } else {
            titleY = collapsedAvatarFrame.maxY + 39.0
        }
        let titleFrame = CGRect(
            origin: CGPoint(
                x: (params.size.width - titleSize.width) * 0.5,
                y: titleY
            ),
            size: titleSize
        )
        transition.setFrame(view: self.titleView, frame: titleFrame)
        genericAlphaTransition.setAlpha(view: self.titleView, alpha: currentAreControlsHidden ? 0.0 : 1.0)
        
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
            genericAlphaTransition.setAlpha(view: self.statusView, alpha: currentAreControlsHidden ? 0.0 : 1.0)
        }
        
        if case let .active(activeState) = params.state.lifecycleState, activeState.signalInfo.quality <= 0.2, !self.isEmojiKeyExpanded, (!self.displayEmojiTooltip || !havePrimaryVideo) {
            let weakSignalView: WeakSignalView
            if let current = self.weakSignalView {
                weakSignalView = current
            } else {
                weakSignalView = WeakSignalView()
                self.weakSignalView = weakSignalView
                self.addSubview(weakSignalView)
            }
            let weakSignalSize = weakSignalView.update(constrainedSize: CGSize(width: params.size.width - 32.0, height: 100.0))
            let weakSignalY: CGFloat
            if currentAreControlsHidden {
                weakSignalY = params.insets.top + 2.0
            } else {
                weakSignalY = statusFrame.maxY + (havePrimaryVideo ? 12.0 : 12.0)
            }
            let weakSignalFrame = CGRect(origin: CGPoint(x: floor((params.size.width - weakSignalSize.width) * 0.5), y: weakSignalY), size: weakSignalSize)
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
