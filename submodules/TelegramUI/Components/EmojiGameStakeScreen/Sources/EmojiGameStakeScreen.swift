import Foundation
import UIKit
import AsyncDisplayKit
import Display
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BalancedTextComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BundleIconComponent
import ButtonComponent
import AccountContext
import PresentationDataUtils
import ListSectionComponent
import TelegramStringFormatting
import UndoUI
import ListActionItemComponent
import PresentationDataUtils
import BalanceNeededScreen
import GlassBarButtonComponent
import GlassBackgroundComponent
import StarsBalanceOverlayComponent
import LottieComponent
import LottieComponentResourceContent
import EdgeEffect
import PlainButtonComponent
import ResizableSheetComponent

private let amountTag = GenericComponentViewTag()

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let gameInfo: EmojiGameInfo.Info
    let controller: () -> ViewController?
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        gameInfo: EmojiGameInfo.Info,
        controller: @escaping () -> ViewController?,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.gameInfo = gameInfo
        self.controller = controller
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        return true
    }
    
    static var body: (CombinedComponentContext<SheetContent>) -> CGSize {
        let description = Child(BalancedTextComponent.self)
        let resultsTitle = Child(MultilineTextComponent.self)
        let results = Child(VStack<Empty>.self)
        let resultsFooter = Child(MultilineTextWithEntitiesComponent.self)
        let amountSection = Child(ListSectionComponent.self)
        let button = Child(ButtonComponent.self)
        
        let body: (CombinedComponentContext<SheetContent>) -> CGSize = { (context: CombinedComponentContext<SheetContent>) -> CGSize in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            state.component = component
            
            let controller = environment.controller
            
            let theme = environment.theme.withModalBlocksBackground()
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            var contentSize = CGSize(width: context.availableSize.width, height: 75.0)
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
           
            let description = description.update(
                component: BalancedTextComponent(
                    text: .markdown(text: strings.EmojiStake_Description, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(description
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + description.size.height * 0.5))
            )
            contentSize.height += description.size.height
            contentSize.height += 32.0
               
            let resultsTitle = resultsTitle.update(
                component: MultilineTextComponent(text: .plain(NSAttributedString(
                    string: strings.EmojiStake_ResultsTitle.uppercased(),
                    font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                    textColor: theme.list.freeTextColor
                ))),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(resultsTitle
                .position(CGPoint(x: textSideInset + resultsTitle.size.width * 0.5, y: contentSize.height + resultsTitle.size.height * 0.5))
            )
            contentSize.height += resultsTitle.size.height
            contentSize.height += 6.0
            
            let resultSpacing: CGFloat = 8.0
            let resultSize = CGSize(width: (context.availableSize.width - sideInset * 2.0 - resultSpacing * 3.0) / 4.0, height: 64.0)
            let doubleResultSize = CGSize(width: resultSize.width * 2.0 + resultSpacing, height: resultSize.height)
            
            var resultValue1: Int32 = 0
            var resultValue2: Int32 = 300
            var resultValue3: Int32 = 600
            var resultValue4: Int32 = 1300
            var resultValue5: Int32 = 1600
            var resultValue6: Int32 = 2000
            var resultValue7: Int32 = 20000
            if context.component.gameInfo.parameters.count == 7 {
                resultValue1 = context.component.gameInfo.parameters[0]
                resultValue2 = context.component.gameInfo.parameters[1]
                resultValue3 = context.component.gameInfo.parameters[2]
                resultValue4 = context.component.gameInfo.parameters[3]
                resultValue5 = context.component.gameInfo.parameters[4]
                resultValue6 = context.component.gameInfo.parameters[5]
                resultValue7 = context.component.gameInfo.parameters[6]
            }
                        
            let results = results.update(
                component: VStack([
                    AnyComponentWithIdentity(id: "first", component: AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(id: 1, component: AnyComponent(
                                ResultCellComponent(context: component.context, theme: environment.theme, files: state.emojiFiles.flatMap { [$0[1]] }, value: resultValue1, size: resultSize)
                            )),
                            AnyComponentWithIdentity(id: 2, component: AnyComponent(
                                ResultCellComponent(context: component.context, theme: environment.theme, files: state.emojiFiles.flatMap { [$0[2]] }, value: resultValue2, size: resultSize)
                            )),
                            AnyComponentWithIdentity(id: 3, component: AnyComponent(
                                ResultCellComponent(context: component.context, theme: environment.theme, files: state.emojiFiles.flatMap { [$0[3]] }, value: resultValue3, size: resultSize)
                            )),
                            AnyComponentWithIdentity(id: 4, component: AnyComponent(
                                ResultCellComponent(context: component.context, theme: environment.theme, files: state.emojiFiles.flatMap { [$0[4]] }, value: resultValue4, size: resultSize)
                            ))
                        ], spacing: resultSpacing)
                    )),
                    AnyComponentWithIdentity(id: "second", component: AnyComponent(
                        HStack([
                            AnyComponentWithIdentity(id: 5, component: AnyComponent(
                                ResultCellComponent(context: component.context, theme: environment.theme, files: state.emojiFiles.flatMap { [$0[5]] }, value: resultValue5, size: resultSize)
                            )),
                            AnyComponentWithIdentity(id: 6, component: AnyComponent(
                                ResultCellComponent(context: component.context, theme: environment.theme, files: state.emojiFiles.flatMap { [$0[6]] }, value: resultValue6, size: resultSize)
                            )),
                            AnyComponentWithIdentity(id: 7, component: AnyComponent(
                                ResultCellComponent(context: component.context, theme: environment.theme, files: state.emojiFiles.flatMap { [$0[6], $0[6], $0[6]] }, value: resultValue7, size: doubleResultSize)
                            )),
                        ], spacing: resultSpacing)
                    ))
                ], spacing: resultSpacing),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(results
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + results.size.height * 0.5))
            )
            contentSize.height += results.size.height
            contentSize.height += 7.0
            
            let resultsFooterAttributedText = NSMutableAttributedString(
                string: strings.EmojiStake_StreakInfo,
                font: Font.regular(13.0),
                textColor: theme.list.freeTextColor
            )
            if let emojiFile = state.emojiFiles?[6] {
                let range = (resultsFooterAttributedText.string as NSString).range(of: "#")
                if range.location != NSNotFound {
                    resultsFooterAttributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: emojiFile, custom: .dice, enableAnimation: false), range: range)
                }
            }
            
            let resultsFooter = resultsFooter.update(
                component: MultilineTextWithEntitiesComponent(
                    context: component.context,
                    animationCache: component.context.animationCache,
                    animationRenderer: component.context.animationRenderer,
                    placeholderColor: .clear,
                    text: .plain(resultsFooterAttributedText),
                    maximumNumberOfLines: 0,
                    enableLooping: true
                ),
                availableSize: context.availableSize,
                transition: .immediate
            )
            context.add(resultsFooter
                .position(CGPoint(x: textSideInset + resultsFooter.size.width * 0.5, y: contentSize.height + resultsFooter.size.height * 0.5))
            )
            contentSize.height += resultsFooter.size.height
            contentSize.height += 39.0
            
            if state.cachedChevronImage == nil || state.cachedChevronImage?.1 !== environment.theme {
                state.cachedChevronImage = (generateTintedImage(image: UIImage(bundleImageName: "Contact List/SubtitleArrow"), color: environment.theme.list.itemAccentColor)!, environment.theme)
            }
           
            let configuration = EmojiGameStakeConfiguration.with(appConfiguration: component.context.currentAppConfiguration.with { $0 })
            var amountLabel = ""
            if let tonUsdRate = configuration.tonUsdRate, let value = state.amount?.value, value > 0 {
                amountLabel = "~\(formatTonUsdValue(value, divide: true, rate: tonUsdRate, dateTimeFormat: environment.dateTimeFormat))"
            }
            
            let amountItems: [AnyComponentWithIdentity<Empty>] = [
                AnyComponentWithIdentity(
                    id: "amount",
                    component: AnyComponent(
                        AmountFieldComponent(
                            textColor: theme.list.itemPrimaryTextColor,
                            secondaryColor: theme.list.itemSecondaryTextColor,
                            placeholderColor: theme.list.itemPlaceholderTextColor,
                            accentColor: theme.list.itemAccentColor,
                            value: state.amount?.value,
                            minValue: 0,
                            forceMinValue: false,
                            allowZero: true,
                            maxValue: nil,
                            placeholderText: strings.EmojiStake_StakePlaceholder,
                            labelText: amountLabel,
                            currency: .ton,
                            dateTimeFormat: presentationData.dateTimeFormat,
                            amountUpdated: { [weak state] amount in
                                state?.amount = amount.flatMap { StarsAmount(value: $0, nanos: 0) }
                                state?.updated()
                            },
                            tag: amountTag
                        )
                    )
                ),
                AnyComponentWithIdentity(id: "presets", component: AnyComponent(
                    AmountPresetsListItemComponent(
                        context: component.context,
                        theme: theme,
                        values: configuration.suggestedAmounts,
                        valueSelected: { [weak state] value in
                            guard let state else {
                                return
                            }
                            state.amount = StarsAmount(value: value, nanos: 0)
                            if let controller = controller() as? EmojiGameStakeScreen {
                                controller.dismissInput()
                                state.updated()
                                controller.resetValue()
                            }
                        }
                    )
                ))
            ]
            
            let amountSection = amountSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.EmojiStake_StakeTitle.uppercased(),
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    footer: nil,
                    items: amountItems
                ),
                environment: {},
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(amountSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + amountSection.size.height / 2.0))
                .clipsToBounds(true)
                .cornerRadius(10.0)
            )
            contentSize.height += amountSection.size.height
            contentSize.height += 24.0
           
    
            var buttonItems: [AnyComponentWithIdentity<Empty>] = []
            buttonItems.append(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Premium/Dice", tintColor: theme.list.itemCheckColors.foregroundColor))))
            buttonItems.append(AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: environment.strings.EmojiStake_Roll, font: Font.semibold(17.0), color: theme.list.itemCheckColors.foregroundColor))))
           
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
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
                        component: AnyComponent(HStack(buttonItems, spacing: 7.0))
                    ),
                    action: { [weak state] in
                        if let state, let amount = state.amount, let controller = controller() as? EmojiGameStakeScreen {
                            controller.complete(amount: amount)
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
            
            if environment.inputHeight > 0.0 {
                contentSize.height += 15.0
                contentSize.height += max(environment.inputHeight, environment.safeInsets.bottom)
            } else {
                contentSize.height += buttonInsets.bottom
            }

            return contentSize
        }
        
        return body
    }
    
    final class State: ComponentState {
        fileprivate let context: AccountContext

        fileprivate var component: SheetContent
        
        fileprivate var forceUpdateAmount = false
        fileprivate var amount: StarsAmount?
        fileprivate var currency: CurrencyAmount.Currency = .ton
        
        var cachedChevronImage: (UIImage, PresentationTheme)?

        var emojiFiles: [TelegramMediaFile]?
        var emojiFilesDisposable: Disposable?
        
        init(component: SheetContent) {
            self.context = component.context
            self.component = component
            
            let amount: StarsAmount? = StarsAmount(value: component.gameInfo.previousStake, nanos: 0)
            let currency: CurrencyAmount.Currency = .ton
            
            self.currency = currency
            self.amount = amount
            
            super.init()
            
            self.emojiFilesDisposable = (self.context.engine.stickers.loadedStickerPack(reference: .dice("🎲"), forceActualized: false)
            |> mapToSignal { stickerPack -> Signal<[TelegramMediaFile], NoError> in
                switch stickerPack {
                    case let .result(_, items, _):
                        var emojiStickers: [TelegramMediaFile] = []
                        for item in items {
                            emojiStickers.append(item.file._parse())
                        }
                        return .single(emojiStickers)
                    default:
                        return .complete()
                }
            }
            |> deliverOnMainQueue).start(next: { [weak self] files in
                guard let self else {
                    return
                }
                self.emojiFiles = files
                self.updated()
            })
        }
        
        deinit {
            self.emojiFilesDisposable?.dispose()
        }
    }
    
    func makeState() -> State {
        return State(component: self)
    }
}

