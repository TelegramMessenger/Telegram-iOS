import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import SolidRoundedButtonComponent
import LottieComponent
import AccountContext
import TelegramStringFormatting
import PremiumPeerShortcutComponent

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let transaction: StarsContext.State.Transaction
    let openExplorer: (String) -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        transaction: StarsContext.State.Transaction,
        openExplorer: @escaping (String) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.peer = peer
        self.transaction = transaction
        self.openExplorer = openExplorer
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.transaction != rhs.transaction {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedCloseImage: (UIImage, PresentationTheme)?
        
        let playOnce =  ActionSlot<Void>()
        private var didPlayAnimation = false
                
        func playAnimationIfNeeded() {
            guard !self.didPlayAnimation else {
                return
            }
            self.didPlayAnimation = true
            self.playOnce.invoke(Void())
        }
    }
    
    func makeState() -> State {
        return State()
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
                
        let amount = Child(MultilineTextComponent.self)
        let title = Child(MultilineTextComponent.self)
        let date = Child(MultilineTextComponent.self)
        let peerShortcut = Child(PremiumPeerShortcutComponent.self)
        
        let actionButton = Child(SolidRoundedButtonComponent.self)

        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let theme = environment.theme
            let strings = environment.strings
            let dateTimeFormat = component.context.sharedContext.currentPresentationData.with { $0 }.dateTimeFormat
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            
            let titleFont = Font.semibold(17.0)
            let textFont = Font.regular(17.0)
            
            var titleColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            
            var contentSize = CGSize(width: context.availableSize.width, height: 45.0)
            
            let closeImage: UIImage
            if let (image, theme) = state.cachedCloseImage, theme === environment.theme {
                closeImage = image
            } else {
                closeImage = generateCloseButtonImage(backgroundColor: UIColor(rgb: 0x808084, alpha: 0.1), foregroundColor: theme.actionSheet.inputClearButtonColor)!
                state.cachedCloseImage = (closeImage, theme)
            }
            
            let closeButton = closeButton.update(
                component: Button(
                    content: AnyComponent(Image(image: closeImage)),
                    action: { [weak component] in
                        component?.dismiss()
                    }
                ),
                availableSize: CGSize(width: 30.0, height: 30.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width - environment.safeInsets.left - closeButton.size.width, y: 28.0))
            )
            
            let amountString: NSMutableAttributedString
            let dateString: String
            let titleString: String
            let buttonTitle: String
            let explorerUrl: String?
            
            let integralFont = Font.with(size: 48.0, design: .round, weight: .semibold)
            let fractionalFont = Font.with(size: 24.0, design: .round, weight: .semibold)
            let labelColor: UIColor
            
            var showPeer = false
            if let fromDate = component.transaction.adsProceedsFromDate, let toDate = component.transaction.adsProceedsToDate {
                labelColor = theme.list.itemDisclosureActions.constructive.fillColor
                amountString = tonAmountAttributedString(formatTonAmountText(component.transaction.count.amount.value, dateTimeFormat: dateTimeFormat, showPlus: true), integralFont: integralFont, fractionalFont: fractionalFont, color: labelColor, decimalSeparator: dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                dateString = "\(stringForMediumCompactDate(timestamp: fromDate, strings: strings, dateTimeFormat: dateTimeFormat)) – \(stringForMediumCompactDate(timestamp: toDate, strings: strings, dateTimeFormat: dateTimeFormat))"
                titleString = strings.Monetization_TransactionInfo_Proceeds
                buttonTitle = strings.Common_OK
                explorerUrl = nil
                showPeer = true
            } else if case .fragment = component.transaction.peer {
                if component.transaction.flags.contains(.isRefund) {
                    labelColor = theme.list.itemDisclosureActions.constructive.fillColor
                    titleString = strings.Monetization_TransactionInfo_Refund
                    amountString = tonAmountAttributedString(formatTonAmountText(component.transaction.count.amount.value, dateTimeFormat: dateTimeFormat, showPlus: true), integralFont: integralFont, fractionalFont: fractionalFont, color: labelColor, decimalSeparator: dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                    dateString = stringForFullDate(timestamp: component.transaction.date, strings: strings, dateTimeFormat: dateTimeFormat)
                    buttonTitle = strings.Common_OK
                } else {
                    labelColor = theme.list.itemDestructiveColor
                    amountString = tonAmountAttributedString(formatTonAmountText(component.transaction.count.amount.value, dateTimeFormat: dateTimeFormat), integralFont: integralFont, fractionalFont: fractionalFont, color: labelColor, decimalSeparator: dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                    dateString = stringForFullDate(timestamp: component.transaction.date, strings: strings, dateTimeFormat: dateTimeFormat)
                    
                    if component.transaction.flags.contains(.isPending) {
                        titleString = strings.Monetization_TransactionInfo_Pending
                        buttonTitle = strings.Common_OK
                    } else if component.transaction.flags.contains(.isFailed) {
                        titleString = strings.Monetization_TransactionInfo_Failed
                        buttonTitle = strings.Common_OK
                        titleColor = theme.list.itemDestructiveColor
                    } else {
                        titleString = strings.Monetization_TransactionInfo_Withdrawal("Fragment").string
                        buttonTitle = strings.Monetization_TransactionInfo_ViewInExplorer
                    }
                }
                explorerUrl = component.transaction.transactionUrl
            } else if component.transaction.flags.contains(.isRefund) {
                labelColor = theme.list.itemDisclosureActions.constructive.fillColor
                titleString = strings.Monetization_TransactionInfo_Refund
                amountString = tonAmountAttributedString(formatTonAmountText(component.transaction.count.amount.value, dateTimeFormat: dateTimeFormat, showPlus: true), integralFont: integralFont, fractionalFont: fractionalFont, color: labelColor, decimalSeparator: dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                dateString = stringForFullDate(timestamp: component.transaction.date, strings: strings, dateTimeFormat: dateTimeFormat)
                buttonTitle = strings.Common_OK
                explorerUrl = nil
            } else {
                labelColor = theme.list.itemDisclosureActions.constructive.fillColor
                amountString = tonAmountAttributedString(formatTonAmountText(component.transaction.count.amount.value, dateTimeFormat: dateTimeFormat, showPlus: true), integralFont: integralFont, fractionalFont: fractionalFont, color: labelColor, decimalSeparator: dateTimeFormat.decimalSeparator).mutableCopy() as! NSMutableAttributedString
                dateString = ""
                titleString = ""
                buttonTitle = ""
                explorerUrl = nil
            }
            
            amountString.insert(NSAttributedString(string: " $ ", font: integralFont, textColor: labelColor), at: 1)
            if let range = amountString.string.range(of: "$"), let icon = generateTintedImage(image: UIImage(bundleImageName: "Ads/TonBig"), color: labelColor) {
                amountString.addAttribute(.attachment, value: icon, range: NSRange(range, in: amountString.string))
                amountString.addAttribute(.baselineOffset, value: 1.0, range: NSRange(range, in: amountString.string))
            }
            
            let amount = amount.update(
                component: MultilineTextComponent(
                    text: .plain(amountString),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(amount
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + amount.size.height / 2.0))
            )
            contentSize.height += amount.size.height
            contentSize.height += -5.0
            
            let date = date.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: dateString, font: textFont, textColor: secondaryTextColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(date
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + date.size.height / 2.0))
            )
            contentSize.height += date.size.height
            contentSize.height += 32.0
            
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: titleFont, textColor: titleColor)),
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
            contentSize.height += 3.0
            
            if showPeer {
                contentSize.height += 5.0
                let peerShortcut = peerShortcut.update(
                    component: PremiumPeerShortcutComponent(
                        context: component.context,
                        theme: theme,
                        peer: component.peer
                        
                    ),
                    availableSize: CGSize(width: context.availableSize.width - 32.0, height: context.availableSize.height),
                    transition: .immediate
                )
                context.add(peerShortcut
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + peerShortcut.size.height / 2.0))
                )
                contentSize.height += peerShortcut.size.height
                contentSize.height += 50.0
            } else {
                contentSize.height += 45.0
            }
           
            let actionButton = actionButton.update(
                component: SolidRoundedButtonComponent(
                    title: buttonTitle,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: theme.list.itemCheckColors.fillColor,
                        backgroundColors: [],
                        foregroundColor: theme.list.itemCheckColors.foregroundColor
                    ),
                    font: .bold,
                    fontSize: 17.0,
                    height: 50.0,
                    cornerRadius: 10.0,
                    gloss: false,
                    iconName: nil,
                    animationName: nil,
                    iconPosition: .left,
                    action: {
                        component.dismiss()
                        if let explorerUrl {
                            component.openExplorer(explorerUrl)
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            context.add(actionButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + actionButton.size.height / 2.0))
            )
            contentSize.height += actionButton.size.height
            contentSize.height += 22.0
                        
            contentSize.height += environment.safeInsets.bottom
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peer: EnginePeer
    let transaction: StarsContext.State.Transaction
    let openExplorer: (String) -> Void
    
    init(
        context: AccountContext,
        peer: EnginePeer,
        transaction: StarsContext.State.Transaction,
        openExplorer: @escaping (String) -> Void
    ) {
        self.context = context
        self.peer = peer
        self.transaction = transaction
        self.openExplorer = openExplorer
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.transaction != rhs.transaction {
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
                    content: AnyComponent<EnvironmentType>(SheetContent(
                        context: context.component.context,
                        peer: context.component.peer,
                        transaction: context.component.transaction,
                        openExplorer: context.component.openExplorer,
                        dismiss: {
                            animateOut.invoke(Action { _ in
                                if let controller = controller() {
                                    controller.dismiss(completion: nil)
                                }
                            })
                        }
                    )),
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    externalState: sheetExternalState,
                    animateOut: animateOut
                ),
                environment: {
                    environment
                    SheetComponentEnvironment(
                        isDisplaying: environment.value.isVisible,
                        isCentered: environment.metrics.widthClass == .regular,
                        hasInputHeight: !environment.inputHeight.isZero,
                        regularMetricsSize: CGSize(width: 430.0, height: 900.0),
                        dismiss: { animated in
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
                    )
                },
                availableSize: context.availableSize,
                transition: context.transition
            )
            
            context.add(sheet
                .position(CGPoint(x: context.availableSize.width / 2.0, y: context.availableSize.height / 2.0))
            )
            
            if let controller = controller(), !controller.automaticallyControlPresentationContextLayout {
                let layout = ContainerViewLayout(
                    size: context.availableSize,
                    metrics: environment.metrics,
                    deviceMetrics: environment.deviceMetrics,
                    intrinsicInsets: UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(environment.safeInsets.bottom, sheetExternalState.contentHeight), right: 0.0),
                    safeInsets: UIEdgeInsets(top: 0.0, left: environment.safeInsets.left, bottom: 0.0, right: environment.safeInsets.right),
                    additionalInsets: .zero,
                    statusBarHeight: environment.statusBarHeight,
                    inputHeight: nil,
                    inputHeightIsInteractivellyChanging: false,
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}


final class TransactionInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
        
    init(
        context: AccountContext,
        peer: EnginePeer,
        transaction: StarsContext.State.Transaction,
        openExplorer: @escaping (String) -> Void
    ) {
        self.context = context
                
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                peer: peer,
                transaction: transaction,
                openExplorer: openExplorer
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
    return generateImage(CGSize(width: 30.0, height: 30.0), contextGenerator: { size, context in
        context.clear(CGRect(origin: CGPoint(), size: size))
        
        context.setFillColor(backgroundColor.cgColor)
        context.fillEllipse(in: CGRect(origin: CGPoint(), size: size))
        
        context.setLineWidth(2.0)
        context.setLineCap(.round)
        context.setStrokeColor(foregroundColor.cgColor)
        
        context.move(to: CGPoint(x: 10.0, y: 10.0))
        context.addLine(to: CGPoint(x: 20.0, y: 20.0))
        context.strokePath()
        
        context.move(to: CGPoint(x: 20.0, y: 10.0))
        context.addLine(to: CGPoint(x: 10.0, y: 20.0))
        context.strokePath()
    })
}
