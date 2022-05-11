import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import AccountContext
import SolidRoundedButtonComponent
import MultilineTextComponent
import PresentationDataUtils
import PrefixSectionGroupComponent
import BundleIconComponent
import SolidRoundedButtonComponent
import Markdown
import SceneKit

private func deg2rad(_ number: Float) -> Float {
    return number * .pi / 180
}

private func rad2deg(_ number: Float) -> Float {
    return number * 180.0 / .pi
}

private class StarComponent: Component {
    static func ==(lhs: StarComponent, rhs: StarComponent) -> Bool {
        return true
    }
    
    final class View: UIView, SCNSceneRendererDelegate, ComponentTaggedView {
        final class Tag {
        }
        
        func matches(tag: Any) -> Bool {
            if let _ = tag as? Tag {
                return true
            }
            return false
        }
        
        private var _ready = Promise<Bool>()
        var ready: Signal<Bool, NoError> {
            return self._ready.get()
        }
        
        private let sceneView: SCNView
                
        override init(frame: CGRect) {
            self.sceneView = SCNView(frame: frame)
            self.sceneView.backgroundColor = .clear
            self.sceneView.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
            self.sceneView.isUserInteractionEnabled = false
            
            super.init(frame: frame)
            
            self.addSubview(self.sceneView)
            
            self.setup()
            
            let panGestureRecoginzer = UIPanGestureRecognizer(target: self, action: #selector(self.handlePan(_:)))
            self.addGestureRecognizer(panGestureRecoginzer)
            
            let tapGestureRecoginzer = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(_:)))
            self.addGestureRecognizer(tapGestureRecoginzer)
            
            self.disablesInteractiveModalDismiss = true
            self.disablesInteractiveTransitionGestureRecognizer = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            var left = true
            if let view = gesture.view {
                let point = gesture.location(in: view)
                if point.x > view.frame.width / 2.0 {
                    left = false
                }
            }
            
            if node.animationKeys.contains("tapRotate") {
                self.playAppearanceAnimation(velocity: nil, mirror: left, boom: true)
                return
            }
            
            let initial = node.rotation
            let target = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: left ? -0.6 : 0.6)
                        
            let animation = CABasicAnimation(keyPath: "rotation")
            animation.fromValue = NSValue(scnVector4: initial)
            animation.toValue = NSValue(scnVector4: target)
            animation.duration = 0.25
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.fillMode = .forwards
            node.addAnimation(animation, forKey: "tapRotate")
            
            node.rotation = target
            
