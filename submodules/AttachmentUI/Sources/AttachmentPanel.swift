import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import AccountContext
import AttachmentTextInputPanelNode
import ChatPresentationInterfaceState
import ChatSendMessageActionUI
import ChatTextLinkEditUI
import PhotoResources
import AnimatedStickerComponent
import SemanticStatusNode
import MediaResources
import MultilineTextComponent
import ShimmerEffect
import TextFormat
import LegacyMessageInputPanel
import LegacyMessageInputPanelInputView
import ReactionSelectionNode
import TopMessageReactions

private let buttonSize = CGSize(width: 88.0, height: 49.0)
private let smallButtonWidth: CGFloat = 69.0
private let iconSize = CGSize(width: 30.0, height: 30.0)
private let sideInset: CGFloat = 3.0

private final class IconComponent: Component {
    public let account: Account
    public let name: String
    public let fileReference: FileMediaReference?
    public let animationName: String?
    public let tintColor: UIColor?
    
    public init(account: Account, name: String, fileReference: FileMediaReference?, animationName: String?, tintColor: UIColor?) {
        self.account = account
        self.name = name
        self.fileReference = fileReference
        self.animationName = animationName
        self.tintColor = tintColor
    }
    
    public static func ==(lhs: IconComponent, rhs: IconComponent) -> Bool {
        if lhs.account !== rhs.account {
            return false
        }
        if lhs.name != rhs.name {
            return false
        }
        if lhs.fileReference?.media != rhs.fileReference?.media {
            return false
        }
        if lhs.animationName != rhs.animationName {
            return false
        }
        if lhs.tintColor != rhs.tintColor {
            return false
        }
        return false
    }
    
    public final class View: UIImageView {
        private var component: IconComponent?
        private var disposable: Disposable?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func update(component: IconComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            if self.component?.name != component.name || self.component?.fileReference?.media.fileId != component.fileReference?.media.fileId || self.component?.tintColor != component.tintColor {
                if let fileReference = component.fileReference {
                    let previousName = self.component?.name ?? ""
                    if !previousName.isEmpty {
                        self.image = nil
                    }
                    
                    self.disposable = (svgIconImageFile(account: component.account, fileReference: fileReference)
                    |> runOn(Queue.concurrentDefaultQueue())
                    |> deliverOnMainQueue).startStrict(next: { [weak self] transform in
                        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: availableSize, boundingSize: availableSize, intrinsicInsets: UIEdgeInsets())
                        let drawingContext = transform(arguments)
                        let image = drawingContext?.generateImage()?.withRenderingMode(.alwaysTemplate)
                        if let tintColor = component.tintColor {
                            self?.image = generateTintedImage(image: image, color: tintColor, backgroundColor: nil)
                        } else {
                            self?.image = image
                        }
                    }).strict()
                } else {
                    if let tintColor = component.tintColor {
                        self.image = generateTintedImage(image: UIImage(bundleImageName: component.name), color: tintColor, backgroundColor: nil)
                    } else {
                        self.image = UIImage(bundleImageName: component.name)
                    }
                }
            }
            self.component = component
                        
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


private final class AttachButtonComponent: CombinedComponent {
    let context: AccountContext
    let type: AttachmentButtonType
    let isSelected: Bool
    let strings: PresentationStrings
    let theme: PresentationTheme
    let action: () -> Void
    let longPressAction: () -> Void
    
    init(
        context: AccountContext,
        type: AttachmentButtonType,
        isSelected: Bool,
        strings: PresentationStrings,
        theme: PresentationTheme,
        action: @escaping () -> Void,
        longPressAction: @escaping () -> Void
    ) {
        self.context = context
        self.type = type
        self.isSelected = isSelected
        self.strings = strings
        self.theme = theme
        self.action = action
        self.longPressAction = longPressAction
    }

    static func ==(lhs: AttachButtonComponent, rhs: AttachButtonComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.type != rhs.type {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        return true
    }
    
    static var body: Body {
        let icon = Child(IconComponent.self)
        let animatedIcon = Child(AnimatedStickerComponent.self)
        let title = Child(MultilineTextComponent.self)
        let button = Child(Rectangle.self)

        return { context in
            let name: String
            let imageName: String
            var imageFile: TelegramMediaFile?
            var animationFile: TelegramMediaFile?
            var botPeer: EnginePeer?
            
            let component = context.component
            let strings = component.strings
            
            switch component.type {
            case .gallery:
                name = strings.Attachment_Gallery
                imageName = "Chat/Attach Menu/Gallery"
            case .file:
                name = strings.Attachment_File
                imageName = "Chat/Attach Menu/File"
            case .location:
                name = strings.Attachment_Location
                imageName = "Chat/Attach Menu/Location"
            case .todo:
                name = strings.Attachment_Todo
                imageName = "Chat/Attach Menu/Todo"
            case .contact:
                name = strings.Attachment_Contact
                imageName = "Chat/Attach Menu/Contact"
            case .poll:
                name = strings.Attachment_Poll
                imageName = "Chat/Attach Menu/Poll"
            case .gift:
                name = strings.Attachment_Gift
                imageName = "Chat/Attach Menu/Gift"
            case let .app(bot):
                botPeer = bot.peer
                name = bot.shortName
                imageName = ""
                if let file = bot.icons[.iOSAnimated] {
                    animationFile = file
                } else if let file = bot.icons[.iOSStatic] {
                    imageFile = file
                } else if let file = bot.icons[.default] {
                    imageFile = file
                }
            case .standalone:
                name = ""
                imageName = ""
                imageFile = nil
            case .quickReply:
                name = strings.Attachment_Reply
                imageName = "Chat/Attach Menu/Reply"
            }

            let tintColor = component.isSelected ? component.theme.rootController.tabBar.selectedIconColor : component.theme.rootController.tabBar.iconColor
            
            let iconSize = CGSize(width: 30.0, height: 30.0)
            let topInset: CGFloat = 4.0 + UIScreenPixel
            let spacing: CGFloat = 15.0 + UIScreenPixel
            
            let iconFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((context.availableSize.width - iconSize.width) / 2.0), y: topInset), size: iconSize)
            if let animationFile = animationFile {
                let icon = animatedIcon.update(
                    component: AnimatedStickerComponent(
                        account: component.context.account,
                        animation: AnimatedStickerComponent.Animation(
                            source: .file(media: animationFile),
                            scale: UIScreenScale,
                            loop: false
                        ),
                        tintColor: tintColor,
                        isAnimating: component.isSelected,
                        size: CGSize(width: iconSize.width, height: iconSize.height)
                    ),
                    availableSize: iconSize,
                    transition: context.transition
                )
                context.add(icon
                    .position(CGPoint(x: iconFrame.midX, y: iconFrame.midY))
                )
            } else {
                var fileReference: FileMediaReference?
                if let peer = botPeer.flatMap({ PeerReference($0._asPeer())}), let imageFile = imageFile {
                    fileReference = .attachBot(peer: peer, media: imageFile)
                }
                
                let icon = icon.update(
                    component: IconComponent(
                        account: component.context.account,
                        name: imageName,
                        fileReference: fileReference,
                        animationName: nil,
                        tintColor: tintColor
                    ),
                    availableSize: iconSize,
                    transition: context.transition
                )
                context.add(icon
                    .position(CGPoint(x: iconFrame.midX, y: iconFrame.midY))
                )
            }

            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: name,
                        font: Font.regular(10.0),
                        textColor: context.component.isSelected ? component.theme.rootController.tabBar.selectedTextColor : component.theme.rootController.tabBar.textColor,
                        paragraphAlignment: .center)),
                    horizontalAlignment: .center,
                    truncationType: .end,
                    maximumNumberOfLines: 1
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            
            let button = button.update(
                component: Rectangle(
                    color: .clear,
                    width: context.availableSize.width,
                    height: context.availableSize.height
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )

            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((context.availableSize.width - title.size.width) / 2.0), y: iconFrame.midY + spacing), size: title.size)
            
            context.add(title
                .position(CGPoint(x: titleFrame.midX, y: titleFrame.midY))
            )
            
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
                .gesture(.tap {
                    component.action()
                })
                .gesture(.longPress({ state in
                    if case .began = state {
                        component.longPressAction()
                    }
                }))
            )
                        
            return context.availableSize
        }
    }
}

private final class LoadingProgressNode: ASDisplayNode {
    var color: UIColor {
        didSet {
            self.foregroundNode.backgroundColor = self.color
        }
    }
    
    private let foregroundNode: ASDisplayNode
    
    init(color: UIColor) {
        self.color = color
        
        self.foregroundNode = ASDisplayNode()
        self.foregroundNode.backgroundColor = color
        
        super.init()
        
        self.addSubnode(self.foregroundNode)
    }
        
    private var _progress: CGFloat = 0.0
    func updateProgress(_ progress: CGFloat, animated: Bool = false) {
        if self._progress == progress && animated {
            return
        }
        
        var animated = animated
        if (progress < self._progress && animated) {
            animated = false
        }
        
        let size = self.bounds.size
        
        self._progress = progress
        
        let transition: ContainedViewLayoutTransition
        if animated && progress > 0.0 {
            transition = .animated(duration: 0.7, curve: .spring)
        } else {
            transition = .immediate
        }
        
        let alpaTransition: ContainedViewLayoutTransition
        if animated {
            alpaTransition = .animated(duration: 0.3, curve: .easeInOut)
        } else {
            alpaTransition = .immediate
        }
        
        transition.updateFrame(node: self.foregroundNode, frame: CGRect(x: -2.0, y: 0.0, width: (size.width + 4.0) * progress, height: size.height))
        
        let alpha: CGFloat = progress < 0.001 || progress > 0.999 ? 0.0 : 1.0
        alpaTransition.updateAlpha(node: self.foregroundNode, alpha: alpha)
    }
    
    override func layout() {
        super.layout()
        
        self.foregroundNode.cornerRadius = self.frame.height / 2.0
    }
}

private final class BadgeNode: ASDisplayNode {
    private var fillColor: UIColor
    private var strokeColor: UIColor
    private var textColor: UIColor
    
    private let textNode: ImmediateTextNode
    private let backgroundNode: ASImageNode
    
