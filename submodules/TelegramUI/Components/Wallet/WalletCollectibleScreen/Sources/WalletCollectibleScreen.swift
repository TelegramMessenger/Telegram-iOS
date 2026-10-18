import Foundation
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import PresentationDataUtils
import TelegramStringFormatting
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import MultilineTextComponent
import BalancedTextComponent
import ButtonComponent
import GlassControls
import CheckComponent
import PlainButtonComponent
import TableComponent
import AvatarComponent
import ContextUI
import TextFormat
import TooltipUI
import UndoUI
import WalletContext
import WalletPagerComponent
import WalletCollectibleHeaderComponent
import GiftAnimationComponent
import GlassBackgroundComponent
import WalletPeerSelectionScreen
import WalletAuthorizationUI
import PasscodeCore
import GiftViewScreen

private func walletCollectibleRarityText(_ rarity: StarGift.UniqueGift.Attribute.Rarity?, strings: PresentationStrings) -> String {
    guard let rarity else {
        return "—"
    }
    switch rarity {
    case let .permille(value):
        if value == 0 {
            return "<0.1%"
        }
        let percentage = Float(value) * 0.1
        return String(format: "%0.1f", percentage)
            .replacingOccurrences(of: ".0", with: "")
            .replacingOccurrences(of: ",0", with: "") + "%"
    case .rare:
        return strings.Gift_Attribute_Rare.capitalized
    case .epic:
        return strings.Gift_Attribute_Epic.capitalized
    case .legendary:
        return strings.Gift_Attribute_Legendary.capitalized
    case .uncommon:
        return strings.Gift_Attribute_Uncommon.capitalized
    }
}

private func walletCollectibleExplorerUrl(explorerUrl: String, address: String) -> String? {
    guard let address = WalletContext.transferAddress(from: address, preserveBounce: true),
          let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
          !encodedAddress.isEmpty else {
        return nil
    }
    let baseUrl = explorerUrl.hasSuffix("/") ? explorerUrl : explorerUrl + "/"
    return "\(baseUrl)\(encodedAddress)"
}

private func walletCollectibleFragmentUrl(collectible: WalletContext.Collectible) -> String? {
    let path: String
    let value: String
    switch collectible.kind {
    case .username:
        path = "username"
        var username = collectible.name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        if username.lowercased().hasSuffix(".t.me") {
            username.removeLast(".t.me".count)
        }
        value = username
    case .anonymousNumber:
        path = "number"
        value = collectible.name.filter { $0.isNumber }
    case .gift:
        guard let giftSlug = collectible.giftSlug else {
            return nil
        }
        path = "gift"
        value = giftSlug
    case .other:
        return nil
    }
    guard !value.isEmpty else {
        return nil
    }
    var allowedCharacters = CharacterSet.urlPathAllowed
    allowedCharacters.remove(charactersIn: "/?#%")
    guard let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowedCharacters) else {
        return nil
    }
    return "https://fragment.com/\(path)/\(encodedValue)"
}

private final class WalletCollectibleActionComponent: Component {
    typealias EnvironmentType = Empty

    let theme: PresentationTheme
    let title: String
    let iconName: String
    let action: () -> Void

    init(theme: PresentationTheme, title: String, iconName: String, action: @escaping () -> Void) {
        self.theme = theme
        self.title = title
        self.iconName = iconName
        self.action = action
    }

    static func ==(lhs: WalletCollectibleActionComponent, rhs: WalletCollectibleActionComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.title == rhs.title && lhs.iconName == rhs.iconName
    }

    final class View: UIView {
        private let backgroundView = UIView()
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let button = HighlightTrackingButton()
        private var component: WalletCollectibleActionComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)

            self.backgroundView.isUserInteractionEnabled = false
            self.backgroundView.layer.cornerRadius = 16.0
            self.addSubview(self.backgroundView)
            self.addSubview(self.button)
            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
            self.button.highligthedChanged = { [weak self] highlighted in
                self?.backgroundView.alpha = highlighted ? 0.55 : 1.0
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            self.component?.action()
        }

        func update(
            component: WalletCollectibleActionComponent,
            availableSize: CGSize,
            transition: ComponentTransition
        ) -> CGSize {
            self.component = component
            let size = CGSize(width: availableSize.width, height: 58.0)
            self.backgroundView.backgroundColor = component.theme.list.itemModalBlocksBackgroundColor
            transition.setFrame(view: self.backgroundView, frame: CGRect(origin: .zero, size: size))
            transition.setFrame(view: self.button, frame: CGRect(origin: .zero, size: size))

            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.theme.list.itemAccentColor
                )),
                environment: {},
                containerSize: CGSize(width: size.width, height: 28.0)
            )
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.addSubview(iconView)
                }
                transition.setFrame(view: iconView, frame: CGRect(
                    x: floorToScreenPixels((size.width - iconSize.width) / 2.0),
                    y: floorToScreenPixels(22.0 - iconSize.height * 0.5),
                    width: iconSize.width,
                    height: iconSize.height
                ))
            }

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.medium(11.0),
                        textColor: component.theme.list.itemAccentColor
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: size.width - 12.0, height: 18.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: CGRect(
                    x: floorToScreenPixels((size.width - titleSize.width) / 2.0),
                    y: floorToScreenPixels(44.0 - titleSize.height * 0.5),
                    width: titleSize.width,
                    height: titleSize.height
                ))
            }
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

private final class WalletCollectibleHeaderButtonComponent: Component {
    let title: String
    let iconName: String
    let buttonColor: UIColor
    let isEnabled: Bool
    let action: () -> Void

    init(title: String, iconName: String, buttonColor: UIColor, isEnabled: Bool, action: @escaping () -> Void) {
        self.title = title
        self.iconName = iconName
        self.buttonColor = buttonColor
        self.isEnabled = isEnabled
        self.action = action
    }

    static func ==(lhs: WalletCollectibleHeaderButtonComponent, rhs: WalletCollectibleHeaderButtonComponent) -> Bool {
        return lhs.title == rhs.title && lhs.iconName == rhs.iconName && lhs.buttonColor == rhs.buttonColor && lhs.isEnabled == rhs.isEnabled
    }

    final class View: UIView {
        private let backgroundView = GlassBackgroundView()
        private let icon = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
        private let button = HighlightTrackingButton()
        private var component: WalletCollectibleHeaderButtonComponent?

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.addSubview(self.backgroundView)
            self.backgroundView.contentView.addSubview(self.button)
            self.button.addTarget(self, action: #selector(self.pressed), for: .touchUpInside)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        @objc private func pressed() {
            self.component?.action()
        }

        func update(component: WalletCollectibleHeaderButtonComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            self.component = component
            let bounds = CGRect(origin: .zero, size: availableSize)
            self.backgroundView.update(size: bounds.size, cornerRadius: 16.0, isDark: true, tintColor: .init(kind: .custom(style: .default, color: component.buttonColor)), isInteractive: true, transition: transition)
            transition.setFrame(view: self.backgroundView, frame: bounds)
            transition.setFrame(view: self.button, frame: bounds)

            let iconSize = self.icon.update(
                transition: transition,
                component: AnyComponent(BundleIconComponent(name: component.iconName, tintColor: .white)),
                environment: {},
                containerSize: availableSize
            )
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    iconView.isUserInteractionEnabled = false
                    self.backgroundView.contentView.addSubview(iconView)
                }
                iconView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - iconSize.width) / 2.0), y: floorToScreenPixels(22.0 - iconSize.height * 0.5)), size: iconSize)
                transition.setAlpha(view: iconView, alpha: component.isEnabled ? 1.0 : 0.5)
            }

            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(string: component.title, font: Font.regular(11.0), textColor: .white)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 16.0, height: availableSize.height)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    titleView.isUserInteractionEnabled = false
                    self.backgroundView.contentView.addSubview(titleView)
                }
                titleView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels(44.0 - titleSize.height * 0.5)), size: titleSize)
                transition.setAlpha(view: titleView, alpha: component.isEnabled ? 1.0 : 0.5)
            }
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, transition: transition)
    }
}

private final class WalletCollectibleTraitValueComponent: Component {
    typealias EnvironmentType = Empty

    let theme: PresentationTheme
    let value: String
    let rarity: String

    init(theme: PresentationTheme, value: String, rarity: String) {
        self.theme = theme
        self.value = value
        self.rarity = rarity
    }

    static func ==(lhs: WalletCollectibleTraitValueComponent, rhs: WalletCollectibleTraitValueComponent) -> Bool {
        return lhs.theme === rhs.theme && lhs.value == rhs.value && lhs.rarity == rhs.rarity
    }

    final class View: UIView {
        private let value = ComponentView<Empty>()
        private let rarityBackground = UIView()
        private let rarity = ComponentView<Empty>()

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.rarityBackground.isUserInteractionEnabled = false
            self.rarityBackground.layer.cornerRadius = 9.0
            self.addSubview(self.rarityBackground)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func update(component: WalletCollectibleTraitValueComponent, availableSize: CGSize, transition: ComponentTransition) -> CGSize {
            let valueSize = self.value.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.value,
                        font: Font.regular(15.0),
                        textColor: component.theme.list.itemPrimaryTextColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            let raritySize = self.rarity.update(
                transition: transition,
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.rarity,
                        font: Font.regular(11.0),
                        textColor: component.theme.list.itemAccentColor
                    )),
                    maximumNumberOfLines: 1
                )),
                environment: {},
                containerSize: availableSize
            )
            let spacing: CGFloat = 4.0
            let badgeSize = CGSize(width: raritySize.width + 10.0, height: 16.0)
            let displayedValueWidth = min(valueSize.width, max(0.0, availableSize.width - badgeSize.width - spacing))
            let badgeX = displayedValueWidth + spacing
            let totalWidth = min(availableSize.width, displayedValueWidth + spacing + badgeSize.width)
            if let valueView = self.value.view {
                if valueView.superview == nil {
                    valueView.isUserInteractionEnabled = false
                    self.addSubview(valueView)
                }
                transition.setFrame(view: valueView, frame: CGRect(
                    x: 0.0,
                    y: floorToScreenPixels((badgeSize.height - valueSize.height) / 2.0),
                    width: displayedValueWidth,
                    height: valueSize.height
                ))
            }
            self.rarityBackground.backgroundColor = component.theme.list.itemAccentColor.withAlphaComponent(0.1)
            transition.setFrame(view: self.rarityBackground, frame: CGRect(
                x: badgeX,
                y: 0.0,
                width: badgeSize.width,
                height: badgeSize.height
            ))
            if let rarityView = self.rarity.view {
                if rarityView.superview == nil {
                    rarityView.isUserInteractionEnabled = false
                    self.addSubview(rarityView)
                }
                transition.setFrame(view: rarityView, frame: CGRect(
                    x: badgeX + 5.0,
                    y: floorToScreenPixels((badgeSize.height - raritySize.height) / 2.0),
                    width: raritySize.width,
                    height: raritySize.height
                ))
            }
            return CGSize(width: totalWidth, height: badgeSize.height)
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

