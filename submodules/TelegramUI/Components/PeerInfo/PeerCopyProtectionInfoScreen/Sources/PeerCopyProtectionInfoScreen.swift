import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import BalancedTextComponent
import BundleIconComponent
import Markdown
import TextFormat
import TelegramStringFormatting
import GlassBarButtonComponent
import ButtonComponent
import InfoParagraphComponent
import LottieComponent
import UndoUI

private final class PeerCopyProtectionInfoSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let getController: () -> ViewController?
    let dismiss: () -> Void
    
    init(
        context: AccountContext,
        getController: @escaping () -> ViewController?,
        dismiss: @escaping () -> Void
    ) {
        self.context = context
        self.getController = getController
        self.dismiss = dismiss
    }
    
    static func ==(lhs: PeerCopyProtectionInfoSheetContent, rhs: PeerCopyProtectionInfoSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        
        fileprivate let playAnimation = ActionSlot<Void>()
        private var didPlayAnimation = false
        
        fileprivate let playButtonAnimation = ActionSlot<Void>()
        private var buttonAnimationTimer: SwiftSignalKit.Timer?
        
        init(
            context: AccountContext
        ) {
            self.context = context
            
            super.init()
            
            self.buttonAnimationTimer = SwiftSignalKit.Timer(timeout: 1.25, repeat: true, completion: { [weak self] in
                self?.playButtonAnimation.invoke(Void())
            }, queue: Queue.mainQueue())
            self.buttonAnimationTimer?.start()
        }
        
        deinit {
            self.buttonAnimationTimer?.invalidate()
        }
        
        func playAnimationIfNeeded() {
            if !self.didPlayAnimation {
                self.didPlayAnimation = true
                self.playAnimation.invoke(Void())
            }
        }
    }
    
    func makeState() -> State {
        return State(context: self.context)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let icon = Child(LottieComponent.self)
        let title = Child(BalancedTextComponent.self)
        let list = Child(List<Empty>.self)
        let button = Child(ButtonComponent.self)
                                
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let state = context.state
            let component = context.component
            let controller = environment.controller
           
            let theme = environment.theme
            let strings = environment.strings
            
            let sideInset: CGFloat = 30.0 + environment.safeInsets.left
            let textSideInset: CGFloat = 30.0 + environment.safeInsets.left
            
            let titleFont = Font.bold(24.0)
            
            let textColor = theme.actionSheet.primaryTextColor
            let secondaryTextColor = theme.actionSheet.secondaryTextColor
            let linkColor = theme.actionSheet.controlAccentColor
            
            let spacing: CGFloat = 16.0
            var contentSize = CGSize(width: context.availableSize.width, height: 33.0)
                                              
            let icon = icon.update(
                component: LottieComponent(
                    content: LottieComponent.AppBundleContent(name: "HandRestrict"),
                    loop: false,
                    playOnce: state.playAnimation
                ),
                availableSize: CGSize(width: 120.0, height: 120.0),
                transition: context.transition
            )
            context.add(icon
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + icon.size.height / 2.0))
            )
            contentSize.height += icon.size.height
            contentSize.height += 26.0
        
            let title = title.update(
                component: BalancedTextComponent(
                    text: .plain(NSAttributedString(string: strings.DisableSharing_Title, font: titleFont, textColor: textColor)),
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
            contentSize.height += spacing + 7.0
            
            var items: [AnyComponentWithIdentity<Empty>] = []
            items.append(
                AnyComponentWithIdentity(
                    id: "screenshot",
                    component: AnyComponent(InfoParagraphComponent(
                        title: strings.DisableSharing_Screenshot_Title,
                        titleColor: textColor,
                        text: strings.DisableSharing_Screenshot_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/CopyProtection/NoScreenshot",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "forward",
                    component: AnyComponent(InfoParagraphComponent(
                        title: strings.DisableSharing_Forwarding_Title,
                        titleColor: textColor,
                        text: strings.DisableSharing_Forwarding_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/CopyProtection/NoForward",
                        iconColor: linkColor
                    ))
                )
            )
            items.append(
                AnyComponentWithIdentity(
                    id: "save",
                    component: AnyComponent(InfoParagraphComponent(
                        title: strings.DisableSharing_Saving_Title,
                        titleColor: textColor,
                        text: strings.DisableSharing_Saving_Text,
                        textColor: secondaryTextColor,
                        accentColor: linkColor,
                        iconName: "Premium/CopyProtection/NoDownload",
                        iconColor: linkColor
                    ))
                )
            )
            
            let list = list.update(
                component: List(items),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: 10000.0),
                transition: context.transition
            )
            context.add(list
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + list.size.height / 2.0))
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
                    action: { _ in
                        component.dismiss()
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            let buttonContent: AnyComponentWithIdentity<Empty>
            if component.context.isPremium {
                buttonContent = AnyComponentWithIdentity(id: "disable", component: AnyComponent(
                    ButtonTextContentComponent(
                        text: strings.DisableSharing_Confirm,
                        badge: 0,
                        textColor: theme.list.itemCheckColors.foregroundColor,
                        badgeBackground: theme.list.itemCheckColors.foregroundColor,
                        badgeForeground: theme.list.itemCheckColors.fillColor
                    )
                ))
            } else {
                buttonContent = AnyComponentWithIdentity(id: "premium", component: AnyComponent(
                    HStack([
                        AnyComponentWithIdentity(
                            id: AnyHashable("icon"),
                            component: AnyComponent(
                                LottieComponent(
                                    content: LottieComponent.AppBundleContent(name: "premium_unlock"),
                                    color: theme.list.itemCheckColors.foregroundColor,
                                    size: CGSize(width: 30.0, height: 30.0),
                                    playOnce: state.playButtonAnimation
                                )
                            )
                        ),
                        AnyComponentWithIdentity(
                            id: AnyHashable("label"),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: "Unlock with Premium", font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        )
                    ], spacing: 3.0)
                ))
            }
            
            let button = button.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: buttonContent,
                    isEnabled: true,
                    displaysProgress: false,
                    action: {
                        component.dismiss()
                        
                        if let controller = controller() as? PeerCopyProtectionInfoScreen {
                            if component.context.isPremium {
                                controller.completion?()
                            } else if let navigationController = controller.navigationController as? NavigationController {
                                controller.dismissAnimated()
                                let controller = component.context.sharedContext.makePremiumIntroController(context: component.context, source: .presence, forceDark: false, dismissed: nil)
                                navigationController.pushViewController(controller)
                            }
                        }
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - 30.0 * 2.0, height: 52.0),
                transition: .immediate
            )
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentSize.height + button.size.height / 2.0))
            )
            contentSize.height += button.size.height
 
            contentSize.height += 30.0
            
            state.playAnimationIfNeeded()
            
            return contentSize
        }
    }
}

final class PeerCopyProtectionInfoSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    
    init(
        context: AccountContext
    ) {
        self.context = context
    }
    
    static func ==(lhs: PeerCopyProtectionInfoSheetComponent, rhs: PeerCopyProtectionInfoSheetComponent) -> Bool {
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
            
            let dismiss: (Bool) -> Void = { animated in
                if animated {
                    if let controller = controller() as? PeerCopyProtectionInfoScreen {
                        animateOut.invoke(Action { _ in
                            controller.dismiss(completion: nil)
                        })
                    }
                } else {
                    if let controller = controller() as? PeerCopyProtectionInfoScreen {
                        controller.dismiss(completion: nil)
                    }
                }
            }
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(PeerCopyProtectionInfoSheetContent(
                        context: context.component.context,
                        getController: controller,
                        dismiss: {
                            dismiss(true)
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    autoAnimateOut: false,
                    externalState: sheetExternalState,
                    animateOut: animateOut,
                    onPan: {},
                    willDismiss: {}
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
                    inVoiceOver: false
                )
                controller.presentationContext.containerLayoutUpdated(layout, transition: context.transition.containedViewLayoutTransition)
            }
            
            return context.availableSize
        }
    }
}

public final class PeerCopyProtectionInfoScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    fileprivate let completion: (() -> Void)?
    
    public init(
        context: AccountContext,
        completion: (() -> Void)?
    ) {
        self.context = context
        self.completion = completion
        
        super.init(
            context: context,
            component: PeerCopyProtectionInfoSheetComponent(
                context: context
            ),
            navigationBarAppearance: .none,
            statusBarStyle: .ignore,
            theme: .default
        )
        
        self.navigationPresentation = .flatModal
        self.automaticallyControlPresentationContextLayout = false
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.disablesInteractiveModalDismiss = true
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.context.isPremium {
            Queue.mainQueue().after(0.3, {
                let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
                let controller = UndoOverlayController(
                    presentationData: presentationData,
                    content: .premiumPaywall(title: nil, text: "Subscribe to [Telegram Premium]() to unlock this feature.", customUndoText: nil, timeout: nil, linkAction: nil),
                    action: { [weak self] action in
                        guard let self else {
                            return true
                        }
                        if case .info = action, let navigationController = self.navigationController as? NavigationController {
                            self.dismissAnimated()
                            let controller = self.context.sharedContext.makePremiumIntroController(context: self.context, source: .presence, forceDark: false, dismissed: nil)
                            navigationController.pushViewController(controller)
                        }
                        return true
                    }
                )
                self.present(controller, in: .current)
            })
        }
    }

    public func dismissAnimated() {
        if let view = self.node.hostView.findTaggedView(tag: SheetComponent<ViewControllerComponentContainer.Environment>.View.Tag()) as? SheetComponent<ViewControllerComponentContainer.Environment>.View {
            view.dismissAnimated()
        }
    }
}