private final class EmojiGameStakeSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    private let context: AccountContext
    private let gameInfo: EmojiGameInfo.Info
    
    init(
        context: AccountContext,
        gameInfo: EmojiGameInfo.Info
    ) {
        self.context = context
        self.gameInfo = gameInfo
    }
    
    static func ==(lhs: EmojiGameStakeSheetComponent, rhs: EmojiGameStakeSheetComponent) -> Bool {
        return true
    }
        
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<(EnvironmentType)>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            
            let controller = environment.controller
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    animateOut.invoke(Action { _ in
                        if let controller = controller() {
                            controller.dismiss(completion: nil)
                        }
                    })
                } else {
                    if let controller = controller() {
                        controller.dismiss(completion: nil)
                    }
                }
            }
            
            let theme = environment.theme.withModalBlocksBackground()
            
            var buttonItems: [AnyComponentWithIdentity<Empty>] = []
            buttonItems.append(AnyComponentWithIdentity(id: "icon", component: AnyComponent(Image(image: PresentationResourcesItemList.itemListRoundTopupIcon(environment.theme), tintColor: theme.list.itemCheckColors.foregroundColor, size: CGSize(width: 16.0, height: 18.0)))))
            buttonItems.append(AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: environment.strings.EmojiStake_Roll, font: Font.semibold(17.0), color: theme.list.itemCheckColors.foregroundColor))))
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        gameInfo: context.component.gameInfo,
                        controller: {
                            return controller()
                        },
                        dismiss: {
                            dismiss(true)
                        }
                    )),
                    titleItem: AnyComponent(
                        Text(text: environment.strings.EmojiStake_Title, font: Font.bold(17.0), color: theme.list.itemPrimaryTextColor)
                    ),
                    leftItem: AnyComponent(
                        GlassBarButtonComponent(
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
                            action: { _ in
                                dismiss(true)
                            }
                        )
                    ),
