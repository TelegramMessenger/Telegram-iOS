import Foundation
import UIKit
import Display
import ActivityIndicator
import AccountContext
import ComponentFlow
import MultilineTextComponent
import BundleIconComponent
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import StarsAvatarComponent
import WalletContext
import WalletCollectibleImageComponent

private final class WalletTransactionAddressTitleComponent: Component {
    let address: String
    let textColor: UIColor
    let backgroundColor: UIColor

    init(address: String, textColor: UIColor, backgroundColor: UIColor) {
        self.address = address
        self.textColor = textColor
        self.backgroundColor = backgroundColor
    }

    static func ==(lhs: WalletTransactionAddressTitleComponent, rhs: WalletTransactionAddressTitleComponent) -> Bool {
        return lhs.address == rhs.address
            && lhs.textColor == rhs.textColor
            && lhs.backgroundColor == rhs.backgroundColor
    }

    final class View: UIView {
        private let contentView = UIView()
        private var backgrounds: [UIView] = []
        private var labels: [UILabel] = []

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.isAccessibilityElement = true
            self.accessibilityTraits = .staticText
            self.addSubview(self.contentView)

            for index in 0 ..< 3 {
                let background = UIView(frame: CGRect(x: CGFloat(index) * 52.0, y: 0.0, width: 48.0, height: 22.0))
                background.layer.cornerRadius = 6.0
                self.contentView.addSubview(background)
                self.backgrounds.append(background)

                let label = UILabel(frame: background.bounds)
                label.font = Font.with(size: 16.0, design: .monospace, weight: .semibold)
                label.textAlignment = .center
                label.isAccessibilityElement = false
                background.addSubview(label)
                self.labels.append(label)

                if index == 1 {
                    let mask = CAGradientLayer()
                    mask.frame = label.bounds
                    mask.startPoint = CGPoint(x: 0.0, y: 0.5)
                    mask.endPoint = CGPoint(x: 1.0, y: 0.5)
                    mask.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor, UIColor.black.cgColor, UIColor.black.cgColor]
                    mask.locations = [0.0, 0.15, 0.5, 0.85, 1.0]
                    label.layer.mask = mask
                }
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletTransactionAddressTitleComponent, availableSize: CGSize) -> CGSize {
            let groups = [
                String(component.address.prefix(4)),
                String(component.address.dropFirst(4).prefix(2)) + String(component.address.suffix(6).prefix(2)),
                String(component.address.suffix(4))
            ]
            for index in 0 ..< self.labels.count {
                self.labels[index].text = groups[index]
                self.labels[index].textColor = component.textColor
                self.backgrounds[index].backgroundColor = component.backgroundColor
            }
            self.accessibilityLabel = component.address

            let contentSize = CGSize(width: 152.0, height: 22.0)
            let scale = min(1.0, max(0.0, availableSize.width) / contentSize.width)
            let size = CGSize(width: contentSize.width * scale, height: contentSize.height * scale)
            self.contentView.isHidden = scale == 0.0
            self.contentView.bounds = CGRect(origin: .zero, size: contentSize)
            self.contentView.center = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
            self.contentView.transform = scale == 0.0 ? .identity : CGAffineTransform(scaleX: scale, y: scale)
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize)
    }
}

private final class WalletTransactionGramIconComponent: Component {
    let isPending: Bool
    let pendingColor: UIColor
    let tintColor: UIColor?

    init(isPending: Bool, pendingColor: UIColor, tintColor: UIColor?) {
        self.isPending = isPending
        self.pendingColor = pendingColor
        self.tintColor = tintColor
    }

    static func ==(lhs: WalletTransactionGramIconComponent, rhs: WalletTransactionGramIconComponent) -> Bool {
        return lhs.isPending == rhs.isPending
            && lhs.pendingColor == rhs.pendingColor
            && lhs.tintColor == rhs.tintColor
    }

    final class View: UIView {
        private let iconImage = UIImage(bundleImageName: "Wallet/TransactionGram")?.withRenderingMode(.alwaysOriginal)
        private let iconView = UIImageView()
        private let pendingContainer = UIView()
        private let pendingIconView = UIImageView()
        private let highlightView = UIImageView()
        private var component: WalletTransactionGramIconComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.addSubview(self.iconView)
            self.addSubview(self.pendingContainer)
            self.pendingContainer.addSubview(self.pendingIconView)
            self.pendingContainer.addSubview(self.highlightView)
            self.highlightView.image = UIImage(bundleImageName: "Wallet/TransactionGramHighlight")?.withRenderingMode(.alwaysOriginal)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletTransactionGramIconComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let transition: ComponentTransition = self.component == nil ? .immediate : transition
            if self.component == nil || self.component?.tintColor != component.tintColor {
                if let tintColor = component.tintColor {
                    self.iconView.image = generateTintedImage(image: self.iconImage, color: tintColor)
                } else {
                    self.iconView.image = self.iconImage
                }
            }
            if self.component?.pendingColor != component.pendingColor {
                self.pendingIconView.image = generateTintedImage(image: self.iconImage, color: component.pendingColor)
            }
            self.component = component

            let size = CGSize(width: min(18.0, availableSize.width), height: min(18.0, availableSize.height))
            let frame = CGRect(origin: .zero, size: size)
            self.iconView.frame = frame
            self.pendingContainer.frame = frame
            self.pendingIconView.frame = frame
            self.highlightView.frame = frame

