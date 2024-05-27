import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import ComponentFlow
import TelegramPresentationData
import PhotoResources
import AvatarNode
import AccountContext

final class StarsParticlesView: UIView {
    private struct Particle {
        var trackIndex: Int
        var position: CGPoint
        var scale: CGFloat
        var alpha: CGFloat
        var direction: CGPoint
        var velocity: CGFloat
        var color: UIColor
        var currentTime: CGFloat
        var lifeTime: CGFloat
        
        init(
            trackIndex: Int,
            position: CGPoint,
            scale: CGFloat,
            alpha: CGFloat,
            direction: CGPoint,
            velocity: CGFloat,
            color: UIColor,
            currentTime: CGFloat,
            lifeTime: CGFloat
        ) {
            self.trackIndex = trackIndex
            self.position = position
            self.scale = scale
            self.alpha = alpha
            self.direction = direction
            self.velocity = velocity
            self.color = color
            self.currentTime = currentTime
            self.lifeTime = lifeTime
        }
        
        mutating func update(deltaTime: CGFloat) {
            var position = self.position
            position.x += self.direction.x * self.velocity * deltaTime
            position.y += self.direction.y * self.velocity * deltaTime
            self.position = position
            self.currentTime += deltaTime
        }
    }
    
    private final class ParticleSet {
        private let size: CGSize
        private let large: Bool
        private(set) var particles: [Particle] = []
        
        init(size: CGSize, large: Bool, preAdvance: Bool) {
            self.size = size
            self.large = large
            
            self.generateParticles(preAdvance: preAdvance)
        }
        
        private func generateParticles(preAdvance: Bool) {
            let maxDirections = self.large ? 8 : 80
            
            if self.particles.count < maxDirections {
                var allTrackIndices: [Int] = Array(repeating: 0, count: maxDirections)
                for i in 0 ..< maxDirections {
                    allTrackIndices[i] = i
                }
                var takenIndexCount = 0
                for particle in self.particles {
                    allTrackIndices[particle.trackIndex] = -1
                    takenIndexCount += 1
                }
                var availableTrackIndices: [Int] = []
                availableTrackIndices.reserveCapacity(maxDirections - takenIndexCount)
                for index in allTrackIndices {
                    if index != -1 {
                        availableTrackIndices.append(index)
                    }
                }
                
                if !availableTrackIndices.isEmpty {
                    availableTrackIndices.shuffle()
                    
                    for takeIndex in availableTrackIndices {
                        let directionIndex = takeIndex
                        var angle = (CGFloat(directionIndex % maxDirections) / CGFloat(maxDirections)) * CGFloat.pi * 2.0
                        var alpha = 1.0
                        var lifeTimeMultiplier = 1.0
                        
                        var isUpOrDownSemisphere = false
                        if angle > CGFloat.pi / 7.0 && angle < CGFloat.pi - CGFloat.pi / 7.0 {
                            isUpOrDownSemisphere = true
                        } else if !"".isEmpty, angle > CGFloat.pi + CGFloat.pi / 7.0 && angle < 2.0 * CGFloat.pi - CGFloat.pi / 7.0 {
                            isUpOrDownSemisphere = true
                        }
                        
                        if isUpOrDownSemisphere {
                            if CGFloat.random(in: 0.0 ... 1.0) < 0.2 {
                                lifeTimeMultiplier = 0.3
                            } else {
                                angle += CGFloat.random(in: 0.0 ... 1.0) > 0.5 ? CGFloat.pi / 1.6 : -CGFloat.pi / 1.6
                                angle += CGFloat.random(in: -0.2 ... 0.2)
                                lifeTimeMultiplier = 0.5
                            }
                            if self.large {
                                alpha = 0.0
                            }
                        }
                        if self.large {
                            angle += CGFloat.random(in: -0.5 ... 0.5)
                        }
                        
                        let direction = CGPoint(x: cos(angle), y: sin(angle))
                        let velocity = self.large ? CGFloat.random(in: 15.0 ..< 20.0) : CGFloat.random(in: 20.0 ..< 35.0)
                        let scale = self.large ? CGFloat.random(in: 0.65 ... 0.9) : CGFloat.random(in: 0.65 ... 1.0) * 0.75
                        let lifeTime = (self.large ? CGFloat.random(in: 2.0 ... 3.5) : CGFloat.random(in: 0.7 ... 3.0))
                        
                        var position = CGPoint(x: self.size.width / 2.0, y: self.size.height / 2.0)
                        var initialOffset: CGFloat = 0.5
                        if preAdvance {
                            initialOffset = CGFloat.random(in: 0.5 ... 1.0)
                        } else {
                            let p = CGFloat.random(in: 0.0 ... 1.0)
                            if p < 0.5 {
                                initialOffset = CGFloat.random(in: 0.65 ... 1.0)
                            } else {
                                initialOffset = 0.5
                            }
                        }
                        position.x += direction.x * initialOffset * 105.0
                        position.y += direction.y * initialOffset * 105.0
                   
                        let largeColors: [UInt32] = [0xff9145, 0xfec007, 0xed9303]
                        let smallColors: [UInt32] = [0xfecc14, 0xf7ab04, 0xff9145, 0xfdda21]
                        
                        let particle = Particle(
                            trackIndex: directionIndex,
                            position: position,
                            scale: scale,
                            alpha: alpha,
                            direction: direction,
                            velocity: velocity,
                            color: UIColor(rgb: (self.large ? largeColors : smallColors).randomElement()!),
                            currentTime: 0.0,
                            lifeTime: lifeTime * lifeTimeMultiplier
                        )
                        self.particles.append(particle)
                    }
                }
            }
        }
        
