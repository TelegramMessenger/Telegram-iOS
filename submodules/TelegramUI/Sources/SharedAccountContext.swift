import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import Display
import TelegramPresentationData
import TelegramCallsUI
import TelegramUIPreferences
import AccountContext
import DeviceLocationManager
import LegacyUI
import ChatListUI
import PeersNearbyUI
import PeerInfoUI
import SettingsUI
import UrlHandling
#if ENABLE_WALLET
import WalletUI
import WalletCore
#endif
import LegacyMediaPickerUI
import LocalMediaResources
import OverlayStatusController
import AlertUI
import PresentationDataUtils

private enum CallStatusText: Equatable {
    case none
    case inProgress(Double?)
}

private final class AccountUserInterfaceInUseContext {
    let subscribers = Bag<(Bool) -> Void>()
    let tokens = Bag<Void>()
    
    var isEmpty: Bool {
        return self.tokens.isEmpty && self.subscribers.isEmpty
    }
}

private struct AccountAttributes: Equatable {
    let sortIndex: Int32
    let isTestingEnvironment: Bool
    let backupData: AccountBackupData?
}

private enum AddedAccountResult {
    case upgrading(Float)
    case ready(AccountRecordId, Account?, Int32)
}

private enum AddedAccountsResult {
    case upgrading(Float)
    case ready([(AccountRecordId, Account?, Int32)])
}

private var testHasInstance = false

public final class SharedAccountContextImpl: SharedAccountContext {
    public let mainWindow: Window1?
    public let applicationBindings: TelegramApplicationBindings
    public let basePath: String
    public let accountManager: AccountManager
    public let appLockContext: AppLockContext
    
    private let navigateToChatImpl: (AccountRecordId, PeerId, MessageId?) -> Void
    
    private let apsNotificationToken: Signal<Data?, NoError>
    private let voipNotificationToken: Signal<Data?, NoError>
    
