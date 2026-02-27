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
import TableComponent
import PresentationDataUtils
import BundleIconComponent
import OverlayStatusController

private final class ProxyServerPreviewSheetContent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let server: ProxyServerSettings
    let cancel: (Bool) -> Void
    
    init(
        context: AccountContext,
        server: ProxyServerSettings,
        cancel: @escaping  (Bool) -> Void
    ) {
        self.context = context
        self.server = server
        self.cancel = cancel
    }
    
    static func ==(lhs: ProxyServerPreviewSheetContent, rhs: ProxyServerPreviewSheetContent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.server != rhs.server {
            return false
        }
        return true
    }
    
    final class State: ComponentState {
        private let context: AccountContext
        private let server: ProxyServerSettings
        
        private var disposable = MetaDisposable()
        private var statusDisposable = MetaDisposable()
        fileprivate var status: ProxyServerStatus?
        private var statusesContext: ProxyServersStatuses?
        
        fileprivate var inProgress = false
        
        fileprivate weak var controller: ProxyServerPreviewScreen?
        
        private var revertSettings: ProxySettings?
        
        init(context: AccountContext, server: ProxyServerSettings) {
            self.context = context
            self.server = server
            
            super.init()
        }
        
        deinit {
            self.disposable.dispose()
            self.statusDisposable.dispose()
            
            if let revertSettings = self.revertSettings {
                let _ = updateProxySettingsInteractively(accountManager: self.context.sharedContext.accountManager, { _ in
                    return revertSettings
                })
            }
        }
        
        var isChecked: Bool {
            return self.statusesContext != nil
        }
        
        func check() {
            guard self.statusesContext == nil else {
                return
            }
            
            self.displayWarningIfNeeded { [weak self] in
                guard let self else {
                    return
                }
                
                let statusesContext = ProxyServersStatuses(network: self.context.account.network, servers: .single([self.server]))
                self.statusesContext = statusesContext
                
                self.status = .checking
                self.updated()
                
                self.statusDisposable.set((statusesContext.statuses()
                |> map { return $0.first?.value }
                |> distinctUntilChanged
                |> deliverOnMainQueue).start(next: { [weak self] status in
                    if let self, let status {
                        self.status = status
                        self.updated()
                    }
                }))
            }
        }
        
        func connect() {
            guard !self.inProgress else {
                return
            }
            
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.displayWarningIfNeeded { [weak self] in
                guard let self else {
                    return
                }
                let accountManager = self.context.sharedContext.accountManager
                let proxyServerSettings = self.server
                let _ = (accountManager.transaction { transaction -> ProxySettings in
                    var currentSettings: ProxySettings?
                    let _ = updateProxySettingsInteractively(transaction: transaction, { settings in
                        currentSettings = settings
                        var settings = settings
                        if let index = settings.servers.firstIndex(of: proxyServerSettings) {
                            settings.servers[index] = proxyServerSettings
                            settings.activeServer = proxyServerSettings
                        } else {
                            settings.servers.insert(proxyServerSettings, at: 0)
                            settings.activeServer = proxyServerSettings
                        }
                        settings.enabled = true
                        return settings
                    })
                    return currentSettings ?? ProxySettings.defaultSettings
                } |> deliverOnMainQueue).start(next: { [weak self] previousSettings in
                    if let self {
                        self.revertSettings = previousSettings
                        
                        self.inProgress = true
                        self.updated()
                        
                        let signal = self.context.account.network.connectionStatus
                        |> filter { status in
                            switch status {
                                case let .online(proxyAddress):
                                    if proxyAddress == proxyServerSettings.host {
                                        return true
                                    } else {
                                        return false
                                    }
                                default:
                                    return false
                            }
                        }
                        |> map { _ -> Bool in
                            return true
                        }
                        |> distinctUntilChanged
                        |> timeout(15.0, queue: Queue.mainQueue(), alternate: .single(false))
                        |> deliverOnMainQueue
                        self.disposable.set(signal.start(next: { [weak self] value in
                            if let self {
                                self.inProgress = false
                                self.updated()
                                
                                self.revertSettings = nil
                                if value {
                                    if let navigationController = self.controller?.navigationController as? NavigationController {
                                        Queue.mainQueue().after(0.5) {
                                            (navigationController.topViewController as? ViewController)?.present(OverlayStatusController(theme: presentationData.theme, type: .shieldSuccess(presentationData.strings.SocksProxySetup_ProxyEnabled, false)), in: .window(.root))
                                        }
                                    }
                                    self.controller?.dismissAnimated()
                                } else {
                                    let _ = updateProxySettingsInteractively(accountManager: accountManager, { _ in
                                        return previousSettings
                                    }).start()
                                    self.controller?.present(textAlertController(sharedContext: self.context.sharedContext, title: nil, text: presentationData.strings.SocksProxySetup_FailedToConnect, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), in: .window(.root))
                                }
                            }
                        }))
                    }
                })
            }
        }
        
        func displayWarningIfNeeded(commit: @escaping () -> Void) {
            guard !self.isChecked else {
                commit()
                return
            }
            let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            let alertController = textAlertController(
                context: context,
                title: presentationData.strings.SocksProxySetup_Warning_Title,
                text: presentationData.strings.SocksProxySetup_Warning_Text,
                actions: [
                    TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                    TextAlertAction(type: .defaultAction, title: presentationData.strings.SocksProxySetup_Warning_Proceed, action: {
                        commit()
                    })
                ]
            )
            self.controller?.present(alertController, in: .window(.root))
        }
    }
    
    func makeState() -> State {
        return State(context: self.context, server: self.server)
    }
    
    static var body: Body {
        let closeButton = Child(GlassBarButtonComponent.self)
        let title = Child(MultilineTextComponent.self)
        let table = Child(TableComponent.self)
        let button = Child(ButtonComponent.self)
        
        return { context in
            let environment = context.environment[ViewControllerComponentContainer.Environment.self].value
            let component = context.component
            let theme = environment.theme
            let strings = environment.strings
            let state = context.state
            if state.controller == nil {
                state.controller = environment.controller() as? ProxyServerPreviewScreen
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
                        
            let title = title.update(
                component: MultilineTextComponent(
                    text: .plain(NSAttributedString(
                        string: strings.SocksProxySetup_Title,
                        font: Font.semibold(17.0),
                        textColor: theme.actionSheet.primaryTextColor,
                        paragraphAlignment: .center
                    )),
                    horizontalAlignment: .center,
                    maximumNumberOfLines: 1
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0 - 60.0, height: CGFloat.greatestFiniteMagnitude),
                transition: .immediate
            )
    
            let tableFont = Font.regular(15.0)
            let tableTextColor = theme.list.itemPrimaryTextColor
            let tableLinkColor = theme.list.itemAccentColor
            var tableItems: [TableComponent.Item] = []
                        
            tableItems.append(.init(
                id: "server",
                title: strings.SocksProxySetup_Hostname,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: component.server.host, font: tableFont, textColor: tableTextColor)))
                )
            ))
            
            tableItems.append(.init(
                id: "port",
                title: strings.SocksProxySetup_Port,
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: "\(component.server.port)", font: tableFont, textColor: tableTextColor)))
                )
            ))
            
            switch component.server.connection {
            case let .socks5(username, password):
                if let username {
                    tableItems.append(.init(
                        id: "username",
                        title: strings.SocksProxySetup_Username,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: username, font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                }
                if let password {
                    tableItems.append(.init(
                        id: "password",
                        title: strings.SocksProxySetup_Password,
                        component: AnyComponent(
                            MultilineTextComponent(text: .plain(NSAttributedString(string: password, font: tableFont, textColor: tableTextColor)))
                        )
                    ))
                }
            case .mtp:
                tableItems.append(.init(
                    id: "secret",
                    title: strings.SocksProxySetup_Secret,
                    component: AnyComponent(
                        MultilineTextComponent(text: .plain(NSAttributedString(string: "•••••", font: tableFont, textColor: tableTextColor)))
                    )
                ))
            }
            
            var statusText = strings.SocksProxySetup_CheckStatus
            var statusColor = tableLinkColor
            var statusIsActive = true
            if let status = state.status {
                statusIsActive = false
                switch status {
                case let .available(rtt):
                    let pingTime = Int(rtt * 1000.0)
                    statusText = strings.SocksProxySetup_ProxyStatusPing("\(pingTime)").string
                    statusColor = tableTextColor
                case .checking:
                    statusText = strings.SocksProxySetup_ProxyStatusChecking
                    statusColor = tableTextColor
                case .notAvailable:
                    statusText = strings.SocksProxySetup_ProxyStatusUnavailable
                    statusColor = environment.theme.list.itemDestructiveColor
                }
            }
            
            tableItems.append(.init(
                id: "status",
                title: strings.SocksProxySetup_Status,
                component: AnyComponent(
                    Button(
                        content: AnyComponent(MultilineTextComponent(text: .plain(NSAttributedString(string: statusText, font: tableFont, textColor: statusColor)))),
                        automaticHighlight: statusIsActive,
                        action: {
                            if statusIsActive {
                                state.check()
                            }
                        }
                    )
                )
            ))
            let table = table.update(
                component: TableComponent(
                    theme: environment.theme,
                    items: tableItems
                ),
                availableSize: CGSize(width: context.availableSize.width - sideInset * 2.0, height: .greatestFiniteMagnitude),
                transition: .immediate
            )
            
            let buttonInsets = ContainerViewLayout.concentricInsets(bottomInset: environment.safeInsets.bottom, innerDiameter: 52.0, sideInset: 30.0)
            let button = button.update(
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
                        component: AnyComponent(MultilineTextComponent(text: .plain(NSMutableAttributedString(string: strings.SocksProxySetup_ConnectAndSave, font: Font.semibold(17.0), textColor: theme.list.itemCheckColors.foregroundColor, paragraphAlignment: .center))))
                    ),
                    displaysProgress: state.inProgress,
                    action: {
                        state.connect()
                    }
                ),
                availableSize: CGSize(width: context.availableSize.width - buttonInsets.left - buttonInsets.right, height: 52.0),
                transition: .immediate
            )
            
            context.add(title
                .position(CGPoint(x: context.availableSize.width / 2.0, y: 38.0))
            )
            
            var originY: CGFloat = 88.0
            context.add(table
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + table.size.height / 2.0))
            )
            originY += table.size.height + 28.0
            
            context.add(button
                .position(CGPoint(x: context.availableSize.width / 2.0, y: originY + button.size.height / 2.0))
            )
            originY += button.size.height
            originY += buttonInsets.bottom
            
            context.add(closeButton
                .position(CGPoint(x: 16.0 + closeButton.size.width / 2.0, y: 16.0 + closeButton.size.height / 2.0))
            )
            
            let contentSize = CGSize(width: context.availableSize.width, height: originY)
            return contentSize
        }
    }
}

private final class ProxyServerPreviewSheetComponent: CombinedComponent {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment
    
    let context: AccountContext
    let server: ProxyServerSettings
    
    init(
        context: AccountContext,
        server: ProxyServerSettings
    ) {
        self.context = context
        self.server = server
    }
    
    static func ==(lhs: ProxyServerPreviewSheetComponent, rhs: ProxyServerPreviewSheetComponent) -> Bool {
        if lhs.context !== rhs.context {
            return false
        }
        if lhs.server != rhs.server {
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
                    content: AnyComponent<EnvironmentType>(ProxyServerPreviewSheetContent(
                        context: context.component.context,
                        server: context.component.server,
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
                    backgroundColor: .color(environment.theme.actionSheet.opaqueItemBackgroundColor),
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

public class ProxyServerPreviewScreen: ViewControllerComponentContainer {
    private let context: AccountContext
    
    public init(
        context: AccountContext,
        server: ProxyServerSettings
    ) {
        self.context = context
        
        super.init(
            context: context,
            component: ProxyServerPreviewSheetComponent(
                context: context,
                server: server
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
