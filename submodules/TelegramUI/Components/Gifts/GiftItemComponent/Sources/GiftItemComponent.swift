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

public final class GiftItemComponent: Component {
    public enum Subject: Equatable {
        case premium(months: Int32, price: String)
        case starGift(gift: StarGift.Gift, price: String)
        case uniqueGift(gift: StarGift.UniqueGift)
    }
    
    public struct Ribbon: Equatable {
        public enum Color: Equatable {
            case red
            case blue
            case purple
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
                case let .custom(topColor, _):
                    return [
                        UIColor(rgb: UInt32(bitPattern: topColor)).withMultiplied(hue: 0.97, saturation: 1.45, brightness: 0.89),
                        UIColor(rgb: UInt32(bitPattern: topColor)).withMultiplied(hue: 1.01, saturation: 1.22, brightness: 1.04)
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
    
    public enum Mode: Equatable {
        case generic
        case profile
        case thumbnail
        case preview
        case grid
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
    let isLoading: Bool
    let isHidden: Bool
    let isSoldOut: Bool
    let isSelected: Bool
    let isPinned: Bool
    let isEditing: Bool
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
        isLoading: Bool = false,
        isHidden: Bool = false,
        isSoldOut: Bool = false,
        isSelected: Bool = false,
        isPinned: Bool = false,
        isEditing: Bool = false,
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
        self.isLoading = isLoading
        self.isHidden = isHidden
        self.isSoldOut = isSoldOut
        self.isSelected = isSelected
        self.isPinned = isPinned
        self.isEditing = isEditing
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
        private let ribbon = UIImageView()
        private let ribbonText = ComponentView<Empty>()
        
        private var animationLayer: InlineStickerItemLayer?
        private var selectionLayer: SimpleShapeLayer?
        
        private var disposables = DisposableSet()
        private var fetchedFiles = Set<Int64>()
        
        private var iconBackground: UIVisualEffectView?
        private var hiddenIcon: UIImageView?
        private var pinnedIcon: UIImageView?
        
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
            case .profile:
                size = availableSize
                iconSize = CGSize(width: 88.0, height: 88.0)
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
            case let .uniqueGift(gift):
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
                    case let .backdrop(_, innerColorValue, outerColorValue, patternColorValue, _, _):
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
            
            if self.animationLayer == nil, let emoji {
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
                self.layer.addSublayer(animationLayer)
            }
            
            let animationFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - iconSize.width) / 2.0), y: component.mode == .generic ? animationOffset : floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
            if let animationLayer = self.animationLayer {
                transition.setFrame(layer: animationLayer, frame: animationFrame)
            }
            
            if let backgroundColor {
                let _ = self.patternView.update(
                    transition: .immediate,
                    component: AnyComponent(PeerInfoCoverComponent(
                        context: component.context,
                        subject: .custom(backgroundColor, secondBackgroundColor, patternColor, patternFile?.fileId.id),
                        files: files,
                        isDark: false,
                        avatarCenter: CGPoint(x: size.width / 2.0, y: animationFrame.midY),
                        avatarScale: 1.0,
                        defaultHeight: size.height,
                        avatarTransitionFraction: 0.0,
                        patternTransitionFraction: 0.0
                    )),
                    environment: {},
                    containerSize: availableSize
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
                    backgroundView.frame = CGRect(origin: .zero, size: size)
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
                let price: String
                switch component.subject {
                case let .premium(_, priceValue), let .starGift(_, priceValue):
                    if priceValue.containsEmoji {
                        buttonColor = component.theme.overallDarkAppearance ? UIColor(rgb: 0xffc337) : UIColor(rgb: 0xd3720a)
                        if !component.isSoldOut {
                            starsColor = UIColor(rgb: 0xffbe27)
                        }
                    } else {
                        buttonColor = component.theme.list.itemAccentColor
                    }
                    price = priceValue
                case .uniqueGift:
                    buttonColor = UIColor.white
                    price = component.strings.Gift_Options_Gift_Transfer
                }
                
                let buttonSize = self.button.update(
                    transition: transition,
                    component: AnyComponent(
                        ButtonContentComponent(
                            context: component.context,
                            text: price,
                            color: buttonColor,
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
            }
            
            if let ribbon = component.ribbon {
                let ribbonFontSize: CGFloat
                if case .profile = component.mode {
                    ribbonFontSize = 9.0
                } else {
                    ribbonFontSize = 10.0
                }
                let ribbonTextSize = self.ribbonText.update(
                    transition: transition,
                    component: AnyComponent(
                        MultilineTextComponent(
                            text: .plain(NSAttributedString(string: ribbon.text, font: Font.semibold(ribbonFontSize), textColor: .white)),
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
                    
                    if self.ribbon.image == nil || themeUpdated || previousComponent?.ribbon?.color != component.ribbon?.color {
                        var direction: GradientImageDirection = .mirroredDiagonal
                        if case .custom = ribbon.color {
                            direction = .mirroredDiagonal
                        }
                        self.ribbon.image = generateGradientTintedImage(image: UIImage(bundleImageName: "Premium/GiftRibbon"), colors: ribbon.color.colors(theme: component.theme), direction: direction)
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
            
            if let peer = component.peer, !component.isPinned {
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
            
            transition.setFrame(layer: self.backgroundLayer, frame: CGRect(origin: .zero, size: size))
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
            
            if case .grid = component.mode {
                let lineWidth: CGFloat = 2.0
                let selectionFrame = CGRect(origin: .zero, size: size).insetBy(dx: 3.0, dy: 3.0)
                
                if component.isSelected {
                    let selectionLayer: SimpleShapeLayer
                    if let current = self.selectionLayer {
                        selectionLayer = current
                    } else {
                        selectionLayer = SimpleShapeLayer()
                        self.selectionLayer = selectionLayer
                        self.layer.addSublayer(selectionLayer)
                        
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
    let starsColor: UIColor?
    
    public init(
        context: AccountContext,
        text: String,
        color: UIColor,
        starsColor: UIColor? = nil
    ) {
        self.context = context
        self.text = text
        self.color = color
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
