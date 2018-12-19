import Foundation
import Intents
import TelegramUI
import SwiftSignalKit
import Postbox
import TelegramCore
import Display
import LegacyComponents

func applicationContext(networkArguments: NetworkInitializationArguments, applicationBindings: TelegramApplicationBindings, replyFromNotificationsActive: Signal<Bool, NoError>, backgroundAudioActive: Signal<Bool, NoError>, watchManagerArguments: Signal<WatchManagerArguments?, NoError>, accountManager: AccountManager, rootPath: String, legacyBasePath: String, testingEnvironment: Bool, mainWindow: Window1, reinitializedNotificationSettings: @escaping () -> Void) -> Signal<ApplicationContext?, NoError> {
    return currentAccount(allocateIfNotExists: true, networkArguments: networkArguments, supplementary: false, manager: accountManager, rootPath: rootPath, beginWithTestingEnvironment: testingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods)
    |> filter { $0 != nil }
    |> deliverOnMainQueue
    |> mapToSignal { account -> Signal<ApplicationContext?, NoError> in
        if let account = account {
            switch account {
                case .upgrading:
                    return .single(.upgrading(UpgradingApplicationContext()))
                case let .unauthorized(account):
                    return currentPresentationDataAndSettings(postbox: account.postbox)
                        |> deliverOnMainQueue
                        |> map { dataAndSettings -> ApplicationContext? in
                            return .unauthorized(UnauthorizedApplicationContext(applicationContext: TelegramApplicationContext(applicationBindings: applicationBindings, accountManager: accountManager, account: nil, initialPresentationDataAndSettings: dataAndSettings, postbox: account.postbox), account: account))
                        }
                case let .authorized(account):
                    return currentPresentationDataAndSettings(postbox: account.postbox)
                        |> deliverOnMainQueue
                        |> map { dataAndSettings -> ApplicationContext? in
                            return .authorized(AuthorizedApplicationContext(mainWindow: mainWindow, applicationContext: TelegramApplicationContext(applicationBindings: applicationBindings, accountManager: accountManager, account: account, initialPresentationDataAndSettings: dataAndSettings, postbox: account.postbox), replyFromNotificationsActive: replyFromNotificationsActive, backgroundAudioActive: backgroundAudioActive, watchManagerArguments: watchManagerArguments, account: account, accountManager: accountManager, legacyBasePath: legacyBasePath, showCallsTab: dataAndSettings.callListSettings.showTab, reinitializedNotificationSettings: reinitializedNotificationSettings))
                    }
            }
        } else {
            return .single(nil)
        }
    }
}

func isAccessLocked(data: PostboxAccessChallengeData, at timestamp: Int32) -> Bool {
    if data.isLockable, let autolockDeadline = data.autolockDeadline, autolockDeadline <= timestamp {
        return true
    } else {
        return false
    }
}

enum ApplicationContext {
    case upgrading(UpgradingApplicationContext)
    case unauthorized(UnauthorizedApplicationContext)
    case authorized(AuthorizedApplicationContext)
    
    var account: Account? {
        switch self {
            case .upgrading:
                return nil
            case .unauthorized:
                return nil
            case let .authorized(context):
                return context.account
        }
    }
    
    var accountId: AccountRecordId? {
        switch self {
            case .upgrading:
                return nil
            case let .unauthorized(unauthorized):
                return unauthorized.account.id
            case let .authorized(authorized):
                return authorized.account.id
        }
    }
    
    var rootController: NavigationController {
        switch self {
            case let .upgrading(context):
                return context.rootController
            case let .unauthorized(context):
                return context.rootController
            case let .authorized(context):
                return context.rootController
        }
    }
    
    var overlayControllers: [ViewController] {
        switch self {
            case .upgrading:
                return []
            case .unauthorized:
                return []
            case let .authorized(context):
                return [context.overlayMediaController, context.notificationController]
        }
    }
}

final class UpgradingApplicationContext {
    let rootController: NavigationController
    
    init() {
        self.rootController = NavigationController(mode: .single, theme: NavigationControllerTheme(navigationBar: NavigationBarTheme(buttonColor: .white, disabledButtonColor: .gray, primaryTextColor: .white, backgroundColor: .black, separatorColor: .white, badgeBackgroundColor: .black, badgeStrokeColor: .black, badgeTextColor: .white), emptyAreaColor: .black, emptyDetailIcon: nil))
        
        let noticeController = ViewController(navigationBarPresentationData: nil)
        self.rootController.pushViewController(noticeController, animated: false)
    }
}

final class UnauthorizedApplicationContext {
    let applicationContext: TelegramApplicationContext
    let account: UnauthorizedAccount
    
    let rootController: AuthorizationSequenceController
    
    init(applicationContext: TelegramApplicationContext, account: UnauthorizedAccount) {
        self.account = account
        self.applicationContext = applicationContext
        
        self.rootController = AuthorizationSequenceController(account: account, strings: (applicationContext.currentPresentationData.with { $0 }).strings, openUrl: { [weak applicationContext] url in
            applicationContext?.applicationBindings.openUrl(url)
        }, apiId: BuildConfig.shared().apiId, apiHash: BuildConfig.shared().apiHash)
        
        account.shouldBeServiceTaskMaster.set(applicationContext.applicationBindings.applicationInForeground |> map { value -> AccountServiceTaskMasterMode in
            if value {
                return .always
            } else {
                return .never
            }
        })
    }
}

private struct PasscodeState: Equatable {
    let isActive: Bool
    let challengeData: PostboxAccessChallengeData
    let autolockTimeout: Int32?
    let enableBiometrics: Bool
}

private enum CallStatusText: Equatable {
    case none
    case inProgress(Double?)
    
    static func ==(lhs: CallStatusText, rhs: CallStatusText) -> Bool {
        switch lhs {
            case .none:
                if case .none = rhs {
                    return true
                } else {
                    return false
                }
            case let .inProgress(lhsReferenceTime):
                if case let .inProgress(rhsReferenceTime) = rhs, lhsReferenceTime == rhsReferenceTime {
                    return true
                } else {
                    return false
                }
            
        }
    }
}

final class AuthorizedApplicationContext {
    let mainWindow: Window1
    let lockedCoveringView: LockedWindowCoveringView
    
    let applicationContext: TelegramApplicationContext
    let account: Account
    let replyFromNotificationsActive: Signal<Bool, NoError>
    let backgroundAudioActive: Signal<Bool, NoError>
    