            Queue.mainQueue().after(0.25) {
                node.rotation = initial
                let springAnimation = CASpringAnimation(keyPath: "rotation")
                springAnimation.fromValue = NSValue(scnVector4: target)
                springAnimation.toValue = NSValue(scnVector4: SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: 0.0))
                springAnimation.mass = 1.0
                springAnimation.stiffness = 21.0
                springAnimation.damping = 5.8
                springAnimation.duration = springAnimation.settlingDuration * 0.8
                node.addAnimation(springAnimation, forKey: "tapRotate")
            }
        }
        
        private var previousAngle: Float = 0.0
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            if #available(iOS 11.0, *) {
                node.removeAnimation(forKey: "rotate", blendOutDuration: 0.1)
                node.removeAnimation(forKey: "tapRotate", blendOutDuration: 0.1)
            } else {
                node.removeAllAnimations()
            }
            
            switch gesture.state {
                case .began:
                    self.previousAngle = 0.0
                case .changed:
                    let translation = gesture.translation(in: gesture.view)
                    let anglePan = deg2rad(Float(translation.x))
                
                    self.previousAngle = anglePan
                    node.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: self.previousAngle)
                case .ended:
                    let velocity = gesture.velocity(in: gesture.view)
                    
                    var smallAngle = false
                    if (self.previousAngle < .pi / 2 && self.previousAngle > -.pi / 2) && abs(velocity.x) < 200 {
                        smallAngle = true
                    }
                
                    self.playAppearanceAnimation(velocity: velocity.x, smallAngle: smallAngle)
                    node.rotation = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: 0.0)
                default:
                    break
            }
        }
        
        private func setup() {
            guard let scene = SCNScene(named: "star.scn") else {
                return
            }
            self.sceneView.scene = scene
            self.sceneView.delegate = self
            
            let _ = self.sceneView.snapshot()
        }
        
        private var didSetReady = false
        func renderer(_ renderer: SCNSceneRenderer, didRenderScene scene: SCNScene, atTime time: TimeInterval) {
            if !self.didSetReady {
                self.didSetReady = true
                
                self._ready.set(.single(true))
                self.onReady()
            }
        }
        
        private func onReady() {
            self.setupGradientAnimation()
            self.setupShineAnimation()
            
            self.playAppearanceAnimation(boom: true)
        }
        
        private func setupGradientAnimation() {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            guard let initial = node.geometry?.materials.first?.diffuse.contentsTransform else {
                return
            }
            
            let animation = CABasicAnimation(keyPath: "contentsTransform")
            animation.duration = 4.5
            animation.fromValue = NSValue(scnMatrix4: initial)
            animation.toValue = NSValue(scnMatrix4: SCNMatrix4Translate(initial, -0.35, 0.35, 0))
            animation.timingFunction = CAMediaTimingFunction(name: .linear)
            animation.autoreverses = true
            animation.repeatCount = .infinity
            
            node.geometry?.materials.first?.diffuse.addAnimation(animation, forKey: "gradient")
        }
        
        private func setupShineAnimation() {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            guard let initial = node.geometry?.materials.first?.emission.contentsTransform else {
                return
            }
            
            let animation = CABasicAnimation(keyPath: "contentsTransform")
            animation.fillMode = .forwards
            animation.fromValue = NSValue(scnMatrix4: initial)
            animation.toValue = NSValue(scnMatrix4: SCNMatrix4Translate(initial, -1.6, 0.0, 0.0))
            animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
            animation.beginTime = 0.6
            animation.duration = 0.9
            
            let group = CAAnimationGroup()
            group.animations = [animation]
            group.beginTime = 1.0
            group.duration = 3.0
            group.repeatCount = .infinity
            
            node.geometry?.materials.first?.emission.addAnimation(group, forKey: "shimmer")
        }
        
        private func playAppearanceAnimation(velocity: CGFloat? = nil, smallAngle: Bool = false, mirror: Bool = false, explode: Bool = false) {
            guard let scene = self.sceneView.scene, let node = scene.rootNode.childNode(withName: "star", recursively: false) else {
                return
            }
            
            if explode, let node = scene.rootNode.childNode(withName: "swirl", recursively: false), let particles = scene.rootNode.childNode(withName: "particles", recursively: false) {
                node.physicsField?.isActive = true
                Queue.mainQueue().after(1.0) {
                    node.physicsField?.isActive = false
                    particles.particleSystems?.first?.birthRate = 0.8
                }
            }
        
            let from = node.presentation.rotation
            node.removeAnimation(forKey: "tapRotate")
            
            var toValue: Float = smallAngle ? 0.0 : .pi * 2.0
            if let velocity = velocity, !smallAngle && abs(velocity) > 200 && velocity < 0.0 {
                toValue *= -1
            }
            if mirror {
                toValue *= -1
            }
            let to = SCNVector4(x: 0.0, y: 1.0, z: 0.0, w: toValue)
            let distance = rad2deg(to.w - from.w)
            
            let springAnimation = CASpringAnimation(keyPath: "rotation")
            springAnimation.fromValue = NSValue(scnVector4: from)
            springAnimation.toValue = NSValue(scnVector4: to)
            springAnimation.mass = 1.0
            springAnimation.stiffness = 21.0
            springAnimation.damping = 5.8
            springAnimation.duration = springAnimation.settlingDuration * 0.75
            springAnimation.initialVelocity = velocity.flatMap { abs($0 / CGFloat(distance)) } ?? 1.7
            
            node.addAnimation(springAnimation, forKey: "rotate")
        }
        
        func update(component: StarComponent, availableSize: CGSize, transition: Transition) -> CGSize {
            self.sceneView.bounds = CGRect(origin: .zero, size: CGSize(width: availableSize.width * 2.0, height: availableSize.height * 2.0))
            self.sceneView.center = CGPoint(x: availableSize.width / 2.0, y: availableSize.height / 2.0)
            
            return availableSize
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}


private final class SectionGroupComponent: Component {
    public final class Item: Equatable {
        public let content: AnyComponentWithIdentity<Empty>
        
        public init(_ content: AnyComponentWithIdentity<Empty>) {
            self.content = content
        }
        
        public static func ==(lhs: Item, rhs: Item) -> Bool {
            if lhs.content != rhs.content {
                return false
            }
            
            return true
        }
    }
    
