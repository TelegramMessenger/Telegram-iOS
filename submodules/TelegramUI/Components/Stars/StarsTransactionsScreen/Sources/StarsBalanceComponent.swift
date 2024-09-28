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

final class StarsBalanceComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let dateTimeFormat: PresentationDateTimeFormat
    let count: Int64
    let rate: Double?
    let actionTitle: String
    let actionAvailable: Bool
    let actionIsEnabled: Bool
    let actionCooldownUntilTimestamp: Int32?
    let action: () -> Void
    let buyAds: (() -> Void)?
    let additionalAction: AnyComponent<Empty>?
    
    init(
        theme: PresentationTheme,
        strings: PresentationStrings,
        dateTimeFormat: PresentationDateTimeFormat,
        count: Int64,
        rate: Double?,
        actionTitle: String,
        actionAvailable: Bool,
        actionIsEnabled: Bool,
        actionCooldownUntilTimestamp: Int32? = nil,
        action: @escaping () -> Void,
        buyAds: (() -> Void)?,
        additionalAction: AnyComponent<Empty>? = nil
    ) {
        self.theme = theme
        self.strings = strings
        self.dateTimeFormat = dateTimeFormat
        self.count = count
        self.rate = rate
        self.actionTitle = actionTitle
        self.actionAvailable = actionAvailable
        self.actionIsEnabled = actionIsEnabled
        self.actionCooldownUntilTimestamp = actionCooldownUntilTimestamp
        self.action = action
        self.buyAds = buyAds
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
        if lhs.count != rhs.count {
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
        private var buyAdsButton = ComponentView<Empty>()
        
        private var additionalButton = ComponentView<Empty>()
        
        private var component: StarsBalanceComponent?
        private weak var state: EmptyComponentState?
        
        private var timer: Timer?
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            
            self.icon.image = UIImage(bundleImageName: "Premium/Stars/BalanceStar")
            
            self.addSubview(self.icon)
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        func update(component: StarsBalanceComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state
            
            var remainingCooldownSeconds: Int32 = 0
            if let cooldownUntilTimestamp = component.actionCooldownUntilTimestamp {
                remainingCooldownSeconds = cooldownUntilTimestamp - Int32(Date().timeIntervalSince1970)
                remainingCooldownSeconds = max(0, remainingCooldownSeconds)
            }
            
            if remainingCooldownSeconds > 0 {
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
            
            let balanceString = presentationStringsFormattedNumber(Int32(component.count), component.dateTimeFormat.groupingSeparator)
            let titleSize = self.title.update(
                transition: .immediate,
                component: AnyComponent(
                    MultilineTextComponent(
                        text: .plain(NSAttributedString(string: balanceString, font: Font.with(size: 48.0, design: .round, weight: .semibold), textColor: component.theme.list.itemPrimaryTextColor))
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
                    let spacing: CGFloat = 3.0
                    let totalWidth = titleSize.width + icon.size.width + spacing
                    let origin = floorToScreenPixels((availableSize.width - totalWidth) / 2.0)
                    let titleFrame = CGRect(origin: CGPoint(x: origin + icon.size.width + spacing, y: contentHeight - 3.0), size: titleSize)
                    titleView.frame = titleFrame
                    
                    self.icon.frame = CGRect(origin: CGPoint(x: origin, y: contentHeight), size: icon.size)
                }
            }
            contentHeight += titleSize.height
        
            let subtitleText: String
            if let rate = component.rate {
                subtitleText = "≈\(formatTonUsdValue(component.count, divide: false, rate: rate, dateTimeFormat: component.dateTimeFormat))"
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
                
                var actionTitle = component.actionTitle
                var withdrawWidth = availableSize.width - sideInset * 2.0
                if let _ = component.buyAds {
                    withdrawWidth = (withdrawWidth - 10.0) / 2.0
                    actionTitle = component.strings.Stars_BotRevenue_Withdraw_WithdrawShort
                }
                
                let content: AnyComponentWithIdentity<Empty>
                if remainingCooldownSeconds > 0 {
                    content = AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(
                        VStack([
                            AnyComponentWithIdentity(id: AnyHashable(1 as Int), component: AnyComponent(Text(text: actionTitle, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor))),
                            AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(HStack([
                                AnyComponentWithIdentity(id: 1, component: AnyComponent(BundleIconComponent(name: "Chat List/StatusLockIcon", tintColor: component.theme.list.itemCheckColors.fillColor.mixedWith(component.theme.list.itemCheckColors.foregroundColor, alpha: 0.7)))),
                                AnyComponentWithIdentity(id: 0, component: AnyComponent(Text(text: stringForRemainingTime(remainingCooldownSeconds), font: Font.with(size: 11.0, weight: .medium, traits: [.monospacedNumbers]), color: component.theme.list.itemCheckColors.fillColor.mixedWith(component.theme.list.itemCheckColors.foregroundColor, alpha: 0.7))))
                            ], spacing: 3.0)))
                        ], spacing: 1.0)
                    ))
                } else {
                    content = AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(Text(text: actionTitle, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor)))
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
                
                if let _ = component.buyAds {
                    let buttonSize = self.buyAdsButton.update(
                        transition: transition,
                        component: AnyComponent(ButtonComponent(
                            background: ButtonComponent.Background(
                                color: component.theme.list.itemCheckColors.fillColor,
                                foreground: component.theme.list.itemCheckColors.foregroundColor,
                                pressedColor: component.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.8)
                            ),
                            content: AnyComponentWithIdentity(id: AnyHashable(0 as Int), component: AnyComponent(Text(text: component.strings.Stars_BotRevenue_Withdraw_BuyAds, font: Font.semibold(17.0), color: component.theme.list.itemCheckColors.foregroundColor))),
                            isEnabled: component.actionIsEnabled,
                            allowActionWhenDisabled: false,
                            displaysProgress: false,
                            action: { [weak self] in
                                guard let self, let component = self.component else {
                                    return
                                }
                                component.buyAds?()
                            }
                        )),
                        environment: {},
                        containerSize: CGSize(width: withdrawWidth, height: 50.0)
                    )
                    if let buttonView = self.buyAdsButton.view {
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