            if case .none = transition.animation {
                self.pendingContainer.layer.removeAnimation(forKey: "opacity")
            }
            transition.setAlpha(view: self.pendingContainer, alpha: component.isPending ? 1.0 : 0.0)
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class WalletTransactionServiceIconComponent: Component {
    let iconName: String

    init(iconName: String) {
        self.iconName = iconName
    }

    static func ==(lhs: WalletTransactionServiceIconComponent, rhs: WalletTransactionServiceIconComponent) -> Bool {
        return lhs.iconName == rhs.iconName
    }

    final class View: UIView {
        private let backgroundView = UIImageView()
        private let iconView = UIImageView()

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.iconView.contentMode = .scaleAspectFit
            self.addSubview(self.backgroundView)
            self.addSubview(self.iconView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletTransactionServiceIconComponent) -> CGSize {
            let size = CGSize(width: 40.0, height: 40.0)
            let isBlue = component.iconName == "Wallet/TransactionCard" || component.iconName == "Wallet/TransactionWalt"
            self.backgroundView.image = generateGradientFilledCircleImage(
                diameter: size.width,
                colors: [
                    UIColor(rgb: isBlue ? 0x2a9ef1 : 0x9aa0ac).cgColor,
                    UIColor(rgb: isBlue ? 0x72d5fd : 0xb8bdc7).cgColor
                ] as NSArray,
                direction: .vertical
            )
            self.iconView.image = generateTintedImage(
                image: UIImage(bundleImageName: component.iconName),
                color: .white
            )
            self.backgroundView.frame = CGRect(origin: .zero, size: size)
            let iconInset: CGFloat = isBlue ? 5.0 : 7.0
            self.iconView.frame = CGRect(origin: .zero, size: size).insetBy(dx: iconInset, dy: iconInset)
            return size
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(component: self)
    }
}

public final class WalletTransactionItemComponent: Component {
    public struct Content: Equatable {
        public let avatar: AnyComponent<Empty>?
        public let title: AnyComponent<Empty>
        public let subtitle: AnyComponent<Empty>?
        public let trailingContent: AnyComponent<Empty>?
        public let additionalContent: AnyComponent<Empty>?
        public let minimumHeight: CGFloat
        public let insets: UIEdgeInsets
        public let spacing: CGFloat

        public init(
            avatar: AnyComponent<Empty>?,
            title: AnyComponent<Empty>,
            subtitle: AnyComponent<Empty>? = nil,
            trailingContent: AnyComponent<Empty>? = nil,
            additionalContent: AnyComponent<Empty>? = nil,
            minimumHeight: CGFloat = 56.0,
            insets: UIEdgeInsets = UIEdgeInsets(top: 8.0, left: 0.0, bottom: 8.0, right: 0.0),
            spacing: CGFloat = 12.0
        ) {
            self.avatar = avatar
            self.title = title
            self.subtitle = subtitle
            self.trailingContent = trailingContent
            self.additionalContent = additionalContent
            self.minimumHeight = minimumHeight
            self.insets = insets
            self.spacing = spacing
        }
    }

    public let context: AccountContext
    public let theme: PresentationTheme
    public let strings: PresentationStrings
    public let dateTimeFormat: PresentationDateTimeFormat
    public let transaction: WalletContext.Transaction?
    public let walletAddress: String?
    public let content: Content?
    public let animatesPendingTransfer: Bool

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        transaction: WalletContext.Transaction,
        walletAddress: String? = nil,
        animatesPendingTransfer: Bool = false
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.transaction = transaction
        self.walletAddress = walletAddress
        self.content = nil
        self.animatesPendingTransfer = animatesPendingTransfer
    }

    public init(
        context: AccountContext,
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        content: Content
    ) {
        self.context = context
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.transaction = nil
        self.walletAddress = nil
        self.content = content
        self.animatesPendingTransfer = false
    }

    public static func ==(lhs: WalletTransactionItemComponent, rhs: WalletTransactionItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.transaction != rhs.transaction {
            return false
        }
        if lhs.walletAddress != rhs.walletAddress {
            return false
        }
        if lhs.animatesPendingTransfer != rhs.animatesPendingTransfer {
            return false
        }
        if lhs.content != rhs.content {
            return false
        }
        return true
    }

    public final class View: UIView {
        private let avatarContainer = UIView()
        private var avatarMask: UIView?
        private var avatarMaskCutout: UIView?
        private let avatar = ComponentView<Empty>()
        private let serviceIcon = ComponentView<Empty>()
        private var activityIndicatorBackground: UIView?
        private var activityIndicator: ActivityIndicator?
        private let title = ComponentView<Empty>()
        private let addressTitle = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private let date = ComponentView<Empty>()
        private let amount = ComponentView<Empty>()
        private let amountIcon = ComponentView<Empty>()
        private let collectibleBackground = ComponentView<Empty>()
        private let collectibleImage = ComponentView<Empty>()
        private let collectibleTitle = ComponentView<Empty>()
        private let collectibleSubtitle = ComponentView<Empty>()
        private let customAvatar = ComponentView<Empty>()
        private let customTitle = ComponentView<Empty>()
        private let customSubtitle = ComponentView<Empty>()
        private let customTrailingContent = ComponentView<Empty>()
        private let customAdditionalContent = ComponentView<Empty>()

        private var component: WalletTransactionItemComponent?
        private var transferPresentation: (expansion: CGFloat, iconAlpha: CGFloat, iconScale: CGFloat, clockAlpha: CGFloat, time: Double)?
        private var pendingClock: UIView?
        private var pendingStatus: UILabel?
        private let clockMinute = CALayer()
        private let clockHour = CALayer()

        public var transferIconFrame: CGRect {
            guard let view = self.amountIcon.view else { return .zero }
            return CGRect(x: view.center.x - view.bounds.width * 0.5, y: view.center.y - view.bounds.height * 0.5, width: view.bounds.width, height: view.bounds.height)
        }

        public func applyTransferPresentation(expansion: CGFloat, iconAlpha: CGFloat, iconScale: CGFloat, clockAlpha: CGFloat, time: Double) {
            self.transferPresentation = (expansion, iconAlpha, iconScale, clockAlpha, time)
            guard self.component?.animatesPendingTransfer == true else { return }
            if let view = self.amount.view {
                let scale = 1.0 + 0.33 * expansion
                view.transform = CGAffineTransform(a: scale, b: 0.0, c: 0.0, d: scale,
                    tx: -23.0 * expansion - (scale - 1.0) * view.bounds.width * 0.5, ty: 20.35 * expansion)
            }
            self.amountIcon.view?.alpha = iconAlpha
            self.amountIcon.view?.transform = CGAffineTransform(scaleX: max(0.001, iconScale), y: max(0.001, iconScale))
            if clockAlpha > 0.0 && self.pendingClock == nil {
                let clock = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 17.0, height: 17.0))
                clock.isUserInteractionEnabled = false
                clock.accessibilityElementsHidden = true
                clock.layer.cornerRadius = 8.5
                let ring = CAShapeLayer()
                ring.path = UIBezierPath(ovalIn: CGRect(x: 2.9, y: 2.9, width: 11.2, height: 11.2)).cgPath
                ring.fillColor = nil
                ring.strokeColor = UIColor(rgb: 0x30a1f5).cgColor
                ring.lineWidth = 1.3
                clock.layer.addSublayer(ring)
                for (hand, length) in [(self.clockMinute, 5.6 * 0.62), (self.clockHour, 5.6 * 0.42)] {
                    hand.backgroundColor = UIColor(rgb: 0x30a1f5).cgColor
                    hand.bounds = CGRect(x: 0.0, y: 0.0, width: length + 1.3, height: 1.3)
                    hand.anchorPoint = CGPoint(x: 0.65 / (length + 1.3), y: 0.5)
                    hand.position = CGPoint(x: 8.5, y: 8.5)
                    hand.cornerRadius = 0.65
                    clock.layer.addSublayer(hand)
                }
                self.addSubview(clock)
                self.pendingClock = clock
                let status = UILabel()
                status.font = Font.regular(14.0)
                self.addSubview(status)
                self.pendingStatus = status
            }
            if let status = self.pendingStatus, let component = self.component {
                if status.text != component.strings.VoiceOver_Chat_Sending { status.text = component.strings.VoiceOver_Chat_Sending }
                if status.textColor != component.theme.list.itemSecondaryTextColor { status.textColor = component.theme.list.itemSecondaryTextColor }
                let frame = self.date.view?.frame ?? .zero
                if status.frame != frame { status.frame = frame }
            }
            self.pendingStatus?.alpha = clockAlpha
            self.date.view?.alpha = 1.0 - clockAlpha
            self.pendingClock?.backgroundColor = self.component?.theme.list.itemBlocksBackgroundColor
            self.pendingClock?.center = CGPoint(x: self.avatarContainer.frame.maxX - 5.5, y: self.avatarContainer.frame.maxY - 5.5)
            self.pendingClock?.alpha = clockAlpha
            self.clockMinute.setAffineTransform(CGAffineTransform(rotationAngle: time * 4.2))
            self.clockHour.setAffineTransform(CGAffineTransform(rotationAngle: time * 4.2 / 12.0 - .pi / 2.0))
        }