    public let items: [Item]
    public let backgroundColor: UIColor
    public let separatorColor: UIColor
    
    public init(
        items: [Item],
        backgroundColor: UIColor,
        separatorColor: UIColor
    ) {
        self.items = items
        self.backgroundColor = backgroundColor
        self.separatorColor = separatorColor
    }
    
    public static func ==(lhs: SectionGroupComponent, rhs: SectionGroupComponent) -> Bool {
        if lhs.items != rhs.items {
            return false
        }
        if lhs.backgroundColor != rhs.backgroundColor {
            return false
        }
        if lhs.separatorColor != rhs.separatorColor {
            return false
        }
        return true
    }
    
    public final class View: UIView {
        private let backgroundView: UIView
        private var itemViews: [AnyHashable: ComponentHostView<Empty>] = [:]
        private var separatorViews: [UIView] = []
        
        override init(frame: CGRect) {
            self.backgroundView = UIView()
            
            super.init(frame: frame)
            
            self.addSubview(self.backgroundView)
            self.backgroundView.layer.cornerRadius = 10.0
            self.backgroundView.layer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: SectionGroupComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
            let sideInset: CGFloat = 16.0
            
            self.backgroundView.backgroundColor = component.backgroundColor
            
            var size = CGSize(width: availableSize.width, height: 0.0)
            
            var validIds: [AnyHashable] = []
            
            var i = 0
            for item in component.items {
                validIds.append(item.content.id)
                
                let itemView: ComponentHostView<Empty>
                var itemTransition = transition
                if let current = self.itemViews[item.content.id] {
                    itemView = current
                } else {
                    itemTransition = transition.withAnimation(.none)
                    itemView = ComponentHostView<Empty>()
                    self.itemViews[item.content.id] = itemView
                    self.addSubview(itemView)
                }
                let itemSize = itemView.update(
                    transition: itemTransition,
                    component: item.content.component,
                    environment: {},
                    containerSize: CGSize(width: size.width - sideInset, height: .greatestFiniteMagnitude)
                )
                
                let itemFrame = CGRect(origin: CGPoint(x: 0.0, y: size.height), size: itemSize)
                itemView.frame = CGRect(origin: CGPoint(x: itemFrame.minX + sideInset, y: itemFrame.minY + floor((itemFrame.height - itemSize.height) / 2.0)), size: itemSize)
                
                size.height += itemSize.height
                
                if i != component.items.count - 1 {
                    let separatorView: UIView
                    if self.separatorViews.count > i {
                        separatorView = self.separatorViews[i]
                    } else {
                        separatorView = UIView()
                        self.separatorViews.append(separatorView)
                        self.addSubview(separatorView)
                    }
                    separatorView.backgroundColor = component.separatorColor
                    
                    separatorView.frame = CGRect(origin: CGPoint(x: itemFrame.minX + sideInset * 2.0 + 30.0, y: itemFrame.maxY), size: CGSize(width: size.width - sideInset * 2.0 - 30.0, height: UIScreenPixel))
                }
                i += 1
            }
            
            var removeIds: [AnyHashable] = []
            for (id, itemView) in self.itemViews {
                if !validIds.contains(id) {
                    removeIds.append(id)
                    itemView.removeFromSuperview()
                }
            }
            for id in removeIds {
                self.itemViews.removeValue(forKey: id)
            }
            
            if self.separatorViews.count > component.items.count - 1 {
                for i in (component.items.count - 1) ..< self.separatorViews.count {
                    self.separatorViews[i].removeFromSuperview()
                }
                self.separatorViews.removeSubrange((component.items.count - 1) ..< self.separatorViews.count)
            }
            
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: CGPoint(), size: size), completion: nil)
            
            return size
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}


private final class ScrollChildEnvironment: Equatable {
    public let insets: UIEdgeInsets
    
    public init(insets: UIEdgeInsets) {
        self.insets = insets
    }
    
    public static func ==(lhs: ScrollChildEnvironment, rhs: ScrollChildEnvironment) -> Bool {
        if lhs.insets != rhs.insets {
            return false
        }

        return true
    }
}

private final class ScrollComponent<ChildEnvironment: Equatable>: Component {
    public typealias EnvironmentType = ChildEnvironment
    
    public let content: AnyComponent<(ChildEnvironment, ScrollChildEnvironment)>
    public let contentInsets: UIEdgeInsets
    public let contentOffsetUpdated: (_ top: CGFloat, _ bottom: CGFloat) -> Void
    
