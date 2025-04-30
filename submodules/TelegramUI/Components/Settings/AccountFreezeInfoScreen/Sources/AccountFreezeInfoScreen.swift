import Foundation
import UIKit
import Display
import ComponentFlow
import SwiftSignalKit
import TelegramCore
import Markdown
import TextFormat
import TelegramPresentationData
import TelegramStringFormatting
import ViewControllerComponent
import SheetComponent
import BundleIconComponent
import BalancedTextComponent
import MultilineTextComponent
import LottieComponent
import ButtonComponent
import AccountContext

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let configuration: AccountFreezeConfiguration
    let openTerms: () -> Void
    let submitAppeal: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        configuration: AccountFreezeConfiguration,
        openTerms: @escaping () -> Void,
        submitAppeal: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.configuration = configuration
        self.openTerms = openTerms
        self.submitAppeal = submitAppeal
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedChevronImage: (UIImage, PresentationTheme)?
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
        let animation = Child(LottieComponent.self)
        
        let title = Child(BalancedTextComponent.self)
        let list = Child(List<Empty>.self)
        let actionButton = Child(ButtonComponent.self)
        let closeButton = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let theme = environment.theme
            let strings = environment.strings
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left
            
            let titleFont = Font.semibold(20.0)
            
            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
                        
            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 32.0)
                                    
            let animationHeight: CGFloat = 120.0
            let animation = animation.update(
                component: LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "Banned"),
                    startingPosition: .begin,
                    playOnce: state.playOnce
                ),
                environment: {},
                availableSize: CGSize(width: animationHeight, height: animationHeight),
                transition: .immediate
            )
            context.add(animation
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + animation.size.height / 2.0))
            )
            contentSize.height += animation.size.height
            contentSize.height += spacing + 5.0
                        
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: strings.FrozenAccount_Title, font: titleFont, textColor: textColor)),
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
            contentSize.height += spacing - 2.0
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "violation",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.FrozenAccount_Violation_Title,
                        titleColor: textColor,
                        text: strings.FrozenAccount_Violation_TextNew,
                        textColor: secondaryTextColor,
                        iconName: "Account Freeze/Violation",
                        iconColor: linkColor,
                        action: {
                            component.openTerms()
                            component.dismiss()
                        }
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "readOnly",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.FrozenAccount_ReadOnly_Title,
                        titleColor: textColor,
                        text: strings.FrozenAccount_ReadOnly_Text,
                        textColor: secondaryTextColor,
                        iconName: "Ads/Privacy",
                        iconColor: linkColor
                    ))
                )
            )
            let dateString = stringForFullDate(timestamp: component.configuration.freezeUntilDate ?? 0, strings: strings, dateTimeFormat: environment.dateTimeFormat)
            items.append(
                AnyComponentWithIdentity(
                    id: "appeal",
                    component: AnyComponent(ParagraphComponent(
                        title: strings.FrozenAccount_Appeal_Title,
                        titleColor: textColor,
                        text: strings.FrozenAccount_Appeal_Text(dateString).string,
                        textColor: secondaryTextColor,
                        iconName: "Account Freeze/Appeal",
                        iconColor: linkColor,
                        action: {
                            component.submitAppeal()
                            component.dismiss()
                        }
                    ))
                )
            )
            
            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width - sideInset, height: 10000.0),
                transition: context.transition
            )
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + list.size.height / 2.0))
            )
            contentSize.height += list.size.height
            contentSize.height += spacing + 2.0
            
            let buttonAttributedString = NSMutableAttributedString(string: strings.FrozenAccount_SubmitAppeal, font: Font.semibold(17.0), textColor: environment.theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center)
            let actionButton = actionButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: environment.theme.list.itemCheckColors.fillColor,
                        foreground: environment.theme.list.itemCheckColors.foregroundColor,
                        pressedColor: environment.theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(buttonAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                        component.submitAppeal()
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            context.add(actionButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + actionButton.size.height / 2.0))
                .cornerRadius(10.0)
            )
            contentSize.height += actionButton.size.height
            contentSize.height += 8.0
            
            let closeAttributedString = NSMutableAttributedString(string: strings.FrozenAccount_Understood, font: Font.regular(17.0), textColor: environment.theme.list.itemCheckColors.fillColor, paragraphAlignment: .center)
            let closeButton = closeButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        color: .clear,
                        foreground: .clear,
                        pressedColor: .clear,
                        cornerRadius: 10.0
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(1),
                        component: AnyComponent(MultilineTextComponent(text: .plain(closeAttributedString)))
                    ),
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            context.add(closeButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + actionButton.size.height / 2.0))
            )
            contentSize.height += closeButton.size.height
           
            if environment.safeInsets.bottom > 0 {
                contentSize.height += environment.safeInsets.bottom + 5.0
            } else {
                contentSize.height += 12.0
            }
                        
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let configuration: AccountFreezeConfiguration
    let openTerms: () -> Void
    let submitAppeal: () -> Void
    
    init(
        context: AccountContext,
        configuration: AccountFreezeConfiguration,
        openTerms: @escaping () -> Void,
        submitAppeal: @escaping () -> Void
    ) {
        self.context = context
        self.configuration = configuration
        self.openTerms = openTerms
        self.submitAppeal = submitAppeal
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
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
                        configuration: context.component.configuration,
                        openTerms: context.component.openTerms,
                        submitAppeal: context.component.submitAppeal,
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


public final class AccountFreezeInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(
        context: AccountContext
    ) {
        self.context = context
        
        let configuration = AccountFreezeConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        var openTermsImpl: (() -> Void)?
        var submitAppealImpl: (() -> Void)?
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                configuration: configuration,
                openTerms: {
                    openTermsImpl?()
                },
                submitAppeal: {
                    submitAppealImpl?()
                }
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
                             
        openTermsImpl = { [weak self] in
            guard let self, let navigationController = self.navigationController as? NavigationController else {
                return
            }
            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
            Queue.mainQueue().after(0.4) {
                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: presentationData.strings.FrozenAccount_Violation_TextNew_URL, forceExternal: false, presentationData: presentationData, navigationController: navigationController, dismissInput: {})
            }
        }
        submitAppealImpl = { [weak self] in
            guard let self, let navigationController = self.navigationController as? NavigationController, let url = configuration.freezeAppealUrl else {
                return
            }
            Queue.mainQueue().after(0.4) {
                context.sharedContext.openExternalUrl(context: context, urlContext: .generic, url: url, forceExternal: false, presentationData: context.sharedContext.currentPresentationData.with { $0 }, navigationController: navigationController, dismissInput: {})
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}

private final class ParagraphComponent: CombinedComponent {
    let title: String
    let titleColor: UIColor
    let text: String
    let textColor: UIColor
    let iconName: String
    let iconColor: UIColor
    let action: (() -> Void)?
    
    public init(
        title: String,
        titleColor: UIColor,
        text: String,
        textColor: UIColor,
        iconName: String,
        iconColor: UIColor,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.titleColor = titleColor
        self.text = text
        self.textColor = textColor
        self.iconName = iconName
        self.iconColor = iconColor
        self.action = action
    }
    
    static func ==(lhs: ParagraphComponent, rhs: ParagraphComponent) -> Bool {
        if lhs.title != rhs.title {
            return false
        }
        if lhs.titleColor != rhs.titleColor {
            return false
        }
        if lhs.text != rhs.text {
            return false
        }
        if lhs.textColor != rhs.textColor {
            return false
        }
        if lhs.iconName != rhs.iconName {
            return false
        }
        if lhs.iconColor != rhs.iconColor {
            return false
        }
        return true
    }
    
    static var body: Body {
        let title = Child(MultilineTextComponent.self)
        let text = Child(MultilineTextComponent.self)
        let icon = Child(BundleIconComponent.self)
        
        return { context in
            let component = context.component
            
            let leftInset: CGFloat = 64.0
            let rightInset: CGFloat = 32.0
            let textSideInset: CGFloat = leftInset + 8.0
            let spacing: CGFloat = 5.0
            
            let textTopInset: CGFloat = 9.0
                        
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: component.title,
                        font: Font.semibold(15.0),
                        textColor: component.titleColor,
                        paragraphAlignment: .natural
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = component.textColor
            let linkColor = component.iconColor
            let markdownAttributes = MarkdownAttributes(
                body: MarkdownAttributeSet(font: textFont, textColor: textColor),
                bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor),
                link: MarkdownAttributeSet(font: textFont, textColor: linkColor),
                linkAttribute: { contents in
                    return (TelegramTextAttributes.URL, contents)
                }
            )
                        
            let text = text.update(
                component: MultilineTextComponent(
                    text: .markdown(text: component.text, attributes: markdownAttributes),
                    horizontalAlignment: .natural,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2,
                    highlightColor: linkColor.withAlphaComponent(0.1),
                    highlightAction: { attributes in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] {
                            return NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)
                        } else {
                            return nil
                        }
                    },
                    tapAction: { attributes, _ in
                        if let _ = attributes[NSAttributedString.Key(rawValue: TelegramTextAttributes.URL)] as? String {
                            component.action?()
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - leftInset - rightInset, height: context.availableSize.height),
                transition: .immediate
            )
            
            let icon = icon.update(
                component: BundleIconComponent(
                    name: component.iconName,
                    tintColor: component.iconColor
                ),
                availableSize: CGSize(width: context.availableSize.width, height: context.availableSize.height),
                transition: .immediate
            )
         
            context.add(title
                .position(CGPoint(x: textSideInset + title.size.width / 2.0, y: textTopInset + title.size.height / 2.0))
            )
            
            context.add(text
                .position(CGPoint(x: textSideInset + text.size.width / 2.0, y: textTopInset + title.size.height + spacing + text.size.height / 2.0))
            )
            
            context.add(icon
                .position(CGPoint(x: 47.0, y: textTopInset + 18.0))
            )
        
            return CGSize(width: context.availableSize.width, height: textTopInset + title.size.height + text.size.height + 18.0)
        }
    }
}

private func generateCloseButtonImage(backgroundColor: UIColor, foregroundColor: UIColor) -> UIImage? {
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