    private var activeAccountsValue: (primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?)?
    private let activeAccountsPromise = Promise<(primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?)>()
    public var activeAccounts: Signal<(primary: Account?, accounts: [(AccountRecordId, Account, Int32)], currentAuth: UnauthorizedAccount?), NoError> {
        return self.activeAccountsPromise.get()
    }
    private let managedAccountDisposables = DisposableDict<AccountRecordId>()
    private let activeAccountsWithInfoPromise = Promise<(primary: AccountRecordId?, accounts: [AccountWithInfo])>()
    public var activeAccountsWithInfo: Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo]), NoError> {
        return self.activeAccountsWithInfoPromise.get()
    }
    
    private var activeUnauthorizedAccountValue: UnauthorizedAccount?
    private let activeUnauthorizedAccountPromise = Promise<UnauthorizedAccount?>()
    public var activeUnauthorizedAccount: Signal<UnauthorizedAccount?, NoError> {
        return self.activeUnauthorizedAccountPromise.get()
    }
    
    private let registeredNotificationTokensDisposable = MetaDisposable()
    
    public let mediaManager: MediaManager
    public let contactDataManager: DeviceContactDataManager?
    public let locationManager: DeviceLocationManager?
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
    
    private var accountUserInterfaceInUseContexts: [AccountRecordId: AccountUserInterfaceInUseContext] = [:]
    
    var switchingData: (settingsController: (SettingsController & ViewController)?, chatListController: ChatListController?, chatListBadge: String?) = (nil, nil, nil)
    
    private let _currentPresentationData: Atomic<PresentationData>
    public var currentPresentationData: Atomic<PresentationData> {
        return self._currentPresentationData
    }
    private let _presentationData = Promise<PresentationData>()
    public var presentationData: Signal<PresentationData, NoError> {
        return self._presentationData.get()
    }
    private let presentationDataDisposable = MetaDisposable()
    
    public let currentInAppNotificationSettings: Atomic<InAppNotificationSettings>
    private var inAppNotificationSettingsDisposable: Disposable?
    
    public let currentAutomaticMediaDownloadSettings: Atomic<MediaAutoDownloadSettings>
    private let _automaticMediaDownloadSettings = Promise<MediaAutoDownloadSettings>()
    public var automaticMediaDownloadSettings: Signal<MediaAutoDownloadSettings, NoError> {
        return self._automaticMediaDownloadSettings.get()
    }
    
    public let currentAutodownloadSettings: Atomic<AutodownloadSettings>
    private let _autodownloadSettings = Promise<AutodownloadSettings>()
    private var currentAutodownloadSettingsDisposable = MetaDisposable()
    
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
    
    private let displayUpgradeProgress: (Float?) -> Void
    
    private var spotlightDataContext: SpotlightDataContext?
    private var widgetDataContext: WidgetDataContext?
    
    public init(mainWindow: Window1?, basePath: String, encryptionParameters: ValueBoxEncryptionParameters, accountManager: AccountManager, appLockContext: AppLockContext, applicationBindings: TelegramApplicationBindings, initialPresentationDataAndSettings: InitialPresentationDataAndSettings, networkArguments: NetworkInitializationArguments, rootPath: String, legacyBasePath: String?, legacyCache: LegacyCache?, apsNotificationToken: Signal<Data?, NoError>, voipNotificationToken: Signal<Data?, NoError>, setNotificationCall: @escaping (PresentationCall?) -> Void, navigateToChat: @escaping (AccountRecordId, PeerId, MessageId?) -> Void, displayUpgradeProgress: @escaping (Float?) -> Void = { _ in }) {
        assert(Queue.mainQueue().isCurrent())
        
        precondition(!testHasInstance)
        testHasInstance = true
        
        self.mainWindow = mainWindow
        self.applicationBindings = applicationBindings
        self.basePath = basePath
        self.accountManager = accountManager
        self.navigateToChatImpl = navigateToChat
        self.displayUpgradeProgress = displayUpgradeProgress
        self.appLockContext = appLockContext
        
        self.accountManager.mediaBox.fetchCachedResourceRepresentation = { (resource, representation) -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return fetchCachedSharedResourceRepresentation(accountManager: accountManager, resource: resource, representation: representation)
        }
        
        self.apsNotificationToken = apsNotificationToken
        self.voipNotificationToken = voipNotificationToken
                
        if applicationBindings.isMainApp {
            self.locationManager = DeviceLocationManager(queue: Queue.mainQueue())
            self.contactDataManager = DeviceContactDataManagerImpl()
        } else {
            self.locationManager = nil
            self.contactDataManager = nil
        }
        
        self._currentPresentationData = Atomic(value: initialPresentationDataAndSettings.presentationData)
        self.currentAutomaticMediaDownloadSettings = Atomic(value: initialPresentationDataAndSettings.automaticMediaDownloadSettings)
        self.currentAutodownloadSettings = Atomic(value: initialPresentationDataAndSettings.autodownloadSettings)
        self.currentMediaInputSettings = Atomic(value: initialPresentationDataAndSettings.mediaInputSettings)
        self.currentInAppNotificationSettings = Atomic(value: initialPresentationDataAndSettings.inAppNotificationSettings)
        
        let presentationData: Signal<PresentationData, NoError> = .single(initialPresentationDataAndSettings.presentationData)
        |> then(
            updatedPresentationData(accountManager: self.accountManager, applicationInForeground: self.applicationBindings.applicationInForeground, systemUserInterfaceStyle: mainWindow?.systemUserInterfaceStyle ?? .single(.light))
        )
        self._presentationData.set(presentationData)
        self._automaticMediaDownloadSettings.set(.single(initialPresentationDataAndSettings.automaticMediaDownloadSettings)
        |> then(accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings])
            |> map { sharedData in
                let autodownloadSettings: AutodownloadSettings = sharedData.entries[SharedDataKeys.autodownloadSettings] as? AutodownloadSettings ?? .defaultSettings
                let automaticDownloadSettings: MediaAutoDownloadSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings] as? MediaAutoDownloadSettings ?? .defaultSettings
                return automaticDownloadSettings.updatedWithAutodownloadSettings(autodownloadSettings)
            }
        ))
        
        self.mediaManager = MediaManagerImpl(accountManager: accountManager, inForeground: applicationBindings.applicationInForeground, presentationData: presentationData)
        
        self._autodownloadSettings.set(.single(initialPresentationDataAndSettings.autodownloadSettings)
        |> then(accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings])
            |> map { sharedData in
                let autodownloadSettings: AutodownloadSettings = sharedData.entries[SharedDataKeys.autodownloadSettings] as? AutodownloadSettings ?? .defaultSettings
                return autodownloadSettings
            }
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
        
        self.currentAutodownloadSettingsDisposable.set(self._autodownloadSettings.get().start(next: { [weak self] next in
            if let strongSelf = self {
                let _ = strongSelf.currentAutodownloadSettings.swap(next)
            }
        }))
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let differenceDisposable = MetaDisposable()
        let _ = (accountManager.accountRecords()
        |> map { view -> (AccountRecordId?, [AccountRecordId: AccountAttributes], (AccountRecordId, Bool)?) in
            print("SharedAccountContextImpl: records appeared in \(CFAbsoluteTimeGetCurrent() - startTime)")
            
            var result: [AccountRecordId: AccountAttributes] = [:]
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
                var backupData: AccountBackupData?
                var sortIndex: Int32 = 0
                for attribute in record.attributes {
                    if let attribute = attribute as? AccountSortOrderAttribute {
                        sortIndex = attribute.order
                    } else if let attribute = attribute as? AccountBackupDataAttribute {
                        backupData = attribute.data
                    }
                }
                result[record.id] = AccountAttributes(sortIndex: sortIndex, isTestingEnvironment: isTestingEnvironment, backupData: backupData)
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
            var addedSignals: [Signal<AddedAccountResult, NoError>] = []
            var addedAuthSignal: Signal<UnauthorizedAccount?, NoError> = .single(nil)
            for (id, attributes) in records {
                if self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == id}) == nil {
                    addedSignals.append(accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: id, encryptionParameters: encryptionParameters, supplementary: !applicationBindings.isMainApp, rootPath: rootPath, beginWithTestingEnvironment: attributes.isTestingEnvironment, backupData: attributes.backupData, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                    |> map { result -> AddedAccountResult in
                        switch result {
                            case let .authorized(account):
                                setupAccount(account, fetchCachedResourceRepresentation: fetchCachedResourceRepresentation, transformOutgoingMessageMedia: transformOutgoingMessageMedia, preFetchedResourcePath: { resource in
                                    return nil
                                })
                                return .ready(id, account, attributes.sortIndex)
                            case let .upgrading(progress):
                                return .upgrading(progress)
                            default:
                                return .ready(id, nil, attributes.sortIndex)
                        }
                    })
                }
            }
            if let authRecord = authRecord, authRecord.0 != self.activeAccountsValue?.currentAuth?.id {
                addedAuthSignal = accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: authRecord.0, encryptionParameters: encryptionParameters, supplementary: !applicationBindings.isMainApp, rootPath: rootPath, beginWithTestingEnvironment: authRecord.1, backupData: nil, auxiliaryMethods: telegramAccountAuxiliaryMethods)
                |> mapToSignal { result -> Signal<UnauthorizedAccount?, NoError> in
                    switch result {
                        case let .unauthorized(account):
                            return .single(account)
                        case .upgrading:
                            return .complete()
                        default:
                            return .single(nil)
                    }
                }
            }
            
            let mappedAddedAccounts = combineLatest(queue: .mainQueue(), addedSignals)
            |> map { results -> AddedAccountsResult in
                var readyAccounts: [(AccountRecordId, Account?, Int32)] = []
                var totalProgress: Float = 0.0
                var hasItemsWithProgress = false
                for result in results {
                    switch result {
                        case let .ready(id, account, sortIndex):
                            readyAccounts.append((id, account, sortIndex))
                            totalProgress += 1.0
                        case let .upgrading(progress):
                            hasItemsWithProgress = true
                            totalProgress += progress
                    }
                }
                if hasItemsWithProgress, !results.isEmpty {
                    return .upgrading(totalProgress / Float(results.count))
                } else {
                    return .ready(readyAccounts)
                }
            }
            
            differenceDisposable.set((combineLatest(queue: .mainQueue(), mappedAddedAccounts, addedAuthSignal)
            |> deliverOnMainQueue).start(next: { mappedAddedAccounts, authAccount in
                print("SharedAccountContextImpl: accounts processed in \(CFAbsoluteTimeGetCurrent() - startTime)")
                
                var addedAccounts: [(AccountRecordId, Account?, Int32)] = []
                switch mappedAddedAccounts {
                    case let .upgrading(progress):
                        self.displayUpgradeProgress(progress)
                        return
                    case let .ready(value):
                        addedAccounts = value
                }
                
                self.displayUpgradeProgress(nil)
                
                var hadUpdates = false
                if self.activeAccountsValue == nil {
                    self.activeAccountsValue = (nil, [], nil)
                    hadUpdates = true
                }
                
                struct AccountPeerKey: Hashable {
                    let peerId: PeerId
                    let isTestingEnvironment: Bool
                }
                
                var existingAccountPeerKeys = Set<AccountPeerKey>()
                for accountRecord in addedAccounts {
                    if let account = accountRecord.1 {
                        if existingAccountPeerKeys.contains(AccountPeerKey(peerId: account.peerId, isTestingEnvironment: account.testingEnvironment)) {
                            let _ = accountManager.transaction({ transaction in
                                transaction.updateRecord(accountRecord.0, { _ in
                                    return nil
                                })
                            }).start()
                        } else {
                            existingAccountPeerKeys.insert(AccountPeerKey(peerId: account.peerId, isTestingEnvironment: account.testingEnvironment))
                            if let index = self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == account.id }) {
                                self.activeAccountsValue?.accounts.remove(at: index)
                                self.managedAccountDisposables.set(nil, forKey: account.id)
                                assertionFailure()
                            }
                            self.activeAccountsValue!.accounts.append((account.id, account, accountRecord.2))
                            self.managedAccountDisposables.set(self.updateAccountBackupData(account: account).start(), forKey: account.id)
                            account.resetStateManagement()
                            hadUpdates = true
                        }
                    } else {
                        let _ = accountManager.transaction({ transaction in
                            transaction.updateRecord(accountRecord.0, { _ in
                                return nil
                            })
                        }).start()
                    }
                }
                var removedIds: [AccountRecordId] = []
                for id in self.activeAccountsValue!.accounts.map({ $0.0 }) {
                    if records[id] == nil {
                        removedIds.append(id)
                    }
                }
                for id in removedIds {
                    hadUpdates = true
                    if let index = self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == id }) {
                        self.activeAccountsValue?.accounts.remove(at: index)
                        self.managedAccountDisposables.set(nil, forKey: id)
                    }
                }
                var primary: Account?
                if let primaryId = primaryId {
                    if let index = self.activeAccountsValue?.accounts.firstIndex(where: { $0.0 == primaryId }) {
                        primary = self.activeAccountsValue?.accounts[index].1
                    }
                }
                if primary == nil && !self.activeAccountsValue!.accounts.isEmpty {
                    primary = self.activeAccountsValue!.accounts.first?.1
                }
                if primary !== self.activeAccountsValue!.primary {
                    hadUpdates = true
                    self.activeAccountsValue!.primary?.postbox.clearCaches()
                    self.activeAccountsValue!.primary?.resetCachedData()
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
                    self.activeAccountsValue!.accounts.sort(by: { $0.2 < $1.2 })
                    self.activeAccountsPromise.set(.single(self.activeAccountsValue!))
                }
                
                if self.activeAccountsValue!.primary == nil && self.activeAccountsValue!.currentAuth == nil {
                    self.beginNewAuth(testingEnvironment: false)
                }
            }))
        })
        
        self.activeAccountsWithInfoPromise.set(self.activeAccounts
        |> mapToSignal { primary, accounts, _ -> Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo]), NoError> in
            return combineLatest(accounts.map { _, account, _ -> Signal<AccountWithInfo?, NoError> in
                let peerViewKey: PostboxViewKey = .peer(peerId: account.peerId, components: [])
                return account.postbox.combinedView(keys: [peerViewKey])
                |> map { view -> AccountWithInfo? in
                    guard let peerView = view.views[peerViewKey] as? PeerView, let peer = peerView.peers[peerView.peerId] else {
                        return nil
                    }
                    return AccountWithInfo(account: account, peer: peer)
                }
                |> distinctUntilChanged
            })
            |> map { accountsWithInfo -> (primary: AccountRecordId?, accounts: [AccountWithInfo]) in
                var accountsWithInfoResult: [AccountWithInfo] = []
                for info in accountsWithInfo {
                    if let info = info {
                        accountsWithInfoResult.append(info)
                    }
                }
                return (primary?.id, accountsWithInfoResult)
            }
        })
        
        if let mainWindow = mainWindow, applicationBindings.isMainApp {
            let callManager = PresentationCallManagerImpl(accountManager: self.accountManager, getDeviceAccessData: {
                return (self.currentPresentationData.with { $0 }, { [weak self] c, a in
                    self?.presentGlobalController(c, a)
                }, {
                    applicationBindings.openSettings()
                })
            }, isMediaPlaying: { [weak self] in
                guard let strongSelf = self else {
                    return false
                }
                var result = false
                let _ = (strongSelf.mediaManager.globalMediaPlayerState
                |> take(1)
                |> deliverOnMainQueue).start(next: { state in
                    if let (_, playbackState, _) = state, case let .state(value) = playbackState, case .playing = value.status.status {
                        result = true
                    }
                })
                return result
            }, resumeMediaPlayback: { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.mediaManager.playlistControl(.playback(.play), type: nil)
            }, audioSession: self.mediaManager.audioSession, activeAccounts: self.activeAccounts |> map { _, accounts, _ in
                return Array(accounts.map({ $0.1 }))
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
                            let callController = CallController(sharedContext: strongSelf, account: call.account, call: call, easyDebugAccess: !GlobalExperimentalSettings.isAppStoreBuild)
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
                            case .active(let timestamp, _, _), .reconnecting(let timestamp, _, _):
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
        
        let _ = managedCleanupAccounts(networkArguments: networkArguments, accountManager: self.accountManager, rootPath: rootPath, auxiliaryMethods: telegramAccountAuxiliaryMethods, encryptionParameters: encryptionParameters).start()
        
        self.updateNotificationTokensRegistration()
        
        if applicationBindings.isMainApp {
            self.widgetDataContext = WidgetDataContext(basePath: self.basePath, activeAccount: self.activeAccounts
            |> map { primary, _, _ in
                return primary
            }, presentationData: self.presentationData)
            
            let enableSpotlight = accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.intentsSettings]))
            |> map { sharedData -> Bool in
                let intentsSettings: IntentsSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.intentsSettings] as? IntentsSettings ?? .defaultSettings
                return intentsSettings.contacts
            }
            |> distinctUntilChanged
            self.spotlightDataContext = SpotlightDataContext(appBasePath: applicationBindings.containerPath, accountManager: accountManager, accounts: combineLatest(enableSpotlight, self.activeAccounts
            |> map { _, accounts, _ in
                return accounts.map { _, account, _ in
                    return account
                }
            }) |> map { enableSpotlight, accounts in
                if enableSpotlight {
                    return accounts
                } else {
                    return []
                }
            })
        }
    }
    
    deinit {
        assertionFailure("SharedAccountContextImpl is not supposed to be deallocated")
        self.registeredNotificationTokensDisposable.dispose()
        self.presentationDataDisposable.dispose()
        self.automaticMediaDownloadSettingsDisposable.dispose()
        self.currentAutodownloadSettingsDisposable.dispose()
        self.inAppNotificationSettingsDisposable?.dispose()
        self.mediaInputSettingsDisposable?.dispose()
        self.callDisposable?.dispose()
        self.callStateDisposable?.dispose()
        self.currentCallStatusTextTimer?.invalidate()
    }
    
    private func updateAccountBackupData(account: Account) -> Signal<Never, NoError> {
        return accountBackupData(postbox: account.postbox)
        |> mapToSignal { backupData -> Signal<Never, NoError> in
            guard let backupData = backupData else {
                return .complete()
            }
            return self.accountManager.transaction { transaction -> Void in
                transaction.updateRecord(account.id, { record in
                    guard let record = record else {
                        return nil
                    }
                    var attributes = record.attributes.filter({ !($0 is AccountBackupDataAttribute) })
                    attributes.append(AccountBackupDataAttribute(data: backupData))
                    return AccountRecord(id: record.id, attributes: attributes, temporarySessionId: record.temporarySessionId)
                })
            }
            |> ignoreValues
        }
    }
    
    public func updateNotificationTokensRegistration() {
        let sandbox: Bool
        #if DEBUG
        sandbox = true
        #else
        sandbox = false
        #endif
        
        let settings = self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
        |> map { sharedData -> (allAccounts: Bool, includeMuted: Bool) in
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings] as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
            return (settings.displayNotificationsFromAllAccounts, false)
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            if lhs.allAccounts != rhs.allAccounts {
                return false
            }
            if lhs.includeMuted != rhs.includeMuted {
                return false
            }
            return true
        })
        
        self.registeredNotificationTokensDisposable.set((combineLatest(queue: .mainQueue(), settings, self.activeAccounts)
        |> mapToSignal { settings, activeAccountsAndInfo -> Signal<Never, NoError> in
            let (primary, activeAccounts, _) = activeAccountsAndInfo
            var applied: [Signal<Never, NoError>] = []
            var activeProductionUserIds = activeAccounts.map({ $0.1 }).filter({ !$0.testingEnvironment }).map({ $0.peerId.id })
            var activeTestingUserIds = activeAccounts.map({ $0.1 }).filter({ $0.testingEnvironment }).map({ $0.peerId.id })
            
            let allProductionUserIds = activeProductionUserIds
            let allTestingUserIds = activeTestingUserIds
            
            if !settings.allAccounts {
                if let primary = primary {
                    if !primary.testingEnvironment {
                        activeProductionUserIds = [primary.peerId.id]
                        activeTestingUserIds = []
                    } else {
                        activeProductionUserIds = []
                        activeTestingUserIds = [primary.peerId.id]
                    }
                } else {
                    activeProductionUserIds = []
                    activeTestingUserIds = []
                }
            }
            
            for (_, account, _) in activeAccounts {
                let appliedAps: Signal<Never, NoError>
                let appliedVoip: Signal<Never, NoError>
                
                if !activeProductionUserIds.contains(account.peerId.id) && !activeTestingUserIds.contains(account.peerId.id) {
                    appliedAps = self.apsNotificationToken
                    |> distinctUntilChanged(isEqual: { $0 == $1 })
                    |> mapToSignal { token -> Signal<Never, NoError> in
                        guard let token = token else {
                            return .complete()
                        }
                        return unregisterNotificationToken(account: account, token: token, type: .aps(encrypt: false), otherAccountUserIds: (account.testingEnvironment ? allTestingUserIds : allProductionUserIds).filter({ $0 != account.peerId.id }))
                    }
                    appliedVoip = self.voipNotificationToken
                    |> distinctUntilChanged(isEqual: { $0 == $1 })
                    |> mapToSignal { token -> Signal<Never, NoError> in
                        guard let token = token else {
                            return .complete()
                        }
                        return unregisterNotificationToken(account: account, token: token, type: .voip, otherAccountUserIds: (account.testingEnvironment ? allTestingUserIds : allProductionUserIds).filter({ $0 != account.peerId.id }))
                    }
                } else {
                    appliedAps = self.apsNotificationToken
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
                        return registerNotificationToken(account: account, token: token, type: .aps(encrypt: encrypt), sandbox: sandbox, otherAccountUserIds: (account.testingEnvironment ? activeTestingUserIds : activeProductionUserIds).filter({ $0 != account.peerId.id }), excludeMutedChats: !settings.includeMuted)
                    }
                    appliedVoip = self.voipNotificationToken
                    |> distinctUntilChanged(isEqual: { $0 == $1 })
                    |> mapToSignal { token -> Signal<Never, NoError> in
                        guard let token = token else {
                            return .complete()
                        }
                        return registerNotificationToken(account: account, token: token, type: .voip, sandbox: sandbox, otherAccountUserIds: (account.testingEnvironment ? activeTestingUserIds : activeProductionUserIds).filter({ $0 != account.peerId.id }), excludeMutedChats: !settings.includeMuted)
                    }
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
    
    public func switchToAccount(id: AccountRecordId, fromSettingsController settingsController: ViewController? = nil, withChatListController chatListController: ViewController? = nil) {
        if self.activeAccountsValue?.primary?.id == id {
            return
        }
        
        assert(Queue.mainQueue().isCurrent())
        var chatsBadge: String?
        if let rootController = self.mainWindow?.viewController as? TelegramRootController {
            if let tabsController = rootController.viewControllers.first as? TabBarController {
                for controller in tabsController.controllers {
                    if let controller = controller as? ChatListController {
                        chatsBadge = controller.tabBarItem.badgeValue
                    }
                }
                
                if let chatListController = chatListController {
                    if let index = tabsController.controllers.firstIndex(where: { $0 is ChatListController }) {
                        var controllers = tabsController.controllers
                        controllers[index] = chatListController
                        tabsController.setControllers(controllers, selectedIndex: index)
                    }
                }
            }
        }
        self.switchingData = (settingsController as? (ViewController & SettingsController), chatListController as? ChatListController, chatsBadge)
        
        let _ = self.accountManager.transaction({ transaction -> Bool in
            if transaction.getCurrent()?.0 != id {
                transaction.setCurrentId(id)
                return true
            } else {
                return false
            }
        }).start(next: { value in
            if !value {
                self.switchingData = (nil, nil, nil)
            }
        })
    }
    
    public func navigateToChat(accountId: AccountRecordId, peerId: PeerId, messageId: MessageId?) {
        self.navigateToChatImpl(accountId, peerId, messageId)
    }
    
    public func messageFromPreloadedChatHistoryViewForLocation(id: MessageId, location: ChatHistoryLocationInput, account: Account, chatLocation: ChatLocation, tagMask: MessageTags?) -> Signal<(MessageIndex?, Bool), NoError> {
        let historyView = preloadedChatHistoryViewForLocation(location, account: account, chatLocation: chatLocation, fixedCombinedReadStates: nil, tagMask: tagMask, additionalData: [])
        return historyView
        |> mapToSignal { historyView -> Signal<(MessageIndex?, Bool), NoError> in
            switch historyView {
            case .Loading:
                return .single((nil, true))
            case let .HistoryView(view, _, _, _, _, _, _):
                for entry in view.entries {
                    if entry.message.id == id {
                        return .single((entry.message.index, false))
                    }
                }
                return .single((nil, false))
            }
        }
        |> take(until: { index in
            return SignalTakeAction(passthrough: true, complete: !index.1)
        })
    }
    
    public func makeOverlayAudioPlayerController(context: AccountContext, peerId: PeerId, type: MediaManagerPlayerType, initialMessageId: MessageId, initialOrder: MusicPlaybackSettingsOrder, parentNavigationController: NavigationController?) -> ViewController & OverlayAudioPlayerController {
        return OverlayAudioPlayerControllerImpl(context: context, peerId: peerId, type: type, initialMessageId: initialMessageId, initialOrder: initialOrder, parentNavigationController: parentNavigationController)
    }
    
    public func makeTempAccountContext(account: Account) -> AccountContext {
        return AccountContextImpl(sharedContext: self, account: account/*, tonContext: nil*/, limitsConfiguration: .defaultValue, contentSettings: .default, temp: true)
    }
    
    public func openChatMessage(_ params: OpenChatMessageParams) -> Bool {
        return openChatMessageImpl(params)
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
            if let navigationController = self.mainWindow?.viewController as? NavigationController {
                navigationController.setForceInCallStatusBar(text)
            }
        } else {
            if let navigationController = self.mainWindow?.viewController as? NavigationController {
                navigationController.setForceInCallStatusBar(nil)
            }
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
    
    public func accountUserInterfaceInUse(_ id: AccountRecordId) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            let context: AccountUserInterfaceInUseContext
            if let current = self.accountUserInterfaceInUseContexts[id] {
                context = current
            } else {
                context = AccountUserInterfaceInUseContext()
                self.accountUserInterfaceInUseContexts[id] = context
            }
            
            subscriber.putNext(!context.tokens.isEmpty)
            let index = context.subscribers.add({ value in
                subscriber.putNext(value)
            })
            
            return ActionDisposable { [weak context] in
                Queue.mainQueue().async {
                    if let current = self.accountUserInterfaceInUseContexts[id], current === context {
                        current.subscribers.remove(index)
                        if current.isEmpty {
                            self.accountUserInterfaceInUseContexts.removeValue(forKey: id)
                        }
                    }
                }
            }
        }
        |> runOn(Queue.mainQueue())
    }
    
    public func setAccountUserInterfaceInUse(_ id: AccountRecordId) -> Disposable {
        assert(Queue.mainQueue().isCurrent())
        let context: AccountUserInterfaceInUseContext
        if let current = self.accountUserInterfaceInUseContexts[id] {
            context = current
        } else {
            context = AccountUserInterfaceInUseContext()
            self.accountUserInterfaceInUseContexts[id] = context
        }
        
        let wasEmpty = context.tokens.isEmpty
        let index = context.tokens.add(Void())
        if wasEmpty {
            for f in context.subscribers.copyItems() {
                f(true)
            }
        }
        
        return ActionDisposable { [weak context] in
            Queue.mainQueue().async {
                if let current = self.accountUserInterfaceInUseContexts[id], current === context {
                    let wasEmpty = current.tokens.isEmpty
                    current.tokens.remove(index)
                    if current.tokens.isEmpty && !wasEmpty {
                        for f in current.subscribers.copyItems() {
                            f(false)
                        }
                    }
                    if current.isEmpty {
                        self.accountUserInterfaceInUseContexts.removeValue(forKey: id)
                    }
                }
            }
        }
    }
    
    public func handleTextLinkAction(context: AccountContext, peerId: PeerId?, navigateDisposable: MetaDisposable, controller: ViewController, action: TextLinkItemActionType, itemLink: TextLinkItem) {
        handleTextLinkActionImpl(context: context, peerId: peerId, navigateDisposable: navigateDisposable, controller: controller, action: action, itemLink: itemLink)
    }
    
    public func makePeerInfoController(context: AccountContext, peer: Peer, mode: PeerInfoControllerMode, avatarInitiallyExpanded: Bool, fromChat: Bool) -> ViewController? {
        let controller = peerInfoControllerImpl(context: context, peer: peer, mode: mode, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: fromChat)
        controller?.navigationPresentation = .modalInLargeLayout
        return controller
    }
    
    public func openExternalUrl(context: AccountContext, urlContext: OpenURLContext, url: String, forceExternal: Bool, presentationData: PresentationData, navigationController: NavigationController?, dismissInput: @escaping () -> Void) {
        openExternalUrlImpl(context: context, urlContext: urlContext, url: url, forceExternal: forceExternal, presentationData: presentationData, navigationController: navigationController, dismissInput: dismissInput)
    }
    
    public func chatAvailableMessageActions(postbox: Postbox, accountPeerId: PeerId, messageIds: Set<MessageId>) -> Signal<ChatAvailableMessageActions, NoError> {
        return chatAvailableMessageActionsImpl(postbox: postbox, accountPeerId: accountPeerId, messageIds: messageIds)
    }
    
    public func navigateToChatController(_ params: NavigateToChatControllerParams) {
        navigateToChatControllerImpl(params)
    }
    
    public func resolveUrl(account: Account, url: String) -> Signal<ResolvedUrl, NoError> {
        return resolveUrlImpl(account: account, url: url)
    }
    
    public func openResolvedUrl(_ resolvedUrl: ResolvedUrl, context: AccountContext, urlContext: OpenURLContext, navigationController: NavigationController?, openPeer: @escaping (PeerId, ChatControllerInteractionNavigateToPeer) -> Void, sendFile: ((FileMediaReference) -> Void)?, sendSticker: ((FileMediaReference, ASDisplayNode, CGRect) -> Bool)?, present: @escaping (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void, contentContext: Any?) {
        openResolvedUrlImpl(resolvedUrl, context: context, urlContext: urlContext, navigationController: navigationController, openPeer: openPeer, sendFile: sendFile, sendSticker: sendSticker, present: present, dismissInput: dismissInput, contentContext: contentContext)
    }
    
    public func makeDeviceContactInfoController(context: AccountContext, subject: DeviceContactInfoSubject, completed: (() -> Void)?, cancelled: (() -> Void)?) -> ViewController {
        return deviceContactInfoController(context: context, subject: subject, completed: completed, cancelled: cancelled)
    }
    
    public func makePeersNearbyController(context: AccountContext) -> ViewController {
        return peersNearbyController(context: context)
    }
    
    public func makeChatController(context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject?, botStart: ChatControllerInitialBotStart?, mode: ChatControllerPresentationMode) -> ChatController {
        return ChatControllerImpl(context: context, chatLocation: chatLocation, subject: subject, botStart: botStart, mode: mode)
    }
    
    public func makePeerSharedMediaController(context: AccountContext, peerId: PeerId) -> ViewController? {
        return peerSharedMediaControllerImpl(context: context, peerId: peerId)
    }
    
    public func makeChatRecentActionsController(context: AccountContext, peer: Peer) -> ViewController {
        return ChatRecentActionsController(context: context, peer: peer)
    }
    
    public func presentContactsWarningSuppression(context: AccountContext, present: (ViewController, Any?) -> Void) {
        presentContactsWarningSuppressionImpl(context: context, present: present)
    }
    
    public func makeContactSelectionController(_ params: ContactSelectionControllerParams) -> ContactSelectionController {
        return ContactSelectionControllerImpl(params)
    }
    
    public func makeContactMultiselectionController(_ params: ContactMultiselectionControllerParams) -> ContactMultiselectionController {
        return ContactMultiselectionControllerImpl(params)
    }
    
    public func makeComposeController(context: AccountContext) -> ViewController {
        return ComposeController(context: context)
    }
    
    public func makeProxySettingsController(context: AccountContext) -> ViewController {
        return proxySettingsController(context: context)
    }
    
    public func makeLocalizationListController(context: AccountContext) -> ViewController {
        return LocalizationListController(context: context)
    }
    
    public func openAddContact(context: AccountContext, firstName: String, lastName: String, phoneNumber: String, label: String, present: @escaping (ViewController, Any?) -> Void, pushController: @escaping (ViewController) -> Void, completed: @escaping () -> Void) {
        openAddContactImpl(context: context, firstName: firstName, lastName: lastName, phoneNumber: phoneNumber, label: label, present: present, pushController: pushController, completed: completed)
    }
    
    public func openAddPersonContact(context: AccountContext, peerId: PeerId, pushController: @escaping (ViewController) -> Void, present: @escaping (ViewController, Any?) -> Void) {
        openAddPersonContactImpl(context: context, peerId: peerId, pushController: pushController, present: present)
    }
    
    public func makeCreateGroupController(context: AccountContext, peerIds: [PeerId], initialTitle: String?, mode: CreateGroupMode, completion: ((PeerId, @escaping () -> Void) -> Void)?) -> ViewController {
        return createGroupControllerImpl(context: context, peerIds: peerIds, initialTitle: initialTitle, mode: mode, completion: completion)
    }
    
    public func makeChatListController(context: AccountContext, groupId: PeerGroupId, controlsHistoryPreload: Bool, hideNetworkActivityStatus: Bool, previewing: Bool, enableDebugActions: Bool) -> ChatListController {
        return ChatListControllerImpl(context: context, groupId: groupId, controlsHistoryPreload: controlsHistoryPreload, hideNetworkActivityStatus: hideNetworkActivityStatus, previewing: previewing, enableDebugActions: enableDebugActions)
    }
    
    public func makePeerSelectionController(_ params: PeerSelectionControllerParams) -> PeerSelectionController {
        return PeerSelectionControllerImpl(params)
    }
    
    public func makeChatMessagePreviewItem(context: AccountContext, message: Message, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder, forcedResourceStatus: FileMediaResourceStatus?, tapMessage: ((Message) -> Void)? = nil, clickThroughMessage: (() -> Void)? = nil) -> ListViewItem {
        let controllerInteraction: ChatControllerInteraction
        if tapMessage != nil || clickThroughMessage != nil {
            controllerInteraction = ChatControllerInteraction(openMessage: { _, _ in
                return false }, openPeer: { _, _, _ in }, openPeerMention: { _ in }, openMessageContextMenu: { _, _, _, _, _ in }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _ in }, tapMessage: { message in
                    tapMessage?(message)
            }, clickThroughMessage: {
                clickThroughMessage?()
            }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _ in }, sendMessage: { _ in }, sendSticker: { _, _, _, _ in return false }, sendGif: { _, _, _ in return false }, requestMessageActionCallback: { _, _, _ in }, requestMessageActionUrlAuth: { _, _, _ in }, activateSwitchInline: { _, _ in }, openUrl: { _, _, _, _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _, _ in  }, openWallpaper: { _ in  }, openTheme: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
            }, presentController: { _, _ in }, navigationController: {
                return nil
            }, chatControllerNode: {
                return nil
            }, reactionContainerNode: {
                return nil
            }, presentGlobalOverlayController: { _, _ in }, callPeer: { _ in }, longTap: { _, _ in }, openCheckoutOrReceipt: { _ in }, openSearch: { }, setupReply: { _ in
            }, canSetupReply: { _ in
                return false
            }, navigateToFirstDateMessage: { _ in
            }, requestRedeliveryOfFailedMessages: { _ in
            }, addContact: { _ in
            }, rateCall: { _, _ in
            }, requestSelectMessagePollOptions: { _, _ in
            }, requestOpenMessagePollResults: { _, _ in
            }, openAppStorePage: {
            }, displayMessageTooltip: { _, _, _, _ in
            }, seekToTimecode: { _, _, _ in
            }, scheduleCurrentMessage: {
            }, sendScheduledMessagesNow: { _ in
            }, editScheduledMessagesTime: { _ in
            }, performTextSelectionAction: { _, _, _ in
            }, updateMessageReaction: { _, _ in
            }, openMessageReactions: { _ in
            }, displaySwipeToReplyHint: {
            }, dismissReplyMarkupMessage: { _ in
            }, openMessagePollResults: { _, _ in
            }, openPollCreation: { _ in
            }, displayPollSolution: { _, _ in
            }, displayPsa: { _, _ in
            }, displayDiceTooltip: { _ in
            }, animateDiceSuccess: {
            }, requestMessageUpdate: { _ in
            }, cancelInteractiveKeyboardGestures: {
            }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
               pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: false))
        } else {
            controllerInteraction = defaultChatControllerInteraction
        }
        
        return ChatMessageItem(presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameOrder, disableAnimations: false, largeEmoji: false, chatBubbleCorners: chatBubbleCorners, animatedEmojiScale: 1.0, isPreview: true), context: context, chatLocation: .peer(message.id.peerId), associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadNetworkType: .cellular, isRecentActions: false, isScheduledMessages: false, contactsPeerIds: Set(), animatedEmojiStickers: [:], forcedResourceStatus: forcedResourceStatus), controllerInteraction: controllerInteraction, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes()), disableDate: true, additionalContent: nil)
    }
    
    public func makeChatMessageDateHeaderItem(context: AccountContext, timestamp: Int32, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder) -> ListViewItemHeader {
        return ChatMessageDateHeader(timestamp: timestamp, scheduled: false, presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameOrder, disableAnimations: false, largeEmoji: false, chatBubbleCorners: chatBubbleCorners, animatedEmojiScale: 1.0, isPreview: true), context: context)
    }
    
    #if ENABLE_WALLET
    public func openWallet(context: AccountContext, walletContext: OpenWalletContext, present: @escaping (ViewController) -> Void) {
        guard let storedContext = context.tonContext else {
            return
        }
        let _ = (combineLatest(queue: .mainQueue(),
            WalletStorageInterfaceImpl(postbox: context.account.postbox).getWalletRecords(),
            storedContext.keychain.encryptionPublicKey(),
            context.account.postbox.preferencesView(keys: [PreferencesKeys.appConfiguration])
        )
        |> deliverOnMainQueue).start(next: { wallets, currentPublicKey, preferences in
            let appConfiguration = preferences.values[PreferencesKeys.appConfiguration] as? AppConfiguration ?? .defaultValue
            let walletConfiguration = WalletConfiguration.with(appConfiguration: appConfiguration)
            guard let config = walletConfiguration.config, let blockchainName = walletConfiguration.blockchainName else {
                return
            }
            let tonContext = storedContext.context(config: config, blockchainName: blockchainName, enableProxy: !walletConfiguration.disableProxy)
            
            if wallets.isEmpty {
                if case .send = walletContext {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                    let controller = textAlertController(context: context, title: presentationData.strings.Conversation_WalletRequiredTitle, text: presentationData.strings.Conversation_WalletRequiredText, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Conversation_WalletRequiredNotNow, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Conversation_WalletRequiredSetup, action: { [weak self] in
                        self?.openWallet(context: context, walletContext: .generic, present: present)
                    })])
                    present(controller)
                } else {
                    if let _ = currentPublicKey {
                        present(WalletSplashScreen(context: WalletContextImpl(context: context, tonContext: tonContext), mode: .intro, walletCreatedPreloadState: nil))
                    } else {
                        present(WalletSplashScreen(context: WalletContextImpl(context: context, tonContext: tonContext), mode: .secureStorageNotAvailable, walletCreatedPreloadState: nil))
                    }
                }
            } else {
                let walletInfo = wallets[0].info
                let exportCompleted = wallets[0].exportCompleted
                if let currentPublicKey = currentPublicKey {
                    if currentPublicKey == walletInfo.encryptedSecret.publicKey {
                        let _ = (walletAddress(publicKey: walletInfo.publicKey, tonInstance: tonContext.instance)
                        |> deliverOnMainQueue).start(next: { address in
                            switch walletContext {
                            case .generic:
                                if exportCompleted {
                                    present(WalletInfoScreen(context: WalletContextImpl(context: context, tonContext: tonContext), walletInfo: walletInfo, address: address, enableDebugActions: !GlobalExperimentalSettings.isAppStoreBuild))
                                } else {
                                    present(WalletSplashScreen(context: WalletContextImpl(context: context, tonContext: tonContext), mode: .created(walletInfo, nil), walletCreatedPreloadState: nil))
                                }
                            case let .send(address, amount, comment):
                                present(walletSendScreen(context: WalletContextImpl(context: context, tonContext: tonContext), randomId: arc4random64(), walletInfo: walletInfo, address: address, amount: amount, comment: comment))
                            }
                            
                        })
                    } else {
                        present(WalletSplashScreen(context: WalletContextImpl(context: context, tonContext: tonContext), mode: .secureStorageReset(.changed), walletCreatedPreloadState: nil))
                    }
                } else {
                    present(WalletSplashScreen(context: WalletContextImpl(context: context, tonContext: tonContext), mode: .secureStorageReset(.notAvailable), walletCreatedPreloadState: nil))
                }
            }
        })
    }
    #endif
    
    public func openImagePicker(context: AccountContext, completion: @escaping (UIImage) -> Void, present: @escaping (ViewController) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = legacyWallpaperPicker(context: context, presentationData: presentationData).start(next: { generator in
            let legacyController = LegacyController(presentation: .navigation, theme: presentationData.theme)
            legacyController.navigationPresentation = .modal
            legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
            
            let controller = generator(legacyController.context)
            legacyController.bind(controller: controller)
            legacyController.deferScreenEdgeGestures = [.top]
            controller.selectionBlock = { [weak legacyController, weak controller] asset, _ in
                if let asset = asset {
                    let _ = (fetchPhotoLibraryImage(localIdentifier: asset.backingAsset.localIdentifier, thumbnail: false)
                    |> deliverOnMainQueue).start(next: { imageAndFlag in
                        if let (image, _) = imageAndFlag {
                            completion(image)
                        }
                    })
                    if let legacyController = legacyController {
                        legacyController.dismiss()
                    }
                }
            }
            controller.dismissalBlock = { [weak legacyController] in
                if let legacyController = legacyController {
                    legacyController.dismiss()
                }
            }
            present(legacyController)
        })
    }
    
    public func makeRecentSessionsController(context: AccountContext, activeSessionsContext: ActiveSessionsContext) -> ViewController & RecentSessionsController {
        return recentSessionsController(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: WebSessionsContext(account: context.account), websitesOnly: false)
    }
}

