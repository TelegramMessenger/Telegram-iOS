import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import PresentationDataUtils
import AccountContext
import LocalAuth
import LocalAuthentication
import PasscodeUI
import PasscodeCore
import WalletContext
import ContextUI
import ComponentFlow
import ViewControllerComponent
import MultilineTextComponent
import ListSectionComponent
import ListActionItemComponent

private struct PasscodeOptionsScreenData: Equatable {
    var accessChallenge: PostboxAccessChallengeData
    var presentationSettings: PresentationPasscodeSettings
}

private struct PasscodeOptionsScreenState: Equatable {
    var data: PasscodeOptionsScreenData?
    var protection: WalletProtectionSettings?
    var protectionLoaded = false
    var protectionUnavailable = true
    var canUseBiometrics = false
    var faceID = false
    var isUpdating = false

    var isReady: Bool {
        return self.data != nil && self.protectionLoaded
    }
}

private func passcodeOptionsAutolockString(strings: PresentationStrings, timeout: Int32?) -> String {
    guard let timeout else {
        return strings.PasscodeSettings_AutoLock_Disabled
    }
    switch timeout {
    case 10:
        return "If away for 10 seconds"
    case 60:
        return strings.PasscodeSettings_AutoLock_IfAwayFor_1minute
    case 5 * 60:
        return strings.PasscodeSettings_AutoLock_IfAwayFor_5minutes
    case 60 * 60:
        return strings.PasscodeSettings_AutoLock_IfAwayFor_1hour
    case 5 * 60 * 60:
        return strings.PasscodeSettings_AutoLock_IfAwayFor_5hours
    default:
        return ""
    }
}

private final class PasscodeOptionsScreenContextSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0))
    }
}

private final class PasscodeOptionsScreenModel {
    let context: AccountContext
    private(set) var presentationData: PresentationData
    private let presentationDataSignal: Signal<PresentationData, NoError>
    let sessionState: PasscodeSettingsSessionState
    private let allowFourDigitPasscode: Bool
    weak var controller: PasscodeOptionsScreen?

    private(set) var state = PasscodeOptionsScreenState()
    private let statePromise = ValuePromise(PasscodeOptionsScreenState(), ignoreRepeated: true)
    private let disposables = DisposableSet()
    private var activeBiometricContext: LAContext?
    private let biometricAuthenticationDisposable = MetaDisposable()
    private var refreshGeneration: UInt64 = 0
    private var hasAppeared = false
    private var reportedInitialError = false
    private var isClosed = false

    var stateSignal: Signal<PasscodeOptionsScreenState, NoError> {
        return self.statePromise.get()
    }