//                    bottomItem: AnyComponent(
//                        ButtonComponent(
//                            background: ButtonComponent.Background(
//                                style: .glass,
//                                color: theme.list.itemCheckColors.fillColor,
//                                foreground: theme.list.itemCheckColors.foregroundColor,
//                                pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
//                            ),
//                            content: AnyComponentWithIdentity(
//                                id: AnyHashable(0),
//                                component: AnyComponent(HStack(buttonItems, spacing: 7.0))
//                            ),
//                            isEnabled: true,
//                            displaysProgress: false,
//                            action: {
//                                dismiss(true)
//                            }
//                        )
//                    ),
                    backgroundColor: .color(theme.list.blocksBackgroundColor),
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    ResizableSheetComponentEnvironment(
                        theme: theme,
                        statusBarHeight: environment.statusBarHeight,
                        safeInsets: environment.safeInsets,
                        metrics: environment.metrics,
                        deviceMetrics: environment.deviceMetrics,
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        screenSize: context.availableSize,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
                            dismiss(animated)
                        }
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            return context.availableSize
        }
    }
}

public final class EmojiGameStakeScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    fileprivate let completion: (StarsAmount) -> Void
    
    fileprivate let balanceOverlay = ComponentView<Empty>()
    private var showBalance = true
    
    public init(
        context: AccountContext,
        gameInfo: EmojiGameInfo.Info,
        completion: @escaping (StarsAmount) -> Void
    ) {
        self.context = context
        self.completion = completion
        
        super.init(
            context: context,
            component: EmojiGameStakeSheetComponent(
                context: context,
                gameInfo: gameInfo
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        
        self.context.tonContext?.load(force: true)
    }
        
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    fileprivate func dismissInput() {
        if let view = self.node.hostView.findTaggedView(tag: amountTag) as? AmountFieldComponent.View {
            view.deactivateInput()
        }
    }
    
    fileprivate func resetValue() {
        if let view = self.node.hostView.findTaggedView(tag: amountTag) as? AmountFieldComponent.View {
            view.resetValue()
        }
    }
        
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? ResizableSheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
    
    func complete(amount: StarsAmount) {
        if let tonState = self.context.tonContext?.currentState, tonState.balance < amount {
            let needed = amount - tonState.balance
            var fragmentUrl = "https://fragment.com/ads/topup"
            if let data = self.context.currentAppConfiguration.with({ $0 }).data, let value = data["ton_topup_url"] as? String {
                fragmentUrl = value
            }
            self.push(BalanceNeededScreen(
                context: self.context,
                amount: needed,
                buttonAction: { [weak self] in
                    self?.context.sharedContext.applicationBindings.openUrl(fragmentUrl)
                }
            ))
        } else {
            self.completion(amount)
            self.dismissAnimated()
        }
    }
    
    func dismissBalanceOverlay() {
        if let view = self.balanceOverlay.view, view.superview != nil {
            view.alpha = 0.0
            view.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4)
            view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { _ in
                view.removeFromSuperview()
                view.alpha = 1.0
            })
        }
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        if self.showBalance {
            let context = self.context
            let insets = layout.insets(options: .statusBar)
            let balanceSize = self.balanceOverlay.update(
                transition: .immediate,
                component: AnyComponent(
                    StarsBalanceOverlayComponent(
                        context: context,
                        peerId: context.account.peerId,
                        theme: context.sharedContext.currentPresentationData.with { $0 }.theme,
                        currency: .ton,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            var fragmentUrl = "https://fragment.com/ads/topup"
                            if let data = context.currentAppConfiguration.with({ $0 }).data, let value = data["ton_topup_url"] as? String {
                                fragmentUrl = value
                            }
                            context.sharedContext.applicationBindings.openUrl(fragmentUrl)
                            
                            self.dismissAnimated()
                        }
                    )
                ),
                environment: {},
                containerSize: layout.size
            )
            if let view = self.balanceOverlay.view {
                if view.superview == nil {
                    self.view.addSubview(view)
                    
                    view.layer.animatePosition(from: CGPoint(x: 0.0, y: -64.0), to: .zero, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, additive: true)
                    view.layer.animateSpring(from: 0.8 as NSNumber, to: 1.0 as NSNumber, keyPath: "transform.scale", duration: 0.5, initialVelocity: 0.0, removeOnCompletion: true, additive: false, completion: nil)
                    view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                }
                view.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - balanceSize.width) / 2.0), y: insets.top + 5.0), size: balanceSize)
            }
        } else if let view = self.balanceOverlay.view, view.superview != nil {
            view.alpha = 0.0
            view.layer.animateScale(from: 1.0, to: 0.8, duration: 0.4)
            view.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.3, completion: { _ in
                view.removeFromSuperview()
                view.alpha = 1.0
            })
        }
    }
}

