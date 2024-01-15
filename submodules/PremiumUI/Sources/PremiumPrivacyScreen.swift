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

private final class SheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let subject: PremiumPrivacyScreen.Subject
    
    let action: () -> Void
    let openPremiumIntro: () -> Void
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        subject: PremiumPrivacyScreen.Subject,
        action: @escaping () -> Void,
        openPremiumIntro: @escaping () -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.peerId = peerId
        self.subject = subject
        self.action = action
        self.openPremiumIntro = openPremiumIntro
        self.dismiss = dismiss
    }
    
    static func ==(lhs: SheetContent, rhs: SheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.subject != rhs.subject {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var cachedCloseImage: (UIImage, PresentationTheme)?
        var cachedIconImage: UIImage?
        
        let playOnce =  ActionSlot<Void>()
        private var didPlayAnimation = false
        
        private var disposable: Disposable?
        
        private(set) var peer: EnginePeer?
        
        init(context: AccountContext, peerId: EnginePeer.Id) {
            super.init()
            
            self.disposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                self.peer = peer
                self.updated()
            })
        }
        
        deinit {
            self.disposable?.dispose()
        }
        
        func playAnimationIfNeeded() {
            guard !self.didPlayAnimation else {
                return
            }
            self.didPlayAnimation = true
            self.playOnce.invoke(Void())
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, peerId: self.peerId)
    }
    
    static var body: Body {
        let closeButton = Child(Button.self)
        
        let iconBackground = Child(Image.self)
        let icon = Child(LottieComponent.self)
        
        let title = Child(BalancedTextComponent.self)
        let text = Child(BalancedTextComponent.self)
        let actionButton = Child(SolidRoundedButtonComponent.self)
        
        let orLeftLine = Child(Rectangle.self)
        let orRightLine = Child(Rectangle.self)
        let orText = Child(MultilineTextComponent.self)
        
        let premiumTitle = Child(BalancedTextComponent.self)
        let premiumText = Child(BalancedTextComponent.self)
        let premiumButton = Child(SolidRoundedButtonComponent.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let component = context.component
            let state = context.state
            
            let theme = environment.theme
            let strings = environment.strings
            
            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 32.0 + environment.safeInsets.left
            
            let titleFont = Font.semibold(20.0)
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            let markdownAttributes = MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: textColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: textColor), link: MarkdownAttributeSet(font: textFont, textColor: linkColor), linkAttribute: { contents in
                return (TelegramTextAttributes.URL, contents)
            })
            
            let iconName: String
            let titleString: String
            let textString: String
            let buttonTitle: String
            let premiumString: String
            
            let premiumTitleString = strings.PrivacyInfo_UpgradeToPremium_Title
            let premiumButtonTitle = strings.PrivacyInfo_UpgradeToPremium_ButtonTitle
            
            let peerName = state.peer?.compactDisplayTitle ?? ""
            switch component.subject {
            case .presence:
                iconName = "PremiumPrivacyPresence"
                titleString = strings.PrivacyInfo_ShowLastSeen_Title
                textString = strings.PrivacyInfo_ShowLastSeen_Text(peerName).string
                buttonTitle = strings.PrivacyInfo_ShowLastSeen_ButtonTitle
                premiumString = strings.PrivacyInfo_ShowLastSeen_PremiumInfo(peerName).string
            case .readTime:
                iconName = "PremiumPrivacyRead"
                titleString = strings.PrivacyInfo_ShowReadTime_Title
                textString = strings.PrivacyInfo_ShowReadTime_Text(peerName).string
                buttonTitle = strings.PrivacyInfo_ShowReadTime_ButtonTitle
                premiumString = strings.PrivacyInfo_ShowReadTime_PremiumInfo(peerName).string
            }
            
            let spacing: CGFloat = 8.0
            var contentSize = CGSize(width: context.availableSize.width, height: 32.0)
            
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
            
            let iconSize = CGSize(width: 90.0, height: 90.0)
            let gradientImage: UIImage
            if let current = state.cachedIconImage {
                gradientImage = current
            } else {
                gradientImage = generateFilledCircleImage(diameter: iconSize.width, color: theme.actionSheet.controlAccentColor)!
                context.state.cachedIconImage = gradientImage
            }
            
            let iconBackground = iconBackground.update(
                component: Image(image: gradientImage),
                availableSize: iconSize,
                transition: .immediate
            )
            context.add(iconBackground
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0))
            )
            
            let icon = icon.update(
                component: LottieComponent(
                    content: LottieComponent.AppBundleContent(name: iconName),
                    playOnce: state.playOnce
                ),
                availableSize: CGSize(width: 70, height: 70),
                transition: .immediate
            )
            
            context.add(icon
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + iconBackground.size.height / 2.0))
            )
            contentSize.height += iconSize.height
            contentSize.height += spacing + 5.0
            
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: titleString, font: titleFont, textColor: textColor)),
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
            contentSize.height += spacing
            
            let text = text.update(
                component: BalancedTextComponent(
                    text: .markdown(text: textString, attributes: markdownAttributes),
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
            contentSize.height += spacing + 5.0
            
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
                        component.action()
                        component.dismiss()
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
                        
            let orText = orText.update(
                component: MultilineTextComponent(text: .plain(NSAttributedString(string: strings.ChannelBoost_Or, font: Font.regular(15.0), textColor: secondaryTextColor, paragraphAlignment: .center))),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(orText
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + orText.size.height / 2.0))
            )
            
            let orLeftLine = orLeftLine.update(
                component: Rectangle(color: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)),
                availableSize: CGSize(width: 90.0, height: 1.0 - UIScreenPixel),
                transition: .immediate
            )
            context.add(orLeftLine
                .position(CGPoint(x: context.availableSize.width / 2.0 - orText.size.width / 2.0 - 11.0 - 45.0, y: contentSize.height + orText.size.height / 2.0))
            )
            
            let orRightLine = orRightLine.update(
                component: Rectangle(color: theme.list.itemBlocksSeparatorColor.withAlphaComponent(0.3)),
                availableSize: CGSize(width: 90.0, height: 1.0 - UIScreenPixel),
                transition: .immediate
            )
            context.add(orRightLine
                .position(CGPoint(x: context.availableSize.width / 2.0 + orText.size.width / 2.0 + 11.0 + 45.0, y: contentSize.height + orText.size.height / 2.0))
            )
            contentSize.height += orText.size.height
            contentSize.height += 18.0
            
            let premiumTitle = premiumTitle.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: premiumTitleString, font: titleFont, textColor: textColor)),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.1
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(premiumTitle
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + premiumTitle.size.height / 2.0))
            )
            contentSize.height += premiumTitle.size.height
            contentSize.height += spacing
            
            let premiumText = premiumText.update(
                component: BalancedTextComponent(
                    text: .markdown(text: premiumString, attributes: markdownAttributes),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 0,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - textSideInset * 2.0, height: context.availableSize.height),
                transition: .immediate
            )
            context.add(premiumText
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + premiumText.size.height / 2.0))
            )
            contentSize.height += premiumText.size.height
            contentSize.height += spacing + 5.0
            
            let premiumButton = premiumButton.update(
                component: SolidRoundedButtonComponent(
                    title: premiumButtonTitle,
                    theme: SolidRoundedButtonComponent.Theme(
                        backgroundColor: .black,
                        backgroundColors: [
                            UIColor(rgb: 0x0077ff),
                            UIColor(rgb: 0x6b93ff),
                            UIColor(rgb: 0x8878ff),
                            UIColor(rgb: 0xe46ace)
                        ],
                        foregroundColor: .white
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
                        component.openPremiumIntro()
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 50.0),
                transition: context.transition
            )
            context.add(premiumButton
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + premiumButton.size.height / 2.0))
            )
            contentSize.height += premiumButton.size.height
            contentSize.height += 14.0
                
            contentSize.height += environment.safeInsets.bottom
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

