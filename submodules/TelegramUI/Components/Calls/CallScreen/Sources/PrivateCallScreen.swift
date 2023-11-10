import Foundation
import UIKit
import Display
import MetalEngine

public final class PrivateCallScreen: UIView {
    public struct State: Equatable {
        public struct SignalInfo: Equatable {
            public var quality: Double
            
            public init(quality: Double) {
                self.quality = quality
            }
        }
        
        public enum LifecycleState: Equatable {
            case connecting
            case ringing
            case exchangingKeys
            case active(startTime: Double, signalInfo: SignalInfo)
        }
        
        public var lifecycleState: LifecycleState
        
        public init(lifecycleState: LifecycleState) {
            self.lifecycleState = lifecycleState
        }
    }
    
    private struct Params: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
        
        init(size: CGSize, insets: UIEdgeInsets) {
            self.size = size
            self.insets = insets
        }
    }
    
    private let backgroundLayer: CallBackgroundLayer
    private let contentOverlayLayer: ContentOverlayLayer
    private let contentOverlayContainer: ContentOverlayContainer
    
    private let blurContentsLayer: SimpleLayer
    private let blurBackgroundLayer: CallBackgroundLayer
    
    private let contentView: ContentView
    
    private let buttonGroupView: ButtonGroupView
    
    public var state: State = State(lifecycleState: .connecting) {
        didSet {
            if self.state != oldValue {
                if let params = self.params {
                    self.updateInternal(params: params, animated: true)
                }
            }
        }
    }
    
    private var params: Params?
    
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
        
        self.buttonGroupView.audioPressed = { [weak self] in
            guard let self else {
                return
            }
            
            var state = self.state
            switch state.lifecycleState {
            case .connecting, .ringing, .exchangingKeys:
                state.lifecycleState = .active(startTime: CFAbsoluteTimeGetCurrent(), signalInfo: State.SignalInfo(quality: 1.0))
            case let .active(startTime, signalInfo):
                if signalInfo.quality == 1.0 {
                    state.lifecycleState = .active(startTime: startTime, signalInfo: State.SignalInfo(quality: 0.2))
                } else if signalInfo.quality == 0.2 {
                    state.lifecycleState = .connecting
                }
                
            }
            self.state = state
        }
        
        self.buttonGroupView.toggleVideo = { [weak self] in
            guard let self else {
                return
            }
            self.contentView.toggleDisplayVideo()
        }
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
    
    public func update(size: CGSize, insets: UIEdgeInsets) {
        let params = Params(size: size, insets: insets)
        if self.params == params {
            return
        }
        self.params = params
        self.updateInternal(params: params, animated: false)
    }
        
    private func updateInternal(params: Params, animated: Bool) {
        let backgroundFrame = CGRect(origin: CGPoint(), size: params.size)
        
        let aspect: CGFloat = params.size.width / params.size.height
        let sizeNorm: CGFloat = 64.0
        let renderingSize = CGSize(width: floor(sizeNorm * aspect), height: sizeNorm)
        let edgeSize: Int = 2
        
        let visualBackgroundFrame = backgroundFrame.insetBy(dx: -CGFloat(edgeSize) / renderingSize.width * backgroundFrame.width, dy: -CGFloat(edgeSize) / renderingSize.height * backgroundFrame.height)
        
        self.backgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(renderingSize.width) + edgeSize * 2, height: Int(renderingSize.height) + edgeSize * 2))
        self.backgroundLayer.frame = visualBackgroundFrame
        
        let backgroundStateIndex: Int
        switch self.state.lifecycleState {
        case .connecting:
            backgroundStateIndex = 0
        case .ringing:
            backgroundStateIndex = 0
        case .exchangingKeys:
            backgroundStateIndex = 0
        case let .active(_, signalInfo):
            if signalInfo.quality <= 0.2 {
                backgroundStateIndex = 2
            } else {
                backgroundStateIndex = 1
            }
        }
        self.backgroundLayer.update(stateIndex: backgroundStateIndex, animated: animated)
        
        self.contentOverlayLayer.frame = CGRect(origin: CGPoint(), size: params.size)
        self.contentOverlayLayer.update(size: params.size, contentInsets: UIEdgeInsets())
        
        self.contentOverlayContainer.frame = CGRect(origin: CGPoint(), size: params.size)
        
        self.blurBackgroundLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(renderingSize.width) + edgeSize * 2, height: Int(renderingSize.height) + edgeSize * 2))
        self.blurBackgroundLayer.frame = visualBackgroundFrame
        self.blurBackgroundLayer.update(stateIndex: backgroundStateIndex, animated: animated)
        
        self.buttonGroupView.frame = CGRect(origin: CGPoint(), size: params.size)
        self.buttonGroupView.update(size: params.size)
        
        self.contentView.frame = CGRect(origin: CGPoint(), size: params.size)
        self.contentView.update(size: params.size, insets: params.insets, state: self.state)
    }
}
