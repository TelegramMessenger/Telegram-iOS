import Foundation
import UIKit
import Display
import ComponentFlow
import AppBundle
import BundleIconComponent
import AccountContext
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AvatarNode
import ContextUI
import AsyncDisplayKit
import StoryContainerScreen
import MultilineTextComponent

private func calculateCircleIntersection(center: CGPoint, otherCenter: CGPoint, radius: CGFloat) -> (point1Angle: CGFloat, point2Angle: CGFloat)? {
    let distanceVector = CGPoint(x: otherCenter.x - center.x, y: otherCenter.y - center.y)
    let distance = sqrt(distanceVector.x * distanceVector.x + distanceVector.y * distanceVector.y)
    if distance > radius * 2.0 || distance == 0.0 {
        return nil
    }
    
    let x1 = center.x
    let y1 = center.y
    let x2 = otherCenter.x
    let y2 = otherCenter.y
    let r1 = radius
    let r2 = radius
    let R = distance
    
    let ix1: CGFloat = 0.5 * (x1 + x2) + (pow(r1, 2.0) - pow(r2, 2.0)) / (2 * pow(R, 2.0)) * (x2 - x1) + 0.5 * sqrt(2.0 * (pow(r1, 2.0) + pow(r2, 2.0)) / pow(R, 2.0) - pow((pow(r1, 2.0) - pow(r2, 2.0)), 2.0) / pow(R, 4.0) - 1) * (y2 - y1)
    let ix2: CGFloat = 0.5 * (x1 + x2) + (pow(r1, 2.0) - pow(r2, 2.0)) / (2 * pow(R, 2.0)) * (x2 - x1) - 0.5 * sqrt(2.0 * (pow(r1, 2.0) + pow(r2, 2.0)) / pow(R, 2.0) - pow((pow(r1, 2.0) - pow(r2, 2.0)), 2.0) / pow(R, 4.0) - 1) * (y2 - y1)
    
    let iy1: CGFloat = 0.5 * (y1 + y2) + (pow(r1, 2.0) - pow(r2, 2.0)) / (2 * pow(R, 2.0)) * (y2 - y1) + 0.5 * sqrt(2.0 * (pow(r1, 2.0) + pow(r2, 2.0)) / pow(R, 2.0) - pow((pow(r1, 2.0) - pow(r2, 2.0)), 2.0) / pow(R, 4.0) - 1) * (x1 - x2)
    let iy2: CGFloat = 0.5 * (y1 + y2) + (pow(r1, 2.0) - pow(r2, 2.0)) / (2 * pow(R, 2.0)) * (y2 - y1) - 0.5 * sqrt(2.0 * (pow(r1, 2.0) + pow(r2, 2.0)) / pow(R, 2.0) - pow((pow(r1, 2.0) - pow(r2, 2.0)), 2.0) / pow(R, 4.0) - 1) * (x1 - x2)
    
    var v1 = CGPoint(x: ix1 - center.x, y: iy1 - center.y)
    let length1 = sqrt(v1.x * v1.x + v1.y * v1.y)
    v1.x /= length1
    v1.y /= length1
    
    var v2 = CGPoint(x: ix2 - center.x, y: iy2 - center.y)
    let length2 = sqrt(v2.x * v2.x + v2.y * v2.y)
    v2.x /= length2
    v2.y /= length2
    
    var point1Angle = atan(v1.y / v1.x)
    var point2Angle = atan(v2.y / v2.x)
    
    if distanceVector.x < 0.0 {
        point1Angle += CGFloat.pi
        point2Angle += CGFloat.pi
    }
    
    return (point1Angle, point2Angle)
}

private func calculateMergingCircleShape(center: CGPoint, leftCenter: CGPoint?, rightCenter: CGPoint?, radius: CGFloat) -> CGPath {
    let leftAngles = leftCenter.flatMap { calculateCircleIntersection(center: center, otherCenter: $0, radius: radius) }
    let rightAngles = rightCenter.flatMap { calculateCircleIntersection(center: center, otherCenter: $0, radius: radius) }
    
    let path = CGMutablePath()
    
    if let leftAngles, let rightAngles {
        path.addArc(center: center, radius: radius, startAngle: leftAngles.point1Angle, endAngle: rightAngles.point2Angle, clockwise: true)
        
        path.move(to: CGPoint(x: center.x + cos(rightAngles.point1Angle) * radius, y: center.y + sin(rightAngles.point1Angle) * radius))
        path.addArc(center: center, radius: radius, startAngle: rightAngles.point1Angle, endAngle: leftAngles.point2Angle, clockwise: true)
    } else if let angles = leftAngles ?? rightAngles {
        path.addArc(center: center, radius: radius, startAngle: angles.point1Angle, endAngle: angles.point2Angle, clockwise: true)
    } else {
        path.addEllipse(in: CGRect(origin: CGPoint(x: center.x - radius, y: center.y - radius), size: CGSize(width: radius * 2.0, height: radius * 2.0)))
    }
    
    return path
}