    var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>) {
        return (initial: self.presentationData, signal: self.presentationDataSignal)
    }

    init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>), settingsSession: PasscodeSession?, allowFourDigitPasscode: Bool) {
        self.context = context
        self.presentationData = updatedPresentationData.initial
        self.presentationDataSignal = updatedPresentationData.signal
        self.sessionState = PasscodeSettingsSessionState(session: settingsSession)
        self.allowFourDigitPasscode = allowFourDigitPasscode

        self.disposables.add((updatedPresentationData.signal
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            guard let self, !self.isClosed else {
                return
            }
            self.presentationData = presentationData
        }))

        self.disposables.add((context.sharedContext.accountManager.transaction { transaction -> PasscodeOptionsScreenData in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings)?.get(PresentationPasscodeSettings.self) ?? PresentationPasscodeSettings.defaultSettings
            return PasscodeOptionsScreenData(accessChallenge: transaction.getAccessChallengeData(), presentationSettings: settings)
        } |> deliverOnMainQueue).start(next: { [weak self] data in
            guard let self, !self.isClosed else {
                return
            }
            self.state.data = data
            self.updateState()
        }))

        self.disposables.add((PasscodeCredentialStore.shared.changes
        |> deliverOnMainQueue).start(next: { [weak self] _ in
            self?.refreshProtection(reportError: false)
        }))

        let accountId = context.account.id
        self.disposables.add((combineLatest(
            context.sharedContext.applicationBindings.applicationInForeground,
            context.sharedContext.appLockContext.isPasscodeLocked,
            context.sharedContext.activeAccountContexts |> map { primary, _, _ in primary?.account.id == accountId }
        ) |> deliverOnMainQueue).start(next: { [weak self] foreground, locked, current in
            guard let self, !self.isClosed else {
                return
            }
            self.sessionState.updateEnvironment(foreground: foreground, locked: locked, currentAccount: current)
            if !foreground || locked || !current {
                self.activeBiometricContext?.invalidate()
                self.activeBiometricContext = nil
                self.biometricAuthenticationDisposable.set(nil)
            }
            self.updateState()
        }))

        self.refreshProtection(reportError: false)
    }

    deinit {
        self.disposables.dispose()
        self.sessionState.close()
        self.activeBiometricContext?.invalidate()
        self.biometricAuthenticationDisposable.dispose()
    }

    private var isControllerAvailable: Bool {
        guard !self.isClosed, let controller = self.controller, let navigation = controller.navigationController as? NavigationController else {
            return false
        }
        return navigation.viewControllers.contains(where: { $0 === controller })
    }

    private var isControllerOnTop: Bool {
        guard !self.isClosed, let controller = self.controller, let navigation = controller.navigationController as? NavigationController else {
            return false
        }
        return navigation.topViewController === controller
    }

    private func updateState() {
        self.state.isUpdating = self.sessionState.isUpdating
        self.statePromise.set(self.state)
    }

    func didAppear() {
        guard !self.isClosed else {
            return
        }
        if self.hasAppeared {
            self.refreshProtection(reportError: true)
        } else {
            self.hasAppeared = true
            self.reportInitialErrorIfNeeded()
        }
    }

    func close() {
        guard !self.isClosed else {
            return
        }
        self.isClosed = true
        self.refreshGeneration &+= 1
        self.sessionState.close()
        self.activeBiometricContext?.invalidate()
        self.activeBiometricContext = nil
        self.biometricAuthenticationDisposable.dispose()
        self.disposables.dispose()
    }

    private func presentProtectionError() {
        guard self.isControllerAvailable else {
            return
        }
        let strings = self.presentationData.strings
        self.controller?.present(textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: nil, text: strings.PasscodeSettings_WalletProtectionError, actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})]), in: .window(.root), with: ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }

    private func reportInitialErrorIfNeeded() {
        guard self.hasAppeared, self.state.protectionLoaded, !self.reportedInitialError else {
            return
        }
        self.reportedInitialError = true
        if self.state.protectionUnavailable {
            self.presentProtectionError()
        }
    }

    private func refreshProtection(reportError: Bool) {
        guard !self.isClosed else {
            return
        }
        self.refreshGeneration &+= 1
        let generation = self.refreshGeneration
        let biometricContext = LAContext()
        let canUseBiometrics = biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let faceID = biometricContext.biometryType == .faceID
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try walletProtectionSettings() }
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.isClosed, self.refreshGeneration == generation else {
                    return
                }
                self.state.protectionLoaded = true
                self.state.canUseBiometrics = canUseBiometrics
                self.state.faceID = faceID
                switch result {
                case let .success(settings):
                    self.state.protection = settings
                    self.state.protectionUnavailable = false
                case .failure:
                    self.state.protectionUnavailable = true
                    if reportError {
                        self.presentProtectionError()
                    }
                }
                self.updateState()
                self.reportInitialErrorIfNeeded()
            }
        }
    }

    private func finishOperation(_ operation: UInt64, error: Error? = nil, refreshProtection: Bool = false) {
        guard self.sessionState.accepts(operation: operation) else {
            return
        }
        self.activeBiometricContext = nil
        self.sessionState.finish(operation: operation)
        self.updateState()
        if refreshProtection {
            self.refreshProtection(reportError: false)
        }
        if let error, (error as? PasscodeError) != .cancelled {
            self.presentProtectionError()
        }
    }

    private func withSettingsSession(
        operation: UInt64,
        proceed: @escaping (PasscodeSession, ViewController?) -> Void,
        failed: @escaping (Error?) -> Void
    ) {
        guard self.sessionState.accepts(operation: operation), self.isControllerOnTop else {
            failed(nil)
            return
        }
        let generation = self.sessionState.generation
        let authenticate: () -> Void = { [weak self] in
            guard let self, self.sessionState.accepts(operation: operation), self.isControllerOnTop else {
                failed(nil)
                return
            }
            weak var authenticationController: ViewController?
            if let controller = settingsPasscodeSessionController(context: self.context, preferredModalWidth: 480.0, completion: { [weak self] result in
                switch result {
                case let .success(session):
                    guard let self, self.sessionState.accepts(operation: operation), self.isControllerAvailable,
                          let authenticationController,
                          let navigation = authenticationController.navigationController as? NavigationController,
                          navigation.topViewController === authenticationController,
                          self.sessionState.replaceSession(session, generation: generation) else {
                        session.invalidate()
                        failed(nil)
                        return
                    }
                    proceed(session, authenticationController)
                case .failure:
                    failed(nil)
                }
            }) {
                authenticationController = controller
                guard self.sessionState.accepts(operation: operation), self.isControllerOnTop else {
                    failed(nil)
                    return
                }
                self.controller?.push(controller)
            }
        }
        if let session = self.sessionState.session {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = Result { try PasscodeCredentialStore.shared.validate(session, scope: .settings) }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.sessionState.accepts(operation: operation), self.isControllerOnTop else {
                        failed(nil)
                        return
                    }
                    switch result {
                    case .success:
                        proceed(session, nil)
                    case let .failure(error):
                        if let error = error as? PasscodeError, error == .staleAuthorization || error == .authenticationRequired {
                            authenticate()
                        } else {
                            failed(error)
                        }
                    }
                }
            }
        } else {
            authenticate()
        }
    }

    func togglePasscode() {
        guard self.isControllerOnTop, let operation = self.sessionState.beginOperation() else {
            return
        }
        self.updateState()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try walletProtectionSettings() }
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                guard self.sessionState.accepts(operation: operation), self.isControllerOnTop else {
                    self.finishOperation(operation)
                    return
                }
                switch result {
                case let .success(current):
                    if current.passcode == nil {
                        self.openPasscodeSetup(session: nil, operation: operation, authenticationController: nil)
                    } else {
                        self.finishOperation(operation)
                        self.confirmDisablePasscode(protectionEnabled: current.enabled)
                    }
                case let .failure(error):
                    self.finishOperation(operation, error: error)
                }
            }
        }
    }

    private func confirmDisablePasscode(protectionEnabled: Bool) {
        let generation = self.sessionState.generation
        let presentationData = self.presentationData
        let alert = textAlertController(context: self.context, updatedPresentationData: self.updatedPresentationData, title: presentationData.strings.PasscodeSettings_TurnPasscodeOff, text: protectionEnabled ? presentationData.strings.PasscodeSettings_TurnOffWalletProtectionWarning : presentationData.strings.PasscodeSettings_TurnPasscodeOff, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: presentationData.strings.PasscodeSettings_TurnPasscodeOff, action: { [weak self] in
                guard let self, self.isControllerOnTop, self.sessionState.accepts(generation: generation), let operation = self.sessionState.beginOperation() else {
                    return
                }
                self.updateState()
                self.disablePasscode(operation: operation)
            })
        ])
        self.controller?.present(alert, in: .window(.root))
    }

    private func disablePasscode(operation: UInt64) {
        self.withSettingsSession(operation: operation, proceed: { [weak self] session, authenticationController in
            guard let self else {
                return
            }
            if let authenticationController, let navigation = authenticationController.navigationController as? NavigationController {
                let _ = navigation.popViewController(animated: true)
            }
            let accountManager = self.context.sharedContext.accountManager
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = Result { try PasscodeCredentialStore.shared.disablePasscode(session: session) }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.sessionState.accepts(operation: operation), self.isControllerAvailable else {
                        return
                    }
                    self.disposables.add((accountManager.transaction { transaction -> PostboxAccessChallengeData in
                        return transaction.getAccessChallengeData()
                    } |> deliverOnMainQueue).start(next: { [weak self] challenge in
                        guard let self, self.sessionState.accepts(operation: operation), self.isControllerAvailable else {
                            return
                        }
                        self.sessionState.finish(operation: operation)
                        if case .none = challenge {
                            self.sessionState.invalidate()
                        }
                        self.state.data?.accessChallenge = challenge
                        self.updateState()
                        self.refreshProtection(reportError: false)
                        if case let .failure(error) = result, (error as? PasscodeError) != .cancelled {
                            self.presentProtectionError()
                        }
                    }))
                }
            }
        }, failed: { [weak self] error in
            self?.finishOperation(operation, error: error, refreshProtection: true)
        })
    }

    func changePasscode() {
        guard self.isControllerOnTop, let operation = self.sessionState.beginOperation() else {
            return
        }
        self.updateState()
        self.withSettingsSession(operation: operation, proceed: { [weak self] session, authenticationController in
            self?.openPasscodeSetup(session: session, operation: operation, authenticationController: authenticationController)
        }, failed: { [weak self] error in
            self?.finishOperation(operation, error: error)
        })
    }

    private func openPasscodeSetup(session: PasscodeSession?, operation: UInt64, authenticationController: ViewController?) {
        guard self.sessionState.accepts(operation: operation) else {
            return
        }
        let generation = self.sessionState.generation
        weak var setupController: ViewController?
        let controller = applicationPasscodeSetupController(context: self.context, session: session, change: session != nil, ownsAuthorizationSession: false, preferredModalWidth: 480.0, allowFourDigitPasscode: self.allowFourDigitPasscode, settingsSessionCompleted: { [weak self] session in
            guard let self, self.sessionState.accepts(operation: operation) else {
                session.invalidate()
                return
            }
            self.sessionState.replaceSession(session, generation: generation)
        }, cancelled: { [weak self] in
            self?.finishOperation(operation)
        }, completion: { [weak self] reference in
            guard let self else {
                return
            }
            guard self.sessionState.accepts(operation: operation), self.isControllerAvailable,
                  let setupController,
                  let navigation = setupController.navigationController as? NavigationController,
                  navigation.topViewController === setupController else {
                self.finishOperation(operation)
                return
            }
            self.state.data?.accessChallenge = accessChallengeData(reference: reference)
            self.finishOperation(operation, refreshProtection: true)
            let _ = navigation.popViewController(animated: true)
        })
        setupController = controller
        guard self.sessionState.accepts(operation: operation) else {
            return
        }
        if let authenticationController, let navigation = authenticationController.navigationController as? NavigationController {
            navigation.replaceTopController(controller, animated: true)
        } else {
            self.controller?.push(controller)
        }
    }

    func changeWalletProtection(biometrics: Bool, enabled: Bool) {
        guard self.isControllerOnTop, !self.state.protectionUnavailable, let operation = self.sessionState.beginOperation() else {
            return
        }
        self.updateState()
        self.withSettingsSession(operation: operation, proceed: { [weak self] session, authenticationController in
            guard let self, self.sessionState.accepts(operation: operation) else {
                return
            }
            if let authenticationController, let navigation = authenticationController.navigationController as? NavigationController {
                let _ = navigation.popViewController(animated: true)
            }
            let authenticationContext = LAContext()
            authenticationContext.localizedReason = self.presentationData.strings.PasscodeSettings_WalletEnableBiometricsReason
            authenticationContext.localizedFallbackTitle = ""
            authenticationContext.touchIDAuthenticationAllowableReuseDuration = 0
            self.activeBiometricContext = authenticationContext
            let biometricAuthentication: Disposable? = biometrics && enabled ? self.context.sharedContext.appLockContext.beginBiometricAuthentication() : nil
            self.biometricAuthenticationDisposable.set(biometricAuthentication)
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let result = Result {
                    if biometrics {
                        try setWalletBiometricsEnabled(enabled, session: session, context: authenticationContext)
                    } else {
                        try setWalletProtectionEnabled(enabled, session: session)
                    }
                }
                authenticationContext.invalidate()
                DispatchQueue.main.async { [weak self] in
                    biometricAuthentication?.dispose()
                    switch result {
                    case .success:
                        self?.finishOperation(operation, refreshProtection: true)
                    case let .failure(error):
                        self?.finishOperation(operation, error: error, refreshProtection: true)
                    }
                }
            }
        }, failed: { [weak self] error in
            self?.finishOperation(operation, error: error, refreshProtection: true)
        })
    }

    func changeAutolockTimeout(_ value: Int32?) {
        guard !self.isClosed, var data = self.state.data else {
            return
        }
        data.presentationSettings = data.presentationSettings.withUpdatedAutolockTimeout(value)
        self.state.data = data
        self.updateState()
        let _ = updatePresentationPasscodeSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { current in
            return current.withUpdatedAutolockTimeout(value)
        }).start()
    }

    func changeTelegramBiometrics(_ value: Bool) {
        guard !self.isClosed, var data = self.state.data else {
            return
        }
        data.presentationSettings = data.presentationSettings.withUpdatedEnableBiometrics(value)
        self.state.data = data
        self.updateState()
        let _ = updatePresentationPasscodeSettingsInteractively(accountManager: self.context.sharedContext.accountManager, { current in
            return current.withUpdatedEnableBiometrics(value)
        }).start()
    }
}