public func makeWalletStyleRestrictionTooltip(context: AccountContext, gifts: [StarGift]?, location: TooltipScreen.Location, openGift: @escaping (StarGift.Gift) -> Void) -> TooltipScreen? {
    let collections = WalletConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 }).cardBackgroundGiftCollections ?? []
    guard !collections.isEmpty else {
        return nil
    }
    var giftsByCollection: [String: StarGift.Gift] = [:]
    for gift in gifts ?? [] {
        if case let .generic(gift) = gift, let title = gift.title {
            let collection = title.filter { $0.isLetter || $0.isNumber }
            if giftsByCollection[collection] == nil {
                giftsByCollection[collection] = gift
            }
        }
    }
    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
    let font = Font.regular(14.0)
    let linkColor = UIColor(rgb: 0x64d2ff)
    let nameFont = Font.medium(14.0)
    let available = collections.compactMap { collection -> (String, StarGift.Gift)? in
        return giftsByCollection[collection].flatMap { (collection, $0) }
    }
    guard !available.isEmpty else {
        return nil
    }
    let names = NSMutableAttributedString()
    for (index, item) in available.enumerated() {
        let (collection, gift) = item
        if index > 0 {
            names.append(NSAttributedString(string: index == available.count - 1 ? strings.CreateGroup_PeersTitleLastDelimeter : strings.CreateGroup_PeersTitleDelimeter, font: font, textColor: .white))
        }
        names.append(NSAttributedString(string: ".", attributes: [.font: font, ChatTextInputAttributes.customEmoji: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: gift.file.fileId.id, file: gift.file)]))
        names.append(NSAttributedString(string: "\u{00A0}", font: font, textColor: .white))
        names.append(NSAttributedString(string: strings.Wallet_Sticker_ColorRestrictedCollection(gift.title ?? collection).string, attributes: [.font: nameFont, .foregroundColor: linkColor, NSAttributedString.Key(rawValue: TelegramTextAttributes.URL): collection]))
    }
    let formatted = strings.Wallet_Sticker_ColorRestricted("")
    let text = NSMutableAttributedString(string: formatted.string, font: font, textColor: .white)
    if let range = formatted.ranges.first(where: { $0.index == 0 })?.range {
        text.insert(names, at: range.location)
    } else {
        text.append(names)
    }
    return TooltipScreen(
        context: context,
        account: context.account,
        sharedContext: context.sharedContext,
        text: .attributedString(text: text),
        arrowStyle: .none,
        icon: generateTintedImage(image: UIImage(bundleImageName: "Wallet/ApplyColor"), color: .white).flatMap { .image($0) },
        location: location,
        displayDuration: .default,
        cornerRadius: 26.0,
        contentLayout: TooltipScreen.ContentLayout(insets: UIEdgeInsets(top: 11.0, left: 14.0, bottom: 11.0, right: 20.0), iconSpacing: 12.0),
        shouldDismissOnTouch: { _, _ in
            return .dismiss(consume: false)
        },
        openActiveTextItem: { item, _ in
            guard case let .url(url, _) = item, let gift = giftsByCollection[url] else {
                return
            }
            openGift(gift)
        }
    )
}