        func update(deltaTime: CGFloat) {
            for i in (0 ..< self.particles.count).reversed() {
                self.particles[i].update(deltaTime: deltaTime)
                if self.particles[i].currentTime > self.particles[i].lifeTime {
                    self.particles.remove(at: i)
                }
            }
            
            self.generateParticles(preAdvance: false)
        }
    }
    
    private var displayLink: SharedDisplayLinkDriver.Link?
    
    private var particleSet: ParticleSet?
    private let particleImage: UIImage
    private var particleLayers: [SimpleLayer] = []
    
    private var size: CGSize?
    private let large: Bool
        
    init(size: CGSize, large: Bool) {
        if large {
            self.particleImage = generateTintedImage(image: UIImage(bundleImageName: "Peer Info/PremiumIcon"), color: .white)!.withRenderingMode(.alwaysTemplate)
        } else {
            self.particleImage = generateTintedImage(image: UIImage(bundleImageName: "Premium/Stars/Particle"), color: .white)!.withRenderingMode(.alwaysTemplate)
        }
        
        self.large = large
        
        super.init(frame: .zero)
        
        self.particleSet = ParticleSet(size: size, large: large, preAdvance: true)
        
        self.displayLink = SharedDisplayLinkDriver.shared.add(framesPerSecond: .max, { [weak self] delta in
            self?.update(deltaTime: CGFloat(delta))
        })
    }

    required init?(coder: NSCoder) {
        preconditionFailure()
    }
    
    fileprivate func update(size: CGSize) {
        self.size = size
    }
    
    private func update(deltaTime: CGFloat) {
        guard let particleSet = self.particleSet else {
            return
        }
        particleSet.update(deltaTime: deltaTime)
        
        for i in 0 ..< particleSet.particles.count {
            let particle = particleSet.particles[i]
            
            let particleLayer: SimpleLayer
            if i < self.particleLayers.count {
                particleLayer = self.particleLayers[i]
                particleLayer.isHidden = false
            } else {
                particleLayer = SimpleLayer()
                particleLayer.contents = self.particleImage.cgImage
                particleLayer.bounds = CGRect(origin: CGPoint(), size: particleImage.size)
                self.particleLayers.append(particleLayer)
                self.layer.addSublayer(particleLayer)
            }
            
            particleLayer.layerTintColor = particle.color.cgColor
            
            particleLayer.position = particle.position
            particleLayer.opacity = Float(particle.alpha)
            
            let particleScale = min(1.0, particle.currentTime / 0.3) * min(1.0, (particle.lifeTime - particle.currentTime) / 0.2) * particle.scale
            particleLayer.transform = CATransform3DMakeScale(particleScale, particleScale, 1.0)
        }
        if particleSet.particles.count < self.particleLayers.count {
            for i in particleSet.particles.count ..< self.particleLayers.count {
                self.particleLayers[i].isHidden = true
            }
        }
    }
}

public final class StarsImageComponent: Component {
    public enum Subject: Equatable {
        case none
        case photo(TelegramMediaWebFile)
        case transactionPeer(StarsContext.State.Transaction.Peer)
    }
    
    public let context: AccountContext
    public let subject: Subject
    public let theme: PresentationTheme
    public let diameter: CGFloat
    
    public init(
        context: AccountContext,
        subject: Subject,
        theme: PresentationTheme,
        diameter: CGFloat
    ) {
        self.context = context
        self.subject = subject
        self.theme = theme
        self.diameter = diameter
    }
    
