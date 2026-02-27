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
import BalancedTextComponent
import GlassBarButtonComponent
import ButtonComponent
import TableComponent
import PresentationDataUtils
import BundleIconComponent
import LottieAnimationComponent
import ListSectionComponent
import ListActionItemComponent
import AvatarComponent
import TelegramStringFormatting
import Markdown

private final class RecentSessionSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: RecentSessionScreen.Subject
    let cancel: (Bool) -> Void
    
    init(
        context: AccountContext,
        subject: RecentSessionScreen.Subject,
        cancel: @escaping  (Bool) -> Void
    ) {
        self.context = context
        self.subject = subject
        self.cancel = cancel
    }
    
    static func ==(lhs: RecentSessionSheetContent, rhs: RecentSessionSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        var allowSecretChats: Bool?
        var allowIncomingCalls: Bool?
        
        weak var controller: RecentSessionScreen?
        
        init(subject: RecentSessionScreen.Subject) {
            super.init()
            
            switch subject {
            case let .session(session):
                if !session.flags.contains(.passwordPending) && session.apiId != 22 {
                    self.allowIncomingCalls = session.flags.contains(.acceptsIncomingCalls)
                    
                    if ![2040, 2496].contains(session.apiId) {
                        self.allowSecretChats = session.flags.contains(.acceptsSecretChats)
                    }
                }
            case .website:
                break
            }
        }
        
        func toggleAllowSecretChats() {
            guard let controller = self.controller else {
                return
            }
            
            if let allowSecretChats = self.allowSecretChats {
                let newValue = !allowSecretChats
                self.allowSecretChats = newValue
                controller.updateAcceptSecretChats(newValue)
            }
            
            self.updated()
        }
        
        func toggleAllowIncomingCalls() {
            guard let controller = self.controller else {
                return
            }
            
            if let allowIncomingCalls = self.allowIncomingCalls {
                let newValue = !allowIncomingCalls
                self.allowIncomingCalls = newValue
                controller.updateAcceptIncomingCalls(newValue)
            }
            
            self.updated()
        }
        
        func terminate() {
            guard let controller = self.controller else {
                return
            }
            self.updated()
            
            controller.remove({ [weak controller] in
                controller?.dismissAnimated()
            })
        }
    }
    
    func makeState() -> State {
        return State(subject: self.subject)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let icon = Child(ZStack<Empty>.self)
        let avatar = Child(AvatarComponent.self)
        let title = Child(BalancedTextComponent.self)
        let description = Child(MultilineTextComponent.self)
        let clientSection = Child(ListSectionComponent.self)
        let optionsSection = Child(ListSectionComponent.self)
        let button = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let state = context.state
            if state.controller == nil {
                state.controller = environment.controller() as? RecentSessionScreen
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
            
            var contentHeight: CGFloat = 32.0
            switch component.subject {
            case let .session(session):
                let (image, backgroundColor, animationName, colorsArray) = iconForSession(session)
                
                var items: [AnyComponentWithIdentity<Empty>] = []
                items.append(
                    AnyComponentWithIdentity(
                        id: "background",
                        component: AnyComponent(
                            FilledRoundedRectangleComponent(
                                color: backgroundColor ?? .clear,
                                cornerRadius: .value(20.0),
                                smoothCorners: true
                            )
                        )
                    )
                )
                if let animationName {
                    var colors: [String: UIColor] = [:]
                    if let colorsArray {
                        for color in colorsArray {
                            colors[color] = backgroundColor
                        }
                    }
                    items.append(
                        AnyComponentWithIdentity(
                            id: "animation",
                            component: AnyComponent(
                                LottieAnimationComponent(
                                    animation: .init(name: animationName, mode: .animating(loop: false)),
                                    colors: colors,
                                    size: CGSize(width: 92.0, height: 92.0)
                                )
                            )
                        )
                    )
                } else if let image {
                    items.append(
                        AnyComponentWithIdentity(
                            id: "icon",
                            component: AnyComponent(
                                Image(image: image)
                            )
                        )
                    )
                }
                
                let icon = icon.update(
                    component: ZStack(items),
                    availableSize: CGSize(width: 92.0, height: 92.0),
                    transition: .immediate
                )
                context.add(icon
                    .position(CGPoint(x: context.availableSize.width / 2.0, y: contentHeight + icon.size.height / 2.0))
                )
                contentHeight += icon.size.height
                contentHeight += 18.0
            case let .website(_, peer):
                if let peer {
                    let avatar = avatar.update(
                        component: AvatarComponent(
                            context: component.context,
                            theme: environment.theme,
                            peer: peer,
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
                }
            }
            
            let titleString: String
            let subtitleString: String
            let subtitleActive: Bool
            let applicationTitle: String
            let applicationString: String
            let ipString: String?
            let locationString: String
            let buttonString: String?
            
            switch component.subject {
            case let .session(session):
                titleString = session.deviceModel
                if session.isCurrent {
                    subtitleString = strings.Presence_online
                    subtitleActive = true
                } else {
                    let timestamp = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970)
                    subtitleString = stringForRelativeActivityTimestamp(strings: strings, dateTimeFormat: presentationData.dateTimeFormat, relativeTimestamp: session.activityDate, relativeTo: timestamp)
                    subtitleActive = false
                }
                var appVersion = session.appVersion
                appVersion = appVersion.replacingOccurrences(of: "APPSTORE", with: "").replacingOccurrences(of: "BETA", with: "Beta").trimmingTrailingSpaces()
                applicationTitle = strings.AuthSessions_View_Application
                applicationString =  "\(session.appName) \(appVersion)"
                ipString = nil
                locationString = session.country
                
                buttonString = !session.isCurrent ? strings.AuthSessions_View_TerminateSession : nil
            case let .website(website, peer):
                titleString = peer?.compactDisplayTitle ?? ""
                subtitleString = website.domain
                subtitleActive = false
                
                var deviceString = ""
                if !website.browser.isEmpty {
                    deviceString += website.browser
                }
                if !website.platform.isEmpty {
                    if !deviceString.isEmpty {
                        deviceString += ", "
                    }
                    deviceString += website.platform
                }
                applicationTitle = strings.AuthSessions_View_Browser
                applicationString = deviceString
                ipString = website.ip
                locationString = website.region
                
                buttonString = strings.AuthSessions_View_Logout
            }
            
            let titleFont = Font.bold(24.0)
            let title = title.update(
                component: BalancedTextComponent(
                    text: .markdown(text: titleString, attributes: MarkdownAttributes(body: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), bold: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.controlAccentColor), link: MarkdownAttributeSet(font: titleFont, textColor: theme.actionSheet.primaryTextColor), linkAttribute: { _ in return nil })),
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
            contentHeight += 2.0
            
            let textFont = Font.regular(15.0)
            let description = description.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(string: subtitleString, font: textFont, textColor: subtitleActive ? theme.actionSheet.controlAccentColor : theme.actionSheet.secondaryTextColor)),
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
            contentHeight += 22.0
            
            var clientSectionItems: [AnyComponentWithIdentity<Empty>] = []
            clientSectionItems.append(
                AnyComponentWithIdentity(id: "application", component: AnyComponent(
                    ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: applicationTitle,
                                font: Font.regular(17.0),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        accessory: .custom(ListActionItemComponent.CustomAccessory(
                            component: AnyComponentWithIdentity(
                                id: "info",
                                component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: applicationString,
                                        font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                        textColor: theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))
                            ),
                            insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                            isInteractive: true
                        )),
                        action: nil
                    )
                ))
            )
            
            if let ipString {
                clientSectionItems.append(
                    AnyComponentWithIdentity(id: "ip", component: AnyComponent(
                        ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthSessions_View_IP,
                                    font: Font.regular(17.0),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            )),
                            accessory: .custom(ListActionItemComponent.CustomAccessory(
                                component: AnyComponentWithIdentity(
                                    id: "info",
                                    component: AnyComponent(MultilineTextComponent(
                                        text: .plain(NSAttributedString(
                                            string: ipString,
                                            font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                            textColor: theme.list.itemSecondaryTextColor
                                        )),
                                        maximumNumberOfLines: 1
                                    ))
                                ),
                                insets: UIEdgeInsets(top: 0.0, left: 8.0, bottom: 0.0, right: 14.0),
                                isInteractive: true
                            )),
                            action: nil
                        )
                    ))
                )
            }
            
            clientSectionItems.append(
                AnyComponentWithIdentity(id: "region", component: AnyComponent(
                    ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.AuthSessions_View_Location,
                                font: Font.regular(17.0),
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )),
                        accessory: .custom(ListActionItemComponent.CustomAccessory(
                            component: AnyComponentWithIdentity(
                                id: "info",
                                component: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: locationString,
                                        font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                        textColor: theme.list.itemSecondaryTextColor
                                    )),
                                    maximumNumberOfLines: 1
                                ))
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
                            string: strings.AuthSessions_View_LocationInfo,
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
            
            if state.allowSecretChats != nil || state.allowIncomingCalls != nil {
                contentHeight += 38.0
                
                var optionsSectionItems: [AnyComponentWithIdentity<Empty>] = []
                
                if let allowSecretChats = state.allowSecretChats {
                    optionsSectionItems.append(AnyComponentWithIdentity(id: "allowSecretChats", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthSessions_View_AcceptSecretChats,
                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: allowSecretChats, action: { [weak state] _ in
                            guard let state else {
                                return
                            }
                            state.toggleAllowSecretChats()
                        })),
                        action: nil
                    ))))
                }
                if let allowIncomingCalls = state.allowIncomingCalls {
                    optionsSectionItems.append(AnyComponentWithIdentity(id: "allowIncomingCalls", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(VStack([
                            AnyComponentWithIdentity(id: AnyHashable(0), component: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.AuthSessions_View_AcceptIncomingCalls,
                                    font: Font.regular(presentationData.listsFontSize.itemListBaseFontSize),
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 1
                            ))),
                        ], alignment: .left, spacing: 2.0)),
                        accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: allowIncomingCalls, action: { [weak state] _ in
                            guard let state else {
                                return
                            }
                            state.toggleAllowIncomingCalls()
                        })),
                        action: nil
                    ))))
                }
                let optionsSection = optionsSection.update(
                    component: ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: environment.strings.AuthSessions_View_AcceptTitle.uppercased(),
                                font: Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize),
                                textColor: theme.list.freeTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        footer: nil,
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
            
            if let buttonString {
                let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
                let button = button.update(
                    component: ButtonComponent(
                        background: ButtonComponent.Background(
                            style: .glass,
                            color: theme.list.itemDestructiveColor,
                            foreground: .white,
                            pressedColor: theme.list.itemCheckColors.fillColor.withMultipliedAlpha(0.9)
                        ),
                        content: AnyComponentWithIdentity(
                            id: AnyHashable(0),
                            component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: buttonString, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                        ),
                        action: { [weak state] in
                            state?.terminate()
                        }
                    ),
                    availableSize: CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0),
                    transition: .immediate
                )
                context.add(button
                    .position(CGPoint(x: context.availableSize.width / 2.0 , y: contentHeight + button.size.height / 2.0))
                )
                contentHeight += button.size.height
                contentHeight += buttonInsets.bottom
            }
            
            return CGSize(width: context.availableSize.width, height: contentHeight)
        }
    }
}