private final class WalletCollectibleContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let collectible: WalletContext.Collectible
    weak var stickerHost: WalletCollectibleStickerHost?
    let openExternalUrl: (String, PresentationTheme) -> Void
    let openTransfer: () -> Void
    let animateOut: ActionSlot<Action<Void>>
    let screenSize: CGSize

    init(
        context: AccountContext,
        collectible: WalletContext.Collectible,
        stickerHost: WalletCollectibleStickerHost?,
        openExternalUrl: @escaping (String, PresentationTheme) -> Void,
        openTransfer: @escaping () -> Void,
        animateOut: ActionSlot<Action<Void>>,
        screenSize: CGSize
    ) {
        self.context = context
        self.collectible = collectible
        self.stickerHost = stickerHost
        self.openExternalUrl = openExternalUrl
        self.openTransfer = openTransfer
        self.animateOut = animateOut
        self.screenSize = screenSize
    }

    static func ==(lhs: WalletCollectibleContentComponent, rhs: WalletCollectibleContentComponent) -> Bool {
        return lhs.context === rhs.context && lhs.collectible == rhs.collectible && lhs.screenSize == rhs.screenSize
    }

    final class View: UIView, UIGestureRecognizerDelegate {
        private let controlButtons = ComponentView<Empty>()
        /// How far the controls' trailing button keeps from a top corner block the sheet has risen beside (iPhone Duo), as
        /// of the last layout: the controls are laid out with it before the content height that decides it is known.
        private var controlsCornerRightInset: CGFloat = 0.0
        private let header = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        private let transferButton = ComponentView<Empty>()
        private let wearButton = ComponentView<Empty>()
        private let sellButton = ComponentView<Empty>()
        private let table = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()
        private let visibilityText = ComponentView<Empty>()

        private let giftDisposable = MetaDisposable()
        private let styleRestrictionDisposable = MetaDisposable()
        private let giftVariantsDisposable = MetaDisposable()
        private let peerDisposable = MetaDisposable()
        private var component: WalletCollectibleContentComponent?
        private var environment: EnvironmentType?
        private weak var componentState: EmptyComponentState?
        private var configuredAddress: String?
        private var uniqueGift: StarGift.UniqueGift?
        private var currentPeer: EnginePeer?
        private var isOpeningValue = false
        private var displayedOverride: Bool?
        private let composition = ComponentView<Empty>()
        private let compositionState = GiftCompositionComponent.ExternalState()
        private let giftTitle = ComponentView<Empty>()
        private let giftSubtitle = ComponentView<Empty>()
        private let giftTransferButton = ComponentView<Empty>()
        private let giftSellButton = ComponentView<Empty>()
        private let giftApplyColorButton = ComponentView<Empty>()
        private let giftAddToCardButton = ComponentView<Empty>()
        private let tearOffAnchor = UIView()
        private var giftSilhouetteView: UIImageView?
        private var displaysGiftHeader = false
        private let tearOffGesture = UILongPressGestureRecognizer()
        private weak var tearOffHost: WalletCollectibleStickerHost?
        private var tearOffSheetGone = false
        private var tearOffFinished = false

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.tearOffGesture.minimumPressDuration = 0.25
            self.tearOffGesture.delegate = self
            self.tearOffGesture.addTarget(self, action: #selector(self.tearOffGestureChanged(_:)))
            self.addGestureRecognizer(self.tearOffGesture)
            self.tearOffAnchor.isUserInteractionEnabled = false
        }

        private var tearOffSourceView: UIView? {
            if self.displaysGiftHeader {
                return self.tearOffAnchor.superview != nil ? self.tearOffAnchor : nil
            }
            return (self.header.view as? WalletCollectibleHeaderComponent.View)?.giftView
        }

        private func hideModelForFlight(host: WalletCollectibleStickerHost, collectible: WalletContext.Collectible, sourceView: UIView) {
            var color = UIColor(white: 0.0, alpha: 0.2)
            for case let .backdrop(_, _, inner, _, pattern, _, _) in (collectible.nft?.gift ?? self.uniqueGift)?.attributes ?? [] {
                color = UIColor(rgb: UInt32(bitPattern: pattern)).mixedWith(UIColor(rgb: UInt32(bitPattern: inner)), alpha: 0.5)
            }
            let silhouette = host.stickerSilhouette(collectible: collectible, side: sourceView.bounds.width)
            if self.displaysGiftHeader {
                if let silhouette {
                    self.showTearOffSilhouette(image: silhouette.image, frame: silhouette.frame, color: color)
                } else {
                    (self.composition.view as? GiftCompositionComponent.View)?.setModelHidden(true)
                }
            } else if let silhouette, let headerView = self.header.view as? WalletCollectibleHeaderComponent.View {
                headerView.showModelSilhouette(image: silhouette.image, frame: silhouette.frame, color: color)
            } else {
                sourceView.isHidden = true
            }
        }

        private func showTearOffSilhouette(image: UIImage, frame: CGRect, color: UIColor) {
            guard let compositionView = self.composition.view as? GiftCompositionComponent.View else { return }
            compositionView.setModelHidden(true)
            let silhouetteView = self.giftSilhouetteView ?? UIImageView()
            self.giftSilhouetteView = silhouetteView
            silhouetteView.isUserInteractionEnabled = false
            silhouetteView.image = image.withRenderingMode(.alwaysTemplate)
            silhouetteView.tintColor = color
            silhouetteView.frame = frame.offsetBy(dx: self.tearOffAnchor.frame.minX - compositionView.frame.minX, dy: self.tearOffAnchor.frame.minY - compositionView.frame.minY)
            if silhouetteView.superview !== compositionView {
                compositionView.addSubview(silhouetteView)
            }
        }

        override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === self.tearOffGesture {
                guard let component = self.component, component.collectible.kind == .gift, component.stickerHost != nil,
                      let sourceView = self.tearOffSourceView else {
                    return false
                }
                return sourceView.bounds.contains(gestureRecognizer.location(in: sourceView))
            }
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }

        @objc private func tearOffGestureChanged(_ recognizer: UILongPressGestureRecognizer) {
            let location = recognizer.location(in: nil)
            switch recognizer.state {
            case .began:
                guard let component = self.component, let host = component.stickerHost, let sourceView = self.tearOffSourceView,
                      host.beginStickerTearOff(collectible: component.collectible, sourceView: sourceView, location: location) else {
                    recognizer.isEnabled = false
                    recognizer.isEnabled = true
                    return
                }
                self.tearOffHost = host
                self.hideModelForFlight(host: host, collectible: component.collectible, sourceView: sourceView)
                self.close(completion: { [weak self] dismiss in
                    guard let self else {
                        dismiss()
                        return
                    }
                    self.tearOffSheetGone = true
                    if self.tearOffFinished {
                        dismiss()
                    }
                })
            case .changed:
                self.tearOffHost?.updateStickerTearOff(location: location)
            case .ended, .cancelled, .failed:
                guard let host = self.tearOffHost else {
                    return
                }
                self.tearOffHost = nil
                host.endStickerTearOff()
                self.tearOffFinished = true
                if self.tearOffSheetGone {
                    (self.environment?.controller() as? WalletCollectibleScreen)?.dismiss(completion: nil)
                }
            default:
                break
            }
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.giftDisposable.dispose()
            self.styleRestrictionDisposable.dispose()
            self.giftVariantsDisposable.dispose()
            self.peerDisposable.dispose()
        }

        private func configure(component: WalletCollectibleContentComponent) {
            self.configuredAddress = component.collectible.address
            self.uniqueGift = nil
            self.displayedOverride = nil
            self.currentPeer = nil
            self.giftDisposable.set(nil)
            self.peerDisposable.set((component.context.engine.data.subscribe(
                TelegramEngine.EngineData.Item.Peer.Peer(id: component.context.account.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, self.configuredAddress == component.collectible.address else {
                    return
                }
                self.currentPeer = peer
                self.componentState?.updated(transition: .easeInOut(duration: 0.2))
            }))

            if component.collectible.kind == .gift, let slug = component.collectible.giftSlug {
                let remoteGift = component.context.engine.payments.getUniqueStarGift(slug: slug)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<StarGift.UniqueGift?, NoError> in
                    return .single(nil)
                }
                self.giftDisposable.set((component.context.engine.payments.cachedUniqueStarGift(slug: slug)
                |> then(remoteGift)
                |> deliverOnMainQueue).start(next: { [weak self] gift in
                    guard let self, self.configuredAddress == component.collectible.address, let gift, self.uniqueGift != gift else {
                        return
                    }
                    self.uniqueGift = gift
                    self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                }))
            }
        }

        private func presentStyleRestriction() {
            guard let component = self.component else {
                return
            }
            self.styleRestrictionDisposable.set((component.context.engine.payments.cachedStarGifts()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] gifts in
                guard let self, let component = self.component, let controller = self.environment?.controller() as? WalletCollectibleScreen,
                      let sourceView = self.giftApplyColorButton.view, sourceView.window != nil, !sourceView.isHidden else {
                    return
                }
                let sourceFrame = sourceView.convert(sourceView.bounds, to: nil)
                guard let tooltip = makeWalletStyleRestrictionTooltip(context: component.context, gifts: gifts, location: .point(sourceFrame, .bottom), openGift: { [weak self] gift in
                    self?.openGiftStore(gift: gift)
                }) else {
                    return
                }
                controller.dismissAllTooltips()
                controller.present(tooltip, in: .current)
            }))
        }

        private func openGiftVariants(attributeKey: String) {
            guard let component = self.component, let gift = self.uniqueGift ?? component.collectible.nft?.gift else {
                return
            }
            let focusedAttribute = gift.attributes.first(where: { attribute in
                switch attribute {
                case .model:
                    return attributeKey == "model"
                case .backdrop:
                    return attributeKey == "backdrop"
                case .pattern:
                    return attributeKey == "symbol"
                default:
                    return false
                }
            })
            let context = component.context
            let starGift = StarGift.unique(gift)
            self.giftVariantsDisposable.set((context.engine.payments.getStarGiftUpgradeAttributes(giftId: starGift.giftId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] attributes in
                guard let self, let attributes, let controller = self.environment?.controller() else {
                    return
                }
                controller.push(context.sharedContext.makeGiftUpgradeVariantsScreen(
                    context: context,
                    gift: starGift,
                    crafted: false,
                    attributes: attributes,
                    selectedAttributes: gift.attributes,
                    focusedAttribute: focusedAttribute
                ))
            }))
        }

        private func openGiftStore(gift: StarGift.Gift) {
            guard let component = self.component, let controller = self.environment?.controller(),
                  let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            let context = component.context
            let storeController = context.sharedContext.makeGiftStoreController(context: context, peerId: context.account.peerId, gift: gift)
            self.close(completion: { dismiss in
                dismiss()
                navigationController.pushViewController(storeController)
            })
        }

        private func performStickerAction(color: Bool) {
            guard let component = self.component, let host = component.stickerHost,
                  let state = host.stickerMenuState(collectible: component.collectible) else {
                return
            }
            let collectible = component.collectible
            if !state.isOnCard, let sourceView = self.tearOffSourceView,
               host.placeSticker(collectible: collectible, color: color, sourceView: sourceView) {
                self.hideModelForFlight(host: host, collectible: collectible, sourceView: sourceView)
                self.close()
                return
            }
            self.close(completion: { [weak host] dismiss in
                dismiss()
                host?.performStickerAction(collectible: collectible, color: color)
            })
        }

        func closeIfDisplaying(address: String) -> Bool {
            guard self.configuredAddress == address else {
                return false
            }
            self.close()
            return true
        }

        private func close(completion: ((@escaping () -> Void) -> Void)? = nil) {
            guard let component = self.component,
                  let controller = self.environment?.controller() as? WalletCollectibleScreen else {
                return
            }
            controller.dismissAllTooltips()
            controller.requestLayout(
                forceUpdate: true,
                transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
            )
            component.animateOut.invoke(Action { [weak controller] _ in
                let dismiss: () -> Void = {
                    controller?.dismiss(completion: nil)
                }
                if let completion {
                    completion(dismiss)
                } else {
                    dismiss()
                }
            })
        }

        private func openMenu(sourceView: UIView) {
            guard let component = self.component,
                  let environment = self.environment,
                  let controller = environment.controller() as? WalletCollectibleScreen else {
                return
            }
            let configuration = WalletConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            let explorerUrl = walletCollectibleExplorerUrl(explorerUrl: configuration.explorerUrl, address: component.collectible.address)
            let item = ContextMenuActionItem(
                text: environment.strings.Wallet_ViewInExplorer,
                icon: { theme in
                    return generateTintedImage(
                        image: UIImage(bundleImageName: "Chat/Context Menu/Search"),
                        color: theme.contextMenu.primaryColor
                    )
                },
                action: { _, dismiss in
                    dismiss(.default)
                    
                    if let explorerUrl {
                        component.openExternalUrl(explorerUrl, environment.theme)
                    }
                }
            )
            var items: [ContextMenuItem] = []
            if component.collectible.kind == .gift, let slug = component.collectible.giftSlug {
                let link = "https://t.me/nft/\(slug)"
                items.append(.action(ContextMenuActionItem(
                    text: environment.strings.Gift_View_Context_CopyLink,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Link"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak controller] _, dismiss in
                        dismiss(.default)
                        UIPasteboard.general.string = link
                        let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
                        controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    }
                )))
                items.append(.action(ContextMenuActionItem(
                    text: environment.strings.Gift_View_Context_Share,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.shareGift(link: link)
                    }
                )))
            }
            if component.collectible.kind == .gift, let uniqueGift = self.uniqueGift {
                let displayed = uniqueGift.hostPeerId != nil
                items.append(.action(ContextMenuActionItem(
                    text: displayed ? environment.strings.Gift_View_Context_HideFromProfile : environment.strings.Gift_View_Context_ShowOnProfile,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: displayed ? "Peer Info/HideIcon" : "Peer Info/ShowIcon"), color: theme.contextMenu.primaryColor)
                    },
                    action: { [weak self] _, dismiss in
                        dismiss(.default)
                        self?.updateDisplayedOnProfile(gift: uniqueGift, displayed: !displayed)
                    }
                )))
            }
            if component.collectible.kind == .gift {
                items.append(.action(ContextMenuActionItem(
                    text: environment.strings.Gift_View_Context_Transfer,
                    icon: { theme in
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Replace"), color: theme.contextMenu.primaryColor)
                    },
                    action: { _, dismiss in
                        dismiss(.default)
                        component.openTransfer()
                    }
                )))
            }
            items.append(.action(item))
            var stickerItems: [ContextMenuItem] = []
            if let host = component.stickerHost, let state = host.stickerMenuState(collectible: component.collectible) {
                let strings = environment.strings
                let perform: (Bool) -> Void = { [weak self] color in
                    self?.performStickerAction(color: color)
                }
                if state.canStyle || state.isStyled || state.isStyleRestricted {
                    let isStyleRestricted = state.isStyleRestricted && !state.isStyled
                    stickerItems.append(.action(ContextMenuActionItem(
                        text: state.isStyled ? strings.Wallet_Sticker_RemoveColor : strings.Wallet_Sticker_ApplyColor,
                        icon: { theme in generateTintedImage(image: UIImage(bundleImageName: state.isStyled ? "Media Editor/Erase" : "Chat/Context Menu/Palette"), color: theme.contextMenu.primaryColor) },
                        action: { [weak self] _, dismiss in
                            dismiss(.default)
                            if isStyleRestricted {
                                self?.presentStyleRestriction()
                            } else {
                                perform(true)
                            }
                        }
                    )))
                }
                stickerItems.append(.action(ContextMenuActionItem(
                    text: state.isOnCard ? strings.Wallet_Sticker_RemoveFromCard : strings.Wallet_Sticker_AddToCard,
                    icon: { theme in generateTintedImage(image: UIImage(bundleImageName: state.isOnCard ? "Chat/Context Menu/Clear" : "Chat/Context Menu/Card"), color: theme.contextMenu.primaryColor) },
                    action: { _, dismiss in
                        dismiss(.default)
                        perform(false)
                    }
                )))
            }
            if !stickerItems.isEmpty {
                items = stickerItems + [.separator] + items
            }
            let contextController = makeContextController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: environment.theme),
                source: .reference(WalletCollectibleContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            controller.presentInGlobalOverlay(contextController)
        }

        private func shareGift(link: String) {
            guard let component = self.component, let controller = self.environment?.controller() as? WalletCollectibleScreen else {
                return
            }
            let context = component.context
            let shareController = context.sharedContext.makeShareScreen(
                context: context,
                params: ShareControllerParams(
                    subject: .url(link),
                    externalShare: false,
                    actionCompleted: { [weak controller] in
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        controller?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                    },
                    enqueued: { [weak controller] peerIds, _ in
                        let _ = (context.engine.data.get(EngineDataList(peerIds.map(TelegramEngine.EngineData.Item.Peer.Peer.init)))
                        |> deliverOnMainQueue).startStandalone(next: { [weak controller] peerList in
                            let peers = peerList.compactMap { $0 }
                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                            let savedMessages = peerIds.count == 1 && peerIds.first == context.account.peerId
                            let text: String
                            if savedMessages {
                                text = presentationData.strings.Conversation_ForwardTooltip_SavedMessages_One
                            } else if peers.count == 1, let peer = peers.first {
                                text = presentationData.strings.Conversation_ForwardTooltip_Chat_One(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")).string
                            } else if peers.count == 2, let firstPeer = peers.first, let secondPeer = peers.last {
                                text = presentationData.strings.Conversation_ForwardTooltip_TwoChats_One(firstPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: ""), secondPeer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: "")).string
                            } else if let peer = peers.first {
                                text = presentationData.strings.Conversation_ForwardTooltip_ManyChats_One(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder).replacingOccurrences(of: "**", with: ""), "\(peers.count - 1)").string
                            } else {
                                return
                            }
                            controller?.present(UndoOverlayController(presentationData: presentationData, content: .forward(savedMessages: savedMessages, text: text), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .current)
                        })
                    }
                )
            )
            controller.present(shareController, in: .window(.root))
        }

        private func updateDisplayedOnProfile(gift: StarGift.UniqueGift, displayed: Bool) {
            guard let component = self.component, let environment = self.environment, let controller = environment.controller() as? WalletCollectibleScreen else {
                return
            }
            let context = component.context
            let address = component.collectible.address
            let _ = (context.engine.payments.displayStarGift(peerId: displayed ? context.account.peerId : nil, slug: gift.slug)
            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                guard let self, self.configuredAddress == address else {
                    return
                }
                self.giftDisposable.set((context.engine.payments.getUniqueStarGift(slug: gift.slug)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<StarGift.UniqueGift?, NoError> in
                    return .single(nil)
                }
                |> deliverOnMainQueue).start(next: { [weak self] updatedGift in
                    guard let self, self.configuredAddress == address, let updatedGift else {
                        return
                    }
                    self.displayedOverride = nil
                    self.uniqueGift = updatedGift
                    self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                }))
            })

            var animationFile: TelegramMediaFile?
            for attribute in gift.attributes {
                if case let .model(_, file, _, _) = attribute {
                    animationFile = file
                    break
                }
            }
            guard let animationFile else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            controller.present(UndoOverlayController(
                presentationData: presentationData,
                content: .sticker(
                    context: context,
                    file: animationFile,
                    loop: false,
                    title: nil,
                    text: displayed ? environment.strings.Gift_Displayed_NewText : environment.strings.Gift_Hidden_NewText,
                    undoText: nil,
                    customAction: nil
                ),
                elevatedLayout: false,
                action: { _ in return true }
            ), in: .current)
        }

        private func giftTrait(
            key: String,
            collectible: WalletContext.Collectible,
            strings: PresentationStrings
        ) -> (value: String, rarity: String) {
            if let uniqueGift = self.uniqueGift {
                for attribute in uniqueGift.attributes {
                    switch (key, attribute) {
                    case let ("model", .model(name, _, rarity, _)):
                        return (name, walletCollectibleRarityText(rarity, strings: strings))
                    case let ("symbol", .pattern(name, _, rarity)):
                        return (name, walletCollectibleRarityText(rarity, strings: strings))
                    case let ("backdrop", .backdrop(name, _, _, _, _, _, rarity)):
                        return (name, walletCollectibleRarityText(rarity, strings: strings))
                    default:
                        break
                    }
                }
            }
            return (collectible.attributes[key] ?? "—", "—")
        }

        private func openValue() {
            guard let component = self.component, let controller = self.environment?.controller() as? WalletCollectibleScreen, let uniqueGift = self.uniqueGift, !self.isOpeningValue else {
                return
            }
            self.isOpeningValue = true
            let context = component.context
            let _ = (context.engine.payments.getUniqueStarGiftValueInfo(slug: uniqueGift.slug)
            |> deliverOnMainQueue).start(next: { [weak self, weak controller] valueInfo in
                self?.isOpeningValue = false
                guard let controller, let valueInfo else {
                    return
                }
                controller.push(GiftValueScreen(context: context, gift: .unique(uniqueGift), valueInfo: valueInfo))
            })
        }

        private func giftTableItems(
            component: WalletCollectibleContentComponent,
            theme: PresentationTheme,
            strings: PresentationStrings,
            dateTimeFormat: PresentationDateTimeFormat,
            displaysOwner: Bool
        ) -> [TableComponent.Item] {
            let ownerFont = Font.monospace(15.0)
            let ownerAddress = component.context.walletContext?.stateValue.walletAddress ?? ""
            let ownerText = NSMutableAttributedString()
            var ownerIndex = ownerAddress.startIndex
            var ownerGroupIndex = 0
            while ownerIndex < ownerAddress.endIndex {
                let row = ownerGroupIndex / 4
                let column = ownerGroupIndex % 4
                let color = (row + column).isMultiple(of: 2) ? theme.list.itemPrimaryTextColor : theme.list.itemSecondaryTextColor
                if ownerGroupIndex != 0 {
                    ownerText.append(NSAttributedString(string: column == 0 ? "\n" : " ", font: ownerFont, textColor: color))
                }
                let endIndex = ownerAddress.index(ownerIndex, offsetBy: 4, limitedBy: ownerAddress.endIndex) ?? ownerAddress.endIndex
                ownerText.append(NSAttributedString(string: String(ownerAddress[ownerIndex ..< endIndex]), font: ownerFont, textColor: color))
                ownerIndex = endIndex
                ownerGroupIndex += 1
            }

            let model = self.giftTrait(key: "model", collectible: component.collectible, strings: strings)
            let symbol = self.giftTrait(key: "symbol", collectible: component.collectible, strings: strings)
            let backdrop = self.giftTrait(key: "backdrop", collectible: component.collectible, strings: strings)
            var items: [TableComponent.Item] = [
                TableComponent.Item(
                    id: "owner",
                    title: strings.Gift_Unique_Owner,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(ownerText),
                        maximumNumberOfLines: 0,
                        lineSpacing: 0.2
                    ))
                ),
                TableComponent.Item(
                    id: "model",
                    title: strings.Gift_Unique_Model,
                    component: AnyComponent(Button(
                        content: AnyComponent(WalletCollectibleTraitValueComponent(
                            theme: theme,
                            value: model.value,
                            rarity: model.rarity
                        )),
                        action: { [weak self] in
                            self?.openGiftVariants(attributeKey: "model")
                        }
                    ))
                ),
                TableComponent.Item(
                    id: "backdrop",
                    title: strings.Gift_Unique_Backdrop,
                    component: AnyComponent(Button(
                        content: AnyComponent(WalletCollectibleTraitValueComponent(
                            theme: theme,
                            value: backdrop.value,
                            rarity: backdrop.rarity
                        )),
                        action: { [weak self] in
                            self?.openGiftVariants(attributeKey: "backdrop")
                        }
                    ))
                ),
                TableComponent.Item(
                    id: "symbol",
                    title: strings.Gift_Unique_Symbol,
                    component: AnyComponent(Button(
                        content: AnyComponent(WalletCollectibleTraitValueComponent(
                            theme: theme,
                            value: symbol.value,
                            rarity: symbol.rarity
                        )),
                        action: { [weak self] in
                            self?.openGiftVariants(attributeKey: "symbol")
                        }
                    ))
                )
            ]
            if !displaysOwner {
                items.removeAll(where: { $0.id == AnyHashable("owner") })
            }
            if let uniqueGift = self.uniqueGift {
                let issuedString = presentationStringsFormattedNumber(uniqueGift.availability.issued, dateTimeFormat.groupingSeparator)
                let totalString = presentationStringsFormattedNumber(uniqueGift.availability.total, dateTimeFormat.groupingSeparator)
                items.append(TableComponent.Item(
                    id: "availability",
                    title: strings.Gift_Unique_Availability,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.Gift_Unique_Issued("\(issuedString)/\(totalString)").string,
                            font: Font.regular(15.0),
                            textColor: theme.list.itemPrimaryTextColor
                        )),
                        maximumNumberOfLines: 1
                    ))
                ))
                if let valueAmount = uniqueGift.valueAmount, let valueCurrency = uniqueGift.valueCurrency {
                    items.append(TableComponent.Item(
                        id: "value",
                        title: strings.Gift_Unique_Value,
                        component: AnyComponent(Button(
                            content: AnyComponent(WalletCollectibleTraitValueComponent(
                                theme: theme,
                                value: "~\(formatCurrencyAmount(valueAmount, currency: valueCurrency))",
                                rarity: strings.Gift_Unique_LearnMore
                            )),
                            action: { [weak self] in
                                self?.openValue()
                            }
                        ))
                    ))
                }
            }
            return items
        }

        func update(
            component: WalletCollectibleContentComponent,
            availableSize: CGSize,
            state: EmptyComponentState,
            environment: Environment<EnvironmentType>,
            transition: ComponentTransition
        ) -> CGSize {
            let environment = environment[EnvironmentType.self].value
            self.component = component
            self.environment = environment
            self.componentState = state
            if self.configuredAddress != component.collectible.address {
                self.configure(component: component)
            }

            let theme = environment.theme
            let headerGift: StarGift.UniqueGift? = component.collectible.kind == .gift ? (component.collectible.nft?.gift ?? self.uniqueGift) : nil
            self.displaysGiftHeader = headerGift != nil
            let giftHeaderButtonHeight: CGFloat = 58.0
            let giftHeaderButtonsBottomInset: CGFloat = 16.0
            let giftHeaderHeight: CGFloat = 220.0 + giftHeaderButtonHeight + giftHeaderButtonsBottomInset
            var controlsBackground: GlassControlGroupComponent.Background = .panel
            var vibrantColor = UIColor.white.withAlphaComponent(0.6)
            var headerButtonColor = UIColor(rgb: 0xffffff, alpha: 0.1)
            if let headerGift {
                let compositionSize = self.composition.update(
                    transition: transition,
                    component: AnyComponent(GiftCompositionComponent(
                        context: component.context,
                        theme: theme,
                        subject: .unique(nil, headerGift),
                        externalState: self.compositionState
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: giftHeaderHeight)
                )
                if let compositionView = self.composition.view {
                    if compositionView.superview == nil {
                        self.insertSubview(compositionView, at: 0)
                    }
                    transition.setFrame(view: compositionView, frame: CGRect(origin: .zero, size: compositionSize))
                    compositionView.alpha = 1.0
                }
                if let backgroundColor = self.compositionState.backgroundColor {
                    let color = backgroundColor.mixedWith(.white, alpha: 0.2)
                    controlsBackground = .color(color)
                    headerButtonColor = color
                }
                if let patternColor = self.compositionState.previewPatternColor {
                    vibrantColor = patternColor.withMultiplied(hue: 1.0, saturation: 1.02, brightness: 1.25).mixedWith(UIColor.white, alpha: 0.3)
                }
                let anchorSide = 136.0 / 0.7
                self.tearOffAnchor.frame = CGRect(x: floorToScreenPixels((availableSize.width - anchorSide) / 2.0), y: 88.0 - anchorSide / 2.0, width: anchorSide, height: anchorSide)
                if self.tearOffAnchor.superview == nil {
                    self.addSubview(self.tearOffAnchor)
                }
            } else {
                self.composition.view?.alpha = 0.0
                self.tearOffAnchor.removeFromSuperview()
            }
            let controlsComponent = AnyComponent(GlassControlPanelComponent(
                theme: theme,
                leftItem: GlassControlPanelComponent.Item(
                    items: [GlassControlGroupComponent.Item(
                        id: AnyHashable("close"),
                        content: .icon("Navigation/Close"),
                        action: { [weak self] in
                            self?.close()
                        }
                    )],
                    background: controlsBackground
                ),
                centralItem: nil,
                rightItem: GlassControlPanelComponent.Item(
                    items: [GlassControlGroupComponent.Item(
                        id: AnyHashable("more"),
                        content: .animation("anim_morewide"),
                        action: { [weak self] in
                            guard let self,
                                  let controlsView = self.controlButtons.view as? GlassControlPanelComponent.View,
                                  let sourceView = controlsView.rightItemView?.itemView(id: AnyHashable("more")) else {
                                return
                            }
                            self.openMenu(sourceView: sourceView)
                        }
                    )],
                    background: controlsBackground
                ),
                centerAlignmentIfPossible: true,
                isDark: headerGift != nil ? true : theme.overallDarkAppearance
            ))
            let controlsSize = self.controlButtons.update(
                transition: transition,
                component: controlsComponent,
                environment: {},
                containerSize: CGSize(width: max(1.0, availableSize.width - 32.0 - self.controlsCornerRightInset), height: 44.0)
            )
            if let controlsView = self.controlButtons.view {
                if controlsView.superview == nil {
                    self.addSubview(controlsView)
                }
                transition.setFrame(view: controlsView, frame: CGRect(x: 16.0, y: 16.0, width: controlsSize.width, height: controlsSize.height))
            }

            var contentHeight: CGFloat = 44.0
            let sideInset: CGFloat = headerGift != nil ? 16.0 : 20.0
            if let headerGift {
                if let headerView = self.header.view {
                    headerView.isHidden = true
                }
                self.descriptionText.view?.alpha = 0.0
                self.transferButton.view?.isHidden = true
                self.wearButton.view?.isHidden = true
                self.sellButton.view?.isHidden = true

                let titleFont = Font.bold(20.0)
                let numberFont = headerGift.number < 1000 ? titleFont : Font.bold(15.0)
                let titleString = NSMutableAttributedString(string: headerGift.title + " ", font: titleFont, textColor: .white)
                titleString.append(NSAttributedString(string: "#" + formatCollectibleNumber(headerGift.number, dateTimeFormat: environment.dateTimeFormat), font: numberFont, textColor: vibrantColor))
                let titleSize = self.giftTitle.update(
                    transition: .immediate,
                    component: AnyComponent(MultilineTextComponent(
                        text: .plain(titleString),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - 32.0 - 60.0, height: 100.0)
                )
                if let titleView = self.giftTitle.view {
                    if titleView.superview == nil {
                        titleView.isUserInteractionEnabled = false
                        self.addSubview(titleView)
                    }
                    titleView.isHidden = false
                    titleView.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - titleSize.width) / 2.0), y: floorToScreenPixels(190.0 - titleSize.height / 2.0)), size: titleSize)
                }

                self.giftSubtitle.view?.isHidden = true

                let headerSideInset: CGFloat = 16.0
                let headerButtonSpacing: CGFloat = 10.0
                let headerButtonY = giftHeaderHeight - giftHeaderButtonHeight - giftHeaderButtonsBottomInset
                var headerButtons: [(ComponentView<Empty>, String, String, Bool, () -> Void)] = [
                    (self.giftTransferButton, environment.strings.Gift_View_Header_Transfer, "Premium/Collectible/Transfer", true, {
                        component.openTransfer()
                    })
                ]
                if let stickerState = component.stickerHost?.stickerMenuState(collectible: component.collectible) {
                    let isStyleRestricted = stickerState.isStyleRestricted && !stickerState.isStyled
                    headerButtons.append((self.giftApplyColorButton, stickerState.isStyled ? environment.strings.Wallet_Collectible_Header_RemoveColor : environment.strings.Wallet_Collectible_Header_ApplyColor, stickerState.isStyled ? "Wallet/RemoveColor" : "Wallet/ApplyColor", !isStyleRestricted, { [weak self] in
                        if isStyleRestricted {
                            self?.presentStyleRestriction()
                        } else {
                            self?.performStickerAction(color: true)
                        }
                    }))
                    headerButtons.append((self.giftAddToCardButton, stickerState.isOnCard ? environment.strings.Wallet_Collectible_Header_RemoveFromCard : environment.strings.Wallet_Collectible_Header_AddToCard, stickerState.isOnCard ? "Wallet/RemoveFromCard" : "Wallet/MoveToWallet", true, { [weak self] in
                        self?.performStickerAction(color: false)
                    }))
                } else {
                    headerButtons.append((self.giftSellButton, environment.strings.Gift_View_Sell, "Premium/Collectible/Sell", true, {
                        guard let url = walletCollectibleFragmentUrl(collectible: component.collectible) else {
                            return
                        }
                        component.openExternalUrl(url, theme)
                    }))
                }
                for view in [self.giftSellButton, self.giftApplyColorButton, self.giftAddToCardButton] where !headerButtons.contains(where: { $0.0 === view }) {
                    view.view?.isHidden = true
                }
                let headerButtonCount = CGFloat(headerButtons.count)
                let headerButtonWidth = floor((availableSize.width - headerSideInset * 2.0 - headerButtonSpacing * (headerButtonCount - 1.0)) / headerButtonCount)
                for (index, item) in headerButtons.enumerated() {
                    let size = item.0.update(
                        transition: transition,
                        component: AnyComponent(WalletCollectibleHeaderButtonComponent(
                            title: item.1,
                            iconName: item.2,
                            buttonColor: headerButtonColor,
                            isEnabled: item.3,
                            action: item.4
                        )),
                        environment: {},
                        containerSize: CGSize(width: headerButtonWidth, height: giftHeaderButtonHeight)
                    )
                    if let view = item.0.view {
                        if view.superview == nil {
                            self.addSubview(view)
                        }
                        view.isHidden = false
                        transition.setFrame(view: view, frame: CGRect(x: headerSideInset + CGFloat(index) * (headerButtonWidth + headerButtonSpacing), y: headerButtonY, width: size.width, height: size.height))
                    }
                }
                contentHeight = giftHeaderHeight - 4.0
            } else {
                self.header.view?.isHidden = false
                self.giftTitle.view?.isHidden = true
                self.giftSubtitle.view?.isHidden = true
                self.giftTransferButton.view?.isHidden = true
                self.giftSellButton.view?.isHidden = true
                self.giftApplyColorButton.view?.isHidden = true
                self.giftAddToCardButton.view?.isHidden = true
                self.transferButton.view?.isHidden = false
                self.sellButton.view?.isHidden = false
                let displaysCollection: Bool
                switch component.collectible.kind {
                case .username, .anonymousNumber:
                    displaysCollection = false
                case .gift, .other:
                    displaysCollection = true
                }
                let headerSize = self.header.update(
                    transition: transition,
                    component: AnyComponent(WalletCollectibleHeaderComponent(
                        context: component.context,
                        theme: theme,
                        item: WalletCollectibleHeaderComponent.Item(
                            name: component.collectible.name,
                            image: component.collectible.image,
                            lottie: component.collectible.lottie,
                            collectionName: component.collectible.collectionName,
                            collectionUrl: component.collectible.collectionUrl,
                            uniqueGift: component.collectible.nft?.gift
                        ),
                        displaysCollection: displaysCollection,
                        openCollection: { url in
                            component.openExternalUrl(url, theme)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: 1000.0)
                )
                if let headerView = self.header.view {
                    if headerView.superview == nil {
                        self.addSubview(headerView)
                    }
                    transition.setFrame(view: headerView, frame: CGRect(x: 0.0, y: contentHeight, width: headerSize.width, height: headerSize.height))
                    (headerView as? WalletCollectibleHeaderComponent.View)?.setAnimationVisible(true)
                }
                contentHeight += headerSize.height

                if component.collectible.kind != .gift,
                   let description = component.collectible.description,
                   !description.isEmpty {
                    contentHeight += 12.0
                    let descriptionSize = self.descriptionText.update(
                        transition: transition,
                        component: AnyComponent(BalancedTextComponent(
                            text: .plain(NSAttributedString(
                                string: description,
                                font: Font.regular(15.0),
                                textColor: theme.actionSheet.secondaryTextColor,
                                paragraphAlignment: .center
                            )),
                            horizontalAlignment: .center,
                            maximumNumberOfLines: 0,
                            lineSpacing: 0.2
                        )),
                        environment: {},
                        containerSize: CGSize(width: availableSize.width - 48.0, height: 1000.0)
                    )
                    if let descriptionView = self.descriptionText.view {
                        if descriptionView.superview == nil {
                            descriptionView.isUserInteractionEnabled = false
                            self.addSubview(descriptionView)
                        }
                        transition.setFrame(view: descriptionView, frame: CGRect(
                            x: floorToScreenPixels((availableSize.width - descriptionSize.width) / 2.0),
                            y: contentHeight,
                            width: descriptionSize.width,
                            height: descriptionSize.height
                        ))
                        transition.setAlpha(view: descriptionView, alpha: 1.0)
                    }
                    contentHeight += descriptionSize.height
                } else if let descriptionView = self.descriptionText.view {
                    transition.setAlpha(view: descriptionView, alpha: 0.0)
                }

                contentHeight += 28.0
                let buttonSpacing: CGFloat = 10.0
                let buttonCount: CGFloat = component.collectible.kind == .gift && !"".isEmpty ? 3.0 : 2.0
                let buttonWidth = floor((availableSize.width - sideInset * 2.0 - buttonSpacing * (buttonCount - 1.0)) / buttonCount)
                var buttonX = sideInset
                let transferSize = self.transferButton.update(
                    transition: transition,
                    component: AnyComponent(WalletCollectibleActionComponent(
                        theme: theme,
                        title: environment.strings.Gift_View_Header_Transfer,
                        iconName: "Premium/Collectible/Transfer",
                        action: {
                            component.openTransfer()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: buttonWidth, height: 58.0)
                )
                if let transferView = self.transferButton.view {
                    if transferView.superview == nil {
                        self.addSubview(transferView)
                    }
                    transition.setFrame(view: transferView, frame: CGRect(x: buttonX, y: contentHeight, width: transferSize.width, height: transferSize.height))
                }
                buttonX += buttonWidth + buttonSpacing

                if !"".isEmpty, component.collectible.kind == .gift {
                    let wearSize = self.wearButton.update(
                        transition: transition,
                        component: AnyComponent(WalletCollectibleActionComponent(
                            theme: theme,
                            title: environment.strings.Gift_View_Header_Wear,
                            iconName: "Premium/Collectible/Wear",
                            action: {
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: buttonWidth, height: 58.0)
                    )
                    if let wearView = self.wearButton.view {
                        if wearView.superview == nil {
                            self.addSubview(wearView)
                        }
                        transition.setFrame(view: wearView, frame: CGRect(x: buttonX, y: contentHeight, width: wearSize.width, height: wearSize.height))
                        transition.setAlpha(view: wearView, alpha: 1.0)
                    }
                    buttonX += buttonWidth + buttonSpacing
                } else if let wearView = self.wearButton.view {
                    transition.setAlpha(view: wearView, alpha: 0.0)
                }

                let sellSize = self.sellButton.update(
                    transition: transition,
                    component: AnyComponent(WalletCollectibleActionComponent(
                        theme: theme,
                        title: environment.strings.Gift_View_Sell,
                        iconName: "Premium/Collectible/Sell",
                        action: {
                            guard let url = walletCollectibleFragmentUrl(collectible: component.collectible) else {
                                return
                            }
                            component.openExternalUrl(url, theme)
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: buttonWidth, height: 58.0)
                )
                if let sellView = self.sellButton.view {
                    if sellView.superview == nil {
                        self.addSubview(sellView)
                    }
                    transition.setFrame(view: sellView, frame: CGRect(x: buttonX, y: contentHeight, width: sellSize.width, height: sellSize.height))
                }
                contentHeight += 58.0
            }

            if component.collectible.kind == .gift {
                contentHeight += 20.0
                var isDuo = false
                if case .iPhoneDuo = environment.deviceMetrics {
                    isDuo = true
                }
                let tableSize = self.table.update(
                    transition: transition,
                    component: AnyComponent(TableComponent(
                        theme: theme,
                        items: self.giftTableItems(component: component, theme: theme, strings: environment.strings, dateTimeFormat: environment.dateTimeFormat, displaysOwner: !isDuo)
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 1000.0)
                )
                if let tableView = self.table.view {
                    if tableView.superview == nil {
                        self.addSubview(tableView)
                    }
                    transition.setFrame(view: tableView, frame: CGRect(
                        x: sideInset,
                        y: contentHeight,
                        width: tableSize.width,
                        height: tableSize.height
                    ))
                    transition.setAlpha(view: tableView, alpha: 1.0)
                }
                contentHeight += tableSize.height
            } else if let tableView = self.table.view {
                transition.setAlpha(view: tableView, alpha: 0.0)
            }

            if component.collectible.kind == .gift {
                let uniqueGift = self.uniqueGift
                let displayed = self.displayedOverride ?? (uniqueGift?.hostPeerId != nil)
                let checkTheme = CheckComponent.Theme(
                    backgroundColor: theme.list.itemCheckColors.fillColor,
                    strokeColor: theme.list.itemCheckColors.foregroundColor,
                    borderColor: theme.list.itemCheckColors.strokeColor,
                    overlayBorder: false,
                    hasInset: false,
                    hasShadow: false
                )

                contentHeight += 18.0
                let visibilityTextSize = self.visibilityText.update(
                    transition: self.visibilityText.view?.superview == nil ? .immediate : transition,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(HStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(CheckComponent(
                                theme: checkTheme,
                                size: CGSize(width: 22.0, height: 22.0),
                                selected: displayed
                            ))),
                            AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(string: environment.strings.Wallet_Collectible_AlsoShowInMyGifts, font: Font.regular(15.0), textColor: theme.list.itemPrimaryTextColor))
                            )))
                        ], spacing: 10.0)),
                        effectAlignment: .center,
                        action: { [weak self] in
                            guard let self, let uniqueGift = self.uniqueGift else {
                                return
                            }
                            let displayed = !(self.displayedOverride ?? (uniqueGift.hostPeerId != nil))
                            self.displayedOverride = displayed
                            self.componentState?.updated(transition: .easeInOut(duration: 0.2))
                            self.updateDisplayedOnProfile(gift: uniqueGift, displayed: displayed)
                        },
                        animateAlpha: false,
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 100.0)
                )
                if let visibilityTextView = self.visibilityText.view {
                    let visibilityTextFrame = CGRect(
                        x: floorToScreenPixels((availableSize.width - visibilityTextSize.width) / 2.0),
                        y: contentHeight,
                        width: visibilityTextSize.width,
                        height: visibilityTextSize.height
                    )
                    if uniqueGift == nil {
                        if visibilityTextView.superview == nil {
                            self.addSubview(visibilityTextView)
                        }
                        visibilityTextView.isHidden = true
                        visibilityTextView.frame = visibilityTextFrame
                    } else if visibilityTextView.superview == nil || visibilityTextView.isHidden {
                        if visibilityTextView.superview == nil {
                            self.addSubview(visibilityTextView)
                        }
                        visibilityTextView.isHidden = false
                        visibilityTextView.frame = visibilityTextFrame
                        transition.animateAlpha(view: visibilityTextView, from: 0.0, to: 1.0)
                    } else {
                        transition.setFrame(view: visibilityTextView, frame: visibilityTextFrame)
                    }
                }
                contentHeight += visibilityTextSize.height + 16.0
            } else {
                self.visibilityText.view?.isHidden = true
                contentHeight += 30.0
            }
            let actionSize = self.actionButton.update(
                transition: transition,
                component: AnyComponent(ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(id: "OK", component: AnyComponent(Text(
                        text: environment.strings.Common_OK,
                        font: Font.semibold(17.0),
                        color: theme.list.itemCheckColors.foregroundColor
                    ))),
                    action: { [weak self] in
                        self?.close()
                    }
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 60.0, height: 52.0)
            )
            if let actionView = self.actionButton.view {
                if actionView.superview == nil {
                    self.addSubview(actionView)
                }
                transition.setFrame(view: actionView, frame: CGRect(
                    x: floorToScreenPixels((availableSize.width - actionSize.width) / 2.0),
                    y: contentHeight,
                    width: actionSize.width,
                    height: actionSize.height
                ))
            }
            contentHeight += actionSize.height + 30.0

            // A tall sheet rises beside the status corner (iPhone Duo, folded portrait: 84x170 at the top right): the
            // trailing button keeps clear of it, which takes the content height, so the controls are laid out again when it
            // changes (the next pass starts from it, so an animated pass does not move the button twice). The sheet is
            // bottom-anchored and centred, its top `contentHeight` (and the glass inset) up. In landscape the sheet keeps to
            // the band beside the strip, where its environment has no side insets, and needs nothing.
            var cornerRightInset: CGFloat = 0.0
            if environment.safeInsets.left > 0.0 || environment.safeInsets.right > 0.0 || environment.navigationBarTrailingButtonsInset > 0.0 {
                cornerRightInset = sheetHeaderCornerInsets(containerWidth: component.screenSize.width, sheetMinX: floorToScreenPixels((component.screenSize.width - availableSize.width) / 2.0), sheetWidth: availableSize.width, sheetMinY: component.screenSize.height - contentHeight - 6.0, reservedCorners: environment.reservedCorners).right
            }
            if cornerRightInset != self.controlsCornerRightInset {
                self.controlsCornerRightInset = cornerRightInset
                let cornerControlsSize = self.controlButtons.update(
                    transition: transition,
                    component: controlsComponent,
                    environment: {},
                    containerSize: CGSize(width: max(1.0, availableSize.width - 32.0 - cornerRightInset), height: 44.0)
                )
                if let controlsView = self.controlButtons.view {
                    transition.setFrame(view: controlsView, frame: CGRect(x: 16.0, y: 16.0, width: cornerControlsSize.width, height: cornerControlsSize.height))
                }
            }

            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
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

private final class WalletCollectiblePagerComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let collectibles: [WalletContext.Collectible]
    let initialIndex: Int
    let itemSpacing: CGFloat
    weak var stickerHost: WalletCollectibleStickerHost?
    let openExternalUrl: (String, PresentationTheme) -> Void
    let openTransfer: (WalletContext.Collectible) -> Void
    let indexUpdated: (Int) -> Void
    let draggingBegan: (Int) -> Void

    init(
        context: AccountContext,
        collectibles: [WalletContext.Collectible],
        initialIndex: Int,
        itemSpacing: CGFloat,
        stickerHost: WalletCollectibleStickerHost?,
        openExternalUrl: @escaping (String, PresentationTheme) -> Void,
        openTransfer: @escaping (WalletContext.Collectible) -> Void,
        indexUpdated: @escaping (Int) -> Void,
        draggingBegan: @escaping (Int) -> Void
    ) {
        self.context = context
        self.collectibles = collectibles
        self.initialIndex = initialIndex
        self.itemSpacing = itemSpacing
        self.stickerHost = stickerHost
        self.openExternalUrl = openExternalUrl
        self.openTransfer = openTransfer
        self.indexUpdated = indexUpdated
        self.draggingBegan = draggingBegan
    }

    static func ==(lhs: WalletCollectiblePagerComponent, rhs: WalletCollectiblePagerComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.collectibles == rhs.collectibles
            && lhs.initialIndex == rhs.initialIndex
            && lhs.itemSpacing == rhs.itemSpacing
    }

    typealias View = WalletPagerView

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(
        view: View,
        availableSize: CGSize,
        state: EmptyComponentState,
        environment: Environment<EnvironmentType>,
        transition: ComponentTransition
    ) -> CGSize {
        return view.update(
            itemIds: self.collectibles.map(\.address),
            initialIndex: self.initialIndex,
            itemSpacing: self.itemSpacing,
            availableSize: availableSize,
            environment: environment,
            transition: transition,
            makeContent: { index, _ in
                let collectible = self.collectibles[index]
                return AnyComponent(WalletCollectibleSheetComponent(
                    context: self.context,
                    collectible: collectible,
                    stickerHost: self.stickerHost,
                    openExternalUrl: self.openExternalUrl,
                    openTransfer: {
                        self.openTransfer(collectible)
                    }
                ))
            },
            indexUpdated: self.indexUpdated,
            draggingBegan: self.draggingBegan
        )
    }
}