private final class StoryProgressLayer: SimpleLayer {
    enum Value: Equatable {
        case indefinite
        case progress(Float)
    }
    
    private struct Params: Equatable {
        var size: CGSize
        var lineWidth: CGFloat
        var value: Value
    }
    private var currentParams: Params?
    
    private let uploadProgressLayer = SimpleShapeLayer()
    
    private let indefiniteDashLayer = SimpleShapeLayer()
    private let indefiniteReplicatorLayer = CAReplicatorLayer()
    
    override init() {
        super.init()
        
        self.uploadProgressLayer.fillColor = nil
        self.uploadProgressLayer.strokeColor = UIColor.white.cgColor
        self.uploadProgressLayer.lineWidth = 2.0
        self.uploadProgressLayer.lineCap = .round
        
        self.indefiniteDashLayer.fillColor = nil
        self.indefiniteDashLayer.strokeColor = UIColor.white.cgColor
        self.indefiniteDashLayer.lineWidth = 2.0
        self.indefiniteDashLayer.lineCap = .round
        self.indefiniteDashLayer.lineJoin = .round
        self.indefiniteDashLayer.strokeEnd = 0.0333
        
        let count = 1.0 / self.indefiniteDashLayer.strokeEnd
        let angle = (2.0 * Double.pi) / Double(count)
        self.indefiniteReplicatorLayer.addSublayer(self.indefiniteDashLayer)
        self.indefiniteReplicatorLayer.instanceCount = Int(count)
        self.indefiniteReplicatorLayer.instanceTransform = CATransform3DMakeRotation(CGFloat(angle), 0.0, 0.0, 1.0)
        self.indefiniteReplicatorLayer.transform = CATransform3DMakeRotation(-.pi / 2.0, 0.0, 0.0, 1.0)
        self.indefiniteReplicatorLayer.instanceDelay = 0.025
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func reset() {
        self.currentParams = nil
        self.indefiniteDashLayer.path = nil
        self.uploadProgressLayer.path = nil
    }
    
    func update(size: CGSize, lineWidth: CGFloat, value: Value, transition: Transition) {
        let params = Params(
            size: size,
            lineWidth: lineWidth,
            value: value
        )
        if self.currentParams == params {
            return
        }
        self.currentParams = params
        
        let lineWidth: CGFloat = 2.0
        let bounds = CGRect(origin: .zero, size: size)
        if self.uploadProgressLayer.path == nil {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(origin: CGPoint(x: lineWidth * 0.5, y: lineWidth * 0.5), size: CGSize(width: size.width - lineWidth, height: size.height - lineWidth)))
            self.uploadProgressLayer.path = path
            self.uploadProgressLayer.frame = bounds
        }
        
        if self.indefiniteDashLayer.path == nil {
            let path = CGMutablePath()
            path.addEllipse(in: CGRect(origin: CGPoint(x: lineWidth * 0.5, y: lineWidth * 0.5), size: CGSize(width: size.width - lineWidth, height: size.height - lineWidth)))
            self.indefiniteDashLayer.path = path
            self.indefiniteReplicatorLayer.frame = bounds
            self.indefiniteDashLayer.frame = bounds
        }
        
        switch value {
        case let .progress(progress):
            if self.indefiniteReplicatorLayer.superlayer != nil {
                self.indefiniteReplicatorLayer.removeFromSuperlayer()
            }
            if self.uploadProgressLayer.superlayer == nil {
                self.addSublayer(self.uploadProgressLayer)
            }
            transition.setShapeLayerStrokeEnd(layer: self.uploadProgressLayer, strokeEnd: CGFloat(progress))
            if self.uploadProgressLayer.animation(forKey: "rotation") == nil {
                let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotationAnimation.duration = 2.0
                rotationAnimation.fromValue = NSNumber(value: Float(0.0))
                rotationAnimation.toValue = NSNumber(value: Float(Double.pi * 2.0))
                rotationAnimation.repeatCount = Float.infinity
                rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                self.uploadProgressLayer.add(rotationAnimation, forKey: "rotation")
            }
        case .indefinite:
            if self.uploadProgressLayer.superlayer == nil {
                self.uploadProgressLayer.removeFromSuperlayer()
            }
            if self.indefiniteReplicatorLayer.superlayer == nil {
                self.addSublayer(self.indefiniteReplicatorLayer)
            }
            if self.indefiniteReplicatorLayer.animation(forKey: "rotation") == nil {
                let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotationAnimation.duration = 4.0
                rotationAnimation.fromValue = NSNumber(value: -.pi / 2.0)
                rotationAnimation.toValue = NSNumber(value: -.pi / 2.0 + Double.pi * 2.0)
                rotationAnimation.repeatCount = Float.infinity
                rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
                self.indefiniteReplicatorLayer.add(rotationAnimation, forKey: "rotation")
            }
            if self.indefiniteDashLayer.animation(forKey: "dash") == nil {
                let dashAnimation = CAKeyframeAnimation(keyPath: "strokeStart")
                dashAnimation.keyTimes = [0.0, 0.45, 0.55, 1.0]
                dashAnimation.values = [
                    self.indefiniteDashLayer.strokeStart,
                    self.indefiniteDashLayer.strokeEnd,
                    self.indefiniteDashLayer.strokeEnd,
                    self.indefiniteDashLayer.strokeStart,
                ]
                dashAnimation.timingFunction = CAMediaTimingFunction(name: .linear)
                dashAnimation.duration = 2.5
                dashAnimation.repeatCount = .infinity
                self.indefiniteDashLayer.add(dashAnimation, forKey: "dash")
            }
        }
    }
}