    public static func ==(lhs: StarsImageComponent, rhs: StarsImageComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.diameter != rhs.diameter {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: StarsImageComponent?
        
        private var smallParticlesView: StarsParticlesView?
        private var largeParticlesView: StarsParticlesView?
        
        private var imageNode: TransformImageNode?
        private var avatarNode: ImageNode?
        private var iconBackgroundView: UIImageView?
        private var iconView: UIImageView?
        
        private let fetchDisposable = MetaDisposable()
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        deinit {
            self.fetchDisposable.dispose()
        }
        
        func update(component: StarsImageComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.component = component
            
            let smallParticlesView: StarsParticlesView
            if let current = self.smallParticlesView {
                smallParticlesView = current
            } else {
                smallParticlesView = StarsParticlesView(size: availableSize, large: false)
                
                self.addSubview(smallParticlesView)
                self.smallParticlesView = smallParticlesView
            }
            smallParticlesView.update(size: availableSize)
            smallParticlesView.frame = CGRect(origin: .zero, size: availableSize)
            
            let largeParticlesView: StarsParticlesView
            if let current = self.largeParticlesView {
                largeParticlesView = current
            } else {
                largeParticlesView = StarsParticlesView(size: availableSize, large: true)
                
                self.addSubview(largeParticlesView)
                self.largeParticlesView = largeParticlesView
            }
            largeParticlesView.update(size: availableSize)
            largeParticlesView.frame = CGRect(origin: .zero, size: availableSize)
            
            let imageSize = CGSize(width: component.diameter, height: component.diameter)
            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - imageSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - imageSize.height) / 2.0)), size: imageSize)
            
            switch component.subject {
            case .none:
                break
            case let .photo(photo):
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

                imageNode.frame = imageFrame
                imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: imageSize.width / 2.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
            case let .transactionPeer(peer):
                if case let .peer(peer) = peer {
                    let avatarNode: ImageNode
                    if let current = self.avatarNode {
                        avatarNode = current
                    } else {
                        avatarNode = ImageNode()
                        avatarNode.displaysAsynchronously = false
                        self.addSubview(avatarNode.view)
                        self.avatarNode = avatarNode
                        
                        avatarNode.setSignal(peerAvatarCompleteImage(account: component.context.account, peer: peer, size: imageSize, font: avatarPlaceholderFont(size: 43.0), fullSize: true))
                    }
                    avatarNode.frame = imageFrame
                } else {
                    let iconBackgroundView: UIImageView
                    let iconView: UIImageView
                    if let currentBackground = self.iconBackgroundView, let current = self.iconView {
                        iconBackgroundView = currentBackground
                        iconView = current
                    } else {
                        iconBackgroundView = UIImageView()
                        iconView = UIImageView()
                        
                        self.addSubview(iconBackgroundView)
                        self.addSubview(iconView)
                        
                        self.iconBackgroundView = iconBackgroundView
                        self.iconView = iconView
                    }
                    
                    var iconInset: CGFloat = 9.0
                    var iconOffset: CGFloat = 0.0
                    switch peer {
                    case .appStore:
                        iconBackgroundView.image = generateGradientFilledCircleImage(
                            diameter: imageSize.width,
                            colors: [
                                UIColor(rgb: 0x2a9ef1).cgColor,
                                UIColor(rgb: 0x72d5fd).cgColor
                            ],
                            direction: .mirroredDiagonal
                        )
                        iconView.image = UIImage(bundleImageName: "Premium/Stars/Apple")
                    case .playMarket:
                        iconBackgroundView.image = generateGradientFilledCircleImage(
                            diameter: imageSize.width,
                            colors: [
                                UIColor(rgb: 0x54cb68).cgColor,
                                UIColor(rgb: 0xa0de7e).cgColor
                            ],
                            direction: .mirroredDiagonal
                        )
                        iconView.image = UIImage(bundleImageName: "Premium/Stars/Google")
                    case .fragment:
                        iconBackgroundView.image = generateFilledCircleImage(
                            diameter: imageSize.width,
                            color: UIColor(rgb: 0x1b1f24)
                        )
                        iconView.image = UIImage(bundleImageName: "Premium/Stars/Fragment")
                        iconOffset = 5.0
                    case .premiumBot:
                        iconInset = 15.0
                        iconBackgroundView.image = generateGradientFilledCircleImage(
                            diameter: imageSize.width,
                            colors: [
                                UIColor(rgb: 0x6b93ff).cgColor,
                                UIColor(rgb: 0x6b93ff).cgColor,
                                UIColor(rgb: 0x8d77ff).cgColor,
                                UIColor(rgb: 0xb56eec).cgColor,
                                UIColor(rgb: 0xb56eec).cgColor
                            ],
                            direction: .mirroredDiagonal
                        )
                        iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon"), color: .white)
                    case .peer, .unsupported:
                        iconInset = 15.0
                        iconBackgroundView.image = generateGradientFilledCircleImage(
                            diameter: imageSize.width,
                            colors: [
                                UIColor(rgb: 0xb1b1b1).cgColor,
                                UIColor(rgb: 0xcdcdcd).cgColor
                            ],
                            direction: .mirroredDiagonal
                        )
                        iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat/Input/Media/EntityInputPremiumIcon"), color: .white)
                    }
                    iconBackgroundView.frame = imageFrame
                    iconView.frame = imageFrame.insetBy(dx: iconInset, dy: iconInset).offsetBy(dx: 0.0, dy: iconOffset)
                }
            }
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}
