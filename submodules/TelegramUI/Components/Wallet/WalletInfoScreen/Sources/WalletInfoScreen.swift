import Foundation
import LottieSettings
import UIKit
import Display
import AccountContext
import SwiftSignalKit
import WalletContext
import Markdown
import TelegramPresentationData
import TelegramStringFormatting
import TextFormat
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import BundleIconComponent
import MultilineTextComponent
import LottieComponent
import PremiumDiamondComponent
import GlassBarButtonComponent
import ButtonComponent
import InfoParagraphComponent

private struct WalletInfoLogo: Equatable {
    let name: String
    let loop: Bool
}

private struct WalletInfoItem: Equatable {
    let id: String
    let title: String?
    let text: String
    let iconName: String
    var textIconName: String? = nil
}

private struct WalletInfoContent: Equatable {
    let logo: WalletInfoLogo
    let title: String
    let text: String
    let items: [WalletInfoItem]
    let buttonTitle: String
}

private func walletInfoContent(
    mode: WalletInfoScreenMode,
    fiatState: WalletContext.FiatState?,
    strings: PresentationStrings,
    dateTimeFormat: PresentationDateTimeFormat
) -> WalletInfoContent {
    switch mode {
    case .wallet:
        return WalletInfoContent(
            logo: WalletInfoLogo(name: "GramDiamond", loop: true),
            title: strings.Wallet_Info_Title,
            text: strings.Wallet_Info_Text,
            items: [
                WalletInfoItem(
                    id: "instantTransfers",
                    title: strings.Wallet_Info_InstantTransfersTitle,
                    text: strings.Wallet_Info_InstantTransfersText,
                    iconName: "Wallet/InfoFast"
                ),
                WalletInfoItem(
                    id: "zeroFees",
                    title: strings.Wallet_Info_ZeroFeesTitle,
                    text: strings.Wallet_Info_ZeroFeesText,
                    iconName: "Wallet/InfoCheap"
                ),
                WalletInfoItem(
                    id: "blockchainVerified",
                    title: strings.Wallet_Info_BlockchainVerifiedTitle,
                    text: strings.Wallet_Info_BlockchainVerifiedText,
                    iconName: "Wallet/InfoVerified"
                )
            ],
            buttonTitle: strings.Wallet_GotIt
        )
    case .gram:
        let text: String
        if let fiatState, let fiatRate = fiatState.selectedRate, fiatRate.unitsPerGram.isFinite, fiatRate.unitsPerGram > 0.0 {
            let fiatRateText = formatFiatValue(
                fiatRate.unitsPerGram,
                currencySymbol: fiatState.selectedCurrency.symbol,
                dateTimeFormat: dateTimeFormat
            )
            text = strings.Wallet_Info_GramRateText(fiatRateText).string
        } else {
            text = strings.Wallet_Info_GramText
        }

        return WalletInfoContent(
            logo: WalletInfoLogo(name: "GramDiamond", loop: true),
            title: strings.Wallet_Info_GramTitle,
            text: text,
            items: [
                WalletInfoItem(
                    id: "fast",
                    title: strings.Wallet_Info_FastTitle,
                    text: strings.Wallet_Info_FastText,
                    iconName: "Wallet/InfoFast"
                ),
                WalletInfoItem(
                    id: "cheap",
                    title: strings.Wallet_Info_CheapTitle,
                    text: strings.Wallet_Info_CheapText,
                    iconName: "Wallet/InfoCheap"
                ),
                WalletInfoItem(
                    id: "useful",
                    title: strings.Wallet_Info_UsefulTitle,
                    text: strings.Wallet_Info_UsefulText,
                    iconName: "Wallet/InfoUseful"
                )
            ],
            buttonTitle: strings.Wallet_GotIt
        )
    case .firstGrams:
        let text: String
        if let fiatState, let fiatRate = fiatState.selectedRate, fiatRate.unitsPerGram.isFinite, fiatRate.unitsPerGram > 0.0 {
            let fiatRateText = formatFiatValue(
                fiatRate.unitsPerGram,
                currencySymbol: fiatState.selectedCurrency.symbol,
                dateTimeFormat: dateTimeFormat
            )
            text = strings.Wallet_Info_FirstGramsRateText(fiatRateText).string
        } else {
            text = strings.Wallet_Info_FirstGramsText
        }

        return WalletInfoContent(
            logo: WalletInfoLogo(name: "GramDiamond", loop: true),
            title: strings.Wallet_Info_FirstGramsTitle,
            text: text,
            items: [
                WalletInfoItem(
                    id: "send",
                    title: strings.Wallet_Info_SendTitle,
                    text: strings.Wallet_Info_SendText,
                    iconName: "Wallet/InfoSend",
                    textIconName: "Wallet/InfoAttach"
                ),
                WalletInfoItem(
                    id: "trade",
                    title: strings.Wallet_Info_TradeTitle,
                    text: strings.Wallet_Info_TradeText,
                    iconName: "Wallet/InfoTrade"
                ),
                WalletInfoItem(
                    id: "store",
                    title: strings.Wallet_Info_StoreTitle,
                    text: strings.Wallet_Info_StoreText,
                    iconName: "Wallet/InfoStore",
                    textIconName: "Wallet/InfoSettings"
                )
            ],
            buttonTitle: strings.Wallet_GotIt
        )
    case .recovery:
        return WalletInfoContent(
            logo: WalletInfoLogo(name: "WalletWordList", loop: false),
            title: strings.Wallet_SecretPhrase,
            text: strings.Wallet_SecretPhraseInfo,
            items: [
                WalletInfoItem(
                    id: "neverShare",
                    title: nil,
                    text: strings.Wallet_Info_NeverSharePhrase,
                    iconName: "Wallet/InfoHidden"
                ),
                WalletInfoItem(
                    id: "canSteal",
                    title: nil,
                    text: strings.Wallet_Info_PhraseTheftWarning,
                    iconName: "Wallet/InfoWarning"
                ),
                WalletInfoItem(
                    id: "support",
                    title: nil,
                    text: strings.Wallet_Info_PhraseSupportWarning,
                    iconName: "Wallet/InfoShield"
                )
            ],
            buttonTitle: strings.Wallet_ShowSecretPhrase
        )
    }
}

