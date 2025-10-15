import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
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
import PeerInfoCoverComponent
import Markdown
import CheckNode
import BundleIconComponent

public final class GiftItemComponent: Component {
    public enum Subject: Equatable {
        case premium(months: Int32, price: String)
        case starGift(gift: StarGift.Gift, price: String)
        case uniqueGift(gift: StarGift.UniqueGift, price: String?)
    }
    
    public struct Ribbon: Equatable {
        public enum Color: Equatable {
            case red
            case blue
            case purple
            case green
            case orange
            case custom(Int32, Int32)
            
            func colors(theme: PresentationTheme) -> [UIColor] {
                switch self {
                case .red:
                    if theme.overallDarkAppearance {
                        return [
                            UIColor(rgb: 0x522124),
                            UIColor(rgb: 0x653634)
                        ]
                    } else {
                        return [
                            UIColor(rgb: 0xed1c26),
                            UIColor(rgb: 0xff5c55)
                        ]
                    }
                case .blue:
                    if theme.overallDarkAppearance {
                        return [
                            UIColor(rgb: 0x142e42),
                            UIColor(rgb: 0x354f5b)
                        ]
                    } else {
                        return [
                            UIColor(rgb: 0x34a4fc),
                            UIColor(rgb: 0x6fd3ff)
                        ]
                    }
                case .purple:
                    return [
                        UIColor(rgb: 0x747bf6),
                        UIColor(rgb: 0xe367d8)
                    ]
                case .green:
                    return [
                        UIColor(rgb: 0x4bb121),
                        UIColor(rgb: 0x53d654)
                    ]
                case .orange:
                    return [
                        UIColor(rgb: 0xea8b01),
                        UIColor(rgb: 0xfab625)
                    ]
                case let .custom(topColor, _):
                    return [
                        UIColor(rgb: UInt32(bitPattern: topColor)).withMultiplied(hue: 0.97, saturation: 1.45, brightness: 0.89),
                        UIColor(rgb: UInt32(bitPattern: topColor)).withMultiplied(hue: 1.01, saturation: 1.22, brightness: 1.04)
                    ]
                }
            }
        }
        
        public enum Font {
            case generic
            case larger
            case monospaced
        }
        
        public let text: String
        public let font: Font
        public let color: Color
        public let outline: UIColor?
        
        public init(
            text: String,
            font: Font = .generic,
            color: Color,
            outline: UIColor? = nil
        ) {
            self.text = text
            self.font = font
            self.color = color
            self.outline = outline
        }
    }
    
    public enum Outline: Equatable {
        case orange
        
        func colors(theme: PresentationTheme) -> [UIColor] {
            switch self {
            case .orange:
                return [
                    UIColor(rgb: 0xfab625),
                    UIColor(rgb: 0xea8b01)
                ]
            }
        }
    }
    
    public enum Peer: Equatable {
        case peer(EnginePeer)
        case anonymous
    }
    
    public enum Mode: Equatable {
        case generic
        case profile
        case thumbnail
        case preview
        case grid
        case select
        case buttonIcon
    }
    