    public init(
        content: AnyComponent<(ChildEnvironment, ScrollChildEnvironment)>,
        contentInsets: UIEdgeInsets,
        contentOffsetUpdated: @escaping (_ top: CGFloat, _ bottom: CGFloat) -> Void
    ) {
        self.content = content
        self.contentInsets = contentInsets
        self.contentOffsetUpdated = contentOffsetUpdated
    }
    
    public static func ==(lhs: ScrollComponent, rhs: ScrollComponent) -> Bool {
        if lhs.content != rhs.content {
            return false
        }
        if lhs.contentInsets != rhs.contentInsets {
            return false
        }
        
        return true
    }
    
    public final class View: UIScrollView, UIScrollViewDelegate {
        private var component: ScrollComponent<ChildEnvironment>?
        private let contentView: ComponentHostView<(ChildEnvironment, ScrollChildEnvironment)>
                
        override init(frame: CGRect) {
            self.contentView = ComponentHostView()
            
            super.init(frame: frame)
            
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                self.contentInsetAdjustmentBehavior = .never
            }
            self.delegate = self
            self.showsVerticalScrollIndicator = false
                        
            self.addSubview(self.contentView)
        }
        
        private var ignoreDidScroll = false
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard let component = self.component, !self.ignoreDidScroll else {
                return
            }
            
            let topOffset = scrollView.contentOffset.y
            let bottomOffset = max(0.0, scrollView.contentSize.height - scrollView.contentOffset.y - scrollView.frame.height)
            component.contentOffsetUpdated(topOffset, bottomOffset)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
                
        func update(component: ScrollComponent<ChildEnvironment>, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChildEnvironment>, transition: Transition) -> CGSize {
            let contentSize = self.contentView.update(
                transition: transition,
                component: component.content,
                environment: {
                    environment[ChildEnvironment.self]
                    ScrollChildEnvironment(insets: component.contentInsets)
                },
                containerSize: CGSize(width: availableSize.width, height: .greatestFiniteMagnitude)
            )
            transition.setFrame(view: self.contentView, frame: CGRect(origin: .zero, size: contentSize), completion: nil)
            
            if self.contentSize != contentSize {
                self.ignoreDidScroll = true
                self.contentSize = contentSize
                self.ignoreDidScroll = false
            }
            if self.scrollIndicatorInsets != component.contentInsets {
                self.scrollIndicatorInsets = component.contentInsets
            }
            
            self.component = component
            
            return availableSize
        }
    }
    
    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ChildEnvironment>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

final class PerkComponent: CombinedComponent {
    public let iconName: String
    public let iconBackgroundColors: [UIColor]
    public let title: String
    public let titleColor: UIColor
    public let subtitle: String
    public let subtitleColor: UIColor
    public let arrowColor: UIColor
    
    public init(
        iconName: String,
        iconBackgroundColors: [UIColor],
        title: String,
        titleColor: UIColor,
        subtitle: String,
        subtitleColor: UIColor,
        arrowColor: UIColor
    ) {
        self.iconName = iconName
        self.iconBackgroundColors = iconBackgroundColors
        self.title = title
        self.titleColor = titleColor
        self.subtitle = subtitle
        self.subtitleColor = subtitleColor
        self.arrowColor = arrowColor
    }
    
    public static func ==(lhs: PerkComponent, rhs: PerkComponent) -> Bool {
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconBackgroundColors != rhs.iconBackgroundColors {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.subtitleColor != rhs.subtitleColor {
            return false
        }
        if lhs.arrowColor != rhs.arrowColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let iconBackground = Child(RoundedRectangle.self)
        let icon = Child(BundleIconComponent.self)
        let title = Child(Text.self)
        let subtitle = Child(MultilineTextComponent.self)
        let arrow = Child(BundleIconComponent.self)

        return { context in
            let component = context.component
            
            let sideInset: CGFloat = 16.0
            let iconTopInset: CGFloat = 15.0
            let textTopInset: CGFloat = 9.0
            let textBottomInset: CGFloat = 9.0
            let spacing: CGFloat = 3.0
            let iconSize = CGSize(width: 30.0, height: 30.0)
            
            let iconBackground = iconBackground.update(
                component: RoundedRectangle(
                    colors: component.iconBackgroundColors,
                    cornerRadius: 7.0,
                    gradientDirection: .vertical),
                availableSize: iconSize, transition: context.transition
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: .white
                ),
                availableSize: iconSize,
                transition: context.transition
            )
            
            let arrow = arrow.update(
                component: BundleIconComponent(
                    name: "Item List/DisclosureArrow",
                    tintColor: component.arrowColor
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let title = title.update(
                component: Text(
                    text: component.title,
                    font: Font.regular(17.0),
                    color: component.titleColor
                ),
                availableSize: CGSize(width: context.availableSize.width - iconBackground.size.width - sideInset * 2.83, height: context.availableSize.height),
                transition: context.transition
            )
            
            let subtitle = subtitle.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: component.subtitle,
                            font: Font.regular(13),
                            textColor: component.subtitleColor
                        )
                    ),
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - iconBackground.size.width - sideInset * 2.83, height: context.availableSize.height),
                transition: context.transition
            )
            
