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
import TableComponent
import AvatarComponent
import ContextUI
import TextFormat
import TooltipUI
import UndoUI
import WalletContext
import WalletPagerComponent
import WalletCollectibleHeaderComponent
import WalletPeerSelectionScreen
import WalletAuthorizationUI
import PasscodeCore

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
    guard let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
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
            let size = CGSize(width: availableSize.width, height: 60.0)
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
                    y: 7.0,
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
                    y: 38.0 + UIScreenPixel,
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

private final class WalletCollectibleContentComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let collectible: WalletContext.Collectible
    let openExternalUrl: (String, PresentationTheme) -> Void
    let openTransfer: () -> Void
    let animateOut: ActionSlot<Action<Void>>

    init(
        context: AccountContext,
        collectible: WalletContext.Collectible,
        openExternalUrl: @escaping (String, PresentationTheme) -> Void,
        openTransfer: @escaping () -> Void,
        animateOut: ActionSlot<Action<Void>>
    ) {
        self.context = context
        self.collectible = collectible
        self.openExternalUrl = openExternalUrl
        self.openTransfer = openTransfer
        self.animateOut = animateOut
    }

    static func ==(lhs: WalletCollectibleContentComponent, rhs: WalletCollectibleContentComponent) -> Bool {
        return lhs.context === rhs.context && lhs.collectible == rhs.collectible
    }

    final class View: UIView {
        private let controlButtons = ComponentView<Empty>()
        private let header = ComponentView<Empty>()
        private let descriptionText = ComponentView<Empty>()
        private let transferButton = ComponentView<Empty>()
        private let wearButton = ComponentView<Empty>()
        private let sellButton = ComponentView<Empty>()
        private let table = ComponentView<Empty>()
        private let actionButton = ComponentView<Empty>()

        private let giftDisposable = MetaDisposable()
        private let peerDisposable = MetaDisposable()
        private var component: WalletCollectibleContentComponent?
        private var environment: EnvironmentType?
        private weak var componentState: EmptyComponentState?
        private var configuredAddress: String?
        private var uniqueGift: StarGift.UniqueGift?
        private var currentPeer: EnginePeer?

        override init(frame: CGRect) {
            super.init(frame: frame)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.giftDisposable.dispose()
            self.peerDisposable.dispose()
        }

        private func configure(component: WalletCollectibleContentComponent) {
            self.configuredAddress = component.collectible.address
            self.uniqueGift = nil
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
                self.giftDisposable.set((component.context.engine.payments.getUniqueStarGift(slug: slug)
                |> map(Optional.init)
                |> `catch` { _ -> Signal<StarGift.UniqueGift?, NoError> in
                    return .single(nil)
                }
                |> deliverOnMainQueue).start(next: { [weak self] gift in
                    guard let self, self.configuredAddress == component.collectible.address else {
                        return
                    }
                    self.uniqueGift = gift
                    self.componentState?.updated(transition: .easeInOut(duration: 0.25))
                }))
            }
        }

        private func close() {
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
                controller?.dismiss(completion: nil)
            })
        }

        private func openExplorer(sourceView: UIView) {
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
            let contextController = makeContextController(
                presentationData: component.context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: environment.theme),
                source: .reference(WalletCollectibleContextReferenceContentSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list([.action(item)]))),
                gesture: nil
            )
            controller.presentInGlobalOverlay(contextController)
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

        private func giftValue() -> String {
            guard let uniqueGift = self.uniqueGift else {
                return "—"
            }
            var parts: [String] = []
            if let amount = uniqueGift.valueAmount, let currency = uniqueGift.valueCurrency {
                parts.append(formatCurrencyAmount(amount, currency: currency))
            }
            if let usdAmount = uniqueGift.valueUsdAmount {
                parts.append("~\(formatCurrencyAmount(usdAmount, currency: "USD"))")
            }
            return parts.isEmpty ? "—" : parts.joined(separator: " ")
        }

        private func giftTableItems(
            component: WalletCollectibleContentComponent,
            theme: PresentationTheme,
            strings: PresentationStrings
        ) -> [TableComponent.Item] {
            var ownerItems: [AnyComponentWithIdentity<Empty>] = []
            if let currentPeer = self.currentPeer {
                ownerItems.append(AnyComponentWithIdentity(
                    id: "avatar",
                    component: AnyComponent(AvatarComponent(
                        context: component.context,
                        theme: theme,
                        peer: currentPeer,
                        size: CGSize(width: 20.0, height: 20.0)
                    ))
                ))
            }
            ownerItems.append(AnyComponentWithIdentity(
                id: "title",
                component: AnyComponent(MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.DialogList_You,
                        font: Font.regular(15.0),
                        textColor: theme.list.itemAccentColor
                    )),
                    maximumNumberOfLines: 1
                ))
            ))

            let model = self.giftTrait(key: "model", collectible: component.collectible, strings: strings)
            let symbol = self.giftTrait(key: "symbol", collectible: component.collectible, strings: strings)
            let backdrop = self.giftTrait(key: "backdrop", collectible: component.collectible, strings: strings)
            return [
                TableComponent.Item(
                    id: "owner",
                    title: strings.Gift_Unique_Owner,
                    component: AnyComponent(HStack(ownerItems, spacing: 6.0))
                ),
                TableComponent.Item(
                    id: "model",
                    title: strings.Gift_Unique_Model,
                    component: AnyComponent(WalletCollectibleTraitValueComponent(
                        theme: theme,
                        value: model.value,
                        rarity: model.rarity
                    ))
                ),
                TableComponent.Item(
                    id: "symbol",
                    title: strings.Gift_Unique_Symbol,
                    component: AnyComponent(WalletCollectibleTraitValueComponent(
                        theme: theme,
                        value: symbol.value,
                        rarity: symbol.rarity
                    ))
                ),
                TableComponent.Item(
                    id: "backdrop",
                    title: strings.Gift_Unique_Backdrop,
                    component: AnyComponent(WalletCollectibleTraitValueComponent(
                        theme: theme,
                        value: backdrop.value,
                        rarity: backdrop.rarity
                    ))
                )
//                ,
//                TableComponent.Item(
//                    id: "value",
//                    title: "Value",
//                    component: AnyComponent(MultilineTextComponent(
//                        text: .plain(NSAttributedString(
//                            string: self.giftValue(),
//                            font: Font.regular(15.0),
//                            textColor: theme.list.itemPrimaryTextColor
//                        )),
//                        maximumNumberOfLines: 1
//                    ))
//                )
            ]
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
            let controlsSize = self.controlButtons.update(
                transition: transition,
                component: AnyComponent(GlassControlPanelComponent(
                    theme: theme,
                    leftItem: GlassControlPanelComponent.Item(
                        items: [GlassControlGroupComponent.Item(
                            id: AnyHashable("close"),
                            content: .icon("Navigation/Close"),
                            action: { [weak self] in
                                self?.close()
                            }
                        )],
                        background: .panel
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
                                self.openExplorer(sourceView: sourceView)
                            }
                        )],
                        background: .panel
                    ),
                    centerAlignmentIfPossible: true,
                    isDark: theme.overallDarkAppearance
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 32.0, height: 44.0)
            )
            if let controlsView = self.controlButtons.view {
                if controlsView.superview == nil {
                    self.addSubview(controlsView)
                }
                transition.setFrame(view: controlsView, frame: CGRect(x: 16.0, y: 16.0, width: controlsSize.width, height: controlsSize.height))
            }

            let displaysCollection: Bool
            switch component.collectible.kind {
            case .username, .anonymousNumber:
                displaysCollection = false
            case .gift, .other:
                displaysCollection = true
            }
            var contentHeight: CGFloat = 44.0
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
                        collectionUrl: component.collectible.collectionUrl
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
            let sideInset: CGFloat = 20.0
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
                containerSize: CGSize(width: buttonWidth, height: 60.0)
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
                    containerSize: CGSize(width: buttonWidth, height: 60.0)
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
                containerSize: CGSize(width: buttonWidth, height: 60.0)
            )
            if let sellView = self.sellButton.view {
                if sellView.superview == nil {
                    self.addSubview(sellView)
                }
                transition.setFrame(view: sellView, frame: CGRect(x: buttonX, y: contentHeight, width: sellSize.width, height: sellSize.height))
            }
            contentHeight += 60.0

            if component.collectible.kind == .gift {
                contentHeight += 20.0
                let tableSize = self.table.update(
                    transition: transition,
                    component: AnyComponent(TableComponent(
                        theme: theme,
                        items: self.giftTableItems(component: component, theme: theme, strings: environment.strings),
                        semiTransparent: true,
                        rightColumnBackgroundColor: theme.list.itemModalBlocksBackgroundColor
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

            contentHeight += 30.0
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
    let openExternalUrl: (String, PresentationTheme) -> Void
    let openTransfer: (WalletContext.Collectible) -> Void
    let indexUpdated: (Int) -> Void
    let draggingBegan: (Int) -> Void

    init(
        context: AccountContext,
        collectibles: [WalletContext.Collectible],
        initialIndex: Int,
        itemSpacing: CGFloat,
        openExternalUrl: @escaping (String, PresentationTheme) -> Void,
        openTransfer: @escaping (WalletContext.Collectible) -> Void,
        indexUpdated: @escaping (Int) -> Void,
        draggingBegan: @escaping (Int) -> Void
    ) {
        self.context = context
        self.collectibles = collectibles
        self.initialIndex = initialIndex
        self.itemSpacing = itemSpacing
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
    let openExternalUrl: (String, PresentationTheme) -> Void
    let openTransfer: () -> Void

    init(
        context: AccountContext,
        collectible: WalletContext.Collectible,
        openExternalUrl: @escaping (String, PresentationTheme) -> Void,
        openTransfer: @escaping () -> Void
    ) {
        self.context = context
        self.collectible = collectible
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
                        openExternalUrl: context.component.openExternalUrl,
                        openTransfer: context.component.openTransfer,
                        animateOut: animateOut
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
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
                        isCentered: environment.metrics.widthClass == .regular,
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
                        additionalInsets: .zero,
                        statusBarHeight: environment.statusBarHeight,
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
        collectibleSent: @escaping (String) -> Void
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

    private func routeToTransfer(_ collectible: WalletContext.Collectible) {
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
            }
        )
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
            contentAreaInScreenSpace: UIScreen.main.bounds,
            actionsPosition: .bottom
        )
    }
}