    private let font: UIFont = Font.with(size: 15.0, design: .round, weight: .bold)
    
    var text: String = "" {
        didSet {
            self.textNode.attributedText = NSAttributedString(string: self.text, font: self.font, textColor: self.textColor)
            self.invalidateCalculatedLayout()
        }
    }
    
    init(fillColor: UIColor, strokeColor: UIColor, textColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.textColor = textColor
        
        self.textNode = ImmediateTextNode()
        self.textNode.isUserInteractionEnabled = false
        self.textNode.displaysAsynchronously = false
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        self.backgroundNode.displayWithoutProcessing = true
        self.backgroundNode.displaysAsynchronously = false
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: fillColor, strokeColor: nil, strokeWidth: 1.0)
        
        super.init()
        
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.textNode)
        
        self.isUserInteractionEnabled = false
    }
    
    func updateTheme(fillColor: UIColor, strokeColor: UIColor, textColor: UIColor) {
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        self.textColor = textColor
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 18.0, color: fillColor, strokeColor: strokeColor, strokeWidth: 1.0)
        self.textNode.attributedText = NSAttributedString(string: self.text, font: self.font, textColor: self.textColor)
    }
    
    func animateBump(incremented: Bool) {
        if incremented {
            let firstTransition = ContainedViewLayoutTransition.animated(duration: 0.1, curve: .easeInOut)
            firstTransition.updateTransformScale(layer: self.backgroundNode.layer, scale: 1.2)
            firstTransition.updateTransformScale(layer: self.textNode.layer, scale: 1.2, completion: { finished in
                if finished {
                    let secondTransition = ContainedViewLayoutTransition.animated(duration: 0.1, curve: .easeInOut)
                    secondTransition.updateTransformScale(layer: self.backgroundNode.layer, scale: 1.0)
                    secondTransition.updateTransformScale(layer: self.textNode.layer, scale: 1.0)
                }
            })
        } else {
            let firstTransition = ContainedViewLayoutTransition.animated(duration: 0.1, curve: .easeInOut)
            firstTransition.updateTransformScale(layer: self.backgroundNode.layer, scale: 0.8)
            firstTransition.updateTransformScale(layer: self.textNode.layer, scale: 0.8, completion: { finished in
                if finished {
                    let secondTransition = ContainedViewLayoutTransition.animated(duration: 0.1, curve: .easeInOut)
                    secondTransition.updateTransformScale(layer: self.backgroundNode.layer, scale: 1.0)
                    secondTransition.updateTransformScale(layer: self.textNode.layer, scale: 1.0)
                }
            })
        }
    }
    
    func animateOut() {
        let timingFunction = CAMediaTimingFunctionName.easeInEaseOut.rawValue
        self.backgroundNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, delay: 0.0, timingFunction: timingFunction, removeOnCompletion: true, completion: nil)
        self.textNode.layer.animateScale(from: 1.0, to: 0.1, duration: 0.3, delay: 0.0, timingFunction: timingFunction, removeOnCompletion: true, completion: nil)
    }
    
    func update(_ constrainedSize: CGSize) -> CGSize {
        let badgeSize = self.textNode.updateLayout(constrainedSize)
        let backgroundSize = CGSize(width: max(18.0, badgeSize.width + 8.0), height: 18.0)
        let backgroundFrame = CGRect(origin: CGPoint(), size: backgroundSize)
        self.backgroundNode.frame = backgroundFrame
        self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels(backgroundFrame.midX - badgeSize.width / 2.0), y: floorToScreenPixels((backgroundFrame.size.height - badgeSize.height) / 2.0) - UIScreenPixel), size: badgeSize)
        
        return backgroundSize
    }
}

private final class MainButtonNode: HighlightTrackingButtonNode {
    private var state: AttachmentMainButtonState
    private var size: CGSize?
    
    private let backgroundAnimationNode: ASImageNode
    private var iconNode: ASImageNode?
    fileprivate let textNode: ImmediateTextNode
    private var badgeNode: BadgeNode?
    private let statusNode: SemanticStatusNode
    private var progressNode: ASImageNode?
        
    private var shimmerView: ShimmerEffectForegroundView?
    private var borderView: UIView?
    private var borderMaskView: UIView?
    private var borderShimmerView: ShimmerEffectForegroundView?
    
    override init(pointerStyle: PointerStyle? = nil) {
        self.state = AttachmentMainButtonState.initial
        
        self.backgroundAnimationNode = ASImageNode()
        self.backgroundAnimationNode.displaysAsynchronously = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.textAlignment = .center
        self.textNode.displaysAsynchronously = false
        
        self.statusNode = SemanticStatusNode(backgroundNodeColor: .clear, foregroundNodeColor: .white)
        
        super.init(pointerStyle: pointerStyle)
        
        self.isExclusiveTouch = true
        self.clipsToBounds = true
                
        self.addSubnode(self.backgroundAnimationNode)
        self.addSubnode(self.textNode)
        self.addSubnode(self.statusNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self, strongSelf.state.isEnabled {
                if highlighted {
                    strongSelf.layer.removeAnimation(forKey: "opacity")
                    strongSelf.alpha = 0.65
                } else {
                    strongSelf.alpha = 1.0
                    strongSelf.layer.animateAlpha(from: 0.65, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.cornerRadius = 12.0
        if #available(iOS 13.0, *) {
            self.layer.cornerCurve = .continuous
        }
    }
    
    public func transitionToProgress() {
        guard self.progressNode == nil, let size = self.size else {
            return
        }
        
        self.isUserInteractionEnabled = false
        
        let rotationAnimation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        rotationAnimation.duration = 1.0
        rotationAnimation.fromValue = NSNumber(value: Float(0.0))
        rotationAnimation.toValue = NSNumber(value: Float.pi * 2.0)
        rotationAnimation.repeatCount = Float.infinity
        rotationAnimation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        rotationAnimation.beginTime = 1.0
        
        let buttonOffset: CGFloat = 0.0
        let buttonWidth = size.width
        
        let progressNode = ASImageNode()
        
        let diameter: CGFloat = size.height - 22.0
        let progressFrame = CGRect(origin: CGPoint(x: floorToScreenPixels(buttonOffset + (buttonWidth - diameter) / 2.0), y: floorToScreenPixels((size.height - diameter) / 2.0)), size: CGSize(width: diameter, height: diameter))
        progressNode.frame = progressFrame
        progressNode.image = generateIndefiniteActivityIndicatorImage(color: self.state.textColor, diameter: diameter, lineWidth: 3.0)
            
        self.addSubnode(progressNode)
 
        progressNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        progressNode.layer.add(rotationAnimation, forKey: "progressRotation")
        self.progressNode = progressNode
        
        self.textNode.alpha = 0.0
        self.textNode.layer.animateAlpha(from: 0.55, to: 0.0, duration: 0.2)
        
        self.shimmerView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.borderShimmerView?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
    }
    
    public func transitionFromProgress() {
        guard let progressNode = self.progressNode else {
            return
        }
        self.progressNode = nil
        
        progressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak progressNode, weak self] _ in
            progressNode?.removeFromSupernode()
            self?.isUserInteractionEnabled = true
        })
        
        self.textNode.alpha = 1.0
        self.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        self.shimmerView?.layer.removeAllAnimations()
        self.shimmerView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.borderShimmerView?.layer.removeAllAnimations()
        self.borderShimmerView?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
    }
    
