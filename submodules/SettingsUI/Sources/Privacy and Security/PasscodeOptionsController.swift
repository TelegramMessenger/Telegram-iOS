import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import LegacyComponents
import LocalAuthentication
import TelegramPresentationData
import TelegramUIPreferences
import ItemListUI
import PresentationDataUtils
import AccountContext
import LocalAuth
import PasscodeUI
import TelegramStringFormatting
import TelegramIntents
import ContextUI
import PasscodeCore
import WalletContext

private final class PasscodeOptionsControllerArguments {
    let turnPasscodeOff: () -> Void
    let changePasscode: () -> Void
    let changePasscodeTimeout: () -> Void
    let changeTouchId: (Bool) -> Void
    let changeWalletProtection: (Bool, Bool) -> Void
    
    init(turnPasscodeOff: @escaping () -> Void, changePasscode: @escaping () -> Void, changePasscodeTimeout: @escaping () -> Void, changeTouchId: @escaping (Bool) -> Void, changeWalletProtection: @escaping (Bool, Bool) -> Void) {
        self.turnPasscodeOff = turnPasscodeOff
        self.changePasscode = changePasscode
        self.changePasscodeTimeout = changePasscodeTimeout
        self.changeTouchId = changeTouchId
        self.changeWalletProtection = changeWalletProtection
    }
}

private enum PasscodeOptionsSection: Int32 {
    case setting
    case options
    case wallet
}

public enum PasscodeOptionsEntryTag: ItemListItemTag, Equatable {
    case togglePasscode
    case changePasscode
    case autolock
    case touchId
   
    public func isEqual(to other: ItemListItemTag) -> Bool {
        if let other = other as? PasscodeOptionsEntryTag, self == other {
            return true
        } else {
            return false
        }
    }
}

private enum PasscodeOptionsEntry: ItemListNodeEntry {
    case togglePasscode(PresentationTheme, String, Bool)
    case changePasscode(PresentationTheme, String)
    case settingInfo(PresentationTheme, String)
    
    case telegramHeader(PresentationTheme, String)
    case walletHeader(PresentationTheme, String)
    case walletPasscode(PresentationTheme, String, Bool, Bool)
    case walletBiometrics(PresentationTheme, String, Bool, Bool)
    case walletInfo(PresentationTheme, String)
    case autoLock(PresentationTheme, String, String)
    case touchId(PresentationTheme, String, Bool)
    
    var section: ItemListSectionId {
        switch self {
            case .togglePasscode, .changePasscode, .settingInfo:
                return PasscodeOptionsSection.setting.rawValue
            case .telegramHeader, .autoLock, .touchId:
                return PasscodeOptionsSection.options.rawValue
            case .walletHeader, .walletPasscode, .walletBiometrics, .walletInfo:
                return PasscodeOptionsSection.wallet.rawValue
        }
    }
    
    var stableId: Int32 {
        switch self {
            case .togglePasscode:
                return 0
            case .changePasscode:
                return 1
            case .settingInfo:
                return 2
            case .telegramHeader: return 3
            case .autoLock: return 4
            case .touchId: return 5
            case .walletHeader: return 6
            case .walletPasscode: return 7
            case .walletBiometrics: return 8
            case .walletInfo: return 9
        }
    }
    
