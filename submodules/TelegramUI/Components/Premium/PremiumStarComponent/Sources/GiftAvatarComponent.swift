import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import SceneKit
import GZip
import AppBundle
import LegacyComponents
import AvatarNode
import AccountContext
import TelegramCore
import MergedAvatarsNode
import MultilineTextComponent
import TelegramPresentationData
import PhotoResources

private let sceneVersion: Int = 1

public final class GiftAvatarComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let peers: [EnginePeer]
    let photo: TelegramMediaWebFile?
    let isVisible: Bool
    let hasIdleAnimations: Bool
    let hasScaleAnimation: Bool
    let avatarSize: CGFloat
    let color: UIColor?
    let offset: CGFloat?
    let hasLargeParticles: Bool
    let action: (() -> Void)?
        
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        peers: [EnginePeer],
        photo: TelegramMediaWebFile? = nil,
        isVisible: Bool,
        hasIdleAnimations: Bool,
        hasScaleAnimation: Bool = true,
        avatarSize: CGFloat = 100.0,
        color: UIColor? = nil,
        offset: CGFloat? = nil,
        hasLargeParticles: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.context = context
        self.theme = theme
        self.peers = peers
        self.photo = photo
        self.isVisible = isVisible
        self.hasIdleAnimations = hasIdleAnimations
        self.hasScaleAnimation = hasScaleAnimation
        self.avatarSize = avatarSize
        self.color = color
        self.offset = offset
        self.hasLargeParticles = hasLargeParticles
        self.action = action
    }
    
    public static func ==(lhs: GiftAvatarComponent, rhs: GiftAvatarComponent) -> Bool {
        return lhs.peers == rhs.peers && lhs.photo == rhs.photo && lhs.theme === rhs.theme && lhs.isVisible == rhs.isVisible && lhs.hasIdleAnimations == rhs.hasIdleAnimations && lhs.hasScaleAnimation == rhs.hasScaleAnimation && lhs.avatarSize == rhs.avatarSize && lhs.offset == rhs.offset && lhs.hasLargeParticles == rhs.hasLargeParticles
    }
    
    public final class View: UIView, SCNSceneRendererDelegate, ComponentTaggedView {
        public final class Tag {
            public init() {
                
            }
        }
        
        public func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag {
                return true
            }
            return false
        }
        
        private var component: GiftAvatarComponent?
        
        private var _ready = Promise<Bool>()
        public var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
        
        weak var animateFrom: UIView?
        weak var containerView: UIView?
        var animationColor: UIColor?
        
        private let sceneView: SCNView
        private let avatarNode: ImageNode
        private var mergedAvatarsNode: MergedAvatarsNode?
        private var imageNode: TransformImageNode?
        
        private var iconBackgroundView: UIImageView?
        private var iconView: UIImageView?
        
        private let badgeBackground = ComponentView<Empty>()
        private let badge = ComponentView<Empty>()
        
        private var previousInteractionTimestamp: Double = 0.0
        private var timer: SwiftSignalKit.Timer?
        private var hasIdleAnimations = false
        
        private let fetchDisposable = MetaDisposable()
        
        public override init(frame: CGRect) {
            self.sceneView = SCNView(frame: CGRect(origin: .zero, size: CGSize(width: 64.0, height: 64.0)))
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            self.sceneView.preferredFramesPerSecond = 60
            
            self.avatarNode = ImageNode()
            self.avatarNode.displaysAsynchronously = false
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
            self.addSubview(self.avatarNode.view)
                                    
            let tapGestureRecoginzer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            self.addGestureRecognizer(tapGestureRecoginzer)
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.timer?.invalidate()
            self.fetchDisposable.dispose()
        }
        
        private let hapticFeedback = HapticFeedback()
        
        private var delayTapsTill: Double?
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            if let action = self.component?.action {
                action()
            } else {
                self.playAppearanceAnimation(velocity: nil, mirror: false, explode: true)
            }
        }
        
        private var didSetup = false
        private func setup() {
            guard let scene = loadCompressedScene(name: "gift2", version: sceneVersion), !self.didSetup else {
                return
            }
            
            self.didSetup = true
            
            self.sceneView.scene = scene
            self.sceneView.delegate = self
            
            if let color = self.component?.color {                
                let names: [String] = [
                    "particles_left",
                    "particles_right",
                    "particles_left_bottom",
                    "particles_right_bottom",
                    "particles_center"
                ]
                
                let starNames: [String] = [
                    "coins_left",
                    "coins_right"
                ]
                
                let particleColor = color
                for name in starNames {
                    if let node = scene.rootNode.childNode(withName: name, recursively: false), let particleSystem = node.particleSystems?.first {
                        particleSystem.particleIntensity = 1.0
                        particleSystem.particleIntensityVariation = 0.05
                        particleSystem.particleColor = particleColor
                        particleSystem.particleColorVariation = SCNVector4Make(0.07, 0.0, 0.1, 0.0)
                        node.isHidden = false
                        
                        if let propertyControllers = particleSystem.propertyControllers, let sizeController = propertyControllers[.size], let colorController = propertyControllers[.color] {
                            let animation = CAKeyframeAnimation()
                            if let existing = colorController.animation as? CAKeyframeAnimation {
                                animation.keyTimes = existing.keyTimes
                                animation.values = existing.values?.compactMap { ($0 as? UIColor)?.alpha } ?? []
                            } else {
                                animation.values = [ 0.0, 1.0, 1.0, 0.0 ]
                            }
                            let opacityController = SCNParticlePropertyController(animation: animation)
                            particleSystem.propertyControllers = [
                                .size: sizeController,
                                .opacity: opacityController
                            ]
                        }
                    }
                }
                
                for name in names {
                    if let node = scene.rootNode.childNode(withName: name, recursively: false), let particleSystem = node.particleSystems?.first {
                        particleSystem.particleIntensity = min(1.0, 2.0 * particleSystem.particleIntensity)
                        particleSystem.particleIntensityVariation = 0.05
                        particleSystem.particleColor = particleColor
                        particleSystem.particleColorVariation = SCNVector4Make(0.1, 0.0, 0.12, 0.0)
                       
                                                
                        if let propertyControllers = particleSystem.propertyControllers, let sizeController = propertyControllers[.size], let colorController = propertyControllers[.color] {
                            let animation = CAKeyframeAnimation()
                            if let existing = colorController.animation as? CAKeyframeAnimation {
                                animation.keyTimes = existing.keyTimes
                                animation.values = existing.values?.compactMap { ($0 as? UIColor)?.alpha } ?? []
                            } else {
                                animation.values = [ 0.0, 1.0, 1.0, 0.0 ]
                            }
                            let opacityController = SCNParticlePropertyController(animation: animation)
                            particleSystem.propertyControllers = [
                                .size: sizeController,
                                .opacity: opacityController
                            ]
                        }
                    }
                }

                self.didSetReady = true
                self._ready.set(.single(true))
                self.onReady()
            } else {
                let _ = self.sceneView.snapshot()
            }
        }
        
        private var didSetReady = false
        public func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            if !self.didSetReady {
                self.didSetReady = true
                
                Queue.mainQueue().justDispatch {
                    self._ready.set(.single(true))
                    self.onReady()
                }
            }
        }
        
        private func onReady() {            
            self.playAppearanceAnimation(explode: true)
            
            self.previousInteractionTimestamp = CACurrentMediaTime()
            self.timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                if let strongSelf = self, strongSelf.hasIdleAnimations {
                    let currentTimestamp = CACurrentMediaTime()
                    if currentTimestamp > strongSelf.previousInteractionTimestamp + 5.0 {
                        strongSelf.playAppearanceAnimation()
                    }
                }
            }, queue: Queue.mainQueue())
            self.timer?.start()
        }
                
        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
            guard let scene = self.sceneView.scene else {
                return
            }
            
            let currentTime = CACurrentMediaTime()
            self.previousInteractionTimestamp = currentTime
            self.delayTapsTill = currentTime + 0.85
            
            if explode, let node = scene.rootNode.childNode(withName: "swirl", recursively: false), let particlesLeft = scene.rootNode.childNode(withName: "particles_left", recursively: false), let particlesRight = scene.rootNode.childNode(withName: "particles_right", recursively: false), let particlesBottomLeft = scene.rootNode.childNode(withName: "particles_left_bottom", recursively: false), let particlesBottomRight = scene.rootNode.childNode(withName: "particles_right_bottom", recursively: false) {
                if let leftParticleSystem = particlesLeft.particleSystems?.first, let rightParticleSystem = particlesRight.particleSystems?.first, let leftBottomParticleSystem = particlesBottomLeft.particleSystems?.first, let rightBottomParticleSystem = particlesBottomRight.particleSystems?.first {
                    leftParticleSystem.speedFactor = 2.0
                    leftParticleSystem.particleVelocity = 1.6
                    leftParticleSystem.birthRate = 60.0
                    leftParticleSystem.particleLifeSpan = 4.0
                    
                    rightParticleSystem.speedFactor = 2.0
                    rightParticleSystem.particleVelocity = 1.6
                    rightParticleSystem.birthRate = 60.0
                    rightParticleSystem.particleLifeSpan = 4.0
                    
//                    leftBottomParticleSystem.speedFactor = 2.0
                    leftBottomParticleSystem.particleVelocity = 1.6
                    leftBottomParticleSystem.birthRate = 24.0
                    leftBottomParticleSystem.particleLifeSpan = 7.0
                    
//                    rightBottomParticleSystem.speedFactor = 2.0
                    rightBottomParticleSystem.particleVelocity = 1.6
                    rightBottomParticleSystem.birthRate = 24.0
                    rightBottomParticleSystem.particleLifeSpan = 7.0
                    
                    node.physicsField?.isActive = true
                    Queue.mainQueue().after(1.0) {
                        node.physicsField?.isActive = false
                        
                        leftParticleSystem.birthRate = 12.0
                        leftParticleSystem.particleVelocity = 1.2
                        leftParticleSystem.particleLifeSpan = 3.0
                        
                        rightParticleSystem.birthRate = 12.0
                        rightParticleSystem.particleVelocity = 1.2
                        rightParticleSystem.particleLifeSpan = 3.0
                        
                        leftBottomParticleSystem.particleVelocity = 1.2
                        leftBottomParticleSystem.birthRate = 7.0
                        leftBottomParticleSystem.particleLifeSpan = 5.0
                        
                        rightBottomParticleSystem.particleVelocity = 1.2
                        rightBottomParticleSystem.birthRate = 7.0
                        rightBottomParticleSystem.particleLifeSpan = 5.0
                        
                        let leftAnimation = POPBasicAnimation()
                        leftAnimation.property = (POPAnimatableProperty.property(withName: "speedFactor", initializer: { property in
                            property?.readBlock = { particleSystem, values in
                                values?.pointee = (particleSystem as! SCNParticleSystem).speedFactor
                            }
                            property?.writeBlock = { particleSystem, values in
                                (particleSystem as! SCNParticleSystem).speedFactor = values!.pointee
                            }
                            property?.threshold = 0.01
                        }) as! POPAnimatableProperty)
                        leftAnimation.fromValue = 1.2 as NSNumber
                        leftAnimation.toValue = 0.85 as NSNumber
                        leftAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                        leftAnimation.duration = 0.5
                        leftParticleSystem.pop_add(leftAnimation, forKey: "speedFactor")
                        
                        let rightAnimation = POPBasicAnimation()
                        rightAnimation.property = (POPAnimatableProperty.property(withName: "speedFactor", initializer: { property in
                            property?.readBlock = { particleSystem, values in
                                values?.pointee = (particleSystem as! SCNParticleSystem).speedFactor
                            }
                            property?.writeBlock = { particleSystem, values in
                                (particleSystem as! SCNParticleSystem).speedFactor = values!.pointee
                            }
                            property?.threshold = 0.01
                        }) as! POPAnimatableProperty)
                        rightAnimation.fromValue = 1.2 as NSNumber
                        rightAnimation.toValue = 0.85 as NSNumber
                        rightAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                        rightAnimation.duration = 0.5
                        rightParticleSystem.pop_add(rightAnimation, forKey: "speedFactor")
                    }
                }
            }
        }
        
        func update(component: GiftAvatarComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            self.setup()
            
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            if self.sceneView.superview == self {
                self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0 + (component.offset ?? 0.0))
            }
            
            self.hasIdleAnimations = component.hasIdleAnimations
            
            if let _ = component.color {
                self.sceneView.backgroundColor = component.theme.list.blocksBackgroundColor
            }
            
            if let photo = component.photo {
                let imageNode: TransformImageNode
                if let current = self.imageNode {
                    imageNode = current
                } else {
                    imageNode = TransformImageNode()
                    imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
                    self.addSubview(imageNode.view)
                    self.imageNode = imageNode
                    
                    imageNode.setSignal(chatWebFileImage(account: component.context.account, file: photo))
                    self.fetchDisposable.set(chatMessageWebFileInteractiveFetched(account: component.context.account, userLocation: .other, image: photo).startStrict())
                }
                                
                let imageSize = CGSize(width: component.avatarSize, height: component.avatarSize)
                imageNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - imageSize.width) / 2.0), y: 113.0 - imageSize.height / 2.0), size: imageSize)
                
                imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: imageSize.width / 2.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
                
                self.avatarNode.isHidden = true
            } else if component.peers.count > 1 {
                let avatarSize = CGSize(width: 60.0, height: 60.0)
                
                let mergedAvatarsNode: MergedAvatarsNode
                if let current = self.mergedAvatarsNode {
                    mergedAvatarsNode = current
                } else {
                    mergedAvatarsNode = MergedAvatarsNode()
                    mergedAvatarsNode.isUserInteractionEnabled = false
                    self.addSubview(mergedAvatarsNode.view)
                    self.mergedAvatarsNode = mergedAvatarsNode
                }
                
                mergedAvatarsNode.update(context: component.context, peers: Array(component.peers.map { $0._asPeer() }.prefix(3)), synchronousLoad: false, imageSize: avatarSize.width, imageSpacing: 30.0, borderWidth: 2.0, avatarFontSize: 26.0)
                let avatarsSize = CGSize(width: avatarSize.width + 30.0 * CGFloat(min(3, component.peers.count) - 1), height: avatarSize.height)
                mergedAvatarsNode.updateLayout(size: avatarsSize)
                mergedAvatarsNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - avatarsSize.width) / 2.0), y: 113.0 - avatarSize.height / 2.0), size: avatarsSize)
                self.avatarNode.isHidden = true
            } else {
                self.mergedAvatarsNode?.view.removeFromSuperview()
                self.mergedAvatarsNode = nil
                self.avatarNode.isHidden = false
                
                let avatarSize = CGSize(width: component.avatarSize, height: component.avatarSize)
                if let peer = component.peers.first {
                    self.avatarNode.setSignal(peerAvatarCompleteImage(account: component.context.account, peer: peer, size: avatarSize, font: avatarPlaceholderFont(size: 43.0), fullSize: true))
                }
                self.avatarNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - avatarSize.width) / 2.0), y: 113.0 - avatarSize.height / 2.0), size: avatarSize)
            }
            
            if component.peers.count > 3 {
                let badgeTextSize = self.badge.update(
                    transition: .immediate,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: "+\(component.peers.count - 3)", font: Font.with(size: 10.0, design: .round, weight: .semibold), textColor: component.theme.list.itemCheckColors.foregroundColor))
                        )
                    ),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                )
                
                let lineWidth = 1.0 + UIScreenPixel
                let badgeSize = CGSize(width: max(17.0, badgeTextSize.width + 7.0) + lineWidth * 2.0, height: 17.0 + lineWidth * 2.0)
                let _ = self.badgeBackground.update(
                    transition: .immediate,
                    component: AnyComponent(
                        RoundedRectangle(color: component.theme.list.itemCheckColors.fillColor, cornerRadius: badgeSize.height / 2.0, stroke: lineWidth, strokeColor: component.theme.list.blocksBackgroundColor)
                    ),
                    environment: {},
                    containerSize: badgeSize
                )
                
                if let badgeTextView = self.badge.view, let badgeBackgroundView = self.badgeBackground.view {
                    if badgeBackgroundView.superview == nil {
                        self.addSubview(badgeBackgroundView)
                        self.addSubview(badgeTextView)
                    }
                    
                    let avatarsSize = CGSize(width: 120.0, height: 60.0)
                    let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width + avatarsSize.width) / 2.0) - 19.0 - lineWidth, y: 113.0 + avatarsSize.height / 2.0 - 15.0 - lineWidth), size: badgeSize)
                    badgeBackgroundView.frame = backgroundFrame
                    badgeTextView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeTextSize.width / 2.0), y: floorToScreenPixels(backgroundFrame.midY - badgeTextSize.height / 2.0) - UIScreenPixel), size: badgeTextSize)
                }
            } else {
                self.badge.view?.removeFromSuperview()
                self.badgeBackground.view?.removeFromSuperview()
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