private final class WalletInfoSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletInfoScreenMode
    let completion: (() -> Void)?
    let animateOut: ActionSlot<Action<()>>
    let getController: () -> ViewController?

    init(
        context: AccountContext,
        mode: WalletInfoScreenMode,
        completion: (() -> Void)?,
        animateOut: ActionSlot<Action<()>>,
        getController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.mode = mode
        self.completion = completion
        self.animateOut = animateOut
        self.getController = getController
    }

    static func ==(lhs: WalletInfoSheetContent, rhs: WalletInfoSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }

    final class State: ComponentState {
        private let animateOut: ActionSlot<Action<()>>
        private let getController: () -> ViewController?
        fileprivate let playRecoveryAnimation = ActionSlot<Void>()
        private var didPlayRecoveryAnimation = false
        fileprivate var fiatState: WalletContext.FiatState?
        private var walletStateDisposable: Disposable?

        init(
            context: AccountContext,
            mode: WalletInfoScreenMode,
            animateOut: ActionSlot<Action<()>>,
            getController: @escaping () -> ViewController?
        ) {
            self.animateOut = animateOut
            self.getController = getController

            super.init()

            if mode == .gram || mode == .firstGrams, let walletContext = context.walletContext {
                self.fiatState = walletContext.stateValue.fiat
                self.walletStateDisposable = (walletContext.state
                |> deliverOnMainQueue).start(next: { [weak self] walletState in
                    guard let self, self.fiatState != walletState.fiat else {
                        return
                    }
                    self.fiatState = walletState.fiat
                    self.updated(transition: .immediate)
                })
            }
        }

        deinit {
            self.walletStateDisposable?.dispose()
        }

        func playRecoveryAnimationIfNeeded() {
            guard !self.didPlayRecoveryAnimation else {
                return
            }
            self.didPlayRecoveryAnimation = true
            self.playRecoveryAnimation.invoke(Void())
        }

        func openTerms(context: AccountContext, url: String) {
            guard let controller = self.getController() else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            context.sharedContext.openExternalUrl(
                context: context,
                urlContext: .generic,
                url: url,
                forceExternal: false,
                presentationData: presentationData,
                navigationController: controller.navigationController as? NavigationController,
                dismissInput: {}
            )
        }

        func dismiss(animated: Bool, completion: (() -> Void)? = nil) {
            guard let controller = self.getController() as? WalletInfoScreen else {
                return
            }
            if animated {
                self.animateOut.invoke(Action { [weak controller] _ in
                    controller?.dismiss(completion: nil)
                    completion?()
                })
            } else {
                controller.dismiss(animated: false)
                completion?()
            }
        }
    }

    func makeState() -> State {
        return State(
            context: self.context,
            mode: self.mode,
            animateOut: self.animateOut,
            getController: self.getController
        )
    }

    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let animation = Child(LottieComponent.self)
        let diamond = Child(InteractiveDiamondComponent.self)
        let premiumDiamond = Child(PremiumDiamondComponent.self)
        let title = Child(BalancedTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let list = Child(List<Empty>.self)
        let button = Child(ButtonComponent.self)
        let terms = Child(MultilineTextComponent.self)

        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let state = context.state
            let theme = environment.theme
            let content = walletInfoContent(
                mode: component.mode,
                fiatState: state.fiatState,
                strings: environment.strings,
                dateTimeFormat: environment.dateTimeFormat
            )

            let sideInset: CGFloat = 30.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left

            let titleFont = Font.bold(24.0)
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)

            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.list.itemSecondaryTextColor

            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: [.wallet, .gram, .firstGrams].contains(component.mode) ? 10.0 : 33.0)

            let animationSide: CGFloat = content.logo.name == "GramDiamond" ? 118.0 : 100.0
            let animationSize = CGSize(width: animationSide, height: animationSide)
            if [.wallet, .gram, .firstGrams].contains(component.mode) {
                let premiumDiamondSize = CGSize(width: context.availableSize.width, height: 164.0)
                let premiumDiamond = premiumDiamond.update(
                    component: PremiumDiamondComponent(theme: theme),
                    availableSize: premiumDiamondSize,
                    transition: context.transition
                )
                context.add(premiumDiamond
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + animationSize.height / 2.0 + 8.0))
                )
            } else if content.logo.name == "GramDiamond" {
                let diamond = diamond.update(
                    component: InteractiveDiamondComponent(
                        size: animationSize,
                        diamondWidth: 78.0,
                        isVisible: environment.isVisible,
                        theme: theme,
                        animationMode: .lottie(loop: true),
                        animateOnAppear: true
                    ),
                    availableSize: animationSize,
                    transition: context.transition
                )
                context.add(diamond
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + diamond.size.height / 2.0))
                )
            } else {
                let animation = animation.update(
                    component: LottieComponent(
                        content: LottieComponent.AppBundleContent(name: content.logo.name),
                        startingPosition: .begin,
                        size: animationSize,
                        loop: content.logo.loop,
                        playOnce: content.logo.loop ? nil : state.playRecoveryAnimation,
                        lottieSettings: component.context.lottieRenderingSettings
                    ),
                    availableSize: animationSize,
                    transition: context.transition
                )
                context.add(animation
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + animation.size.height / 2.0))
                )
                if !content.logo.loop {
                    state.playRecoveryAnimationIfNeeded()
                }
            }
            contentSize.height += animationSize.height
            contentSize.height += 8.0

            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: content.title, font: titleFont, textColor: textColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + title.size.height / 2.0))
            )
            contentSize.height += title.size.height
            contentSize.height += spacing - 8.0

            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(
                        text: content.text,
                        attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                            bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                            link: MarkdownAttributeSet(font: textFont, textColor: textColor),
                            linkAttribute: { _ in nil }
                        )
                    ),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(text
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + text.size.height / 2.0))
            )
            contentSize.height += text.size.height
            contentSize.height += spacing + 9.0

            let items: [AnyComponentWithIdentity<Empty>] = content.items.map { item in
                let itemTextColor = item.title != nil ? secondaryTextColor : textColor
                var attributedText: NSAttributedString?
                if let textIconName = item.textIconName, let range = item.text.range(of: "#"), let image = generateTintedImage(image: UIImage(bundleImageName: textIconName), color: itemTextColor) {
                    let text = NSMutableAttributedString(string: item.text, font: textFont, textColor: itemTextColor)
                    let iconRange = NSRange(range, in: item.text)
                    let placeholderWidth = text.attributedSubstring(from: iconRange).size().width
                    text.addAttributes([
                        .attachment: image,
                        .kern: image.size.width - placeholderWidth
                    ], range: iconRange)
                    attributedText = text
                }

                return AnyComponentWithIdentity(
                    id: item.id,
                    component: AnyComponent(InfoParagraphComponent(
                        title: item.title,
                        titleColor: textColor,
                        text: item.text,
                        attributedText: attributedText,
                        textColor: itemTextColor,
                        accentColor: theme.list.itemAccentColor,
                        iconName: item.iconName,
                        iconColor: theme.list.itemAccentColor
                    ))
                )
            }

            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width - sideInset - 6.0, height: 10000.0),
                transition: context.transition
            )
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0 + 12.0, y: contentSize.height + list.size.height / 2.0))
            )
            contentSize.height += list.size.height
            contentSize.height += spacing + 8.0

            let closeButton = closeButton.update(
                component: GlassBarButtonComponent(
                    size: CGSize(width: 44.0, height: 44.0),
                    backgroundColor: nil,
                    isDark: theme.overallDarkAppearance,
                    state: .glass,
                    component: AnyComponentWithIdentity(id: "close", component: AnyComponent(
                        BundleIconComponent(
                            name: "Navigation/Close",
                            tintColor: theme.chat.inputPanel.panelControlColor
                        )
                    )),
                    action: { [weak state] _ in
                        state?.dismiss(animated: true)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )

            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(Text(
                            text: content.buttonTitle,
                            font: Font.semibold(17.0),
                            color: theme.list.itemCheckColors.foregroundColor
                        ))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: { [weak state] in
                        state?.dismiss(animated: true, completion: component.completion)
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 30.0 * 2.0, height: 52.0),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height

            if case .wallet = component.mode {
                contentSize.height += 24.0

                let url = environment.strings.Wallet_TermsText_URL
                let terms = terms.update(
                    component: MultilineTextComponent(
                        text: .markdown(text: environment.strings.Wallet_TermsText, attributes: MarkdownAttributes(
                            body: MarkdownAttributeSet(font: Font.regular(13.0), textColor: secondaryTextColor),
                            bold: MarkdownAttributeSet(font: Font.semibold(13.0), textColor: secondaryTextColor),
                            link: MarkdownAttributeSet(font: Font.regular(13.0), textColor: theme.list.itemAccentColor),
                            linkAttribute: { contents in
                                return (TelegramTextAttributes.URL, contents)
                            }
                        )),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 0,
                        highlightColor: theme.list.itemAccentColor.withAlphaComponent(0.2),
                        highlightAction: { attributes in
                            if attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] != nil {
                                return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                            } else {
                                return nil
                            }
                        },
                        tapAction: { [weak state] _, _ in
                            state?.openTerms(context: component.context, url: url)
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(terms
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + terms.size.height / 2.0))
                )
                contentSize.height += terms.size.height
            }
            contentSize.height += 30.0

            return contentSize
        }
    }
}