private final class WalletCollectibleSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let collectible: WalletContext.Collectible
    weak var stickerHost: WalletCollectibleStickerHost?
    let openExternalUrl: (String, PresentationTheme) -> Void
    let openTransfer: () -> Void

    init(
        context: AccountContext,
        collectible: WalletContext.Collectible,
        stickerHost: WalletCollectibleStickerHost?,
        openExternalUrl: @escaping (String, PresentationTheme) -> Void,
        openTransfer: @escaping () -> Void
    ) {
        self.context = context
        self.collectible = collectible
        self.stickerHost = stickerHost
        self.openExternalUrl = openExternalUrl
        self.openTransfer = openTransfer
    }

    static func ==(lhs: WalletCollectibleSheetComponent, rhs: WalletCollectibleSheetComponent) -> Bool {
        return lhs.context === rhs.context && lhs.collectible == rhs.collectible
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            let sheetComponent = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletCollectibleContentComponent(
                        context: context.component.context,
                        collectible: context.component.collectible,
                        stickerHost: context.component.stickerHost,
                        openExternalUrl: context.component.openExternalUrl,
                        openTransfer: context.component.openTransfer,
                        animateOut: animateOut,
                        screenSize: context.availableSize
                    )),
                    style: .glass,
                    backgroundColor: .color(context.component.collectible.kind == .gift ? environment.theme.list.modalPlainBackgroundColor : environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    hasDimView: false,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                        (controller() as? WalletCollectibleScreen)?.dismissAllTooltips()
                    },
                    willDismiss: {
                        (controller() as? WalletCollectibleScreen)?.requestLayout(
                            forceUpdate: true,
                            transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
                        )
                    }
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.presentsFloatingPanels,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            guard let controller = controller() as? WalletCollectibleScreen else {
                                return
                            }
                            controller.dismissAllTooltips()
                            if animated {
                                controller.requestLayout(
                                    forceUpdate: true,
                                    transition: .easeInOut(duration: 0.3).withUserData(ViewControllerComponentContainer.AnimateOutTransition())
                                )
                                animateOut.invoke(Action { [weak controller] _ in
                                    controller?.dismiss(completion: nil)
                                })
                            } else {
                                controller.dismiss(animated: false)
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            context.add(sheetComponent.position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0)))

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }
                controller.presentationContext.containerLayoutUpdated(
                    ContainerViewLayout(
                        size: context.availableSize,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                        safeInsets: UIEdgeInsets(
                            top: 0.0,
                            left: max(sideInset, environment.safeInsets.left),
                            bottom: 0.0,
                            right: max(sideInset, environment.safeInsets.right)
                        ),
                        reservedCorners: environment.reservedCorners,
                        division: nil,
                        additionalInsets: .zero,
                        statusBarHeight: environment.fullStatusBarHeight,
                        inputHeight: nil,
                        inputHeightIsInteractivellyChanging: false,
                        inVoiceOver: false,
                        presentedInFormSheet: false
                    ),
                    transition: context.transition.containedViewLayoutTransition
                )
            }
            return context.availableSize
        }
    }
}