private final class AmountFieldStarsFormatter: NSObject, UITextFieldDelegate {
    private let currency: CurrencyAmount.Currency
    private let dateTimeFormat: PresentationDateTimeFormat
    
    private let textField: UITextField
    private let minValue: Int64
    private let forceMinValue: Bool
    private let allowZero: Bool
    private let maxValue: Int64
    private let updated: (Int64) -> Void
    private let isEmptyUpdated: (Bool) -> Void
    private let animateError: () -> Void
    private let focusUpdated: (Bool) -> Void

    init?(textField: UITextField, currency: CurrencyAmount.Currency, dateTimeFormat: PresentationDateTimeFormat, minValue: Int64, forceMinValue: Bool, allowZero: Bool, maxValue: Int64, updated: @escaping (Int64) -> Void, isEmptyUpdated: @escaping (Bool) -> Void, animateError: @escaping () -> Void, focusUpdated: @escaping (Bool) -> Void) {
        self.textField = textField
        self.currency = currency
        self.dateTimeFormat = dateTimeFormat
        self.minValue = minValue
        self.forceMinValue = forceMinValue
        self.allowZero = allowZero
        self.maxValue = maxValue
        self.updated = updated
        self.isEmptyUpdated = isEmptyUpdated
        self.animateError = animateError
        self.focusUpdated = focusUpdated

        super.init()
    }
    
    func amountFrom(text: String) -> Int64 {
        var amount: Int64?
        if !text.isEmpty {
            switch self.currency {
            case .stars:
                if let value = Int64(text) {
                    amount = value
                }
            case .ton:
                let scale: Int64 = 1_000_000_000  // 10⁹  (one “nano”)
                if let decimalSeparator = self.dateTimeFormat.decimalSeparator.first, let dot = text.firstIndex(of: decimalSeparator) {
                    // Slices for the parts on each side of the dot
                    var wholeSlice = String(text[..<dot])
                    if wholeSlice.isEmpty {
                        wholeSlice = "0"
                    }
                    let fractionSlice  = text[text.index(after: dot)...]

                    // Make the fractional string exactly 9 characters long
                    var fractionStr = String(fractionSlice)
                    if fractionStr.count > 9 {
                        fractionStr = String(fractionStr.prefix(9))      // trim extra digits
                    } else {
                        fractionStr = fractionStr.padding(
                            toLength: 9, withPad: "0", startingAt: 0)     // pad with zeros
                    }

                    // Convert and combine
                    if let whole = Int64(wholeSlice),
                       let frac  = Int64(fractionStr) {
                        
                        let whole = min(whole, Int64.max / scale)
                        
                        amount = whole * scale + frac
                    }
                } else if let whole = Int64(text) {   // string had no dot at all
                    let whole = min(whole, Int64.max / scale)
                    
                    amount = whole * scale
                }
            }
        }
        return amount ?? 0
    }