private final class WalletInfoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let mode: WalletInfoScreenMode
    let completion: (() -> Void)?

    init(
        context: AccountContext,
        mode: WalletInfoScreenMode,
        completion: (() -> Void)?
    ) {
        self.context = context
        self.mode = mode
        self.completion = completion
    }

    static func ==(lhs: WalletInfoSheetComponent, rhs: WalletInfoSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.mode != rhs.mode {
            return false
        }
        return true
    }

    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        let sheetExternalState = SheetComponent<EnvironmentType>.ExternalState()

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller

            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(WalletInfoSheetContent(
                        context: context.component.context,
                        mode: context.component.mode,
                        completion: context.component.completion,
                        animateOut: animateOut,
                        getController: controller
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {
                    },
                    willDismiss: {
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
                            if animated {
                                if let controller = controller() as? WalletInfoScreen {
                                    animateOut.invoke(Action { _ in
                                        controller.dismiss(completion: nil)
                                    })
                                }
                            } else {
                                if let controller = controller() as? WalletInfoScreen {
                                    controller.dismiss(completion: nil)
                                }
                            }
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )

            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )

            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                var sideInset: CGFloat = 0.0
                var bottomInset: CGFloat = max(environment.safeInsets.bottom, sheetExternalState.contentHeight)
                if case .regular = environment.metrics.widthClass {
                    sideInset = floor((context.availableSize.width - 430.0) / 2.0) - 12.0
                    bottomInset = (context.availableSize.height - sheetExternalState.contentHeight) / 2.0 + sheetExternalState.contentHeight
                }

                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: bottomInset, right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: max(sideInset, environment.safeInsets.left), bottom: 0.0, right: max(sideInset, environment.safeInsets.right)),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false,
                    presentedInFormSheet: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }

            return context.availableSize
        }
    }
}

public final class WalletInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext

    public init(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
        mode: WalletInfoScreenMode,
        completion: (() -> Void)?
    ) {
        self.context = context

        super.init(
            context: context,
            component: WalletInfoSheetComponent(
                context: context,
                mode: mode,
                completion: completion
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )

        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        self.view.disablesInteractiveModalDismiss = true
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