    static func ==(lhs: PasscodeOptionsEntry, rhs: PasscodeOptionsEntry) -> Bool {
        switch lhs {
            case let .telegramHeader(theme, text):
                if case let .telegramHeader(otherTheme, otherText) = rhs { return theme === otherTheme && text == otherText }
                return false
            case let .walletHeader(theme, text):
                if case let .walletHeader(otherTheme, otherText) = rhs { return theme === otherTheme && text == otherText }
                return false
            case let .walletInfo(theme, text):
                if case let .walletInfo(otherTheme, otherText) = rhs { return theme === otherTheme && text == otherText }
                return false
            case let .walletPasscode(theme, text, value, enabled):
                if case let .walletPasscode(otherTheme, otherText, otherValue, otherEnabled) = rhs { return theme === otherTheme && text == otherText && value == otherValue && enabled == otherEnabled }
                return false
            case let .walletBiometrics(theme, text, value, enabled):
                if case let .walletBiometrics(otherTheme, otherText, otherValue, otherEnabled) = rhs { return theme === otherTheme && text == otherText && value == otherValue && enabled == otherEnabled }
                return false

            case let .togglePasscode(lhsTheme, lhsText, lhsValue):
                if case let .togglePasscode(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .changePasscode(lhsTheme, lhsText):
                if case let .changePasscode(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .settingInfo(lhsTheme, lhsText):
                if case let .settingInfo(rhsTheme, rhsText) = rhs, lhsTheme === rhsTheme, lhsText == rhsText {
                    return true
                } else {
                    return false
                }
            case let .autoLock(lhsTheme, lhsText, lhsValue):
                if case let .autoLock(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
            case let .touchId(lhsTheme, lhsText, lhsValue):
                if case let .touchId(rhsTheme, rhsText, rhsValue) = rhs, lhsTheme === rhsTheme, lhsText == rhsText, lhsValue == rhsValue {
                    return true
                } else {
                    return false
                }
        }
    }
    
    static func <(lhs: PasscodeOptionsEntry, rhs: PasscodeOptionsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }
    
    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! PasscodeOptionsControllerArguments
        switch self {
            case let .telegramHeader(_, text), let .walletHeader(_, text):
                return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
            case let .walletInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .walletPasscode(_, title, value, enabled):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enableInteractiveChanges: false, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.changeWalletProtection(false, value)
                })
            case let .walletBiometrics(_, title, value, enabled):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, enableInteractiveChanges: false, enabled: enabled, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.changeWalletProtection(true, value)
                })

            case let .togglePasscode(_, title, _):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.turnPasscodeOff()
                }, tag: PasscodeOptionsEntryTag.togglePasscode)
            case let .changePasscode(_, title):
                return ItemListActionItem(presentationData: presentationData, systemStyle: .glass, title: title, kind: .generic, alignment: .natural, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscode()
                }, tag: PasscodeOptionsEntryTag.changePasscode)
            case let .settingInfo(_, text):
                return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
            case let .autoLock(_, title, value):
                return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, sectionId: self.section, style: .blocks, action: {
                    arguments.changePasscodeTimeout()
                }, tag: PasscodeOptionsEntryTag.autolock)
            case let .touchId(_, title, value):
                return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                    arguments.changeTouchId(value)
                }, tag: PasscodeOptionsEntryTag.touchId)
        }
    }
}

private struct PasscodeOptionsControllerState: Equatable {
    var protection: WalletProtectionSettings?
    var protectionLoaded = false
    var protectionUnavailable = true
    var canUseBiometrics = false
    var faceID = false
}

private final class PasscodeOptionsListController: ItemListController {
    var sessionState: PasscodeSettingsSessionState?

    override func viewWillLeaveNavigation() {
        super.viewWillLeaveNavigation()
        if let navigation = self.navigationController as? NavigationController,
           !navigation.viewControllers.contains(where: { $0 === self }) {
            self.sessionState?.close()
        }
    }

    deinit { self.sessionState?.close() }
}

private final class PasscodeOptionsContextReferenceContentSource: ContextReferenceContentSource {
    private let sourceView: UIView

    init(sourceView: UIView) {
        self.sourceView = sourceView
    }

    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceView, contentAreaInScreenSpace: UIScreen.main.bounds, insets: UIEdgeInsets(top: -4.0, left: 0.0, bottom: -4.0, right: 0.0))
    }
}

private struct PasscodeOptionsData: Equatable {
    let accessChallenge: PostboxAccessChallengeData
    let presentationSettings: PresentationPasscodeSettings
    
    init(accessChallenge: PostboxAccessChallengeData, presentationSettings: PresentationPasscodeSettings) {
        self.accessChallenge = accessChallenge
        self.presentationSettings = presentationSettings
    }
    
