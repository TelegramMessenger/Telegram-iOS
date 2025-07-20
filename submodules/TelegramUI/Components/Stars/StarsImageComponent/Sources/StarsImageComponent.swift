import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import Postbox
import TelegramCore
import ComponentFlow
import TelegramPresentationData
import PhotoResources
import AvatarNode
import AccountContext
import InvisibleInkDustNode
import AnimatedStickerNode
import TelegramAnimatedStickerNode

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
                particleLayer.bounds = CGRect(origin: CGPoint(), size: self.particleImage.size)
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
        case media([AnyMediaReference])
        case extendedMedia([TelegramExtendedMedia])
        case transactionPeer(StarsContext.State.Transaction.Peer)
        case gift(Int32)
        case color(UIColor)
        
        public static func == (lhs: StarsImageComponent.Subject, rhs: StarsImageComponent.Subject) -> Bool {
            switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .photo(lhsPhoto):
                if case let .photo(rhsPhoto) = rhs, lhsPhoto == rhsPhoto {
                    return true
                } else {
                    return false
                }
            case let .media(lhsMedia):
                if case let .media(rhsMedia) = rhs, areMediaArraysEqual(lhsMedia.map { $0.media }, rhsMedia.map { $0.media }) {
                    return true
                } else {
                    return false
                }
            case let .extendedMedia(lhsExtendedMedia):
                if case let .extendedMedia(rhsExtendedMedia) = rhs, lhsExtendedMedia == rhsExtendedMedia {
                    return true
                } else {
                    return false
                }
            case let .transactionPeer(lhsPeer):
                if case let .transactionPeer(rhsPeer) = rhs, lhsPeer == rhsPeer {
                    return true
                } else {
                    return false
                }
            case let .gift(lhsCount):
                if case let .gift(rhsCount) = rhs, lhsCount == rhsCount {
                    return true
                } else {
                    return false
                }
            case let .color(lhsColor):
                if case let .color(rhsColor) = rhs, lhsColor == rhsColor {
                    return true
                } else {
                    return false
                }
            }
        }
    }
    
    public enum Icon {
        case star
        case ton
    }
    
    public let context: AccountContext
    public let subject: Subject
    public let theme: PresentationTheme
    public let diameter: CGFloat
    public let backgroundColor: UIColor
    public let icon: Icon?
    public let value: Int64?
    public let action: ((@escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void)?
    
    public init(
        context: AccountContext,
        subject: Subject,
        theme: PresentationTheme,
        diameter: CGFloat,
        backgroundColor: UIColor,
        icon: Icon? = nil,
        value: Int64? = nil,
        action: ((@escaping (Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?, @escaping (UIView) -> Void) -> Void)? = nil
    ) {
        self.context = context
        self.subject = subject
        self.theme = theme
        self.diameter = diameter
        self.backgroundColor = backgroundColor
        self.icon = icon
        self.value = value
        self.action = action
    }
    
    public static func ==(lhs: StarsImageComponent, rhs: StarsImageComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.diameter != rhs.diameter {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.icon != rhs.icon {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private var component: StarsImageComponent?
        private var state: EmptyComponentState?
        
        private var smallParticlesView: StarsParticlesView?
        private var largeParticlesView: StarsParticlesView?
        
        private var containerNode: ASDisplayNode?
        private var imageNode: TransformImageNode?
        private var imageFrameNode: UIView?
        private var secondImageNode: TransformImageNode?
        private var avatarNode: ImageNode?
        private var iconBackgroundView: UIImageView?
        private var iconView: UIImageView?
        private var smallIconOutlineView: UIImageView?
        private var smallIconView: UIImageView?
        private var dustNode: MediaDustNode?
        private var button: UIControl?
        
        private var amountIconView: UIImageView?
        private var amountBackgroundView = ComponentView<Empty>()
        private let amountView = ComponentView<Empty>()
        
        private var animationNode: AnimatedStickerNode?
        
        private var lockView: UIImageView?
        private let countView = ComponentView<Empty>()
        
        private let fetchDisposable = MetaDisposable()
        private var hiddenMediaDisposable: Disposable?
        
        private var hiddenMedia: [Media] = []
        
        public override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            preconditionFailure()
        }
        deinit {
            self.fetchDisposable.dispose()
            self.hiddenMediaDisposable?.dispose()
        }
        
        @objc private func buttonPressed() {
            guard let component = self.component else {
                return
            }
            component.action?({ [weak self] media in
                guard let self else {
                    return nil
                }
                return self.transitionNode(media)
            }, { [weak self] view in
                guard let self else {
                    return
                }
                self.superview?.addSubview(view)
            })
        }
        
        public func transitionNode(_ transitionMedia: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
            guard let component = self.component, let containerNode = self.containerNode else {
                return nil
            }
            if case let .media(media) = component.subject, media.first?.media.id == transitionMedia.id {
                return (containerNode, containerNode.bounds, { [weak containerNode] in
                    return (containerNode?.view.snapshotContentTree(unhide: true), nil)
                })
            }
            return nil
        }
        
        func update(component: StarsImageComponent, state: EmptyComponentState, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
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
            
            let containerNode: ASDisplayNode
            if let current = self.containerNode {
                containerNode = current
            } else {
                containerNode = ASDisplayNode()
                
                self.addSubview(containerNode.view)
                self.containerNode = containerNode
            }
            
            var imageSize = CGSize(width: component.diameter, height: component.diameter)
            let containerFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - imageSize.width) / 2.0), y: floorToScreenPixels((availableSize.height - imageSize.height) / 2.0)), size: imageSize)
            containerNode.frame = containerFrame
            
            if case let .media(media) = component.subject, media.count > 1 {
                imageSize = CGSize(width: component.diameter - 6.0, height: component.diameter - 6.0)
            } else if case let .extendedMedia(media) = component.subject, media.count > 1 {
                imageSize = CGSize(width: component.diameter - 6.0, height: component.diameter - 6.0)
            }
            let imageFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((containerFrame.width - imageSize.width) / 2.0), y: floorToScreenPixels((containerFrame.height - imageSize.height) / 2.0)), size: imageSize)
            
            switch component.subject {
            case .none:
                break
            case let .color(color):
                let imageNode: TransformImageNode
                if let current = self.imageNode {
                    imageNode = current
                } else {
                    imageNode = TransformImageNode()
                    imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
                    containerNode.view.addSubview(imageNode.view)
                    self.imageNode = imageNode
                    
                    imageNode.setSignal(solidColorImage(color))
                }

                imageNode.frame = imageFrame
                imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
            case let .photo(photo):
                let imageNode: TransformImageNode
                if let current = self.imageNode {
                    imageNode = current
                } else {
                    imageNode = TransformImageNode()
                    imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
                    containerNode.view.addSubview(imageNode.view)
                    self.imageNode = imageNode
                    
                    imageNode.setSignal(chatWebFileImage(account: component.context.account, file: photo))
                    self.fetchDisposable.set(chatMessageWebFileInteractiveFetched(account: component.context.account, userLocation: .other, image: photo).startStrict())
                }

                imageNode.frame = imageFrame
                imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: imageSize.width / 2.0), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
            case let .media(media):
                let imageNode: TransformImageNode
                var dimensions = imageSize
                var isFirstTime = false
                if let current = self.imageNode {
                    imageNode = current
                } else {
                    isFirstTime = true
                    imageNode = TransformImageNode()
                    imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
                    containerNode.view.addSubview(imageNode.view)
                    self.imageNode = imageNode
                }
                if let imageReference = media.first?.concrete(TelegramMediaImage.self) {
                    if let imageDimensions = largestImageRepresentation(imageReference.media.representations)?.dimensions {
                        dimensions = imageDimensions.cgSize.aspectFilled(imageSize)
                    }
                    if isFirstTime {
                        imageNode.setSignal(chatMessagePhotoThumbnail(account: component.context.account, userLocation: .other, photoReference: imageReference, onlyFullSize: false, blurred: false))
                    }
                } else if let fileReference = media.first?.concrete(TelegramMediaFile.self) {
                    if let videoDimensions = fileReference.media.dimensions {
                        dimensions = videoDimensions.cgSize.aspectFilled(imageSize)
                    }
                    if isFirstTime {
                        imageNode.setSignal(mediaGridMessageVideo(postbox: component.context.account.postbox, userLocation: .other, videoReference: fileReference, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true))
                    }
                }
                imageNode.frame = imageFrame
                imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: dimensions, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
                
                if let firstMedia = media.first?.media, self.hiddenMedia.contains(where: { $0.id == firstMedia.id }) {
                    containerNode.isHidden = true
                } else {
                    containerNode.isHidden = false
                }
                
                if media.count > 1 {
                    let secondImageNode: TransformImageNode
                    let imageFrameNode: UIView
                    var secondDimensions = imageSize
                    if let current = self.secondImageNode, let currentFrame = self.imageFrameNode {
                        secondImageNode = current
                        imageFrameNode = currentFrame
                    } else {
                        secondImageNode = TransformImageNode()
                        secondImageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
                        containerNode.view.insertSubview(secondImageNode.view, belowSubview: imageNode.view)
                        self.secondImageNode = secondImageNode
                        
                        imageFrameNode = UIView()
                        imageFrameNode.layer.cornerRadius = 17.0
                        containerNode.view.insertSubview(imageFrameNode, belowSubview: imageNode.view)
                        self.imageFrameNode = imageFrameNode
                    }
                    
                    if let imageReference = media[1].concrete(TelegramMediaImage.self) {
                        if let imageDimensions = largestImageRepresentation(imageReference.media.representations)?.dimensions {
                            secondDimensions = imageDimensions.cgSize.aspectFilled(imageSize)
                        }
                        if isFirstTime {
                            secondImageNode.setSignal(chatMessagePhotoThumbnail(account: component.context.account, userLocation: .other, photoReference: imageReference, onlyFullSize: false, blurred: false))
                        }
                    } else if let fileReference = media[1].concrete(TelegramMediaFile.self) {
                        if let videoDimensions = fileReference.media.dimensions {
                            secondDimensions = videoDimensions.cgSize.aspectFilled(imageSize)
                        }
                        if isFirstTime {
                            secondImageNode.setSignal(mediaGridMessageVideo(postbox: component.context.account.postbox, userLocation: .other, videoReference: fileReference, useLargeThumbnail: true, autoFetchFullSizeThumbnail: true))
                        }
                    }
                    
                    imageFrameNode.backgroundColor = component.backgroundColor
                    secondImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: secondDimensions, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
                    secondImageNode.frame = imageFrame.offsetBy(dx: 6.0, dy: -6.0)
                    imageFrameNode.frame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                    
                    let countSize = self.countView.update(
                        transition: .immediate,
                        component: AnyComponent(
                            Text(text: "\(media.count)", font: Font.with(size: 30.0, design: .round, weight: .medium), color: .white)
                        ),
                        environment: {},
                        containerSize: imageFrame.size
                    )
                    let countFrame = CGRect(origin: CGPoint(x: imageFrame.minX + floorToScreenPixels((imageFrame.width - countSize.width) / 2.0), y: imageFrame.minY + floorToScreenPixels((imageFrame.height - countSize.height) / 2.0)), size: countSize)
                    if let countView = self.countView.view {
                        if countView.superview == nil {
                            containerNode.view.addSubview(countView)
                        }
                        countView.frame = countFrame
                    }
                }
            case let .extendedMedia(extendedMedia):
                let imageNode: TransformImageNode
                let dustNode: MediaDustNode
                var dimensions = imageSize
                var isFirstTime = false
                if let current = self.imageNode, let currentDust = self.dustNode {
                    imageNode = current
                    dustNode = currentDust
                } else {
                    isFirstTime = true
                    imageNode = TransformImageNode()
                    imageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
                    containerNode.view.addSubview(imageNode.view)
                    self.imageNode = imageNode
                                                                                
                    dustNode = MediaDustNode(enableAnimations: true)
                    dustNode.isUserInteractionEnabled = false
                    containerNode.view.addSubview(dustNode.view)
                    self.dustNode = dustNode
                }
                
                let media: TelegramMediaImage
                switch extendedMedia.first {
                case let .preview(imageDimensions, immediateThumbnailData, _):
                    let thumbnailMedia = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [], immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                    media = thumbnailMedia
                    if let imageDimensions {
                        dimensions = imageDimensions.cgSize.aspectFilled(imageSize)
                    }
                default:
                    fatalError()
                }
                if isFirstTime {
                    imageNode.setSignal(chatSecretPhoto(account: component.context.account, userLocation: .other, photoReference: .standalone(media: media), ignoreFullSize: true, synchronousLoad: true))
                }
                
                imageNode.frame = imageFrame
                imageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: dimensions, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
                
                dustNode.frame = imageFrame
                dustNode.update(size: imageFrame.size, color: .white, transition: .immediate)

                if extendedMedia.count > 1 {
                    let secondImageNode: TransformImageNode
                    let imageFrameNode: UIView
                    var secondDimensions = imageSize
                    var isFirstTime = false
                    if let current = self.secondImageNode, let currentFrame = self.imageFrameNode {
                        secondImageNode = current
                        imageFrameNode = currentFrame
                    } else {
                        isFirstTime = true
                        secondImageNode = TransformImageNode()
                        secondImageNode.contentAnimations = [.firstUpdate, .subsequentUpdates]
                        containerNode.view.insertSubview(secondImageNode.view, belowSubview: imageNode.view)
                        self.secondImageNode = secondImageNode
                        
                        imageFrameNode = UIView()
                        imageFrameNode.layer.cornerRadius = 17.0
                        containerNode.view.insertSubview(imageFrameNode, belowSubview: imageNode.view)
                        self.imageFrameNode = imageFrameNode
                    }
                    
                    let media: TelegramMediaImage
                    switch extendedMedia[1] {
                    case let .preview(imageDimensions, immediateThumbnailData, _):
                        let thumbnailMedia = TelegramMediaImage(imageId: MediaId(namespace: 0, id: 0), representations: [], immediateThumbnailData: immediateThumbnailData, reference: nil, partialReference: nil, flags: [])
                        media = thumbnailMedia
                        if let imageDimensions {
                            secondDimensions = imageDimensions.cgSize.aspectFilled(imageSize)
                        }
                    default:
                        fatalError()
                    }
                            
                    if isFirstTime {
                        secondImageNode.setSignal(chatSecretPhoto(account: component.context.account, userLocation: .other, photoReference: .standalone(media: media), ignoreFullSize: true, synchronousLoad: true))
                    }
                    
                    imageFrameNode.backgroundColor = component.backgroundColor
                    secondImageNode.asyncLayout()(TransformImageArguments(corners: ImageCorners(radius: 16.0), imageSize: secondDimensions, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets(), emptyColor: component.theme.list.mediaPlaceholderColor))()
                    secondImageNode.frame = imageFrame.offsetBy(dx: 6.0, dy: -6.0)
                    imageFrameNode.frame = imageFrame.insetBy(dx: -2.0, dy: -2.0)
                }
                
                var totalLabelWidth: CGFloat = 0.0
                let labelSpacing: CGFloat = 4.0
                let lockView: UIImageView
                if let current = self.lockView {
                    lockView = current
                } else {
                    lockView = UIImageView(image: UIImage(bundleImageName: "Premium/Stars/MediaLock"))
                    containerNode.view.addSubview(lockView)
                }
                if let icon = lockView.image {
                    totalLabelWidth += icon.size.width
                }
                
                if extendedMedia.count > 1 {
                    let countSize = self.countView.update(
                        transition: .immediate,
                        component: AnyComponent(
                            Text(text: "\(extendedMedia.count)", font: Font.with(size: 30.0, design: .round, weight: .medium), color: .white)
                        ),
                        environment: {},
                        containerSize: imageFrame.size
                    )
                    let iconWidth = totalLabelWidth
                    totalLabelWidth += countSize.width + labelSpacing
                    let countFrame = CGRect(origin: CGPoint(x: imageFrame.minX + floorToScreenPixels((imageFrame.width - totalLabelWidth) / 2.0) + iconWidth + labelSpacing, y: imageFrame.minY + floorToScreenPixels((imageFrame.height - countSize.height) / 2.0)), size: countSize)
                    if let countView = self.countView.view {
                        if countView.superview == nil {
                            containerNode.view.addSubview(countView)
                        }
                        countView.frame = countFrame
                    }
                }
                
                lockView.frame = CGRect(origin: CGPoint(x: imageFrame.minX + floorToScreenPixels((imageFrame.width - totalLabelWidth) / 2.0), y: imageFrame.minY + floorToScreenPixels((imageFrame.height - lockView.bounds.height) / 2.0)), size: lockView.bounds.size)
            case let .transactionPeer(peer):
                if case let .peer(peer) = peer {
                    let avatarNode: ImageNode
                    if let current = self.avatarNode {
                        avatarNode = current
                    } else {
                        avatarNode = ImageNode()
                        avatarNode.displaysAsynchronously = false
                        if let smallIconOutlineView = self.smallIconOutlineView {
                            containerNode.view.insertSubview(avatarNode.view, belowSubview: smallIconOutlineView)
                        } else {
                            containerNode.view.addSubview(avatarNode.view)
                        }
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
                        
                        containerNode.view.addSubview(iconBackgroundView)
                        containerNode.view.addSubview(iconView)
                        
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
                    case .ads:
                        iconBackgroundView.image = generateGradientFilledCircleImage(
                            diameter: imageSize.width,
                            colors: [
                                UIColor(rgb: 0xffa85c).cgColor,
                                UIColor(rgb: 0xffcd6a).cgColor
                            ],
                            direction: .mirroredDiagonal
                        )
                        iconView.image = generateTintedImage(image: UIImage(bundleImageName: "Chat List/Filters/Channel"), color: .white)
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
                    case .apiLimitExtension:
                        iconBackgroundView.image = generateGradientFilledCircleImage(
                            diameter: imageSize.width,
                            colors: [
                                UIColor(rgb: 0x32b83b).cgColor,
                                UIColor(rgb: 0x87d93b).cgColor
                            ],
                            direction: .vertical
                        )
                        iconView.image = UIImage(bundleImageName: "Premium/Stars/PaidBroadcast")
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
            case let .gift(count):
                let animationNode: AnimatedStickerNode
                if let current = self.animationNode {
                    animationNode = current
                } else {
                    let animationName: String
                    switch count {
                    case 1000:
                        animationName = "GiftDiamond1"
                    case 2000:
                        animationName = "GiftDiamond2"
                    case 3000:
                        animationName = "GiftDiamond3"
                    case 12:
                        animationName = "Gift12"
                    case 6:
                        animationName = "Gift6"
                    case 3:
                        animationName = "Gift3"
                    default:
                        animationName = "Gift3"
                    }
                    animationNode = DefaultAnimatedStickerNodeImpl()
                    animationNode.autoplay = true
                    animationNode.setup(source: AnimatedStickerNodeLocalFileSource(name: animationName), width: 384, height: 384, playbackMode: .still(.end), mode: .direct(cachePathPrefix: nil))
                    animationNode.visibility = true
                    containerNode.view.addSubview(animationNode.view)
                    self.animationNode = animationNode
                    
                    animationNode.playOnce()
                }
                let animationFrame = imageFrame.insetBy(dx: -imageFrame.width * 0.19, dy: -imageFrame.height * 0.19).offsetBy(dx: 0.0, dy: -14.0)
                animationNode.frame = animationFrame
                animationNode.updateLayout(size: animationFrame.size)
            }
            
            if let icon = component.icon {
                let smallIconView: UIImageView
                let smallIconOutlineView: UIImageView
                if let current = self.smallIconView, let currentOutline = self.smallIconOutlineView {
                    smallIconView = current
                    smallIconOutlineView = currentOutline
                } else {
                    smallIconOutlineView = UIImageView()
                    containerNode.view.addSubview(smallIconOutlineView)
                    self.smallIconOutlineView = smallIconOutlineView
                    
                    smallIconView = UIImageView()
                    containerNode.view.addSubview(smallIconView)
                    self.smallIconView = smallIconView
                    
                    switch icon {
                    case .star:
                        smallIconOutlineView.image = UIImage(bundleImageName: "Premium/Stars/TransactionStarOutline")?.withRenderingMode(.alwaysTemplate)
                        smallIconView.image = UIImage(bundleImageName: "Premium/Stars/TransactionStar")
                    case .ton:
                        smallIconOutlineView.image = UIImage(bundleImageName: "Ads/TonMedium")?.withRenderingMode(.alwaysTemplate)
                        smallIconView.image = UIImage(bundleImageName: "Ads/TonMedium")?.withRenderingMode(.alwaysTemplate)
                    }
                }
                
                smallIconOutlineView.tintColor = component.backgroundColor
                
                if let iconImage = smallIconView.image {
                    let smallIconFrame = CGRect(origin: CGPoint(x: imageFrame.maxX - iconImage.size.width, y: imageFrame.maxY - iconImage.size.height), size: iconImage.size)
                    smallIconView.frame = smallIconFrame
                    switch icon {
                    case .star:
                        smallIconView.tintColor = nil
                    case .ton:
                        smallIconView.tintColor = component.theme.list.itemAccentColor
                    }
                    smallIconOutlineView.frame = smallIconFrame
                }
            } else if let smallIconView = self.smallIconView, let smallIconOutlineView = self.smallIconOutlineView {
                self.smallIconView = nil
                smallIconView.removeFromSuperview()
                self.smallIconOutlineView = nil
                smallIconOutlineView.removeFromSuperview()
            }
            
            if let amount = component.value {
                let smallIconView: UIImageView
                if let current = self.amountIconView {
                    smallIconView = current
                } else {
                    smallIconView = UIImageView()
                    self.amountIconView = smallIconView
                    
                    smallIconView.image = UIImage(bundleImageName: "Premium/SendStarsPeerBadgeStarIcon")?.withRenderingMode(.alwaysTemplate)
                    smallIconView.tintColor = .white
                }
                
                let countSize = self.amountView.update(
                    transition: .immediate,
                    component: AnyComponent(
                        Text(text: "\(amount)", font: Font.with(size: 12.0, design: .round, weight: .bold), color: .white)
                    ),
                    environment: {},
                    containerSize: imageFrame.size
                )
                
                let iconSize = CGSize(width: 11.0, height: 11.0)
                let iconSpacing: CGFloat = 1.0
                
                let totalLabelWidth = iconSize.width + iconSpacing + countSize.width
                let iconFrame = CGRect(origin: CGPoint(x: imageFrame.minX + floorToScreenPixels((imageFrame.width - totalLabelWidth) / 2.0), y: imageFrame.maxY - countSize.height + 4.0), size: iconSize)
                smallIconView.frame = iconFrame
                
                let countFrame = CGRect(origin: CGPoint(x: imageFrame.minX + floorToScreenPixels((imageFrame.width - totalLabelWidth) / 2.0) + iconSize.width + iconSpacing, y: imageFrame.maxY - countSize.height + 2.0), size: countSize)
                       
                let amountBackgroundFrame = CGRect(origin: CGPoint(x: imageFrame.minX + floorToScreenPixels((imageFrame.width - totalLabelWidth) / 2.0) - 7.0, y: imageFrame.maxY - countSize.height - 3.0), size: CGSize(width: totalLabelWidth + 14.0, height: countFrame.height + 10.0))
                
                let _ = self.amountBackgroundView.update(
                    transition: .immediate,
                    component: AnyComponent(
                        RoundedRectangle(colors: [UIColor(rgb: 0xffaa01)], cornerRadius: amountBackgroundFrame.height / 2.0, gradientDirection: .horizontal, stroke: 2.0 - UIScreenPixel, strokeColor: component.backgroundColor, size: amountBackgroundFrame.size)
                    ),
                    environment: {},
                    containerSize: amountBackgroundFrame.size
                )
                if let backgroundView = self.amountBackgroundView.view {
                    if backgroundView.superview == nil {
                        containerNode.view.addSubview(backgroundView)
                    }
                    backgroundView.frame = amountBackgroundFrame
                }
                
                if let countView = self.amountView.view {
                    if countView.superview == nil {
                        containerNode.view.addSubview(countView)
                        containerNode.view.addSubview(smallIconView)
                    }
                    countView.frame = countFrame
                }
            }
            
            if let _ = component.action {
                if self.button == nil {
                    let button = UIControl(frame: imageFrame)
                    button.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
                    containerNode.view.addSubview(button)
                    self.button = button
                }
            } else if let button = self.button {
                self.button = nil
                button.removeFromSuperview()
            }
            
            if case .media = component.subject {
                if self.hiddenMediaDisposable == nil {
                    self.hiddenMediaDisposable = component.context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().startStrict(next: { [weak self] ids in
                        guard let self, let component = self.component else {
                            return
                        }
                        var hiddenMedia: [Media] = []
                        for id in ids {
                            if case let .chat(accountId, _, media) = id, accountId == component.context.account.id {
                                hiddenMedia.append(media)
                            }
                        }
                        self.hiddenMedia = hiddenMedia
                        self.state?.updated()
                    }).strict()
                }
            } else if let hiddenMediaDisposable = self.hiddenMediaDisposable {
                self.hiddenMediaDisposable = nil
                hiddenMediaDisposable.dispose()
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, state: state, availableSize: availableSize, transition: transition)
    }
}
