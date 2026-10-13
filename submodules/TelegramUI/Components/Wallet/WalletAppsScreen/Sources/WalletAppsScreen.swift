import Foundation
import UIKit
import Display
import AccountContext
import WalletContext
import WalletConnectScreen
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import ItemListUI
import BundleIconComponent
import ListSectionComponent
import ListActionItemComponent
import AlertComponent
import UndoUI

private func connectedAppSessions(_ sessions: [WalletContext.TonConnectSession]) -> [WalletContext.TonConnectSession] {
    return sessions.filter { session in
        guard session.manifest != nil else {
            return false
        }
        return session.status == .connected || session.status == .disconnecting
    }
}

private func presentDisconnectedOverlay(presentationData: PresentationData, controller: ViewController, text: String) {
    controller.present(UndoOverlayController(
        presentationData: presentationData,
        content: .actionSucceeded(title: nil, text: text, cancel: nil, destructive: false),
        position: .bottom,
        action: { _ in false }
    ), in: .current)
}

private final class WalletAppsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)
    let walletContext: WalletContext

    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>), walletContext: WalletContext) {
        self.context = context
        self.updatedPresentationData = updatedPresentationData
        self.walletContext = walletContext
    }

    static func ==(lhs: WalletAppsScreenComponent, rhs: WalletAppsScreenComponent) -> Bool {
        return lhs.context === rhs.context
            && lhs.updatedPresentationData.initial === rhs.updatedPresentationData.initial
            && lhs.updatedPresentationData.signal === rhs.updatedPresentationData.signal
            && lhs.walletContext === rhs.walletContext
    }

    final class View: UIView {
        private let scrollView = UIScrollView()
        private let section = ComponentView<Empty>()
        private let sessionsDisposable = MetaDisposable()
        private let operationDisposable = MetaDisposable()
        private var component: WalletAppsScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
        private var sessions: [WalletContext.TonConnectSession]?
        private var operationId: UUID?
        private var operationSessionIds = Set<Int64>()
        private var operationToast: String?
        private var operationCompletion: ((Bool) -> Void)?
        private weak var infoController: WalletAppInfoScreen?
        private weak var allAppsAlert: AlertScreen?
        private var allAppsProgress: ValuePromise<Bool>?
        private var pendingToast: String?
        private var isUpdating = false
        private var reconciliationScheduled = false
        private var isDismissingAlert = false

        var isDisconnecting: Bool {
            return self.operationId != nil
        }

        private func currentPresentationData(for component: WalletAppsScreenComponent) -> (initial: PresentationData, signal: Signal<PresentationData, NoError>) {
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            return (
                initial: presentationData.withUpdated(theme: self.environment?.theme ?? component.updatedPresentationData.initial.theme),
                signal: component.updatedPresentationData.signal
            )
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.alwaysBounceVertical = true
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.sessionsDisposable.dispose()
            self.operationDisposable.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(.zero, animated: true)
        }

        func scheduleReconciliation() {
            guard !self.reconciliationScheduled else {
                return
            }
            self.reconciliationScheduled = true
            Queue.mainQueue().async { [weak self] in
                guard let self else {
                    return
                }
                self.reconciliationScheduled = false
                self.reconcilePresentations()
            }
        }

        private func reconcilePresentations() {
            guard !self.isDisconnecting, !self.isDismissingAlert,
                  let component = self.component, let sessions = self.sessions,
                  let controller = self.environment?.controller() as? WalletAppsScreen,
                  controller.hasAppeared, !controller.isFinishing else {
                return
            }
            let apps = connectedAppSessions(sessions)
            if let infoController = self.infoController {
                if !apps.contains(where: { $0.id == infoController.sessionId }) {
                    infoController.dismissAnimated()
                }
                return
            }
            if apps.isEmpty {
                if self.allAppsAlert != nil {
                    self.dismissAllAppsAlert()
                    return
                }
                let toast = self.pendingToast
                self.pendingToast = nil
                controller.finish(toast: toast, presentationData: self.currentPresentationData(for: component).initial)
            } else if self.allAppsAlert == nil, let toast = self.pendingToast {
                self.pendingToast = nil
                presentDisconnectedOverlay(presentationData: self.currentPresentationData(for: component).initial, controller: controller, text: toast)
            }
        }

        private func openApp(_ session: WalletContext.TonConnectSession) {
            guard !self.isDisconnecting, self.infoController == nil, self.allAppsAlert == nil,
                  let component = self.component, let manifest = session.manifest,
                  let controller = self.environment?.controller() as? WalletAppsScreen,
                  !controller.isFinishing,
                  connectedAppSessions(self.sessions ?? []).contains(where: { $0.id == session.id }) else {
                return
            }
            let infoController = WalletAppInfoScreen(
                context: component.context,
                updatedPresentationData: self.currentPresentationData(for: component),
                sessionId: session.id,
                manifest: manifest,
                disconnect: { [weak self] completion in
                    guard let self else {
                        completion(false)
                        return
                    }
                    self.disconnect(ids: [session.id], all: false, toast: self.currentPresentationData(for: component).initial.strings.Wallet_Apps_Disconnected(manifest.name).string, completion: completion)
                },
                closed: { [weak self] in
                    self?.infoController = nil
                    self?.scheduleReconciliation()
                }
            )
            self.infoController = infoController
            controller.push(infoController)
        }

        private func presentDisconnectAllAlert() {
            guard !self.isDisconnecting, self.allAppsAlert == nil, self.infoController == nil,
                  connectedAppSessions(self.sessions ?? []).count > 1,
                  let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let strings = self.currentPresentationData(for: component).initial.strings
            let progress = ValuePromise<Bool>(false, ignoreRepeated: true)
            let enabled = progress.get() |> map { !$0 }
            let alert = AlertScreen(
                configuration: AlertScreen.Configuration(actionAlignment: .vertical, dismissOnOutsideTap: false),
                content: [
                    AnyComponentWithIdentity(id: "title", component: AnyComponent(AlertTitleComponent(title: strings.Wallet_Apps_DisconnectAllTitle))),
                    AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(content: .plain(strings.Wallet_Apps_DisconnectAllText))))
                ],
                actions: [
                    AlertScreen.Action(
                        title: strings.Wallet_Apps_DisconnectAllAction,
                        type: .destructive,
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            let ids = Set(connectedAppSessions(self.sessions ?? []).map(\.id))
                            self.disconnect(ids: ids, all: true, toast: strings.Wallet_Apps_AllDisconnected) { [weak self] succeeded in
                                if succeeded {
                                    self?.dismissAllAppsAlert()
                                }
                            }
                        },
                        autoDismiss: false,
                        isEnabled: enabled,
                        progress: progress.get()
                    ),
                    AlertScreen.Action(title: strings.Common_Cancel, action: {}, isEnabled: enabled)
                ],
                updatedPresentationData: self.currentPresentationData(for: component)
            )
            self.allAppsAlert = alert
            self.allAppsProgress = progress
            alert.dismissed = { [weak self, weak alert] _ in
                guard let self, self.allAppsAlert === alert else {
                    return
                }
                self.allAppsAlert = nil
                self.allAppsProgress = nil
                self.isDismissingAlert = false
                self.scheduleReconciliation()
            }
            controller.present(alert, in: .window(.root))
        }

        private func dismissAllAppsAlert() {
            guard !self.isDismissingAlert, let alert = self.allAppsAlert else {
                return
            }
            self.isDismissingAlert = true
            alert.dismiss(completion: { [weak self, weak alert] in
                guard let self else {
                    return
                }
                if self.allAppsAlert === alert {
                    self.allAppsAlert = nil
                    self.allAppsProgress = nil
                }
                self.isDismissingAlert = false
                self.scheduleReconciliation()
            })
        }

        private func disconnect(ids: Set<Int64>, all: Bool, toast: String, completion: @escaping (Bool) -> Void) {
            guard !self.isDisconnecting, !ids.isEmpty, let component = self.component else {
                completion(false)
                return
            }
            let operationId = UUID()
            self.operationId = operationId
            self.operationSessionIds = ids
            self.operationToast = toast
            self.operationCompletion = completion
            self.allAppsProgress?.set(true)
            self.environment?.controller()?.view.disablesInteractiveModalDismiss = true
            self.state?.updated(transition: .easeInOut(duration: 0.2))

            let operation: Signal<Void, NoError>
            if all {
                operation = component.walletContext.disconnectAllTonConnectSessions()
            } else if let id = ids.first {
                operation = component.walletContext.disconnectTonConnectSession(id: id)
            } else {
                return
            }
            self.operationDisposable.set((operation
            |> mapToSignal { component.walletContext.tonConnectState |> take(1) }
            |> deliverOnMainQueue).start(next: { [weak self] tonConnectState in
                guard let self, self.operationId == operationId, self.component?.walletContext === component.walletContext else {
                    return
                }
                self.sessions = tonConnectState.sessions
                // NoError only means that the command returned. Check the actual session state.
                if !self.completeAcceptedDisconnect(sessions: tonConnectState.sessions) {
                    self.completeDisconnect(succeeded: false)
                    self.presentDisconnectError(all: all)
                }
            }))
        }

        @discardableResult
        private func completeAcceptedDisconnect(sessions: [WalletContext.TonConnectSession]) -> Bool {
            guard self.operationId != nil else {
                return false
            }
            let accepted = self.operationSessionIds.allSatisfy { id in
                !sessions.contains(where: { $0.id == id })
            }
            if accepted {
                self.completeDisconnect(succeeded: true)
            }
            return accepted
        }

        private func completeDisconnect(succeeded: Bool) {
            let completion = self.operationCompletion
            self.operationCompletion = nil
            self.operationId = nil
            self.operationSessionIds.removeAll()
            self.allAppsProgress?.set(false)
            self.environment?.controller()?.view.disablesInteractiveModalDismiss = false
            if succeeded {
                self.pendingToast = self.operationToast
            }
            self.operationToast = nil
            self.state?.updated(transition: .easeInOut(duration: 0.25))
            completion?(succeeded)
            self.scheduleReconciliation()
        }

        private func presentDisconnectError(all: Bool) {
            guard let component = self.component, let controller = self.environment?.controller() else {
                return
            }
            let strings = self.currentPresentationData(for: component).initial.strings
            controller.present(AlertScreen(
                content: [AnyComponentWithIdentity(id: "text", component: AnyComponent(AlertTextComponent(content: .plain(all ? strings.Wallet_Apps_DisconnectAllError : strings.Wallet_Apps_DisconnectError))))],
                actions: [AlertScreen.Action(title: strings.Common_OK, action: {})],
                updatedPresentationData: self.currentPresentationData(for: component)
            ), in: .window(.root))
        }

        func update(component: WalletAppsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer { self.isUpdating = false }
            let environment = environment[EnvironmentType.self].value
            let previousContext = self.component?.walletContext
            self.component = component
            self.environment = environment
            self.state = state
            if previousContext !== component.walletContext {
                self.operationDisposable.set(nil)
                self.operationId = nil
                self.operationSessionIds.removeAll()
                self.operationToast = nil
                environment.controller()?.view.disablesInteractiveModalDismiss = false
                let completion = self.operationCompletion
                self.operationCompletion = nil
                completion?(false)
                self.infoController?.dismissAnimated()
                self.allAppsProgress?.set(false)
                self.dismissAllAppsAlert()
                self.pendingToast = nil
                self.sessions = nil
                let walletContext = component.walletContext
                walletContext.refreshTonConnectSessions()
                self.sessionsDisposable.set((walletContext.tonConnectState
                |> deliverOnMainQueue).start(next: { [weak self] tonConnectState in
                    guard let self, self.component?.walletContext === walletContext else {
                        return
                    }
                    if self.sessions != tonConnectState.sessions {
                        self.sessions = tonConnectState.sessions
                        if !self.isUpdating {
                            self.state?.updated(transition: .easeInOut(duration: 0.25))
                        }
                        self.scheduleReconciliation()
                    }
                    self.completeAcceptedDisconnect(sessions: tonConnectState.sessions)
                }))
            }

            let theme = environment.theme
            self.backgroundColor = theme.list.blocksBackgroundColor
            let apps = connectedAppSessions(self.sessions ?? [])
            let sideInset = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            var items: [AnyComponentWithIdentity<Empty>] = []
            if apps.count > 1 {
                items.append(AnyComponentWithIdentity(id: "disconnectAll", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.Wallet_Apps_DisconnectAll, font: Font.regular(17.0), textColor: theme.list.itemDestructiveColor)),
                        maximumNumberOfLines: 0
                    )),
                    leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(BundleIconComponent(name: "Item List/Block", tintColor: theme.list.itemDestructiveColor))), false),
                    action: { [weak self] _ in self?.presentDisconnectAllAlert() }
                ))))
            }
            for session in apps {
                guard let manifest = session.manifest else {
                    continue
                }
                items.append(AnyComponentWithIdentity(id: session.id, component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(VStack<Empty>([
                        AnyComponentWithIdentity(id: "name", component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: manifest.name, font: Font.semibold(17.0), textColor: theme.list.itemPrimaryTextColor)),
                            maximumNumberOfLines: 1
                        ))),
                        AnyComponentWithIdentity(id: "domain", component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(string: manifest.domain, font: Font.regular(15.0), textColor: theme.list.itemSecondaryTextColor)),
                            maximumNumberOfLines: 1
                        )))
                    ], alignment: .left, spacing: 2.0)),
                    contentInsets: UIEdgeInsets(top: 10.0, left: 0.0, bottom: 10.0, right: 0.0),
                    leftIcon: .custom(AnyComponentWithIdentity(id: "icon", component: AnyComponent(WalletConnectAppIconComponent(
                        context: component.context,
                        applicationName: manifest.name,
                        icon: manifest.icon,
                        size: 30.0,
                        cornerRadius: 9.0
                    ))), false),
                    accessory: .arrow,
                    action: { [weak self] _ in self?.openApp(session) }
                ))))
            }

            self.section.parentState = state
            let presentationData = component.context.sharedContext.currentPresentationData.with { $0 }
            let headerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let sectionSize = self.section.update(
                transition: transition,
                component: AnyComponent(ListSectionComponent(
                    theme: theme,
                    style: .glass,
                    header: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.Wallet_Apps_ActiveConnections.uppercased(), font: headerFont, textColor: theme.list.freeTextColor)),
                        maximumNumberOfLines: 0
                    )),
                    footer: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(string: environment.strings.Wallet_Apps_AllPermissions, font: Font.regular(13.0), textColor: theme.list.freeTextColor)),
                        maximumNumberOfLines: 0
                    )),
                    items: items,
                    isModal: true
                )),
                environment: {},
                containerSize: CGSize(width: max(1.0, availableSize.width - sideInset * 2.0), height: 10000.0)
            )
            let contentY = environment.navigationHeight + 32.0
            if let sectionView = self.section.view {
                if sectionView.superview == nil {
                    self.scrollView.addSubview(sectionView)
                }
                transition.setFrame(view: sectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentY), size: sectionSize))
            }
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: .zero, size: availableSize))
            let contentSize = CGSize(width: availableSize.width, height: max(availableSize.height + 1.0, contentY + sectionSize.height + 24.0 + environment.safeInsets.bottom))
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            self.scrollView.verticalScrollIndicatorInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: .zero)
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class WalletAppsScreen: ViewControllerComponentContainer {
    fileprivate var hasAppeared = false
    fileprivate var isFinishing = false

    public init(context: AccountContext, walletContext: WalletContext) {
        let updatedPresentationData = presentationDataWithDefaultAccent((
            initial: context.sharedContext.currentPresentationData.with { $0 },
            signal: context.sharedContext.presentationData
        ))
        super.init(
            context: context,
            component: WalletAppsScreenComponent(context: context, updatedPresentationData: updatedPresentationData, walletContext: walletContext),
            navigationBarAppearance: .default,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )
        self.title = updatedPresentationData.initial.strings.Wallet_Apps_Title
        self.attemptNavigation = { [weak self] _ in
            guard let self else {
                return true
            }
            return (self.node.hostView.componentView as? WalletAppsScreenComponent.View)?.isDisconnecting != true
        }
        self.scrollToTop = { [weak self] in
            (self?.node.hostView.componentView as? WalletAppsScreenComponent.View)?.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        guard layout.metrics.widthClass == .regular else {
            return nil
        }
        return CGSize(
            width: min(480.0, layout.size.width - 20.0),
            height: min(layout.size.width, layout.size.height) - 88.0
        )
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.hasAppeared = true
        (self.node.hostView.componentView as? WalletAppsScreenComponent.View)?.scheduleReconciliation()
    }

    fileprivate func finish(toast: String?, presentationData: PresentationData) {
        guard !self.isFinishing else {
            return
        }
        self.isFinishing = true
        if let navigationController = self.navigationController as? NavigationController,
           let index = navigationController.viewControllers.firstIndex(where: { $0 === self }) {
            let previousController = navigationController.viewControllers.prefix(upTo: index).last as? ViewController
            navigationController.setViewControllers(navigationController.viewControllers.filter { $0 !== self }, animated: true, completion: { [weak previousController] in
                if let toast, let previousController {
                    presentDisconnectedOverlay(presentationData: presentationData, controller: previousController, text: toast)
                }
            })
        } else {
            self.dismiss()
        }
    }
}