    static func ==(lhs: PasscodeOptionsData, rhs: PasscodeOptionsData) -> Bool {
        return lhs.accessChallenge == rhs.accessChallenge && lhs.presentationSettings == rhs.presentationSettings
    }
    
    func withUpdatedAccessChallenge(_ accessChallenge: PostboxAccessChallengeData) -> PasscodeOptionsData {
        return PasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: self.presentationSettings)
    }
    
    func withUpdatedPresentationSettings(_ presentationSettings: PresentationPasscodeSettings) -> PasscodeOptionsData {
        return PasscodeOptionsData(accessChallenge: self.accessChallenge, presentationSettings: presentationSettings)
    }
}

private func autolockStringForTimeout(strings: PresentationStrings, timeout: Int32?) -> String {
    if let timeout = timeout {
        if timeout == 10 {
            return "If away for 10 seconds"
        } else if timeout == 1 * 60 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_1minute
        } else if timeout == 5 * 60 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_5minutes
        } else if timeout == 1 * 60 * 60 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_1hour
        } else if timeout == 5 * 60 * 60 {
            return strings.PasscodeSettings_AutoLock_IfAwayFor_5hours
        } else {
            return ""
        }
    } else {
        return strings.PasscodeSettings_AutoLock_Disabled
    }
}

private func passcodeOptionsControllerEntries(context: AccountContext, presentationData: PresentationData, state: PasscodeOptionsControllerState, passcodeOptionsData: PasscodeOptionsData) -> [PasscodeOptionsEntry] {
    var entries: [PasscodeOptionsEntry] = []
    
    let challenge = state.protection.map { $0.passcode.map { accessChallengeData(reference: $0) } ?? PostboxAccessChallengeData.none } ?? passcodeOptionsData.accessChallenge
    switch challenge {
        case .none:
            entries.append(.togglePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_TurnPasscodeOn, false))
            entries.append(.settingInfo(presentationData.theme, presentationData.strings.PasscodeSettings_Help))
        case .numericalPassword, .plaintextPassword, .secured:
            entries.append(.togglePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_TurnPasscodeOff, true))
            entries.append(.changePasscode(presentationData.theme, presentationData.strings.PasscodeSettings_ChangePasscode))
            entries.append(.settingInfo(presentationData.theme, presentationData.strings.PasscodeSettings_Help))
            entries.append(.telegramHeader(presentationData.theme, presentationData.strings.PasscodeSettings_LockTelegram.uppercased()))
            entries.append(.autoLock(presentationData.theme, presentationData.strings.PasscodeSettings_AutoLock, autolockStringForTimeout(strings: presentationData.strings, timeout: passcodeOptionsData.presentationSettings.autolockTimeout)))
            if let biometricAuthentication = LocalAuth.biometricAuthentication {
                switch biometricAuthentication {
                    case .touchId:
                        entries.append(.touchId(presentationData.theme, presentationData.strings.PasscodeSettings_UnlockWithTouchId, passcodeOptionsData.presentationSettings.enableBiometrics))
                    case .faceId:
                        entries.append(.touchId(presentationData.theme, presentationData.strings.PasscodeSettings_UnlockWithFaceId, passcodeOptionsData.presentationSettings.enableBiometrics))
                }
            }
            if WalletConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 }).isAvailable {
                entries.append(.walletHeader(presentationData.theme, presentationData.strings.PasscodeSettings_LockWallet.uppercased()))
                let protectionEnabled = state.protection?.enabled == true

                let controlsEnabled = !state.protectionUnavailable
                entries.append(.walletPasscode(presentationData.theme, presentationData.strings.PasscodeSettings_WalletConfirmWithPasscode, protectionEnabled, controlsEnabled))
                if protectionEnabled && (state.canUseBiometrics || state.protection?.biometricsEnabled == true) {
                    entries.append(.walletBiometrics(presentationData.theme, state.faceID ? presentationData.strings.PasscodeSettings_WalletConfirmWithFaceId : presentationData.strings.PasscodeSettings_WalletConfirmWithTouchId, state.protection?.biometricsEnabled == true, controlsEnabled))
                }
                entries.append(.walletInfo(presentationData.theme, presentationData.strings.PasscodeSettings_WalletProtectionInfo))
            }
    }
    
    return entries
}