private var sharedAvatarBackgroundImage: UIImage?

public final class StoryPeerListItemComponent: Component {
    public final class TransitionView: UIView {
        private weak var itemView: StoryPeerListItemComponent.View?
        private var snapshotView: UIView?
        private var portalView: PortalView?
        
        init(itemView: StoryPeerListItemComponent.View?) {
            self.itemView = itemView
            
            super.init(frame: CGRect())
            
            if let itemView {
                if let portalView = PortalView(matchPosition: false) {
                    itemView.avatarContent.addPortal(view: portalView)
                    self.portalView = portalView
                    self.addSubview(portalView.view)
                }
                /*if let snapshotView = itemView.avatarContent.snapshotView(afterScreenUpdates: false) {
                    self.addSubview(snapshotView)
                    self.snapshotView = snapshotView
                }*/
            }
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(state: StoryContainerScreen.TransitionState, transition: Transition) {
            let size = state.sourceSize.interpolate(to: state.destinationSize, amount: state.progress)
            
            if let snapshotView = self.snapshotView {
                transition.setPosition(view: snapshotView, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                transition.setScale(view: snapshotView, scale: size.width / state.destinationSize.width)
            }
            if let portalView = self.portalView {
                transition.setPosition(view: portalView.view, position: CGPoint(x: size.width * 0.5, y: size.height * 0.5))
                transition.setScale(view: portalView.view, scale: size.width / state.destinationSize.width)
            }
        }
    }
    
    public enum RingAnimation: Equatable {
        case progress(Float)
        case loading
    }
    
    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let peer: EnginePeer
    public let hasUnseen: Bool
    public let hasItems: Bool
    public let ringAnimation: RingAnimation?
    public let collapseFraction: CGFloat
    public let collapsedScaleFactor: CGFloat
    public let collapsedWidth: CGFloat
    public let leftNeighborDistance: CGFloat?
    public let rightNeighborDistance: CGFloat?
    public let action: (EnginePeer) -> Void
    public let contextGesture: (ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: EnginePeer,
        hasUnseen: Bool,
        hasItems: Bool,
        ringAnimation: RingAnimation?,
        collapseFraction: CGFloat,
        collapsedScaleFactor: CGFloat,
        collapsedWidth: CGFloat,
        leftNeighborDistance: CGFloat?,
        rightNeighborDistance: CGFloat?,
        action: @escaping (EnginePeer) -> Void,
        contextGesture: @escaping (ContextExtractedContentContainingNode, ContextGesture, EnginePeer) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.hasUnseen = hasUnseen
        self.hasItems = hasItems
        self.ringAnimation = ringAnimation
        self.collapseFraction = collapseFraction
        self.collapsedScaleFactor = collapsedScaleFactor
        self.collapsedWidth = collapsedWidth
        self.leftNeighborDistance = leftNeighborDistance
        self.rightNeighborDistance = rightNeighborDistance
        self.action = action
        self.contextGesture = contextGesture
    }
    
    public static func ==(lhs: StoryPeerListItemComponent, rhs: StoryPeerListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.hasUnseen != rhs.hasUnseen {
            return false
        }
        if lhs.hasItems != rhs.hasItems {
            return false
        }
        if lhs.ringAnimation != rhs.ringAnimation {
            return false
        }
        if lhs.collapseFraction != rhs.collapseFraction {
            return false
        }
        if lhs.collapsedScaleFactor != rhs.collapsedScaleFactor {
            return false
        }
        if lhs.collapsedWidth != rhs.collapsedWidth {
            return false
        }
        if lhs.leftNeighborDistance != rhs.leftNeighborDistance {
            return false
        }
        if lhs.rightNeighborDistance != rhs.rightNeighborDistance {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        let backgroundContainer: UIView
        
        private let extractedContainerNode: ContextExtractedContentContainingNode
        private let containerNode: ContextControllerSourceNode
        private let extractedBackgroundView: UIImageView
        
        private let button: HighlightTrackingButton
        
        fileprivate let avatarContent: PortalSourceView
        private let avatarContainer: UIView
        private let avatarBackgroundContainer: UIView
        private let avatarBackgroundView: UIImageView
        private var avatarNode: AvatarNode?
        private var avatarAddBadgeView: UIImageView?
        private let avatarShapeLayer: SimpleShapeLayer
        private let indicatorMaskLayer: SimpleLayer
        private let indicatorColorLayer: SimpleGradientLayer
        private var progressLayer: StoryProgressLayer?
        private let indicatorShapeLayer: SimpleShapeLayer
        private let title = ComponentView<Empty>()
        
        private var component: StoryPeerListItemComponent?
        private weak var componentState: EmptyComponentState?
        
        private var demoLoading = false
        
        public override init(frame: CGRect) {
            self.backgroundContainer = UIView()
            self.backgroundContainer.isUserInteractionEnabled = false
            
            self.button = HighlightTrackingButton()
            
            self.extractedContainerNode = ContextExtractedContentContainingNode()
            self.containerNode = ContextControllerSourceNode()
            self.extractedBackgroundView = UIImageView()
            self.extractedBackgroundView.alpha = 0.0
            
            self.avatarContent = PortalSourceView()
            self.avatarContent.isUserInteractionEnabled = false
            
            self.avatarContainer = UIView()
            self.avatarContainer.isUserInteractionEnabled = false
            
            self.avatarBackgroundContainer = UIView()
            self.avatarBackgroundView = UIImageView()
            
            self.avatarShapeLayer = SimpleShapeLayer()
            
            self.indicatorColorLayer = SimpleGradientLayer()
            self.indicatorColorLayer.type = .axial
            self.indicatorColorLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
            self.indicatorColorLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
            
            self.indicatorMaskLayer = SimpleLayer()
            self.indicatorShapeLayer = SimpleShapeLayer()
            
            super.init(frame: frame)
            
            self.extractedContainerNode.contentNode.view.addSubview(self.extractedBackgroundView)
            
            self.containerNode.addSubnode(self.extractedContainerNode)
            self.containerNode.targetNodeForActivationProgress = self.extractedContainerNode.contentNode
            self.addSubview(self.containerNode.view)
            
            self.backgroundContainer.addSubview(self.avatarBackgroundContainer)
            self.avatarBackgroundContainer.addSubview(self.avatarBackgroundView)
            
            self.extractedContainerNode.contentNode.view.addSubview(self.button)
            self.avatarContent.addSubview(self.avatarContainer)
            self.button.addSubview(self.avatarContent)
            
            self.avatarContent.layer.addSublayer(self.indicatorColorLayer)
            self.indicatorMaskLayer.addSublayer(self.indicatorShapeLayer)
            self.indicatorColorLayer.mask = self.indicatorMaskLayer
            
            self.avatarShapeLayer.fillColor = UIColor.white.cgColor
            self.avatarShapeLayer.fillRule = .evenOdd
            
            self.indicatorShapeLayer.fillColor = nil
            self.indicatorShapeLayer.strokeColor = UIColor.white.cgColor
            self.indicatorShapeLayer.lineCap = .round
            
            self.button.highligthedChanged = { [weak self] highlighted in
                guard let self else {
                    return
                }
                if highlighted {
                    self.alpha = 0.7
                } else {
                    let previousAlpha = self.alpha
                    self.alpha = 1.0
                    self.layer.animateAlpha(from: previousAlpha, to: self.alpha, duration: 0.25)
                }
            }
            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            
            self.containerNode.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    return
                }
                self.button.isEnabled = false
                DispatchQueue.main.async { [weak self] in
                    guard let self else {
                        return
                    }
                    self.button.isEnabled = true
                }
                component.contextGesture(self.extractedContainerNode, gesture, component.peer)
            }
            
            self.extractedContainerNode.willUpdateIsExtractedToContextPreview = { [weak self] isExtracted, transition in
                guard let self, let component = self.component else {
                    return
                }
                
                if isExtracted {
                    self.extractedBackgroundView.image = generateStretchableFilledCircleImage(diameter: 24.0, color: component.theme.contextMenu.backgroundColor)
                }
                transition.updateAlpha(layer: self.extractedBackgroundView.layer, alpha: isExtracted ? 1.0 : 0.0, completion: { [weak self] _ in
                    if !isExtracted {
                        self?.extractedBackgroundView.image = nil
                    }
                })
            }
        }
        
        required public init?(coder: NSCoder) {
            preconditionFailure()
        }
        
        @objc private func pressed() {
            guard let component = self.component else {
                return
            }
            component.action(component.peer)
        }
        
        public func transitionView() -> UIView? {
            return self.avatarNode?.view
        }
        
        func updateIsPreviewing(isPreviewing: Bool) {
            self.avatarContent.alpha = isPreviewing ? 0.0 : 1.0
        }
        
        func update(component: StoryPeerListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let size = availableSize
            
            transition.setFrame(view: self.button, frame: CGRect(origin: CGPoint(), size: size))
            transition.setFrame(view: self.extractedBackgroundView, frame: CGRect(origin: CGPoint(), size: size).insetBy(dx: -4.0, dy: -4.0))
            
            self.extractedContainerNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentNode.frame = CGRect(origin: CGPoint(), size: size)
            self.extractedContainerNode.contentRect = CGRect(origin: CGPoint(x: self.extractedBackgroundView.frame.minX - 2.0, y: self.extractedBackgroundView.frame.minY), size: CGSize(width: self.extractedBackgroundView.frame.width + 4.0, height: self.extractedBackgroundView.frame.height))
            self.containerNode.frame = CGRect(origin: CGPoint(), size: size)
            
            let hadUnseen = self.component?.hasUnseen
            let hadProgress = self.component?.ringAnimation != nil
            let themeUpdated = self.component?.theme !== component.theme
            
            let previousComponent = self.component
            
            self.component = component
            self.componentState = state
            
            let effectiveWidth: CGFloat = (1.0 - component.collapseFraction) * availableSize.width + component.collapseFraction * component.collapsedWidth
            
            let effectiveScale: CGFloat = 1.0 * (1.0 - component.collapseFraction) + (24.0 / 52.0) * component.collapsedScaleFactor * component.collapseFraction
            
            let avatarNode: AvatarNode
            if let current = self.avatarNode {
                avatarNode = current
            } else {
                avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 26.0))
                self.avatarNode = avatarNode
                avatarNode.layer.mask = self.avatarShapeLayer
                avatarNode.isUserInteractionEnabled = false
                self.avatarContainer.addSubview(avatarNode.view)
            }
            
