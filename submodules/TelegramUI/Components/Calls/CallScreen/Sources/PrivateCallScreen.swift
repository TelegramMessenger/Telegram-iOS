import Foundation
import UIKit
import Display
import MetalEngine
import ComponentFlow

public final class PrivateCallScreen: UIView {
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
        
        public enum LifecycleState: Equatable {
            case connecting
            case ringing
            case exchangingKeys
            case active(ActiveState)
        }
        
        public var lifecycleState: LifecycleState
        public var name: String
        public var avatarImage: UIImage?
        
        public init(
            lifecycleState: LifecycleState,
            name: String,
            avatarImage: UIImage?
        ) {
            self.lifecycleState = lifecycleState
            self.name = name
            self.avatarImage = avatarImage
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
    
    private let backgroundLayer: CallBackgroundLayer
    private let contentOverlayLayer: ContentOverlayLayer
    private let contentOverlayContainer: ContentOverlayContainer
    
    private let blurContentsLayer: SimpleLayer
    private let blurBackgroundLayer: CallBackgroundLayer
    
    private let contentView: ContentView
    
    private let buttonGroupView: ButtonGroupView
    
    private var params: Params?
    
    private var remoteVideo: VideoSource?
    
    private var isSpeakerOn: Bool = false
    private var isMicrophoneMuted: Bool = false
    private var isVideoOn: Bool = false
    
    public override init(frame: CGRect) {
        self.blurContentsLayer = SimpleLayer()
        
        self.backgroundLayer = CallBackgroundLayer(isBlur: false)
        
        self.contentOverlayLayer = ContentOverlayLayer()
        self.contentOverlayContainer = ContentOverlayContainer(overlayLayer: self.contentOverlayLayer)
        
        self.blurBackgroundLayer = CallBackgroundLayer(isBlur: true)
        
        self.contentView = ContentView(frame: CGRect())
        
        self.buttonGroupView = ButtonGroupView()
        
        super.init(frame: frame)
        
        self.contentOverlayLayer.contentsLayer = self.blurContentsLayer
        
        self.layer.addSublayer(self.backgroundLayer)
        
        self.blurContentsLayer.addSublayer(self.blurBackgroundLayer)
        
        self.addSubview(self.contentView)
        self.blurContentsLayer.addSublayer(self.contentView.blurContentsLayer)
        
        self.layer.addSublayer(self.contentOverlayLayer)
        
        self.addSubview(self.contentOverlayContainer)
        
        self.contentOverlayContainer.addSubview(self.buttonGroupView)
        
        /*self.buttonGroupView.audioPressed = { [weak self] in
            guard let self, var params = self.params else {
                return
            }
            
            self.isSpeakerOn = !self.isSpeakerOn
            
            switch params.state.lifecycleState {
            case .connecting:
                params.state.lifecycleState = .ringing
            case .ringing:
                params.state.lifecycleState = .exchangingKeys
            case .exchangingKeys:
                params.state.lifecycleState = .active(State.ActiveState(
                    startTime: Date().timeIntervalSince1970,
                    signalInfo: State.SignalInfo(quality: 1.0),
                    emojiKey: ["🐱", "🚂", "❄️", "🎨"]
                ))
            case var .active(activeState):
                if activeState.signalInfo.quality == 1.0 {
                    activeState.signalInfo.quality = 0.1
                } else {
                    activeState.signalInfo.quality = 1.0
                }
                params.state.lifecycleState = .active(activeState)
            }
            
            self.params = params
            self.update(transition: .spring(duration: 0.3))
        }
        
        self.buttonGroupView.toggleVideo = { [weak self] in
            guard let self else {
                return
            }
            if self.remoteVideo == nil {
                if let url = Bundle.main.url(forResource: "test2", withExtension: "mp4") {
                    self.remoteVideo = FileVideoSource(device: MetalEngine.shared.device, url: url)
                }
            } else {
                self.remoteVideo = nil
            }
            
            self.isVideoOn = !self.isVideoOn
            
            self.update(transition: .spring(duration: 0.3))
        }*/
    }
    
    public required init?(coder: NSCoder) {
        fatalError()
    }
    
    override public func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let result = super.hitTest(point, with: event) else {
            return nil
        }
        
        return result
    }
    
    public func update(size: CGSize, insets: UIEdgeInsets, screenCornerRadius: CGFloat, state: State, transition: Transition) {
        let params = Params(size: size, insets: insets, screenCornerRadius: screenCornerRadius, state: state)
        if self.params == params {
            return
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
        }
        self.backgroundLayer.update(stateIndex: backgroundStateIndex, transition: transition)
        
        self.contentOverlayLayer.frame = CGRect(origin: CGPoint(), size: params.size)
        self.contentOverlayLayer.update(size: params.size, contentInsets: UIEdgeInsets())
        
        self.contentOverlayContainer.frame = CGRect(origin: CGPoint(), size: params.size)
        
        self.blurBackgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(renderingSize.width) + edgeSize * 2, height: Int(renderingSize.height) + edgeSize * 2))
        self.blurBackgroundLayer.update(stateIndex: backgroundStateIndex, transition: transition)
        transition.setFrame(layer: self.blurBackgroundLayer, frame: visualBackgroundFrame)
        
        self.buttonGroupView.frame = CGRect(origin: CGPoint(), size: params.size)
        
        let buttons: [ButtonGroupView.Button] = [
            ButtonGroupView.Button(content: .speaker(isActive: self.isSpeakerOn), action: { [weak self] in
                guard let self, var params = self.params else {
                    return
                }
                
                self.isSpeakerOn = !self.isSpeakerOn
                
                switch params.state.lifecycleState {
                case .connecting:
                    params.state.lifecycleState = .ringing
                case .ringing:
                    params.state.lifecycleState = .exchangingKeys
                case .exchangingKeys:
                    params.state.lifecycleState = .active(State.ActiveState(
                        startTime: Date().timeIntervalSince1970,
                        signalInfo: State.SignalInfo(quality: 1.0),
                        emojiKey: ["🐱", "🚂", "❄️", "🎨"]
                    ))
                case var .active(activeState):
                    if activeState.signalInfo.quality == 1.0 {
                        activeState.signalInfo.quality = 0.1
                    } else {
                        activeState.signalInfo.quality = 1.0
                    }
                    params.state.lifecycleState = .active(activeState)
                }
                
                self.params = params
                self.update(transition: .spring(duration: 0.3))
            }),
            ButtonGroupView.Button(content: .video(isActive: self.isVideoOn), action: { [weak self] in
                guard let self else {
                    return
                }
                if self.remoteVideo == nil {
                    if let url = Bundle.main.url(forResource: "test2", withExtension: "mp4") {
                        self.remoteVideo = FileVideoSource(device: MetalEngine.shared.device, url: url)
                    }
                } else {
                    self.remoteVideo = nil
                }
                
                self.isVideoOn = !self.isVideoOn
                
                self.update(transition: .spring(duration: 0.3))
            }),
            ButtonGroupView.Button(content: .microphone(isMuted: self.isMicrophoneMuted), action: {
                
            }),
            ButtonGroupView.Button(content: .end, action: {
            })
        ]
        self.buttonGroupView.update(size: params.size, buttons: buttons, transition: transition)
        
        self.contentView.frame = CGRect(origin: CGPoint(), size: params.size)
        self.contentView.update(
            size: params.size,
            insets: params.insets,
            screenCornerRadius: params.screenCornerRadius,
            state: params.state,
            remoteVideo: remoteVideo,
            transition: transition
        )
    }
}