private final class PasscodeOptionsScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let model: PasscodeOptionsScreenModel
    let focusOnItemTag: PasscodeOptionsEntryTag?

    init(model: PasscodeOptionsScreenModel, focusOnItemTag: PasscodeOptionsEntryTag?) {
        self.model = model
        self.focusOnItemTag = focusOnItemTag
    }

    static func ==(lhs: PasscodeOptionsScreenComponent, rhs: PasscodeOptionsScreenComponent) -> Bool {
        return lhs.model === rhs.model && lhs.focusOnItemTag == rhs.focusOnItemTag
    }

    final class View: UIView {
        private let scrollView: UIScrollView
        private let passcodeSection = ComponentView<Empty>()
        private let telegramSection = ComponentView<Empty>()
        private let walletSection = ComponentView<Empty>()
        private let stateDisposable = MetaDisposable()

        private var component: PasscodeOptionsScreenComponent?
        private var environment: EnvironmentType?
        private weak var state: EmptyComponentState?
        private var isUpdating = false
        private var didFocusOnItem = false
        private weak var autolockContextController: ContextController?

        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollView.showsVerticalScrollIndicator = true
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.scrollsToTop = true
            self.scrollView.delaysContentTouches = false
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            if #available(iOS 13.0, *) {
                self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            }
            self.scrollView.alwaysBounceVertical = true

            super.init(frame: frame)

            self.addSubview(self.scrollView)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.stateDisposable.dispose()
        }

        func scrollToTop() {
            self.scrollView.setContentOffset(CGPoint(), animated: true)
        }

        private func openAutolockMenu(sourceView: UIView) {
            guard let component = self.component, let controller = self.environment?.controller(), self.autolockContextController == nil else {
                return
            }
            let presentationData = component.model.presentationData
            let currentTimeout = component.model.state.data?.presentationSettings.autolockTimeout
            var values: [Int32] = [0, 60, 5 * 60, 60 * 60, 5 * 60 * 60]
            #if DEBUG
            values.append(10)
            values.sort()
            #endif

            var items: [ContextMenuItem] = []
            for value in values {
                let timeout: Int32? = value == 0 ? nil : value
                items.append(.action(ContextMenuActionItem(text: passcodeOptionsAutolockString(strings: presentationData.strings, timeout: timeout), icon: { theme in
                    if currentTimeout == timeout {
                        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                    } else {
                        return UIImage()
                    }
                }, action: { [weak self] _, completion in
                    completion(.default)
                    self?.component?.model.changeAutolockTimeout(timeout)
                })))
            }
            let contextController = makeContextController(
                presentationData: presentationData,
                source: .reference(PasscodeOptionsScreenContextSource(sourceView: sourceView)),
                items: .single(ContextController.Items(content: .list(items))),
                gesture: nil
            )
            self.autolockContextController = contextController
            sourceView.alpha = 0.5
            contextController.dismissed = { [weak self, weak sourceView] in
                self?.autolockContextController = nil
                if let sourceView {
                    ComponentTransition.easeInOut(duration: 0.2).setAlpha(view: sourceView, alpha: 1.0)
                }
            }
            controller.presentInGlobalOverlay(contextController, with: nil)
        }

        private func focusOnItemIfNeeded(availableSize: CGSize) {
            guard !self.didFocusOnItem, let component = self.component, component.model.state.isReady, let tag = component.focusOnItemTag, let environment = self.environment, environment.isVisible else {
                return
            }
            let section: ComponentView<Empty>
            let itemId: String
            switch tag {
            case .togglePasscode:
                section = self.passcodeSection
                itemId = "togglePasscode"
            case .changePasscode:
                section = self.passcodeSection
                itemId = "changePasscode"
            case .autolock:
                section = self.telegramSection
                itemId = "autolock"
            case .touchId:
                section = self.telegramSection
                itemId = "touchId"
            }
            guard let sectionView = section.view as? ListSectionComponent.View, sectionView.superview != nil,
                  let itemView = sectionView.itemView(id: itemId) as? ListActionItemComponent.View else {
                return
            }
            self.didFocusOnItem = true
            let itemFrame = itemView.convert(itemView.bounds, to: self.scrollView)
            let visibleTop = self.scrollView.contentOffset.y + environment.navigationHeight
            let visibleBottom = self.scrollView.contentOffset.y + availableSize.height - environment.safeInsets.bottom
            var offset = self.scrollView.contentOffset.y
            if itemFrame.minY < visibleTop {
                offset = itemFrame.minY - environment.navigationHeight - 16.0
            } else if itemFrame.maxY > visibleBottom {
                offset = itemFrame.maxY - availableSize.height + environment.safeInsets.bottom + 16.0
            }
            offset = max(0.0, min(offset, self.scrollView.contentSize.height - availableSize.height))
            self.scrollView.setContentOffset(CGPoint(x: 0.0, y: offset), animated: false)
            itemView.customUpdateIsHighlighted?(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak itemView] in
                itemView?.customUpdateIsHighlighted?(false)
            }
        }

        func update(component: PasscodeOptionsScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
            self.isUpdating = true
            defer {
                self.isUpdating = false
            }
            let environment = environment[EnvironmentType.self].value
            let previousModel = self.component?.model
            self.component = component
            self.environment = environment
            self.state = state

            if previousModel !== component.model {
                self.didFocusOnItem = false
                self.stateDisposable.set((component.model.stateSignal
                |> deliverOnMainQueue).start(next: { [weak self] _ in
                    guard let self, !self.isUpdating else {
                        return
                    }
                    self.state?.updated(transition: .easeInOut(duration: 0.25))
                }))
            }

            let theme = environment.theme
            let strings = environment.strings
            self.backgroundColor = theme.list.blocksBackgroundColor
            if let controller = environment.controller() {
                if controller.title != strings.PasscodeSettings_Title {
                    controller.title = strings.PasscodeSettings_Title
                }
                if controller.navigationItem.backBarButtonItem?.title != strings.Common_Back {
                    controller.navigationItem.backBarButtonItem = UIBarButtonItem(title: strings.Common_Back, style: .plain, target: nil, action: nil)
                }
            }
            let presentationData = component.model.presentationData
            let actionFont = Font.regular(presentationData.listsFontSize.baseDisplaySize)
            let footerFont = Font.regular(presentationData.listsFontSize.itemListBaseHeaderFontSize)
            let sideInset = 16.0 + max(environment.safeInsets.left, environment.safeInsets.right)
            let sectionWidth = availableSize.width - sideInset * 2.0
            var contentHeight = environment.navigationHeight + 16.0

            func updateSection(_ section: ComponentView<Empty>, header: String?, footer: String?, items: [AnyComponentWithIdentity<Empty>]) {
                section.parentState = state
                var transition = transition
                if section.view == nil {
                    transition = .immediate
                }
                let sectionSize = section.update(
                    transition: transition,
                    component: AnyComponent(ListSectionComponent(
                        theme: theme,
                        style: .glass,
                        header: header.map { value in
                            AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: value,
                                    font: footerFont,
                                    textColor: theme.list.freeTextColor
                                )),
                                maximumNumberOfLines: 0
                            ))
                        },
                        footer: footer.map { value in
                            AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: value,
                                    font: footerFont,
                                    textColor: theme.list.freeTextColor
                                )),
                                maximumNumberOfLines: 0
                            ))
                        },
                        items: items
                    )),
                    environment: {},
                    containerSize: CGSize(width: sectionWidth, height: 10000.0)
                )
                if let sectionView = section.view {
                    if sectionView.superview == nil {
                        self.scrollView.addSubview(sectionView)
                    }
                    transition.setFrame(view: sectionView, frame: CGRect(origin: CGPoint(x: sideInset, y: contentHeight), size: sectionSize))
                }
                contentHeight += sectionSize.height + 24.0
            }

            let screenState = component.model.state
            if screenState.isReady, let data = screenState.data {
                let challenge = screenState.protection.map { $0.passcode.map { accessChallengeData(reference: $0) } ?? PostboxAccessChallengeData.none } ?? data.accessChallenge
                let hasPasscode: Bool
                switch challenge {
                case .none:
                    hasPasscode = false
                case .numericalPassword, .plaintextPassword, .secured:
                    hasPasscode = true
                }
                var passcodeItems: [AnyComponentWithIdentity<Empty>] = []
                passcodeItems.append(AnyComponentWithIdentity(id: "togglePasscode", component: AnyComponent(ListActionItemComponent(
                    theme: theme,
                    style: .glass,
                    title: AnyComponent(MultilineTextComponent(
                        text: .plain(NSAttributedString(
                            string: hasPasscode ? strings.PasscodeSettings_TurnPasscodeOff : strings.PasscodeSettings_TurnPasscodeOn,
                            font: actionFont,
                            textColor: theme.list.itemAccentColor
                        )),
                        maximumNumberOfLines: 0
                    )),
                    accessory: nil,
                    action: screenState.isUpdating ? nil : { [weak self] _ in
                        self?.component?.model.togglePasscode()
                    }
                ))))
                if hasPasscode {
                    passcodeItems.append(AnyComponentWithIdentity(id: "changePasscode", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.PasscodeSettings_ChangePasscode,
                                font: actionFont,
                                textColor: theme.list.itemAccentColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        accessory: nil,
                        action: screenState.isUpdating ? nil : { [weak self] _ in
                            self?.component?.model.changePasscode()
                        }
                    ))))
                }
                updateSection(self.passcodeSection, header: nil, footer: strings.PasscodeSettings_Help, items: passcodeItems)

                if hasPasscode {
                    var telegramItems: [AnyComponentWithIdentity<Empty>] = []
                    telegramItems.append(AnyComponentWithIdentity(id: "autolock", component: AnyComponent(ListActionItemComponent(
                        theme: theme,
                        style: .glass,
                        title: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: strings.PasscodeSettings_AutoLock,
                                font: actionFont,
                                textColor: theme.list.itemPrimaryTextColor
                            )),
                            maximumNumberOfLines: 0
                        )),
                        icon: ListActionItemComponent.Icon(component: AnyComponentWithIdentity(id: "timeout", component: AnyComponent(MultilineTextComponent(
                            text: .plain(NSAttributedString(
                                string: passcodeOptionsAutolockString(strings: strings, timeout: data.presentationSettings.autolockTimeout),
                                font: actionFont,
                                textColor: theme.list.itemSecondaryTextColor
                            )),
                            maximumNumberOfLines: 1
                        )))),
                        accessory: .arrow,
                        action: { [weak self] view in
                            guard let sourceView = (view as? ListActionItemComponent.View)?.iconView else {
                                return
                            }
                            self?.openAutolockMenu(sourceView: sourceView)
                        }
                    ))))
                    if let biometricAuthentication = LocalAuth.biometricAuthentication {
                        let title: String
                        switch biometricAuthentication {
                        case .touchId:
                            title = strings.PasscodeSettings_UnlockWithTouchId
                        case .faceId:
                            title = strings.PasscodeSettings_UnlockWithFaceId
                        }
                        telegramItems.append(AnyComponentWithIdentity(id: "touchId", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: title,
                                    font: actionFont,
                                    textColor: theme.list.itemPrimaryTextColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: data.presentationSettings.enableBiometrics, action: { [weak self] value in
                                self?.component?.model.changeTelegramBiometrics(value)
                            })),
                            action: nil
                        ))))
                    }
                    updateSection(self.telegramSection, header: strings.PasscodeSettings_LockTelegram.uppercased(), footer: nil, items: telegramItems)

                    if WalletConfiguration.with(appConfiguration: component.model.context.currentAppConfiguration.with { $0 }).isAvailable {
                        let protectionEnabled = screenState.protection?.enabled == true
                        let controlsEnabled = !screenState.protectionUnavailable && !screenState.isUpdating
                        let walletTextColor = controlsEnabled ? theme.list.itemPrimaryTextColor : theme.list.itemDisabledTextColor
                        var walletItems: [AnyComponentWithIdentity<Empty>] = []
                        walletItems.append(AnyComponentWithIdentity(id: "walletPasscode", component: AnyComponent(ListActionItemComponent(
                            theme: theme,
                            style: .glass,
                            title: AnyComponent(MultilineTextComponent(
                                text: .plain(NSAttributedString(
                                    string: strings.PasscodeSettings_WalletConfirmWithPasscode,
                                    font: actionFont,
                                    textColor: walletTextColor
                                )),
                                maximumNumberOfLines: 0
                            )),
                            accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: protectionEnabled, isInteractive: false, isEnabled: controlsEnabled)),
                            action: controlsEnabled ? { [weak self] _ in
                                guard let model = self?.component?.model else {
                                    return
                                }
                                model.changeWalletProtection(biometrics: false, enabled: model.state.protection?.enabled != true)
                            } : nil
                        ))))
                        if protectionEnabled && (screenState.canUseBiometrics || screenState.protection?.biometricsEnabled == true) {
                            walletItems.append(AnyComponentWithIdentity(id: "walletBiometrics", component: AnyComponent(ListActionItemComponent(
                                theme: theme,
                                style: .glass,
                                title: AnyComponent(MultilineTextComponent(
                                    text: .plain(NSAttributedString(
                                        string: screenState.faceID ? strings.PasscodeSettings_WalletConfirmWithFaceId : strings.PasscodeSettings_WalletConfirmWithTouchId,
                                        font: actionFont,
                                        textColor: walletTextColor
                                    )),
                                    maximumNumberOfLines: 0
                                )),
                                accessory: .toggle(ListActionItemComponent.Toggle(style: .regular, isOn: screenState.protection?.biometricsEnabled == true, isInteractive: false, isEnabled: controlsEnabled)),
                                action: controlsEnabled ? { [weak self] _ in
                                    guard let model = self?.component?.model else {
                                        return
                                    }
                                    model.changeWalletProtection(biometrics: true, enabled: model.state.protection?.biometricsEnabled != true)
                                } : nil
                            ))))
                        }
                        updateSection(self.walletSection, header: strings.PasscodeSettings_LockWallet.uppercased(), footer: strings.PasscodeSettings_WalletProtectionInfo, items: walletItems)
                    } else {
                        self.walletSection.view?.removeFromSuperview()
                    }
                } else {
                    self.telegramSection.view?.removeFromSuperview()
                    self.walletSection.view?.removeFromSuperview()
                }
            }
            contentHeight += environment.safeInsets.bottom
            transition.setFrame(view: self.scrollView, frame: CGRect(origin: CGPoint(), size: availableSize))
            let contentSize = CGSize(width: availableSize.width, height: max(contentHeight, availableSize.height + 1.0))
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            let scrollInsets = UIEdgeInsets(top: environment.navigationHeight, left: 0.0, bottom: environment.safeInsets.bottom, right: 0.0)
            if self.scrollView.verticalScrollIndicatorInsets != scrollInsets {
                self.scrollView.verticalScrollIndicatorInsets = scrollInsets
            }
            self.focusOnItemIfNeeded(availableSize: availableSize)
            return availableSize
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<EnvironmentType>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