            let iconPosition = CGPoint(x: iconBackground.size.width / 2.0, y: iconTopInset + iconBackground.size.height / 2.0)
            context.add(iconBackground
                .position(iconPosition)
            )
            
            context.add(icon
                .position(iconPosition)
            )
            
            context.add(title
                .position(CGPoint(x: iconBackground.size.width + sideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            context.add(subtitle
                .position(CGPoint(x: iconBackground.size.width + sideInset + subtitle.size.width / 2.0, y: textTopInset + title.size.height + spacing + subtitle.size.height / 2.0))
            )
            
            let size = CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + spacing + subtitle.size.height + textBottomInset)
            context.add(arrow
                .position(CGPoint(x: context.availableSize.width - 7.0 - arrow.size.width / 2.0, y: size.height / 2.0))
            )
        
            return size
        }
    }
}


private final class PremiumIntroScreenContentComponent: CombinedComponent {
    typealias EnvironmentType = (ViewControllerComponentContainer.Environment, ScrollChildEnvironment)
    
    let context: AccountContext
    
    init(context: AccountContext) {
        self.context = context
    }
    
    static func ==(lhs: PremiumIntroScreenContentComponent, rhs: PremiumIntroScreenContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
    
        return true
    }
    
    static var body: Body {
        let overscroll = Child(Rectangle.self)
        let fade = Child(RoundedRectangle.self)
        let text = Child(MultilineTextComponent.self)
        let section = Child(SectionGroupComponent.self)
        let infoText = Child(MultilineTextComponent.self)
        
        return { context in
            let sideInset: CGFloat = 16.0
            
            let scrollEnvironment = context.environment[ScrollChildEnvironment.self].value
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            
            let theme = environment.theme
            let strings = environment.strings
            
            let availableWidth = context.availableSize.width
            let sideInsets = sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right
            var size = CGSize(width: context.availableSize.width, height: 0.0)
            
            let overscroll = overscroll.update(
                component: Rectangle(color: theme.list.plainBackgroundColor),
                availableSize: CGSize(width: context.availableSize.width, height: 1000),
                transition: context.transition
            )
            context.add(overscroll
                .position(CGPoint(x: overscroll.size.width / 2.0, y: -overscroll.size.height / 2.0))
            )
            
            let fade = fade.update(
                component: RoundedRectangle(
                    colors: [
                        theme.list.plainBackgroundColor,
                        theme.list.blocksBackgroundColor
                    ],
                    cornerRadius: 0.0,
                    gradientDirection: .vertical
                ),
                availableSize: CGSize(width: availableWidth, height: 300),
                transition: context.transition
            )
            context.add(fade
                .position(CGPoint(x: fade.size.width / 2.0, y: fade.size.height / 2.0))
            )
            
            size.height += 183.0 + 10.0
            
            let textColor = theme.list.itemPrimaryTextColor
            let titleColor = theme.list.itemPrimaryTextColor
            let subtitleColor = theme.list.itemSecondaryTextColor
            let arrowColor = theme.list.disclosureArrowColor
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: textColor), linkAttribute: { _ in
                return nil
            })
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(
                        text: strings.Premium_Description,
                        attributes: markdownAttributes
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets, height: 240.0),
                transition: context.transition
            )
            context.add(text
                .position(CGPoint(x: size.width / 2.0, y: size.height + text.size.height / 2.0))
            )
            size.height += text.size.height
            size.height += 21.0
            
            let section = section.update(
                component: SectionGroupComponent(
                    items: [
                        SectionGroupComponent.Item(
                            AnyComponentWithIdentity(
                                id: "limits",
                                component: AnyComponent(
                                    PerkComponent(
                                        iconName: "Premium/Perk/Limits",
                                        iconBackgroundColors: [
                                            UIColor(rgb: 0xF28528),
                                            UIColor(rgb: 0xEF7633)
                                        ],
                                        title: strings.Premium_DoubledLimits,
                                        titleColor: titleColor,
                                        subtitle: strings.Premium_DoubledLimitsInfo,
                                        subtitleColor: subtitleColor,
                                        arrowColor: arrowColor
                                    )
                                )
                            )
                        ),
                        SectionGroupComponent.Item(
                            AnyComponentWithIdentity(
                                id: "upload",
                                component: AnyComponent(
                                    PerkComponent(
                                        iconName: "Premium/Perk/Upload",
                                        iconBackgroundColors: [
                                            UIColor(rgb: 0xEA5F43),
                                            UIColor(rgb: 0xE7504E)
                                        ],
                                        title: strings.Premium_UploadSize,
                                        titleColor: titleColor,
                                        subtitle: strings.Premium_UploadSizeInfo,
                                        subtitleColor: subtitleColor,
                                        arrowColor: arrowColor
                                    )
                                )
                            )
                        ),
                        SectionGroupComponent.Item(
                            AnyComponentWithIdentity(
                                id: "speed",
                                component: AnyComponent(
                                    PerkComponent(
                                        iconName: "Premium/Perk/Speed",
                                        iconBackgroundColors: [
                                            UIColor(rgb: 0xDE4768),
                                            UIColor(rgb: 0xD54D82)
                                        ],
                                        title: strings.Premium_FasterSpeed,
                                        titleColor: titleColor,
                                        subtitle: strings.Premium_FasterSpeedInfo,
                                        subtitleColor: subtitleColor,
                                        arrowColor: arrowColor
                                    )
                                )
                            )
                        ),
                        SectionGroupComponent.Item(
                            AnyComponentWithIdentity(
                                id: "noAds",
                                component: AnyComponent(
                                    PerkComponent(
                                        iconName: "Premium/Perk/NoAds",
                                        iconBackgroundColors: [
                                            UIColor(rgb: 0xC654A8),
                                            UIColor(rgb: 0xBE5AC2)
                                        ],
                                        title: strings.Premium_NoAds,
                                        titleColor: titleColor,
                                        subtitle: strings.Premium_NoAdsInfo,
                                        subtitleColor: subtitleColor,
                                        arrowColor: arrowColor
                                    )
                                )
                            )
                        ),
                        SectionGroupComponent.Item(
                            AnyComponentWithIdentity(
                                id: "reactions",
                                component: AnyComponent(
                                    PerkComponent(
                                        iconName: "Premium/Perk/Reactions",
                                        iconBackgroundColors: [
                                            UIColor(rgb: 0xAF62E9),
                                            UIColor(rgb: 0xA668FF)
                                        ],
                                        title: strings.Premium_Reactions,
                                        titleColor: titleColor,
                                        subtitle: strings.Premium_ReactionsInfo,
                                        subtitleColor: subtitleColor,
                                        arrowColor: arrowColor
                                    )
                                )
                            )
                        ),
                        SectionGroupComponent.Item(
                            AnyComponentWithIdentity(
                                id: "stickers",
                                component: AnyComponent(
                                    PerkComponent(
                                        iconName: "Premium/Perk/Stickers",
                                        iconBackgroundColors: [
                                            UIColor(rgb: 0x9674FF),
                                            UIColor(rgb: 0x8C7DFF)
                                        ],
                                        title: strings.Premium_Stickers,
                                        titleColor: titleColor,
                                        subtitle: strings.Premium_StickersInfo,
                                        subtitleColor: subtitleColor,
                                        arrowColor: arrowColor
                                    )
                                )
                            )
                        ),
                        SectionGroupComponent.Item(
                            AnyComponentWithIdentity(
                                id: "badge",
                                component: AnyComponent(
                                    PerkComponent(
                                        iconName: "Premium/Perk/Badge",
                                        iconBackgroundColors: [
                                            UIColor(rgb: 0x7B88FF),
                                            UIColor(rgb: 0x7091FF)
                                        ],
                                        title: strings.Premium_Badge,
                                        titleColor: titleColor,
                                        subtitle: strings.Premium_BadgeInfo,
                                        subtitleColor: subtitleColor,
                                        arrowColor: arrowColor
                                    )
                                )
                            )
                        ),
                        SectionGroupComponent.Item(
                            AnyComponentWithIdentity(
                                id: "avatar",
                                component: AnyComponent(
                                    PerkComponent(
                                        iconName: "Premium/Perk/Avatar",
                                        iconBackgroundColors: [
                                            UIColor(rgb: 0x609DFF),
                                            UIColor(rgb: 0x56A5FF)
                                        ],
                                        title: strings.Premium_Avatar,
                                        titleColor: titleColor,
                                        subtitle: strings.Premium_AvatarInfo,
                                        subtitleColor: subtitleColor,
                                        arrowColor: arrowColor
                                    )
                                )
                            )
                        ),
                    ],
                    backgroundColor: environment.theme.list.itemBlocksBackgroundColor,
                    separatorColor: environment.theme.list.itemBlocksSeparatorColor
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets, height: .greatestFiniteMagnitude),
                transition: context.transition
            )
            context.add(section
                .position(CGPoint(x: availableWidth / 2.0, y: size.height + section.size.height / 2.0))
            )
            size.height += section.size.height
            size.height += 17.0
            
            let infoText = infoText.update(
                component: MultilineTextComponent(
                    text: .plain(
                        NSAttributedString(
                            string: strings.Premium_HelpUs,
                            font: Font.regular(15.0),
                            textColor: environment.theme.list.freeTextColor
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                environment: {},
                availableSize: CGSize(width: availableWidth - sideInsets, height: 120.0),
                transition: context.transition
            )
            context.add(infoText
                .position(CGPoint(x: size.width / 2.0, y: size.height + infoText.size.height / 2.0))
            )
            size.height += text.size.height
            size.height += 3.0
            size.height += scrollEnvironment.insets.bottom
            
            return size
        }
    }
}

