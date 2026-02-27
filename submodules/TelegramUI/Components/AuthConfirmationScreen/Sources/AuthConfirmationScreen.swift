import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import AccountContext
import TelegramPresentationData
import ComponentFlow
import ViewControllerComponent
import SheetComponent
import MultilineTextComponent
import GlassBarButtonComponent
import ButtonComponent
import PresentationDataUtils
import BundleIconComponent
import ListSectionComponent
import ListActionItemComponent
import AvatarComponent
import Markdown
import PhoneNumberFormat
import ContextUI
import AccountUtils
import GlassBackgroundComponent
import AccountPeerContextItem

private final class AuthConfirmationSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: MessageActionUrlAuthResult
    let completion: (AccountContext, EnginePeer, Bool, Bool) -> Void
    let cancel: (Bool) -> Void
    
    init(
        context: AccountContext,
        subject: MessageActionUrlAuthResult,
        completion: @escaping (AccountContext, EnginePeer, Bool, Bool) -> Void,
        cancel: @escaping  (Bool) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.completion = completion
        self.cancel = cancel
    }
    
    static func ==(lhs: AuthConfirmationSheetContent, rhs: AuthConfirmationSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let subject: MessageActionUrlAuthResult
        
        var peer: EnginePeer?
        var forcedAccount: (AccountContext, EnginePeer)?
        
        fileprivate var inProgress = false
        var allowWrite = true
        weak var controller: ViewController?
        
        init(context: AccountContext, subject: MessageActionUrlAuthResult) {
            self.context = context
            self.subject = subject
                        
            super.init()
            
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let peer else {
                    return
                }
                self.peer = peer
                self.updated()
            })
        }
        
        func displayPhoneNumberConfirmation(commit: @escaping (Bool) -> Void) {
            guard case let .request(domain, _, _, _) = self.subject else {
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, case let .user(user) = peer, let phone = user.phone else {
                    return
                }
                let phoneNumber = formatPhoneNumber(context: self.context, number: phone).replacingOccurrences(of: " ", with: "\u{00A0}")
                
                let alertController = textAlertController(
                    context: self.context,
                    title: presentationData.strings.AuthConfirmation_PhoneNumberConfirmation_Title,
                    text: presentationData.strings.AuthConfirmation_PhoneNumberConfirmation_Text(domain, phoneNumber).string,
                    actions: [
                        TextAlertAction(type: .genericAction, title: presentationData.strings.AuthConfirmation_PhoneNumberConfirmation_Deny, action: {
                            commit(false)
                        }),
                        TextAlertAction(type: .defaultAction, title: presentationData.strings.AuthConfirmation_PhoneNumberConfirmation_Allow, action: {
                            commit(true)
                        })
                    ]
                )
                self.controller?.present(alertController, in: .window(.root))
            })
        }
        
        func presentAccountSwitchMenu(sourceView: GlassContextExtractableContainer) {
            guard let controller = self.controller else {
                return
            }
            
            let context = self.context
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let items: Signal<[ContextMenuItem], NoError> = activeAccountsAndPeers(context: self.context, includePrimary: true)
            |> take(1)
            |> map { primary, other -> [ContextMenuItem] in
                var items: [ContextMenuItem] = []
                var existingIds = Set<EnginePeer.Id>()
                if let (_, peer) = primary {
                    items.append(.custom(AccountPeerContextItem(context: context, account: context.account, peer: peer, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        self.forcedAccount = nil
                        self.updated()
                    }), true))
                    existingIds.insert(peer.id)
                }
                
                for (accountContext, peer, _) in other {
                    guard !existingIds.contains(peer.id) else {
                        continue
                    }
                    items.append(.custom(AccountPeerContextItem(context: accountContext, account: accountContext.account, peer: peer, action: { [weak self] _, f in
                        f(.default)
                        guard let self else {
                            return
                        }
                        self.forcedAccount = (accountContext, peer)
                        self.updated()
                    }), true))
                }
                
                return items
            }

            let contextController = makeContextController(presentationData: presentationData, source: .reference(AuthConfirmationReferenceContentSource(controller: controller, sourceView: sourceView)), items: items |> map { ContextController.Items(content: .list($0)) }, gesture: nil)
            controller.presentInGlobalOverlay(contextController)
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, subject: self.subject)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let accountButton = Child(AccountSwitchComponent.self)
        let avatar = Child(AvatarComponent.self)
        let title = Child(MultilineTextComponent.self)
        let description = Child(MultilineTextComponent.self)
        let clientSection = Child(ListSectionComponent.self)
        let optionsSection = Child(ListSectionComponent.self)
        let cancelButton = Child(ButtonComponent.self)
        let doneButton = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let state = context.state
            if state.controller == nil {
                state.controller = environment.controller()
            }
            
            let presentationData = context.component.context.sharedContext.currentPresentationData.with { $0 }
            let _ = strings
            
            guard case let .request(domain, bot, clientData, flags) = component.subject else {
                fatalError()
            }

            let sideInset: CGFloat = 16.0 + environment.safeInsets.left
            
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
                        component.cancel(true)
                    }
                ),
                availableSize: CGSize(width: 44.0, height: 44.0),
                transition: .immediate
            )
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            if let peer = state.peer {
                let accountButton = accountButton.update(
                    component: AccountSwitchComponent(
                        context: state.forcedAccount?.0 ?? component.context,
                        theme: environment.theme,
                        peer: state.forcedAccount?.1 ?? peer,
                        canSwitch: true,
                        action: { [weak state] sourceView in
                            state?.presentAccountSwitchMenu(sourceView: sourceView)
                        }
                    ),
                    availableSize: context.availableSize,
                    transition: .immediate
                )
                context.add(accountButton
                    .position(CGPoint(x: context.availableSize.width - 16.0 - accountButton.size.width / 2.0, y: 16.0 + accountButton.size.height / 2.0))
                )
            }
            
            var contentHeight: CGFloat = 32.0
            let avatar = avatar.update(
                component: AvatarComponent(
                    context: component.context,
                    theme: environment.theme,
                    peer: EnginePeer(bot),
                    clipStyle: .roundedRect
                ),
                availableSize: CGSize(width: 92.0, height: 92.0),
                transition: .immediate
            )
            context.add(avatar
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + avatar.size.height / 2.0))
            )
            contentHeight += avatar.size.height
            contentHeight += 18.0
                        
            let titleFont = Font.bold(24.0)
            let title = title.update(
                component: MultilineTextComponent(
                    text: .markdown(text: strings.AuthConfirmation_Title(domain).string, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.controlAccentColor), link: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil })),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 2
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + title.size.height / 2.0))
            )
            contentHeight += title.size.height
            contentHeight += 16.0
            
            let textFont = Font.regular(15.0)
            let boldTextFont = Font.semibold(15.0)
            let description = description.update(
                component: MultilineTextComponent(
                    text: .markdown(text: strings.AuthConfirmation_Description, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: textFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: boldTextFont, textColor: theme.actionSheet.primaryTextColor), link: MarkdownAttributeSet(font: textFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil })),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 3,
                    lineSpacing: 0.2
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
            context.add(description
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + description.size.height / 2.0))
            )
            contentHeight += description.size.height
            contentHeight += 16.0
            
            var clientSectionItems: [AnyComponentWithIdentity<Empty>] = []
            clientSectionItems.append(
                AnyComponentWithIdentity(id: "device", component: AnyComponent(
                    ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.AuthConfirmation_Device,
                                font: Font.regular(17.0),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        contentInsets: UIEdgeInsets(top: 19.0, left: 0.0, bottom: 19.0, right: 0.0),
                        accessory: .custom(ListActionItemComponent.CustomAccessory(
                            component: AnyComponentWithIdentity(
                                id: "info",
                                component: AnyComponent(
                                    VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                            text: .plain(NSAttributedString(
                                                string: clientData?.platform ?? "",
                                                font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                                textColor: theme.list.itemPrimaryTextColor
                                            )),
                                            maximumNumberOfLines: 1
                                        ))),
                                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                            text: .plain(NSAttributedString(
                                                string: clientData?.browser ?? "",
                                                font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 15.0),
                                                textColor: theme.list.itemSecondaryTextColor
                                            )),
                                            horizontalAlignment: .left,
                                            truncationType: .middle,
                                            maximumNumberOfLines: 1
                                        )))
                                    ], alignment: .right, spacing: 3.0)
                                )
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                            isInteractive: true
                        )),
                        action: nil
                    )
                ))
            )
            
            clientSectionItems.append(
                AnyComponentWithIdentity(id: "region", component: AnyComponent(
                    ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.AuthConfirmation_IpAddress,
                                font: Font.regular(17.0),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        contentInsets: UIEdgeInsets(top: 19.0, left: 0.0, bottom: 19.0, right: 0.0),
                        accessory: .custom(ListActionItemComponent.CustomAccessory(
                            component: AnyComponentWithIdentity(
                                id: "info",
                                component: AnyComponent(
                                    VStack([
                                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                            text: .plain(NSAttributedString(
                                                string: clientData?.ip ?? "",
                                                font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                                textColor: theme.list.itemPrimaryTextColor
                                            )),
                                            maximumNumberOfLines: 1
                                        ))),
                                        AnyComponentWithIdentity(id: AnyHashable(1), component: AnyComponent(MultilineTextComponent(
                                            text: .plain(NSAttributedString(
                                                string: clientData?.region ?? "",
                                                font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize / 17.0 * 15.0),
                                                textColor: theme.list.itemSecondaryTextColor
                                            )),
                                            horizontalAlignment: .left,
                                            truncationType: .middle,
                                            maximumNumberOfLines: 1
                                        )))
                                    ], alignment: .right, spacing: 3.0)
                                )
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                            isInteractive: true
                        )),
                        action: nil
                    )
                ))
            )
            
            let clientSection = clientSection.update(
                component: ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: nil,
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: strings.AuthConfirmation_Info,
                            font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                            textColor: environment.theme.list.freeTextColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    items: clientSectionItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                transition: context.transition
            )
            context.add(clientSection
                .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + clientSection.size.height / 2.0))
            )
            contentHeight += clientSection.size.height
            
            if flags.contains(.requestWriteAccess) {
                contentHeight += 38.0
                
                var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
                optionsSectionItems.append(AnyComponentWithIdentity(id: "allowWrite", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(VStack([
                        AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.AuthConfirmation_AllowMessages,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        ))),
                    ], alignment: .left, spacing: 2.0)),
                    accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: state.allowWrite, action: { [weak state] _ in
                        guard let state else {
                            return
                        }
                        state.allowWrite = !state.allowWrite
                        state.updated()
                    })),
                    action: nil
                ))))
                let optionsSection = optionsSection.update(
                    component: ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: nil,
                        footer: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.AuthConfirmation_AllowMessagesInfo(EnginePeer(bot).compactDisplayTitle).string,
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: environment.theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        items: optionsSectionItems
                    ),
                    availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: context.availableSize.height),
                    transition: context.transition
                )
                context.add(optionsSection
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + optionsSection.size.height / 2.0))
                )
                contentHeight += optionsSection.size.height
            }
            contentHeight += 32.0
    
            let buttonSpacing: CGFloat = 10.0
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let buttonWidth = (context.availableSize.width - buttonInsets.left - buttonInsets.right - buttonSpacing) / 2.0
            
            let cancelButton = cancelButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemPrimaryTextColor.withMultipliedAlpha(0.1),
                        foreground: theme.list.itemPrimaryTextColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.AuthConfirmation_Cancel, font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor, paragraphAlignment: .center))))
                    ),
                    action: {
                        component.cancel(true)
                    }
                ),
                availableSize: CGSize(width: buttonWidth, height: 52.0),
                transition: .immediate
            )
            context.add(cancelButton
                .position(CGPoint(x: context.availableSize.width / 2.0 - buttonSpacing / 2.0 - cancelButton.size.width / 2.0, y: contentHeight + cancelButton.size.height / 2.0))
            )
            
            let doneButton = doneButton.update(
                component: ButtonComponent(
                    background: ButtonComponent.Background(
                        style: .glass,
                        color: theme.list.itemCheckColors.fillColor,
                        foreground: theme.list.itemCheckColors.foregroundColor,
                        pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9),
                        cornerRadius: 10.0,
                    ),
                    content: AnyComponentWithIdentity(
                        id: AnyHashable(0),
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.AuthConfirmation_LogIn, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    displaysProgress: state.inProgress,
                    action: { [weak state] in
                        guard let state else {
                            return
                        }
                        var allowWrite = false
                        if flags.contains(.requestWriteAccess) && state.allowWrite {
                            allowWrite = true
                        }
                        
                        let accountContext = state.forcedAccount?.0 ?? component.context
                        guard let accountPeer = state.forcedAccount?.1 ?? state.peer else {
                            return
                        }
                        
                        if flags.contains(.requestPhoneNumber) {
                            state.displayPhoneNumberConfirmation(commit: { sharePhoneNumber in
                                component.completion(accountContext, accountPeer, allowWrite, sharePhoneNumber)
                                state.inProgress = true
                                state.updated()
                            })
                        } else {
                            component.completion(accountContext, accountPeer, allowWrite, false)
                            state.inProgress = true
                            state.updated()
                        }
                    }
                ),
                availableSize: CGSize(width: buttonWidth, height: 52.0),
                transition: .immediate
            )
            context.add(doneButton
                .position(CGPoint(x: context.availableSize.width / 2.0 + buttonSpacing / 2.0 + doneButton.size.width / 2.0, y: contentHeight + doneButton.size.height / 2.0))
            )
            contentHeight += doneButton.size.height
            contentHeight += buttonInsets.bottom
          
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class AuthConfirmationSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: MessageActionUrlAuthResult
    let completion: (AccountContext, EnginePeer, Bool, Bool) -> Void
    
    init(
        context: AccountContext,
        subject: MessageActionUrlAuthResult,
        completion: @escaping (AccountContext, EnginePeer, Bool, Bool) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.completion = completion
    }
    
    static func ==(lhs: AuthConfirmationSheetComponent, rhs: AuthConfirmationSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    static var body: Body {
        let sheet = Child(SheetComponent<EnvironmentType>.self)
        let animateOut = StoredActionSlot(Action<Void>.self)
        
        return { context in
            let environment = context.environment[EnvironmentType.self]
            let controller = environment.controller
            
            let sheet = sheet.update(
                component: SheetComponent<EnvironmentType>(
                    content: AnyComponent<EnvironmentType>(AuthConfirmationSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
                        completion: context.component.completion,
                        cancel: { animate in
                            if animate {
                                animateOut.invoke(Action { _ in
                                    if let controller = controller() {
                                        controller.dismiss(completion: nil)
                                    }
                                })
                            } else if let controller = controller() {
                                controller.dismiss(animated: false, completion: nil)
                            }
                        }
                    )),
                    style: .glass,
                    backgroundColor: .color(environment.theme.list.modalBlocksBackgroundColor),
                    followContentSizeChanges: true,
                    clipsContent: true,
                    animateOut: animateOut
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
            
            return context.availableSize
        }
    }
}

public class AuthConfirmationScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    private let subject: MessageActionUrlAuthResult
    fileprivate let completion: (AccountContext, EnginePeer, Bool, Bool) -> Void
    
    public init(
        context: AccountContext,
        subject: MessageActionUrlAuthResult,
        completion: @escaping (AccountContext, EnginePeer, Bool, Bool) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.completion = completion
        
        super.init(
            context: context,
            component: AuthConfirmationSheetComponent(
                context: context,
                subject: subject,
                completion: completion
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

private final class AuthConfirmationReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceView: UIView
    
    let forceDisplayBelowKeyboard = true
    
    init(controller: ViewController, sourceView: UIView) {
        self.controller = controller
        self.sourceView = sourceView
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}
