import Foundation
import LottieSettings
import UIKit
import AsyncDisplayKit
import Display
import TelegramPresentationData
import ManagedAnimationNode
import ComponentFlow
import PremiumLockButtonSubtitleComponent
import ButtonComponent

public enum WallpaperGalleryToolbarCancelButtonType {
    case cancel
    case discard
}

public enum WallpaperGalleryToolbarDoneButtonType {
    case set
    case setPeer(String, Bool)
    case setChannel
    case proceed
    case apply
    case none
}

public protocol WallpaperGalleryToolbar: ASDisplayNode {
    var cancelButtonType: WallpaperGalleryToolbarCancelButtonType { get set }
    var doneButtonType: WallpaperGalleryToolbarDoneButtonType { get set }

    var cancel: (() -> Void)? { get set }
    var done: ((Bool) -> Void)? { get set }

    func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings)

    func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)
}

public final class WallpaperGalleryToolbarNode: ASDisplayNode, WallpaperGalleryToolbar {
    class ButtonNode: ASDisplayNode {
        private let strings: PresentationStrings

        private let doneButton = HighlightTrackingButtonNode()
        private var doneButtonBackgroundNode: WallpaperOptionBackgroundNode
        private let doneButtonTitleNode: ImmediateTextNode
        private var doneButtonSubtitle: ComponentView<Empty>?

        private let doneButtonSolidBackgroundNode: ASDisplayNode
        private let doneButtonSolidTitleNode: ImmediateTextNode

        private let animationNode: SimpleAnimationNode

        var action: () -> Void = {}

        var isLocked: Bool = false {
            didSet {
                self.animationNode.isHidden = !self.isLocked
            }
        }

        var requiredLevel: Int?

        init(strings: PresentationStrings) {
            self.strings = strings

            self.doneButtonBackgroundNode = WallpaperOptionBackgroundNode(isDark: false)

            self.doneButtonTitleNode = ImmediateTextNode()
            self.doneButtonTitleNode.displaysAsynchronously = false
            self.doneButtonTitleNode.isUserInteractionEnabled = false

            self.doneButtonSolidBackgroundNode = ASDisplayNode()
            self.doneButtonSolidBackgroundNode.alpha = 0.0
            self.doneButtonSolidBackgroundNode.clipsToBounds = true
            self.doneButtonSolidBackgroundNode.layer.cornerRadius = 26.0
            if #available(iOS 13.0, *) {
                self.doneButtonSolidBackgroundNode.layer.cornerCurve = .continuous
            }
            self.doneButtonSolidBackgroundNode.isUserInteractionEnabled = false

            self.doneButtonSolidTitleNode = ImmediateTextNode()
            self.doneButtonSolidTitleNode.alpha = 0.0
            self.doneButtonSolidTitleNode.displaysAsynchronously = false
            self.doneButtonSolidTitleNode.isUserInteractionEnabled = false

            self.animationNode = SimpleAnimationNode(animationName: "premium_unlock", size: CGSize(width: 30.0, height: 30.0), lottieSettings: .noAccountFallback)
            self.animationNode.customColor = .white
            self.animationNode.isHidden = true

            super.init()

            self.doneButton.isExclusiveTouch = true

            self.addSubnode(self.doneButtonBackgroundNode)
            self.doneButtonBackgroundNode.contentView.addSubnode(self.doneButtonTitleNode)

            self.doneButtonBackgroundNode.contentView.addSubnode(self.doneButtonSolidBackgroundNode)
            self.doneButtonBackgroundNode.contentView.addSubnode(self.doneButtonSolidTitleNode)

            self.addSubnode(self.animationNode)

            self.doneButtonBackgroundNode.contentView.addSubview(self.doneButton.view)

            self.doneButton.addTarget(self, action: #selector(self.pressed), forControlEvents: .touchUpInside)
        }

        func setEnabled(_ enabled: Bool) {
            self.doneButton.alpha = enabled ? 1.0 : 0.4
            self.doneButton.isUserInteractionEnabled = enabled
        }

        private var isSolid = false
        func setIsSolid(_ isSolid: Bool, transition: ContainedViewLayoutTransition) {
            guard self.isSolid != isSolid else {
                return
            }
            self.isSolid = isSolid

            transition.updateAlpha(node: self.doneButtonBackgroundNode, alpha: isSolid ? 0.0 : 1.0)
            transition.updateAlpha(node: self.doneButtonSolidBackgroundNode, alpha: isSolid ? 1.0 : 0.0)
            transition.updateAlpha(node: self.doneButtonTitleNode, alpha: isSolid ? 0.0 : 1.0)
            transition.updateAlpha(node: self.doneButtonSolidTitleNode, alpha: isSolid ? 1.0 : 0.0)
        }