    private func setupShimmering() {
        if self.state.hasShimmer {
            if self.shimmerView == nil {
                let shimmerView = ShimmerEffectForegroundView()
                shimmerView.isUserInteractionEnabled = false
                self.shimmerView = shimmerView
                
                shimmerView.layer.cornerRadius = 12.0
                if #available(iOS 13.0, *) {
                    shimmerView.layer.cornerCurve = .continuous
                }
                
                let borderView = UIView()
                borderView.isUserInteractionEnabled = false
                self.borderView = borderView
                
                let borderMaskView = UIView()
                borderMaskView.layer.borderWidth = 1.0 + UIScreenPixel
                borderMaskView.layer.borderColor = UIColor.white.cgColor
                borderMaskView.layer.cornerRadius = 12.0
                borderView.mask = borderMaskView
                self.borderMaskView = borderMaskView
                
                let borderShimmerView = ShimmerEffectForegroundView()
                self.borderShimmerView = borderShimmerView
                borderView.addSubview(borderShimmerView)
                
                self.view.addSubview(shimmerView)
                self.view.addSubview(borderView)
                
                self.updateShimmerParameters()
                
                if let size = self.size {
                    self.updateLayout(size: size, state: state, transition: .immediate)
                }
            }
        } else if self.shimmerView != nil {
            self.shimmerView?.removeFromSuperview()
            self.borderView?.removeFromSuperview()
            self.borderMaskView?.removeFromSuperview()
            self.borderShimmerView?.removeFromSuperview()
            
            self.shimmerView = nil
            self.borderView = nil
            self.borderMaskView = nil
            self.borderShimmerView = nil
        }
    }
    
    func updateShimmerParameters() {
        guard let shimmerView = self.shimmerView, let borderShimmerView = self.borderShimmerView else {
            return
        }
        
        let color = UIColor.white
        let alpha: CGFloat
        let borderAlpha: CGFloat
        let compositingFilter: String?
        if color.lightness > 0.5 {
            alpha = 0.5
            borderAlpha = 0.75
            compositingFilter = "overlayBlendMode"
        } else {
            alpha = 0.2
            borderAlpha = 0.3
            compositingFilter = nil
        }
        
        shimmerView.update(backgroundColor: .clear, foregroundColor: color.withAlphaComponent(alpha), gradientSize: 70.0, globalTimeOffset: false, duration: 4.0, horizontal: true)
        borderShimmerView.update(backgroundColor: .clear, foregroundColor: color.withAlphaComponent(borderAlpha), gradientSize: 70.0, globalTimeOffset: false, duration: 4.0, horizontal: true)
        
        shimmerView.layer.compositingFilter = compositingFilter
        borderShimmerView.layer.compositingFilter = compositingFilter
    }
    
    private func setupGradientAnimations() {
        if let _ = self.backgroundAnimationNode.layer.animation(forKey: "movement") {
        } else {
            let offset = (self.backgroundAnimationNode.frame.width - self.frame.width) / 2.0
            let previousValue = self.backgroundAnimationNode.position.x
            var newValue: CGFloat = offset
            if offset - previousValue < self.backgroundAnimationNode.frame.width * 0.25 {
                newValue -= self.backgroundAnimationNode.frame.width * 0.35
            }
            self.backgroundAnimationNode.position = CGPoint(x: newValue, y: self.backgroundAnimationNode.bounds.size.height / 2.0)
            
            CATransaction.begin()
            
            let animation = CABasicAnimation(keyPath: "position.x")
            animation.duration = 4.5
            animation.fromValue = previousValue
            animation.toValue = newValue
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            
            CATransaction.setCompletionBlock { [weak self] in
                self?.setupGradientAnimations()
            }

            self.backgroundAnimationNode.layer.add(animation, forKey: "movement")
            CATransaction.commit()
        }
    }
    
    func updateLayout(size: CGSize, state: AttachmentMainButtonState, animateBackground: Bool = false, transition: ContainedViewLayoutTransition) {
        let previousState = self.state
        self.state = state
        self.size = size
        
        self.isUserInteractionEnabled = state.isVisible
        
        self.setupShimmering()
        
        let colorUpdated = previousState.textColor != state.textColor
        if let progressNode = self.progressNode, colorUpdated {
            let diameter: CGFloat = size.height - 22.0
            progressNode.image = generateIndefiniteActivityIndicatorImage(color: state.textColor, diameter: diameter, lineWidth: 3.0)
        }
        
        var textFrame: CGRect = .zero
        if let text = state.text {
            let font: UIFont
            switch state.font {
            case .regular:
                font = Font.regular(17.0)
            case .bold:
                font = Font.semibold(17.0)
            }
            self.textNode.attributedText = NSAttributedString(string: text, font: font, textColor: state.textColor)
            
            let textSize = self.textNode.updateLayout(size)
            textFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - textSize.width) / 2.0), y: floorToScreenPixels((size.height - textSize.height) / 2.0)), size: textSize)
            
            switch state.background {
            case let .color(backgroundColor):
                self.backgroundAnimationNode.image = nil
                self.backgroundAnimationNode.layer.removeAllAnimations()
                if animateBackground {
                    ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear).updateBackgroundColor(node: self, color: backgroundColor)
                } else {
                    self.backgroundColor = backgroundColor
                }
            case .premium:
                if self.backgroundAnimationNode.image == nil {
                    let backgroundColors = [
                        UIColor(rgb: 0x0077ff),
                        UIColor(rgb: 0x6b93ff),
                        UIColor(rgb: 0x8878ff),
                        UIColor(rgb: 0xe46ace)
                    ]
                    var locations: [CGFloat] = []
                    let delta = 1.0 / CGFloat(backgroundColors.count - 1)
                    for i in 0 ..< backgroundColors.count {
                        locations.append(delta * CGFloat(i))
                    }
                    self.backgroundAnimationNode.image = generateGradientImage(size: CGSize(width: 200.0, height: 50.0), colors: backgroundColors, locations: locations, direction: .horizontal)
                    
                    self.backgroundAnimationNode.bounds = CGRect(origin: CGPoint(), size: CGSize(width: size.width * 2.4, height: size.height))
                    if self.backgroundAnimationNode.layer.animation(forKey: "movement") == nil {
                        self.backgroundAnimationNode.position = CGPoint(x: size.width * 2.4 / 2.0 - self.backgroundAnimationNode.frame.width * 0.35, y: size.height / 2.0)
                    }
                    self.setupGradientAnimations()
                }
                self.backgroundColor = UIColor(rgb: 0x8878ff)
            }
        }
        
        if let badge = state.badge {
            let badgeNode: BadgeNode
            var badgeTransition = transition
            if let current = self.badgeNode {
                badgeNode = current
            } else {
                badgeTransition = .immediate
                var textColor: UIColor
                switch state.background {
                case let .color(backgroundColor):
                    textColor = backgroundColor
                case .premium:
                    textColor = UIColor(rgb: 0x0077ff)
                }
                badgeNode = BadgeNode(fillColor: state.textColor, strokeColor: .clear, textColor: textColor)
                self.badgeNode = badgeNode
                self.addSubnode(badgeNode)
            }
            badgeNode.text = badge
            let badgeSize = badgeNode.update(CGSize(width: 100.0, height: 100.0))
            textFrame.origin.x -= badgeSize.width / 2.0
            badgeTransition.updateFrame(node: badgeNode, frame: CGRect(origin: CGPoint(x: textFrame.maxX + 6.0, y: textFrame.minY + floorToScreenPixels((textFrame.height - badgeSize.height) * 0.5)), size: badgeSize))
        } else if let badgeNode = self.badgeNode {
            self.badgeNode = nil
            badgeNode.removeFromSupernode()
        }
        
        if let iconName = state.iconName {
            let iconNode: ASImageNode
            if let current = self.iconNode {
                iconNode = current
            } else {
                iconNode = ASImageNode()
                iconNode.displaysAsynchronously = false
                iconNode.image = generateTintedImage(image: UIImage(bundleImageName: iconName), color: state.textColor)
                self.iconNode = iconNode
                self.addSubnode(iconNode)
            }
            if let iconSize = iconNode.image?.size {
                textFrame.origin.x += (iconSize.width + 6.0) / 2.0
                iconNode.frame = CGRect(origin: CGPoint(x: textFrame.minX - iconSize.width - 6.0, y: textFrame.minY + floorToScreenPixels((textFrame.height - iconSize.height) * 0.5)), size: iconSize)
            }
        } else if let iconNode = self.iconNode {
            self.iconNode = nil
            iconNode.removeFromSupernode()
        }
        
        if self.textNode.frame.width.isZero {
            self.textNode.frame = textFrame
        } else {
            self.textNode.bounds = CGRect(origin: .zero, size: textFrame.size)
            transition.updatePosition(node: self.textNode, position: textFrame.center)
        }
        
        if previousState.progress != state.progress {
            if state.progress == .center {
                self.transitionToProgress()
            } else {
                self.transitionFromProgress()
            }
        }
                
        if let shimmerView = self.shimmerView, let borderView = self.borderView, let borderMaskView = self.borderMaskView, let borderShimmerView = self.borderShimmerView {
            let buttonFrame = CGRect(origin: .zero, size: size)
            let buttonWidth = size.width
            let buttonHeight = size.height
            transition.updateFrame(view: shimmerView, frame: buttonFrame)
            transition.updateFrame(view: borderView, frame: buttonFrame)
            transition.updateFrame(view: borderMaskView, frame: buttonFrame)
            transition.updateFrame(view: borderShimmerView, frame: buttonFrame)
            
            shimmerView.updateAbsoluteRect(CGRect(origin: CGPoint(x: buttonWidth * 4.0, y: 0.0), size: size), within: CGSize(width: buttonWidth * 9.0, height: buttonHeight))
            borderShimmerView.updateAbsoluteRect(CGRect(origin: CGPoint(x: buttonWidth * 4.0, y: 0.0), size: size), within: CGSize(width: buttonWidth * 9.0, height: buttonHeight))
        }
        
        let statusSize = CGSize(width: 20.0, height: 20.0)
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(x: size.width - statusSize.width - 15.0, y: floorToScreenPixels((size.height - statusSize.height) / 2.0)), size: statusSize))
        
        self.statusNode.foregroundNodeColor = state.textColor
        self.statusNode.transitionToState(state.progress == .side ? .progress(value: nil, cancelEnabled: false, appearance: SemanticStatusNodeState.ProgressAppearance(inset: 0.0, lineWidth: 2.0), animateRotation: true) : .none)
    }
}

final class AttachmentPanel: ASDisplayNode, ASScrollViewDelegate {
    private weak var controller: AttachmentController?
    private let context: AccountContext
    private let isScheduledMessages: Bool
    private var presentationData: PresentationData
    private var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private var presentationDataDisposable: Disposable?
    private var peerDisposable: Disposable?
    
    private var iconDisposables: [MediaId: Disposable] = [:]
    
    private var presentationInterfaceState: ChatPresentationInterfaceState
    private var interfaceInteraction: ChatPanelInterfaceInteraction?
    
    private let makeEntityInputView: () -> AttachmentTextInputPanelInputView?
    
    private let containerNode: ASDisplayNode
    private let backgroundNode: NavigationBackgroundNode
    private let scrollNode: ASScrollNode
    private let separatorNode: ASDisplayNode
    private var buttonViews: [AnyHashable: ComponentHostView<Empty>] = [:]
    
    private var textInputPanelNode: AttachmentTextInputPanelNode?
    private var progressNode: LoadingProgressNode?
    private var mainButtonNode: MainButtonNode
    private var secondaryButtonNode: MainButtonNode
    
    private var loadingProgress: CGFloat?
    private var mainButtonState: AttachmentMainButtonState = .initial
    private var secondaryButtonState: AttachmentMainButtonState = .initial
    private var customBottomPanelBackgroundColor: UIColor?
    
    private var elevateProgress: Bool = false
    private var buttons: [AttachmentButtonType] = []
    private var selectedIndex: Int = 0
    private(set) var isSelecting: Bool = false
    private var selectionCount: Int = 0
    
    private var _isButtonVisible: Bool = false
    var isButtonVisible: Bool {
        return self.mainButtonState.isVisible || self.secondaryButtonState.isVisible
    }
    
    private var validLayout: ContainerViewLayout?
    private var scrollLayout: (width: CGFloat, contentSize: CGSize)?
    
    var fromMenu: Bool = false
    var isStandalone: Bool = false
    
    var selectionChanged: (AttachmentButtonType) -> Bool = { _ in return false }
    var longPressed: (AttachmentButtonType) -> Void = { _ in }

    var beganTextEditing: () -> Void = {}
    var textUpdated: (NSAttributedString) -> Void = { _ in }
    var sendMessagePressed: (AttachmentTextInputPanelSendMode, ChatSendMessageActionSheetController.SendParameters?) -> Void = { _, _ in }
    var requestLayout: () -> Void = {}
    var present: (ViewController) -> Void = { _ in }
    var presentInGlobalOverlay: (ViewController) -> Void = { _ in }
    