public final class WalletCollectibleScreen: ViewControllerComponentContainer {
    private let accountContext: AccountContext
    private let walletContext: WalletContext
    private let openExternalUrl: (String, PresentationTheme) -> Void
    private let collectibleSent: (String) -> Void
    private let moveToGifts: ((WalletContext.Collectible, ViewController, @escaping () -> Void) -> Void)?
    private weak var stickerHost: WalletCollectibleStickerHost?
    private let walletPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    private let stateDisposable = MetaDisposable()
    private let loadMoreDisposable = MetaDisposable()
    private var screenUpdatesDisposable: Disposable?
    private let signingAccessDisposable = MetaDisposable()
    private var restorationSession: PasscodeSession?
    private var restorationGeneration = 0
    private var pendingSigningTransfer: (collectible: WalletContext.Collectible, wallet: WalletContext.WalletInfo)?
    private var signingAccessRestored = false
    private weak var recoveryPhraseImportController: ViewController?
    private var isScreenVisible = false

    private var collectiblesState: WalletContext.CollectiblesState
    private var collectibles: [WalletContext.Collectible]
    private var currentAddress: String
    private var requestedPage: WalletContext.CollectiblesState.PageId?
    private var failedPage: WalletContext.CollectiblesState.PageId?

    public init(
        context: AccountContext,
        walletContext: WalletContext,
        collectible: WalletContext.Collectible,
        stickerHost: WalletCollectibleStickerHost? = nil,
        collectibleSent: @escaping (String) -> Void,
        moveToGifts: ((WalletContext.Collectible, ViewController, @escaping () -> Void) -> Void)? = nil
    ) {
        let updatedPresentationData = presentationDataWithDefaultAccent((
            initial: context.sharedContext.currentPresentationData.with { $0 },
            signal: context.sharedContext.presentationData
        ))
        let initialState = walletContext.stateValue.collectibles
        var initialCollectibles = initialState.items
        if !initialCollectibles.contains(where: { $0.address == collectible.address }) {
            initialCollectibles.insert(collectible, at: 0)
        }
        let initialIndex = initialCollectibles.firstIndex(where: { $0.address == collectible.address }) ?? 0
        let openExternalUrl: (String, PresentationTheme) -> Void = { url, theme in
            context.sharedContext.openExternalUrl(
                context: context,
                urlContext: .generic,
                url: url,
                forceExternal: true,
                presentationData: context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: theme),
                navigationController: nil,
                dismissInput: {
                }
            )
        }