        func updateTitle(_ title: String, theme: PresentationTheme) {
            self.doneButtonTitleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: self.dark ? .white : .black)

            self.doneButtonSolidBackgroundNode.backgroundColor = theme.list.itemCheckColors.fillColor
            self.doneButtonSolidTitleNode.attributedText = NSAttributedString(string: title, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor)
        }

        func updateSize(_ size: CGSize) {
            let bounds = CGRect(origin: .zero, size: size)
            self.doneButtonBackgroundNode.frame = bounds
            self.doneButtonBackgroundNode.updateLayout(size: size)
            self.doneButtonSolidBackgroundNode.frame = bounds
            self.doneButtonSolidBackgroundNode.layer.cornerRadius = size.height * 0.5

            let constrainedSize = CGSize(width: size.width - 44.0, height: size.height)
            let iconSize = CGSize(width: 30.0, height: 30.0)
            let doneTitleSize = self.doneButtonTitleNode.updateLayout(constrainedSize)

            var totalWidth = doneTitleSize.width
            if self.isLocked {
                totalWidth += iconSize.width + 1.0
            }
            let titleOriginX = floorToScreenPixels((bounds.width - totalWidth) / 2.0)

            self.animationNode.frame = CGRect(origin: CGPoint(x: titleOriginX, y: floorToScreenPixels((bounds.height - iconSize.height) / 2.0)), size: iconSize)

            var titleFrame = CGRect(origin: CGPoint(x: titleOriginX + totalWidth - doneTitleSize.width, y: floorToScreenPixels((bounds.height - doneTitleSize.height) / 2.0)), size: doneTitleSize).offsetBy(dx: bounds.minX, dy: bounds.minY)

            if let requiredLevel = self.requiredLevel {
                let subtitle: ComponentView<Empty>
                if let current = self.doneButtonSubtitle {
                    subtitle = current
                } else {
                    subtitle = ComponentView<Empty>()
                    self.doneButtonSubtitle = subtitle
                }

                let subtitleSize = subtitle.update(
                    transition: .immediate,
                    component: AnyComponent(
                        PremiumLockButtonSubtitleComponent(
                            count: requiredLevel,
                            color: UIColor(rgb: 0xffffff, alpha: 0.7),
                            strings: self.strings
                        )
                    ),
                    environment: {},
                    containerSize: size
                )

                if let view = subtitle.view {
                    if view.superview == nil {
                        view.isUserInteractionEnabled = false
                        self.view.addSubview(view)
                    }

                    titleFrame.origin.y -= 8.0

                    let subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((bounds.width - subtitleSize.width) / 2.0), y: titleFrame.maxY + 3.0), size: subtitleSize)
                    view.frame = subtitleFrame
                }
            }

            self.doneButtonTitleNode.frame = titleFrame

            let _ = self.doneButtonSolidTitleNode.updateLayout(constrainedSize)
            self.doneButtonSolidTitleNode.frame = self.doneButtonTitleNode.frame

            self.doneButton.frame = bounds
        }

        var dark: Bool = false {
            didSet {
                if self.dark != oldValue {
                    self.doneButtonBackgroundNode.isDark = self.dark
                }
            }
        }

        private var previousActionTime: Double?
        @objc func pressed() {
            let currentTime = CACurrentMediaTime()
            if let previousActionTime = self.previousActionTime, currentTime < previousActionTime + 1.0 {
                return
            }
            self.previousActionTime = currentTime
            self.action()
        }
    }

    private var theme: PresentationTheme
    private let strings: PresentationStrings

    public var cancelButtonType: WallpaperGalleryToolbarCancelButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    public var doneButtonType: WallpaperGalleryToolbarDoneButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }

    public var dark: Bool = false {
        didSet {
            self.applyButton.dark = self.dark
            self.applyForBothButton.dark = self.dark
        }
    }

    private let applyButton: ButtonNode
    private let applyForBothButton: ButtonNode

    public var cancel: (() -> Void)?
    public var done: ((Bool) -> Void)?

    var requiredLevel: Int? {
        didSet {
            self.applyButton.requiredLevel = self.requiredLevel
        }
    }

    public init(theme: PresentationTheme, strings: PresentationStrings, cancelButtonType: WallpaperGalleryToolbarCancelButtonType = .cancel, doneButtonType: WallpaperGalleryToolbarDoneButtonType = .set) {
        self.theme = theme
        self.strings = strings
        self.cancelButtonType = cancelButtonType
        self.doneButtonType = doneButtonType

        self.applyButton = ButtonNode(strings: strings)
        self.applyForBothButton = ButtonNode(strings: strings)

        super.init()

        self.addSubnode(self.applyButton)
        self.addSubnode(self.applyForBothButton)

        self.updateThemeAndStrings(theme: theme, strings: strings)

        self.applyButton.action = { [weak self] in
            if let self {
                self.done?(false)
            }
        }
        self.applyForBothButton.action = { [weak self] in
            if let self {
                self.done?(true)
            }
        }
    }

    public func setDoneEnabled(_ enabled: Bool) {
        self.applyButton.setEnabled(enabled)
        self.applyForBothButton.setEnabled(enabled)
    }

    private var isSolid = false
    public func setDoneIsSolid(_ isSolid: Bool, transition: ContainedViewLayoutTransition) {
        guard self.isSolid != isSolid else {
            return
        }

        self.isSolid = isSolid
        self.applyButton.setIsSolid(isSolid, transition: transition)
        self.applyForBothButton.setIsSolid(isSolid, transition: transition)
    }

    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme
        self.applyButton.isUserInteractionEnabled = true

        let applyTitle: String
        var applyForBothTitle: String? = nil
        var applyForBothLocked = false
        switch self.doneButtonType {
        case .set:
            applyTitle = strings.Wallpaper_ApplyForAll
        case let .setPeer(name, isPremium):
            applyTitle = strings.Wallpaper_ApplyForMe
            applyForBothTitle = strings.Wallpaper_ApplyForBoth(name).string
            applyForBothLocked = !isPremium
        case .setChannel:
            applyTitle = strings.Wallpaper_ApplyForChannel
        case .proceed:
            applyTitle = strings.Theme_Colors_Proceed
        case .apply:
            applyTitle = strings.WallpaperPreview_PatternPaternApply
        case .none:
            applyTitle = ""
            self.applyButton.isUserInteractionEnabled = false
        }

        self.applyButton.updateTitle(applyTitle, theme: theme)
        if let applyForBothTitle {
            self.applyForBothButton.updateTitle(applyForBothTitle, theme: theme)
        }
        self.applyForBothButton.isLocked = applyForBothLocked
    }

    public func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        let inset: CGFloat = 30.0
        let buttonHeight: CGFloat = 52.0

        let spacing: CGFloat = 8.0

        let applyFrame = CGRect(origin: CGPoint(x: inset, y: 2.0), size: CGSize(width: size.width - inset * 2.0, height: buttonHeight))
        let applyForBothFrame = CGRect(origin: CGPoint(x: inset, y: applyFrame.maxY + spacing), size: CGSize(width: size.width - inset * 2.0, height: buttonHeight))

        var showApplyForBothButton = false
        if case .setPeer = self.doneButtonType {
            showApplyForBothButton = true
        }
        transition.updateAlpha(node: self.applyForBothButton, alpha: showApplyForBothButton ? 1.0 : 0.0)
        self.applyForBothButton.isUserInteractionEnabled = showApplyForBothButton

        self.applyButton.frame = applyFrame
        self.applyButton.updateSize(applyFrame.size)
        self.applyForBothButton.frame = applyForBothFrame
        self.applyForBothButton.updateSize(applyForBothFrame.size)
    }

    @objc func cancelPressed() {
        self.cancel?()
    }
}