    let rootController: TelegramRootController
    let overlayMediaController: OverlayMediaController
    let notificationController: NotificationContainerController
    
    private var scheduledOperChatWithPeerId: PeerId?
    private var scheduledOpenExternalUrl: URL?
    
    let wakeupManager: WakeupManager
    let notificationManager: NotificationManager
        
    private let passcodeStatusDisposable = MetaDisposable()
    private let passcodeLockDisposable = MetaDisposable()
    private let loggedOutDisposable = MetaDisposable()
    private let inAppNotificationSettingsDisposable = MetaDisposable()
    private let notificationMessagesDisposable = MetaDisposable()
    private let termsOfServiceUpdatesDisposable = MetaDisposable()
    private let termsOfServiceProceedToBotDisposable = MetaDisposable()
    private let watchNavigateToMessageDisposable = MetaDisposable()
    private let permissionsDisposable = MetaDisposable()
    
    private var inAppNotificationSettings: InAppNotificationSettings?
    
    private var isLocked: Bool = true
    private var passcodeController: ViewController?
    private var callController: CallController?
    private let hasOngoingCall = ValuePromise<Bool>(false)
    private let callState = Promise<PresentationCallState?>(nil)
    
    private var currentTermsOfServiceUpdate: TermsOfServiceUpdate?
    private var currentPermissionsController: PermissionController?
    
    private let unlockedStatePromise = Promise<Bool>()
    var unlockedState: Signal<Bool, NoError> {
        return self.unlockedStatePromise.get()
    }
    
    var applicationBadge: Signal<Int32, NoError> {
        return renderedTotalUnreadCount(postbox: self.account.postbox)
        |> map {
            $0.0
        }
    }
    
    private var presentationDataDisposable: Disposable?
    private var displayAlertsDisposable: Disposable?
    private var removeNotificationsDisposable: Disposable?
    private var callDisposable: Disposable?
    private var callStateDisposable: Disposable?
    private var currentCallStatusText: CallStatusText = .none
    private var currentCallStatusTextTimer: SwiftSignalKit.Timer?
    
    private var applicationInForegroundDisposable: Disposable?
    
    private var showCallsTab: Bool
    private var showCallsTabDisposable: Disposable?
    private var enablePostboxTransactionsDiposable: Disposable?
    