public final class PasscodeOptionsScreen: ViewControllerComponentContainer {
    private let model: PasscodeOptionsScreenModel

    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, focusOnItemTag: PasscodeOptionsEntryTag? = nil, settingsSession: PasscodeSession? = nil, allowFourDigitPasscode: Bool = true) {
        let updatedPresentationData = updatedPresentationData ?? (
            initial: context.sharedContext.currentPresentationData.with { $0 },
            signal: context.sharedContext.presentationData
        )
        let model = PasscodeOptionsScreenModel(context: context, updatedPresentationData: updatedPresentationData, settingsSession: settingsSession, allowFourDigitPasscode: allowFourDigitPasscode)
        self.model = model

        super.init(
            context: context,
            component: PasscodeOptionsScreenComponent(model: model, focusOnItemTag: focusOnItemTag),
            navigationBarAppearance: .default,
            theme: .default,
            updatedPresentationData: updatedPresentationData
        )

        model.controller = self
        let strings = model.presentationData.strings
        self.title = strings.PasscodeSettings_Title
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: strings.Common_Back, style: .plain, target: nil, action: nil)
        self.ready.set(model.stateSignal |> map { $0.isReady } |> filter { $0 } |> take(1))
        self.scrollToTop = { [weak self] in
            (self?.node.hostView.componentView as? PasscodeOptionsScreenComponent.View)?.scrollToTop()
        }
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.model.close()
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

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.model.didAppear()
    }

    override public func viewWillLeaveNavigation() {
        super.viewWillLeaveNavigation()
        if let navigation = self.navigationController as? NavigationController,
           !navigation.viewControllers.contains(where: { $0 === self }) {
            self.model.close()
        }
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.isBeingDismissed || self.navigationController?.isBeingDismissed == true || self.navigationController?.viewControllers.contains(where: { $0 === self }) != true {
            self.model.close()
        }
    }
}