private let defaultChatControllerInteraction = ChatControllerInteraction.default

private func peerInfoControllerImpl(context: AccountContext, peer: Peer, mode: PeerInfoControllerMode, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool) -> ViewController? {
    if let _ = peer as? TelegramGroup {
        return PeerInfoScreen(context: context, peerId: peer.id, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, nearbyPeer: false, callMessages: [])
    } else if let channel = peer as? TelegramChannel {
        return PeerInfoScreen(context: context, peerId: peer.id, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, nearbyPeer: false, callMessages: [])
    } else if peer is TelegramUser {
        var nearbyPeer = false
        var callMessages: [Message] = []
        var ignoreGroupInCommon: PeerId?
        switch mode {
        case .nearbyPeer:
            nearbyPeer = true
        case let .calls(messages):
            callMessages = messages
        case .generic:
            break
        case let .group(id):
            ignoreGroupInCommon = id
        }
        return PeerInfoScreen(context: context, peerId: peer.id, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, nearbyPeer: nearbyPeer, callMessages: callMessages, ignoreGroupInCommon: ignoreGroupInCommon)
    } else if peer is TelegramSecretChat {
        return PeerInfoScreen(context: context, peerId: peer.id, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, nearbyPeer: false, callMessages: [])
    }
    return nil
}