        public func resetTransferPresentation() {
            self.transferPresentation = nil
            self.amount.view?.transform = .identity
            self.amountIcon.view?.transform = .identity
            self.amountIcon.view?.alpha = 1.0
            self.pendingClock?.removeFromSuperview()
            self.pendingClock = nil
            self.pendingStatus?.removeFromSuperview()
            self.pendingStatus = nil
            self.date.view?.alpha = 1.0
        }

        override public init(frame: CGRect) {
            super.init(frame: frame)

            self.isUserInteractionEnabled = false
            self.avatarContainer.isUserInteractionEnabled = false
            self.addSubview(self.avatarContainer)
        }

        required public init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setTransactionContentHidden(_ hidden: Bool) {
            self.avatarContainer.isHidden = hidden
            self.serviceIcon.view?.isHidden = hidden
            self.activityIndicatorBackground?.isHidden = hidden
            self.activityIndicator?.view.isHidden = hidden
            self.title.view?.isHidden = hidden
            self.addressTitle.view?.isHidden = hidden
            self.subtitle.view?.isHidden = hidden
            self.date.view?.isHidden = hidden
            self.amount.view?.isHidden = hidden
            self.amountIcon.view?.isHidden = hidden
            self.collectibleBackground.view?.isHidden = hidden
            self.collectibleImage.view?.isHidden = hidden
            self.collectibleTitle.view?.isHidden = hidden
            self.collectibleSubtitle.view?.isHidden = hidden
        }

        private func setCustomContentHidden(_ hidden: Bool) {
            self.customAvatar.view?.isHidden = hidden
            self.customTitle.view?.isHidden = hidden
            self.customSubtitle.view?.isHidden = hidden
            self.customTrailingContent.view?.isHidden = hidden
            self.customAdditionalContent.view?.isHidden = hidden
        }