private final class SheetContainerComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let peerId: EnginePeer.Id
    let subject: PremiumPrivacyScreen.Subject
    let action: () -> Void
    let openPremiumIntro: () -> Void
    
    init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        subject: PremiumPrivacyScreen.Subject,
        action: @escaping () -> Void,
        openPremiumIntro: @escaping () -> Void
    ) {
        self.context = context
        self.peerId = peerId
        self.subject = subject
        self.action = action
        self.openPremiumIntro = openPremiumIntro
    }
    
    static func ==(lhs: SheetContainerComponent, rhs: SheetContainerComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.peerId != rhs.peerId {
            return false
        }
        if lhs.subject != rhs.subject {
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
                        peerId: context.component.peerId,
                        subject: context.component.subject,
                        action: context.component.action,
                        openPremiumIntro: context.component.openPremiumIntro,
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


public class PremiumPrivacyScreen: ViewControllerComponentContainer {
    public enum Subject: Equatable {
        case presence
        case readTime
    }
    
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let subject: PremiumPrivacyScreen.Subject
    private var action: (() -> Void)?
    private var openPremiumIntro: (() -> Void)?
        
    public init(
        context: AccountContext,
        peerId: EnginePeer.Id,
        subject: PremiumPrivacyScreen.Subject,
        action: @escaping () -> Void,
        openPremiumIntro: @escaping () -> Void
    ) {
        self.context = context
        self.peerId = peerId
        self.subject = subject
        self.action = action
        self.openPremiumIntro = openPremiumIntro
                
        super.init(
            context: context,
            component: SheetContainerComponent(
                context: context,
                peerId: peerId,
                subject: subject,
                action: action,
                openPremiumIntro: openPremiumIntro
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
