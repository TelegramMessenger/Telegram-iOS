import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import PasscodeCore
import PresentationDataUtils
import TelegramUIPreferences
import LocalAuth
import ContextUI

private final class PasscodeModeContextSource: ContextReferenceContentSource {
    private let sourceNode: HighlightableButtonNode
    let forceDisplayBelowKeyboard = true

    init(sourceNode: HighlightableButtonNode) {
        self.sourceNode = sourceNode
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        let titleFrame = self.sourceNode.titleNode.frame.insetBy(dx: -4.0, dy: -4.0)
        let bounds = self.sourceNode.bounds
        return ContextControllerReferenceViewInfo(
            referenceView: self.sourceNode.view,
            contentAreaInScreenSpace: UIScreen.main.bounds,
            insets: UIEdgeInsets(top: titleFrame.minY - bounds.minY, left: titleFrame.minX - bounds.minX, bottom: bounds.maxY - titleFrame.maxY, right: bounds.maxX - titleFrame.maxX),
            actionsPosition: .top
        )
    }
}

public enum PasscodeSetupControllerMode {
    case setup(change: Bool, PasscodeEntryFieldType)
    case entry(PostboxAccessChallengeData)
}

public final class PasscodeSetupController: ViewController {
    private var controllerNode: PasscodeSetupControllerNode {
        return self.displayNode as! PasscodeSetupControllerNode
    }
    
    private let context: AccountContext
    private var mode: PasscodeSetupControllerMode
    private let preferredModalWidth: CGFloat?
    private let useCustomNumericKeyboard: Bool
    private let allowFourDigitPasscode: Bool
    private weak var passcodeModeContextController: ContextController?
    
    public var complete: ((String, Bool) -> Void)?
    var authenticationCompleted: ((Result<PasscodeSession, PasscodeError>) -> Void)?

    private let authentication: SettingsPasscodeAuthentication?
    private let authenticationDisposables = DisposableSet()
    private var cooldownTimer: SwiftSignalKit.Timer?
    private var isLeavingNavigation = false
    private var authenticationFailed = false
    var setupCancelled: (() -> Void)?
    var setupDisposable: Disposable?
    
    private let hapticFeedback = HapticFeedback()
    
    private var presentationData: PresentationData
    
    private var nextAction: UIBarButtonItem?
    