    let context: AccountContext
    let theme: PresentationTheme
    let strings: PresentationStrings
    let peer: GiftItemComponent.Peer?
    let subject: GiftItemComponent.Subject
    let title: String?
    let subtitle: String?
    let label: String?
    let ribbon: Ribbon?
    let outline: Outline?
    let resellPrice: Int64?
    let isLoading: Bool
    let isHidden: Bool
    let isSoldOut: Bool
    let isSelected: Bool
    let isPinned: Bool
    let isEditing: Bool
    let isDateLocked: Bool
    let mode: Mode
    let action: (() -> Void)?
    let contextAction: ((UIView, ContextGesture) -> Void)?
    
    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        peer: GiftItemComponent.Peer? = nil,
        subject: GiftItemComponent.Subject,
        title: String? = nil,
        subtitle: String? = nil,
        label: String? = nil,
        ribbon: Ribbon? = nil,
        outline: Outline? = nil,
        resellPrice: Int64? = nil,
        isLoading: Bool = false,
        isHidden: Bool = false,
        isSoldOut: Bool = false,
        isSelected: Bool = false,
        isPinned: Bool = false,
        isEditing: Bool = false,
        isDateLocked: Bool = false,
        mode: Mode = .generic,
        action: (() -> Void)? = nil,
        contextAction: ((UIView, ContextGesture) -> Void)? = nil
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.peer = peer
        self.subject = subject
        self.title = title
        self.subtitle = subtitle
        self.label = label
        self.ribbon = ribbon
        self.outline = outline
        self.resellPrice = resellPrice
        self.isLoading = isLoading
        self.isHidden = isHidden
        self.isSoldOut = isSoldOut
        self.isSelected = isSelected
        self.isPinned = isPinned
        self.isEditing = isEditing
        self.isDateLocked = isDateLocked
        self.mode = mode
        self.action = action
        self.contextAction = contextAction
    }

    public static func ==(lhs: GiftItemComponent, rhs: GiftItemComponent) -> Bool {
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
        if lhs.subject != rhs.subject {
            return false
        }
        if lhs.label != rhs.label {
            return false
        }
        if lhs.title != rhs.title {
            return false
        }
        if lhs.subtitle != rhs.subtitle {
            return false
        }
        if lhs.ribbon != rhs.ribbon {
            return false
        }
        if lhs.outline != rhs.outline {
            return false
        }
        if lhs.resellPrice != rhs.resellPrice {
            return false
        }
        if lhs.isLoading != rhs.isLoading {
            return false
        }
        if lhs.isHidden != rhs.isHidden {
            return false
        }
        if lhs.isSoldOut != rhs.isSoldOut {
            return false
        }
        if lhs.isSelected != rhs.isSelected {
            return false
        }
        if lhs.isPinned != rhs.isPinned {
            return false
        }
        if lhs.isEditing != rhs.isEditing {
            return false
        }
        if lhs.isDateLocked != rhs.isDateLocked {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        if (lhs.contextAction == nil) != (rhs.contextAction == nil) {
            return false
        }
        return true
    }

    public final class View: ContextControllerSourceView {
        private var component: GiftItemComponent?
        private weak var componentState: EmptyComponentState?
        
        private let containerButton = HighlightTrackingButton()
        
        private let backgroundLayer = SimpleLayer()
        private var loadingBackground: ComponentView<Empty>?
        
        private let patternView = ComponentView<Empty>()
        
        private var avatarNode: AvatarNode?
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let button = ComponentView<Empty>()
        private let label = ComponentView<Empty>()
        private let ton = ComponentView<Empty>()
       
        private let ribbonOutline = UIImageView()
        private let ribbon = UIImageView()
        private let ribbonText = ComponentView<Empty>()
        
        private var animationLayer: InlineStickerItemLayer?
        private var selectionLayer: SimpleShapeLayer?
        private var checkLayer: CheckLayer?
        private var outlineLayer: SimpleLayer?
        
        private var animationFile: TelegramMediaFile?
        
        private var disposables = DisposableSet()
        private var fetchedFiles = Set<Int64>()
        
        private var iconBackground: UIVisualEffectView?
        private var hiddenIcon: UIImageView?
        private var pinnedIcon: UIImageView?
        private var dateLockedIcon: UIImageView?
        
        private var resellBackground: BlurredBackgroundView?
        private let reselLabel = ComponentView<Empty>()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.layer.addSublayer(self.backgroundLayer)
            
            if #available(iOS 13.0, *) {
                self.backgroundLayer.cornerCurve = .circular
            }
            self.backgroundLayer.masksToBounds = true
            
            self.activated = { [weak self] gesture, _ in
                guard let self, let component = self.component else {
                    gesture.cancel()
                    return
                }
                component.contextAction?(self, gesture)
            }
            
            self.containerButton.addTarget(self, action: #selector(self.buttonPressed), for: .touchUpInside)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
            self.disposables.dispose()
        }
        
        @objc private func buttonPressed() {
            self.component?.action?()
        }
        
        func update(component: GiftItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let isFirstTime = self.component == nil
            let previousComponent = self.component
            self.component = component
            self.componentState = state
                        
            self.isGestureEnabled = component.contextAction != nil
            
            var themeUpdated = false
            if previousComponent?.theme !== component.theme {
                themeUpdated = true
            }
            
            var size: CGSize
            let iconSize: CGSize
            let cornerRadius: CGFloat
            switch component.mode {
            case .generic:
                size = CGSize(width: availableSize.width, height: component.title != nil ? 178.0 : 154.0)
                if let _ = component.label {
                    size.height += 23.0
                }
                iconSize = CGSize(width: 88.0, height: 88.0)
                cornerRadius = 10.0
            case .profile, .select:
                size = availableSize
                let side = floor(88.0 * availableSize.height / 116.0)
                iconSize = CGSize(width: side, height: side)
                cornerRadius = 10.0
            case .thumbnail:
                size = CGSize(width: availableSize.width, height: availableSize.width)
                iconSize = CGSize(width: floor(size.width * 0.7), height: floor(size.width * 0.7))
                cornerRadius = floor(availableSize.width * 0.2)
            case .grid:
                size = CGSize(width: availableSize.width, height: availableSize.width)
                iconSize = CGSize(width: floor(size.width * 0.7), height: floor(size.width * 0.7))
                cornerRadius = 10.0
            case .preview:
                size = availableSize
                iconSize = CGSize(width: floor(size.width * 0.6), height: floor(size.width * 0.6))
                cornerRadius = 4.0
            case .buttonIcon:
                size = CGSize(width: 26.0, height: 26.0)
                iconSize = size
                cornerRadius = 0.0
            }
            var backgroundSize = size
            if case .grid = component.mode {
                backgroundSize = CGSize(width: backgroundSize.width - 4.0, height: backgroundSize.height - 4.0)
            }
            
            self.backgroundLayer.cornerRadius = cornerRadius
            
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
            
            var animationFile: TelegramMediaFile?
            var backgroundColor: UIColor?
            var secondBackgroundColor: UIColor?
            var patternColor: UIColor?
            var patternFile: TelegramMediaFile?
            var files: [Int64: TelegramMediaFile] = [:]
            
            var placeholderColor = component.theme.list.mediaPlaceholderColor
            
            let emoji: ChatTextInputTextCustomEmojiAttribute?
            var animationOffset: CGFloat = 0.0
            switch component.subject {
            case let .premium(months, _):
                emoji = ChatTextInputTextCustomEmojiAttribute(
                    interactivelySelectedFromPackId: nil,
                    fileId: 0,
                    file: nil,
                    custom: .animation(name: "Gift\(months)")
                )
            case let .starGift(gift, _):
                animationFile = gift.file
                emoji = ChatTextInputTextCustomEmojiAttribute(
                    interactivelySelectedFromPackId: nil,
                    fileId: gift.file.fileId.id,
                    file: gift.file
                )
                animationOffset = 16.0
            case let .uniqueGift(gift, _):
                animationOffset = 16.0
                for attribute in gift.attributes {
                    switch attribute {
                    case let .model(_, file, _):
                        animationFile = file
                        if !self.fetchedFiles.contains(file.fileId.id) {
                            self.disposables.add(freeMediaFileResourceInteractiveFetched(account: component.context.account, userLocation: .other, fileReference: .standalone(media: file), resource: file.resource).start())
                            self.fetchedFiles.insert(file.fileId.id)
                        }
                    case let .pattern(_, file, _):
                        patternFile = file
                        files[file.fileId.id] = file
                    case let .backdrop(_, _, innerColorValue, outerColorValue, patternColorValue, _, _):
                        backgroundColor = UIColor(rgb: UInt32(bitPattern: outerColorValue))
                        secondBackgroundColor = UIColor(rgb: UInt32(bitPattern: innerColorValue))
                        patternColor = UIColor(rgb: UInt32(bitPattern: patternColorValue))
                        if let backgroundColor {
                            placeholderColor = backgroundColor
                        }
                    default:
                        break
                    }
                }
                                
                if let animationFile {
                    emoji = ChatTextInputTextCustomEmojiAttribute(
                        interactivelySelectedFromPackId: nil,
                        fileId: animationFile.fileId.id,
                        file: animationFile
                    )
                } else {
                    emoji = nil
                }
            }
            
            if case .buttonIcon = component.mode {
                backgroundColor = nil
                secondBackgroundColor = nil
                patternColor = nil
                placeholderColor = component.theme.list.mediaPlaceholderColor
            }
            
            var animationTransition = transition
            if self.animationLayer == nil || self.animationFile?.fileId != animationFile?.fileId, let emoji {
                animationTransition = .immediate
                self.animationFile = animationFile
                if let animationLayer = self.animationLayer {
                    self.animationLayer = nil
                    animationLayer.removeFromSuperlayer()
                }
                let animationLayer = InlineStickerItemLayer(
                    context: .account(component.context),
                    userLocation: .other,
                    attemptSynchronousLoad: false,
                    emoji: emoji,
                    file: animationFile,
                    cache: component.context.animationCache,
                    renderer: component.context.animationRenderer,
                    unique: false,
                    placeholderColor: placeholderColor,
                    pointSize: CGSize(width: iconSize.width * 2.0, height: iconSize.height * 2.0),
                    loopCount: 1
                )
                animationLayer.isVisibleForAnimations = true
                self.animationLayer = animationLayer
                
                if let patternView = self.patternView.view {
                    self.layer.insertSublayer(animationLayer, above: patternView.layer)
                } else {
                    self.layer.insertSublayer(animationLayer, above: self.backgroundLayer)
                }
            }
            
            let animationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: component.mode == .generic ? animationOffset : floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
            if let animationLayer = self.animationLayer {
                animationTransition.setFrame(layer: animationLayer, frame: animationFrame)
            }
            
            if let backgroundColor {
                let _ = self.patternView.update(
                    transition: .immediate,
                    component: AnyComponent(PeerInfoCoverComponent(
                        context: component.context,
                        subject: .custom(backgroundColor, secondBackgroundColor, patternColor, patternFile?.fileId.id),
                        files: files,
                        isDark: false,
                        avatarCenter: CGPoint(x: backgroundSize.width / 2.0, y: animationFrame.midY),
                        avatarScale: 1.0,
                        defaultHeight: backgroundSize.height,
                        avatarTransitionFraction: 0.0,
                        patternTransitionFraction: 0.0
                    )),
                    environment: {},
                    containerSize: backgroundSize
                )
                if let backgroundView = self.patternView.view {
                    if backgroundView.superview == nil {
                        backgroundView.layer.cornerRadius = cornerRadius
                        if #available(iOS 13.0, *) {
                            backgroundView.layer.cornerCurve = .circular
                        }
                        backgroundView.clipsToBounds = true
                        self.insertSubview(backgroundView, at: 1)
                    }
                    backgroundView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize)
                }
            }
            
            if case .generic = component.mode {
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
                
                let buttonColor: UIColor
                var starsColor: UIColor?
                var tinted = false
                let price: String
                switch component.subject {
                case let .premium(_, priceValue), let .starGift(_, priceValue):
                    if priceValue.contains("#") {
                        buttonColor = component.theme.overallDarkAppearance ? UIColor(rgb: 0xffc337) : UIColor(rgb: 0xd3720a)
                        if !component.isSoldOut {
                            starsColor = UIColor(rgb: 0xffbe27)
                        }
                    } else {
                        buttonColor = component.theme.list.itemAccentColor
                    }
                    price = priceValue
                case let .uniqueGift(_, priceValue):
                    if let ribbon = component.ribbon, case let .custom(bottomValue, topValue) = ribbon.color {
                        let topColor = UIColor(rgb: UInt32(bitPattern: topValue)).withMultiplied(hue: 1.01, saturation: 1.22, brightness: 1.04)
                        let bottomColor = UIColor(rgb: UInt32(bitPattern: bottomValue)).withMultiplied(hue: 0.97, saturation: 1.45, brightness: 0.89)
                        buttonColor = topColor.mixedWith(bottomColor, alpha: 0.8)
                    } else {
                        buttonColor = UIColor.white
                    }
                    price = priceValue ?? component.strings.Gift_Options_Gift_Transfer
                    tinted = true
                }
                
                let buttonSize = self.button.update(
                    transition: transition,
                    component: AnyComponent(
                        ButtonContentComponent(
                            context: component.context,
                            text: price,
                            color: buttonColor,
                            tinted: tinted,
                            starsColor: starsColor
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                var bottomOffset: CGFloat = 10.0
                if let _ = component.label {
                    bottomOffset += 23.0
                }
                let buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - buttonSize.width) / 2.0), y: size.height - buttonSize.height - bottomOffset), size: buttonSize)
                if let buttonView = self.button.view {
                    if buttonView.superview == nil {
                        self.addSubview(buttonView)
                    }
                    transition.setFrame(view: buttonView, frame: buttonFrame)
                }
                
                if let label = component.label {
                    let labelColor = component.theme.overallDarkAppearance ? UIColor(rgb: 0xffc337) : UIColor(rgb: 0xd3720a)
                    let attributes = MarkdownAttributes(
                        body: MarkdownAttributeSet(font: Font.regular(11.0), textColor: labelColor),
                        bold: MarkdownAttributeSet(font: Font.semibold(11.0), textColor: labelColor),
                        link: MarkdownAttributeSet(font: Font.regular(11.0), textColor: labelColor),
                        linkAttribute: { contents in
                            return (TelegramTextAttributes.URL, contents)
                        }
                    )
                    let labelText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString(label, attributes: attributes))
                    if let range = labelText.string.range(of: "#") {
                        labelText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: NSRange(range, in: labelText.string))
                    }
                    
                    let labelSize = self.label.update(
                        transition: transition,
                        component: AnyComponent(
                            MultilineTextWithEntitiesComponent(
                                context: component.context,
                                animationCache: component.context.animationCache,
                                animationRenderer: component.context.animationRenderer,
                                placeholderColor: .white,
                                text: .plain(labelText),
                                horizontalAlignment: .center
                            )
                        ),
                        environment: {},
                        containerSize: availableSize
                    )
                    let labelFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - labelSize.width) / 2.0), y: 178.0), size: labelSize)
                    if let labelView = self.label.view {
                        if labelView.superview == nil {
                            self.addSubview(labelView)
                        }
                        transition.setFrame(view: labelView, frame: labelFrame)
                    }
                }
                
                if case let .uniqueGift(gift, _) = component.subject, gift.resellForTonOnly {
                    let tonSize = self.ton.update(
                        transition: .immediate,
                        component: AnyComponent(
                            ZStack([
                                AnyComponentWithIdentity(id: "background", component: AnyComponent(RoundedRectangle(color: buttonColor, cornerRadius: 12.0))),
                                AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Premium/TonGift", tintColor: .white)))
                            ])
                        ),
                        environment: {},
                        containerSize: CGSize(width: 24.0, height: 24.0)
                    )
                    let tonFrame = CGRect(origin: CGPoint(x: 4.0, y: 4.0), size: tonSize)
                    if let tonView = self.ton.view {
                        if tonView.superview == nil {
                            self.addSubview(tonView)
                        }
                        transition.setFrame(view: tonView, frame: tonFrame)
                    }
                } else if let tonView = self.ton.view, tonView.superview != nil {
                    tonView.removeFromSuperview()
                }
            }
            
            if let ribbon = component.ribbon {
                let ribbonFontSize: CGFloat
                if case .profile = component.mode {
                    ribbonFontSize = 9.0
                } else {
                    ribbonFontSize = 10.0
                }
                let ribbonFont: UIFont
                switch ribbon.font {
                case .generic:
                    ribbonFont = Font.semibold(ribbonFontSize)
                case .larger:
                    ribbonFont = Font.semibold(10.0)
                case .monospaced:
                    ribbonFont = Font.with(size: 10.0, design: .monospace, weight: .semibold)
                }
                
                let ribbonTextSize = self.ribbonText.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: ribbon.text, font: ribbonFont, textColor: .white)),
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
                    
                    if let _ = component.ribbon?.outline {
                        if self.ribbonOutline.image == nil || themeUpdated || previousComponent?.ribbon?.outline != component.ribbon?.outline {
                            self.ribbonOutline.image = ribbonOutlineImage
                            self.ribbonOutline.tintColor = component.ribbon?.outline
                            if self.ribbonOutline.superview == nil {
                                self.insertSubview(self.ribbonOutline, belowSubview: self.ribbon)
                            }
                        }
                    } else if self.ribbonOutline.superview != nil {
                        self.ribbonOutline.removeFromSuperview()
                    }
                    
                    if self.ribbon.image == nil || themeUpdated || previousComponent?.ribbon?.color != component.ribbon?.color {
                        var direction: GradientImageDirection = .mirroredDiagonal
                        if case .custom = ribbon.color {
                            direction = .mirroredDiagonal
                        }
                        self.ribbon.image = generateGradientTintedImage(image: UIImage(bundleImageName: "Premium/GiftRibbon"), colors: ribbon.color.colors(theme: component.theme), direction: direction)
                    }
                    
                    var ribbonOffset: CGPoint = CGPoint(x: 2.0, y: -2.0)
                    if case .grid = component.mode {
                        ribbonOffset = .zero
                    }
                    
                    if let ribbonImage = self.ribbon.image {
                        self.ribbon.frame = CGRect(origin: CGPoint(x: size.width - ribbonImage.size.width + ribbonOffset.x, y: ribbonOffset.y), size: ribbonImage.size)
                    }
                    if let ribbonOutlineImage = self.ribbonOutline.image {
                        self.ribbonOutline.frame = ribbonOutlineImage.size.centered(around: self.ribbon.center.offsetBy(dx: 0.0, dy: 2.0))
                    }
                    
                    ribbonTextView.transform = CGAffineTransform(rotationAngle: .pi / 4.0)
                    ribbonTextView.center = CGPoint(x: size.width - 22.0 + ribbonOffset.x, y: 22.0 + ribbonOffset.y)
                }
            } else {
                if self.ribbonText.view?.superview != nil {
                    self.ribbonOutline.removeFromSuperview()
                    self.ribbon.removeFromSuperview()
                    self.ribbonText.view?.removeFromSuperview()
                }
            }
            
            if let peer = component.peer, !component.isPinned && component.mode != .select {
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
                
                avatarNode.frame = CGRect(origin: CGPoint(x: 5.0, y: 5.0), size: CGSize(width: 20.0, height: 20.0))
            } else if let avatarNode = self.avatarNode {
                self.avatarNode = nil
                avatarNode.view.removeFromSuperview()
            }
            
            if let backgroundColor, let _ = secondBackgroundColor {
                self.backgroundLayer.backgroundColor = backgroundColor.cgColor
            } else {
                self.backgroundLayer.backgroundColor = component.theme.list.itemBlocksBackgroundColor.cgColor
            }
            
            let backgroundFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - backgroundSize.width) / 2.0), y: floorToScreenPixels((size.height - backgroundSize.height) / 2.0)), size: backgroundSize)
            transition.setFrame(layer: self.backgroundLayer, frame: backgroundFrame)
            transition.setFrame(view: self.containerButton, frame: CGRect(origin: .zero, size: size))
            
            var iconBackgroundSize: CGSize?
            if component.isEditing {
                if !component.isPinned && backgroundColor != nil {
                    iconBackgroundSize = CGSize(width: 48.0, height: 48.0)
                }
            } else {
                if component.isHidden {
                    iconBackgroundSize = CGSize(width: 30.0, height: 30.0)
                }
            }
            
            if let iconBackgroundSize {
                let iconBackground: UIVisualEffectView
                var iconBackgroundTransition = transition
                if let currentBackground = self.iconBackground {
                    iconBackground = currentBackground
                } else {
                    iconBackgroundTransition = .immediate
                    
                    let blurEffect: UIBlurEffect
                    if #available(iOS 13.0, *) {
                        blurEffect = UIBlurEffect(style: .systemThinMaterialDark)
                    } else {
                        blurEffect = UIBlurEffect(style: .dark)
                    }
                    iconBackground = UIVisualEffectView(effect: blurEffect)
                    iconBackground.clipsToBounds = true
                    self.iconBackground = iconBackground
                    
                    self.addSubview(iconBackground)
                    
                    if !isFirstTime {
                        iconBackground.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        iconBackground.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                iconBackgroundTransition.containedViewLayoutTransition.animateView {
                    iconBackground.frame = iconBackgroundSize.centered(around: animationFrame.center)
                    iconBackground.layer.cornerRadius = iconBackgroundSize.width / 2.0
                }
            } else if let iconBackground = self.iconBackground {
                self.iconBackground = nil
                iconBackground.layer.animateAlpha(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    iconBackground.removeFromSuperview()
                })
                iconBackground.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            }
            
            if component.isPinned || (component.isEditing && backgroundColor != nil) {
                let pinnedIcon: UIImageView
                if let currentIcon = self.pinnedIcon {
                    pinnedIcon = currentIcon
                } else {
                    pinnedIcon = UIImageView(image: UIImage(bundleImageName: !component.isPinned ? "Peer Info/PinnedLargeIcon" : "Peer Info/PinnedIcon")?.withRenderingMode(.alwaysTemplate))
                    self.pinnedIcon = pinnedIcon
                    self.addSubview(pinnedIcon)
                    
                    if !isFirstTime {
                        pinnedIcon.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        pinnedIcon.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                
                if component.isPinned {
                    pinnedIcon.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: CGSize(width: 24.0, height: 24.0))
                    pinnedIcon.tintColor = backgroundColor == nil ? component.theme.list.itemSecondaryTextColor : .white
                } else {
                    let iconSize = CGSize(width: 48.0, height: 48.0)
                    pinnedIcon.frame = iconSize.centered(around: animationFrame.center)
                    pinnedIcon.tintColor = .white
                }
            } else if let pinnedIcon = self.pinnedIcon {
                self.pinnedIcon = nil
                pinnedIcon.layer.animateAlpha(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    pinnedIcon.removeFromSuperview()
                })
                pinnedIcon.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            }
            
            if component.isDateLocked {
                let dateLockedIcon: UIImageView
                if let currentIcon = self.dateLockedIcon {
                    dateLockedIcon = currentIcon
                } else {
                    dateLockedIcon = UIImageView(image: UIImage(bundleImageName: "Peer Info/DateLockedIcon")?.withRenderingMode(.alwaysTemplate))
                    self.dateLockedIcon = dateLockedIcon
                    self.addSubview(dateLockedIcon)
                }
                dateLockedIcon.frame = CGRect(origin: CGPoint(x: 3.0, y: 3.0), size: CGSize(width: 24.0, height: 24.0))
                dateLockedIcon.tintColor = component.theme.list.itemDestructiveColor
            } else if let dateLockedIcon = self.dateLockedIcon {
                self.dateLockedIcon = nil
                dateLockedIcon.removeFromSuperview()
            }
                        
            if component.isHidden && !component.isEditing {
                let hiddenIcon: UIImageView
                if let currentIcon = self.hiddenIcon {
                    hiddenIcon = currentIcon
                } else {
                    hiddenIcon = UIImageView(image: generateTintedImage(image: UIImage(bundleImageName: "Peer Info/HiddenIcon"), color: .white))
                    self.hiddenIcon = hiddenIcon
                    self.addSubview(hiddenIcon)
                    
                    if !isFirstTime {
                        hiddenIcon.layer.animateScale(from: 0.01, to: 1.0, duration: 0.2)
                        hiddenIcon.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                    }
                }
                
                let iconSize = CGSize(width: 30.0, height: 30.0)
                hiddenIcon.frame = iconSize.centered(around: animationFrame.center)
            } else if let hiddenIcon = self.hiddenIcon {
                self.hiddenIcon = nil
                hiddenIcon.layer.animateAlpha(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false, completion: { _ in
                    hiddenIcon.removeFromSuperview()
                })
                hiddenIcon.layer.animateScale(from: 1.0, to: 0.01, duration: 0.2, removeOnCompletion: false)
            }

            if let resellPrice = component.resellPrice {
                let labelColor = UIColor.white
                let attributes = MarkdownAttributes(
                    body: MarkdownAttributeSet(font: Font.semibold(11.0), textColor: labelColor),
                    bold: MarkdownAttributeSet(font: Font.semibold(11.0), textColor: labelColor),
                    link: MarkdownAttributeSet(font: Font.regular(11.0), textColor: labelColor),
                    linkAttribute: { contents in
                        return (TelegramTextAttributes.URL, contents)
                    }
                )
                let dateTimeFormat = component.context.sharedContext.currentPresentationData.with { $0 }.dateTimeFormat
                let labelText = NSMutableAttributedString(attributedString: parseMarkdownIntoAttributedString("# \(presentationStringsFormattedNumber(Int32(resellPrice), dateTimeFormat.groupingSeparator))", attributes: attributes))
                let range = (labelText.string as NSString).range(of: "#")
                if range.location != NSNotFound {
                    labelText.addAttribute(NSAttributedString.Key.font, value: Font.semibold(10.0), range: range)
                    labelText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: true)), range: range)
                    labelText.addAttribute(.kern, value: -1.5, range: NSRange(location: range.upperBound, length: 1))
                }
                
                let resellSize = self.reselLabel.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextWithEntitiesComponent(
                            context: component.context,
                            animationCache: component.context.animationCache,
                            animationRenderer: component.context.animationRenderer,
                            placeholderColor: .white,
                            text: .plain(labelText),
                            horizontalAlignment: .center
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                
                let resellFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - resellSize.width) / 2.0), y: size.height - 20.0), size: resellSize)
                
                let resellBackground: BlurredBackgroundView
                var resellBackgroundTransition = transition
                if let currentBackground = self.resellBackground {
                    resellBackground = currentBackground
                } else {
                    resellBackgroundTransition = .immediate
                    
                    resellBackground = BlurredBackgroundView(color: UIColor(rgb: 0x000000, alpha: 0.3), enableBlur: true)
                    resellBackground.clipsToBounds = true
                    self.resellBackground = resellBackground
                    
                    self.addSubview(resellBackground)
                }
                let resellBackgroundFrame = resellFrame.insetBy(dx: -6.0, dy: -4.0)
                resellBackgroundTransition.setFrame(view: resellBackground, frame: resellBackgroundFrame)
                resellBackground.update(size: resellBackgroundFrame.size, cornerRadius: resellBackgroundFrame.size.height / 2.0, transition: resellBackgroundTransition.containedViewLayoutTransition)
                
                if let resellLabelView = self.reselLabel.view {
                    if resellLabelView.superview == nil {
                        self.addSubview(resellLabelView)
                    }
                    transition.setFrame(view: resellLabelView, frame: resellFrame)
                }
            } else {
                self.reselLabel.view?.removeFromSuperview()
                if let resellBackground = self.resellBackground {
                    self.resellBackground = nil
                    resellBackground.removeFromSuperview()
                }
            }
            
            switch component.mode {
            case .generic, .grid:
                let lineWidth: CGFloat = 2.0
                let selectionFrame = backgroundFrame.insetBy(dx: 3.0, dy: 3.0)
                
                if component.isSelected {
                    let selectionLayer: SimpleShapeLayer
                    if let current = self.selectionLayer {
                        selectionLayer = current
                    } else {
                        selectionLayer = SimpleShapeLayer()
                        self.selectionLayer = selectionLayer
                        if self.ribbon.layer.superlayer != nil {
                            self.layer.insertSublayer(selectionLayer, below: self.ribbon.layer)
                        } else {
                            self.layer.addSublayer(selectionLayer)
                        }
                        
                        selectionLayer.fillColor = UIColor.clear.cgColor
                        selectionLayer.strokeColor = UIColor.white.cgColor
                        selectionLayer.lineWidth = lineWidth
                        selectionLayer.frame = selectionFrame
                        selectionLayer.path = CGPath(roundedRect: CGRect(origin: .zero, size: selectionFrame.size).insetBy(dx: lineWidth / 2.0, dy: lineWidth / 2.0), cornerWidth: 6.0, cornerHeight: 6.0, transform: nil)
                        
                        if !transition.animation.isImmediate {
                            let initialPath = CGPath(roundedRect: CGRect(origin: .zero, size: selectionFrame.size).insetBy(dx: 0.0, dy: 0.0), cornerWidth: 6.0, cornerHeight: 6.0, transform: nil)
                            selectionLayer.animate(from: initialPath, to: selectionLayer.path as AnyObject, keyPath: "path", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2)
                            selectionLayer.animateShapeLineWidth(from: 0.0, to: lineWidth, duration: 0.2)
                        }
                    }
                    
                } else if let selectionLayer = self.selectionLayer {
                    self.selectionLayer = nil
                    
                    let targetPath = CGPath(roundedRect: CGRect(origin: .zero, size: selectionFrame.size).insetBy(dx: 0.0, dy: 0.0), cornerWidth: 6.0, cornerHeight: 6.0, transform: nil)
                    selectionLayer.animate(from: selectionLayer.path, to: targetPath, keyPath: "path", timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, duration: 0.2, removeOnCompletion: false)
                    selectionLayer.animateShapeLineWidth(from: selectionLayer.lineWidth, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { _ in
                        selectionLayer.removeFromSuperlayer()
                    })
                }
            default:
                break
            }
            
            if case .select = component.mode {
                var checkFrame = CGRect(origin: CGPoint(x: 4.0, y: 4.0), size: CGSize(width: 26.0, height: 26.0))
                let checkTheme: CheckNodeTheme
                if case .uniqueGift = component.subject {
                    checkTheme = CheckNodeTheme(theme: component.theme, style: .overlay)
                } else {
                    checkTheme = CheckNodeTheme(theme: component.theme, style: .plain)
                    checkFrame = checkFrame.insetBy(dx: 2.0, dy: 2.0)
                }
                
                var isAnimated = true
                let checkLayer: CheckLayer
                if let current = self.checkLayer {
                    checkLayer = current
                } else {
                    isAnimated = false
                    checkLayer = CheckLayer(theme: checkTheme)
                    self.checkLayer = checkLayer
                    self.layer.addSublayer(checkLayer)
                }
                
                checkLayer.theme = checkTheme
                checkLayer.frame = checkFrame
                checkLayer.setSelected(component.isSelected, animated: isAnimated)
            }
            
            if let outline = component.outline {
                let lineWidth: CGFloat = 2.0
                let outlineFrame = backgroundFrame
                
                let outlineLayer: SimpleLayer
                if let current = self.outlineLayer {
                    outlineLayer = current
                } else {
                    outlineLayer = SimpleLayer()
                    self.outlineLayer = outlineLayer
                    if self.ribbon.layer.superlayer != nil {
                        self.layer.insertSublayer(outlineLayer, below: self.ribbon.layer)
                    } else {
                        self.layer.addSublayer(outlineLayer)
                    }

                    let image = generateImage(outlineFrame.size, rotatedContext: { size, context in
                        context.clear(CGRect(origin: .zero, size: size))
                        
                        context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: outlineFrame.size), cornerWidth: 10.0, cornerHeight: 10.0, transform: nil))
                        context.addPath(CGPath(roundedRect: CGRect(origin: .zero, size: outlineFrame.size).insetBy(dx: lineWidth, dy: lineWidth), cornerWidth: 8.0, cornerHeight: 8.0, transform: nil))
                        
                        context.clip(using: .evenOdd)
                        
                        var locations: [CGFloat] = [0.0, 1.0]
                        let colors: [CGColor] = outline.colors(theme: component.theme).map { $0.cgColor }
                        
                        let colorSpace = CGColorSpaceCreateDeviceRGB()
                        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
                        
                        context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: size.height), options: CGGradientDrawingOptions())
                        
                        context.resetClip()
                        
                        if let _ = component.ribbon, let ribbonOutline = ribbonOutlineImage, let cgImage = ribbonOutline.cgImage {
                            context.saveGState()
                            
                            context.translateBy(x: 0.0, y: size.height)
                            context.scaleBy(x: 1.0, y: -1.0)
                            
                            context.clip(to: CGRect(origin: CGPoint(x: size.width - 58.0, y: 91.0 - UIScreenPixel), size: ribbonOutline.size), mask: cgImage)
                            context.setBlendMode(.clear)
                            context.setFillColor(UIColor.clear.cgColor)
                            context.fill(CGRect(origin: .zero, size: size))
                            
                            context.restoreGState()
                        }
                    })
                    outlineLayer.contents = image?.cgImage

                    outlineLayer.frame = outlineFrame
                }
                
            } else if let outlineLayer = self.outlineLayer {
                self.outlineLayer = nil
                outlineLayer.removeFromSuperlayer()
            }
            
            if let _ = component.action {
                self.addSubview(self.containerButton)
                self.containerButton.isUserInteractionEnabled = true
            } else {
                self.containerButton.isUserInteractionEnabled = false
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
    let tinted: Bool
    let starsColor: UIColor?
    
    public init(
        context: AccountContext,
        text: String,
        color: UIColor,
        tinted: Bool = false,
        starsColor: UIColor? = nil
    ) {
        self.context = context
        self.text = text
        self.color = color
        self.tinted = tinted
        self.starsColor = starsColor
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
        if lhs.tinted != rhs.tinted {
            return false
        }
        if lhs.starsColor != rhs.starsColor {
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
            
            var textColor = component.color
            if component.tinted {
                textColor = .white
            }
                        
            let attributedText = NSMutableAttributedString(string: component.text, font: Font.semibold(11.0), textColor: textColor)
            let range = (attributedText.string as NSString).range(of: "#")
            if range.location != NSNotFound {
                attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: component.tinted)), range: range)
                attributedText.addAttribute(.font, value: Font.semibold(component.tinted ? 14.0 : 15.0), range: range)
                attributedText.addAttribute(.baselineOffset, value: -3.0, range: range)
                attributedText.addAttribute(.baselineOffset, value: 1.5, range: NSRange(location: range.upperBound + 1, length: attributedText.length - range.upperBound - 1))
                attributedText.addAttribute(.kern, value: -1.5, range: NSRange(location: range.upperBound, length: 1))
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
            
            if let starsColor = component.starsColor {
                let starsLayer: StarsButtonEffectLayer
                if let current = self.starsLayer {
                    starsLayer = current
                } else {
                    starsLayer = StarsButtonEffectLayer()
                    self.layer.addSublayer(starsLayer)
                    self.starsLayer = starsLayer
                }
                starsLayer.frame = CGRect(origin: .zero, size: size)
                starsLayer.update(color: starsColor, size: size)
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
                if component.tinted {
                    backgroundColor = component.color
                } else {
                    backgroundColor = component.color.withAlphaComponent(0.1)
                }
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
    
    private func setup(color: UIColor) {
        let emitter = CAEmitterCell()
        emitter.name = "emitter"
        emitter.contents = UIImage(bundleImageName: "Premium/Stars/Particle")?.cgImage
        emitter.birthRate = 14.0
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
    
    func update(color: UIColor, size: CGSize) {
        if self.emitterLayer.emitterCells == nil {
            self.setup(color: color)
        }
        self.emitterLayer.emitterShape = .circle
        self.emitterLayer.emitterSize = CGSize(width: size.width * 0.7, height: size.height * 0.7)
        self.emitterLayer.emitterMode = .surface
        self.emitterLayer.frame = CGRect(origin: .zero, size: size)
        self.emitterLayer.emitterPosition = CGPoint(x: size.width / 2.0, y: size.height / 2.0)
    }
}

private var ribbonOutlineImage: UIImage? = {
    if let image = UIImage(bundleImageName: "Premium/GiftRibbon") {
        return generateScaledImage(image: image, size: CGSize(width: image.size.width + 8.0, height: image.size.height + 8.0), opaque: false)?.withRenderingMode(.alwaysTemplate)
    } else {
        return UIImage()
    }
}()