    var getCurrentSendMessageContextMediaPreview: (() -> ChatSendMessageContextScreenMediaPreview?)?
    
    var onMainButtonPressed: () -> Void = { }
    var onSecondaryButtonPressed: () -> Void = { }
    
    init(controller: AttachmentController, context: AccountContext, chatLocation: ChatLocation?, isScheduledMessages: Bool, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, makeEntityInputView: @escaping () -> AttachmentTextInputPanelInputView?) {
        self.controller = controller
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        self.isScheduledMessages = isScheduledMessages
        
        self.makeEntityInputView = makeEntityInputView
                
        self.presentationInterfaceState = ChatPresentationInterfaceState(chatWallpaper: .builtin(WallpaperSettings()), theme: self.presentationData.theme, strings: self.presentationData.strings, dateTimeFormat: self.presentationData.dateTimeFormat, nameDisplayOrder: self.presentationData.nameDisplayOrder, limitsConfiguration: self.context.currentLimitsConfiguration.with { $0 }, fontSize: self.presentationData.chatFontSize, bubbleCorners: self.presentationData.chatBubbleCorners, accountPeerId: self.context.account.peerId, mode: .standard(.default), chatLocation: chatLocation ?? .peer(id: context.account.peerId), subject: nil, peerNearbyData: nil, greetingData: nil, pendingUnpinnedAllMessages: false, activeGroupCallInfo: nil, hasActiveGroupCall: false, importState: nil, threadData: nil, isGeneralThreadClosed: nil, replyMessage: nil, accountPeerColor: nil, businessIntro: nil)
        
        self.containerNode = ASDisplayNode()
        self.containerNode.clipsToBounds = true
        
        self.scrollNode = ASScrollNode()
        
        self.backgroundNode = NavigationBackgroundNode(color: self.presentationData.theme.rootController.tabBar.backgroundColor)
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = self.presentationData.theme.rootController.tabBar.separatorColor
        
        self.mainButtonNode = MainButtonNode()
        self.secondaryButtonNode = MainButtonNode()
        
        super.init()
                        
        self.addSubnode(self.containerNode)
        self.containerNode.addSubnode(self.backgroundNode)
        self.containerNode.addSubnode(self.separatorNode)
        self.containerNode.addSubnode(self.scrollNode)
        
        self.addSubnode(self.secondaryButtonNode)
        self.addSubnode(self.mainButtonNode)
        
        self.mainButtonNode.addTarget(self, action: #selector(self.mainButtonPressed), forControlEvents: .touchUpInside)
        self.secondaryButtonNode.addTarget(self, action: #selector(self.secondaryButtonPressed), forControlEvents: .touchUpInside)
        
        self.interfaceInteraction = ChatPanelInterfaceInteraction(setupReplyMessage: { _, _  in
        }, setupEditMessage: { _, _ in
        }, beginMessageSelection: { _, _ in
        }, cancelMessageSelection: { _ in
        }, deleteSelectedMessages: {
        }, reportSelectedMessages: {
        }, reportMessages: { _, _ in
        }, blockMessageAuthor: { _, _ in
        }, deleteMessages: { _, _, f in
            f(.default)
        }, forwardSelectedMessages: {
        }, forwardCurrentForwardMessages: {
        }, forwardMessages: { _ in
        }, updateForwardOptionsState: { [weak self] value in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, { $0.updatedInterfaceState({ $0.withUpdatedForwardOptionsState($0.forwardOptionsState) }) })
            }
        }, presentForwardOptions: { _ in
        }, presentReplyOptions: { _ in
        }, presentLinkOptions: { _ in
        }, presentSuggestPostOptions: {
        }, shareSelectedMessages: {
        }, updateTextInputStateAndMode: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                    let (updatedState, updatedMode) = f(state.interfaceState.effectiveInputState, state.inputMode)
                    return state.updatedInterfaceState { interfaceState in
                        return interfaceState.withUpdatedEffectiveInputState(updatedState)
                    }.updatedInputMode({ _ in updatedMode })
                })
            }
        }, updateInputModeAndDismissedButtonKeyboardMessageId: { [weak self] f in
            if let strongSelf = self {
                strongSelf.updateChatPresentationInterfaceState(animated: true, {
                    let (updatedInputMode, updatedClosedButtonKeyboardMessageId) = f($0)
                    return $0.updatedInputMode({ _ in return updatedInputMode }).updatedInterfaceState({
                        $0.withUpdatedMessageActionsState({ value in
                            var value = value
                            value.closedButtonKeyboardMessageId = updatedClosedButtonKeyboardMessageId
                            return value
                        })
                    })
                })
            }
        }, openStickers: {
        }, editMessage: {
        }, beginMessageSearch: { _, _ in
        }, dismissMessageSearch: {
        }, updateMessageSearch: { _ in
        }, openSearchResults: {
        }, navigateMessageSearch: { _ in
        }, openCalendarSearch: {
        }, toggleMembersSearch: { _ in
        }, navigateToMessage: { _, _, _, _ in
        }, navigateToChat: { _ in
        }, navigateToProfile: { _ in
        }, openPeerInfo: {
        }, togglePeerNotifications: {
        }, sendContextResult: { _, _, _, _ in
            return false
        }, sendBotCommand: { _, _ in
        }, sendShortcut: { _ in
        }, openEditShortcuts: {
        }, sendBotStart: { _ in
        }, botSwitchChatWithPayload: { _, _ in
        }, beginMediaRecording: { _ in
        }, finishMediaRecording: { _ in
        }, stopMediaRecording: {
        }, lockMediaRecording: {
        }, resumeMediaRecording: {  
        }, deleteRecordedMedia: {
        }, sendRecordedMedia: { _, _ in
        }, displayRestrictedInfo: { _, _ in
        }, displayVideoUnmuteTip: { _ in
        }, switchMediaRecordingMode: {
        }, setupMessageAutoremoveTimeout: {
        }, sendSticker: { _, _, _, _, _, _ in
            return false
        }, unblockPeer: {
        }, pinMessage: { _, _ in
        }, unpinMessage: { _, _, _ in
        }, unpinAllMessages: {
        }, openPinnedList: { _ in
        }, shareAccountContact: {
        }, reportPeer: {
        }, presentPeerContact: {
        }, dismissReportPeer: {
        }, deleteChat: {
        }, beginCall: { _ in
        }, toggleMessageStickerStarred: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, getNavigationController: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, navigateFeed: {
        }, openGrouping: {
        }, toggleSilentPost: {
        }, requestUnvoteInMessage: { _ in
        }, requestStopPollInMessage: { _ in
        }, updateInputLanguage: { _ in
        }, unarchiveChat: {
        }, openLinkEditing: { [weak self] in
            if let strongSelf = self {
                var selectionRange: Range<Int>?
                var text: NSAttributedString?
                var inputMode: ChatInputMode?

                strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                    selectionRange = state.interfaceState.effectiveInputState.selectionRange
                    if let selectionRange = selectionRange {
                        text = state.interfaceState.effectiveInputState.inputText.attributedSubstring(from: NSRange(location: selectionRange.startIndex, length: selectionRange.count))
                    }
                    inputMode = state.inputMode
                    return state
                })
                
                var link: String?
                if let text {
                    text.enumerateAttributes(in: NSMakeRange(0, text.length)) { attributes, _, _ in
                        if let linkAttribute = attributes[ChatTextInputAttributes.textUrl] as? ChatTextInputTextUrlAttribute {
                            link = linkAttribute.url
                        }
                    }
                }

                let presentationData = strongSelf.context.sharedContext.currentPresentationData.with { $0 }
                let controller = chatTextLinkEditController(sharedContext: strongSelf.context.sharedContext, updatedPresentationData: (presentationData, .never()), account: strongSelf.context.account, text: text?.string ?? "", link: link, apply: { [weak self] link in
                    if let strongSelf = self, let inputMode = inputMode, let selectionRange = selectionRange {
                        if let link = link {
                            strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                                return state.updatedInterfaceState({
                                    $0.withUpdatedEffectiveInputState(chatTextInputAddLinkAttribute($0.effectiveInputState, selectionRange: selectionRange, url: link))
                                })
                            })
                        }
                        if let textInputPanelNode = strongSelf.textInputPanelNode {
                            textInputPanelNode.ensureFocused()
                        }
                        strongSelf.updateChatPresentationInterfaceState(animated: true, { state in
                            return state.updatedInputMode({ _ in return inputMode }).updatedInterfaceState({
                                $0.withUpdatedEffectiveInputState(ChatTextInputState(inputText: $0.effectiveInputState.inputText, selectionRange: selectionRange.endIndex ..< selectionRange.endIndex))
                            })
                        })
                    }
                })
                strongSelf.present(controller)
            }
        }, displaySlowmodeTooltip: { _, _ in
        }, displaySendMessageOptions: { [weak self] node, gesture in
            guard let strongSelf = self, let textInputPanelNode = strongSelf.textInputPanelNode else {
                return
            }
            textInputPanelNode.loadTextInputNodeIfNeeded()
            guard let textInputNode = textInputPanelNode.textInputNode, let peerId = chatLocation?.peerId else {
                return
            }
            
            var hasEntityKeyboard = false
            if case .media = strongSelf.presentationInterfaceState.inputMode {
                hasEntityKeyboard = true
            }
            
            let effectItems: Signal<[ReactionItem]?, NoError>
            if strongSelf.presentationInterfaceState.chatLocation.peerId != strongSelf.context.account.peerId && strongSelf.presentationInterfaceState.chatLocation.peerId?.namespace == Namespaces.Peer.CloudUser {
                effectItems = effectMessageReactions(context: strongSelf.context)
                |> map(Optional.init)
            } else {
                effectItems = .single(nil)
            }
            
            let availableMessageEffects = strongSelf.context.availableMessageEffects |> take(1)
            let hasPremium = strongSelf.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.context.account.peerId))
            |> map { peer -> Bool in
                guard case let .user(user) = peer else {
                    return false
                }
                return user.isPremium
            }
            
            let _ = (combineLatest(
                strongSelf.context.account.viewTracker.peerView(peerId) |> take(1),
                effectItems,
                availableMessageEffects,
                hasPremium
            )
            |> deliverOnMainQueue).startStandalone(next: { [weak self] peerView, effectItems, availableMessageEffects, hasPremium in
                guard let strongSelf = self, let peer = peerViewMainPeer(peerView) else {
                    return
                }
                var sendWhenOnlineAvailable = false
                if let presence = peerView.peerPresences[peer.id] as? TelegramUserPresence, case let .present(until) = presence.status {
                    let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                    if currentTime > until {
                        sendWhenOnlineAvailable = true
                    }
                }
                if peer.id.isTelegramNotifications {
                    sendWhenOnlineAvailable = false
                }
                
                let mediaPreview = strongSelf.getCurrentSendMessageContextMediaPreview?()
                let isReady: Signal<Bool, NoError>
                if let mediaPreview {
                    isReady = mediaPreview.isReady
                    |> filter { $0 }
                    |> take(1)
                    |> timeout(0.5, queue: .mainQueue(), alternate: .single(true))
                } else {
                    isReady = .single(true)
                }
                
                var captionIsAboveMedia: Signal<Bool, NoError> = .single(false)
                var canMakePaidContent = false
                var currentPrice: Int64?
                var hasTimers = false
                if let controller = strongSelf.controller, let mediaPickerContext = controller.mediaPickerContext {
                    captionIsAboveMedia = mediaPickerContext.captionIsAboveMedia
                    canMakePaidContent = mediaPickerContext.canMakePaidContent
                    currentPrice = mediaPickerContext.price
                    hasTimers = mediaPickerContext.hasTimers
                }
                
                let _ = (combineLatest(
                    isReady,
                    captionIsAboveMedia |> take(1),
                    ChatSendMessageContextScreen.initialData(context: strongSelf.context, currentMessageEffectId: nil)
                )
                |> deliverOnMainQueue).start(next: { [weak strongSelf] _, captionIsAboveMedia, initialData in
                    guard let strongSelf else {
                        return
                    }
                    
                    let controller = makeChatSendMessageActionSheetController(
                        initialData: initialData,
                        context: strongSelf.context,
                        updatedPresentationData: strongSelf.updatedPresentationData,
                        peerId: strongSelf.presentationInterfaceState.chatLocation.peerId,
                        params: .sendMessage(SendMessageActionSheetControllerParams.SendMessage(
                            isScheduledMessages: false,
                            mediaPreview: mediaPreview,
                            mediaCaptionIsAbove: (captionIsAboveMedia, { [weak strongSelf] value in
                                guard let strongSelf, let controller = strongSelf.controller, let mediaPickerContext = controller.mediaPickerContext else {
                                    return
                                }
                                mediaPickerContext.setCaptionIsAboveMedia(value)
                            }),
                            messageEffect: nil,
                            attachment: true,
                            canSendWhenOnline: sendWhenOnlineAvailable,
                            forwardMessageIds: strongSelf.presentationInterfaceState.interfaceState.forwardMessageIds ?? [],
                            canMakePaidContent: canMakePaidContent,
                            currentPrice: currentPrice,
                            hasTimers: hasTimers,
                            sendPaidMessageStars: strongSelf.presentationInterfaceState.sendPaidMessageStars,
                            isMonoforum: strongSelf.presentationInterfaceState.renderedPeer?.peer?.isMonoForum ?? false
                        )),
                        hasEntityKeyboard: hasEntityKeyboard,
                        gesture: gesture,
                        sourceSendButton: node,
                        textInputView: textInputNode.textView,
                        emojiViewProvider: textInputPanelNode.emojiViewProvider,
                        completion: {
                        },
                        sendMessage: { [weak textInputPanelNode] mode, messageEffect in
                            switch mode {
                            case .generic:
                                textInputPanelNode?.sendMessage(.generic, messageEffect)
                            case .silently:
                                textInputPanelNode?.sendMessage(.silent, messageEffect)
                            case .whenOnline:
                                textInputPanelNode?.sendMessage(.whenOnline, messageEffect)
                            }
                        },
                        schedule: { [weak textInputPanelNode] messageEffect in
                            textInputPanelNode?.sendMessage(.schedule, messageEffect)
                        },
                        editPrice: { [weak strongSelf] price in
                            guard let strongSelf, let controller = strongSelf.controller, let mediaPickerContext = controller.mediaPickerContext else {
                                return
                            }
                            mediaPickerContext.setPrice(price)
                        },
                        openPremiumPaywall: { [weak self] c in
                            guard let self else {
                                return
                            }
                            self.controller?.push(c)
                        },
                        reactionItems: effectItems,
                        availableMessageEffects: availableMessageEffects,
                        isPremium: hasPremium
                    )
                    strongSelf.presentInGlobalOverlay(controller)
                })
            })
        }, openScheduledMessages: {
        }, openPeersNearby: {
        }, displaySearchResultsTooltip: { _, _ in
        }, unarchivePeer: {
        }, scrollToTop: {
        }, viewReplies: { _, _ in
        }, activatePinnedListPreview: { _, _ in
        }, joinGroupCall: { _ in
        }, presentInviteMembers: {
        }, presentGigagroupHelp: {
        }, openMonoforum: {
        }, editMessageMedia: { _, _ in
        }, updateShowCommands: { _ in
        }, updateShowSendAsPeers: { _ in
        }, openInviteRequests: {
        }, openSendAsPeer: { _, _ in
        }, presentChatRequestAdminInfo: {
        }, displayCopyProtectionTip: { _, _ in
        }, openWebView: { _, _, _, _ in  
        }, updateShowWebView: { _ in
        }, insertText: { _ in
        }, backwardsDeleteText: {
        }, restartTopic: {
        }, toggleTranslation: { _ in
        }, changeTranslationLanguage: { _ in
        }, addDoNotTranslateLanguage: { _ in
        }, hideTranslationPanel: {
        }, openPremiumGift: {
        }, openSuggestPost: { _, _ in
        }, openPremiumRequiredForMessaging: {
        }, openStarsPurchase: { _ in
        }, openMessagePayment: {
        }, openBoostToUnrestrict: {
        }, updateRecordingTrimRange: { _, _, _, _ in
        }, dismissAllTooltips: {  
        }, editTodoMessage: { _, _, _ in
        }, updateHistoryFilter: { _ in
        }, updateChatLocationThread: { _, _ in
        }, toggleChatSidebarMode: {
        }, updateDisplayHistoryFilterAsList: { _ in
        }, requestLayout: { _ in
        }, chatController: {
            return nil
        }, statuses: nil)
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                strongSelf.presentationData = presentationData
                
                strongSelf.backgroundNode.updateColor(color: strongSelf.customBottomPanelBackgroundColor ?? presentationData.theme.rootController.tabBar.backgroundColor, transition: .immediate)
                strongSelf.separatorNode.backgroundColor = presentationData.theme.rootController.tabBar.separatorColor
                
                strongSelf.updateChatPresentationInterfaceState({ $0.updatedTheme(presentationData.theme) })
            
                if let layout = strongSelf.validLayout {
                    let _ = strongSelf.update(layout: layout, buttons: strongSelf.buttons, isSelecting: strongSelf.isSelecting, selectionCount: strongSelf.selectionCount, elevateProgress: strongSelf.elevateProgress, transition: .immediate)
                }
            }
        }).strict()
        
        if let peerId = chatLocation?.peerId {
            self.peerDisposable = ((self.context.account.viewTracker.peerView(peerId)
            |> map { view -> StarsAmount? in
                if let data = view.cachedData as? CachedUserData {
                    return data.sendPaidMessageStars
                } else if let channel = peerViewMainPeer(view) as? TelegramChannel {
                    if channel.isMonoForum, let linkedMonoforumId = channel.linkedMonoforumId, let mainChannel = view.peers[linkedMonoforumId] as? TelegramChannel, mainChannel.hasPermission(.manageDirect) {
                        return nil
                    } else {
                        return channel.sendPaidMessageStars
                    }
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged
            |> deliverOnMainQueue).start(next: { [weak self] amount in
                guard let self else {
                    return
                }
                self.updateChatPresentationInterfaceState({ $0.updatedSendPaidMessageStars(amount) })
            }))
        }
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.peerDisposable?.dispose()
        for (_, disposable) in self.iconDisposables {
            disposable.dispose()
        }
    }
    
    override func didLoad() {
        super.didLoad()
        if #available(iOS 13.0, *) {
            self.containerNode.layer.cornerCurve = .continuous
        }
    
        self.scrollNode.view.delegate = self.wrappedScrollViewDelegate
        self.scrollNode.view.showsHorizontalScrollIndicator = false
        self.scrollNode.view.showsVerticalScrollIndicator = false
        
        self.view.accessibilityTraits = .tabBar
    }
    
    @objc private func mainButtonPressed() {
        self.onMainButtonPressed()
    }
    
    @objc private func secondaryButtonPressed() {
        self.onSecondaryButtonPressed()
    }
    
    func updateBackgroundAlpha(_ alpha: CGFloat, transition: ContainedViewLayoutTransition) {
        transition.updateAlpha(node: self.separatorNode, alpha: alpha)
        transition.updateAlpha(node: self.backgroundNode, alpha: alpha)
    }
    
    func updateCaption(_ caption: NSAttributedString) {
        if !caption.string.isEmpty {
            self.loadTextNodeIfNeeded()
        }
        self.updateChatPresentationInterfaceState(animated: false, { $0.updatedInterfaceState { $0.withUpdatedComposeInputState(ChatTextInputState(inputText: caption))} })
    }

    private func updateChatPresentationInterfaceState(animated: Bool = true, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        self.updateChatPresentationInterfaceState(transition: animated ? .animated(duration: 0.4, curve: .spring) : .immediate, f, completion: completion)
    }
    
    private func updateChatPresentationInterfaceState(update: Bool = true, transition: ContainedViewLayoutTransition, _ f: (ChatPresentationInterfaceState) -> ChatPresentationInterfaceState, completion externalCompletion: @escaping (ContainedViewLayoutTransition) -> Void = { _ in }) {
        let presentationInterfaceState = f(self.presentationInterfaceState)
        
        let updateInputTextState = self.presentationInterfaceState.interfaceState.effectiveInputState != presentationInterfaceState.interfaceState.effectiveInputState
        
        self.presentationInterfaceState = presentationInterfaceState
        
        if update {
            if let textInputPanelNode = self.textInputPanelNode, updateInputTextState {
                textInputPanelNode.updateInputTextState(presentationInterfaceState.interfaceState.effectiveInputState, animated: transition.isAnimated)
                
                self.textUpdated(presentationInterfaceState.interfaceState.effectiveInputState.inputText)
            }
        }
    }
    
    func updateSelectedIndex(_ index: Int) {
        self.selectedIndex = index
        self.updateViews(transition: .init(animation: .curve(duration: 0.2, curve: .spring)))
    }
    
    func updateViews(transition: ComponentTransition) {
        guard let layout = self.validLayout else {
            return
        }
        
        let visibleRect = self.scrollNode.bounds.insetBy(dx: -180.0, dy: 0.0)
        
        var distanceBetweenNodes = layout.size.width / CGFloat(self.buttons.count)
        let internalWidth = distanceBetweenNodes * CGFloat(self.buttons.count - 1)
        var leftNodeOriginX = (layout.size.width - internalWidth) / 2.0
        
        var buttonWidth = buttonSize.width
        if self.buttons.count > 6 && layout.size.width < layout.size.height {
            buttonWidth = smallButtonWidth
            distanceBetweenNodes = buttonWidth
            leftNodeOriginX = layout.safeInsets.left + sideInset + buttonWidth / 2.0
        }
        
        var validIds = Set<AnyHashable>()
        
        for i in 0 ..< self.buttons.count {
            let originX = floor(leftNodeOriginX + CGFloat(i) * distanceBetweenNodes - buttonWidth / 2.0)
            let buttonFrame = CGRect(origin: CGPoint(x: originX, y: 0.0), size: CGSize(width: buttonWidth, height: buttonSize.height))
            if !visibleRect.intersects(buttonFrame) {
                continue
            }
            
            let type = self.buttons[i]
            let _ = validIds.insert(type.key)
            
            var buttonTransition = transition
            let buttonView: ComponentHostView<Empty>
            if let current = self.buttonViews[type.key] {
                buttonView = current
            } else {
                buttonTransition = .immediate
                buttonView = ComponentHostView<Empty>()
                self.buttonViews[type.key] = buttonView
                self.scrollNode.view.addSubview(buttonView)
            }
            
            if case let .app(bot) = type {
                for (name, file) in bot.icons {
                    if [.default, .iOSAnimated, .iOSSettingsStatic, .placeholder].contains(name) {
                        if self.iconDisposables[file.fileId] == nil, let peer = PeerReference(bot.peer._asPeer()) {
                            if case .placeholder = name {
                                let account = self.context.account
                                let path = account.postbox.mediaBox.cachedRepresentationCompletePath(file.resource.id, representation: CachedPreparedSvgRepresentation())
                                if !FileManager.default.fileExists(atPath: path) {
                                    let accountFullSizeData = Signal<(Data?, Bool), NoError> { subscriber in
                                        let accountResource = account.postbox.mediaBox.cachedResourceRepresentation(file.resource, representation: CachedPreparedSvgRepresentation(), complete: false, fetch: true)
                                        
                                        let fetchedFullSize = fetchedMediaResource(mediaBox: account.postbox.mediaBox, userLocation: .other, userContentType: MediaResourceUserContentType(file: file), reference: .media(media: .attachBot(peer: peer, media: file), resource: file.resource))
                                        let fetchedFullSizeDisposable = fetchedFullSize.start()
                                        let fullSizeDisposable = accountResource.start()
                                        
                                        return ActionDisposable {
                                            fetchedFullSizeDisposable.dispose()
                                            fullSizeDisposable.dispose()
                                        }
                                    }
                                    self.iconDisposables[file.fileId] = accountFullSizeData.start()
                                }
                            } else {
                                self.iconDisposables[file.fileId] = freeMediaFileInteractiveFetched(account: self.context.account, userLocation: .other, fileReference: .attachBot(peer: peer, media: file)).startStrict()
                            }
                        }
                    }
                }
            }
            let _ = buttonView.update(
                transition: buttonTransition,
                component: AnyComponent(AttachButtonComponent(
                    context: self.context,
                    type: type,
                    isSelected: i == self.selectedIndex,
                    strings: self.presentationData.strings,
                    theme: self.presentationData.theme,
                    action: { [weak self] in
                        if let strongSelf = self {
                            if strongSelf.selectionChanged(type) {
                                strongSelf.selectedIndex = i
                                strongSelf.updateViews(transition: .init(animation: .curve(duration: 0.2, curve: .spring)))
                                
                                if strongSelf.buttons.count > 6, let button = strongSelf.buttonViews[i] {
                                    strongSelf.scrollNode.view.scrollRectToVisible(button.frame.insetBy(dx: -35.0, dy: 0.0), animated: true)
                                }
                            }
                        }
                    }, longPressAction: { [weak self] in
                        if let strongSelf = self, i == strongSelf.selectedIndex {
                            strongSelf.longPressed(type)
                        }
                    })
                ),
                environment: {},
                containerSize: CGSize(width: buttonWidth, height: buttonSize.height)
            )
            buttonTransition.setFrame(view: buttonView, frame: buttonFrame)
            var accessibilityTitle = ""
            switch type {
            case .gallery:
                accessibilityTitle = self.presentationData.strings.Attachment_Gallery
            case .file:
                accessibilityTitle = self.presentationData.strings.Attachment_File
            case .location:
                accessibilityTitle = self.presentationData.strings.Attachment_Location
            case .todo:
                accessibilityTitle = self.presentationData.strings.Attachment_Todo
            case .contact:
                accessibilityTitle = self.presentationData.strings.Attachment_Contact
            case .poll:
                accessibilityTitle = self.presentationData.strings.Attachment_Poll
            case .gift:
                accessibilityTitle = self.presentationData.strings.Attachment_Gift
            case let .app(bot):
                accessibilityTitle = bot.shortName
            case .standalone:
                accessibilityTitle = ""
            case .quickReply:
                accessibilityTitle = self.presentationData.strings.Attachment_Reply
            }
            buttonView.isAccessibilityElement = true
            buttonView.accessibilityLabel = accessibilityTitle
            buttonView.accessibilityTraits = [.button]
        }
        var removeIds: [AnyHashable] = []
        for (id, itemView) in self.buttonViews {
            if !validIds.contains(id) {
                removeIds.append(id)
                itemView.removeFromSuperview()
            }
        }
        for id in removeIds {
            self.buttonViews.removeValue(forKey: id)
        }
    }
    
    private func updateScrollLayoutIfNeeded(force: Bool, transition: ContainedViewLayoutTransition) -> Bool {
        guard let layout = self.validLayout else {
            return false
        }
        if self.scrollLayout?.width == layout.size.width && !force {
            return false
        }
        
        var contentSize = CGSize(width: layout.size.width, height: buttonSize.height)
        var buttonWidth = buttonSize.width
        if self.buttons.count > 6 && layout.size.width < layout.size.height {
            buttonWidth = smallButtonWidth
            contentSize.width = layout.safeInsets.left + layout.safeInsets.right + sideInset * 2.0 + CGFloat(self.buttons.count) * buttonWidth
        }
        self.scrollLayout = (layout.size.width, contentSize)

        transition.updateFrameAsPositionAndBounds(node: self.scrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: self.isSelecting || self._isButtonVisible ? -buttonSize.height : 0.0), size: CGSize(width: layout.size.width, height: buttonSize.height)))
        self.scrollNode.view.contentSize = contentSize

        return true
    }
    
    private func loadTextNodeIfNeeded() {
        if let _ = self.textInputPanelNode {
        } else {
            let textInputPanelNode = AttachmentTextInputPanelNode(context: self.context, presentationInterfaceState: self.presentationInterfaceState, isAttachment: true, isScheduledMessages: self.isScheduledMessages, presentController: { [weak self] c in
                if let strongSelf = self {
                    strongSelf.present(c)
                }
            }, makeEntityInputView: self.makeEntityInputView)
            textInputPanelNode.interfaceInteraction = self.interfaceInteraction
            textInputPanelNode.sendMessage = { [weak self] mode, messageEffect in
                if let strongSelf = self {
                    strongSelf.sendMessagePressed(mode, messageEffect)
                }
            }
            textInputPanelNode.focusUpdated = { [weak self] focus in
                if let strongSelf = self, focus {
                    strongSelf.beganTextEditing()
                }
            }
            textInputPanelNode.updateHeight = { [weak self] _ in
                if let strongSelf = self {
                    strongSelf.requestLayout()
                }
            }
            self.addSubnode(textInputPanelNode)
            self.textInputPanelNode = textInputPanelNode
            
            textInputPanelNode.alpha = self.isSelecting ? 1.0 : 0.0
            textInputPanelNode.isUserInteractionEnabled = self.isSelecting
        }
    }
    
    func updateLoadingProgress(_ progress: CGFloat?) {
        self.loadingProgress = progress
    }
    
    func updateMainButtonState(_ mainButtonState: AttachmentMainButtonState?) {
        var currentButtonState = self.mainButtonState
        if mainButtonState == nil {
            currentButtonState = AttachmentMainButtonState(text: currentButtonState.text, font: currentButtonState.font, background: currentButtonState.background, textColor: currentButtonState.textColor, isVisible: false, progress: .none, isEnabled: currentButtonState.isEnabled, hasShimmer: currentButtonState.hasShimmer)
        }
        self.mainButtonState = mainButtonState ?? currentButtonState
    }
    
    func updateSecondaryButtonState(_ secondaryButtonState: AttachmentMainButtonState?) {
        var currentButtonState = self.secondaryButtonState
        if secondaryButtonState == nil {
            currentButtonState = AttachmentMainButtonState(text: currentButtonState.text, font: currentButtonState.font, background: currentButtonState.background, textColor: currentButtonState.textColor, isVisible: false, progress: .none, isEnabled: currentButtonState.isEnabled, hasShimmer: currentButtonState.hasShimmer)
        }
        self.secondaryButtonState = secondaryButtonState ?? currentButtonState
    }
    
    func updateCustomBottomPanelBackgroundColor(_ color: UIColor?) {
        self.customBottomPanelBackgroundColor = color
        self.backgroundNode.updateColor(color: self.customBottomPanelBackgroundColor ?? presentationData.theme.rootController.tabBar.backgroundColor, transition: .animated(duration: 0.2, curve: .linear))
    }
    
    let animatingTransitionPromise = ValuePromise<Bool>(false)
    private(set) var animatingTransition = false {
        didSet {
            self.animatingTransitionPromise.set(self.animatingTransition)
        }
    }
    
    func animateTransitionIn(inputTransition: AttachmentController.InputPanelTransition, transition: ContainedViewLayoutTransition) {
        guard !self.animatingTransition, let inputNodeSnapshotView = inputTransition.inputNode.view.snapshotView(afterScreenUpdates: false) else {
            return
        }
        guard let menuIconSnapshotView = inputTransition.menuIconNode.view.snapshotView(afterScreenUpdates: false), let menuTextSnapshotView = inputTransition.menuTextNode.view.snapshotView(afterScreenUpdates: false) else {
            return
        }
        self.animatingTransition = true
        
        let targetButtonColor = self.mainButtonNode.backgroundColor
        self.mainButtonNode.backgroundColor = inputTransition.menuButtonBackgroundNode.backgroundColor
        transition.updateBackgroundColor(node: self.mainButtonNode, color: targetButtonColor ?? .clear)
        
        transition.animateFrame(layer: self.mainButtonNode.layer, from: inputTransition.menuButtonNode.frame)
        transition.animatePosition(node: self.mainButtonNode.textNode, from: CGPoint(x: inputTransition.menuButtonNode.frame.width / 2.0, y: inputTransition.menuButtonNode.frame.height / 2.0))
        
        let targetButtonCornerRadius = self.mainButtonNode.cornerRadius
        self.mainButtonNode.cornerRadius = inputTransition.menuButtonNode.cornerRadius
        transition.updateCornerRadius(node: self.mainButtonNode, cornerRadius: targetButtonCornerRadius)
        self.mainButtonNode.subnodeTransform = CATransform3DMakeScale(0.2, 0.2, 1.0)
        transition.updateSublayerTransformScale(node: self.mainButtonNode, scale: 1.0)
        self.mainButtonNode.textNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        
        let menuContentDelta = (self.mainButtonNode.frame.width - inputTransition.menuButtonNode.frame.width) / 2.0
        menuIconSnapshotView.frame = inputTransition.menuIconNode.frame.offsetBy(dx: inputTransition.menuButtonNode.frame.minX, dy: inputTransition.menuButtonNode.frame.minY)
        self.view.addSubview(menuIconSnapshotView)
        menuIconSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak menuIconSnapshotView] _ in
            menuIconSnapshotView?.removeFromSuperview()
        })
        transition.updatePosition(layer: menuIconSnapshotView.layer, position: CGPoint(x: menuIconSnapshotView.center.x + menuContentDelta, y: self.mainButtonNode.position.y))
        
        menuTextSnapshotView.frame = inputTransition.menuTextNode.frame.offsetBy(dx: inputTransition.menuButtonNode.frame.minX + 19.0, dy: inputTransition.menuButtonNode.frame.minY)
        self.view.addSubview(menuTextSnapshotView)
        menuTextSnapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak menuTextSnapshotView] _ in
            menuTextSnapshotView?.removeFromSuperview()
        })
        transition.updatePosition(layer: menuTextSnapshotView.layer, position: CGPoint(x: menuTextSnapshotView.center.x + menuContentDelta, y: self.mainButtonNode.position.y))
        
        inputNodeSnapshotView.clipsToBounds = true
        inputNodeSnapshotView.contentMode = .right
        inputNodeSnapshotView.frame = CGRect(x: inputTransition.menuButtonNode.frame.maxX, y: 0.0, width: inputNodeSnapshotView.frame.width - inputTransition.menuButtonNode.frame.maxX, height: inputNodeSnapshotView.frame.height)
        self.view.addSubview(inputNodeSnapshotView)
        
        let targetInputPosition = CGPoint(x: inputNodeSnapshotView.center.x + inputNodeSnapshotView.frame.width, y: self.mainButtonNode.position.y)
        transition.updatePosition(layer: inputNodeSnapshotView.layer, position: targetInputPosition, completion: { [weak inputNodeSnapshotView, weak self] _ in
            inputNodeSnapshotView?.removeFromSuperview()
            self?.animatingTransition = false
        })
    }
    
    private var dismissed = false
    func animateTransitionOut(inputTransition: AttachmentController.InputPanelTransition, dismissed: Bool, transition: ContainedViewLayoutTransition) {
        guard !self.animatingTransition, let inputNodeSnapshotView = inputTransition.inputNode.view.snapshotView(afterScreenUpdates: false) else {
            return
        }
        if dismissed {
            inputTransition.prepareForDismiss()
        }
      
        self.animatingTransition = true
        self.dismissed = dismissed
        
        let action = {
            guard let menuIconSnapshotView = inputTransition.menuIconNode.view.snapshotView(afterScreenUpdates: false), let menuTextSnapshotView = inputTransition.menuTextNode.view.snapshotView(afterScreenUpdates: false) else {
                return
            }
            
            let sourceButtonColor = self.mainButtonNode.backgroundColor
            transition.updateBackgroundColor(node: self.mainButtonNode, color: inputTransition.menuButtonBackgroundNode.backgroundColor ?? .clear)
            
            let sourceButtonFrame = self.mainButtonNode.frame
            transition.updateFrame(node: self.mainButtonNode, frame: inputTransition.menuButtonNode.frame)
            let sourceButtonTextPosition = self.mainButtonNode.textNode.position
            transition.updatePosition(node: self.mainButtonNode.textNode, position: CGPoint(x: inputTransition.menuButtonNode.frame.width / 2.0, y: inputTransition.menuButtonNode.frame.height / 2.0))
            
            let sourceButtonCornerRadius = self.mainButtonNode.cornerRadius
            transition.updateCornerRadius(node: self.mainButtonNode, cornerRadius: inputTransition.menuButtonNode.cornerRadius)
            transition.updateSublayerTransformScale(node: self.mainButtonNode, scale: 0.2)
            self.mainButtonNode.textNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
            
            let menuContentDelta = (sourceButtonFrame.width - inputTransition.menuButtonNode.frame.width) / 2.0
            var menuIconSnapshotViewFrame = inputTransition.menuIconNode.frame.offsetBy(dx: inputTransition.menuButtonNode.frame.minX + menuContentDelta, dy: inputTransition.menuButtonNode.frame.minY)
            menuIconSnapshotViewFrame.origin.y = self.mainButtonNode.position.y - menuIconSnapshotViewFrame.height / 2.0
            menuIconSnapshotView.frame = menuIconSnapshotViewFrame
            self.view.addSubview(menuIconSnapshotView)
            menuIconSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            transition.updatePosition(layer: menuIconSnapshotView.layer, position: CGPoint(x: menuIconSnapshotView.center.x - menuContentDelta, y: inputTransition.menuButtonNode.position.y))
            
            var menuTextSnapshotViewFrame = inputTransition.menuTextNode.frame.offsetBy(dx: inputTransition.menuButtonNode.frame.minX + 19.0 + menuContentDelta, dy: inputTransition.menuButtonNode.frame.minY)
            menuTextSnapshotViewFrame.origin.y = self.mainButtonNode.position.y - menuTextSnapshotViewFrame.height / 2.0
            menuTextSnapshotView.frame = menuTextSnapshotViewFrame
            self.view.addSubview(menuTextSnapshotView)
            menuTextSnapshotView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
            transition.updatePosition(layer: menuTextSnapshotView.layer, position: CGPoint(x: menuTextSnapshotView.center.x - menuContentDelta, y: inputTransition.menuButtonNode.position.y))
            
            inputNodeSnapshotView.clipsToBounds = true
            inputNodeSnapshotView.contentMode = .right
            let targetInputFrame = CGRect(x: inputTransition.menuButtonNode.frame.maxX, y: 0.0, width: inputNodeSnapshotView.frame.width - inputTransition.menuButtonNode.frame.maxX, height: inputNodeSnapshotView.frame.height)
            inputNodeSnapshotView.frame = targetInputFrame.offsetBy(dx: targetInputFrame.width, dy: self.mainButtonNode.position.y - inputNodeSnapshotView.frame.height / 2.0)
            self.view.addSubview(inputNodeSnapshotView)
            transition.updateFrame(layer: inputNodeSnapshotView.layer, frame: targetInputFrame, completion: { [weak inputNodeSnapshotView, weak menuIconSnapshotView, weak menuTextSnapshotView, weak self] _ in
                inputNodeSnapshotView?.removeFromSuperview()
                self?.animatingTransition = false
                
                if !dismissed {
                    menuIconSnapshotView?.removeFromSuperview()
                    menuTextSnapshotView?.removeFromSuperview()
                    
                    self?.mainButtonNode.backgroundColor = sourceButtonColor
                    self?.mainButtonNode.frame = sourceButtonFrame
                    self?.mainButtonNode.textNode.position = sourceButtonTextPosition
                    self?.mainButtonNode.textNode.layer.removeAllAnimations()
                    self?.mainButtonNode.cornerRadius = sourceButtonCornerRadius
                }
            })
        }
        
        if dismissed {
            Queue.mainQueue().after(0.01, action)
        } else {
            action()
        }
    }
    
    func update(layout: ContainerViewLayout, buttons: [AttachmentButtonType], isSelecting: Bool, selectionCount: Int, elevateProgress: Bool, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.validLayout = layout
        self.buttons = buttons
        self.elevateProgress = elevateProgress
        
        if selectionCount != self.selectionCount {
            self.selectionCount = selectionCount
            self.updateChatPresentationInterfaceState(update: false, transition: .immediate, { state in
                var selectedMessages: [EngineMessage.Id] = []
                for i in 0 ..< selectionCount {
                    selectedMessages.append(EngineMessage.Id(peerId: PeerId(0), namespace: Namespaces.Message.Local, id: Int32(i)))
                }
                return state.updatedInterfaceState { state in
                    return state.withUpdatedForwardMessageIds(selectedMessages)
                }
            })
        }
                
        let isButtonVisibleUpdated = self._isButtonVisible != self.mainButtonState.isVisible
        self._isButtonVisible = self.mainButtonState.isVisible
        
        let isSelectingUpdated = self.isSelecting != isSelecting
        self.isSelecting = isSelecting
        
        self.scrollNode.isUserInteractionEnabled = !isSelecting
        
        let isAnyButtonVisible = self.mainButtonState.isVisible || self.secondaryButtonState.isVisible
        let isNarrowButton = isAnyButtonVisible && self.mainButtonState.font == .regular
        
        let isTwoVerticalButtons = self.mainButtonState.isVisible && self.secondaryButtonState.isVisible && [.top, .bottom].contains(self.secondaryButtonState.position)
        let isTwoHorizontalButtons = self.mainButtonState.isVisible && self.secondaryButtonState.isVisible && [.left, .right].contains(self.secondaryButtonState.position)
        
        var insets = layout.insets(options: [])
        if let inputHeight = layout.inputHeight, inputHeight > 0.0 && (isSelecting || isAnyButtonVisible) {
            insets.bottom = inputHeight
        } else if layout.intrinsicInsets.bottom > 0.0 {
            insets.bottom = layout.intrinsicInsets.bottom
        }
        
        if isSelecting {
            self.loadTextNodeIfNeeded()
        } else {
            self.textInputPanelNode?.ensureUnfocused()
        }
        var textPanelHeight: CGFloat = 0.0
        if let textInputPanelNode = self.textInputPanelNode {
            textInputPanelNode.isUserInteractionEnabled = isSelecting
            
            var panelTransition = transition
            if textInputPanelNode.frame.width.isZero {
                panelTransition = .immediate
            }
            let panelHeight = textInputPanelNode.updateLayout(width: layout.size.width, leftInset: insets.left + layout.safeInsets.left, rightInset: insets.right + layout.safeInsets.right, bottomInset: 0.0, additionalSideInsets: UIEdgeInsets(), maxHeight: layout.size.height / 2.0, isSecondary: false, transition: panelTransition, interfaceState: self.presentationInterfaceState, metrics: layout.metrics, isMediaInputExpanded: false)
            let panelFrame = CGRect(x: 0.0, y: 0.0, width: layout.size.width, height: panelHeight)
            if textInputPanelNode.frame.width.isZero {
                textInputPanelNode.frame = panelFrame
            }
            transition.updateFrame(node: textInputPanelNode, frame: panelFrame)
            if panelFrame.height > 0.0 {
                textPanelHeight = panelFrame.height
            } else {
                textPanelHeight = 45.0
            }
        }
        
        let bounds = CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: buttonSize.height + insets.bottom))
        var containerTransition: ContainedViewLayoutTransition
        let containerFrame: CGRect
        
        let sideInset: CGFloat = 16.0
        let buttonHeight: CGFloat = 50.0
        
        if isAnyButtonVisible {
            var height: CGFloat
            if layout.intrinsicInsets.bottom > 0.0 && (layout.inputHeight ?? 0.0).isZero {
                height = bounds.height
                if case .regular = layout.metrics.widthClass {
                    if self.isStandalone {
                        height -= 3.0
                    } else {
                        height += 6.0
                    }
                }
            } else {
                height = bounds.height + 8.0
            }
            if isTwoVerticalButtons && self.secondaryButtonState.smallSpacing {
                
            } else if !isNarrowButton {
                height += 9.0
            }
            if isTwoVerticalButtons {
                height += buttonHeight + sideInset
            }
            containerFrame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: height))
        } else if isSelecting {
            containerFrame = CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: textPanelHeight + insets.bottom))
        } else {
            containerFrame = bounds
        }
        let containerBounds = CGRect(origin: CGPoint(), size: containerFrame.size)
        if isSelectingUpdated || isButtonVisibleUpdated {
            containerTransition = .animated(duration: 0.25, curve: .easeInOut)
        } else {
            containerTransition = transition
        }
        containerTransition.updateAlpha(node: self.scrollNode, alpha: isSelecting || isAnyButtonVisible ? 0.0 : 1.0)
        containerTransition.updateTransformScale(node: self.scrollNode, scale: isSelecting || isAnyButtonVisible ? 0.85 : 1.0)
        
        if isSelectingUpdated {
            if isSelecting {
                self.loadTextNodeIfNeeded()
                if let textInputPanelNode = self.textInputPanelNode {
                    textInputPanelNode.alpha = 1.0
                    textInputPanelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    textInputPanelNode.layer.animatePosition(from: CGPoint(x: 0.0, y: 44.0), to: CGPoint(), duration: 0.25, additive: true)
                }
            } else {
                if let textInputPanelNode = self.textInputPanelNode {
                    textInputPanelNode.alpha = 0.0
                    textInputPanelNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25)
                    textInputPanelNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: 44.0), duration: 0.25, additive: true)
                }
            }
        }
        
        if self.containerNode.frame.size.width.isZero {
            containerTransition = .immediate
        }
        
        containerTransition.updateFrame(node: self.containerNode, frame: containerFrame)
        containerTransition.updateFrame(node: self.backgroundNode, frame: containerBounds)
        self.backgroundNode.update(size: containerBounds.size, transition: transition)
        containerTransition.updateFrame(node: self.separatorNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: bounds.width, height: UIScreenPixel)))
                
        let _ = self.updateScrollLayoutIfNeeded(force: isSelectingUpdated || isButtonVisibleUpdated, transition: containerTransition)

        self.updateViews(transition: .immediate)
        
        if let progress = self.loadingProgress {
            let loadingProgressNode: LoadingProgressNode
            if let current = self.progressNode {
                loadingProgressNode = current
            } else {
                loadingProgressNode = LoadingProgressNode(color: self.presentationData.theme.rootController.tabBar.selectedIconColor)
                self.addSubnode(loadingProgressNode)
                self.progressNode = loadingProgressNode
            }
            let loadingProgressHeight: CGFloat = 2.0
            let loadingProgressY: CGFloat = elevateProgress ? -loadingProgressHeight : -loadingProgressHeight / 2.0
            transition.updateFrame(node: loadingProgressNode, frame: CGRect(origin: CGPoint(x: 0.0, y: loadingProgressY), size: CGSize(width: layout.size.width, height: loadingProgressHeight)))
            
            loadingProgressNode.updateProgress(progress, animated: true)
        } else if let progressNode = self.progressNode {
            self.progressNode = nil
            progressNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak progressNode] _ in
                progressNode?.removeFromSupernode()
            })
        }
        
        var buttonSize = CGSize(width: layout.size.width - (sideInset + layout.safeInsets.left) * 2.0, height: buttonHeight)
        if isTwoHorizontalButtons {
            buttonSize = CGSize(width: (buttonSize.width - sideInset) / 2.0, height: buttonSize.height)
        }
        let buttonTopInset: CGFloat = isNarrowButton ? 2.0 : 8.0
                
        if !self.animatingTransition {
            let buttonOriginX = layout.safeInsets.left + sideInset
            let buttonOriginY = isAnyButtonVisible || self.fromMenu ? buttonTopInset : containerFrame.height
            var mainButtonFrame: CGRect?
            var secondaryButtonFrame: CGRect?
            if self.secondaryButtonState.isVisible && self.mainButtonState.isVisible, let position = self.secondaryButtonState.position {
                switch position {
                case .top:
                    secondaryButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX, y: buttonOriginY), size: buttonSize)
                    mainButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX, y: buttonOriginY + sideInset + buttonSize.height), size: buttonSize)
                case .bottom:
                    mainButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX, y: buttonOriginY), size: buttonSize)
                    let buttonSpacing = self.secondaryButtonState.smallSpacing ? 8.0 : sideInset
                    secondaryButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX, y: buttonOriginY + buttonSpacing + buttonSize.height), size: buttonSize)
                case .left:
                    secondaryButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX, y: buttonOriginY), size: buttonSize)
                    mainButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX + buttonSize.width + sideInset, y: buttonOriginY), size: buttonSize)
                case .right:
                    mainButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX, y: buttonOriginY), size: buttonSize)
                    secondaryButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX + buttonSize.width + sideInset, y: buttonOriginY), size: buttonSize)
                }
            } else {
                if self.mainButtonState.isVisible {
                    mainButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX, y: buttonOriginY), size: buttonSize)
                }
                if self.secondaryButtonState.isVisible {
                    secondaryButtonFrame = CGRect(origin: CGPoint(x: buttonOriginX, y: buttonOriginY), size: buttonSize)
                }
            }
            
            if let mainButtonFrame {
                if !self.dismissed {
                    self.mainButtonNode.updateLayout(size: buttonSize, state: self.mainButtonState, animateBackground: self.mainButtonState.background.colorValue == self.backgroundNode.color && transition.isAnimated, transition: transition)
                }
                if self.mainButtonNode.frame.width.isZero {
                    self.mainButtonNode.frame = mainButtonFrame
                } else {
                    transition.updateFrame(node: self.mainButtonNode, frame: mainButtonFrame)
                }
                transition.updateAlpha(node: self.mainButtonNode, alpha: 1.0)
            } else {
                transition.updateAlpha(node: self.mainButtonNode, alpha: 0.0)
            }
            if let secondaryButtonFrame {
                if !self.dismissed {
                    self.secondaryButtonNode.updateLayout(size: buttonSize, state: self.secondaryButtonState, animateBackground: self.secondaryButtonState.background.colorValue == self.backgroundNode.color && transition.isAnimated, transition: transition)
                }
                if self.secondaryButtonNode.frame.width.isZero {
                    self.secondaryButtonNode.frame = secondaryButtonFrame
                } else {
                    transition.updateFrame(node: self.secondaryButtonNode, frame: secondaryButtonFrame)
                }
                transition.updateAlpha(node: self.secondaryButtonNode, alpha: 1.0)
            } else {
                transition.updateAlpha(node: self.secondaryButtonNode, alpha: 0.0)
            }
        }
        
        return containerFrame.height
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.updateViews(transition: .immediate)
    }
}