    public init(context: AccountContext, mode: PasscodeSetupControllerMode, authenticationScope: PasscodeSession.Scope = .settings, preferredModalWidth: CGFloat? = nil, useCustomNumericKeyboard: Bool = true, allowFourDigitPasscode: Bool = true) {
        self.context = context
        self.mode = mode
        self.preferredModalWidth = preferredModalWidth
        self.useCustomNumericKeyboard = useCustomNumericKeyboard
        self.allowFourDigitPasscode = allowFourDigitPasscode
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        if case let .entry(challenge) = mode {
            let reference = passcodeCredentialReference(from: challenge)
            self.authentication = SettingsPasscodeAuthentication(
                isMainApp: context.sharedContext.applicationBindings.isMainApp,
                verify: { try PasscodeCredentialStore.shared.verify($0, reference: reference, scope: authenticationScope) },
                cooldownRemaining: { try PasscodeCredentialStore.shared.cooldownRemaining() }
            )
        } else {
            self.authentication = nil
        }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData, style: .glass))
        
        self.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .all, compactSize: .portrait)
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.nextAction = UIBarButtonItem(title: self.presentationData.strings.Common_Next, style: .done, target: self, action: #selector(self.nextPressed))
        
        self.title = self.presentationData.strings.PasscodeSettings_Title
    }

    deinit {
        self.setupCancelled?()
        self.setupDisposable?.dispose()
        self.authenticationDisposables.dispose()
        self.cooldownTimer?.invalidate()
        if let authentication, authentication.state != .finished {
            authentication.cancel()
            self.authenticationCompleted?(.failure(.cancelled))
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func preferredContentSizeForLayout(_ layout: ContainerViewLayout) -> CGSize? {
        guard layout.metrics.widthClass == .regular, let preferredModalWidth = self.preferredModalWidth else {
            return nil
        }
        return CGSize(
            width: min(preferredModalWidth, layout.size.width - 20.0),
            height: min(layout.size.width, layout.size.height) - 88.0
        )
    }

    override public func loadDisplayNode() {
        self.displayNode = PasscodeSetupControllerNode(presentationData: self.presentationData, mode: self.mode, useCustomNumericKeyboard: self.useCustomNumericKeyboard)
        self.displayNodeDidLoad()
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        
        self.controllerNode.selectPasscodeMode = { [weak self] sourceNode in
            self?.openPasscodeModeMenu(sourceNode: sourceNode)
        }
        self.controllerNode.updateNextAction = { [weak self] visible in
            guard let strongSelf = self else {
                return
            }
            
            if visible {
                strongSelf.navigationItem.setRightBarButton(strongSelf.nextAction, animated: true)
            } else {
                strongSelf.navigationItem.setRightBarButton(nil, animated: true)
            }
        }
        self.controllerNode.complete = { [weak self] passcode, numerical in
            if let strongSelf = self {
                strongSelf.complete?(passcode, numerical)
            }
        }
        self.controllerNode.checkPasscode = { [weak self] passcode in
            self?.authentication?.submit(passcode)
        }
        if let authentication {
            if case let .entry(challenge) = self.mode, challenge.passcodeKind == .alphanumeric {
                self.navigationItem.rightBarButtonItem = self.nextAction
            }
            authentication.updated = { [weak self] state in
                self?.updateAuthenticationState(state)
            }
            authentication.incorrectCode = { [weak self] in self?.controllerNode.animateError() }
            authentication.completed = { [weak self] result in
                guard let self else {
                    if case let .success(session) = result { session.invalidate() }
                    return
                }
                self.authenticationDisposables.dispose()
                self.cooldownTimer?.invalidate()
                self.cooldownTimer = nil
                if case let .failure(error) = result {
                    self.authenticationFailed = true
                    if !self.isLeavingNavigation {
                        self.view.isHidden = true
                        self.removeAuthenticationController()
                        // Invalidation may arrive before this controller is pushed.
                        DispatchQueue.main.async { [weak self] in self?.removeAuthenticationController() }
                    }
                    if error != .cancelled {
                        let strings = self.presentationData.strings
                        self.context.sharedContext.presentGlobalController(textAlertController(context: self.context, title: nil, text: strings.PasscodeSettings_UpdateError, actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})]), nil)
                    }
                }
                self.authenticationCompleted?(result)
            }
            self.authenticationDisposables.add((self.context.sharedContext.applicationBindings.applicationInForeground
            |> deliverOnMainQueue).start(next: { [weak authentication] value in
                authentication?.updateApplicationInForeground(value)
            }))
            self.authenticationDisposables.add((self.context.sharedContext.appLockContext.isPasscodeLocked
            |> deliverOnMainQueue).start(next: { [weak authentication] value in
                authentication?.updatePasscodeLocked(value)
            }))
            authentication.refreshCooldown()
        }
    }

    private func openPasscodeModeMenu(sourceNode: HighlightableButtonNode) {
        guard !self.isLeavingNavigation, self.passcodeModeContextController == nil,
              case let .setup(change, selectedType) = self.mode else { return }

        let strings = self.presentationData.strings
        var types: [(PasscodeEntryFieldType, String)] = [(.digits6, strings.PasscodeSettings_6DigitCode)]
        if self.allowFourDigitPasscode {
            types.append((.digits4, strings.PasscodeSettings_4DigitCode))
        }
        types.append((.alphanumeric, strings.PasscodeSettings_AlphanumericCode))

        let items: [ContextMenuItem] = types.map { type, title in
            return .action(ContextMenuActionItem(text: title, icon: { theme in
                if type == selectedType {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                } else {
                    return UIImage()
                }
            }, action: { [weak self] _, completion in
                if let self, !self.isLeavingNavigation, type != selectedType {
                    self.mode = .setup(change: change, type)
                    self.controllerNode.updateMode(self.mode)
                }
                completion(.default)
            }))
        }
        let controller = makeContextController(
            presentationData: self.presentationData,
            source: .reference(PasscodeModeContextSource(sourceNode: sourceNode)),
            items: .single(ContextController.Items(content: .list(items))),
            gesture: nil
        )
        self.passcodeModeContextController = controller
        controller.dismissed = { [weak self] in
            guard let self else { return }
            self.passcodeModeContextController = nil
            if !self.isLeavingNavigation && !self.view.isHidden {
                self.controllerNode.activateInput()
            }
        }
        self.presentInGlobalOverlay(controller, with: nil)
    }

    private func updateAuthenticationState(_ state: SettingsPasscodeAuthentication.State) {
        // Navigation owns the outgoing view and keyboard until its transition ends.
        // Authentication still finishes immediately, rejecting any pending result.
        if !self.isLeavingNavigation || state != .finished {
            self.controllerNode.updateAuthenticationState(state)
        }
        self.nextAction?.isEnabled = state == .ready
        switch state {
        case .cooldown:
            if self.cooldownTimer == nil {
                let timer = SwiftSignalKit.Timer(timeout: 1.0, repeat: true, completion: { [weak self] in
                    guard let authentication = self?.authentication, case .cooldown = authentication.state else { return }
                    authentication.refreshCooldown()
                }, queue: Queue.mainQueue())
                self.cooldownTimer = timer
                timer.start()
            }
        case .ready:
            self.cooldownTimer?.invalidate()
            self.cooldownTimer = nil
            self.controllerNode.activateInput()
        case .finished:
            self.cooldownTimer?.invalidate()
            self.cooldownTimer = nil
        case .checking: break
        }
    }

    private func removeAuthenticationController() {
        guard !self.isLeavingNavigation else { return }
        if let navigation = self.navigationController as? NavigationController,
           let index = navigation.viewControllers.firstIndex(where: { $0 === self }), index > 0 {
            self.isLeavingNavigation = true
            navigation.setViewControllers(Array(navigation.viewControllers.prefix(index)), animated: false)
        }
    }

    override public func viewWillLeaveNavigation() {
        super.viewWillLeaveNavigation()
        self.isLeavingNavigation = true
        self.passcodeModeContextController?.dismiss()
        if self.isNodeLoaded {
            self.controllerNode.deactivateCustomInput()
        }
        self.setupCancelled?()
        self.authentication?.cancel()
    }

    override public func dismiss(completion: (() -> Void)? = nil) {
        self.isLeavingNavigation = true
        self.passcodeModeContextController?.dismiss()
        if self.isNodeLoaded {
            self.controllerNode.deactivateCustomInput()
        }
        self.setupCancelled?()
        self.authentication?.cancel()
        super.dismiss(completion: completion)
    }

    override public func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.controllerNode.deactivateCustomInput()
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.isLeavingNavigation, self.authentication?.state == .finished, self.isNodeLoaded {
            self.controllerNode.updateAuthenticationState(.finished)
        }
    }
    
    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if self.authenticationFailed {
            self.view.isHidden = true
            DispatchQueue.main.async { [weak self] in self?.removeAuthenticationController() }
            return
        }
        
        self.controllerNode.activateInput()
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.view.disablesInteractiveTransitionGestureRecognizer = true
        
        self.controllerNode.activateInput()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    @objc private func nextPressed() {
       self.controllerNode.activateNext()
    }

    fileprivate func updateSetupInputEnabled(_ enabled: Bool) {
        self.view.isUserInteractionEnabled = enabled
        self.controllerNode.updateInputEnabled(enabled)
    }
}

