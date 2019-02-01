import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit
import Display

private enum CallStatusText: Equatable {
    case none
    case inProgress(Double?)
}

public final class SharedAccountContext {
    private let mainWindow: Window1?
    public let applicationBindings: TelegramApplicationBindings
    public let accountManager: AccountManager
    
    private let apsNotificationToken: Signal<Data?, NoError>
    private let voipNotificationToken: Signal<Data?, NoError>
    
    private var activeAccountsValue: (primary: Account?, accounts: [AccountRecordId: Account], currentAuth: UnauthorizedAccount?)?
    private let activeAccountsPromise = Promise<(primary: Account?, accounts: [AccountRecordId: Account], currentAuth: UnauthorizedAccount?)>()
    public var activeAccounts: Signal<(primary: Account?, accounts: [AccountRecordId: Account], currentAuth: UnauthorizedAccount?), NoError> {
        return self.activeAccountsPromise.get()
    }
    
    private var activeUnauthorizedAccountValue: UnauthorizedAccount?
    private let activeUnauthorizedAccountPromise = Promise<UnauthorizedAccount?>()
    public var activeUnauthorizedAccount: Signal<UnauthorizedAccount?, NoError> {
        return self.activeUnauthorizedAccountPromise.get()
    }
    
    private let registeredNotificationTokensDisposable = MetaDisposable()
    
    public let mediaManager: MediaManager
    public let contactDataManager: DeviceContactDataManager?
    let locationManager: DeviceLocationManager?
    public var callManager: PresentationCallManager?
    
    private var callDisposable: Disposable?
    private var callStateDisposable: Disposable?
    private var currentCallStatusText: CallStatusText = .none
    private var currentCallStatusTextTimer: SwiftSignalKit.Timer?
    
    private var callController: CallController?
    public let hasOngoingCall = ValuePromise<Bool>(false)
    private let callState = Promise<PresentationCallState?>(nil)
    
    private var immediateHasOngoingCallValue = Atomic<Bool>(value: false)
    public var immediateHasOngoingCall: Bool {
        return self.immediateHasOngoingCallValue.with { $0 }
    }
    private var hasOngoingCallDisposable: Disposable?
    
    var switchingSettingsController: (SettingsController & ViewController)?
    
    public let currentPresentationData: Atomic<PresentationData>
    private let _presentationData = Promise<PresentationData>()
    public var presentationData: Signal<PresentationData, NoError> {
        return self._presentationData.get()
    }
    private let presentationDataDisposable = MetaDisposable()
    
    public let currentInAppNotificationSettings: Atomic<InAppNotificationSettings>
    private var inAppNotificationSettingsDisposable: Disposable?
    
    public let currentAutomaticMediaDownloadSettings: Atomic<AutomaticMediaDownloadSettings>
    private let _automaticMediaDownloadSettings = Promise<AutomaticMediaDownloadSettings>()
    public var automaticMediaDownloadSettings: Signal<AutomaticMediaDownloadSettings, NoError> {
        return self._automaticMediaDownloadSettings.get()
    }
    
    public let currentMediaInputSettings: Atomic<MediaInputSettings>
    private var mediaInputSettingsDisposable: Disposable?
    
    private let automaticMediaDownloadSettingsDisposable = MetaDisposable()
    
    private var immediateExperimentalUISettingsValue = Atomic<ExperimentalUISettings>(value: ExperimentalUISettings.defaultSettings)
    public var immediateExperimentalUISettings: ExperimentalUISettings {
        return self.immediateExperimentalUISettingsValue.with { $0 }
    }
    private var experimentalUISettingsDisposable: Disposable?
    
    public var presentGlobalController: (ViewController, Any?) -> Void = { _, _ in }
    public var presentCrossfadeController: () -> Void = {}
    