public func passcodeOptionsController(context: AccountContext, focusOnItemTag: PasscodeOptionsEntryTag? = nil, settingsSession: PasscodeSession? = nil) -> ViewController {
    var currentState = PasscodeOptionsControllerState()
    let initialState = currentState
    let sessionState = PasscodeSettingsSessionState(session: settingsSession)
    
    let statePromise = ValuePromise(initialState, ignoreRepeated: true)
    
    var presentControllerImpl: ((ViewController, ViewControllerPresentationArguments?) -> Void)?
    var presentInGlobalOverlayImpl: ((ViewController) -> Void)?
    var pushControllerImpl: ((ViewController) -> Void)?
    var popControllerImpl: (() -> Void)?
    var findAutolockReferenceNode: (() -> ItemListDisclosureItemNode?)?
    var currentAutolockTimeout: Int32?
    
    let actionsDisposable = DisposableSet()
    
    let passcodeOptionsDataPromise = Promise<PasscodeOptionsData>()
    passcodeOptionsDataPromise.set(context.sharedContext.accountManager.transaction { transaction -> (PostboxAccessChallengeData, PresentationPasscodeSettings) in
        let passcodeSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.presentationPasscodeSettings)?.get(PresentationPasscodeSettings.self) ?? PresentationPasscodeSettings.defaultSettings
        return (transaction.getAccessChallengeData(), passcodeSettings)
    }
    |> map { accessChallenge, passcodeSettings -> PasscodeOptionsData in
        return PasscodeOptionsData(accessChallenge: accessChallenge, presentationSettings: passcodeSettings)
    })
    
    var activeBiometricContext: LAContext?
    let biometricAuthenticationDisposable = MetaDisposable()
    actionsDisposable.add(biometricAuthenticationDisposable)
    var isControllerAvailable: () -> Bool = { false }
    var isControllerOnTop: () -> Bool = { false }
    let updateState: () -> Void = {
        statePromise.set(currentState)
    }
    let presentProtectionError: () -> Void = {
        let strings = context.sharedContext.currentPresentationData.with { $0 }.strings
        presentControllerImpl?(textAlertController(context: context, title: nil, text: strings.PasscodeSettings_WalletProtectionError, actions: [TextAlertAction(type: .defaultAction, title: strings.Common_OK, action: {})]), ViewControllerPresentationArguments(presentationAnimation: .modalSheet))
    }
    var refreshGeneration: UInt64 = 0
    let refreshProtection: (Bool) -> Void = { reportError in
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let biometricContext = LAContext()
        let canUseBiometrics = biometricContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        let faceID = biometricContext.biometryType == .faceID
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try walletProtectionSettings() }
            DispatchQueue.main.async {
                guard generation == refreshGeneration else { return }
                currentState.protectionLoaded = true
                currentState.canUseBiometrics = canUseBiometrics
                currentState.faceID = faceID
                switch result {
                case let .success(settings):
                    currentState.protection = settings
                    currentState.protectionUnavailable = false
                case .failure:
                    currentState.protectionUnavailable = true
                    if reportError && isControllerAvailable() { presentProtectionError() }
                }
                updateState()
            }
        }
    }
    actionsDisposable.add(PasscodeCredentialStore.shared.changes.start(next: { _ in
        refreshProtection(false)
    }))
    let accountId = context.account.id
    actionsDisposable.add((combineLatest(
        context.sharedContext.applicationBindings.applicationInForeground,
        context.sharedContext.appLockContext.isPasscodeLocked,
        context.sharedContext.activeAccountContexts |> map { primary, _, _ in primary?.account.id == accountId }
    ) |> deliverOnMainQueue).start(next: { foreground, locked, current in
        sessionState.updateEnvironment(foreground: foreground, locked: locked, currentAccount: current)
        if !foreground || locked || !current {
            activeBiometricContext?.invalidate()
            activeBiometricContext = nil
            biometricAuthenticationDisposable.set(nil)
        }
        updateState()
    }))

    let changeWalletProtection: (Bool, Bool) -> Void = { biometrics, enabled in
        guard !currentState.protectionUnavailable, let operation = sessionState.beginOperation() else { return }
        let generation = sessionState.generation
        updateState()
        let finish: (Error?) -> Void = { error in
            guard sessionState.accepts(operation: operation) else { return }
            activeBiometricContext = nil
            sessionState.finish(operation: operation)
            updateState()
            refreshProtection(false)
            if let error, (error as? PasscodeError) != .cancelled { presentProtectionError() }
        }
        let perform: (PasscodeSession) -> Void = { session in
            guard sessionState.accepts(operation: operation) else { return }
            let authenticationContext = LAContext()
            authenticationContext.localizedReason = context.sharedContext.currentPresentationData.with { $0 }.strings.PasscodeSettings_WalletEnableBiometricsReason
            authenticationContext.localizedFallbackTitle = ""
            authenticationContext.touchIDAuthenticationAllowableReuseDuration = 0
            activeBiometricContext = authenticationContext
            let biometricAuthentication: Disposable? = biometrics && enabled ? context.sharedContext.appLockContext.beginBiometricAuthentication() : nil
            biometricAuthenticationDisposable.set(biometricAuthentication)
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result {
                    if biometrics {
                        try setWalletBiometricsEnabled(enabled, session: session, context: authenticationContext)
                    } else {
                        try setWalletProtectionEnabled(enabled, session: session)
                    }
                }
                authenticationContext.invalidate()
                DispatchQueue.main.async {
                    biometricAuthentication?.dispose()
                    switch result {
                    case .success: finish(nil)
                    case let .failure(error): finish(error)
                    }
                }
            }
        }
        let authenticate: () -> Void = {
            guard sessionState.accepts(operation: operation) else { return }
            weak var authenticationController: ViewController?
            if let controller = settingsPasscodeSessionController(context: context, completion: { result in
                switch result {
                case let .success(session):
                    guard sessionState.accepts(operation: operation),
                          let navigation = authenticationController?.navigationController as? NavigationController,
                          navigation.topViewController === authenticationController,
                          sessionState.replaceSession(session, generation: generation) else { session.invalidate(); return }
                    let _ = navigation.popViewController(animated: true)
                    perform(session)
                case .failure: finish(nil)
                }
            }) {
                authenticationController = controller
                pushControllerImpl?(controller)
            }
        }
        if let session = sessionState.session {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try PasscodeCredentialStore.shared.validate(session, scope: .settings) }
                DispatchQueue.main.async {
                    guard sessionState.accepts(operation: operation) else { return }
                    switch result {
                    case .success: perform(session)
                    case let .failure(error):
                        if let error = error as? PasscodeError, error == .staleAuthorization || error == .authenticationRequired { authenticate() }
                        else { finish(error) }
                    }
                }
            }
        } else { authenticate() }
    }

    func withSettingsSession(
        operation: UInt64,
        proceed: @escaping (PasscodeSession, ViewController?) -> Void,
        failed: @escaping (Error?) -> Void
    ) {
        guard sessionState.accepts(operation: operation), isControllerOnTop() else { failed(nil); return }
        let generation = sessionState.generation
        let authenticate: () -> Void = {
            guard sessionState.accepts(operation: operation), isControllerOnTop() else { failed(nil); return }
            weak var authenticationController: ViewController?
            if let controller = settingsPasscodeSessionController(context: context, completion: { result in
                switch result {
                case let .success(session):
                    guard sessionState.accepts(operation: operation),
                          let authenticationController,
                          let navigation = authenticationController.navigationController as? NavigationController,
                          navigation.topViewController === authenticationController,
                          sessionState.replaceSession(session, generation: generation) else {
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
                guard sessionState.accepts(operation: operation) else { return }
                pushControllerImpl?(controller)
            }
        }
        if let session = sessionState.session {
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Result { try PasscodeCredentialStore.shared.validate(session, scope: .settings) }
                DispatchQueue.main.async {
                    guard sessionState.accepts(operation: operation), isControllerOnTop() else { failed(nil); return }
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

    let arguments = PasscodeOptionsControllerArguments(turnPasscodeOff: {
        guard !sessionState.isUpdating else {
            return
        }
        let current: WalletProtectionSettings
        do {
            current = try walletProtectionSettings()
        }
        catch {
            presentProtectionError();
            return
        }
        let generation = sessionState.generation
        if current.passcode == nil {
            pushControllerImpl?(applicationPasscodeSetupController(context: context, session: nil, change: false, settingsSessionCompleted: { session in
                sessionState.replaceSession(session, generation: generation)
            }, completion: { reference in
                guard sessionState.accepts(generation: generation) else { return }
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { data in
                    passcodeOptionsDataPromise.set(.single(data.withUpdatedAccessChallenge(accessChallengeData(reference: reference))))
                })
                popControllerImpl?()
            }))
            return
        }
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let alert = textAlertController(context: context, title: presentationData.strings.PasscodeSettings_TurnPasscodeOff, text: current.enabled ? presentationData.strings.PasscodeSettings_TurnOffWalletProtectionWarning : presentationData.strings.PasscodeSettings_TurnPasscodeOff, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: presentationData.strings.PasscodeSettings_TurnPasscodeOff, action: {
                guard sessionState.accepts(generation: generation), let operation = sessionState.beginOperation() else { return }
                updateState()
                let finish: (Error?) -> Void = { error in
                    guard sessionState.accepts(operation: operation) else { return }
                    sessionState.finish(operation: operation)
                    updateState()
                    refreshProtection(false)
                    if let error, (error as? PasscodeError) != .cancelled { presentProtectionError() }
                }
                withSettingsSession(operation: operation, proceed: { session, authenticationController in
                    if let authenticationController,
                       let navigation = authenticationController.navigationController as? NavigationController {
                        let _ = navigation.popViewController(animated: true)
                    }
                    DispatchQueue.global(qos: .userInitiated).async {
                        let result = Result { try PasscodeCredentialStore.shared.disablePasscode(session: session) }
                        let _ = (context.sharedContext.accountManager.transaction { transaction -> PostboxAccessChallengeData in
                            transaction.getAccessChallengeData()
                        } |> deliverOnMainQueue).start(next: { challenge in
                            guard sessionState.accepts(operation: operation), isControllerAvailable() else { return }
                            sessionState.finish(operation: operation)
                            if case .none = challenge { sessionState.invalidate() }
                            updateState()
                            refreshProtection(false)
                            let generation = sessionState.generation
                            let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { data in
                                guard sessionState.accepts(generation: generation), isControllerAvailable() else { return }
                                passcodeOptionsDataPromise.set(.single(data.withUpdatedAccessChallenge(challenge)))
                            })
                            if case let .failure(error) = result, (error as? PasscodeError) != .cancelled {
                                presentProtectionError()
                            }
                        })
                    }
                }, failed: finish)
            })
        ])
        presentControllerImpl?(alert, nil)
    }, changePasscode: {
        guard let operation = sessionState.beginOperation() else { return }
        let generation = sessionState.generation
        updateState()
        let finish: (Error?) -> Void = { error in
            guard sessionState.accepts(operation: operation) else { return }
            sessionState.finish(operation: operation)
            updateState()
            if let error, (error as? PasscodeError) != .cancelled { presentProtectionError() }
        }
        withSettingsSession(operation: operation, proceed: { session, authenticationController in
            weak var setupController: ViewController?
            let controller = applicationPasscodeSetupController(context: context, session: session, change: true, ownsAuthorizationSession: false, settingsSessionCompleted: { session in
                guard sessionState.accepts(operation: operation) else { session.invalidate(); return }
                sessionState.replaceSession(session, generation: generation)
            }, cancelled: {
                finish(nil)
            }, completion: { reference in
                guard sessionState.accepts(operation: operation),
                      let setupController,
                      let navigation = setupController.navigationController as? NavigationController,
                      navigation.topViewController === setupController else {
                    finish(nil)
                    return
                }
                sessionState.finish(operation: operation)
                updateState()
                let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { data in
                    guard sessionState.accepts(generation: generation), isControllerAvailable() else { return }
                    passcodeOptionsDataPromise.set(.single(data.withUpdatedAccessChallenge(accessChallengeData(reference: reference))))
                })
                let _ = navigation.popViewController(animated: true)
            })
            setupController = controller
            guard sessionState.accepts(operation: operation) else { return }
            if let authenticationController,
               let navigation = authenticationController.navigationController as? NavigationController {
                navigation.replaceTopController(controller, animated: true)
            } else {
                pushControllerImpl?(controller)
            }
        }, failed: finish)
    }, changePasscodeTimeout: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let setAction: (Int32?) -> Void = { [passcodeOptionsDataPromise] value in
            let _ = (passcodeOptionsDataPromise.get()
            |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
                passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedAutolockTimeout(value))))
                
                let _ = updatePresentationPasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                    return current.withUpdatedAutolockTimeout(value)
                }).start()
            })
        }
        var values: [Int32] = [0, 1 * 60, 5 * 60, 1 * 60 * 60, 5 * 60 * 60]
        
        #if DEBUG
            values.append(10)
            values.sort()
        #endif
        
        var items: [ContextMenuItem] = []
        for value in values {
            var t: Int32?
            if value != 0 {
                t = value
            }
            items.append(.action(ContextMenuActionItem(text: autolockStringForTimeout(strings: presentationData.strings, timeout: t), icon: { theme in
                if currentAutolockTimeout == t {
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Check"), color: theme.contextMenu.primaryColor)
                } else {
                    return UIImage()
                }
            }, action: { _, f in
                f(.default)
                setAction(t)
            })))
        }
        
        guard let sourceNode = findAutolockReferenceNode?() else {
            return
        }
        let contextController = makeContextController(
            presentationData: presentationData,
            source: .reference(PasscodeOptionsContextReferenceContentSource(sourceView: sourceNode.labelNode.view)),
            items: .single(ContextController.Items(content: .list(items))),
            gesture: nil
        )
        sourceNode.updateHasContextMenu(hasContextMenu: true)
        contextController.dismissed = { [weak sourceNode] in
            sourceNode?.updateHasContextMenu(hasContextMenu: false)
        }
        presentInGlobalOverlayImpl?(contextController)
    }, changeTouchId: { [passcodeOptionsDataPromise] value in
        let _ = (passcodeOptionsDataPromise.get() |> take(1)).start(next: { [weak passcodeOptionsDataPromise] data in
            passcodeOptionsDataPromise?.set(.single(data.withUpdatedPresentationSettings(data.presentationSettings.withUpdatedEnableBiometrics(value))))
            
            let _ = updatePresentationPasscodeSettingsInteractively(accountManager: context.sharedContext.accountManager, { current in
                return current.withUpdatedEnableBiometrics(value)
            }).start()
        })
    }, changeWalletProtection: { biometrics, enabled in
        changeWalletProtection(biometrics, enabled)
    })
    
    let signal = combineLatest(context.sharedContext.presentationData, statePromise.get(), passcodeOptionsDataPromise.get()) |> deliverOnMainQueue
    |> filter { _, state, _ in state.protectionLoaded }
    |> map { presentationData, state, passcodeOptionsData -> (ItemListControllerState, (ItemListNodeState, Any)) in
        currentAutolockTimeout = passcodeOptionsData.presentationSettings.autolockTimeout

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(presentationData.strings.PasscodeSettings_Title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back), animateChanges: false)
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: passcodeOptionsControllerEntries(context: context, presentationData: presentationData, state: state, passcodeOptionsData: passcodeOptionsData), style: .blocks, ensureVisibleItemTag: focusOnItemTag, emptyStateItem: nil, animateChanges: true)
        
        return (controllerState, (listState, arguments))
    } |> afterDisposed {
        actionsDisposable.dispose()
        sessionState.close()
        activeBiometricContext?.invalidate()
    }
    
    let controller = PasscodeOptionsListController(context: context, state: signal)
    controller.sessionState = sessionState
    isControllerAvailable = { [weak controller] in
        guard let controller, let navigation = controller.navigationController as? NavigationController else { return false }
        return navigation.viewControllers.contains(where: { $0 === controller })
    }
    isControllerOnTop = { [weak controller] in
        guard let controller, let navigation = controller.navigationController as? NavigationController else { return false }
        return navigation.topViewController === controller
    }
    controller.didAppear = { firstTime in
        if firstTime {
            if currentState.protectionUnavailable { presentProtectionError() }
        } else {
            refreshProtection(true)
        }
    }
    controller.didDisappear = { [weak controller] _ in
        guard let controller else { return }
        if !isControllerAvailable() || controller.isBeingDismissed {
            sessionState.close()
            activeBiometricContext?.invalidate()
            biometricAuthenticationDisposable.set(nil)
        }
    }
    presentControllerImpl = { [weak controller] c, p in
        if let controller = controller {
            controller.present(c, in: .window(.root), with: p)
        }
    }
    presentInGlobalOverlayImpl = { [weak controller] c in
        controller?.presentInGlobalOverlay(c, with: nil)
    }
    pushControllerImpl = { [weak controller] c in
        (controller?.navigationController as? NavigationController)?.pushViewController(c)
    }
    popControllerImpl = { [weak controller] in
        let _ = (controller?.navigationController as? NavigationController)?.popViewController(animated: true)
    }
    findAutolockReferenceNode = { [weak controller] in
        return controller?.itemNode(forTag: PasscodeOptionsEntryTag.autolock) as? ItemListDisclosureItemNode
    }
    
    if let focusOnItemTag {
        var didFocusOnItem = false
        controller.afterTransactionCompleted = { [weak controller] in
            if !didFocusOnItem, let controller {
                controller.forEachItemNode { itemNode in
                    if let itemNode = itemNode as? ItemListItemNode, let tag = itemNode.tag, tag.isEqual(to: focusOnItemTag) {
                        didFocusOnItem = true
                        itemNode.displayHighlight()
                    }
                }
            }
        }
    }
    
    refreshProtection(false)
    return controller
}