public func applicationPasscodeSetupController(
    context: AccountContext,
    session authorizationSession: PasscodeSession?,
    change: Bool,
    ownsAuthorizationSession: Bool = true,
    preferredModalWidth: CGFloat? = nil,
    initialAutolockTimeout: Int32? = 60 * 60,
    useCustomNumericKeyboard: Bool = true,
    allowFourDigitPasscode: Bool = true,
    settingsSessionCompleted: ((PasscodeSession) -> Void)? = nil,
    cancelled: (() -> Void)? = nil,
    completion: @escaping (PasscodeCredentialReference) -> Void
) -> ViewController {
    let controller = PasscodeSetupController(context: context, mode: .setup(change: change, .digits6), preferredModalWidth: preferredModalWidth, useCustomNumericKeyboard: useCustomNumericKeyboard, allowFourDigitPasscode: allowFourDigitPasscode)
    let lifecycle = PasscodeSetupSessionState(authorizationSession: authorizationSession, ownsAuthorizationSession: ownsAuthorizationSession)
    var savingTask: Task<Void, Never>?
    controller.setupCancelled = {
        savingTask?.cancel()
        if lifecycle.cancel() { cancelled?() }
    }
    let accountId = context.account.id
    controller.setupDisposable = (combineLatest(
        context.sharedContext.applicationBindings.applicationInForeground,
        context.sharedContext.appLockContext.isPasscodeLocked,
        context.sharedContext.activeAccountContexts |> map { primary, _, _ in primary?.account.id == accountId }
    ) |> deliverOnMainQueue).start(next: { [weak controller] foreground, locked, current in
        lifecycle.updateEnvironment(foreground: foreground, locked: locked, currentAccount: current)
        if !foreground || locked || !current {
            controller?.setupCancelled?()
            let remove: () -> Void = { [weak controller] in
                guard let controller else { return }
                controller.updateSetupInputEnabled(false)
                controller.view.isHidden = true
                controller.view.endEditing(true)
                if let navigation = controller.navigationController as? NavigationController,
                   let index = navigation.viewControllers.firstIndex(where: { $0 === controller }), index > 0 {
                    navigation.setViewControllers(Array(navigation.viewControllers.prefix(index)), animated: false)
                }
            }
            remove()
            DispatchQueue.main.async(execute: remove)
        }
    })
    controller.complete = { [weak controller] code, numerical in
        guard let controller, savingTask == nil, lifecycle.accepts(generation: lifecycle.generation) else { return }
        let generation = lifecycle.generation
        controller.updateSetupInputEnabled(false)
        savingTask = Task.detached(priority: .userInitiated) { [weak controller] in
            let result = Result { () -> (PasscodeCredentialReference, PasscodeSession?) in
                guard !Task.isCancelled else { throw PasscodeError.cancelled }
                let kind: PasscodeKind = numerical ? (code.count == 6 ? .digits6 : .digits4) : .alphanumeric
                if settingsSessionCompleted != nil {
                    let result = try PasscodeCredentialStore.shared.setPasscodeWithSettingsSession(code, kind: kind, session: authorizationSession)
                    return (result.reference, result.session)
                }
                return (try PasscodeCredentialStore.shared.setPasscode(code, kind: kind, session: authorizationSession), nil)
            }
            switch result {
            case let .success((reference, session)):
                if Task.isCancelled { session?.invalidate() }
                authorizationSession?.invalidate()
                // A committed credential must reach AccountManager even after UI cancellation.
                let _ = (context.sharedContext.accountManager.transaction { transaction -> Void in
                    transaction.setAccessChallengeData(accessChallengeData(reference: reference))
                    if !change {
                        updatePresentationPasscodeSettingsInternal(transaction: transaction, { $0.withUpdatedAutolockTimeout(initialAutolockTimeout).withUpdatedBiometricsDomainState(LocalAuth.evaluatedPolicyDomainState) })
                    }
                } |> deliverOnMainQueue).start(completed: { [weak controller] in
                    guard controller != nil else { session?.invalidate(); return }
                    guard lifecycle.complete(generation: generation, session: session) else { return }
                    if let session { settingsSessionCompleted?(session) }
                    completion(reference)
                })
            case let .failure(error):
                DispatchQueue.main.async { [weak controller] in
                    guard lifecycle.accepts(generation: generation) else { return }
                    savingTask = nil
                    controller?.updateSetupInputEnabled(true)
                    guard (error as? PasscodeError) != .cancelled else { return }
                    let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
                    controller?.present(textAlertController(context: context, title: nil, text: strings.PasscodeSettings_UpdateError, actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})]), in: .window(.root))
                }
            }
        }
    }
    return controller
}
