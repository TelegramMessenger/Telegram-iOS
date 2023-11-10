import Foundation
import UIKit
import Display
import MetalEngine

final class ContentView: UIView {
    private struct Params: Equatable {
        var size: CGSize
        var insets: UIEdgeInsets
        var state: PrivateCallScreen.State
        
        init(size: CGSize, insets: UIEdgeInsets, state: PrivateCallScreen.State) {
            self.size = size
            self.insets = insets
            self.state = state
        }
    }
    
    private let blobLayer: CallBlobsLayer
    private let avatarLayer: AvatarLayer
    private let titleView: TextView
    private let statusView: StatusView
    private var emojiView: KeyEmojiView?
    
    let blurContentsLayer: SimpleLayer
    
    private let videoLayer: MainVideoLayer
    private var videoLayerMask: SimpleShapeLayer?
    private var blurredVideoLayerMask: SimpleShapeLayer?
    
    private var params: Params?
    
    private var isDisplayingVideo: Bool = false
    private var videoDisplayFraction = AnimatedProperty<CGFloat>(0.0)
    
    private var videoInput: VideoInput?
    
    private let managedAnimations: ManagedAnimations
    
    override init(frame: CGRect) {
        self.blobLayer = CallBlobsLayer()
        self.avatarLayer = AvatarLayer()
        
        self.titleView = TextView()
        self.statusView = StatusView()
        
        self.blurContentsLayer = SimpleLayer()
        
        self.videoLayer = MainVideoLayer()
        
        self.managedAnimations = ManagedAnimations()
        
        super.init(frame: frame)
        
        self.layer.addSublayer(self.blobLayer)
        self.layer.addSublayer(self.avatarLayer)
        self.layer.addSublayer(self.videoLayer)
        self.blurContentsLayer.addSublayer(self.videoLayer.blurredLayer)
        
        self.addSubview(self.titleView)
        self.addSubview(self.statusView)
        
        self.avatarLayer.image = UIImage(named: "test")
        
        self.managedAnimations.add(property: self.videoDisplayFraction)
        self.managedAnimations.updated = { [weak self] in
            guard let self else {
                return
            }
            if let params = self.params {
                self.updateInternal(params: params)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func update(size: CGSize, insets: UIEdgeInsets, state: PrivateCallScreen.State) {
        let params = Params(size: size, insets: insets, state: state)
        if self.params == params {
            return
        }
        self.params = params
        self.updateInternal(params: params)
    }
    
    private func updateInternal(params: Params) {
        if self.emojiView == nil {
            let emojiView = KeyEmojiView(emoji: ["🐱", "🚂", "❄️", "🎨"])
            self.emojiView = emojiView
            self.addSubview(emojiView)
        }
        if let emojiView = self.emojiView {
            emojiView.frame = CGRect(origin: CGPoint(x: params.size.width - 12.0 - emojiView.size.width, y: params.insets.top + 27.0), size: emojiView.size)
        }
        
        if self.videoInput == nil, let url = Bundle.main.url(forResource: "test2", withExtension: "mp4") {
            self.videoInput = VideoInput(device: MetalEngine.shared.device, url: url)
            self.videoLayer.video = self.videoInput
        }
        
        //self.phase += 3.0 / 60.0
        //self.phase = self.phase.truncatingRemainder(dividingBy: 1.0)
        var avatarScale: CGFloat = 0.05 * sin(CGFloat(0.0) * CGFloat.pi)
        avatarScale *= 1.0 - self.videoDisplayFraction.value
        
        let avatarSize: CGFloat = 136.0
        let blobSize: CGFloat = 176.0
        
        let expandedVideoRadius: CGFloat = sqrt(pow(params.size.width * 0.5, 2.0) + pow(params.size.height * 0.5, 2.0))
        
        let avatarFrame = CGRect(origin: CGPoint(x: floor((params.size.width - avatarSize) * 0.5), y: CGFloat.animationInterpolator.interpolate(from: 222.0, to: floor((params.size.height - avatarSize) * 0.5), fraction: self.videoDisplayFraction.value)), size: CGSize(width: avatarSize, height: avatarSize))
        
        let titleSize = self.titleView.update(string: "Emma Walters", fontSize: CGFloat.animationInterpolator.interpolate(from: 28.0, to: 17.0, fraction: self.videoDisplayFraction.value), fontWeight: CGFloat.animationInterpolator.interpolate(from: 0.0, to: 0.25, fraction: self.videoDisplayFraction.value), constrainedWidth: params.size.width - 16.0 * 2.0)
        let titleFrame = CGRect(origin: CGPoint(x: (params.size.width - titleSize.width) * 0.5, y: CGFloat.animationInterpolator.interpolate(from: avatarFrame.maxY + 39.0, to: params.insets.top + 17.0, fraction: self.videoDisplayFraction.value)), size: titleSize)
        self.titleView.frame = titleFrame
        
        let statusState: StatusView.State
        switch params.state.lifecycleState {
        case .connecting:
            statusState = .waiting(.requesting)
        case .ringing:
            statusState = .waiting(.ringing)
        case .exchangingKeys:
            statusState = .waiting(.generatingKeys)
        case let .active(_, signalInfo):
            statusState = .active(StatusView.ActiveState(signalStrength: signalInfo.quality))
        }
        let statusSize = self.statusView.update(state: statusState)
        self.statusView.frame = CGRect(origin: CGPoint(x: (params.size.width - statusSize.width) * 0.5, y: titleFrame.maxY + CGFloat.animationInterpolator.interpolate(from: 4.0, to: 0.0, fraction: self.videoDisplayFraction.value)), size: statusSize)
        
        let blobFrame = CGRect(origin: CGPoint(x: floor(avatarFrame.midX - blobSize * 0.5), y: floor(avatarFrame.midY - blobSize * 0.5)), size: CGSize(width: blobSize, height: blobSize))
        
        self.avatarLayer.position = CGPoint(x: avatarFrame.midX, y: avatarFrame.midY)
        self.avatarLayer.bounds = CGRect(origin: CGPoint(), size: avatarFrame.size)
        
        let visibleAvatarScale = CGFloat.animationInterpolator.interpolate(from: 1.0 + avatarScale, to: expandedVideoRadius * 2.0 / avatarSize, fraction: self.videoDisplayFraction.value)
        self.avatarLayer.transform = CATransform3DMakeScale(visibleAvatarScale, visibleAvatarScale, 1.0)
        self.avatarLayer.opacity = Float(1.0 - self.videoDisplayFraction.value)
        
        self.blobLayer.position = CGPoint(x: blobFrame.midX, y: blobFrame.midY)
        self.blobLayer.bounds = CGRect(origin: CGPoint(), size: blobFrame.size)
        self.blobLayer.transform = CATransform3DMakeScale(1.0 + avatarScale * 2.0, 1.0 + avatarScale * 2.0, 1.0)
        
        let videoResolution = CGSize(width: 400.0, height: 400.0)
        let videoFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: params.size)
        
        let videoRenderingSize = CGSize(width: videoResolution.width * 2.0, height: videoResolution.height * 2.0)
        
        self.videoLayer.frame = videoFrame
        self.videoLayer.renderSpec = RenderLayerSpec(size: RenderSize(width: Int(videoRenderingSize.width), height: Int(videoRenderingSize.height)))
        
        self.videoLayer.blurredLayer.frame = videoFrame
        
        let videoDisplayFraction = self.videoDisplayFraction.value
        
        self.videoLayer.isHidden = videoDisplayFraction == 0.0
        self.videoLayer.opacity = Float(videoDisplayFraction)
        
        self.videoLayer.blurredLayer.isHidden = videoDisplayFraction == 0.0
        
        if videoDisplayFraction != 0.0 && videoDisplayFraction != 1.0 {
            let videoLayerMask: SimpleShapeLayer
            if let current = self.videoLayerMask {
                videoLayerMask = current
            } else {
                videoLayerMask = SimpleShapeLayer()
                self.videoLayerMask = videoLayerMask
                self.videoLayer.mask = videoLayerMask
            }
            
            let blurredVideoLayerMask: SimpleShapeLayer
            if let current = self.blurredVideoLayerMask {
                blurredVideoLayerMask = current
            } else {
                blurredVideoLayerMask = SimpleShapeLayer()
                self.blurredVideoLayerMask = blurredVideoLayerMask
                self.videoLayer.blurredLayer.mask = blurredVideoLayerMask
            }
            
            let fromRadius: CGFloat = avatarSize * 0.5
            let toRadius = expandedVideoRadius
            
            let maskPosition = CGPoint(x: avatarFrame.midX, y: avatarFrame.midY)
            let maskRadius = CGFloat.animationInterpolator.interpolate(from: fromRadius, to: toRadius, fraction: videoDisplayFraction)
            
            videoLayerMask.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: maskPosition.x - maskRadius, y: maskPosition.y - maskRadius), size: CGSize(width: maskRadius * 2.0, height: maskRadius * 2.0))).cgPath
            blurredVideoLayerMask.path = UIBezierPath(ovalIn: CGRect(origin: CGPoint(x: maskPosition.x - maskRadius, y: maskPosition.y - maskRadius), size: CGSize(width: maskRadius * 2.0, height: maskRadius * 2.0))).cgPath
        } else {
            if let videoLayerMask = self.videoLayerMask {
                self.videoLayerMask = nil
                videoLayerMask.removeFromSuperlayer()
            }
            if let blurredVideoLayerMask = self.blurredVideoLayerMask {
                self.blurredVideoLayerMask = nil
                blurredVideoLayerMask.removeFromSuperlayer()
            }
        }
    }
    
    func toggleDisplayVideo() {
        self.isDisplayingVideo = !self.isDisplayingVideo
        self.videoDisplayFraction.animate(to: self.isDisplayingVideo ? 1.0 : 0.0, duration: 0.4, curve: .spring)
    }
}