        private func updateCustomContent(
            content: Content,
            availableSize: CGSize,
            state: EmptyComponentState,
            transition: ComponentTransition
        ) -> CGSize {
            self.setTransactionContentHidden(true)
            self.setCustomContentHidden(false)

            let contentWidth = max(0.0, availableSize.width - content.insets.left - content.insets.right)
            let avatarSize: CGSize
            if let avatar = content.avatar {
                self.customAvatar.parentState = state
                avatarSize = self.customAvatar.update(
                    transition: transition,
                    component: avatar,
                    environment: {},
                    containerSize: CGSize(width: contentWidth, height: 1000.0)
                )
            } else {
                avatarSize = .zero
            }

            let mainOriginX = content.insets.left + (avatarSize.width > 0.0 ? avatarSize.width + content.spacing : 0.0)
            let mainWidth = max(0.0, availableSize.width - mainOriginX - content.insets.right)

            let trailingSize: CGSize
            if let trailingContent = content.trailingContent {
                self.customTrailingContent.parentState = state
                trailingSize = self.customTrailingContent.update(
                    transition: transition,
                    component: trailingContent,
                    environment: {},
                    containerSize: CGSize(width: mainWidth * 0.5, height: 1000.0)
                )
            } else {
                trailingSize = .zero
            }

            let titleTrailingSpacing: CGFloat = trailingSize.width > 0.0 ? 12.0 : 0.0
            let titleWidth = max(0.0, mainWidth - trailingSize.width - titleTrailingSpacing)
            self.customTitle.parentState = state
            let titleSize = self.customTitle.update(
                transition: transition,
                component: content.title,
                environment: {},
                containerSize: CGSize(width: titleWidth, height: 1000.0)
            )

            let subtitleSize: CGSize
            if let subtitle = content.subtitle {
                self.customSubtitle.parentState = state
                subtitleSize = self.customSubtitle.update(
                    transition: transition,
                    component: subtitle,
                    environment: {},
                    containerSize: CGSize(width: mainWidth, height: 1000.0)
                )
            } else {
                subtitleSize = .zero
            }

            let additionalSize: CGSize
            if let additionalContent = content.additionalContent {
                self.customAdditionalContent.parentState = state
                additionalSize = self.customAdditionalContent.update(
                    transition: transition,
                    component: additionalContent,
                    environment: {},
                    containerSize: CGSize(width: mainWidth, height: 1000.0)
                )
            } else {
                additionalSize = .zero
            }

            var mainHeight = titleSize.height
            if subtitleSize.height > 0.0 {
                mainHeight += 1.0 + subtitleSize.height
            }
            if additionalSize.height > 0.0 {
                mainHeight += 8.0 + additionalSize.height
            }
            let innerHeight = max(avatarSize.height, max(mainHeight, trailingSize.height))
            let height = max(content.minimumHeight, content.insets.top + innerHeight + content.insets.bottom)

            let avatarOriginY: CGFloat
            let mainOriginY: CGFloat
            let trailingOriginY: CGFloat
            if additionalSize.height == 0.0 {
                let availableInnerHeight = max(0.0, height - content.insets.top - content.insets.bottom)
                avatarOriginY = content.insets.top + floorToScreenPixels((availableInnerHeight - avatarSize.height) * 0.5)
                mainOriginY = content.insets.top + floorToScreenPixels((availableInnerHeight - mainHeight) * 0.5)
                trailingOriginY = content.insets.top + floorToScreenPixels((availableInnerHeight - trailingSize.height) * 0.5)
            } else {
                avatarOriginY = content.insets.top
                mainOriginY = content.insets.top
                trailingOriginY = content.insets.top
            }

            if let avatarView = self.customAvatar.view {
                if avatarView.superview == nil {
                    self.addSubview(avatarView)
                }
                avatarView.isHidden = content.avatar == nil
                transition.setFrame(
                    view: avatarView,
                    frame: CGRect(
                        x: content.insets.left,
                        y: avatarOriginY,
                        width: avatarSize.width,
                        height: avatarSize.height
                    )
                )
            }
            if let titleView = self.customTitle.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(x: mainOriginX, y: mainOriginY, width: titleSize.width, height: titleSize.height)
                )
            }
            var mainContentY = mainOriginY + titleSize.height
            if let subtitleView = self.customSubtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                subtitleView.isHidden = content.subtitle == nil
                if subtitleSize.height > 0.0 {
                    mainContentY += 1.0
                }
                transition.setFrame(
                    view: subtitleView,
                    frame: CGRect(x: mainOriginX, y: mainContentY, width: subtitleSize.width, height: subtitleSize.height)
                )
                mainContentY += subtitleSize.height
            }
            if let trailingView = self.customTrailingContent.view {
                if trailingView.superview == nil {
                    self.addSubview(trailingView)
                }
                trailingView.isHidden = content.trailingContent == nil
                transition.setFrame(
                    view: trailingView,
                    frame: CGRect(
                        x: availableSize.width - content.insets.right - trailingSize.width,
                        y: trailingOriginY,
                        width: trailingSize.width,
                        height: trailingSize.height
                    )
                )
            }
            if let additionalView = self.customAdditionalContent.view {
                if additionalView.superview == nil {
                    self.addSubview(additionalView)
                }
                additionalView.isHidden = content.additionalContent == nil
                if additionalSize.height > 0.0 {
                    mainContentY += 8.0
                }
                transition.setFrame(
                    view: additionalView,
                    frame: CGRect(x: mainOriginX, y: mainContentY, width: additionalSize.width, height: additionalSize.height)
                )
            }

            return CGSize(width: availableSize.width, height: height)
        }

        func update(
            component: WalletTransactionItemComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<Empty>,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component
            self.amount.view?.transform = .identity
            self.amountIcon.view?.transform = .identity
            if !component.animatesPendingTransfer { self.resetTransferPresentation() }

            if let content = component.content {
                return self.updateCustomContent(
                    content: content,
                    availableSize: availableSize,
                    state: state,
                    transition: transition
                )
            }
            guard let transaction = component.transaction else {
                return CGSize(width: availableSize.width, height: 0.0)
            }
            self.setTransactionContentHidden(false)
            self.setCustomContentHidden(true)

            let isDeployContract = transaction.kind == .deployContract
            let isKeyChange = transaction.kind == .keyChange
            let isServiceTransaction = isDeployContract || isKeyChange
            let serviceIconName: String?
            if isKeyChange {
                serviceIconName = "Wallet/TransactionKey"
            } else if isDeployContract {
                serviceIconName = "Chat List/Tabs/IconSettings"
            } else if case let .onramp(_, _, provider) = transaction.peer {
                switch provider {
                case "MoonPay":
                    serviceIconName = "Wallet/TransactionCard"
                case "Walt":
                    serviceIconName = "Wallet/TransactionWalt"
                default:
                    serviceIconName = nil
                }
            } else {
                serviceIconName = nil
            }
            let isSelfTransfer = transaction.isSelfTransfer(walletAddress: component.walletAddress)
            let displayedDirection: WalletContext.Transaction.Direction = isSelfTransfer ? .incoming : transaction.direction
            let displayedAmount = isSelfTransfer ? abs(transaction.amount) : transaction.amount
            var subtitleText: String
            var amountValue: Int64
            var amountPrefix: String = ""
            var amountColor: UIColor
            var amountIconColor: UIColor?
            var avatarPeer: StarsAvatarComponent.Peer?
            if isKeyChange {
                subtitleText = component.strings.Wallet_Transaction_KeyUpdate
                amountValue = -(abs(transaction.amount) + transaction.fee)
                amountColor = component.theme.list.itemPrimaryTextColor
                amountIconColor = nil
                avatarPeer = nil
            } else if isDeployContract {
                subtitleText = component.strings.Wallet_Transaction_DeployContract
                amountValue = 0
                amountColor = component.theme.list.itemPrimaryTextColor
                amountIconColor = nil
                avatarPeer = nil
            } else {
                switch displayedDirection {
                case .incoming:
                    if transaction.collectible != nil {
                        subtitleText = component.strings.Wallet_Transaction_IncomingCollectible
                    } else {
                        if case .user = transaction.peer {
                            subtitleText = component.strings.Wallet_Transaction_IncomingTransfer
                        } else {
                            subtitleText = component.strings.Wallet_Transaction_Deposit
                        }
                    }
                    amountValue = displayedAmount
                    if transaction.currency == .usdt {
                        amountColor = UIColor(rgb: 0x0B9696)
                    } else {
                        amountColor = component.theme.list.itemDisclosureActions.constructive.fillColor
                    }
                    amountIconColor = transaction.collectible != nil ? amountColor : nil
                    avatarPeer = .transaction(.incoming)
                case .outgoing:
                    if transaction.collectible != nil {
                        subtitleText = component.strings.Wallet_Transaction_OutgoingCollectible
                    } else {
                        if case .user = transaction.peer {
                            subtitleText = component.strings.Wallet_Transaction_OutgoingTransfer
                        } else {
                            subtitleText = component.strings.Wallet_Transaction_Withdrawal
                        }
                    }
                    amountValue = displayedAmount
                    amountColor = component.theme.list.itemPrimaryTextColor
                    amountIconColor = transaction.collectible != nil
                        ? component.theme.list.itemSecondaryTextColor
                        : nil
                    avatarPeer = .transaction(.outgoing)
                case .unknown:
                    subtitleText = ""
                    amountValue = displayedAmount
                    amountColor = component.theme.list.itemPrimaryTextColor
                    amountIconColor = nil
                    avatarPeer = nil
                }
                if case let .onramp(_, _, providerName) = transaction.peer {
                    subtitleText = providerName
                }
            }
            if !isServiceTransaction, case let .user(peer, _, _) = transaction.peer {
                avatarPeer = .transactionPeer(.peer(peer))
            }
            
            if amountValue > 0 {
                amountPrefix = "+"
            } else {
                amountValue *= -1
                amountPrefix = "–"
            }

            let isPending = transaction.status == .pending
                && transaction.collectible == nil
                && !isServiceTransaction
            if isPending && !component.animatesPendingTransfer {
                amountColor = component.theme.list.itemSecondaryTextColor
                amountIconColor = component.theme.list.itemSecondaryTextColor
            }
            if transaction.status == .failed {
                subtitleText = component.strings.Wallet_Transaction_Failed
                amountColor = component.theme.list.itemDestructiveColor
                amountIconColor = component.theme.list.itemDestructiveColor
            }

            let avatarSize = CGSize(width: 40.0, height: 40.0)
            let avatarFrame = CGRect(origin: CGPoint(x: -4.0, y: 2.0), size: avatarSize)
            if let serviceIconName {
                self.avatarContainer.isHidden = false
                self.avatar.view?.isHidden = true
                self.serviceIcon.parentState = state
                let _ = self.serviceIcon.update(
                    transition: transition,
                    component: AnyComponent(WalletTransactionServiceIconComponent(
                        iconName: serviceIconName
                    )),
                    environment: {},
                    containerSize: avatarSize
                )
                if let serviceIconView = self.serviceIcon.view {
                    if serviceIconView.superview == nil {
                        serviceIconView.isUserInteractionEnabled = false
                        self.avatarContainer.addSubview(serviceIconView)
                    }
                    serviceIconView.isHidden = false
                    transition.setFrame(view: self.avatarContainer, frame: avatarFrame)
                    transition.setFrame(view: serviceIconView, frame: CGRect(origin: .zero, size: avatarSize))
                }
            } else if let avatarPeer {
                self.serviceIcon.view?.isHidden = true
                self.avatarContainer.isHidden = false
                self.avatar.parentState = state
                let _ = self.avatar.update(
                    transition: transition,
                    component: AnyComponent(StarsAvatarComponent(
                        context: component.context,
                        theme: component.theme,
                        peer: avatarPeer,
                        photo: nil,
                        media: [],
                        gift: nil,
                        backgroundColor: .clear,
                        size: avatarSize
                    )),
                    environment: {},
                    containerSize: avatarSize
                )
                if let avatarView = self.avatar.view {
                    avatarView.isHidden = false
                    if avatarView.superview == nil {
                        self.avatarContainer.addSubview(avatarView)
                    }
                    transition.setFrame(view: self.avatarContainer, frame: avatarFrame)
                    transition.setFrame(
                        view: avatarView,
                        frame: CGRect(origin: CGPoint(), size: avatarSize)
                    )
                }
            } else {
                self.serviceIcon.view?.isHidden = true
                self.avatarContainer.isHidden = true
            }

            if isPending && !component.animatesPendingTransfer, avatarPeer != nil || serviceIconName != nil {
                let backgroundDiameter: CGFloat = 14.0
                let indicatorDiameter: CGFloat = 9.0
                let circlePoint = CGPoint(
                    x: avatarSize.width / 2.0 + cos(CGFloat.pi / 4.0) * avatarSize.width / 2.0 + 1.0,
                    y: avatarSize.height / 2.0 - sin(CGFloat.pi / 4.0) * avatarSize.height / 2.0 - 1.0
                )
                let backgroundFrame = CGRect(
                    x: circlePoint.x - backgroundDiameter / 2.0,
                    y: circlePoint.y - backgroundDiameter / 2.0,
                    width: backgroundDiameter,
                    height: backgroundDiameter
                )
                let indicatorFrame = CGRect(
                    x: backgroundFrame.midX - indicatorDiameter / 2.0,
                    y: backgroundFrame.midY - indicatorDiameter / 2.0,
                    width: indicatorDiameter,
                    height: indicatorDiameter
                )

                let avatarMask: UIView
                let avatarMaskCutout: UIView
                if let currentAvatarMask = self.avatarMask, let currentAvatarMaskCutout = self.avatarMaskCutout {
                    avatarMask = currentAvatarMask
                    avatarMaskCutout = currentAvatarMaskCutout
                } else {
                    avatarMask = UIView()
                    avatarMask.backgroundColor = .white
                    if let filter = CALayer.luminanceToAlpha() {
                        avatarMask.layer.filters = [filter]
                    }
                    avatarMaskCutout = UIView()
                    avatarMaskCutout.backgroundColor = .black
                    avatarMask.addSubview(avatarMaskCutout)
                    self.avatarMask = avatarMask
                    self.avatarMaskCutout = avatarMaskCutout
                }
                avatarMask.frame = CGRect(origin: CGPoint(), size: avatarSize)
                avatarMaskCutout.frame = backgroundFrame.insetBy(dx: -2.0, dy: -2.0)
                avatarMaskCutout.layer.cornerRadius = avatarMaskCutout.bounds.width / 2.0
                self.avatarContainer.mask = avatarMask

                let activityIndicatorBackground: UIView
                if let current = self.activityIndicatorBackground {
                    activityIndicatorBackground = current
                } else {
                    activityIndicatorBackground = UIView()
                    activityIndicatorBackground.isUserInteractionEnabled = false
                    self.activityIndicatorBackground = activityIndicatorBackground
                    self.addSubview(activityIndicatorBackground)
                }
                activityIndicatorBackground.backgroundColor = component.theme.list.itemSecondaryTextColor
                activityIndicatorBackground.layer.cornerRadius = backgroundDiameter / 2.0
                activityIndicatorBackground.frame = backgroundFrame.offsetBy(
                    dx: avatarFrame.minX,
                    dy: avatarFrame.minY
                )

                let activityIndicator: ActivityIndicator
                if let current = self.activityIndicator {
                    activityIndicator = current
                } else {
                    activityIndicator = ActivityIndicator(
                        type: .custom(
                            .white,
                            indicatorDiameter,
                            1.5,
                            true
                        ),
                        speed: .slow
                    )
                    activityIndicator.isUserInteractionEnabled = false
                    self.activityIndicator = activityIndicator
                    self.addSubview(activityIndicator.view)
                }
                activityIndicator.type = .custom(
                    .white,
                    indicatorDiameter,
                    1.5,
                    true
                )
                activityIndicator.frame = indicatorFrame.offsetBy(
                    dx: avatarFrame.minX,
                    dy: avatarFrame.minY
                )
            } else {
                let avatarMask = self.avatarMask
                let avatarMaskCutout = self.avatarMaskCutout
                let activityIndicatorBackground = self.activityIndicatorBackground
                let activityIndicatorView = self.activityIndicator?.view

                self.avatarMask = nil
                self.avatarMaskCutout = nil
                self.activityIndicatorBackground = nil
                self.activityIndicator = nil

                if transition.animation.isImmediate {
                    if self.avatarContainer.mask === avatarMask {
                        self.avatarContainer.mask = nil
                    }
                    avatarMaskCutout?.removeFromSuperview()
                    activityIndicatorBackground?.removeFromSuperview()
                    activityIndicatorView?.removeFromSuperview()
                } else {
                    if let avatarMask, let avatarMaskCutout {
                        transition.setScale(view: avatarMaskCutout, scale: 0.001, completion: { [weak self, weak avatarMask, weak avatarMaskCutout] _ in
                            guard let self else {
                                return
                            }
                            if self.avatarContainer.mask === avatarMask {
                                self.avatarContainer.mask = nil
                            }
                            avatarMaskCutout?.removeFromSuperview()
                        })
                    }
                    if let activityIndicatorBackground {
                        transition.setScale(view: activityIndicatorBackground, scale: 0.001)
                        transition.setAlpha(view: activityIndicatorBackground, alpha: 0.0, completion: { [weak activityIndicatorBackground] _ in
                            activityIndicatorBackground?.removeFromSuperview()
                        })
                    }
                    if let activityIndicatorView {
                        transition.setScale(view: activityIndicatorView, scale: 0.001)
                        transition.setAlpha(view: activityIndicatorView, alpha: 0.0, completion: { [weak activityIndicatorView] _ in
                            activityIndicatorView?.removeFromSuperview()
                        })
                    }
                }
            }

            let textOriginX: CGFloat = 46.0
            let textAvailableWidth = max(0.0, availableSize.width - textOriginX)

            let amountText: String
            let amountIconName: String
            if transaction.collectible != nil {
                amountText = (displayedDirection == .incoming ? "+" : "–") + component.strings.Wallet_Transaction_ItemCount(1)
                amountIconName = "Wallet/TransactionCollectible"
            } else if transaction.currency == .ton {
                amountText = amountPrefix + formatTonAmountText(
                    amountValue,
                    dateTimeFormat: component.dateTimeFormat,
                    showPlus: false,
                    maxDecimalPositions: isKeyChange ? 5 : 3
                )
                amountIconName = "Wallet/TransactionGram"
            } else {
                amountText = amountPrefix + formatWalletTokenAmountText(
                    amountValue,
                    decimalDigits: 6,
                    dateTimeFormat: component.dateTimeFormat,
                    showPlus: false,
                    maxDecimalPositions: 2
                )
                amountIconName = "Wallet/TransactionUsdt"
            }
            let amountAttributedText = tonAmountAttributedString(
                amountText,
                integralFont: Font.semibold(15.0),
                fractionalFont: Font.semibold(12.0),
                color: .white,
                decimalSeparator: component.dateTimeFormat.decimalSeparator
            )
            let amountIconComponent: AnyComponent<Empty>
            if transaction.collectible == nil && transaction.currency == .ton {
                amountIconComponent = AnyComponent(WalletTransactionGramIconComponent(
                    isPending: isPending && !component.animatesPendingTransfer,
                    pendingColor: component.theme.list.itemSecondaryTextColor,
                    tintColor: isPending ? nil : amountIconColor
                ))
            } else {
                amountIconComponent = AnyComponent(BundleIconComponent(
                    name: amountIconName,
                    tintColor: amountIconColor,
                    maxSize: CGSize(width: 18.0, height: 18.0)
                ))
            }
            let amountIconSize = self.amountIcon.update(
                transition: transition,
                component: amountIconComponent,
                environment: {},
                containerSize: CGSize(width: 18.0, height: 18.0)
            )
            let amountSize = self.amount.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(amountAttributedText),
                    maximumNumberOfLines: 1,
                    tintColor: amountColor
                )),
                environment: {},
                containerSize: CGSize(width: max(0.0, textAvailableWidth - amountIconSize.width - 3.0), height: 100.0)
            )

            let amountSpacing: CGFloat = 1.0
            let displaysAmount = !isDeployContract
            let amountContentWidth = displaysAmount ? amountSize.width + amountSpacing + amountIconSize.width : 0.0
            let titleToAmountSpacing: CGFloat = 12.0
            let titleAvailableWidth = max(
                0.0,
                textAvailableWidth - amountContentWidth - (displaysAmount ? titleToAmountSpacing : 0.0)
            )

            let peerTitle: String
            var titleAddress: String?
            switch transaction.peer {
            case let .user(peer, _, _):
                peerTitle = peer.debugDisplayTitle
            case let .address(address, domain):
                if let domain = domain?.trimmingCharacters(in: .whitespacesAndNewlines), !domain.isEmpty {
                    peerTitle = domain
                } else {
                    let address = WalletContext.transferAddress(from: address, preserveBounce: true) ?? address
                    peerTitle = walletTransactionCounterparty(address, strings: component.strings)
                    if address.count > 12 {
                        titleAddress = address
                    }
                }
            case let .onramp(_, _, provider):
                switch provider {
                case "MoonPay":
                    peerTitle = component.strings.Wallet_Transaction_CardTopUp
                default:
                    peerTitle = component.strings.Wallet_Transaction_CryptoTopUp
                }
            case .unsupported:
                peerTitle = walletTransactionCounterparty(nil, strings: component.strings)
            }
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: peerTitle,
                        font: Font.semibold(17.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: titleAvailableWidth, height: 100.0)
            )
            self.title.view?.isHidden = titleAddress != nil
            if let titleAddress {
                let addressTitleSize = self.addressTitle.update(
                    transition: transition,
                    component: AnyComponent(WalletTransactionAddressTitleComponent(
                        address: titleAddress,
                        textColor: component.theme.list.itemPrimaryTextColor,
                        backgroundColor: component.theme.list.itemSecondaryTextColor.withAlphaComponent(0.08)
                    )),
                    environment: {},
                    containerSize: CGSize(width: titleAvailableWidth, height: 100.0)
                )
                if let addressTitleView = self.addressTitle.view {
                    if addressTitleView.superview == nil {
                        self.addSubview(addressTitleView)
                    }
                    addressTitleView.isHidden = false
                    // Keep the original title's height so the amount, subtitle and date stay aligned.
                    transition.setFrame(
                        view: addressTitleView,
                        frame: CGRect(
                            origin: CGPoint(x: textOriginX, y: 2.0 + floorToScreenPixels((titleSize.height - addressTitleSize.height) * 0.5)),
                            size: addressTitleSize
                        )
                    )
                }
            } else {
                self.addressTitle.view?.isHidden = true
            }
            let subtitleSize = self.subtitle.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: subtitleText,
                        font: Font.regular(15.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textAvailableWidth, height: 100.0)
            )

            let dateComponents = getDateTimeComponents(timestamp: transaction.timestamp)
            let compactDate = stringForMediumCompactDate(
                timestamp: transaction.timestamp,
                strings: component.strings,
                dateTimeFormat: component.dateTimeFormat,
                withTime: false
            )
            let compactTime = stringForShortTimestamp(
                hours: dateComponents.hour,
                minutes: dateComponents.minutes,
                dateTimeFormat: component.dateTimeFormat
            )
            let dateText = component.strings.Time_MediumDate(compactDate, compactTime).string
            let dateSize = self.date.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: dateText,
                        font: Font.regular(14.0),
                        textColor: component.theme.list.itemSecondaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: textAvailableWidth, height: 100.0)
            )

            var contentHeight: CGFloat = 2.0
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(
                    view: titleView,
                    frame: CGRect(origin: CGPoint(x: textOriginX, y: contentHeight), size: titleSize)
                )
            }
            contentHeight += titleSize.height
            contentHeight += 2.0

            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                transition.setFrame(
                    view: subtitleView,
                    frame: CGRect(origin: CGPoint(x: textOriginX, y: contentHeight), size: subtitleSize)
                )
            }
            contentHeight += subtitleSize.height
            contentHeight += 4.0

            if let dateView = self.date.view {
                if dateView.superview == nil {
                    self.addSubview(dateView)
                }
                transition.setFrame(
                    view: dateView,
                    frame: CGRect(origin: CGPoint(x: textOriginX, y: contentHeight), size: dateSize)
                )
            }
            contentHeight += dateSize.height
            contentHeight += 1.0

            if let collectible = transaction.collectible {
                contentHeight += 8.0
                let collectibleImageSize = CGSize(width: 40.0, height: 40.0)
                let collectibleTextOriginX: CGFloat = 50.0
                let collectibleTextAvailableWidth = max(0.0, textAvailableWidth - collectibleTextOriginX - 8.0)
                let collectibleTitleSize = self.collectibleTitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: collectible.name,
                            font: Font.semibold(14.0),
                            textColor: component.theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: collectibleTextAvailableWidth, height: 100.0)
                )
                let collectibleTypeText: String
                switch collectible.kind {
                case .gift:
                    collectibleTypeText = component.strings.Wallet_Transaction_CollectibleGift
                case .username:
                    collectibleTypeText = component.strings.Wallet_Transaction_Username
                case .anonymousNumber:
                    collectibleTypeText = component.strings.Wallet_Transaction_AnonymousNumber
                case .other:
                    collectibleTypeText = component.strings.Wallet_Transaction_Collectible
                }
                let collectibleSubtitleSize = self.collectibleSubtitle.update(
                    transition: transition,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: collectibleTypeText,
                            font: Font.regular(13.0),
                            textColor: component.theme.list.itemSecondaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: collectibleTextAvailableWidth, height: 100.0)
                )
                let collectibleContentWidth = min(
                    textAvailableWidth,
                    collectibleTextOriginX + max(collectibleTitleSize.width, collectibleSubtitleSize.width) + 10.0
                )
                let collectibleFrame = CGRect(
                    x: textOriginX,
                    y: contentHeight,
                    width: collectibleContentWidth,
                    height: 44.0
                )
                let _ = self.collectibleBackground.update(
                    transition: transition,
                    component: AnyComponent(RoundedRectangle(
                        color: component.theme.list.itemSecondaryTextColor.withAlphaComponent(0.08),
                        cornerRadius: 10.0
                    )),
                    environment: {},
                    containerSize: collectibleFrame.size
                )
                if let collectibleBackgroundView = self.collectibleBackground.view {
                    if collectibleBackgroundView.superview == nil {
                        collectibleBackgroundView.isUserInteractionEnabled = false
                        self.addSubview(collectibleBackgroundView)
                    }
                    collectibleBackgroundView.isHidden = false
                    transition.setFrame(view: collectibleBackgroundView, frame: collectibleFrame)
                }

                let collectibleImageFrame = CGRect(
                    origin: CGPoint(x: collectibleFrame.minX + 2.0, y: collectibleFrame.minY + 2.0),
                    size: collectibleImageSize
                )
                let _ = self.collectibleImage.update(
                    transition: transition,
                    component: AnyComponent(WalletCollectibleImageComponent(
                        context: component.context,
                        file: collectible.thumbnail ?? collectible.image,
                        placeholderColor: component.theme.list.mediaPlaceholderColor,
                        cornerRadius: 8.0
                    )),
                    environment: {},
                    containerSize: collectibleImageSize
                )
                if let collectibleImageView = self.collectibleImage.view {
                    if collectibleImageView.superview == nil {
                        collectibleImageView.isUserInteractionEnabled = false
                        self.addSubview(collectibleImageView)
                    }
                    collectibleImageView.isHidden = false
                    transition.setFrame(view: collectibleImageView, frame: collectibleImageFrame)
                }

                if let collectibleTitleView = self.collectibleTitle.view {
                    collectibleTitleView.isHidden = false
                    if collectibleTitleView.superview == nil {
                        self.addSubview(collectibleTitleView)
                    }
                    transition.setFrame(
                        view: collectibleTitleView,
                        frame: CGRect(
                            x: collectibleFrame.minX + collectibleTextOriginX,
                            y: collectibleFrame.minY + 5.0 + UIScreenPixel,
                            width: collectibleTitleSize.width,
                            height: collectibleTitleSize.height
                        )
                    )
                }
                if let collectibleSubtitleView = self.collectibleSubtitle.view {
                    collectibleSubtitleView.isHidden = false
                    if collectibleSubtitleView.superview == nil {
                        self.addSubview(collectibleSubtitleView)
                    }
                    transition.setFrame(
                        view: collectibleSubtitleView,
                        frame: CGRect(
                            x: collectibleFrame.minX + collectibleTextOriginX,
                            y: collectibleFrame.minY + 23.0,
                            width: collectibleSubtitleSize.width,
                            height: collectibleSubtitleSize.height
                        )
                    )
                }
                contentHeight += collectibleFrame.height
                contentHeight += 1.0
            } else {
                self.collectibleBackground.view?.isHidden = true
                if let collectibleImageView = self.collectibleImage.view {
                    let _ = self.collectibleImage.update(
                        transition: .immediate,
                        component: AnyComponent(WalletCollectibleImageComponent(
                            context: component.context,
                            file: nil,
                            placeholderColor: component.theme.list.mediaPlaceholderColor,
                            cornerRadius: 8.0
                        )),
                        environment: {},
                        containerSize: CGSize(width: 40.0, height: 40.0)
                    )
                    collectibleImageView.isHidden = true
                }
                self.collectibleTitle.view?.isHidden = true
                self.collectibleSubtitle.view?.isHidden = true
            }

            let amountOriginX = max(0.0, availableSize.width - amountContentWidth)
            let amountOriginY = floor((titleSize.height - amountSize.height) * 0.5)
            if let amountView = self.amount.view {
                if amountView.superview == nil {
                    self.addSubview(amountView)
                }
                amountView.isHidden = !displaysAmount
                transition.setFrame(
                    view: amountView,
                    frame: CGRect(origin: CGPoint(x: amountOriginX, y: amountOriginY), size: amountSize)
                )
            }
            if let amountIconView = self.amountIcon.view {
                if amountIconView.superview == nil {
                    self.addSubview(amountIconView)
                }
                amountIconView.isHidden = !displaysAmount
                transition.setFrame(
                    view: amountIconView,
                    frame: CGRect(
                        origin: CGPoint(
                            x: amountOriginX + amountSize.width + amountSpacing,
                            y: floorToScreenPixels(amountOriginY + (amountSize.height - amountIconSize.height) * 0.5) + UIScreenPixel
                        ),
                        size: amountIconSize
                    )
                )
            }

            if let presentation = self.transferPresentation, component.animatesPendingTransfer {
                self.applyTransferPresentation(expansion: presentation.expansion, iconAlpha: presentation.iconAlpha, iconScale: presentation.iconScale, clockAlpha: presentation.clockAlpha, time: presentation.time)
            }
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }

    public func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<Empty>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            component: self,
            availableSize: availableSize,
            state: state,
            environment: environment,
            transition: transition
        )
    }
}