    func onTextChanged(text: String) {
        self.updated(self.amountFrom(text: text))
        self.isEmptyUpdated(text.isEmpty)
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        var acceptZero = false
        if case .ton = self.currency, self.minValue < 1_000_000_000 {
            acceptZero = true
        }
        
        var newText = ((textField.text ?? "") as NSString).replacingCharacters(in: range, with: string)
        if newText.contains(where: { c in
            switch c {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                return false
            default:
                if case .ton = self.currency {
                    if let decimalSeparator = self.dateTimeFormat.decimalSeparator.first, c == decimalSeparator {
                        return false
                    }
                }
                return true
            }
        }) {
            return false
        }
        if let decimalSeparator = self.dateTimeFormat.decimalSeparator.first, newText.count(where: { $0 == decimalSeparator }) > 1 {
            return false
        }
        
        switch self.currency {
        case .stars:
            if (newText == "0" && !acceptZero) || (newText.count > 1 && newText.hasPrefix("0")) {
                newText.removeFirst()
                textField.text = newText
                self.onTextChanged(text: newText)
                return false
            }
        case .ton:
            var fixedText = false
            if let decimalSeparator = self.dateTimeFormat.decimalSeparator.first, let index = newText.firstIndex(of: decimalSeparator) {
                let fractionalString = newText[newText.index(after: index)...]
                if fractionalString.count > 2 {
                    newText = String(newText[newText.startIndex ..< newText.index(index, offsetBy: 3)])
                    fixedText = true
                }
            }
            
            if newText == self.dateTimeFormat.decimalSeparator {
                if !acceptZero {
                    newText.removeFirst()
                } else {
                    newText = "0\(newText)"
                }
                fixedText = true
            }
            
            if (newText == "0" && !acceptZero) || (newText.count > 1 && newText.hasPrefix("0") && !newText.hasPrefix("0\(self.dateTimeFormat.decimalSeparator)")) {
                newText.removeFirst()
                fixedText = true
            }
            
            if fixedText {
                textField.text = newText
                self.onTextChanged(text: newText)
                return false
            }
        }
        
        let amount: Int64 = self.amountFrom(text: newText)
        if self.forceMinValue && amount < self.minValue {
            switch self.currency {
            case .stars:
                textField.text = "\(self.minValue)"
            case .ton:
                textField.text = "\(formatTonAmountText(self.minValue, dateTimeFormat: PresentationDateTimeFormat(timeFormat: self.dateTimeFormat.timeFormat, dateFormat: self.dateTimeFormat.dateFormat, dateSeparator: "", dateSuffix: "", requiresFullYear: false, decimalSeparator: self.dateTimeFormat.decimalSeparator, groupingSeparator: ""), maxDecimalPositions: nil))"
            }
            self.onTextChanged(text: self.textField.text ?? "")
            self.animateError()
            return false
        } else if amount > self.maxValue {
            switch self.currency {
            case .stars:
                textField.text = "\(self.maxValue)"
            case .ton:
                textField.text = "\(formatTonAmountText(self.maxValue, dateTimeFormat: PresentationDateTimeFormat(timeFormat: self.dateTimeFormat.timeFormat, dateFormat: self.dateTimeFormat.dateFormat, dateSeparator: "", dateSuffix: "", requiresFullYear: false, decimalSeparator: self.dateTimeFormat.decimalSeparator, groupingSeparator: ""), maxDecimalPositions: nil))"
            }
            self.onTextChanged(text: self.textField.text ?? "")
            self.animateError()
            return false
        }
        
        self.onTextChanged(text: newText)
        
        return true
    }
}

public final class AmountFieldComponent: Component {
    public typealias EnvironmentType = Empty
    
    let textColor: UIColor
    let secondaryColor: UIColor
    let placeholderColor: UIColor
    let accentColor: UIColor
    let value: Int64?
    let minValue: Int64?
    let forceMinValue: Bool
    let allowZero: Bool
    let maxValue: Int64?
    let placeholderText: String
    let textFieldOffset: CGPoint
    let labelText: String?
    let currency: CurrencyAmount.Currency
    let dateTimeFormat: PresentationDateTimeFormat
    let amountUpdated: (Int64?) -> Void
    let tag: AnyObject?
    
    public init(
        textColor: UIColor,
        secondaryColor: UIColor,
        placeholderColor: UIColor,
        accentColor: UIColor,
        value: Int64?,
        minValue: Int64?,
        forceMinValue: Bool,
        allowZero: Bool,
        maxValue: Int64?,
        placeholderText: String,
        textFieldOffset: CGPoint = .zero,
        labelText: String?,
        currency: CurrencyAmount.Currency,
        dateTimeFormat: PresentationDateTimeFormat,
        amountUpdated: @escaping (Int64?) -> Void,
        tag: AnyObject? = nil
    ) {
        self.textColor = textColor
        self.secondaryColor = secondaryColor
        self.placeholderColor = placeholderColor
        self.accentColor = accentColor
        self.value = value
        self.minValue = minValue
        self.forceMinValue = forceMinValue
        self.allowZero = allowZero
        self.maxValue = maxValue
        self.placeholderText = placeholderText
        self.textFieldOffset = textFieldOffset
        self.labelText = labelText
        self.currency = currency
        self.dateTimeFormat = dateTimeFormat
        self.amountUpdated = amountUpdated
        self.tag = tag
    }
    