public final class WallpaperGalleryOldToolbarNode: ASDisplayNode, WallpaperGalleryToolbar {
    private var theme: PresentationTheme
    private let strings: PresentationStrings

    public var cancelButtonType: WallpaperGalleryToolbarCancelButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }
    public var doneButtonType: WallpaperGalleryToolbarDoneButtonType {
        didSet {
            self.updateThemeAndStrings(theme: self.theme, strings: self.strings)
        }
    }

    private let cancelButton = ComponentView<Empty>()
    private let doneButton = ComponentView<Empty>()

    private var cancelTitle: String = ""
    private var doneTitle: String = ""
    private var doneEnabled: Bool = true
    private var validLayout: (CGSize, ContainerViewLayout)?

    public var cancel: (() -> Void)?
    public var done: ((Bool) -> Void)?

    public init(theme: PresentationTheme, strings: PresentationStrings, cancelButtonType: WallpaperGalleryToolbarCancelButtonType = .cancel, doneButtonType: WallpaperGalleryToolbarDoneButtonType = .set) {
        self.theme = theme
        self.strings = strings
        self.cancelButtonType = cancelButtonType
        self.doneButtonType = doneButtonType

        super.init()

        self.updateThemeAndStrings(theme: theme, strings: strings)
    }

    public func setDoneEnabled(_ enabled: Bool) {
        self.doneEnabled = enabled
        if let (size, layout) = self.validLayout {
            self.updateLayout(size: size, layout: layout, transition: .immediate)
        }
    }

    public func updateThemeAndStrings(theme: PresentationTheme, strings: PresentationStrings) {
        self.theme = theme

        switch self.cancelButtonType {
            case .cancel:
                self.cancelTitle = strings.Common_Cancel
            case .discard:
                self.cancelTitle = strings.WallpaperPreview_PatternPaternDiscard
        }
        switch self.doneButtonType {
            case .set, .setPeer, .setChannel:
                self.doneTitle = strings.Wallpaper_Set
            case .proceed:
                self.doneTitle = strings.Theme_Colors_Proceed
            case .apply:
                self.doneTitle = strings.WallpaperPreview_PatternPaternApply
            case .none:
                self.doneTitle = ""
        }

        if let (size, layout) = self.validLayout {
            self.updateLayout(size: size, layout: layout, transition: .immediate)
        }
    }

    public func updateLayout(size: CGSize, layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = (size, layout)

        let sideInset: CGFloat = 30.0
        let spacing: CGFloat = 24.0
        let buttonHeight: CGFloat = 52.0
        let buttonWidth = floor(max(1.0, size.width - sideInset * 2.0 - spacing) / 2.0)
        let buttonY = floor((size.height - buttonHeight) / 2.0)
        let cancelFrame = CGRect(x: sideInset, y: buttonY, width: buttonWidth, height: buttonHeight)
        let doneFrame = CGRect(x: cancelFrame.maxX + spacing, y: buttonY, width: max(1.0, size.width - sideInset - cancelFrame.maxX - spacing), height: buttonHeight)

        let glassColor = UIColor(white: 1.0, alpha: 0.0)
        let foregroundColor = self.theme.list.itemPrimaryTextColor
        let componentTransition = ComponentTransition(transition)

        let cancelSize = self.cancelButton.update(
            transition: componentTransition,
            component: AnyComponent(ButtonComponent(
                background: ButtonComponent.Background(
                    style: .actualGlass,
                    color: glassColor,
                    foreground: foregroundColor,
                    pressedColor: glassColor,
                    cornerRadius: buttonHeight * 0.5
                ),
                content: AnyComponentWithIdentity(
                    id: AnyHashable(self.cancelTitle),
                    component: AnyComponent(Text(text: self.cancelTitle, font: Font.semibold(17.0), color: foregroundColor))
                ),
                action: { [weak self] in
                    self?.cancel?()
                }
            )),
            environment: {},
            containerSize: cancelFrame.size
        )
        if let cancelView = self.cancelButton.view {
            if cancelView.superview == nil {
                self.view.addSubview(cancelView)
            }
            transition.updateFrame(view: cancelView, frame: CGRect(origin: cancelFrame.origin, size: cancelSize))
        }

        let doneIsVisible = !self.doneTitle.isEmpty
        let doneSize = self.doneButton.update(
            transition: componentTransition,
            component: AnyComponent(ButtonComponent(
                background: ButtonComponent.Background(
                    style: .actualGlass,
                    color: glassColor,
                    foreground: foregroundColor,
                    pressedColor: glassColor,
                    cornerRadius: buttonHeight * 0.5
                ),
                content: AnyComponentWithIdentity(
                    id: AnyHashable(self.doneTitle),
                    component: AnyComponent(Text(text: self.doneTitle, font: Font.semibold(17.0), color: foregroundColor))
                ),
                isEnabled: self.doneEnabled && doneIsVisible,
                tintWhenDisabled: false,
                action: { [weak self] in
                    self?.done?(false)
                }
            )),
            environment: {},
            containerSize: doneFrame.size
        )
        if let doneView = self.doneButton.view {
            if doneView.superview == nil {
                self.view.addSubview(doneView)
            }
            transition.updateFrame(view: doneView, frame: CGRect(origin: doneFrame.origin, size: doneSize))
            componentTransition.setAlpha(view: doneView, alpha: doneIsVisible ? (self.doneEnabled ? 1.0 : 0.4) : 0.0)
            doneView.isUserInteractionEnabled = self.doneEnabled && doneIsVisible
        }
    }
}