        self.accountContext = context
        self.walletContext = walletContext
        self.openExternalUrl = openExternalUrl
        self.collectibleSent = collectibleSent
        self.moveToGifts = moveToGifts
        self.stickerHost = stickerHost
        self.walletPresentationData = updatedPresentationData
        self.collectiblesState = initialState
        self.collectibles = initialCollectibles
        self.currentAddress = collectible.address

        var indexUpdatedImpl: ((Int) -> Void)?
        var draggingBeganImpl: ((Int) -> Void)?
        var openTransferImpl: ((WalletContext.Collectible) -> Void)?
        super.init(
            context: context,
            component: WalletCollectiblePagerComponent(
                context: context,
                collectibles: initialCollectibles,
                initialIndex: initialIndex,
                itemSpacing: 10.0,
                stickerHost: stickerHost,
                openExternalUrl: openExternalUrl,
                openTransfer: { collectible in
                    openTransferImpl?(collectible)
                },
                indexUpdated: { index in
                    indexUpdatedImpl?(index)
                },
                draggingBegan: { index in
                    draggingBeganImpl?(index)
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )
        indexUpdatedImpl = { [weak self] index in
            self?.currentIndexUpdated(index)
        }
        draggingBeganImpl = { [weak self] index in
            self?.draggingBegan(index)
        }
        openTransferImpl = { [weak self] collectible in
            self?.openTransfer(collectible)
        }

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false

        self.stateDisposable.set((walletContext.state
        |> deliverOnMainQueue).start(next: { [weak self] state in
            guard let self else { return }
            if let pending = self.pendingSigningTransfer {
                if case let .wallet(info) = state.phase,
                   info.address == pending.wallet.address, info.publicKey == pending.wallet.publicKey {
                    self.resumeTransferAfterSigningAccess()
                } else {
                    self.abandonRestoration()
                }
            }
            self.collectiblesStateUpdated(state.collectibles)
        }))
        self.requestLoadMoreIfNeeded(index: initialIndex)
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.signingAccessDisposable.dispose()
        self.restorationSession?.invalidate()
        self.screenUpdatesDisposable?.dispose()
        self.stateDisposable.dispose()
        self.loadMoreDisposable.dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.disablesInteractiveModalDismiss = true
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.isScreenVisible = true
        if self.screenUpdatesDisposable == nil {
            self.screenUpdatesDisposable = self.walletContext.beginCollectiblesScreenUpdates()
        }
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.screenUpdatesDisposable?.dispose()
        self.screenUpdatesDisposable = nil
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.isScreenVisible = false
        self.abandonRestoration()
        self.dismissAllTooltips()
    }

    fileprivate func dismissAllTooltips() {
        self.window?.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
        })
        self.forEachController({ controller in
            if let controller = controller as? TooltipScreen {
                controller.dismiss(inPlace: false)
            }
            if let controller = controller as? UndoOverlayController {
                controller.dismiss()
            }
            return true
        })
    }

    private func collectiblesStateUpdated(_ state: WalletContext.CollectiblesState) {
        if let requestedPage = self.requestedPage,
           state.nextPage != requestedPage || !state.canLoadMore {
            self.requestedPage = nil
            self.failedPage = nil
        }

        var collectibles = state.items
        if !collectibles.contains(where: { $0.address == self.currentAddress }),
           let currentCollectible = self.collectibles.first(where: { $0.address == self.currentAddress }) {
            let previousIndex = self.collectibles.firstIndex(where: { $0.address == self.currentAddress }) ?? 0
            collectibles.insert(currentCollectible, at: min(previousIndex, collectibles.count))
        }
        if collectibles.isEmpty, let currentCollectible = self.collectibles.first {
            collectibles = [currentCollectible]
        }

        self.collectiblesState = state
        self.collectibles = collectibles
        let currentIndex = collectibles.firstIndex(where: { $0.address == self.currentAddress }) ?? 0
        self.updatePager(initialIndex: currentIndex)
        self.requestLoadMoreIfNeeded(index: currentIndex)
    }

    private func updatePager(initialIndex: Int) {
        self.updateComponent(
            component: AnyComponent(WalletCollectiblePagerComponent(
                context: self.accountContext,
                collectibles: self.collectibles,
                initialIndex: initialIndex,
                itemSpacing: 10.0,
                stickerHost: self.stickerHost,
                openExternalUrl: self.openExternalUrl,
                openTransfer: { [weak self] collectible in
                    self?.openTransfer(collectible)
                },
                indexUpdated: { [weak self] index in
                    self?.currentIndexUpdated(index)
                },
                draggingBegan: { [weak self] index in
                    self?.draggingBegan(index)
                }
            )),
            transition: .immediate
        )
    }

    private func openTransfer(_ collectible: WalletContext.Collectible) {
        guard self.isScreenVisible, self.pendingSigningTransfer == nil,
              self.recoveryPhraseImportController == nil else { return }
        guard case let .wallet(info) = self.walletContext.stateValue.phase else { return }
        if let balance = self.walletContext.stateValue.balance.currentValue, balance < 100_000_000 {
            let strings = self.walletPresentationData.initial.strings
            self.present(textAlertController(
                context: self.accountContext,
                updatedPresentationData: self.walletPresentationData,
                title: strings.Wallet_Backup_InsufficientFundsTitle,
                text: strings.Wallet_Transfer_CollectibleTopUpText,
                actions: [
                    TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .defaultAction, title: strings.Wallet_Backup_TopUp, action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.push(self.accountContext.sharedContext.makeWalletReceiveScreen(
                            context: self.accountContext,
                            address: info.address
                        ))
                    })
                ]
            ), in: .window(.root))
            return
        }
        if info.canSign {
            self.routeToTransfer(collectible)
        } else if info.canExportPhrase {
            self.pendingSigningTransfer = (collectible, info)
            let generation = self.restorationGeneration
            self.signingAccessDisposable.set(performWalletAuthorizedOperation(
                context: self.accountContext,
                updatedPresentationData: self.walletPresentationData,
                present: { [weak self] alert in
                    self?.present(alert, in: .window(.root))
                },
                operation: { [weak self] password -> Signal<[String], WalletContext.WalletError> in
                    guard let self, self.restorationGeneration == generation,
                          self.signingWalletMatches(info) else { return .fail(.authorizationCancelled) }
                    return self.restorationAuthorization()
                    |> mapToSignal { [weak self] session in
                        guard let self, self.restorationGeneration == generation,
                              self.signingWalletMatches(info) else { return .fail(.authorizationCancelled) }
                        return self.walletContext.recoveryPhrase(password: password, session: session)
                    }
                },
                next: { [weak self] _ in
                    guard let self, self.restorationGeneration == generation else { return }
                    self.signingAccessRestored = true
                    self.resumeTransferAfterSigningAccess()
                },
                failed: { [weak self] error in
                    guard let self, self.restorationGeneration == generation else { return }
                    self.finishRestoration(error: error, collectible: collectible, wallet: info)
                }
            ))
        } else {
            let importController = self.accountContext.sharedContext.makeWalletImportScreen(
                context: self.accountContext,
                mode: .enterRecoveryPhrase,
                completion: { [weak self] in
                    self?.recoveryPhraseImportController?.dismiss(animated: true)
                    self?.recoveryPhraseImportController = nil
                }
            )
            self.recoveryPhraseImportController = importController
            self.push(importController)
        }
    }

    private func signingWalletMatches(_ expected: WalletContext.WalletInfo) -> Bool {
        guard case let .wallet(info) = self.walletContext.stateValue.phase else { return false }
        return info.address == expected.address && info.publicKey == expected.publicKey
    }

    private func restorationAuthorization() -> Signal<PasscodeSession, WalletContext.WalletError> {
        if let session = self.restorationSession, session.isValid { return .single(session) }
        let generation = self.restorationGeneration
        return self.walletContext.beginWalletFlow(reason: "Restore wallet")
        |> deliverOnMainQueue
        |> mapToSignal { [weak self] session -> Signal<PasscodeSession, WalletContext.WalletError> in
            guard let self, self.restorationGeneration == generation else {
                session.invalidate()
                return .fail(.authorizationCancelled)
            }
            self.restorationSession?.invalidate()
            self.restorationSession = session
            return .single(session)
        }
    }

    private func resumeTransferAfterSigningAccess() {
        guard self.signingAccessRestored, self.pendingSigningTransfer != nil else { return }
        let generation = self.restorationGeneration
        Queue.mainQueue().justDispatch { [weak self] in
            guard let self, self.restorationGeneration == generation, self.isScreenVisible,
                  let pending = self.pendingSigningTransfer,
                  self.signingWalletMatches(pending.wallet),
                  case let .wallet(info) = self.walletContext.stateValue.phase,
                  info.canSign, self.walletContext.stateValue.activeOperation == nil else { return }
            self.abandonRestoration()
            self.routeToTransfer(pending.collectible)
        }
    }

    private func abandonRestoration() {
        self.restorationGeneration &+= 1
        self.pendingSigningTransfer = nil
        self.signingAccessRestored = false
        self.signingAccessDisposable.set(nil)
        self.restorationSession?.invalidate()
        self.restorationSession = nil
    }

    private func finishRestoration(error: WalletContext.WalletError, collectible: WalletContext.Collectible, wallet: WalletContext.WalletInfo) {
        self.abandonRestoration()
        guard error != .authorizationCancelled, self.isScreenVisible, self.signingWalletMatches(wallet) else { return }
        let strings = self.walletPresentationData.initial.strings
        let message = walletAuthorizationErrorMessage(error, strings: strings)
        let generation = self.restorationGeneration
        self.present(textAlertController(
            context: self.accountContext,
            updatedPresentationData: self.walletPresentationData,
            title: message?.title ?? strings.Wallet_RestoreErrorTitle,
            text: message?.text ?? strings.Wallet_NetworkError,
            actions: [
                TextAlertAction(type: .genericAction, title: strings.Common_Cancel, action: {}),
                TextAlertAction(type: .defaultAction, title: strings.Wallet_Retry, action: { [weak self] in
                    guard let self, self.restorationGeneration == generation, self.signingWalletMatches(wallet) else { return }
                    self.openTransfer(collectible)
                })
            ],
            dismissOnOutsideTap: false
        ), in: .window(.root))
    }

    private func closeAnimated(address: String) {
        func findContentView(_ view: UIView) -> WalletCollectibleContentComponent.View? {
            if let view = view as? WalletCollectibleContentComponent.View, view.closeIfDisplaying(address: address) {
                return view
            }
            for subview in view.subviews {
                if let result = findContentView(subview) {
                    return result
                }
            }
            return nil
        }
        if findContentView(self.view) == nil {
            self.dismiss(animated: true)
        }
    }

    private func routeToTransfer(_ collectible: WalletContext.Collectible) {
        var moveToGiftsImpl: (() -> Void)?
        let peerSelectionScreen = WalletPeerSelectionScreen(
            context: self.accountContext,
            walletContext: self.walletContext,
            mode: .collectible(collectible),
            dismissSourceScreen: { [weak self] in
                guard let self else {
                    return
                }
                self.collectibleSent(collectible.address)
                if let navigationController = self.navigationController as? NavigationController {
                    var viewControllers = navigationController.viewControllers
                    viewControllers.removeAll(where: { $0 === self })
                    navigationController.setViewControllers(viewControllers, animated: false)
                } else {
                    self.dismiss(animated: false)
                }
            },
            moveToGifts: collectible.kind == .gift && collectible.giftSlug != nil && self.moveToGifts != nil ? {
                moveToGiftsImpl?()
            } : nil
        )
        moveToGiftsImpl = { [weak self, weak peerSelectionScreen] in
            guard let self, let peerSelectionScreen else {
                return
            }
            peerSelectionScreen.view.window?.endEditing(true)
            if let navigationController = self.navigationController as? NavigationController {
                navigationController.setViewControllers(navigationController.viewControllers.filter { $0 !== peerSelectionScreen }, animated: true)
            }
            self.moveToGifts?(collectible, self, { [weak self] in
                guard let self else {
                    return
                }
                self.collectibleSent(collectible.address)
                self.closeAnimated(address: collectible.address)
            })
        }
        peerSelectionScreen.navigationPresentation = .modal
        self.push(peerSelectionScreen)
    }

    private func currentIndexUpdated(_ index: Int) {
        guard self.collectibles.indices.contains(index) else {
            return
        }
        self.currentAddress = self.collectibles[index].address
        self.requestLoadMoreIfNeeded(index: index)
    }

    private func draggingBegan(_ index: Int) {
        if self.failedPage == self.collectiblesState.nextPage {
            self.requestedPage = nil
            self.failedPage = nil
        }
        self.requestLoadMoreIfNeeded(index: index)
    }

    private func requestLoadMoreIfNeeded(index: Int) {
        guard !self.collectibles.isEmpty,
              index >= max(0, self.collectibles.count - 2),
              let page = self.collectiblesState.nextPage,
              !self.collectiblesState.isRefreshing,
              !self.collectiblesState.isLoadingMore,
              self.collectiblesState.error == nil || self.failedPage == nil,
              self.walletContext.stateValue.activeOperation == nil else {
            return
        }
        guard self.requestedPage != page else {
            return
        }
        self.requestedPage = page
        self.loadMoreDisposable.set((self.walletContext.loadMoreCollectibles()
        |> deliverOnMainQueue).start(error: { [weak self] _ in
            guard let self, self.requestedPage == page else {
                return
            }
            self.failedPage = page
        }))
    }
}

private final class WalletCollectibleContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(
            referenceView: self.sourceView,
            contentAreaInScreenSpace: mainWindowScreenBounds,
            actionsPosition: .bottom
        )
    }
}