    public static func ==(lhs: AmountFieldComponent, rhs: AmountFieldComponent) -> Bool {
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.secondaryColor != rhs.secondaryColor {
            return false
        }
        if lhs.placeholderColor != rhs.placeholderColor {
            return false
        }
        if lhs.accentColor != rhs.accentColor {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.minValue != rhs.minValue {
            return false
        }
        if lhs.allowZero != rhs.allowZero {
            return false
        }
        if lhs.maxValue != rhs.maxValue {
            return false
        }
        if lhs.placeholderText != rhs.placeholderText {
            return false
        }
        if lhs.labelText != rhs.labelText {
            return false
        }
        if lhs.currency != rhs.currency {
            return false
        }
        return true
    }
    
    public final class View: UIView, ListSectionComponent.ChildView, UITextFieldDelegate, ComponentTaggedView {
        public func matches(tag: Any) -> Bool {
            if let component = self.component, let componentTag = component.tag {
                let tag = tag as AnyObject
                if componentTag === tag {
                    return true
                }
            }
            return false
        }
        
        private let placeholderView: ComponentView<Empty>
        private let icon = ComponentView<Empty>()
        private let textField: TextFieldNodeView
        private var starsFormatter: AmountFieldStarsFormatter?
        private var tonFormatter: AmountFieldStarsFormatter?
        private let labelView: ComponentView<Empty>
        
        private var component: AmountFieldComponent?
        private weak var state: EmptyComponentState?
        private var isUpdating: Bool = false
        
        private var didSetValueOnce = false
        
        public var customUpdateIsHighlighted: ((Bool) -> Void)?
        public var enumerateSiblings: (((UIView) -> Void) -> Void)?
        public let separatorInset: CGFloat = 16.0
        
        public override init(frame: CGRect) {
            self.placeholderView = ComponentView<Empty>()
            self.textField = TextFieldNodeView(frame: .zero)
            self.labelView = ComponentView<Empty>()
            
            super.init(frame: frame)
            
            self.addSubview(self.textField)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        public func activateInput() {
            self.textField.becomeFirstResponder()
        }
        
        public func deactivateInput() {
            self.textField.resignFirstResponder()
        }
        
        public func selectAll() {
            self.textField.selectAll(nil)
        }
                
        public func animateError() {
            self.textField.layer.addShakeAnimation()
            let hapticFeedback = HapticFeedback()
            hapticFeedback.error()
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1.0, execute: {
                let _ = hapticFeedback
            })
        }
        
        public func resetValue() {
            guard let component = self.component, let value = component.value else {
                return
            }
            var text = ""
            switch component.currency {
            case .stars:
                text = "\(value)"
            case .ton:
                text = "\(formatTonAmountText(value, dateTimeFormat: PresentationDateTimeFormat(timeFormat: component.dateTimeFormat.timeFormat, dateFormat: component.dateTimeFormat.dateFormat, dateSeparator: "", dateSuffix: "", requiresFullYear: false, decimalSeparator: ".", groupingSeparator: ""), maxDecimalPositions: nil))"
            }
            self.textField.text = text
            self.placeholderView.view?.isHidden = !(self.textField.text ?? "").isEmpty
        }
        
        func update(component: AmountFieldComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            
            self.textField.textColor = component.textColor
            if self.component?.currency != component.currency || ((self.textField.text ?? "").isEmpty && !self.didSetValueOnce) {
                if let value = component.value, value != .zero {
                    var text = ""
                    switch component.currency {
                    case .stars:
                        text = "\(value)"
                    case .ton:
                        text = "\(formatTonAmountText(value, dateTimeFormat: PresentationDateTimeFormat(timeFormat: component.dateTimeFormat.timeFormat, dateFormat: component.dateTimeFormat.dateFormat, dateSeparator: "", dateSuffix: "", requiresFullYear: false, decimalSeparator: ".", groupingSeparator: ""), maxDecimalPositions: nil))"
                    }
                    self.textField.text = text
                    self.placeholderView.view?.isHidden = !text.isEmpty
                } else {
                    self.textField.text = ""
                }
                self.didSetValueOnce = true
            }
            self.textField.font = Font.regular(17.0)
            
            self.textField.returnKeyType = .done
            self.textField.autocorrectionType = .no
            self.textField.autocapitalizationType = .none
            
            if self.component?.currency != component.currency {
                switch component.currency {
                case .stars:
                    self.textField.delegate = self
                    self.textField.keyboardType = .numberPad
                    if self.starsFormatter == nil {
                        self.starsFormatter = AmountFieldStarsFormatter(
                            textField: self.textField,
                            currency: component.currency,
                            dateTimeFormat: component.dateTimeFormat,
                            minValue: component.minValue ?? 0,
                            forceMinValue: component.forceMinValue,
                            allowZero: component.allowZero,
                            maxValue: component.maxValue ?? Int64.max,
                            updated: { [weak self] value in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if !self.isUpdating {
                                    component.amountUpdated(value == 0 ? nil : value)
                                }
                            },
                            isEmptyUpdated: { [weak self] isEmpty in
                                guard let self else {
                                    return
                                }
                                self.placeholderView.view?.isHidden = !isEmpty
                            },
                            animateError: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.animateError()
                            },
                            focusUpdated: { _ in
                            }
                        )
                    }
                    self.tonFormatter = nil
                    self.textField.delegate = self.starsFormatter
                case .ton:
                    self.textField.keyboardType = .decimalPad
                    if self.tonFormatter == nil {
                        self.tonFormatter = AmountFieldStarsFormatter(
                            textField: self.textField,
                            currency: component.currency,
                            dateTimeFormat: component.dateTimeFormat,
                            minValue: component.minValue ?? 0,
                            forceMinValue: component.forceMinValue,
                            allowZero: component.allowZero,
                            maxValue: component.maxValue ?? Int64.max,
                            updated: { [weak self] value in
                                guard let self, let component = self.component else {
                                    return
                                }
                                if !self.isUpdating {
                                    component.amountUpdated(value == 0 ? nil : value)
                                }
                            },
                            isEmptyUpdated: { [weak self] isEmpty in
                                guard let self else {
                                    return
                                }
                                self.placeholderView.view?.isHidden = !isEmpty
                            },
                            animateError: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.animateError()
                            },
                            focusUpdated: { _ in
                            }
                        )
                    }
                    self.starsFormatter = nil
                    self.textField.delegate = self.tonFormatter
                }
                self.textField.reloadInputViews()
            }
                        
            self.component = component
            self.state = state
                       
            let size = CGSize(width: availableSize.width, height: 52.0)
            
            let sideInset: CGFloat = 16.0
            var leftInset: CGFloat = 16.0
            
            let iconName: String
            var iconTintColor: UIColor?
            let iconMaxSize: CGSize?
            var iconOffset = CGPoint()
            switch component.currency {
            case .stars:
                iconName = "Premium/Stars/StarLarge"
                iconMaxSize = CGSize(width: 22.0, height: 22.0)
            case .ton:
                iconName = "Ads/TonBig"
                iconTintColor = component.accentColor
                iconMaxSize = CGSize(width: 18.0, height: 18.0)
                iconOffset = CGPoint(x: 3.0, y: 1.0)
            }
            let iconSize = self.icon.update(
                transition: .immediate,
                component: AnyComponent(BundleIconComponent(
                    name: iconName,
                    tintColor: iconTintColor,
                    maxSize: iconMaxSize
                )),
                environment: {},
                containerSize: CGSize(width: 100.0, height: 100.0)
            )
            
            if let iconView = self.icon.view {
                if iconView.superview == nil {
                    self.addSubview(iconView)
                }
                iconView.frame = CGRect(origin: CGPoint(x: iconOffset.x + 15.0, y: iconOffset.y - 1.0 + floorToScreenPixels((size.height - iconSize.height) / 2.0)), size: iconSize)
            }
            
            leftInset += 24.0 + 6.0
            
            let placeholderSize = self.placeholderView.update(
                transition: .easeInOut(duration: 0.2),
                component: AnyComponent(
                    Text(
                        text: component.placeholderText,
                        font: Font.regular(17.0),
                        color: component.placeholderColor
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            
            if let placeholderComponentView = self.placeholderView.view {
                if placeholderComponentView.superview == nil {
                    self.insertSubview(placeholderComponentView, at: 0)
                }
                
                placeholderComponentView.frame = CGRect(origin: CGPoint(x: leftInset, y: -1.0 + floorToScreenPixels((size.height - placeholderSize.height) / 2.0) + 1.0 - UIScreenPixel), size: placeholderSize)
                placeholderComponentView.isHidden = !(self.textField.text ?? "").isEmpty
            }
            
            if let labelText = component.labelText {
                let labelSize = self.labelView.update(
                    transition: .immediate,
                    component: AnyComponent(
                        Text(
                            text: labelText,
                            font: Font.regular(17.0),
                            color: component.secondaryColor
                        )
                    ),
                    environment: {},
                    containerSize: availableSize
                )
                
                if let labelView = self.labelView.view {
                    if labelView.superview == nil {
                        self.insertSubview(labelView, at: 0)
                    }
                    
                    labelView.frame = CGRect(origin: CGPoint(x: size.width - sideInset - labelSize.width, y: floorToScreenPixels((size.height - labelSize.height) / 2.0) + 1.0 - UIScreenPixel), size: labelSize)
                }
            } else if let labelView = self.labelView.view, labelView.superview != nil {
                labelView.removeFromSuperview()
            }
            
            self.textField.frame = CGRect(x: leftInset + component.textFieldOffset.x, y: 4.0 + component.textFieldOffset.y, width: size.width - 30.0, height: 44.0)
                        
            return size
        }
    }

    public func makeView() -> View {
        return View(frame: CGRect())
    }
    
    public func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class ResultCellComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let files: [TelegramMediaFile]?
    let value: Int32
    let size: CGSize
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        files: [TelegramMediaFile]?,
        value: Int32,
        size: CGSize
    ) {
        self.context = context
        self.theme = theme
        self.files = files
        self.value = value
        self.size = size
    }

    static func ==(lhs: ResultCellComponent, rhs: ResultCellComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.files != rhs.files {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        if lhs.size != rhs.size {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: ResultCellComponent?
        
        private let background = ComponentView<Empty>()
        private let emoji = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
                
        override init(frame: CGRect) {
            
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: ResultCellComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let size = component.size
            
            let backgroundSize = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(color: component.theme.list.itemBlocksBackgroundColor, cornerRadius: .value(22.0), smoothCorners: true)),
                environment: {},
                containerSize: size
            )
            let backgroundFrame = CGRect(origin: .zero, size: backgroundSize)
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            let value = Double(component.value) / 1000.0
            let titleString = String(format: "%0.1f", value).replacingOccurrences(of: ".0", with: "").replacingOccurrences(of: ",0", with: "")
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            if let files = component.files {
                for file in files {
                    items.append(AnyComponentWithIdentity(id: items.count, component: AnyComponent(
                        LottieComponent(
                            content: LottieComponent.ResourceContent(
                                context: component.context,
                                file: file,
                                attemptSynchronously: true,
                                providesPlaceholder: true
                            ),
                            placeholderColor: component.theme.list.mediaPlaceholderColor,
                            startingPosition: .end,
                            size: CGSize(width: 50.0, height: 50.0),
                            loop: false
                        )
                    )))
                }
            }
            let emojiSize = self.emoji.update(
                transition: transition,
                component: AnyComponent(
                    HStack(items, spacing: -18.0)
                ),
                environment: {},
                containerSize: availableSize
            )
            let emojiFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - emojiSize.width) / 2.0), y: -9.0), size: emojiSize)
            if let emojiView = self.emoji.view {
                if emojiView.superview == nil {
                    self.addSubview(emojiView)
                }
                transition.setFrame(view: emojiView, frame: emojiFrame)
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: "×\(titleString)", font: Font.semibold(11.0), textColor: component.theme.list.itemPrimaryTextColor)),
                        horizontalAlignment: .center,
                        maximumNumberOfLines: 1
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: size.height - titleSize.height - 10.0), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class AmountPresetsListItemComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let values: [Int64]
    let valueSelected: (Int64) -> Void
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        values: [Int64],
        valueSelected: @escaping (Int64) -> Void
    ) {
        self.context = context
        self.theme = theme
        self.values = values
        self.valueSelected = valueSelected
    }

    static func ==(lhs: AmountPresetsListItemComponent, rhs: AmountPresetsListItemComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.values != rhs.values {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: AmountPresetsListItemComponent?
        
        private var itemViews: [Int64: ComponentView<Empty>] = [:]
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AmountPresetsListItemComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            
            let sideInset: CGFloat = 16.0
            let spacing: CGFloat = 6.0
            let itemSize = CGSize(width: floorToScreenPixels((availableSize.width - sideInset * 2.0 - spacing * 2.0) / 3.0), height: 28.0)
            
            var itemOrigin = CGPoint(x: sideInset, y: sideInset)
            for value in component.values {
                let itemView: ComponentView<Empty>
                if let current = self.itemViews[value] {
                    itemView = current
                } else {
                    itemView = ComponentView()
                    self.itemViews[value] = itemView
                }
                let _ = itemView.update(
                    transition: .immediate,
                    component: AnyComponent(PlainButtonComponent(
                        content: AnyComponent(AmountPresetComponent(
                            context: component.context,
                            theme: component.theme,
                            value: value
                        )),
                        action: {
                            component.valueSelected(value)
                        },
                        animateScale: false
                    )),
                    environment: {},
                    containerSize: itemSize
                )
                var itemFrame = CGRect(origin: itemOrigin, size: itemSize)
                if itemFrame.maxX > availableSize.width {
                    itemOrigin = CGPoint(x: sideInset, y: itemOrigin.y + itemSize.height + spacing)
                    itemFrame.origin = itemOrigin
                }
                if let itemView = itemView.view {
                    if itemView.superview == nil {
                        self.addSubview(itemView)
                    }
                    transition.setFrame(view: itemView, frame: itemFrame)
                }
                itemOrigin.x += itemSize.width + spacing
            }
            
            let size = CGSize(width: availableSize.width, height: itemOrigin.y + itemSize.height + sideInset)
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class AmountPresetComponent: Component {
    let context: AccountContext
    let theme: PresentationTheme
    let value: Int64
    
    init(
        context: AccountContext,
        theme: PresentationTheme,
        value: Int64
    ) {
        self.context = context
        self.theme = theme
        self.value = value
    }

    static func ==(lhs: AmountPresetComponent, rhs: AmountPresetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    final class View: UIView {
        private var component: AmountPresetComponent?
        
        private let background = ComponentView<Empty>()
        private let title = ComponentView<Empty>()
                
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: AmountPresetComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            
            let size = availableSize
            
            let backgroundSize = self.background.update(
                transition: transition,
                component: AnyComponent(FilledRoundedRectangleComponent(color: component.theme.list.itemAccentColor.withMultipliedAlpha(0.1), cornerRadius: .minEdge, smoothCorners: false)),
                environment: {},
                containerSize: size
            )
            let backgroundFrame = CGRect(origin: .zero, size: backgroundSize)
            if let backgroundView = self.background.view {
                if backgroundView.superview == nil {
                    self.addSubview(backgroundView)
                }
                transition.setFrame(view: backgroundView, frame: backgroundFrame)
            }
            
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            
            let attributedText = NSMutableAttributedString(string: "$ \(formatTonAmountText(component.value, dateTimeFormat: presentationData.dateTimeFormat))", font: Font.semibold(14.0), textColor: component.theme.list.itemAccentColor)
            if let range = attributedText.string.range(of: "$") {
                attributedText.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .ton(tinted: true)), range: NSRange(range, in: attributedText.string))
                attributedText.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: attributedText.string))
            }
            
            let titleSize = self.title.update(
                transition: transition,
                component: AnyComponent(
                    MultilineTextWithEntitiesComponent(
                        context: component.context,
                        animationCache: component.context.animationCache,
                        animationRenderer: component.context.animationRenderer,
                        placeholderColor: .clear,
                        text: .plain(attributedText)
                    )
                ),
                environment: {},
                containerSize: availableSize
            )
            let titleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((size.width - titleSize.width) / 2.0), y: floorToScreenPixels((size.height - titleSize.height) / 2.0)), size: titleSize)
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                transition.setFrame(view: titleView, frame: titleFrame)
            }
            
            return size
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private struct EmojiGameStakeConfiguration {
    static var defaultValue: EmojiGameStakeConfiguration {
        return EmojiGameStakeConfiguration(
            tonUsdRate: nil,
            minStakeAmount: nil,
            maxStakeAmount: nil,
            suggestedAmounts: [
                100000000,
                1000000000,
                2000000000,
                5000000000,
                10000000000,
                20000000000
            ]
        )
    }
    
    let tonUsdRate: Double?
    let minStakeAmount: Int64?
    let maxStakeAmount: Int64?
    let suggestedAmounts: [Int64]
        
    fileprivate init(
        tonUsdRate: Double?,
        minStakeAmount: Int64?,
        maxStakeAmount: Int64?,
        suggestedAmounts: [Int64]
    ) {
        self.tonUsdRate = tonUsdRate
        self.minStakeAmount = minStakeAmount
        self.maxStakeAmount = maxStakeAmount
        self.suggestedAmounts = suggestedAmounts
    }
    
    static func with(appConfiguration: AppConfiguration) -> EmojiGameStakeConfiguration {
        if let data = appConfiguration.data {
            var tonUsdRate: Double?
            if let value = data["ton_usd_rate"] as? Double {
                tonUsdRate = value
            }
            
            var minStakeAmount: Int64?
            if let value = data["ton_stakedice_stake_amount_min"] as? Double {
                minStakeAmount = Int64(value)
            }
            
            var maxStakeAmount: Int64?
            if let value = data["ton_stakedice_stake_amount_max"] as? Double {
                maxStakeAmount = Int64(value)
            }
            
            var suggestedAmounts: [Int64] = []
            if let value = data["ton_stakedice_stake_suggested_amounts"] as? [Double] {
                suggestedAmounts = value.map { Int64($0) }
            } else {
                suggestedAmounts = EmojiGameStakeConfiguration.defaultValue.suggestedAmounts
            }
            
            return EmojiGameStakeConfiguration(
                tonUsdRate: tonUsdRate,
                minStakeAmount: minStakeAmount,
                maxStakeAmount: maxStakeAmount,
                suggestedAmounts: suggestedAmounts
            )
        } else {
            return .defaultValue
        }
    }
}
