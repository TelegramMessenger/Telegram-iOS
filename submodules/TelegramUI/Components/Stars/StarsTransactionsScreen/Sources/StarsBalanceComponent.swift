import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import AccountContext
import MultilineTextComponent
import TelegramPresentationData
import PresentationDataUtils
import ButtonComponent
import BundleIconComponent
import TelegramStringFormatting
import TelegramCore

final class StarsBalanceComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let count: StarsAmount
    let currency: CurrencyAmount.Currency
    let rate: Double?
    let actionTitle: String
    let actionAvailable: Bool
    let actionIsEnabled: Bool
    let actionCooldownUntilTimestamp: Int32?
    let actionIcon: UIImage?
    let action: () -> Void
    let secondaryActionTitle: String?
    let secondaryActionIcon: UIImage?
    let secondaryActionCooldownUntilTimestamp: Int32?
    let secondaryAction: (() -> Void)?
    let additionalAction: AnyComponent<Empty>?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        count: StarsAmount,
        currency: CurrencyAmount.Currency,
        rate: Double?,
        actionTitle: String,
        actionAvailable: Bool,
        actionIsEnabled: Bool,
        actionCooldownUntilTimestamp: Int32? = nil,
        actionIcon: UIImage? = nil,
        action: @escaping () -> Void,
        secondaryActionTitle: String? = nil,
        secondaryActionIcon: UIImage? = nil,
        secondaryActionCooldownUntilTimestamp: Int32? = nil,
        secondaryAction: (() -> Void)? = nil,
        additionalAction: AnyComponent<Empty>? = nil
    ) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.count = count
        self.currency = currency
        self.rate = rate
        self.actionTitle = actionTitle
        self.actionAvailable = actionAvailable
        self.actionIsEnabled = actionIsEnabled
        self.actionCooldownUntilTimestamp = actionCooldownUntilTimestamp
        self.actionIcon = actionIcon
        self.action = action
        self.secondaryActionTitle = secondaryActionTitle
        self.secondaryActionCooldownUntilTimestamp = secondaryActionCooldownUntilTimestamp
        self.secondaryActionIcon = secondaryActionIcon
        self.secondaryAction = secondaryAction
        self.additionalAction = additionalAction
    }
    
    static func ==(lhs: StarsBalanceComponent, rhs: StarsBalanceComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.dateTimeFormat != rhs.dateTimeFormat {
            return false
        }
        if lhs.actionTitle != rhs.actionTitle {
            return false
        }
        if lhs.actionAvailable != rhs.actionAvailable {
            return false
        }
        if lhs.actionIsEnabled != rhs.actionIsEnabled {
            return false
        }
        if lhs.actionCooldownUntilTimestamp != rhs.actionCooldownUntilTimestamp {
            return false
        }
        if lhs.secondaryActionTitle != rhs.secondaryActionTitle {
            return false
        }
        if lhs.secondaryActionCooldownUntilTimestamp != rhs.secondaryActionCooldownUntilTimestamp {
            return false
        }
        if lhs.count != rhs.count {
            return false
        }
        if lhs.currency != rhs.currency {
            return false
        }
        if lhs.rate != rhs.rate {
            return false
        }
        return true
    }
    
    final class View: UIView {
        private let icon = UIImageView()
        private let title = ComponentView<Empty>()
        private let subtitle = ComponentView<Empty>()
        private var button = ComponentView<Empty>()
        private var secondaryButton = ComponentView<Empty>()
        
        private var additionalButton = ComponentView<Empty>()
        
        private var component: StarsBalanceComponent?
        private weak var state: EmptyComponentState?
        
        private var timer: Timer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.addSubview(self.icon)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StarsBalanceComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            if self.component == nil {
                switch component.currency {
                case .ton:
                    self.icon.image = generateTintedImage(image: UIImage(bundleImageName: "Ads/TonBig"), color: component.theme.list.itemAccentColor)
                case .stars:
                    self.icon.image = UIImage(bundleImageName: "Premium/Stars/BalanceStar")
                }
            }
            
            self.component = component
            self.state = state
            
            var remainingCooldownSeconds: Int32 = 0
            if let cooldownUntilTimestamp = component.actionCooldownUntilTimestamp {
                remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                remainingCooldownSeconds = max(0, remainingCooldownSeconds)
            }
            
            var remainingSecondaryCooldownSeconds: Int32 = 0
            if let cooldownUntilTimestamp = component.secondaryActionCooldownUntilTimestamp {
                remainingSecondaryCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                remainingSecondaryCooldownSeconds = max(0, remainingSecondaryCooldownSeconds)
            }
            
            if remainingCooldownSeconds > 0 || remainingSecondaryCooldownSeconds > 0  {
                if self.timer == nil {
                    self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] _ in
                        guard let self else {
                            return
                        }
                        self.state?.updated(transition: .immediate)
                    })
                }
            } else {
                if let timer = self.timer {
                    self.timer = nil
                    timer.invalidate()
                }
            }
            
            let sideInset: CGFloat = 16.0
            var contentHeight: CGFloat = sideInset
            
            let formattedLabel: String
            switch component.currency {
            case .ton:
                formattedLabel = formatTonAmountText(component.count.value, dateTimeFormat: component.dateTimeFormat)
            case .stars:
                formattedLabel = formatStarsAmountText(component.count, dateTimeFormat: component.dateTimeFormat)
            }
            let labelFont: UIFont
            if formattedLabel.contains(component.dateTimeFormat.decimalSeparator) {
                labelFont = Font.with(size: 48.0, design: .round, weight: .semibold)
            } else {
                labelFont = Font.with(size: 48.0, design: .round, weight: .semibold)
            }
            let smallLabelFont = Font.with(size: 32.0, design: .round, weight: .regular)
            let balanceString = tonAmountAttributedString(formattedLabel, integralFont: labelFont, fractionalFont: smallLabelFont, color: component.theme.list.itemPrimaryTextColor, decimalSeparator: component.dateTimeFormat.decimalSeparator)
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(balanceString)
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.addSubview(titleView)
                }
                if let icon = self.icon.image {
                    let spacing: CGFloat = 4.0
                    let totalWidth = titleSize.width + icon.size.width + spacing
                    let origin = floorToScreenPixels((availableSize.width - totalWidth) / 2.0)
                    let titleFrame = CGRect(origin: CGPoint(x: origin + icon.size.width + spacing, y: contentHeight - 3.0), size: titleSize)
                    titleView.frame = titleFrame
                                        
                    self.icon.frame = CGRect(origin: CGPoint(x: origin, y: floorToScreenPixels(titleFrame.midY - icon.size.height / 2.0)), size: icon.size)
                }
            }
            contentHeight += titleSize.height
        
            let subtitleText: String
            if let rate = component.rate {
                subtitleText = "≈\(formatTonUsdValue(component.count.value, divide: false, rate: rate, dateTimeFormat: component.dateTimeFormat))"
            } else {
                subtitleText = component.strings.Stars_Intro_YourBalance
            }
            
            let subtitleSize = self.subtitle.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: subtitleText, font: Font.regular(17.0), textColor: component.theme.list.itemSecondaryTextColor)),
                        horizontalAlignment: .center
                    )
                ),
                environment: {},
                containerSize: CGSize(width: availableSize.width - sideInset * 2.0, height: 50.0)
            )
            if let subtitleView = self.subtitle.view {
                if subtitleView.superview == nil {
                    self.addSubview(subtitleView)
                }
                let subtitleFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - subtitleSize.width) / 2.0), y: contentHeight - 4.0), size: subtitleSize)
                subtitleView.frame = subtitleFrame
            }
            contentHeight += subtitleSize.height
            
            if component.actionAvailable {
                contentHeight += 12.0
                
                var withdrawWidth = availableSize.width - sideInset * 2.0
                if let _ = component.secondaryAction {
                    withdrawWidth = (withdrawWidth - 10.0) / 2.0
                }
                
                let content: AnyComponentWithIdentity<Empty>
                if remainingCooldownSeconds > 0 {
                    content = AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(
                        VStack([
                            AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(Text(text: component.actionTitle, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor))),
                            AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(BundleIconComponent(name: "Chat List/StatusLockIcon", tintColor: component.theme.list.itemCheckColors.fillColor.mixedWith(component.theme.list.itemCheckColors.foregroundColor, alpha: 0.7)))),
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(Text(text: stringForRemainingTime(remainingCooldownSeconds), font: Font.with(size: 11.0, weight: .medium, traits: [.monospacedNumbers]), color: component.theme.list.itemCheckColors.fillColor.mixedWith(component.theme.list.itemCheckColors.foregroundColor, alpha: 0.7))))
                            ], spacing: 3.0)))
                        ], spacing: 1.0)
                    ))
                } else {
                    var items: [AnyComponentWithIdentity<Empty>] = []
                    if let icon = component.actionIcon {
                        items.append(AnyComponentWithIdentity(id: "icon", component: AnyComponent(Image(image: icon, tintColor: component.theme.list.itemCheckColors.foregroundColor, size: icon.size))))
                    }
                    items.append(AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: component.actionTitle, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor))))
                    content = AnyComponentWithIdentity(
                        id: AnyHashable(0 as Int),
                        component: AnyComponent(
                            HStack(items, spacing: 7.0)
                        )
                    )
                }
                                
                let buttonSize = self.button.update(
                    transition: transition,
                    component: AnyComponent(ButtonComponent(
                        background: ButtonComponent.Background(
                            color: component.theme.list.itemCheckColors.fillColor,
                            foreground: component.theme.list.itemCheckColors.foregroundColor,
                            pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                        ),
                        content: content,
                        isEnabled: component.actionIsEnabled,
                        allowActionWhenDisabled: false,
                        displaysProgress: false,
                        action: { [weak self] in
                            guard let self, let component = self.component else {
                                return
                            }
                            component.action()
                        }
                    )),
                    environment: {},
                    containerSize: CGSize(width: withdrawWidth, height: 50.0)
                )
                if let buttonView = self.button.view {
                    if buttonView.superview == nil {
                        self.addSubview(buttonView)
                    }
                    let buttonFrame = CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: buttonSize)
                    buttonView.frame = buttonFrame
                }
                
                if let secondaryActionTitle = component.secondaryActionTitle {
                    let content: AnyComponentWithIdentity<Empty>
                    var items: [AnyComponentWithIdentity<Empty>] = []
                    if let icon = component.secondaryActionIcon {
                        items.append(AnyComponentWithIdentity(id: "icon", component: AnyComponent(Image(image: icon, tintColor: component.theme.list.itemCheckColors.foregroundColor, size: icon.size))))
                    }
                    if remainingSecondaryCooldownSeconds > 0 {
                        items.append(AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(
                            VStack([
                                AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(Text(text: secondaryActionTitle, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor))),
                                AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(HStack([
                                    AnyComponentWithIdentity(id: 1, component: AnyComponent(BundleIconComponent(name: "Chat List/StatusLockIcon", tintColor: component.theme.list.itemCheckColors.fillColor.mixedWith(component.theme.list.itemCheckColors.foregroundColor, alpha: 0.7)))),
                                    AnyComponentWithIdentity(id: 0, component: AnyComponent(Text(text: stringForRemainingTime(remainingSecondaryCooldownSeconds), font: Font.with(size: 11.0, weight: .medium, traits: [.monospacedNumbers]), color: component.theme.list.itemCheckColors.fillColor.mixedWith(component.theme.list.itemCheckColors.foregroundColor, alpha: 0.7))))
                                ], spacing: 3.0)))
                            ], spacing: 1.0)
                        )))
                    } else {
                        items.append(AnyComponentWithIdentity(id: "label", component: AnyComponent(Text(text: secondaryActionTitle, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor))))
                    }
                    content = AnyComponentWithIdentity(
                        id: AnyHashable(0 as Int),
                        component: AnyComponent(
                            HStack(items, spacing: 7.0)
                        )
                    )
                    
                    let buttonSize = self.secondaryButton.update(
                        transition: transition,
                        component: AnyComponent(ButtonComponent(
                            background: ButtonComponent.Background(
                                color: component.theme.list.itemCheckColors.fillColor,
                                foreground: component.theme.list.itemCheckColors.foregroundColor,
                                pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                            ),
                            content: content,
                            isEnabled: component.actionIsEnabled,
                            allowActionWhenDisabled: false,
                            displaysProgress: false,
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.secondaryAction?()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: withdrawWidth, height: 50.0)
                    )
                    if let buttonView = self.secondaryButton.view {
                        if buttonView.superview == nil {
                            self.addSubview(buttonView)
                        }
                        let buttonFrame = CGRect(origin: CGPoint(x: sideInset + withdrawWidth + 10.0, y: contentHeight), size: buttonSize)
                        buttonView.frame = buttonFrame
                    }
                }
                
                contentHeight += buttonSize.height
            }
            
            if let additionalAction = component.additionalAction {
                contentHeight += 18.0
                
                let buttonSize = self.additionalButton.update(
                    transition: transition,
                    component: additionalAction,
                    environment: {},
                    containerSize: CGSize(width: availableSize.width, height: 50.0)
                )
                if let buttonView = self.additionalButton.view {
                    if buttonView.superview == nil {
                        self.addSubview(buttonView)
                    }
                    let buttonFrame = CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - buttonSize.width) / 2.0), y: contentHeight), size: buttonSize)
                    buttonView.frame = buttonFrame
                }
                contentHeight += buttonSize.height
                contentHeight += 2.0
            }
            
            contentHeight += sideInset
            
            return CGSize(width: availableSize.width, height: contentHeight)
        }
    }
    
    func makeView() -> View {
        return View(frame: CGRect())
    }
    
    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

func stringForRemainingTime(_ duration: Int32) -> String {
    let hours = duration / 3600
    let minutes = duration / 60 % 60
    let seconds = duration % 60
    let durationString: String
    if hours > 0 {
        durationString = String(format: "%d:%02d", hours, minutes)
    } else {
        durationString = String(format: "%02d:%02d", minutes, seconds)
    }
    return durationString
}