            let avatarSize = CGSize(width: 52.0, height: 52.0)
            
            let avatarBackgroundImage: UIImage?
            if let sharedAvatarBackgroundImage = sharedAvatarBackgroundImage, sharedAvatarBackgroundImage.size.width == avatarSize.width {
                avatarBackgroundImage = sharedAvatarBackgroundImage
            } else {
                avatarBackgroundImage = generateFilledCircleImage(diameter: avatarSize.width, color: .white)?.withRenderingMode(.alwaysTemplate)
            }
            self.avatarBackgroundView.image = avatarBackgroundImage
            
            self.avatarBackgroundView.isHidden = component.ringAnimation != nil
            
            if themeUpdated {
                self.avatarBackgroundView.tintColor = component.theme.rootController.navigationBar.opaqueBackgroundColor
            }
            
            let avatarFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - avatarSize.width) * 0.5) + (effectiveWidth - availableSize.width) * 0.5, y: 4.0), size: avatarSize)
            
            transition.setFrame(view: avatarNode.view, frame: CGRect(origin: CGPoint(), size: avatarFrame.size))
            transition.setFrame(view: self.avatarBackgroundView, frame: CGRect(origin: CGPoint(), size: avatarFrame.size).insetBy(dx: -3.0 - UIScreenPixel * 2.0, dy: -3.0 - UIScreenPixel * 2.0))
            
            let indicatorFrame = avatarFrame.insetBy(dx: -6.0, dy: -6.0)
            
            let baseLineWidth: CGFloat
            let minimizedLineWidth: CGFloat = 3.0
            if component.hasUnseen || component.ringAnimation != nil {
                baseLineWidth = 2.0
            } else {
                baseLineWidth = 1.0 + UIScreenPixel
            }
            let indicatorLineWidth: CGFloat = baseLineWidth * (1.0 - component.collapseFraction) + minimizedLineWidth * component.collapseFraction
            
            avatarNode.setPeer(
                context: component.context,
                theme: component.theme,
                peer: component.peer
            )
            avatarNode.updateSize(size: avatarSize)
            
            transition.setPosition(view: self.avatarContent, position: CGPoint(x: avatarFrame.midX, y: avatarFrame.midY))
            transition.setBounds(view: self.avatarContent, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            
            transition.setPosition(view: self.avatarContainer, position: CGPoint(x: avatarFrame.width * 0.5, y: avatarFrame.height * 0.5))
            transition.setBounds(view: self.avatarContainer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            
            transition.setPosition(view: self.avatarBackgroundContainer, position: avatarFrame.center)
            transition.setBounds(view: self.avatarBackgroundContainer, bounds: CGRect(origin: CGPoint(), size: avatarFrame.size))
            
            let scaledAvatarSize = effectiveScale * (avatarSize.width + 4.0 - 2.0 * 2.0)
            
            transition.setScale(view: self.avatarContainer, scale: scaledAvatarSize / avatarSize.width)
            transition.setScale(view: self.avatarBackgroundContainer, scale: scaledAvatarSize / avatarSize.width)
            
            if component.peer.id == component.context.account.peerId && !component.hasItems && component.ringAnimation == nil {
                self.indicatorColorLayer.isHidden = true
                
                let avatarAddBadgeView: UIImageView
                var avatarAddBadgeTransition = transition
                if let current = self.avatarAddBadgeView {
                    avatarAddBadgeView = current
                } else {
                    avatarAddBadgeTransition = .immediate
                    avatarAddBadgeView = UIImageView()
                    self.avatarAddBadgeView = avatarAddBadgeView
                    self.avatarContainer.addSubview(avatarAddBadgeView)
                }
                let badgeSize = CGSize(width: 16.0, height: 16.0)
                if avatarAddBadgeView.image == nil || themeUpdated {
                    avatarAddBadgeView.image = generateImage(badgeSize, rotatedContext: { size, context in
                        context.clear(CGRect(origin: CGPoint(), size: size))
                        context.setFillColor(component.theme.list.itemCheckColors.fillColor.cgColor)
                        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
                        
                        context.setStrokeColor(component.theme.list.itemCheckColors.foregroundColor.cgColor)
                        context.setLineWidth(UIScreenPixel * 3.0)
                        context.setLineCap(.round)
                        
                        let lineSize: CGFloat = 9.0 + UIScreenPixel
                        
                        context.move(to: CGPoint(x: size.width * 0.5, y: (size.height - lineSize) * 0.5))
                        context.addLine(to: CGPoint(x: size.width * 0.5, y: (size.height - lineSize) * 0.5 + lineSize))
                        context.strokePath()
                        
                        context.move(to: CGPoint(x: (size.width - lineSize) * 0.5, y: size.height * 0.5))
                        context.addLine(to: CGPoint(x: (size.width - lineSize) * 0.5 + lineSize, y: size.height * 0.5))
                        context.strokePath()
                    })
                }
                avatarAddBadgeTransition.setFrame(view: avatarAddBadgeView, frame: CGRect(origin: CGPoint(x: avatarFrame.width - 1.0 - badgeSize.width, y: avatarFrame.height - 2.0 - badgeSize.height), size: badgeSize))
            } else {
                if indicatorColorLayer.isHidden {
                    self.indicatorColorLayer.isHidden = false
                }
                
                if let avatarAddBadgeView = self.avatarAddBadgeView {
                    self.avatarAddBadgeView = nil
                    avatarAddBadgeView.removeFromSuperview()
                }
            }
            
            let baseRadius: CGFloat = 30.0
            let collapsedRadius: CGFloat = 32.0
            let indicatorRadius: CGFloat = baseRadius * (1.0 - component.collapseFraction) + collapsedRadius * component.collapseFraction
            
            self.indicatorShapeLayer.lineWidth = indicatorLineWidth
            
            if hadUnseen != component.hasUnseen || themeUpdated || hadProgress != (component.ringAnimation != nil) {
                let locations: [CGFloat] = [0.0, 1.0]
                let colors: [CGColor]
                
                if component.hasUnseen || component.ringAnimation != nil {
                    colors = [UIColor(rgb: 0x34C76F).cgColor, UIColor(rgb: 0x3DA1FD).cgColor]
                } else {
                    if component.theme.overallDarkAppearance {
                        colors = [UIColor(rgb: 0x48484A).cgColor, UIColor(rgb: 0x48484A).cgColor]
                    } else {
                        colors = [UIColor(rgb: 0xD8D8E1).cgColor, UIColor(rgb: 0xD8D8E1).cgColor]
                    }
                }
                
                self.indicatorColorLayer.locations = locations.map { $0 as NSNumber }
                self.indicatorColorLayer.colors = colors
            }
            
            transition.setPosition(layer: self.indicatorColorLayer, position: indicatorFrame.offsetBy(dx: -avatarFrame.minX, dy: -avatarFrame.minY).center)
            transition.setBounds(layer: self.indicatorColorLayer, bounds: CGRect(origin: CGPoint(), size: indicatorFrame.size))
            transition.setPosition(layer: self.indicatorShapeLayer, position: CGPoint(x: indicatorFrame.width * 0.5, y: indicatorFrame.height * 0.5))
            transition.setBounds(layer: self.indicatorShapeLayer, bounds: CGRect(origin: CGPoint(), size: indicatorFrame.size))
            transition.setScale(layer: self.indicatorColorLayer, scale: effectiveScale)
            
            let indicatorCenter = CGRect(origin: CGPoint(), size: indicatorFrame.size).center
            
            var mappedLeftCenter: CGPoint?
            var mappedRightCenter: CGPoint?
            
            if let leftNeighborDistance = component.leftNeighborDistance {
                mappedLeftCenter = CGPoint(x: indicatorCenter.x - leftNeighborDistance * (1.0 / effectiveScale), y: indicatorCenter.y)
            }
            if let rightNeighborDistance = component.rightNeighborDistance {
                mappedRightCenter = CGPoint(x: indicatorCenter.x + rightNeighborDistance * (1.0 / effectiveScale), y: indicatorCenter.y)
            }
            
            let avatarPath = CGMutablePath()
            avatarPath.addEllipse(in: CGRect(origin: CGPoint(), size: avatarSize).insetBy(dx: -1.0, dy: -1.0))
            if component.peer.id == component.context.account.peerId && !component.hasItems && component.ringAnimation == nil {
                let cutoutSize: CGFloat = 18.0 + UIScreenPixel * 2.0
                avatarPath.addEllipse(in: CGRect(origin: CGPoint(x: avatarSize.width - cutoutSize + UIScreenPixel, y: avatarSize.height - 1.0 - cutoutSize + UIScreenPixel), size: CGSize(width: cutoutSize, height: cutoutSize)))
            } else if let mappedLeftCenter {
                avatarPath.addEllipse(in: CGRect(origin: CGPoint(), size: avatarSize).insetBy(dx: -indicatorLineWidth, dy: -indicatorLineWidth).offsetBy(dx: -abs(indicatorCenter.x - mappedLeftCenter.x), dy: 0.0))
            }
            Transition.immediate.setShapeLayerPath(layer: self.avatarShapeLayer, path: avatarPath)
            
            Transition.immediate.setShapeLayerPath(layer: self.indicatorShapeLayer, path: calculateMergingCircleShape(center: indicatorCenter, leftCenter: mappedLeftCenter, rightCenter: mappedRightCenter, radius: indicatorRadius - indicatorLineWidth * 0.5))
            
            //TODO:localize
            let titleString: String
            if component.peer.id == component.context.account.peerId {
                if let ringAnimation = component.ringAnimation, case .progress = ringAnimation {
                    titleString = "Uploading..."
                } else {
                    titleString = "My story"
                }
            } else {
                titleString = component.peer.compactDisplayTitle
            }
            
            var titleTransition = transition
            if let previousAnimation = previousComponent?.ringAnimation, case .progress = previousAnimation, component.ringAnimation == nil {
                if let titleView = self.title.view, let snapshotView = titleView.snapshotView(afterScreenUpdates: false) {
                    self.button.addSubview(snapshotView)
                    snapshotView.frame = titleView.frame
                    snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                        snapshotView?.removeFromSuperview()
                    })
                    titleView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                titleTransition = .immediate
                
                self.avatarContent.layer.transform = CATransform3DMakeScale(1.08, 1.08, 1.0)
                self.avatarContent.layer.animateScale(from: 1.0, to: 1.08, duration: 0.2, completion: { [weak self] _ in
                    self?.avatarContent.layer.transform = CATransform3DMakeScale(1.0, 1.0, 1.0)
                    self?.avatarContent.layer.animateScale(from: 1.08, to: 1.0, duration: 0.15)
                })
                
                let initialLineWidth: CGFloat = 2.0
                let targetLineWidth: CGFloat = 3.0
                self.indicatorShapeLayer.lineWidth = targetLineWidth
                self.indicatorShapeLayer.animateShapeLineWidth(from: initialLineWidth, to: targetLineWidth, duration: 0.2, completion: { [weak self] _ in
                    self?.indicatorShapeLayer.lineWidth = initialLineWidth
                    self?.indicatorShapeLayer.animateShapeLineWidth(from: targetLineWidth, to: initialLineWidth, duration: 0.15)
                })
            }
            
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: Font.regular(11.0), textColor: component.theme.list.itemPrimaryTextColor)),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width + 4.0, height: 100.0)
            )
            let titleFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - titleSize.width) * 0.5) + (effectiveWidth - availableSize.width) * 0.5, y: indicatorFrame.midY + (indicatorFrame.height * 0.5 + 2.0) * effectiveScale), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
                    titleView.isUserInteractionEnabled = false
                    self.button.addSubview(titleView)
                }
                titleTransition.setPosition(view: titleView, position: titleFrame.center)
                titleView.bounds = CGRect(origin: CGPoint(), size: titleFrame.size)
                titleTransition.setScale(view: titleView, scale: effectiveScale)
                titleTransition.setAlpha(view: titleView, alpha: 1.0 - component.collapseFraction)
            }
            
            if let ringAnimation = component.ringAnimation {
                var progressTransition = transition
                let progressLayer: StoryProgressLayer
                if let current = self.progressLayer {
                    progressLayer = current
                } else {
                    progressTransition = .immediate
                    progressLayer = StoryProgressLayer()
                    self.progressLayer = progressLayer
                    self.indicatorMaskLayer.addSublayer(progressLayer)
                }
                let progressFrame = CGRect(origin: CGPoint(), size: indicatorFrame.size).insetBy(dx: 2.0, dy: 2.0)
                progressTransition.setFrame(layer: progressLayer, frame: progressFrame)
                
                switch ringAnimation {
                case let .progress(progress):
                    let progressTransition: Transition
                    if abs(progress - 0.028) < 0.001 {
                        progressTransition = .immediate
                    } else {
                        progressTransition = .easeInOut(duration: 0.3)
                    }
                    progressLayer.update(size: progressFrame.size, lineWidth: 4.0, value: .progress(progress), transition: progressTransition)
                case .loading:
                    progressLayer.update(size: progressFrame.size, lineWidth: 4.0, value: .indefinite, transition: transition)
                }
                self.indicatorShapeLayer.opacity = 0.0
            } else {
                self.indicatorShapeLayer.opacity = 1.0
                
                if let progressLayer = self.progressLayer {
                    self.progressLayer = nil
                    if transition.animation.isImmediate {
                        progressLayer.reset()
                        progressLayer.removeFromSuperlayer()
                    } else {
                        progressLayer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak progressLayer] _ in
                            progressLayer?.reset()
                            progressLayer?.removeFromSuperlayer()
                        })
                    }
                }
            }
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}