public func passcodeOptionsAccessController(context: AccountContext, preferredModalWidth: CGFloat? = nil, initialAutolockTimeout: Int32? = 60 * 60, useCustomNumericKeyboard: Bool = true, allowFourDigitPasscode: Bool = true, replaceController: @escaping (ViewController) -> Void, authorizationCompleted: @escaping (Result<PasscodeSession, PasscodeError>) -> Void) -> Signal<ViewController?, NoError> {
    return context.sharedContext.accountManager.transaction { transaction -> PostboxAccessChallengeData in
        transaction.getAccessChallengeData()
    }
    |> deliverOnMainQueue
    |> map { challenge -> ViewController? in
        if case .none = challenge {
            weak var introController: PrivacyIntroController?
            var didProceed = false
            let controller = PrivacyIntroController(context: context, mode: .passcode, preferredModalWidth: preferredModalWidth, proceedAction: {
                guard !didProceed, let introController,
                      let navigation = introController.navigationController as? NavigationController,
                      navigation.topViewController === introController else {
                    return
                }
                didProceed = true
                let setupController = applicationPasscodeSetupController(context: context, session: nil, change: false, preferredModalWidth: preferredModalWidth, initialAutolockTimeout: initialAutolockTimeout, useCustomNumericKeyboard: useCustomNumericKeyboard, allowFourDigitPasscode: allowFourDigitPasscode, settingsSessionCompleted: { session in
                    authorizationCompleted(.success(session))
                }, cancelled: { authorizationCompleted(.failure(.cancelled)) }, completion: { _ in
                    deleteAllSendMessageIntents()
                })
                replaceController(setupController)
            })
            introController = controller
            return controller
        }
        return settingsPasscodeSessionController(context: context, preferredModalWidth: preferredModalWidth, completion: authorizationCompleted)
    }
}