private func walletTransactionCounterparty(_ address: String?, strings: PresentationStrings) -> String {
    guard let address, !address.isEmpty else {
        return strings.Wallet_Transaction_UnknownAddress
    }
    
    let edgeLength = 4
    guard address.count > edgeLength * 2 else {
        return address
    }
    return "\(address.prefix(edgeLength))…\(address.suffix(edgeLength))"
}

private func formatWalletTokenAmountText(
    _ value: Int64,
    decimalDigits: Int,
    dateTimeFormat: PresentationDateTimeFormat,
    showPlus: Bool,
    maxDecimalPositions: Int
) -> String {
    var digits = String(value.magnitude)
    while digits.count <= decimalDigits {
        digits.insert("0", at: digits.startIndex)
    }

    let fractionStart = digits.index(digits.endIndex, offsetBy: -decimalDigits)
    var integralPart = String(digits[..<fractionStart])
    var fractionalPart = String(digits[fractionStart...])
    while fractionalPart.last == "0" {
        fractionalPart.removeLast()
    }
    if fractionalPart.count > maxDecimalPositions {
        fractionalPart = String(fractionalPart.prefix(maxDecimalPositions))
    }

    if let integralValue = Int32(integralPart) {
        integralPart = presentationStringsFormattedNumber(integralValue, dateTimeFormat.groupingSeparator)
    }

    var result = integralPart
    if !fractionalPart.isEmpty {
        result.append(dateTimeFormat.decimalSeparator)
        result.append(fractionalPart)
    }
    if value < 0 {
        result.insert("-", at: result.startIndex)
    } else if showPlus {
        result.insert("+", at: result.startIndex)
    }
    return result
}
