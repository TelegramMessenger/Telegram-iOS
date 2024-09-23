import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramCore
import TelegramPresentationData
import AppBundle
import AccountContext
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import EmojiTextAttachmentView
import TextFormat
import ItemShimmeringLoadingComponent
import AvatarNode

public final class GiftItemComponent: Component {
    public enum Subject: Equatable {
        case premium(Int32)
        case starGift(Int64, TelegramMediaFile)
    }
    
    public struct Ribbon: Equatable {
        public enum Color {
            case red
            case blue
            
            var colors: [UIColor] {
                switch self {
                case .red:
                    return [
                        UIColor(rgb: 0xed1c26),
                        UIColor(rgb: 0xff5c55)
                        
                    ]
                case .blue:
                    return [
                        UIColor(rgb: 0x34a4fc),
                        UIColor(rgb: 0x6fd3ff)
                    ]
                }
            }
        }
        public let text: String
        public let color: Color
        
        public init(text: String, color: Color) {
            self.text = text
            self.color = color
        }
    }
    
    public enum Peer: Equatable {
        case peer(EnginePeer)
        case anonymous
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let peer: GiftItemComponent.Peer?
    let subject: GiftItemComponent.Subject
    let title: String?
    let subtitle: String?
    let price: String
    let ribbon: Ribbon?
    let isLoading: Bool
    let isHidden: Bool
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        peer: GiftItemComponent.Peer?,
        subject: GiftItemComponent.Subject,
        title: String? = nil,
        subtitle: String? = nil,
        price: String,
        ribbon: Ribbon? = nil,
        isLoading: Bool = false,
        isHidden: Bool = false
    ) {
        self.context = context
        self.theme = theme
        self.peer = peer
        self.subject = subject
        self.title = title
        self.subtitle = subtitle
        self.price = price
        self.ribbon = ribbon
        self.isLoading = isLoading
        self.isHidden = isHidden
    }

