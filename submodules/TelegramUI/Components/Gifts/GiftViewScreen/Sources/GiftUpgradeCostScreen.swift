import Foundation
import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import TelegramPresentationData
import ComponentFlow
import ComponentDisplayAdapters
import AccountContext
import ViewControllerComponent
import MultilineTextComponent
import MultilineTextWithEntitiesComponent
import BalancedTextComponent
import ButtonComponent
import PresentationDataUtils
import LottieComponent
import ProfileLevelRatingBarComponent
import TextFormat
import TelegramStringFormatting
import TableComponent
import ResizableSheetComponent
import GlassBarButtonComponent
import BundleIconComponent

private final class GiftUpgradeCostScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let upgradePreview: StarGiftUpgradePreview
    
    init(
        context: AccountContext,
        upgradePreview: StarGiftUpgradePreview
    ) {
        self.context = context
        self.upgradePreview = upgradePreview
    }
    
    static func ==(lhs: GiftUpgradeCostScreenComponent, rhs: GiftUpgradeCostScreenComponent) -> Bool {
        return true
    }

    final class View: UIView {
        private let descriptionText = ComponentView<Empty>()
        private let bar = ComponentView<Empty>()
        private let table = ComponentView<Empty>()
        private let additionalDescription = ComponentView<Empty>()
  
        private var component: GiftUpgradeCostScreenComponent?
        private weak var state: EmptyComponentState?
        private var environment: ViewControllerComponentContainer.Environment?
        private var isUpdating: Bool = false
        
        private var upgradePreviewTimer: SwiftSignalKit.Timer?
        private var effectiveUpgradePrice: StarGiftUpgradePreview.Price?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        deinit {
        }
        
        func upgradePreviewTimerTick() {
            guard let upgradePreview = self.component?.upgradePreview else {
                return
            }
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            if let currentPrice = self.effectiveUpgradePrice {
                if let price = upgradePreview.nextPrices.reversed().first(where: { currentTime >= $0.date  }) {
                    if price.stars != currentPrice.stars {
                        self.effectiveUpgradePrice = price
                        if !self.isUpdating {
                            self.state?.updated(transition: .immediate.withUserData(ProfileLevelRatingBarComponent.TransitionHint(animate: true)))
                        }
                    }
                } else {
                    self.upgradePreviewTimer?.invalidate()
                    self.upgradePreviewTimer = nil
                }
            } else if let price = upgradePreview.nextPrices.reversed().first(where: { currentTime >= $0.date}) {
                self.effectiveUpgradePrice = price
                if !self.isUpdating {
                    self.state?.updated()
                }
            }
        }
        
        func update(component: GiftUpgradeCostScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
                                    
            let environment = environment[ViewControllerComponentContainer.Environment.self].value

            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
                       
            let isFirstTime = self.component == nil
            self.component = component
            self.state = state
            self.environment = environment
            
            if isFirstTime {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                if let _ = component.upgradePreview.nextPrices.first(where: { currentTime < $0.date }) {
                    self.upgradePreviewTimer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: { [weak self] in
                        self?.upgradePreviewTimerTick()
                    }, queue: Queue.mainQueue())
                    self.upgradePreviewTimer?.start()
                    self.upgradePreviewTimerTick()
                }
            }
            
            var contentHeight: CGFloat = 56.0
            
            var value: CGFloat = 0.0
            if let startStars = component.upgradePreview.prices.first?.stars, let endStars = component.upgradePreview.prices.last?.stars {
                let effectiveValue = self.effectiveUpgradePrice?.stars ?? endStars
                value = (CGFloat(effectiveValue - endStars) / CGFloat(startStars - endStars))
            }
            value = pow(value, 0.6)
            value = min(0.96, 1.0 - value)
            
            let barSize = self.bar.update(
                transition: transition,
                component: AnyComponent(ProfileLevelRatingBarComponent(
                    theme: environment.theme,
                    value: value,
                    leftLabel: environment.strings.Gift_UpgradeCost_Stars(Int32(clamping: component.upgradePreview.prices.first?.stars ?? 0)),
                    rightLabel: environment.strings.Gift_UpgradeCost_Stars(Int32(clamping: component.upgradePreview.prices.last?.stars ?? 0)),
                    badgeValue: "\(self.effectiveUpgradePrice?.stars ?? 0)",
                    badgeTotal: "",
                    level: 0,
                    icon: .stars,
                    inversed: true
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 110.0)
            )
            let barFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - barSize.width) * 0.5), y: contentHeight), size: barSize)
            if let barView = self.bar.view {
                if barView.superview == nil {
                    self.addSubview(barView)
                }
                transition.setFrame(view: barView, frame: barFrame)
            }
            contentHeight += barSize.height + 25.0
            
            let descriptionSize = self.descriptionText.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Gift_UpgradeCost_Description,
                        font: Font.regular(15.0),
                        textColor: environment.theme.list.itemPrimaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 3,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 50.0, height: .greatestFiniteMagnitude)
            )
            let descriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - descriptionSize.width) * 0.5), y: contentHeight), size: descriptionSize)
            if let descriptionView = self.descriptionText.view {
                if descriptionView.superview == nil {
                    self.addSubview(descriptionView)
                }
                transition.setFrame(view: descriptionView, frame: descriptionFrame)
            }
            contentHeight += descriptionSize.height + 23.0
        
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            
            var tableItems: [TableComponent.Item] = []
            for price in component.upgradePreview.prices {
                if price.date < currentTime {
                    continue
                }
                let valueString = "⭐️\(presentationStringsFormattedNumber(abs(Int32(clamping: price.stars)), environment.dateTimeFormat.groupingSeparator))"
                let valueAttributedString = NSMutableAttributedString(string: valueString, font: Font.regular(15.0), textColor: environment.theme.list.itemPrimaryTextColor)
                let range = (valueAttributedString.string as NSString).range(of: "⭐️")
                if range.location != NSNotFound {
                    valueAttributedString.addAttribute(ChatTextInputAttributes.customEmoji, value: ChatTextInputTextCustomEmojiAttribute(interactivelySelectedFromPackId: nil, fileId: 0, file: nil, custom: .stars(tinted: false)), range: range)
                    valueAttributedString.addAttribute(.baselineOffset, value: 1.0, range: range)
                }
                tableItems.append(TableComponent.Item(
                    id: price.stars,
                    title: stringForGiftUpgradeTimestamp(strings: environment.strings, dateTimeFormat: environment.dateTimeFormat, timestamp: price.date),
                    titleFont: .bold,
                    component: AnyComponent(MultilineTextWithEntitiesComponent(context: component.context, animationCache: component.context.animationCache, animationRenderer: component.context.animationRenderer, placeholderColor: .white, text: .plain(valueAttributedString)))
                ))
            }
            let tableSize = self.table.update(
                transition: transition,
                component: AnyComponent(TableComponent(
                    theme: environment.theme,
                    items: tableItems
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude)
            )
            let tableFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - tableSize.width) * 0.5), y: contentHeight), size: tableSize)
            if let tableView = self.table.view {
                if tableView.superview == nil {
                    self.addSubview(tableView)
                }
                transition.setFrame(view: tableView, frame: tableFrame)
            }
            contentHeight += tableSize.height + 15.0
            
            let additionalDescriptionSize = self.additionalDescription.update(
                transition: transition,
                component: AnyComponent(BalancedTextComponent(
                    text: .plain(NSAttributedString(
                        string: environment.strings.Gift_UpgradeCost_AdditionalDescription,
                        font: Font.regular(13.0),
                        textColor: environment.theme.list.itemSecondaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 5,
                    lineSpacing: 0.2
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0 - 50.0, height: .greatestFiniteMagnitude)
            )
            let additionalDescriptionFrame = CGRect(origin: CGPoint(x: floor((availableSize.width - additionalDescriptionSize.width) * 0.5), y: contentHeight), size: additionalDescriptionSize)
            if let additionalDescriptionView = self.additionalDescription.view {
                if additionalDescriptionView.superview == nil {
                    self.addSubview(additionalDescriptionView)
                }
                transition.setFrame(view: additionalDescriptionView, frame: additionalDescriptionFrame)
            }
            contentHeight += additionalDescriptionSize.height + 15.0
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            contentHeight += 52.0
            contentHeight += buttonInsets.bottom
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let upgradePreview: StarGiftUpgradePreview
   
    init(
        context: AccountContext,
        upgradePreview: StarGiftUpgradePreview
    ) {
        self.context = context
        self.upgradePreview = upgradePreview
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.upgradePreview != rhs.upgradePreview {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let sheet = Child(ResizableSheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
                        
        return { context in
            let component = context.component
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
            
            let theme = environment.theme
                        
            let backgroundColor = environment.theme.list.modalPlainBackgroundColor
            
            var buttonTitle: [AnyComponentWithIdentity<Empty>] = []
            let playButtonAnimation = ActionSlot<Void>()
            buttonTitle.append(AnyComponentWithIdentity(id: 0, component: AnyComponent(LottieComponent(
                content: LottieComponent.AppBundleContent(name: "anim_ok"),
                color: environment.theme.list.itemCheckColors.foregroundColor,
                startingPosition: .begin,
                size: CGSize(width: 28.0, height: 28.0),
                playOnce: playButtonAnimation
            ))))
            buttonTitle.append(AnyComponentWithIdentity(id: 1, component: AnyComponent(ButtonTextContentComponent(
                text: environment.strings.Gift_UpgradeCost_Done,
                badge: 0,
                textColor: environment.theme.list.itemCheckColors.foregroundColor,
                badgeBackground: environment.theme.list.itemCheckColors.foregroundColor,
                badgeForeground: environment.theme.list.itemCheckColors.fillColor
            ))))
            
            let sheet = sheet.update(
                component: ResizableSheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(
                        GiftUpgradeCostScreenComponent(
                            context: component.context,
                            upgradePreview: component.upgradePreview
                        )
                    ),
                    titleItem: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: environment.strings.Gift_UpgradeCost_Title, font: Font.semibold(17.0), textColor: environment.theme.actionSheet.primaryTextColor)))
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
                    rightItem: nil,
                    bottomItem: AnyComponent(
                        ButtonComponent(
                            background: ButtonComponent.Background(
                                style: .glass,
                                color: environment.theme.list.itemCheckColors.fillColor,
                                foreground: environment.theme.list.itemCheckColors.foregroundColor,
                                pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                            ),
                            content: AnyComponentWithIdentity(
                                id: AnyHashable(0),
                                component: AnyComponent(HStack(buttonTitle, spacing: 2.0))
                            ),
                            action: {
                                dismiss(true)
                            }
                        )
                    ),
                    backgroundColor: .color(backgroundColor),
                    isFullscreen: false,
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

public class GiftUpgradeCostScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private var isDismissed: Bool = false
    
    public init(
        context: AccountContext,
        upgradePreview: StarGiftUpgradePreview
    ) {
        self.context = context
        
        super.init(context: context, component: SheetContainerComponent(
            context: context,
            upgradePreview: upgradePreview
        ), navigationBarAppearance: .none, theme: .default)
        
        self.statusBar.statusBarStyle = .Ignore
        self.navigationPresentation = .flatModal
        self.blocksBackgroundWhenInOverlay = true
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
}