private final class RecentSessionSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let subject: RecentSessionScreen.Subject
    
    init(
        context: AccountContext,
        subject: RecentSessionScreen.Subject
    ) {
        self.context = context
        self.subject = subject
    }
    
    static func ==(lhs: RecentSessionSheetComponent, rhs: RecentSessionSheetComponent) -> Bool {
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
                    content: AnyComponent<EnvironmentType>(RecentSessionSheetContent(
                        context: context.component.context,
                        subject: context.component.subject,
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

public class RecentSessionScreen: ViewControllerComponentContainer {
    public enum Subject {
        case session(RecentAccountSession)
        case website(WebAuthorization, EnginePeer?)
    }
    
    private let context: AccountContext
    fileprivate let updateAcceptSecretChats: (Bool) -> Void
    fileprivate let updateAcceptIncomingCalls: (Bool) -> Void
    fileprivate let remove: (@escaping () -> Void) -> Void
    
    public init(
        context: AccountContext,
        subject: RecentSessionScreen.Subject,
        updateAcceptSecretChats: @escaping (Bool) -> Void,
        updateAcceptIncomingCalls: @escaping (Bool) -> Void,
        remove: @escaping (@escaping () -> Void) -> Void
    ) {
        self.context = context
        self.updateAcceptSecretChats = updateAcceptSecretChats
        self.updateAcceptIncomingCalls = updateAcceptIncomingCalls
        self.remove = remove
        
        super.init(
            context: context,
            component: RecentSessionSheetComponent(
                context: context,
                subject: subject
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