    public static func ==(lhs: GiftItemComponent, rhs: GiftItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.price != rhs.price {
            return false
        }
        if lhs.ribbon != rhs.ribbon {
            return false
        }
        if lhs.isLoading != rhs.isLoading {
            return false
        }
        if lhs.isHidden != rhs.isHidden {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: GiftItemComponent?
        private weak var componentState: EmptyComponentState?
        
        private let backgroundLayer = SimpleLayer()
        private var loadingBackground: ComponentView<Empty>?
        
        private var avatarNode: AvatarNode?
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        private let ribbon = UIImageView()
        private let ribbonText = ComponentView<Empty>()
        
        private var animationLayer: InlineStickerItemLayer?
        
        private var hiddenIconBackground: UIVisualEffectView?
        private var hiddenIcon: UIImageView?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            
            self.backgroundLayer.cornerRadius = 10.0
            if #available(iOS 13.0, *) {
                self.backgroundLayer.cornerCurve = .circular
            }
            self.backgroundLayer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: GiftItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            
            self.component = component
            self.componentState = state
            
            let size = CGSize(width: availableSize.width, height: component.title != nil ? 178.0 : 154.0)
            
            if component.isLoading {
                let loadingBackground: ComponentView<Empty>
                if let current = self.loadingBackground {
                    loadingBackground = current
                } else {
                    loadingBackground = ComponentView<Empty>()
                    self.loadingBackground = loadingBackground
                }
                
                let _ = loadingBackground.update(
                    transition: transition,
                    component: AnyComponent(
                        ItemShimmeringLoadingComponent(color: component.theme.list.itemAccentColor, cornerRadius: 10.0)
                    ),
                    environment: {},
                    containerSize: size
                )
                if let loadingBackgroundView = loadingBackground.view {
                    if loadingBackgroundView.layer.superlayer == nil {
                        self.layer.insertSublayer(loadingBackgroundView.layer, above: self.backgroundLayer)
                    }
                    loadingBackgroundView.frame = CGRect(origin: .zero, size: size)
                }
            } else if let loadingBackground = self.loadingBackground {
                loadingBackground.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    loadingBackground.view?.layer.removeFromSuperlayer()
                })
                self.loadingBackground = nil
            }
                
            let emoji: ChatTextInputTextCustomEmojiAttribute?
            var file: TelegramMediaFile?
            var animationOffset: CGFloat = 0.0
            switch component.subject {
            case let .premium(months):
                emoji = ChatTextInputTextCustomEmojiAttribute(
                    interactivelySelectedFromPackId: nil,
                    fileId: 0,
                    file: nil,
                    custom: .animation(name: "Gift\(months)")
                )
            case let .starGift(_, fileValue):
                file = fileValue
                emoji = ChatTextInputTextCustomEmojiAttribute(
                    interactivelySelectedFromPackId: nil,
                    fileId: fileValue.fileId.id,
                    file: fileValue
                )
                animationOffset = 16.0
            }
            
            let iconSize = CGSize(width: 88.0, height: 88.0)
            if self.animationLayer == nil, let emoji {
                let animationLayer = InlineStickerItemLayer(
                    context: .account(component.context),
                    userLocation: .other,
                    attemptSynchronousLoad: false,
                    emoji: emoji,
                    file: file,
                    cache: component.context.animationCache,
                    renderer: component.context.animationRenderer,
                    unique: false,
                    placeholderColor: component.theme.list.mediaPlaceholderColor,
                    pointSize: CGSize(width: iconSize.width * 2.0, height: iconSize.height * 2.0),
                    loopCount: 1
                )
                animationLayer.isVisibleForAnimations = true
                self.animationLayer = animationLayer
                self.layer.addSublayer(animationLayer)
            }
            
            let animationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - iconSize.width) / 2.0), y: animationOffset), size: iconSize)
            if let animationLayer = self.animationLayer {
                transition.setFrame(layer: animationLayer, frame: animationFrame)
            }
            
            if let title = component.title {
                let titleSize = self.title.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: title, font: Font.semibold(15.0), textColor: component.theme.list.itemPrimaryTextColor)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: 94.0), size: titleSize)
                if let titleView = self.title.view {
                    if titleView.superview == nil {
                        self.addSubview(titleView)
                    }
                    transition.setFrame(view: titleView, frame: titleFrame)
                }
            }
            
            if let subtitle = component.subtitle {
                let subtitleSize = self.subtitle.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: subtitle, font: Font.regular(13.0), textColor: component.theme.list.itemPrimaryTextColor)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                let subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - subtitleSize.width) / 2.0), y: 112.0), size: subtitleSize)
                if let subtitleView = self.subtitle.view {
                    if subtitleView.superview == nil {
                        self.addSubview(subtitleView)
                    }
                    transition.setFrame(view: subtitleView, frame: subtitleFrame)
                }
            }
            
            let buttonSize = self.button.update(
                transition: transition,
                component: AnyComponent(
                    ButtonContentComponent(
                        context: component.context,
                        text: component.price, 
                        color: component.price.containsEmoji ? UIColor(rgb: 0xd3720a) : component.theme.list.itemAccentColor,
                        isStars: component.price.containsEmoji)
                ),
                environment: {},
                containerSize: availableSize
            )
            let buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - buttonSize.width) / 2.0), y: size.height - buttonSize.height - 10.0), size: buttonSize)
            if let buttonView = self.button.view {
                if buttonView.superview == nil {
                    self.addSubview(buttonView)
                }
                transition.setFrame(view: buttonView, frame: buttonFrame)
            }
            
            if let ribbon = component.ribbon {
                let ribbonTextSize = self.ribbonText.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: ribbon.text, font: Font.semibold(11.0), textColor: .white)),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                if let ribbonTextView = self.ribbonText.view {
                    if ribbonTextView.superview == nil {
                        self.addSubview(self.ribbon)
                        self.addSubview(ribbonTextView)
                    }
                    ribbonTextView.bounds = CGRect(origin: .zero, size: ribbonTextSize)
                    
                    if self.ribbon.image == nil {
                        self.ribbon.image = generateGradientTintedImage(image: UIImage(bundleImageName: "Premium/GiftRibbon"), colors: ribbon.color.colors, direction: .diagonal)
                    }
                    if let ribbonImage = self.ribbon.image {
                        self.ribbon.frame = CGRect(origin: CGPoint(x: size.width - ribbonImage.size.width + 2.0, y: -2.0), size: ribbonImage.size)
                    }
                    ribbonTextView.transform = CGAffineTransform(rotationAngle: .pi / 4.0)
                    ribbonTextView.center = CGPoint(x: size.width - 20.0, y: 20.0)
                }
            } else {
                if self.ribbonText.view?.superview != nil {
                    self.ribbon.removeFromSuperview()
                    self.ribbonText.view?.removeFromSuperview()
                }
            }
            
            if let peer = component.peer {
                let avatarNode: AvatarNode
                if let current = self.avatarNode {
                    avatarNode = current
                } else {
                    avatarNode = AvatarNode(font: avatarPlaceholderFont(size: 8.0))
                    self.addSubview(avatarNode.view)
                    self.avatarNode = avatarNode
                }
                
                switch peer {
                case let .peer(peer):
                    avatarNode.setPeer(context: component.context, theme: component.theme, peer: peer, displayDimensions: CGSize(width: 20.0, height: 20.0))
                case .anonymous:
                    avatarNode.setPeer(context: component.context, theme: component.theme, peer: nil, overrideImage: .anonymousSavedMessagesIcon(isColored: true))
                }
                
                avatarNode.frame = CGRect(origin: CGPoint(x: 2.0, y: 2.0), size: CGSize(width: 20.0, height: 20.0))
            }
            
            self.backgroundLayer.backgroundColor = component.theme.list.itemBlocksBackgroundColor.cgColor
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))
            
            if component.isHidden {
                let hiddenIconBackground: UIVisualEffectView
                let hiddenIcon: UIImageView
                if let currentBackground = self.hiddenIconBackground, let currentIcon = self.hiddenIcon {
                    hiddenIconBackground = currentBackground
                    hiddenIcon = currentIcon
                } else {
                    let blurEffect: UIBlurEffect
                    if #available(iOS 13.0, *) {
                        blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
                    } else {
                        blurEffect = UIBlurEffect(style: .dark)
                    }
                    hiddenIconBackground = UIVisualEffectView(effect: blurEffect)
                    hiddenIconBackground.clipsToBounds = true
                    hiddenIconBackground.layer.cornerRadius = 15.0
                    self.hiddenIconBackground = hiddenIconBackground
                    
                    hiddenIcon = UIImageView(image: generateTintedImage(image: UIImage(bundleImageName: "Peer Info/HiddenIcon"), color: .white))
                    self.hiddenIcon = hiddenIcon
                    
                    self.addSubview(hiddenIconBackground)
                    hiddenIconBackground.contentView.addSubview(hiddenIcon)
                    
                    if !isFirstTime {
                        hiddenIconBackground.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        hiddenIconBackground.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                
                let iconSize = CGSize(width: 30.0, height: 30.0)
                hiddenIconBackground.frame = iconSize.centered(around: animationFrame.center)
                hiddenIcon.frame = CGRect(origin: .zero, size: iconSize)
            } else {
                if let hiddenIconBackground = self.hiddenIconBackground {
                    self.hiddenIconBackground = nil
                    self.hiddenIcon = nil
                    
                    hiddenIconBackground.layer.animateAlpha(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        hiddenIconBackground.removeFromSuperview()
                    })
                    hiddenIconBackground.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
                }
            }
            
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ButtonContentComponent: Component {
    let context: AccountContext
    let text: String
    let color: UIColor
    let isStars: Bool
    
    public init(
        context: AccountContext,
        text: String,
        color: UIColor,
        isStars: Bool = false
    ) {
        self.context = context
        self.text = text
        self.color = color
        self.isStars = isStars
    }

    public static func ==(lhs: ButtonContentComponent, rhs: ButtonContentComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.color != rhs.color {
            return false
        }
        if lhs.isStars != rhs.isStars {
            return false
        }
        return true
    }

    public final class View: UIView {
        private var component: ButtonContentComponent?
        private weak var componentState: EmptyComponentState?
        
        private let backgroundLayer = SimpleLayer()
        private let title = ComponentView<Empty>()
        
        private var starsLayer: StarsButtonEffectLayer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            self.backgroundLayer.masksToBounds = true
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ButtonContentComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.componentState = state
                        
            let attributedText = NSMutableAttributedString(string: component.text, font: Font.semibold(11.0), textColor: component.color)
            let range = (attributedText.string as NSString).range(of: "⭐️")
            if range.location != NSNotFound {
                attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                attributedText.addAttribute(.font, value: Font.semibold(15.0), range: range)
                attributedText.addAttribute(.baselineOffset, value: 2.0, range: NSRange(location: range.upperBound, length: attributedText.length - range.upperBound))
            }
        
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        placeholderColor: .white,
                        text: .plain(attributedText)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            let padding: CGFloat = 9.0
            let size = CGSize(width: titleSize.width + padding * 2.0, height: 30.0)
            
            if component.isStars {
                let starsLayer: StarsButtonEffectLayer
                if let current = self.starsLayer {
                    starsLayer = current
                } else {
                    starsLayer = StarsButtonEffectLayer()
                    self.layer.addSublayer(starsLayer)
                    self.starsLayer = starsLayer
                }
                starsLayer.frame = CGRect(origin: .zero, size: size)
                starsLayer.update(size: size)
            } else {
                self.starsLayer?.removeFromSuperlayer()
                self.starsLayer = nil
            }
            
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            let backgroundColor: UIColor
            if component.color.rgb == 0xd3720a {
                backgroundColor = UIColor(rgb: 0xffc83d, alpha: 0.2)
            } else {
                backgroundColor = component.color.withAlphaComponent(0.1)
            }
            
            self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))
            self.backgroundLayer.cornerRadius = size.height / 2.0
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class StarsButtonEffectLayer: SimpleLayer {
    let emitterLayer = CAEmitterLayer()
    
    override init() {
        super.init()
        
        self.addSublayer(self.emitterLayer)
    }
    
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setup() {
        let color = UIColor(rgb: 0xffbe27)
        
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 25.0
        emitter.lifetime = 2.0
        emitter.velocity = 12.0
        emitter.velocityRange = 3
        emitter.scale = 0.1
        emitter.scaleRange = 0.08
        emitter.alphaRange = 0.1
        emitter.emissionRange = .pi * 2.0
        emitter.setValue(3.0, forKey: "mass")
        emitter.setValue(2.0, forKey: "massRange")
        
        let staticColors: [Any] = [
            color.withAlphaComponent(0.0).cgColor,
            color.cgColor,
            color.cgColor,
            color.withAlphaComponent(0.0).cgColor
        ]
        let staticColorBehavior = CAEmitterCell.createEmitterBehavior(type: "colorOverLife")
        staticColorBehavior.setValue(staticColors, forKey: "colors")
        emitter.setValue([staticColorBehavior], forKey: "emitterBehaviors")
        
        self.emitterLayer.emitterCells = [emitter]
    }
    
    func update(size: CGSize) {
        if self.emitterLayer.emitterCells == nil {
            self.setup()
        }
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = CGSize(width: size.width * 0.7, height: size.height * 0.7)
        self.emitterLayer.emitterMode = .surface
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}