    init(mainWindow: Window1, applicationContext: TelegramApplicationContext, replyFromNotificationsActive: Signal<Bool, NoError>, backgroundAudioActive: Signal<Bool, NoError>, watchManagerArguments: Signal<WatchManagerArguments?, NoError>, account: Account, accountManager: AccountManager,  legacyBasePath: String, showCallsTab: Bool, reinitializedNotificationSettings: @escaping () -> Void) {
        setupLegacyComponents(account: account)
        let presentationData = applicationContext.currentPresentationData.with { $0 }
        
        self.mainWindow = mainWindow
        self.lockedCoveringView = LockedWindowCoveringView(theme: presentationData.theme)
        
        self.applicationContext = applicationContext
        self.account = account
        self.replyFromNotificationsActive = replyFromNotificationsActive
        self.backgroundAudioActive = backgroundAudioActive
        
        let runningBackgroundLocationTasks: Signal<Bool, NoError>
        if let liveLocationManager = applicationContext.liveLocationManager {
            runningBackgroundLocationTasks = liveLocationManager.isPolling
        } else {
            runningBackgroundLocationTasks = .single(false)
        }
        
        let runningWatchTasksPromise = Promise<WatchRunningTasks?>(nil)
        
        let downloadPreferencesKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings]))
        let runningDownloadTasks = combineLatest(account.postbox.combinedView(keys: [downloadPreferencesKey]), account.shouldKeepBackgroundDownloadConnections.get())
        |> map { views, shouldKeepBackgroundDownloadConnections -> Bool in
            let settings: AutomaticMediaDownloadSettings = (views.views[downloadPreferencesKey] as? PreferencesView)?.values[ApplicationSpecificPreferencesKeys.automaticMediaDownloadSettings] as? AutomaticMediaDownloadSettings ?? AutomaticMediaDownloadSettings.defaultSettings
            if !settings.downloadInBackground {
                return false
            }
            return shouldKeepBackgroundDownloadConnections
        }
        |> distinctUntilChanged
        
        self.wakeupManager = WakeupManager(inForeground: applicationContext.applicationBindings.applicationInForeground, runningServiceTasks: account.importantTasksRunning, runningBackgroundLocationTasks: runningBackgroundLocationTasks, runningWatchTasks: runningWatchTasksPromise.get(), runningDownloadTasks: runningDownloadTasks)
        self.wakeupManager.account = account
        
        self.showCallsTab = showCallsTab
        
        self.notificationManager = NotificationManager()
        self.notificationManager.account = account
        self.notificationManager.isApplicationInForeground = false
        
        self.overlayMediaController = OverlayMediaController()
        
        applicationContext.attachOverlayMediaController(self.overlayMediaController)
        var presentImpl: ((ViewController, Any?) -> Void)?
        var openSettingsImpl: (() -> Void)?
        let callManager = PresentationCallManager(account: account, getDeviceAccessData: {
            return (account.telegramApplicationContext.currentPresentationData.with { $0 }, { c, a in
                presentImpl?(c, a)
            }, {
                openSettingsImpl?()
            })
        }, networkType: account.networkType, audioSession: applicationContext.mediaManager!.audioSession, callSessionManager: account.callSessionManager)
        applicationContext.callManager = callManager
        applicationContext.hasOngoingCall = self.hasOngoingCall.get()
        
        let shouldBeServiceTaskMaster = combineLatest(applicationContext.applicationBindings.applicationInForeground, self.wakeupManager.isWokenUp, replyFromNotificationsActive, backgroundAudioActive, callManager.hasActiveCalls)
        |> map { foreground, wokenUp, replyFromNotificationsActive, backgroundAudioActive, hasActiveCalls -> AccountServiceTaskMasterMode in
            if foreground || wokenUp || replyFromNotificationsActive || hasActiveCalls {
                return .always
            } else {
                return .never
            }
        }
        account.shouldBeServiceTaskMaster.set(shouldBeServiceTaskMaster)
        self.enablePostboxTransactionsDiposable = (combineLatest(shouldBeServiceTaskMaster, backgroundAudioActive)
        |> map { shouldBeServiceTaskMaster, backgroundAudioActive -> Bool in
            switch shouldBeServiceTaskMaster {
                case .never:
                    break
                default:
                    return true
            }
            if backgroundAudioActive {
                return true
            }
            return false
        }
        |> deliverOnMainQueue).start(next: { [weak account] next in
            if let account = account {
                Logger.shared.log("ApplicationContext", "setting canBeginTransactions to \(next)")
                account.postbox.setCanBeginTransactions(next)
            }
        })
        account.shouldExplicitelyKeepWorkerConnections.set(backgroundAudioActive)
        account.shouldKeepBackgroundDownloadConnections.set(applicationContext.fetchManager.hasUserInitiatedEntries)
        account.shouldKeepOnlinePresence.set(applicationContext.applicationBindings.applicationInForeground)
        
        let cache = TGCache(cachesPath: legacyBasePath + "/Caches")!
        
        setupAccount(account, fetchCachedResourceRepresentation: fetchCachedResourceRepresentation, transformOutgoingMessageMedia: transformOutgoingMessageMedia, preFetchedResourcePath: { resource in
            preFetchedLegacyResourcePath(basePath: legacyBasePath, resource: resource, cache: cache)
        })
        
        account.applicationContext = applicationContext
        
        self.notificationController = NotificationContainerController(account: account)
        
        self.mainWindow.previewThemeAccentColor = presentationData.theme.rootController.navigationBar.accentTextColor
        self.mainWindow.previewThemeDarkBlur = presentationData.theme.chatList.searchBarKeyboardColor == .dark
        self.mainWindow.setupVolumeControlStatusBarGraphics(presentationData.volumeControlStatusBarIcons.images)
        
        self.rootController = TelegramRootController(account: account)
        
        if KeyShortcutsController.isAvailable {
            let keyShortcutsController = KeyShortcutsController { [weak self] f in
                if let strongSelf = self {
                    if let tabController = strongSelf.rootController.rootTabController {
                        let controller = tabController.controllers[tabController.selectedIndex]
                        if !f(controller) {
                            return
                        }
                        if let controller = strongSelf.rootController.topViewController as? ViewController {
                            if !f(controller) {
                                return
                            }
                        }
                    }
                    strongSelf.mainWindow.forEachViewController(f)
                }
            }
            applicationContext.keyShortcutsController = keyShortcutsController
        }
        
        self.applicationInForegroundDisposable = applicationContext.applicationBindings.applicationInForeground.start(next: { [weak self] value in
            Queue.mainQueue().async {
                self?.notificationManager.isApplicationInForeground = value
            }
        })
        
        self.mainWindow.inCallNavigate = { [weak self] in
            if let strongSelf = self, let callController = strongSelf.callController {
                if callController.isNodeLoaded && callController.view.superview == nil {
                    strongSelf.rootController.view.endEditing(true)
                    strongSelf.mainWindow.present(callController, on: .calls)
                }
            }
        }
        
        applicationContext.presentGlobalController = { [weak self] c, a in
            self?.mainWindow.present(c, on: .root)
        }
        applicationContext.presentCrossfadeController = { [weak self] in
            guard let strongSelf = self else {
                return
            }
            var exists = false
            strongSelf.mainWindow.forEachViewController { controller in
                if controller is ThemeSettingsCrossfadeController {
                    exists = true
                }
                return true
            }
            
            if !exists {
                mainWindow.present(ThemeSettingsCrossfadeController(), on: .root)
            }
        }
        
        applicationContext.navigateToCurrentCall = { [weak self] in
            if let strongSelf = self, let callController = strongSelf.callController {
                if callController.isNodeLoaded && callController.view.superview == nil {
                    strongSelf.rootController.view.endEditing(true)
                    strongSelf.mainWindow.present(callController, on: .calls)
                }
            }
        }
        
        presentImpl = { [weak self] c, _ in
            self?.mainWindow.present(c, on: .root)
        }
        openSettingsImpl = {
            applicationContext.applicationBindings.openSettings()
        }
        
        let previousPasscodeState = Atomic<PasscodeState?>(value: nil)
        
        let preferencesKey: PostboxViewKey = .preferences(keys: Set<ValueBoxKey>([ApplicationSpecificPreferencesKeys.presentationPasscodeSettings]))
        
        self.passcodeStatusDisposable.set((combineLatest(queue: Queue.mainQueue(), account.postbox.combinedView(keys: [.accessChallengeData, preferencesKey]), applicationContext.applicationBindings.applicationIsActive)
        |> map { view, isActive -> (PostboxAccessChallengeData, PresentationPasscodeSettings?, Bool) in
            let accessChallengeData = (view.views[.accessChallengeData] as? AccessChallengeDataView)?.data ?? PostboxAccessChallengeData.none
            let passcodeSettings = (view.views[preferencesKey] as! PreferencesView).values[ApplicationSpecificPreferencesKeys.presentationPasscodeSettings] as? PresentationPasscodeSettings
            return (accessChallengeData, passcodeSettings, isActive)
        }
        |> map { accessChallengeData, passcodeSettings, isActive -> PasscodeState in
            return PasscodeState(isActive: isActive, challengeData: accessChallengeData, autolockTimeout: passcodeSettings?.autolockTimeout, enableBiometrics: passcodeSettings?.enableBiometrics ?? false)
        }).start(next: { [weak self] updatedState in
            guard let strongSelf = self else {
                return
            }
            let previousState = previousPasscodeState.swap(updatedState)
            
            var updatedAutolockDeadline: Int32?
            if updatedState.isActive != previousState?.isActive, let autolockTimeout = updatedState.autolockTimeout {
                updatedAutolockDeadline = Int32(CFAbsoluteTimeGetCurrent()) + max(10, autolockTimeout)
            }
            
            var effectiveAutolockDeadline = updatedState.challengeData.autolockDeadline
            if updatedState.isActive {
            } else if previousState != nil && previousState!.autolockTimeout != updatedState.autolockTimeout {
                effectiveAutolockDeadline = updatedAutolockDeadline
            }
            
            if let previousState = previousState, previousState.isActive, !updatedState.isActive, effectiveAutolockDeadline != 0 {
                effectiveAutolockDeadline = updatedAutolockDeadline
            }
            
            var isLocked = false
            if isAccessLocked(data: updatedState.challengeData.withUpdatedAutolockDeadline(effectiveAutolockDeadline), at: Int32(CFAbsoluteTimeGetCurrent())) {
                isLocked = true
                updatedAutolockDeadline = 0
            }
            
            let isLockable: Bool
            switch updatedState.challengeData {
                case .none:
                    isLockable = false
                default:
                    isLockable = true
            }
            
            if previousState?.isActive != updatedState.isActive || isLocked != strongSelf.isLocked {
                if updatedAutolockDeadline != previousState?.challengeData.autolockDeadline {
                    let _ = (account.postbox.transaction { transaction -> Void in
                        let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(updatedAutolockDeadline)
                        transaction.setAccessChallengeData(data)
                    }).start()
                }
                
                strongSelf.isLocked = isLocked
                strongSelf.notificationManager.isApplicationLocked = isLocked
                
                if isLocked {
                    if updatedState.isActive {
                        if strongSelf.passcodeController == nil {
                            var attemptData: TGPasscodeEntryAttemptData?
                            if let attempts = updatedState.challengeData.attempts {
                                attemptData = TGPasscodeEntryAttemptData(numberOfInvalidAttempts: Int(attempts.count), dateOfLastInvalidAttempt: Double(attempts.timestamp))
                            }
                            var mode: TGPasscodeEntryControllerMode
                            switch updatedState.challengeData {
                                case .none:
                                    mode = TGPasscodeEntryControllerModeVerifySimple
                                case .numericalPassword:
                                    mode = TGPasscodeEntryControllerModeVerifySimple
                                case .plaintextPassword:
                                    mode = TGPasscodeEntryControllerModeVerifyComplex
                            }
                            let presentationData = strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }
                            let presentAnimated = previousState != nil && previousState!.isActive
                            let legacyController = LegacyController(presentation: LegacyControllerPresentation.modal(animateIn: presentAnimated), theme: presentationData.theme)
                            let controller = TGPasscodeEntryController(context: legacyController.context, style: TGPasscodeEntryControllerStyleDefault, mode: mode, cancelEnabled: false, allowTouchId: updatedState.enableBiometrics, attemptData: attemptData, completion: { value in
                                if value != nil {
                                    let _ = (account.postbox.transaction { transaction -> Void in
                                        let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(nil)
                                        transaction.setAccessChallengeData(data)
                                    }).start()
                                }
                            })!
                            controller.checkCurrentPasscode = { value in
                                if let value = value {
                                    switch updatedState.challengeData {
                                        case .none:
                                            return true
                                        case let .numericalPassword(code, _, _):
                                            return value == code
                                        case let .plaintextPassword(code, _, _):
                                            return value == code
                                    }
                                } else {
                                    return false
                                }
                            }
                            controller.updateAttemptData = { attemptData in
                                let _ = account.postbox.transaction({ transaction -> Void in
                                    var attempts: AccessChallengeAttempts?
                                    if let attemptData = attemptData {
                                        attempts = AccessChallengeAttempts(count: Int32(attemptData.numberOfInvalidAttempts), timestamp: Int32(attemptData.dateOfLastInvalidAttempt))
                                    }
                                    var data = transaction.getAccessChallengeData()
                                    switch data {
                                    case .none:
                                        break
                                    case let .numericalPassword(value, timeout, _):
                                        data = .numericalPassword(value: value, timeout: timeout, attempts: attempts)
                                    case let .plaintextPassword(value, timeout, _):
                                        data = .plaintextPassword(value: value, timeout: timeout, attempts: attempts)
                                    }
                                    transaction.setAccessChallengeData(data)
                                }).start()
                            }
                            controller.touchIdCompletion = {
                                let _ = (account.postbox.transaction { transaction -> Void in
                                    let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(nil)
                                    transaction.setAccessChallengeData(data)
                                }).start()
                            }
                            legacyController.bind(controller: controller)
                            legacyController.supportedOrientations = ViewControllerSupportedOrientations(regularSize: .portrait, compactSize: .portrait)
                            legacyController.statusBar.statusBarStyle = .White
                            strongSelf.passcodeController = legacyController
                            
                            strongSelf.unlockedStatePromise.set(.single(false))
                            if presentAnimated {
                                legacyController.presentationCompleted = {
                                    if let strongSelf = self {
                                        strongSelf.rootController.view.isHidden = true
                                        strongSelf.overlayMediaController.view.isHidden = true
                                        strongSelf.notificationController.view.isHidden = true
                                    }
                                }
                            } else {
                                strongSelf.rootController.view.isHidden = true
                                strongSelf.overlayMediaController.view.isHidden = true
                                strongSelf.notificationController.view.isHidden = true
                            }
                            
                            strongSelf.mainWindow.present(legacyController, on: .passcode)
                            
                            if !presentAnimated {
                                controller.refreshTouchId()
                            }
                        } else if previousState?.isActive != updatedState.isActive, updatedState.isActive, let passcodeController = strongSelf.passcodeController as? LegacyController {
                            if let controller = passcodeController.legacyController as? TGPasscodeEntryController {
                                controller.refreshTouchId()
                            }
                        }
                        strongSelf.updateCoveringViewSnaphot(false)
                        strongSelf.mainWindow.coveringView = nil
                    } else {
                        strongSelf.unlockedStatePromise.set(.single(false))
                        strongSelf.updateCoveringViewSnaphot(true)
                        strongSelf.mainWindow.coveringView = strongSelf.lockedCoveringView
                        strongSelf.rootController.view.isHidden = true
                        strongSelf.overlayMediaController.view.isHidden = true
                        strongSelf.notificationController.view.isHidden = true
                    }
                } else {
                    if !updatedState.isActive && updatedState.autolockTimeout != nil && isLockable {
                        strongSelf.updateCoveringViewSnaphot(true)
                        strongSelf.mainWindow.coveringView = strongSelf.lockedCoveringView
                        strongSelf.rootController.view.isHidden = true
                        strongSelf.overlayMediaController.view.isHidden = true
                        strongSelf.notificationController.view.isHidden = true
                    } else {
                        strongSelf.updateCoveringViewSnaphot(false)
                        strongSelf.mainWindow.coveringView = nil
                        strongSelf.rootController.view.isHidden = false
                        strongSelf.overlayMediaController.view.isHidden = false
                        strongSelf.notificationController.view.isHidden = false
                        if strongSelf.rootController.rootTabController == nil {
                            strongSelf.rootController.addRootControllers(showCallsTab: strongSelf.showCallsTab)
                            if let peerId = strongSelf.scheduledOperChatWithPeerId {
                                strongSelf.scheduledOperChatWithPeerId = nil
                                strongSelf.openChatWithPeerId(peerId: peerId)
                            }
                            
                            if let url = strongSelf.scheduledOpenExternalUrl {
                                strongSelf.scheduledOpenExternalUrl = nil
                                strongSelf.openUrl(url)
                            }
                            
                            if #available(iOS 10.0, *) {
                                INPreferences.requestSiriAuthorization { _ in
                                }
                            } else {
                                DeviceAccess.authorizeAccess(to: .contacts, presentationData: strongSelf.account.telegramApplicationContext.currentPresentationData.with { $0 }, present: { c, a in
                                }, openSettings: {}, { _ in })
                            }
                            
                            if let passcodeController = strongSelf.passcodeController {
                                if let chatListController = strongSelf.rootController.chatListController {
                                    let _ = chatListController.ready.get().start(next: { [weak passcodeController] _ in
                                        if let strongSelf = self, let passcodeController = passcodeController, strongSelf.passcodeController === passcodeController {
                                            strongSelf.passcodeController = nil
                                            strongSelf.rootController.chatListController?.displayNode.recursivelyEnsureDisplaySynchronously(true)
                                            passcodeController.dismiss()
                                        }
                                    })
                                } else {
                                    strongSelf.passcodeController = nil
                                    strongSelf.rootController.chatListController?.displayNode.recursivelyEnsureDisplaySynchronously(true)
                                    passcodeController.dismiss()
                                }
                            }
                        } else {
                            if let passcodeController = strongSelf.passcodeController {
                                strongSelf.passcodeController = nil
                                passcodeController.dismiss()
                            }
                        }
                    }
                    strongSelf.unlockedStatePromise.set(.single(true))
                }
            }/* else if updatedAutolockDeadline != previousState?.challengeData.autolockDeadline {
                let _ = (account.postbox.transaction { transaction -> Void in
                    let data = transaction.getAccessChallengeData().withUpdatedAutolockDeadline(updatedAutolockDeadline)
                    transaction.setAccessChallengeData(data)
                }).start()
            }*/
        }))
        
        let accountId = account.id
        self.loggedOutDisposable.set(account.loggedOut.start(next: { value in
            if value {
                Logger.shared.log("ApplicationContext", "account logged out")
                let _ = logoutFromAccount(id: accountId, accountManager: accountManager).start()
            }
        }))
        
        let inAppPreferencesKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.inAppNotificationSettings]))
        self.inAppNotificationSettingsDisposable.set(((account.postbox.combinedView(keys: [inAppPreferencesKey])) |> deliverOnMainQueue).start(next: { [weak self] views in
            if let strongSelf = self {
                if let view = views.views[inAppPreferencesKey] as? PreferencesView {
                    if let settings = view.values[ApplicationSpecificPreferencesKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                        let previousSettings = strongSelf.inAppNotificationSettings
                        strongSelf.inAppNotificationSettings = settings
                        if let previousSettings = previousSettings, previousSettings.displayNameOnLockscreen != settings.displayNameOnLockscreen {
                            reinitializedNotificationSettings()
                        }
                    }
                }
            }
        }))
        
        self.notificationMessagesDisposable.set((account.stateManager.notificationMessages |> deliverOn(Queue.mainQueue())).start(next: { [weak self] messageList in
            if let strongSelf = self, let (messages, groupId, notify) = messageList.last, let firstMessage = messages.first {
                if UIApplication.shared.applicationState == .active {
                    var chatIsVisible = false
                    if let topController = strongSelf.rootController.topViewController as? ChatController, topController.traceVisibility() {
                        if case .peer(firstMessage.id.peerId) = topController.chatLocation {
                            chatIsVisible = true
                        } else if case let .group(topGroupId) = topController.chatLocation, topGroupId == groupId {
                            chatIsVisible = true
                        }
                    }
                    
                    if !notify {
                        chatIsVisible = true
                    }
                    
                    if !chatIsVisible {
                        strongSelf.mainWindow.forEachViewController({ controller in
                            if let controller = controller as? ChatController, case .peer(firstMessage.id.peerId) = controller.chatLocation  {
                                chatIsVisible = true
                                return false
                            }
                            return true
                        })
                    }
                    
                    let inAppNotificationSettings: InAppNotificationSettings
                    if let current = strongSelf.inAppNotificationSettings {
                        inAppNotificationSettings = current
                    } else {
                        inAppNotificationSettings = InAppNotificationSettings.defaultSettings
                    }
                    
                    if !strongSelf.isLocked {
                        if inAppNotificationSettings.playSounds {
                            serviceSoundManager.playIncomingMessageSound()
                        }
                        if inAppNotificationSettings.vibrate {
                            serviceSoundManager.playVibrationSound()
                        }
                    }
                    
                    if chatIsVisible {
                        return
                    }
                    
                    if inAppNotificationSettings.displayPreviews {
                       let presentationData = strongSelf.applicationContext.currentPresentationData.with { $0 }
                        strongSelf.notificationController.enqueue(ChatMessageNotificationItem(account: strongSelf.account, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, messages: messages, tapAction: {
                            if let strongSelf = self {
                                var foundOverlay = false
                                strongSelf.mainWindow.forEachViewController({ controller in
                                    if isOverlayControllerForChatNotificationOverlayPresentation(controller) {
                                        foundOverlay = true
                                        return false
                                    }
                                    return true
                                })
                                
                                if foundOverlay {
                                    return true
                                }
                                
                                if let topController = strongSelf.rootController.topViewController as? ViewController, isInlineControllerForChatNotificationOverlayPresentation(topController) {
                                    return true
                                }
                                
                                if let topController = strongSelf.rootController.topViewController as? ChatController, case .peer(firstMessage.id.peerId) = topController.chatLocation {
                                    strongSelf.notificationController.removeItemsWithGroupingKey(firstMessage.id.peerId)
                                    
                                    return false
                                }
                                
                                for controller in strongSelf.rootController.viewControllers {
                                    if let controller = controller as? ChatController, case .peer(firstMessage.id.peerId) = controller.chatLocation  {
                                        return true
                                    }
                                }
                                
                                strongSelf.notificationController.removeItemsWithGroupingKey(firstMessage.id.peerId)
                                
                                navigateToChatController(navigationController: strongSelf.rootController, account: strongSelf.account, chatLocation: .peer(firstMessage.id.peerId))
                            }
                            return false
                        }, expandAction: { expandData in
                            if let strongSelf = self {
                                let chatController = ChatController(account: strongSelf.account, chatLocation: .peer(firstMessage.id.peerId), mode: .overlay)
                                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(chatController, in: .window(.root), with: ChatControllerOverlayPresentationData(expandData: expandData()))
                            }
                        }))
                    }
                }
            }
        }))
        
        self.termsOfServiceUpdatesDisposable.set((account.stateManager.termsOfServiceUpdate
        |> deliverOnMainQueue).start(next: { [weak self] termsOfServiceUpdate in
            guard let strongSelf = self, strongSelf.currentTermsOfServiceUpdate != termsOfServiceUpdate else {
                return
            }
            
            strongSelf.currentTermsOfServiceUpdate = termsOfServiceUpdate
            if let termsOfServiceUpdate = termsOfServiceUpdate {
                let presentationData = strongSelf.applicationContext.currentPresentationData.with { $0 }
                var acceptImpl: ((String?) -> Void)?
                var declineImpl: (() -> Void)?
                let controller = TermsOfServiceController(theme: TermsOfServiceControllerTheme(presentationTheme: presentationData.theme), strings: presentationData.strings, text: termsOfServiceUpdate.text, entities: termsOfServiceUpdate.entities, ageConfirmation: termsOfServiceUpdate.ageConfirmation, signingUp: false, accept: { proccedBot in
                    acceptImpl?(proccedBot)
                }, decline: {
                    declineImpl?()
                }, openUrl: { url in
                    if let parsedUrl = URL(string: url) {
                        UIApplication.shared.openURL(parsedUrl)
                    }
                })
                
                acceptImpl = { [weak controller] botName in
                    controller?.inProgress = true
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (acceptTermsOfService(account: strongSelf.account, id: termsOfServiceUpdate.id)
                    |> deliverOnMainQueue).start(completed: {
                        controller?.dismiss()
                        if let botName = botName {
                            self?.termsOfServiceProceedToBotDisposable.set((resolvePeerByName(account: account, name: botName, ageLimit: 10) |> take(1) |> deliverOnMainQueue).start(next: { peerId in
                                if let peerId = peerId {
                                    self?.rootController.pushViewController(ChatController(account: account, chatLocation: .peer(peerId), messageId: nil))
                                }
                            }))
                        }
                    })
                }
                
                declineImpl = {
                    guard let strongSelf = self else {
                        return
                    }
                    let _ = (strongSelf.account.postbox.loadedPeerWithId(strongSelf.account.peerId)
                    |> deliverOnMainQueue).start(next: { peer in
                        if let phone = (peer as? TelegramUser)?.phone {
                            UIApplication.shared.openURL(URL(string: "https://telegram.org/deactivate?phone=\(phone)")!)
                        }
                    })
                }
                
                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
            }
        }))
        
        if #available(iOS 10.0, *) {
            let alwaysModal = true
            
            let permissionsPosition = ValuePromise(0, ignoreRepeated: true)
            self.permissionsDisposable.set((combineLatest(requiredPermissions(account: account), permissionUISplitTest(postbox: account.postbox), permissionsPosition.get(), account.postbox.combinedView(keys: [.noticeEntry(ApplicationSpecificNotice.contactsPermissionWarningKey()), .noticeEntry(ApplicationSpecificNotice.notificationsPermissionWarningKey())]))
            |> deliverOnMainQueue).start(next: { [weak self] contactsAndNotifications, splitTest, position, combined in
                guard let strongSelf = self else {
                    return
                }
                
                let contactsTimestamp = (combined.views[.noticeEntry(ApplicationSpecificNotice.contactsPermissionWarningKey())] as? NoticeEntryView)?.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                let notificationsTimestamp = (combined.views[.noticeEntry(ApplicationSpecificNotice.notificationsPermissionWarningKey())] as? NoticeEntryView)?.value.flatMap({ ApplicationSpecificNotice.getTimestampValue($0) })
                if contactsTimestamp == nil, case .requestable = contactsAndNotifications.0.status {
                    ApplicationSpecificNotice.setContactsPermissionWarning(postbox: account.postbox, value: 1)
                }
                if notificationsTimestamp == nil, case .requestable = contactsAndNotifications.1.status {
                    ApplicationSpecificNotice.setNotificationsPermissionWarning(postbox: account.postbox, value: 1)
                }
                
                let config = splitTest.configuration
                var requestedPermissions: [(PermissionState, Bool)] = []
                var i: Int = 0
                for subject in config.order {
                    if i < position {
                        i += 1
                        continue
                    }
                    var modal = false
                    switch subject {
                        case .contacts:
                            if case .modal = config.contacts {
                                modal = true
                            }
                            if case .requestable = contactsAndNotifications.0.status, contactsTimestamp != 0 {
                                requestedPermissions.append((contactsAndNotifications.0, modal || alwaysModal))
                            }
                        case .notifications:
                            if case .modal = config.notifications {
                                modal = true
                            }
                            if case .requestable = contactsAndNotifications.1.status, notificationsTimestamp != 0 {
                                requestedPermissions.append((contactsAndNotifications.1, modal || alwaysModal))
                            }
                        default:
                            break
                    }
                    i += 1
                }
                
                if let (state, modal) = requestedPermissions.first {
                    if modal {
                        var didAppear = false
                        let controller: PermissionController
                        if let currentController = strongSelf.currentPermissionsController {
                            controller = currentController
                            didAppear = true
                        } else {
                            controller = PermissionController(account: account, splitTest: splitTest)
                            strongSelf.currentPermissionsController = controller
                        }
                        
                        controller.setState(state, animated: didAppear)
                        controller.proceed = { resolved in
                            permissionsPosition.set(position + 1)
                            switch state {
                                case .contacts:
                                    ApplicationSpecificNotice.setContactsPermissionWarning(postbox: account.postbox, value: 0)
                                case .notifications:
                                    ApplicationSpecificNotice.setNotificationsPermissionWarning(postbox: account.postbox, value: 0)
                                default:
                                    break
                            }
                        }
                        
                        if !didAppear {
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.15, execute: {
                                (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root), with: ViewControllerPresentationArguments.init(presentationAnimation: .modalSheet))
                            })
                        }
                    } else {
                        switch state {
                            case .contacts:
                                splitTest.addEvent(.ContactsRequest)
                                DeviceAccess.authorizeAccess(to: .contacts, account: account) { result in
                                    if result {
                                        splitTest.addEvent(.ContactsAllowed)
                                    } else {
                                        splitTest.addEvent(.ContactsDenied)
                                    }
                                    permissionsPosition.set(position + 1)
                                    ApplicationSpecificNotice.setContactsPermissionWarning(postbox: account.postbox, value: 0)
                                }
                            case .notifications:
                                splitTest.addEvent(.NotificationsRequest)
                                DeviceAccess.authorizeAccess(to: .notifications, account: account) { result in
                                    if result {
                                        splitTest.addEvent(.NotificationsAllowed)
                                    } else {
                                        splitTest.addEvent(.NotificationsDenied)
                                    }
                                    permissionsPosition.set(position + 1)
                                    ApplicationSpecificNotice.setNotificationsPermissionWarning(postbox: account.postbox, value: 0)
                            }
                            default:
                                break
                        }
                    }
                } else {
                    if let controller = strongSelf.currentPermissionsController {
                        strongSelf.currentPermissionsController = nil
                        controller.dismiss(completion: {
                        })
                    }
                }
            }))
        }
        
        self.displayAlertsDisposable = (account.stateManager.displayAlerts |> deliverOnMainQueue).start(next: { [weak self] alerts in
            if let strongSelf = self{
                for text in alerts {
                    let presentationData = strongSelf.applicationContext.currentPresentationData.with { $0 }
                    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})])
                    (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
                }
            }
        })
        
        self.removeNotificationsDisposable = (account.stateManager.appliedIncomingReadMessages
        |> deliverOnMainQueue).start(next: { [weak self] ids in
            if let strongSelf = self {
                strongSelf.applicationContext.applicationBindings.clearMessageNotifications(ids)
            }
        })
        
        self.callDisposable = (callManager.currentCallSignal
        |> deliverOnMainQueue).start(next: { [weak self] call in
            if let strongSelf = self {
                if call !== strongSelf.callController?.call {
                    strongSelf.callController?.dismiss()
                    strongSelf.callController = nil
                    strongSelf.hasOngoingCall.set(false)
                    
                    if let call = call {
                        let callController = CallController(account: account, call: call)
                        strongSelf.callController = callController
                        strongSelf.rootController.view?.endEditing(true)
                        strongSelf.mainWindow.present(callController, on: .calls)
                        strongSelf.callState.set(call.state
                        |> map(Optional.init))
                        strongSelf.hasOngoingCall.set(true)
                        strongSelf.notificationManager.notificationCall = call
                    } else {
                        strongSelf.callState.set(.single(nil))
                        strongSelf.hasOngoingCall.set(false)
                        strongSelf.notificationManager.notificationCall = nil
                    }
                }
            }
        })
        
        self.callStateDisposable = (self.callState.get()
        |> deliverOnMainQueue).start(next: { [weak self] state in
            if let strongSelf = self {
                let resolvedText: CallStatusText
                if let state = state {
                    switch state {
                        case .connecting, .requesting, .terminating, .ringing, .waiting:
                            resolvedText = .inProgress(nil)
                        case .terminated:
                            resolvedText = .none
                        case let .active(timestamp, _, _):
                            resolvedText = .inProgress(timestamp)
                    }
                } else {
                    resolvedText = .none
                }
                
                if strongSelf.currentCallStatusText != resolvedText {
                    strongSelf.currentCallStatusText = resolvedText
                    
                    var referenceTimestamp: Double?
                    if case let .inProgress(timestamp) = resolvedText, let concreteTimestamp = timestamp {
                        referenceTimestamp = concreteTimestamp
                    }
                    
                    if let _ = referenceTimestamp {
                        if strongSelf.currentCallStatusTextTimer == nil {
                            let timer = SwiftSignalKit.Timer(timeout: 0.5, repeat: true, completion: {
                                if let strongSelf = self {
                                    strongSelf.updateStatusBarText()
                                }
                            }, queue: Queue.mainQueue())
                            strongSelf.currentCallStatusTextTimer = timer
                            timer.start()
                        }
                    } else {
                        strongSelf.currentCallStatusTextTimer?.invalidate()
                        strongSelf.currentCallStatusTextTimer = nil
                    }
                    
                    strongSelf.updateStatusBarText()
                }
            }
        })
        
        self.account.resetStateManagement()
        let contactSynchronizationPreferencesKey = PostboxViewKey.preferences(keys: Set([ApplicationSpecificPreferencesKeys.contactSynchronizationSettings]))
       
        let importableContacts = self.applicationContext.contactDataManager.importable()
        self.account.importableContacts.set(self.account.postbox.combinedView(keys: [contactSynchronizationPreferencesKey])
        |> mapToSignal { preferences -> Signal<[DeviceContactNormalizedPhoneNumber: ImportableDeviceContactData], NoError> in
            let settings: ContactSynchronizationSettings = ((preferences.views[contactSynchronizationPreferencesKey] as? PreferencesView)?.values[ApplicationSpecificPreferencesKeys.contactSynchronizationSettings] as? ContactSynchronizationSettings) ?? .defaultSettings
            if settings.synchronizeDeviceContacts {
                return importableContacts
            } else {
                return .single([:])
            }
        })
        
        let previousTheme = Atomic<PresentationTheme?>(value: nil)
        self.presentationDataDisposable = (applicationContext.presentationData
            |> deliverOnMainQueue).start(next: { [weak self] presentationData in
                if let strongSelf = self {
                    if previousTheme.swap(presentationData.theme) !== presentationData.theme {
                        strongSelf.mainWindow.previewThemeAccentColor = presentationData.theme.rootController.navigationBar.accentTextColor
                        strongSelf.mainWindow.previewThemeDarkBlur = presentationData.theme.chatList.searchBarKeyboardColor == .dark
                        strongSelf.lockedCoveringView.updateTheme(presentationData.theme)
                        strongSelf.rootController.updateTheme(NavigationControllerTheme(presentationTheme: presentationData.theme))
                    }
                }
            })
        
        let showCallsTabSignal = account.postbox.preferencesView(keys: [ApplicationSpecificPreferencesKeys.callListSettings])
            |> map { view -> Bool in
                var value = true
                if let settings = view.values[ApplicationSpecificPreferencesKeys.callListSettings] as? CallListSettings {
                    value = settings.showTab
                }
                return value
            }
        self.showCallsTabDisposable = (showCallsTabSignal |> deliverOnMainQueue).start(next: { [weak self] value in
            if let strongSelf = self {
                if strongSelf.showCallsTab != value {
                    strongSelf.showCallsTab = value
                    strongSelf.rootController.updateRootControllers(showCallsTab: value)
                }
            }
        })
        
        let _ = (watchManagerArguments |> deliverOnMainQueue).start(next: { [weak self] arguments in
            guard let strongSelf = self else {
                return
            }
            
            let watchManager = WatchManager(arguments: arguments)
            strongSelf.applicationContext.watchManager = watchManager
            runningWatchTasksPromise.set(watchManager.runningTasks)
            
            strongSelf.watchNavigateToMessageDisposable.set((strongSelf.applicationContext.applicationBindings.applicationInForeground |> mapToSignal({ applicationInForeground -> Signal<(Bool, MessageId), NoError> in
                return watchManager.navigateToMessageRequested
                |> map { messageId in
                    return (applicationInForeground, messageId)
                }
                |> deliverOnMainQueue
            })).start(next: { [weak self] applicationInForeground, messageId in
                if let strongSelf = self {
                    if applicationInForeground {
                        var chatIsVisible = false
                        if let controller = strongSelf.rootController.viewControllers.last as? ChatController, case .peer(messageId.peerId) = controller.chatLocation  {
                            chatIsVisible = true
                        }
                        
                        let navigateToMessage = {
                            navigateToChatController(navigationController: strongSelf.rootController, account: strongSelf.account, chatLocation: .peer(messageId.peerId), messageId: messageId)
                        }
                        
                        if chatIsVisible {
                            navigateToMessage()
                        } else {
                            let presentationData = strongSelf.applicationContext.currentPresentationData.with { $0 }
                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: presentationData.strings.WatchRemote_AlertTitle, text: presentationData.strings.WatchRemote_AlertText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.WatchRemote_AlertOpen, action:navigateToMessage)])
                            (strongSelf.rootController.viewControllers.last as? ViewController)?.present(controller, in: .window(.root))
                        }
                    } else {
                        strongSelf.notificationManager.presentWatchContinuityNotification(messageId: messageId)
                    }
                }
            }))
        })
    }
    
    private func updateStatusBarText() {
        if case let .inProgress(timestamp) = self.currentCallStatusText {
            let text: String
            let presentationData = self.applicationContext.currentPresentationData.with { $0 }
            if let timestamp = timestamp {
                let duration = Int32(CFAbsoluteTimeGetCurrent() - timestamp)
                let durationString: String
                if duration > 60 * 60 {
                    durationString = String(format: "%02d:%02d:%02d", arguments: [duration / 3600, (duration / 60) % 60, duration % 60])
                } else {
                    durationString = String(format: "%02d:%02d", arguments: [(duration / 60) % 60, duration % 60])
                }
                
                text = presentationData.strings.Call_StatusBar(durationString).0
            } else {
                text = presentationData.strings.Call_StatusBar("").0
            }
            
            self.mainWindow.setForceInCallStatusBar(text)
        } else {
            self.mainWindow.setForceInCallStatusBar(nil)
        }
    }
    
    deinit {
        self.account.postbox.clearCaches()
        self.account.shouldKeepOnlinePresence.set(.single(false))
        self.account.shouldBeServiceTaskMaster.set(.single(.never))
        self.loggedOutDisposable.dispose()
        self.inAppNotificationSettingsDisposable.dispose()
        self.notificationMessagesDisposable.dispose()
        self.termsOfServiceUpdatesDisposable.dispose()
        self.passcodeLockDisposable.dispose()
        self.passcodeStatusDisposable.dispose()
        self.displayAlertsDisposable?.dispose()
        self.removeNotificationsDisposable?.dispose()
        self.callDisposable?.dispose()
        self.callStateDisposable?.dispose()
        self.currentCallStatusTextTimer?.invalidate()
        self.presentationDataDisposable?.dispose()
        self.enablePostboxTransactionsDiposable?.dispose()
        self.termsOfServiceProceedToBotDisposable.dispose()
        self.watchNavigateToMessageDisposable.dispose()
        self.permissionsDisposable.dispose()
    }
    
    func openChatWithPeerId(peerId: PeerId, messageId: MessageId? = nil) {
        var visiblePeerId: PeerId?
        if let controller = self.rootController.topViewController as? ChatController, case let .peer(peerId) = controller.chatLocation {
            visiblePeerId = peerId
        }
        
        if visiblePeerId != peerId || messageId != nil {
            if self.rootController.rootTabController != nil {
                navigateToChatController(navigationController: self.rootController, account: self.account, chatLocation: .peer(peerId), messageId: messageId)
            } else {
                self.scheduledOperChatWithPeerId = peerId
            }
        }
    }
    
    func openUrl(_ url: URL) {
        if self.rootController.rootTabController != nil {
            let presentationData = self.account.telegramApplicationContext.currentPresentationData.with { $0 }
            openExternalUrl(account: self.account, url: url.absoluteString, presentationData: presentationData, applicationContext: self.applicationContext, navigationController: self.rootController, dismissInput: { [weak self] in
                self?.rootController.view.endEditing(true)
            })
        } else {
            self.scheduledOpenExternalUrl = url
        }
    }
    
    func openRootSearch() {
        self.rootController.openChatsSearch()
    }
    
    func openRootCompose() {
        self.rootController.openRootCompose()
    }
    
    func openRootCamera() {
        self.rootController.openRootCamera()
    }
    
    private func updateCoveringViewSnaphot(_ visible: Bool) {
        if visible {
            let scale: CGFloat = 0.5
            let unscaledSize = self.mainWindow.hostView.containerView.frame.size
            let image = generateImage(CGSize(width: floor(unscaledSize.width * scale), height: floor(unscaledSize.height * scale)), rotatedContext: { size, context in
                context.clear(CGRect(origin: CGPoint(), size: size))
                context.scaleBy(x: scale, y: scale)
                UIGraphicsPushContext(context)
                self.mainWindow.hostView.containerView.drawHierarchy(in: CGRect(origin: CGPoint(), size: unscaledSize), afterScreenUpdates: false)
                UIGraphicsPopContext()
            })?.applyScreenshotEffect()
            self.lockedCoveringView.updateSnapshot(image)
        } else {
            self.lockedCoveringView.updateSnapshot(nil)
        }
    }
}