    public init(mainWindow: Window1?, accountManager: AccountManager, applicationBindings: TelegramApplicationBindings, initialPresentationDataAndSettings: InitialPresentationDataAndSettings, networkArguments: NetworkInitializationArguments, rootPath: String, apsNotificationToken: Signal<Data?, NoError>, voipNotificationToken: Signal<Data?, NoError>, setNotificationCall: @escaping (PresentationCall?) -> Void) {
        assert(Queue.mainQueue().isCurrent())
        self.mainWindow = mainWindow
        self.applicationBindings = applicationBindings
        self.accountManager = accountManager
        
        self.apsNotificationToken = apsNotificationToken
        self.voipNotificationToken = voipNotificationToken
        
        self.mediaManager = MediaManager(accountManager: accountManager, inForeground: applicationBindings.applicationInForeground)
        
        if applicationBindings.isMainApp {
            self.locationManager = DeviceLocationManager(queue: Queue.mainQueue())
            self.contactDataManager = DeviceContactDataManager()
        } else {
            self.locationManager = nil
            self.contactDataManager = nil
        }
        
        self.currentPresentationData = Atomic(value: initialPresentationDataAndSettings.presentationData)
        self.currentAutomaticMediaDownloadSettings = Atomic(value: initialPresentationDataAndSettings.automaticMediaDownloadSettings)
        self.currentMediaInputSettings = Atomic(value: initialPresentationDataAndSettings.mediaInputSettings)
        self.currentInAppNotificationSettings = Atomic(value: initialPresentationDataAndSettings.inAppNotificationSettings)
        
        self._presentationData.set(.single(initialPresentationDataAndSettings.presentationData)
        |> then(
            updatedPresentationData(accountManager: self.accountManager, applicationBindings: self.applicationBindings)
        ))
        self._automaticMediaDownloadSettings.set(.single(initialPresentationDataAndSettings.automaticMediaDownloadSettings)
        |> then(
            updatedAutomaticMediaDownloadSettings(accountManager: self.accountManager)
        ))
        
        self.presentationDataDisposable.set((self.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] next in
            if let strongSelf = self {
                var stringsUpdated = false
                var themeUpdated = false
                var themeNameUpdated = false
                let _ = strongSelf.currentPresentationData.modify { current in
                    if next.strings !== current.strings {
                        stringsUpdated = true
                    }
                    if next.theme !== current.theme {
                        themeUpdated = true
                    }
                    if next.theme.name != current.theme.name {
                        themeNameUpdated = true
                    }
                    return next
                }
                if stringsUpdated {
                    updateLegacyLocalization(strings: next.strings)
                }
                if themeUpdated {
                    updateLegacyTheme()
                }
                if themeNameUpdated {
                    strongSelf.presentCrossfadeController()
                }
            }
        }))
        
        self.inAppNotificationSettingsDisposable = (self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings {
                    let _ = strongSelf.currentInAppNotificationSettings.swap(settings)
                }
            }
        })
        
        self.mediaInputSettingsDisposable = (self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.mediaInputSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.mediaInputSettings] as? MediaInputSettings {
                    let _ = strongSelf.currentMediaInputSettings.swap(settings)
                }
            }
        })
        
        let immediateExperimentalUISettingsValue = self.immediateExperimentalUISettingsValue
        let _ = immediateExperimentalUISettingsValue.swap(initialPresentationDataAndSettings.experimentalUISettings)
        self.experimentalUISettingsDisposable = (self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.experimentalUISettings])
        |> deliverOnMainQueue).start(next: { sharedData in
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings] as? ExperimentalUISettings {
                let _ = immediateExperimentalUISettingsValue.swap(settings)
            }
        })
        
        let _ = self.contactDataManager?.personNameDisplayOrder().start(next: { order in
            let _ = updateContactSettingsInteractively(accountManager: accountManager, { settings in
                var settings = settings
                settings.nameDisplayOrder = order
                return settings
            }).start()
        })
        
        self.automaticMediaDownloadSettingsDisposable.set(self._automaticMediaDownloadSettings.get().start(next: { [weak self] next in
            if let strongSelf = self {
                let _ = strongSelf.currentAutomaticMediaDownloadSettings.swap(next)
            }
        }))
        
        let differenceDisposable = MetaDisposable()
        let _ = (accountManager.accountRecords()
        |> map { view -> (AccountRecordId?, [AccountRecordId: Bool], (AccountRecordId, Bool)?) in
            var result: [AccountRecordId: Bool] = [:]
            for record in view.records {
                let isLoggedOut = record.attributes.contains(where: { attribute in
                    return attribute is LoggedOutAccountAttribute
                })
                if isLoggedOut {
                    continue
                }
                let isTestingEnvironment = record.attributes.contains(where: { attribute in
                    if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
                        return true
                    } else {
                        return false
                    }
                })
                result[record.id] = isTestingEnvironment
            }
            let authRecord: (AccountRecordId, Bool)? = view.currentAuthAccount.flatMap({ authAccount in
                let isTestingEnvironment = authAccount.attributes.contains(where: { attribute in
                    if let attribute = attribute as? AccountEnvironmentAttribute, case .test = attribute.environment {
                        return true
                    } else {
                        return false
                    }
                })
                return (authAccount.id, isTestingEnvironment)
            })
            return (view.currentRecord?.id, result, authRecord)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.0 != rhs.0 {
                return false
            }
            if lhs.1 != rhs.1 {
                return false
            }
            if lhs.2?.0 != rhs.2?.0 {
                return false
            }
            if lhs.2?.1 != rhs.2?.1 {
                return false
            }
            return true
        })
        |> deliverOnMainQueue).start(next: { primaryId, records, authRecord in
            var addedSignals: [Signal<Account?, NoError>] = []
            var addedAuthSignal: Signal<UnauthorizedAccount?, NoError> = .single(nil)
            for (id, isTestingEnvironment) in records {
                if self.activeAccountsValue?.accounts[id] == nil {
                    addedSignals.append(accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: id, supplementary: false, rootPath: rootPath, beginWithTestingEnvironment: isTestingEnvironment, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                    |> map { result -> Account? in
                        switch result {
                            case let .authorized(account):
                                return account
                            default:
                                return nil
                        }
                    })
                }
            }
            if let authRecord = authRecord, authRecord.0 != self.activeAccountsValue?.currentAuth?.id {
                addedAuthSignal = accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: authRecord.0, supplementary: false, rootPath: rootPath, beginWithTestingEnvironment: authRecord.1, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                |> map { result -> UnauthorizedAccount? in
                    switch result {
                        case let .unauthorized(account):
                            return account
                        default:
                            return nil
                    }
                }
            }
            differenceDisposable.set((combineLatest(combineLatest(addedSignals), addedAuthSignal)
            |> deliverOnMainQueue).start(next: { accounts, authAccount in
                var hadUpdates = false
                if self.activeAccountsValue == nil {
                    self.activeAccountsValue = (nil, [:], nil)
                    hadUpdates = true
                }
                for account in accounts {
                    if let account = account {
                        self.activeAccountsValue!.accounts[account.id] = account
                        hadUpdates = true
                    }
                }
                var removedIds: [AccountRecordId] = []
                for id in self.activeAccountsValue!.accounts.keys {
                    if records[id] == nil {
                        removedIds.append(id)
                    }
                }
                for id in removedIds {
                    hadUpdates = true
                    self.activeAccountsValue!.accounts.removeValue(forKey: id)
                }
                var primary: Account?
                if let primaryId = primaryId {
                    primary = self.activeAccountsValue!.accounts[primaryId]
                } else if !self.activeAccountsValue!.accounts.isEmpty {
                    primary = self.activeAccountsValue!.accounts.sorted(by: { lhs, rhs in lhs.key < rhs.key }).first?.1
                }
                if primary !== self.activeAccountsValue!.primary {
                    hadUpdates = true
                    self.activeAccountsValue!.primary?.postbox.clearCaches()
                    self.activeAccountsValue!.primary = primary
                }
                if self.activeAccountsValue!.currentAuth?.id != authRecord?.0 {
                    hadUpdates = true
                    self.activeAccountsValue!.currentAuth?.postbox.clearCaches()
                    self.activeAccountsValue!.currentAuth = nil
                }
                if let authAccount = authAccount {
                    hadUpdates = true
                    self.activeAccountsValue!.currentAuth = authAccount
                }
                if hadUpdates {
                    self.activeAccountsPromise.set(.single(self.activeAccountsValue!))
                }
                
                if self.activeAccountsValue!.primary == nil && self.activeAccountsValue!.currentAuth == nil {
                    self.beginNewAuth(testingEnvironment: false)
                }
            }))
        })
        
        if let mainWindow = mainWindow, applicationBindings.isMainApp {
            let callManager = PresentationCallManager(accountManager: self.accountManager, getDeviceAccessData: {
                return (self.currentPresentationData.with { $0 }, { [weak self] c, a in
                    self?.presentGlobalController(c, a)
                    }, {
                        applicationBindings.openSettings()
                })
            }, audioSession: self.mediaManager.audioSession, activeAccounts: self.activeAccounts |> map { _, accounts, _ in
                return Array(accounts.values)
            })
            self.callManager = callManager
            
            self.callDisposable = (callManager.currentCallSignal
            |> deliverOnMainQueue).start(next: { [weak self] call in
                if let strongSelf = self {
                    if call !== strongSelf.callController?.call {
                        strongSelf.callController?.dismiss()
                        strongSelf.callController = nil
                        strongSelf.hasOngoingCall.set(false)
                        
                        if let call = call {
                            mainWindow.hostView.containerView.endEditing(true)
                            let callController = CallController(sharedContext: strongSelf, account: call.account, call: call)
                            strongSelf.callController = callController
                            strongSelf.mainWindow?.present(callController, on: .calls)
                            strongSelf.callState.set(call.state
                            |> map(Optional.init))
                            strongSelf.hasOngoingCall.set(true)
                            setNotificationCall(call)
                        } else {
                            strongSelf.callState.set(.single(nil))
                            strongSelf.hasOngoingCall.set(false)
                            setNotificationCall(nil)
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
            
            mainWindow.inCallNavigate = { [weak self] in
                if let strongSelf = self, let callController = strongSelf.callController {
                    if callController.isNodeLoaded && callController.view.superview == nil {
                        mainWindow.hostView.containerView.endEditing(true)
                        mainWindow.present(callController, on: .calls)
                    }
                }
            }
        } else {
            self.callManager = nil
        }
        
        let immediateHasOngoingCallValue = self.immediateHasOngoingCallValue
        self.hasOngoingCallDisposable = self.hasOngoingCall.get().start(next: { value in
            let _ = immediateHasOngoingCallValue.swap(value)
        })
        
        let _ = managedCleanupAccounts(networkArguments: networkArguments, accountManager: self.accountManager, rootPath: rootPath, auxiliaryMethods: telegramAccountAuxiliaryMethods).start()
        
        self.updateNotificationTokensRegistration()
    }
    
    deinit {
        assertionFailure("SharedAccountContext is not supposed to be deallocated")
        self.registeredNotificationTokensDisposable.dispose()
        self.presentationDataDisposable.dispose()
        self.automaticMediaDownloadSettingsDisposable.dispose()
        self.inAppNotificationSettingsDisposable?.dispose()
        self.mediaInputSettingsDisposable?.dispose()
        self.callDisposable?.dispose()
        self.callStateDisposable?.dispose()
        self.currentCallStatusTextTimer?.invalidate()
    }
    
    public func updateNotificationTokensRegistration() {
        let sandbox: Bool
        #if DEBUG
        sandbox = true
        #else
        sandbox = false
        #endif
        
        self.registeredNotificationTokensDisposable.set((self.activeAccounts
        |> mapToSignal { _, activeAccounts, _ -> Signal<Never, NoError> in
            var applied: [Signal<Never, NoError>] = []
            let activeProductionUserIds = activeAccounts.values.filter({ !$0.testingEnvironment }).map({ $0.peerId.id })
            let activeTestingUserIds = activeAccounts.values.filter({ $0.testingEnvironment }).map({ $0.peerId.id })
            for (_, account) in activeAccounts {
                let appliedAps = self.apsNotificationToken
                |> distinctUntilChanged(isEqual: { $0 == $1 })
                |> mapToSignal { token -> Signal<Never, NoError> in
                    guard let token = token else {
                        return .complete()
                    }
                    let encrypt: Bool
                    if #available(iOS 10.0, *) {
                        encrypt = true
                    } else {
                        encrypt = false
                    }
                    return registerNotificationToken(account: account, token: token, type: .aps(encrypt: encrypt), sandbox: sandbox, otherAccountUserIds: (account.testingEnvironment ? activeTestingUserIds : activeProductionUserIds).filter({ $0 != account.peerId.id }))
                }
                let appliedVoip = self.voipNotificationToken
                |> distinctUntilChanged(isEqual: { $0 == $1 })
                |> mapToSignal { token -> Signal<Never, NoError> in
                    guard let token = token else {
                        return .complete()
                    }
                    return registerNotificationToken(account: account, token: token, type: .voip, sandbox: sandbox, otherAccountUserIds: (account.testingEnvironment ? activeTestingUserIds : activeProductionUserIds).filter({ $0 != account.peerId.id }))
                }
                
                applied.append(appliedAps)
                applied.append(appliedVoip)
            }
            return combineLatest(applied)
            |> ignoreValues
        }).start())
    }
    
    public func beginNewAuth(testingEnvironment: Bool) {
        let _ = self.accountManager.transaction({ transaction -> Void in
            let _ = transaction.createAuth([AccountEnvironmentAttribute(environment: testingEnvironment ? .test : .production)])
        }).start()
    }
    
    public func switchToAccount(id: AccountRecordId, fromSettingsController settingsController: (SettingsController & ViewController)? = nil) {
        assert(Queue.mainQueue().isCurrent())
        self.switchingSettingsController = settingsController
        let _ = self.accountManager.transaction({ transaction -> Bool in
            if transaction.getCurrent()?.0 != id {
                transaction.setCurrentId(id)
                return true
            } else {
                return false
            }
        }).start(next: { value in
            if !value {
                self.switchingSettingsController = nil
            }
        })
    }
    
    private func updateStatusBarText() {
        if case let .inProgress(timestamp) = self.currentCallStatusText {
            let text: String
            let presentationData = self.currentPresentationData.with { $0 }
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
            
            self.mainWindow?.setForceInCallStatusBar(text)
        } else {
            self.mainWindow?.setForceInCallStatusBar(nil)
        }
    }
    
    public func navigateToCurrentCall() {
        if let mainWindow = self.mainWindow, let callController = self.callController {
            if callController.isNodeLoaded && callController.view.superview == nil {
                mainWindow.hostView.containerView.endEditing(true)
                mainWindow.present(callController, on: .calls)
            }
        }
    }
}