private class BlurredRectangle: Component {
    let color: UIColor

    init(color: UIColor) {
        self.color = color
    }

    static func ==(lhs: BlurredRectangle, rhs: BlurredRectangle) -> Bool {
        if !lhs.color.isEqual(rhs.color) {
            return false
        }
        return true
    }

    final class View: UIView {
        private let background: NavigationBackgroundNode

        init() {
            self.background = NavigationBackgroundNode(color: .clear)

            super.init(frame: CGRect())

            self.addSubview(self.background.view)
        }

        required init?(coder aDecoder: NSCoder) {
            preconditionFailure()
        }

        func update(component: BlurredRectangle, availableSize: CGSize, transition: Transition) -> CGSize {
            transition.setFrame(view: self.background.view, frame: CGRect(origin: CGPoint(), size: availableSize))
            self.background.updateColor(color: component.color, transition: .immediate)
            self.background.update(size: availableSize, cornerRadius: 0.0, transition: .immediate)

            return availableSize
        }
    }

    func makeView() -> View {
        return View()
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: Transition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class PremiumIntroScreenComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let action: () -> Void
    
    init(context: AccountContext, action: @escaping () -> Void) {
        self.context = context
        self.action = action
    }
    
    static func ==(lhs: PremiumIntroScreenComponent, rhs: PremiumIntroScreenComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var topContentOffset: CGFloat?
        var bottomContentOffset: CGFloat?
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let background = Child(Rectangle.self)
        let scrollContent = Child(ScrollComponent<EnvironmentType>.self)
        let star = Child(StarComponent.self)
        let topPanel = Child(BlurredRectangle.self)
        let topSeparator = Child(Rectangle.self)
        let title = Child(Text.self)
        let bottomPanel = Child(BlurredRectangle.self)
        let bottomSeparator = Child(Rectangle.self)
        let button = Child(SolidRoundedButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self].value
            let state = context.state
            
            let background = background.update(component: Rectangle(color: environment.theme.list.blocksBackgroundColor), environment: {}, availableSize: context.availableSize, transition: context.transition)
            
            let star = star.update(
                component: StarComponent(),
                availableSize: CGSize(width: 260.0, height: 180.0),
                transition: context.transition
            )
            
            let topPanel = topPanel.update(
                component: BlurredRectangle(
                    color: environment.theme.rootController.navigationBar.blurredBackgroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: environment.navigationHeight),
                transition: context.transition
            )
            
            let topSeparator = topSeparator.update(
                component: Rectangle(
                    color: environment.theme.rootController.navigationBar.separatorColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                transition: context.transition
            )
            
            let title = title.update(
                component: Text(
                    text: environment.strings.Premium_Title,
                    font: Font.bold(28.0),
                    color: environment.theme.rootController.navigationBar.primaryTextColor
                ),
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            let sideInset: CGFloat = 16.0
            let button = button.update(
                component: SolidRoundedButtonComponent(
                    title: environment.strings.Premium_SubscribeFor("$5").string,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: .black,
                        backgroundColors: [
                            UIColor(rgb: 0x0077ff),
                            UIColor(rgb: 0x6b93ff),
                            UIColor(rgb: 0x8878ff),
                            UIColor(rgb: 0xe46ace)
                        ],
                        foregroundColor: .white
                    ),
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: true,
                    action: context.component.action
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - environment.safeInsets.left - environment.safeInsets.right, height: 50.0),
                transition: context.transition)
            
            let bottomPanelPadding: CGFloat = 12.0
            let bottomInset: CGFloat = environment.safeInsets.bottom > 0.0 ? environment.safeInsets.bottom + 5.0 : bottomPanelPadding
            let bottomPanel = bottomPanel.update(
                component: BlurredRectangle(
                    color: environment.theme.rootController.tabBar.backgroundColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: bottomPanelPadding + button.size.height + bottomInset),
                transition: context.transition
            )
            
            let bottomSeparator = bottomSeparator.update(
                component: Rectangle(
                    color: environment.theme.rootController.tabBar.separatorColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: UIScreenPixel),
                transition: context.transition
            )
            
            let scrollContent = scrollContent.update(
                component: ScrollComponent<EnvironmentType>(
                    content: AnyComponent(PremiumIntroScreenContentComponent(
                        context: context.component.context
                    )),
                    contentInsets: UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: bottomPanel.size.height, right: 0.0),
                    contentOffsetUpdated: { [weak state] topContentOffset, bottomContentOffset in
                        state?.topContentOffset = topContentOffset
                        state?.bottomContentOffset = bottomContentOffset
                        state?.updated(transition: .immediate)
                    }
                ),
                environment: { environment },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(background
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            context.add(scrollContent
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
                        
            let topPanelAlpha: CGFloat
            let titleOffset: CGFloat
            let titleScale: CGFloat
            let titleOffsetDelta = 160.0 - environment.navigationHeight / 2.0
            
            if let topContentOffset = state.topContentOffset {
                topPanelAlpha = min(30.0, max(0.0, topContentOffset - 64.0)) / 30.0
                titleOffset = topContentOffset
                titleScale = 1.0 - max(0.0, min(1.0, titleOffset / titleOffsetDelta)) * 0.36
            } else {
                topPanelAlpha = 0.0
                titleOffset = 0.0
                titleScale = 1.0
            }
            
            context.add(star
                .position(CGPoint(x: context.availableSize.width / 2.0, y: star.size.height / 2.0 - 10.0 - titleOffset * titleScale))
                .scale(titleScale)
            )
            
            context.add(topPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height / 2.0))
                .opacity(topPanelAlpha)
            )
            context.add(topSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: topPanel.size.height))
                .opacity(topPanelAlpha)
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: max(160.0 - titleOffset, environment.navigationHeight / 2.0)))
                .scale(titleScale)
            )
            
            let bottomPanelAlpha: CGFloat
            if let bottomContentOffset = state.bottomContentOffset {
                bottomPanelAlpha = min(16.0, bottomContentOffset) / 16.0
            } else {
                bottomPanelAlpha = 1.0
            }
            
            context.add(bottomPanel
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height / 2.0))
                .opacity(bottomPanelAlpha)
            )
            context.add(bottomSeparator
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height - bottomSeparator.size.height))
                .opacity(bottomPanelAlpha)
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height - bottomPanel.size.height + bottomPanelPadding + button.size.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class PremiumIntroScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let action: () -> Void
    
    private var didSetReady = false
    private let _ready = Promise<Bool>()
    public override var ready: Promise<Bool> {
        return self._ready
    }
    
    public init(context: AccountContext, action: @escaping () -> Void) {
        self.context = context
        self.action = action
                                
        super.init(context: context, component: PremiumIntroScreenComponent(context: context, action: action), navigationBarAppearance: .transparent)
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        let cancelItem = UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.setLeftBarButton(cancelItem, animated: false)
        
        self.navigationPresentation = .modal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if !self.didSetReady {
            if let view = self.node.hostView.findTaggedView(tag: StarComponent.View.Tag()) as? StarComponent.View {
                self.didSetReady = true
                self._ready.set(view.ready)
            }
        }
    }
}
