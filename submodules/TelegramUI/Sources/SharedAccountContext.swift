import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import TelegramCore
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
import LegacyMediaPickerUI
import LocalMediaResources
import OverlayStatusController
import AlertUI
import PresentationDataUtils
import LocationUI
import AppLock
import WallpaperBackgroundNode
import InAppPurchaseManager
import PremiumUI
import StickerPackPreviewUI
import ChatControllerInteraction
import ChatPresentationInterfaceState
import StorageUsageScreen
import DebugSettingsUI
import MediaPickerUI
import Photos
import TextFormat
import ChatTextLinkEditUI
import AttachmentTextInputPanelNode
import ChatEntityKeyboardInputNode
import HashtagSearchUI
import PeerInfoStoryGridScreen
import TelegramAccountAuxiliaryMethods
import PeerSelectionController
import LegacyMessageInputPanel
import StatisticsUI
import ChatHistoryEntry
import ChatMessageItem
import ChatMessageItemImpl
import ChatRecentActionsController
import PeerInfoScreen
import ChatQrCodeScreen
import UndoUI
import ChatMessageNotificationItem
import ChatbotSetupScreen
import BusinessLocationSetupScreen
import BusinessHoursSetupScreen
import AutomaticBusinessMessageSetupScreen
import CollectibleItemInfoScreen
import StickerPickerScreen
import MediaEditor
import MediaEditorScreen
import BusinessIntroSetupScreen
import TelegramNotices
import BotSettingsScreen
import CameraScreen
import BirthdayPickerScreen
import StarsTransactionsScreen
import StarsPurchaseScreen
import StarsTransferScreen
import StarsTransactionScreen
import StarsWithdrawalScreen
import MiniAppListScreen
import GiftOptionsScreen
import GiftViewScreen
import StarsIntroScreen
import ContentReportScreen
import AffiliateProgramSetupScreen
import GalleryUI

private final class AccountUserInterfaceInUseContext {
    let subscribers = Bag<(Bool) -> Void>()
    let tokens = Bag<Void>()
    
    var isEmpty: Bool {
        return self.tokens.isEmpty && self.subscribers.isEmpty
    }
}

typealias AccountInitialData = (limitsConfiguration: LimitsConfiguration?, contentSettings: ContentSettings?, appConfiguration: AppConfiguration?, availableReplyColors: EngineAvailableColorOptions, availableProfileColors: EngineAvailableColorOptions)

private struct AccountAttributes: Equatable {
    let sortIndex: Int32
    let isTestingEnvironment: Bool
    let backupData: AccountBackupData?
    let isSupportUser: Bool
}

private enum AddedAccountResult {
    case upgrading(Float)
    case ready(AccountRecordId, Account?, Int32, AccountInitialData)
}

private enum AddedAccountsResult {
    case upgrading(Float)
    case ready([(AccountRecordId, Account?, Int32, AccountInitialData)])
}

private var testHasInstance = false

public final class SharedAccountContextImpl: SharedAccountContext {
    public let mainWindow: Window1?
    public let applicationBindings: TelegramApplicationBindings
    public let sharedContainerPath: String
    public let basePath: String
    public let networkArguments: NetworkInitializationArguments
    public let accountManager: AccountManager<TelegramAccountManagerTypes>
    public let appLockContext: AppLockContext
    public var notificationController: NotificationContainerController? {
        didSet {
            if self.notificationController !== oldValue {
                if let oldValue {
                    oldValue.setBlocking(nil)
                }
            }
        }
    }
    
    private let navigateToChatImpl: (AccountRecordId, PeerId, MessageId?) -> Void
    
    private let apsNotificationToken: Signal<Data?, NoError>
    private let voipNotificationToken: Signal<Data?, NoError>
    
    public let firebaseSecretStream: Signal<[String: String], NoError>
    
    private let authorizationPushConfigurationValue = Promise<AuthorizationCodePushNotificationConfiguration?>(nil)
    public var authorizationPushConfiguration: Signal<AuthorizationCodePushNotificationConfiguration?, NoError> {
        return self.authorizationPushConfigurationValue.get()
    }
    
    private var activeAccountsValue: (primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?)?
    private let activeAccountsPromise = Promise<(primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?)>()
    public var activeAccountContexts: Signal<(primary: AccountContext?, accounts: [(AccountRecordId, AccountContext, Int32)], currentAuth: UnauthorizedAccount?), NoError> {
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
    let hasInAppPurchases: Bool
    
    private var callDisposable: Disposable?
    private var callStateDisposable: Disposable?
    
    private(set) var currentCallStatusBarNode: CallStatusBarNodeImpl?
    
    private var groupCallDisposable: Disposable?
    
    private var callController: CallController?
    private var call: PresentationCall?
    public let hasOngoingCall = ValuePromise<Bool>(false)
    private let callState = Promise<PresentationCallState?>(nil)
    private var awaitingCallConnectionDisposable: Disposable?
    private var callPeerDisposable: Disposable?
    
    private var groupCallController: VoiceChatController?
    public var currentGroupCallController: ViewController? {
        return self.groupCallController
    }
    private let hasGroupCallOnScreenPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    public var hasGroupCallOnScreen: Signal<Bool, NoError> {
        return self.hasGroupCallOnScreenPromise.get()
    }
    
    private var immediateHasOngoingCallValue = Atomic<Bool>(value: false)
    public var immediateHasOngoingCall: Bool {
        return self.immediateHasOngoingCallValue.with { $0 }
    }
    private var hasOngoingCallDisposable: Disposable?
    
    public let enablePreloads = Promise<Bool>()
    public let hasPreloadBlockingContent = Promise<Bool>(false)
    public let deviceContactPhoneNumbers = Promise<Set<String>>(Set())
    
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
    
    public var currentAutomaticMediaDownloadSettings: MediaAutoDownloadSettings
    private let _automaticMediaDownloadSettings = Promise<MediaAutoDownloadSettings>()
    public var automaticMediaDownloadSettings: Signal<MediaAutoDownloadSettings, NoError> {
        return self._automaticMediaDownloadSettings.get()
    }
    
    public private(set) var energyUsageSettings: EnergyUsageSettings
    
    public let currentAutodownloadSettings: Atomic<AutodownloadSettings>
    private let _autodownloadSettings = Promise<AutodownloadSettings>()
    private var currentAutodownloadSettingsDisposable = MetaDisposable()
    
    public let currentMediaInputSettings: Atomic<MediaInputSettings>
    private var mediaInputSettingsDisposable: Disposable?
    
    public let currentMediaDisplaySettings: Atomic<MediaDisplaySettings>
    private var mediaDisplaySettingsDisposable: Disposable?
    
    public let currentStickerSettings: Atomic<StickerSettings>
    private var stickerSettingsDisposable: Disposable?
    
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
    
    private weak var appDelegate: AppDelegate?
    
    private var invalidatedApsToken: Data?
    
    private let energyUsageAutomaticDisposable = MetaDisposable()
    
    init(mainWindow: Window1?, sharedContainerPath: String, basePath: String, encryptionParameters: ValueBoxEncryptionParameters, accountManager: AccountManager<TelegramAccountManagerTypes>, appLockContext: AppLockContext, notificationController: NotificationContainerController?, applicationBindings: TelegramApplicationBindings, initialPresentationDataAndSettings: InitialPresentationDataAndSettings, networkArguments: NetworkInitializationArguments, hasInAppPurchases: Bool, rootPath: String, legacyBasePath: String?, apsNotificationToken: Signal<Data?, NoError>, voipNotificationToken: Signal<Data?, NoError>, firebaseSecretStream: Signal<[String: String], NoError>, setNotificationCall: @escaping (PresentationCall?) -> Void, navigateToChat: @escaping (AccountRecordId, PeerId, MessageId?) -> Void, displayUpgradeProgress: @escaping (Float?) -> Void = { _ in }, appDelegate: AppDelegate?) {
        assert(Queue.mainQueue().isCurrent())
        
        precondition(!testHasInstance)
        testHasInstance = true
        
        self.appDelegate = appDelegate
        self.mainWindow = mainWindow
        self.applicationBindings = applicationBindings
        self.sharedContainerPath = sharedContainerPath
        self.basePath = basePath
        self.networkArguments = networkArguments
        self.accountManager = accountManager
        self.navigateToChatImpl = navigateToChat
        self.displayUpgradeProgress = displayUpgradeProgress
        self.appLockContext = appLockContext
        self.notificationController = notificationController
        self.hasInAppPurchases = hasInAppPurchases
        
        self.accountManager.mediaBox.fetchCachedResourceRepresentation = { (resource, representation) -> Signal<CachedMediaResourceRepresentationResult, NoError> in
            return fetchCachedSharedResourceRepresentation(accountManager: accountManager, resource: resource, representation: representation)
        }
        
        self.apsNotificationToken = apsNotificationToken
        self.voipNotificationToken = voipNotificationToken
        
        self.firebaseSecretStream = firebaseSecretStream
        
        self.authorizationPushConfigurationValue.set(apsNotificationToken |> map { data -> AuthorizationCodePushNotificationConfiguration? in
            guard let data else {
                return nil
            }
            let sandbox: Bool
            #if DEBUG
            sandbox = true
            #else
            sandbox = false
            #endif
            return AuthorizationCodePushNotificationConfiguration(
                token: hexString(data),
                isSandbox: sandbox
            )
        })
                
        if applicationBindings.isMainApp {
            self.locationManager = DeviceLocationManager(queue: Queue.mainQueue())
            self.contactDataManager = DeviceContactDataManagerImpl()
        } else {
            self.locationManager = nil
            self.contactDataManager = nil
        }
        
        self._currentPresentationData = Atomic(value: initialPresentationDataAndSettings.presentationData)
        self.currentAutomaticMediaDownloadSettings = initialPresentationDataAndSettings.automaticMediaDownloadSettings
        self.currentAutodownloadSettings = Atomic(value: initialPresentationDataAndSettings.autodownloadSettings)
        self.currentMediaInputSettings = Atomic(value: initialPresentationDataAndSettings.mediaInputSettings)
        self.currentMediaDisplaySettings = Atomic(value: initialPresentationDataAndSettings.mediaDisplaySettings)
        self.currentStickerSettings = Atomic(value: initialPresentationDataAndSettings.stickerSettings)
        self.currentInAppNotificationSettings = Atomic(value: initialPresentationDataAndSettings.inAppNotificationSettings)
        
        if automaticEnergyUsageShouldBeOnNow(settings: self.currentAutomaticMediaDownloadSettings) {
            self.energyUsageSettings = EnergyUsageSettings.powerSavingDefault
        } else {
            self.energyUsageSettings = self.currentAutomaticMediaDownloadSettings.energyUsageSettings
        }
        
        let presentationData: Signal<PresentationData, NoError> = .single(initialPresentationDataAndSettings.presentationData)
        |> then(
            updatedPresentationData(accountManager: self.accountManager, applicationInForeground: self.applicationBindings.applicationInForeground, systemUserInterfaceStyle: mainWindow?.systemUserInterfaceStyle ?? .single(.light))
        )
        self._presentationData.set(presentationData)
        self._automaticMediaDownloadSettings.set(.single(initialPresentationDataAndSettings.automaticMediaDownloadSettings)
        |> then(accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings, ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings])
            |> map { sharedData in
                let autodownloadSettings: AutodownloadSettings = sharedData.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) ?? .defaultSettings
                let automaticDownloadSettings: MediaAutoDownloadSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.automaticMediaDownloadSettings]?.get(MediaAutoDownloadSettings.self) ?? .defaultSettings
                return automaticDownloadSettings.updatedWithAutodownloadSettings(autodownloadSettings)
            }
        ))
        
        self.mediaManager = MediaManagerImpl(accountManager: accountManager, inForeground: applicationBindings.applicationInForeground, presentationData: presentationData)
        
        self.mediaManager.overlayMediaManager.updatePossibleEmbeddingItem = { [weak self] item in
            guard let strongSelf = self else {
                return
            }
            guard let navigationController = strongSelf.mainWindow?.viewController as? NavigationController else {
                return
            }
            var content: NavigationControllerDropContent?
            if let item = item {
                content = NavigationControllerDropContent(
                    position: item.position,
                    item: VideoNavigationControllerDropContentItem(
                        itemNode: item.itemNode
                    )
                )
            }
            
            navigationController.updatePossibleControllerDropContent(content: content)
        }
        
        self.mediaManager.overlayMediaManager.embedPossibleEmbeddingItem = { [weak self] item in
            guard let strongSelf = self else {
                return false
            }
            guard let navigationController = strongSelf.mainWindow?.viewController as? NavigationController else {
                return false
            }
            let content = NavigationControllerDropContent(
                position: item.position,
                item: VideoNavigationControllerDropContentItem(
                    itemNode: item.itemNode
                )
            )
            
            return navigationController.acceptPossibleControllerDropContent(content: content)
        }
        
        self._autodownloadSettings.set(.single(initialPresentationDataAndSettings.autodownloadSettings)
        |> then(accountManager.sharedData(keys: [SharedDataKeys.autodownloadSettings])
            |> map { sharedData in
                let autodownloadSettings: AutodownloadSettings = sharedData.entries[SharedDataKeys.autodownloadSettings]?.get(AutodownloadSettings.self) ?? .defaultSettings
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
                    
                    /*if #available(iOS 13.0, *) {
                        let userInterfaceStyle: UIUserInterfaceStyle
                        if strongSelf.currentPresentationData.with({ $0 }).theme.overallDarkAppearance {
                            userInterfaceStyle = .dark
                        } else {
                            userInterfaceStyle = .light
                        }
                        if let eventView = strongSelf.mainWindow?.hostView.eventView, eventView.overrideUserInterfaceStyle != userInterfaceStyle {
                            eventView.overrideUserInterfaceStyle = userInterfaceStyle
                        }
                    }*/
                }
                if themeNameUpdated {
                    strongSelf.presentCrossfadeController()
                }
            }
        }))
        
        self.inAppNotificationSettingsDisposable = (self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.inAppNotificationSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) {
                    let _ = strongSelf.currentInAppNotificationSettings.swap(settings)
                }
            }
        })
        
        self.mediaInputSettingsDisposable = (self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.mediaInputSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.mediaInputSettings]?.get(MediaInputSettings.self) {
                    let _ = strongSelf.currentMediaInputSettings.swap(settings)
                }
            }
        })
        
        self.mediaDisplaySettingsDisposable = (self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.mediaDisplaySettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.mediaDisplaySettings]?.get(MediaDisplaySettings.self) {
                    let _ = strongSelf.currentMediaDisplaySettings.swap(settings)
                }
            }
        })
        
        self.stickerSettingsDisposable = (self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.stickerSettings])
        |> deliverOnMainQueue).start(next: { [weak self] sharedData in
            if let strongSelf = self {
                if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.stickerSettings]?.get(StickerSettings.self) {
                    let _ = strongSelf.currentStickerSettings.swap(settings)
                }
            }
        })
        
        let immediateExperimentalUISettingsValue = self.immediateExperimentalUISettingsValue
        let _ = immediateExperimentalUISettingsValue.swap(initialPresentationDataAndSettings.experimentalUISettings)
        self.experimentalUISettingsDisposable = (self.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.experimentalUISettings])
        |> deliverOnMainQueue).start(next: { sharedData in
            if let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.experimentalUISettings]?.get(ExperimentalUISettings.self) {
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
                strongSelf.currentAutomaticMediaDownloadSettings = next
                
                if automaticEnergyUsageShouldBeOnNow(settings: next) {
                    strongSelf.energyUsageSettings = EnergyUsageSettings.powerSavingDefault
                } else {
                    strongSelf.energyUsageSettings = next.energyUsageSettings
                }
                strongSelf.energyUsageAutomaticDisposable.set((automaticEnergyUsageShouldBeOn(settings: next)
                |> deliverOnMainQueue).start(next: { value in
                    if let strongSelf = self {
                        if value {
                            strongSelf.energyUsageSettings = EnergyUsageSettings.powerSavingDefault
                        } else {
                            strongSelf.energyUsageSettings = next.energyUsageSettings
                        }
                    }
                }))
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
                    if case .loggedOut = attribute {
                        return true
                    } else {
                        return false
                    }
                })
                if isLoggedOut {
                    continue
                }
                let isTestingEnvironment = record.attributes.contains(where: { attribute in
                    if case let .environment(environment) = attribute, case .test = environment.environment {
                        return true
                    } else {
                        return false
                    }
                })
                var backupData: AccountBackupData?
                var sortIndex: Int32 = 0
                var isSupportUser = false
                for attribute in record.attributes {
                    if case let .sortOrder(sortOrder) = attribute {
                        sortIndex = sortOrder.order
                    } else if case let .backupData(backupDataValue) = attribute {
                        backupData = backupDataValue.data
                    } else if case .supportUserInfo = attribute, !"".isEmpty {
                        isSupportUser = true
                    }
                }
                result[record.id] = AccountAttributes(sortIndex: sortIndex, isTestingEnvironment: isTestingEnvironment, backupData: backupData, isSupportUser: isSupportUser)
            }
            let authRecord: (AccountRecordId, Bool)? = view.currentAuthAccount.flatMap({ authAccount in
                let isTestingEnvironment = authAccount.attributes.contains(where: { attribute in
                    if case let .environment(environment) = attribute, case .test = environment.environment {
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
                    addedSignals.append(accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: id, encryptionParameters: encryptionParameters, supplementary: !applicationBindings.isMainApp, isSupportUser: attributes.isSupportUser, rootPath: rootPath, beginWithTestingEnvironment: attributes.isTestingEnvironment, backupData: attributes.backupData, auxiliaryMethods: makeTelegramAccountAuxiliaryMethods(uploadInBackground: appDelegate?.uploadInBackround))
                    |> mapToSignal { result -> Signal<AddedAccountResult, NoError> in
                        switch result {
                            case let .authorized(account):
                                setupAccount(account, fetchCachedResourceRepresentation: fetchCachedResourceRepresentation, transformOutgoingMessageMedia: transformOutgoingMessageMedia)
                                return TelegramEngine(account: account).data.get(
                                    TelegramEngine.EngineData.Item.Configuration.Limits(),
                                    TelegramEngine.EngineData.Item.Configuration.ContentSettings(),
                                    TelegramEngine.EngineData.Item.Configuration.App(),
                                    TelegramEngine.EngineData.Item.Configuration.AvailableColorOptions(scope: .replies),
                                    TelegramEngine.EngineData.Item.Configuration.AvailableColorOptions(scope: .profile)
                                )
                                |> map { limitsConfiguration, contentSettings, appConfiguration, availableReplyColors, availableProfileColors -> AddedAccountResult in
                                    return .ready(id, account, attributes.sortIndex, (limitsConfiguration._asLimits(), contentSettings, appConfiguration, availableReplyColors, availableProfileColors))
                                }
                            case let .upgrading(progress):
                                return .single(.upgrading(progress))
                            default:
                                return .single(.ready(id, nil, attributes.sortIndex, (nil, nil, nil, EngineAvailableColorOptions(hash: 0, options: []), EngineAvailableColorOptions(hash: 0, options: []))))
                        }
                    })
                }
            }
            if let authRecord = authRecord, authRecord.0 != self.activeAccountsValue?.currentAuth?.id {
                addedAuthSignal = accountWithId(accountManager: accountManager, networkArguments: networkArguments, id: authRecord.0, encryptionParameters: encryptionParameters, supplementary: !applicationBindings.isMainApp, isSupportUser: false, rootPath: rootPath, beginWithTestingEnvironment: authRecord.1, backupData: nil, auxiliaryMethods: makeTelegramAccountAuxiliaryMethods(uploadInBackground: appDelegate?.uploadInBackround))
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
                var readyAccounts: [(AccountRecordId, Account?, Int32, AccountInitialData)] = []
                var totalProgress: Float = 0.0
                var hasItemsWithProgress = false
                for result in results {
                    switch result {
                        case let .ready(id, account, sortIndex, initialData):
                            readyAccounts.append((id, account, sortIndex, initialData))
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
                
                var addedAccounts: [(AccountRecordId, Account?, Int32, AccountInitialData)] = []
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

                            let context = AccountContextImpl(sharedContext: self, account: account, limitsConfiguration: accountRecord.3.limitsConfiguration ?? .defaultValue, contentSettings: accountRecord.3.contentSettings ?? .default, appConfiguration: accountRecord.3.appConfiguration ?? .defaultValue, availableReplyColors: accountRecord.3.availableReplyColors, availableProfileColors: accountRecord.3.availableProfileColors)

                            self.activeAccountsValue!.accounts.append((account.id, context, accountRecord.2))
                            
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
                var primary: AccountContext?
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
                    self.activeAccountsValue!.primary?.account.postbox.clearCaches()
                    self.activeAccountsValue!.primary?.account.resetCachedData()
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
                    
                    self.performAccountSettingsImportIfNecessary()
                }
                
                if self.activeAccountsValue!.primary == nil && self.activeAccountsValue!.currentAuth == nil {
                    self.beginNewAuth(testingEnvironment: false)
                }
            }))
        })
        
        self.activeAccountsWithInfoPromise.set(self.activeAccountContexts
        |> mapToSignal { primary, accounts, _ -> Signal<(primary: AccountRecordId?, accounts: [AccountWithInfo]), NoError> in
            return combineLatest(accounts.map { _, context, _ -> Signal<AccountWithInfo?, NoError> in
                return context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                |> map { peer -> AccountWithInfo? in
                    guard let peer = peer else {
                        return nil
                    }
                    return AccountWithInfo(account: context.account, peer: peer._asPeer())
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
                return (primary?.account.id, accountsWithInfoResult)
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
            }, audioSession: self.mediaManager.audioSession, activeAccounts: self.activeAccountContexts |> map { _, accounts, _ in
                return Array(accounts.map({ $0.1 }))
            })
            self.callManager = callManager
            
            self.callDisposable = (callManager.currentCallSignal
            |> deliverOnMainQueue).start(next: { [weak self] call in
                guard let self else {
                    return
                }
                    
                if call !== self.call {
                    self.call = call
                    
                    self.callController?.dismiss()
                    self.callController = nil
                    self.hasOngoingCall.set(false)
                    
                    self.notificationController?.setBlocking(nil)
                    
                    self.callPeerDisposable?.dispose()
                    self.callPeerDisposable = nil
                    
                    if let call {
                        self.callState.set(call.state
                        |> map(Optional.init))
                        self.hasOngoingCall.set(true)
                        setNotificationCall(call)
                        
                        if call.isOutgoing {
                            self.presentControllerWithCurrentCall()
                        } else {
                            if !call.isIntegratedWithCallKit {
                                self.callPeerDisposable?.dispose()
                                self.callPeerDisposable = (call.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: call.peerId))
                                |> deliverOnMainQueue).startStrict(next: { [weak self, weak call] peer in
                                    guard let self, let call, let peer else {
                                        return
                                    }
                                    if self.call !== call {
                                        return
                                    }
                                    
                                    let presentationData = self.currentPresentationData.with { $0 }
                                    self.notificationController?.setBlocking(ChatCallNotificationItem(context: call.context, strings: presentationData.strings, nameDisplayOrder: presentationData.nameDisplayOrder, peer: peer, isVideo: call.isVideo, action: { [weak call] answerAction in
                                        guard let call else {
                                            return
                                        }
                                        if answerAction {
                                            call.answer()
                                        } else {
                                            call.rejectBusy()
                                        }
                                    }))
                                })
                            }
                            
                            self.awaitingCallConnectionDisposable = (call.state
                            |> filter { state in
                                switch state.state {
                                case .ringing:
                                    return false
                                case .terminating, .terminated:
                                    return false
                                default:
                                    return true
                                }
                            }
                            |> take(1)
                            |> deliverOnMainQueue).start(next: { [weak self] _ in
                                guard let self else {
                                    return
                                }
                                self.notificationController?.setBlocking(nil)
                                self.presentControllerWithCurrentCall()
                                
                                self.callPeerDisposable?.dispose()
                                self.callPeerDisposable = nil
                            })
                        }
                    } else {
                        self.callState.set(.single(nil))
                        self.hasOngoingCall.set(false)
                        self.awaitingCallConnectionDisposable?.dispose()
                        self.awaitingCallConnectionDisposable = nil
                        setNotificationCall(nil)
                    }
                }
            })
            
            self.groupCallDisposable = (callManager.currentGroupCallSignal
            |> deliverOnMainQueue).start(next: { [weak self] call in
                if let strongSelf = self {
                    if call !== strongSelf.groupCallController?.call {
                        strongSelf.groupCallController?.dismiss(closing: true, manual: false)
                        strongSelf.groupCallController = nil
                        strongSelf.hasOngoingCall.set(false)
                        
                        if let call = call, let navigationController = mainWindow.viewController as? NavigationController {
                            mainWindow.hostView.containerView.endEditing(true)
                            
                            if call.isStream {
                                strongSelf.hasGroupCallOnScreenPromise.set(true)
                                let groupCallController = MediaStreamComponentController(call: call)
                                groupCallController.onViewDidAppear = { [weak self] in
                                    if let strongSelf = self {
                                        strongSelf.hasGroupCallOnScreenPromise.set(true)
                                    }
                                }
                                groupCallController.onViewDidDisappear = { [weak self] in
                                    if let strongSelf = self {
                                        strongSelf.hasGroupCallOnScreenPromise.set(false)
                                    }
                                }
                                groupCallController.navigationPresentation = .flatModal
                                groupCallController.parentNavigationController = navigationController
                                strongSelf.groupCallController = groupCallController
                                navigationController.pushViewController(groupCallController)
                            } else {
                                strongSelf.hasGroupCallOnScreenPromise.set(true)
                                
                                let _ = (makeVoiceChatControllerInitialData(sharedContext: strongSelf, accountContext: call.accountContext, call: call)
                                |> deliverOnMainQueue).start(next: { [weak strongSelf, weak navigationController] initialData in
                                    guard let strongSelf, let navigationController else {
                                        return
                                    }
                                    
                                    let groupCallController = makeVoiceChatController(sharedContext: strongSelf, accountContext: call.accountContext, call: call, initialData: initialData)
                                    groupCallController.onViewDidAppear = { [weak strongSelf] in
                                        if let strongSelf {
                                            strongSelf.hasGroupCallOnScreenPromise.set(true)
                                        }
                                    }
                                    groupCallController.onViewDidDisappear = { [weak strongSelf] in
                                        if let strongSelf {
                                            strongSelf.hasGroupCallOnScreenPromise.set(false)
                                        }
                                    }
                                    groupCallController.navigationPresentation = .flatModal
                                    groupCallController.parentNavigationController = navigationController
                                    strongSelf.groupCallController = groupCallController
                                    navigationController.pushViewController(groupCallController)
                                })
                            }
                            
                            strongSelf.hasOngoingCall.set(true)
                        } else {
                            strongSelf.hasOngoingCall.set(false)
                        }
                    }
                }
            })
            
            let callSignal: Signal<PresentationCall?, NoError> = .single(nil)
            |> then(
                callManager.currentCallSignal
                |> deliverOnMainQueue
                |> mapToSignal { call -> Signal<PresentationCall?, NoError> in
                    guard let call else {
                        return .single(nil)
                    }
                    return call.state
                    |> map { [weak call] state -> PresentationCall? in
                        guard let call else {
                            return nil
                        }
                        switch state.state {
                        case .ringing:
                            return nil
                        case .terminating, .terminated:
                            return nil
                        default:
                            return call
                        }
                    }
                }
                |> distinctUntilChanged(isEqual: { lhs, rhs in
                    return lhs === rhs
                })
            )
            let groupCallSignal: Signal<PresentationGroupCall?, NoError> = .single(nil)
            |> then(
                callManager.currentGroupCallSignal
            )
            
            self.callStateDisposable = combineLatest(queue: .mainQueue(),
                callSignal,
                groupCallSignal,
                self.hasGroupCallOnScreenPromise.get()
            ).start(next: { [weak self] call, groupCall, hasGroupCallOnScreen in
                if let strongSelf = self {
                    let statusBarContent: CallStatusBarNodeImpl.Content?
                    if let call = call {
                        statusBarContent = .call(strongSelf, call.context.account, call)
                    } else if let groupCall = groupCall, !hasGroupCallOnScreen {
                        statusBarContent = .groupCall(strongSelf, groupCall.account, groupCall)
                    } else {
                        statusBarContent = nil
                    }
                    
                    var resolvedCallStatusBarNode: CallStatusBarNodeImpl?
                    if let statusBarContent = statusBarContent {
                        if let current = strongSelf.currentCallStatusBarNode {
                            resolvedCallStatusBarNode = current
                        } else {
                            resolvedCallStatusBarNode = CallStatusBarNodeImpl()
                            strongSelf.currentCallStatusBarNode = resolvedCallStatusBarNode
                        }
                        resolvedCallStatusBarNode?.update(content: statusBarContent)
                    } else {
                        strongSelf.currentCallStatusBarNode = nil
                    }
                    
                    if let navigationController = strongSelf.mainWindow?.viewController as? NavigationController {
                        navigationController.setForceInCallStatusBar(resolvedCallStatusBarNode)
                    }
                }
            })
            
            mainWindow.inCallNavigate = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                if let callController = strongSelf.callController {
                    if callController.isNodeLoaded {
                        mainWindow.hostView.containerView.endEditing(true)
                        if callController.view.superview == nil {
                            mainWindow.present(callController, on: .calls)
                        } else {
                            callController.expandFromPipIfPossible()
                        }
                    }
                } else if let groupCallController = strongSelf.groupCallController {
                    if groupCallController.isNodeLoaded {
                        mainWindow.hostView.containerView.endEditing(true)
                        if groupCallController.view.superview == nil {
                            (mainWindow.viewController as? NavigationController)?.pushViewController(groupCallController)
                        }
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
        
        self.enablePreloads.set(combineLatest(
            self.hasOngoingCall.get(),
            self.hasPreloadBlockingContent.get()
        )
        |> map { hasOngoingCall, hasPreloadBlockingContent -> Bool in
            if hasOngoingCall {
                return false
            }
            if hasPreloadBlockingContent {
                return false
            }
            return true
        })
        
        let _ = managedCleanupAccounts(networkArguments: networkArguments, accountManager: self.accountManager, rootPath: rootPath, auxiliaryMethods: makeTelegramAccountAuxiliaryMethods(uploadInBackground: appDelegate?.uploadInBackround), encryptionParameters: encryptionParameters).start()
        
        self.updateNotificationTokensRegistration()
        
        if applicationBindings.isMainApp {
            self.widgetDataContext = WidgetDataContext(basePath: self.basePath, inForeground: self.applicationBindings.applicationInForeground, activeAccounts: self.activeAccountContexts
            |> map { _, accounts, _ in
                return accounts.map { $0.1.account }
            }, presentationData: self.presentationData, appLockContext: self.appLockContext as! AppLockContextImpl)
            
            let enableSpotlight = accountManager.sharedData(keys: Set([ApplicationSpecificSharedDataKeys.intentsSettings]))
            |> map { sharedData -> Bool in
                let intentsSettings: IntentsSettings = sharedData.entries[ApplicationSpecificSharedDataKeys.intentsSettings]?.get(IntentsSettings.self) ?? .defaultSettings
                return intentsSettings.contacts
            }
            |> distinctUntilChanged
            self.spotlightDataContext = SpotlightDataContext(appBasePath: applicationBindings.containerPath, accountManager: accountManager, accounts: combineLatest(enableSpotlight, self.activeAccountContexts
            |> map { _, accounts, _ in
                return accounts.map { _, account, _ in
                    return account.account
                }
            }) |> map { enableSpotlight, accounts in
                if enableSpotlight {
                    return accounts
                } else {
                    return []
                }
            })
        }
        
        /*if #available(iOS 13.0, *) {
            let userInterfaceStyle: UIUserInterfaceStyle
            if self.currentPresentationData.with({ $0 }).theme.overallDarkAppearance {
                userInterfaceStyle = .dark
            } else {
                userInterfaceStyle = .light
            }
            if let eventView = self.mainWindow?.hostView.eventView, eventView.overrideUserInterfaceStyle != userInterfaceStyle {
                eventView.overrideUserInterfaceStyle = userInterfaceStyle
            }
        }*/
    }
    
    deinit {
        assertionFailure("SharedAccountContextImpl is not supposed to be deallocated")
        self.registeredNotificationTokensDisposable.dispose()
        self.presentationDataDisposable.dispose()
        self.automaticMediaDownloadSettingsDisposable.dispose()
        self.currentAutodownloadSettingsDisposable.dispose()
        self.inAppNotificationSettingsDisposable?.dispose()
        self.mediaInputSettingsDisposable?.dispose()
        self.mediaDisplaySettingsDisposable?.dispose()
        self.callDisposable?.dispose()
        self.groupCallDisposable?.dispose()
        self.callStateDisposable?.dispose()
        self.awaitingCallConnectionDisposable?.dispose()
        self.callPeerDisposable?.dispose()
    }
    
    private var didPerformAccountSettingsImport = false
    private func performAccountSettingsImportIfNecessary() {
        if self.didPerformAccountSettingsImport {
            return
        }
        if let _ = UserDefaults.standard.value(forKey: "didPerformAccountSettingsImport") {
            self.didPerformAccountSettingsImport = true
            return
        }
        UserDefaults.standard.set(true as NSNumber, forKey: "didPerformAccountSettingsImport")
        UserDefaults.standard.synchronize()
        
        if let primary = self.activeAccountsValue?.primary {
            let _ = (primary.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: primary.account.peerId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, case let .user(user) = peer else {
                    return
                }
                if user.isPremium {
                    let _ = updateMediaDownloadSettingsInteractively(accountManager: self.accountManager, { settings in
                        var settings = settings
                        settings.energyUsageSettings.loopEmoji = true
                        return settings
                    }).start()
                }
            })
        }
        
        self.didPerformAccountSettingsImport = true
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
                    var attributes: [TelegramAccountManagerTypes.Attribute] = record.attributes.filter { attribute in
                        if case .backupData = attribute {
                            return false
                        } else {
                            return true
                        }
                    }
                    attributes.append(.backupData(AccountBackupDataAttribute(data: backupData)))
                    return AccountRecord(id: record.id, attributes: attributes, temporarySessionId: record.temporarySessionId)
                })
            }
            |> ignoreValues
        }
    }
    
    private func presentControllerWithCurrentCall() {
        guard let call = self.call else {
            return
        }
        
        if let currentCallController = self.callController {
            if currentCallController.call == .call(call) {
                self.navigateToCurrentCall()
                return
            } else {
                self.callController = nil
                currentCallController.dismiss()
            }
        }
        
        self.mainWindow?.hostView.containerView.endEditing(true)
        let callController = CallController(sharedContext: self, account: call.context.account, call: .call(call), easyDebugAccess: !GlobalExperimentalSettings.isAppStoreBuild)
        self.callController = callController
        callController.restoreUIForPictureInPicture = { [weak self, weak callController] completion in
            guard let self, let callController else {
                completion(false)
                return
            }
            if callController.window == nil {
                self.mainWindow?.present(callController, on: .calls)
            }
            completion(true)
        }
        self.mainWindow?.present(callController, on: .calls)
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
            let settings = sharedData.entries[ApplicationSpecificSharedDataKeys.inAppNotificationSettings]?.get(InAppNotificationSettings.self) ?? InAppNotificationSettings.defaultSettings
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
        
        let updatedApsToken = self.apsNotificationToken |> distinctUntilChanged(isEqual: { $0 == $1 })
        self.registeredNotificationTokensDisposable.set((combineLatest(
            queue: .mainQueue(),
            settings,
            self.activeAccountContexts,
            updatedApsToken
        )
        |> mapToSignal { settings, activeAccountsAndInfo, apsNotificationToken -> Signal<(Bool, Data?), NoError> in
            let (primary, activeAccounts, _) = activeAccountsAndInfo
            var appliedApsList: [Signal<Bool?, NoError>] = []
            var appliedVoipList: [Signal<Never, NoError>] = []
            var activeProductionUserIds = activeAccounts.map({ $0.1 }).filter({ !$0.account.testingEnvironment }).map({ $0.account.peerId.id })
            var activeTestingUserIds = activeAccounts.map({ $0.1 }).filter({ $0.account.testingEnvironment }).map({ $0.account.peerId.id })
            
            let allProductionUserIds = activeProductionUserIds
            let allTestingUserIds = activeTestingUserIds
            
            if !settings.allAccounts {
                if let primary = primary {
                    if !primary.account.testingEnvironment {
                        activeProductionUserIds = [primary.account.peerId.id]
                        activeTestingUserIds = []
                    } else {
                        activeProductionUserIds = []
                        activeTestingUserIds = [primary.account.peerId.id]
                    }
                } else {
                    activeProductionUserIds = []
                    activeTestingUserIds = []
                }
            }
            
            for (_, account, _) in activeAccounts {
                let appliedAps: Signal<Bool, NoError>
                let appliedVoip: Signal<Never, NoError>
                
                if !activeProductionUserIds.contains(account.account.peerId.id) && !activeTestingUserIds.contains(account.account.peerId.id) {
                    if let apsNotificationToken {
                        appliedAps = account.engine.accountData.unregisterNotificationToken(token: apsNotificationToken, type: .aps(encrypt: false), otherAccountUserIds: (account.account.testingEnvironment ? allTestingUserIds : allProductionUserIds).filter({ $0 != account.account.peerId.id }))
                        |> map { _ -> Bool in
                        }
                        |> then(.single(true))
                    } else {
                        appliedAps = .single(true)
                    }
                    
                    appliedVoip = self.voipNotificationToken
                    |> distinctUntilChanged(isEqual: { $0 == $1 })
                    |> mapToSignal { token -> Signal<Never, NoError> in
                        guard let token = token else {
                            return .complete()
                        }
                        return account.engine.accountData.unregisterNotificationToken(token: token, type: .voip, otherAccountUserIds: (account.account.testingEnvironment ? allTestingUserIds : allProductionUserIds).filter({ $0 != account.account.peerId.id }))
                    }
                } else {
                    if let apsNotificationToken {
                        appliedAps = account.engine.accountData.registerNotificationToken(token: apsNotificationToken, type: .aps(encrypt: true), sandbox: sandbox, otherAccountUserIds: (account.account.testingEnvironment ? activeTestingUserIds : activeProductionUserIds).filter({ $0 != account.account.peerId.id }), excludeMutedChats: !settings.includeMuted)
                    } else {
                        appliedAps = .single(true)
                    }
                    appliedVoip = self.voipNotificationToken
                    |> distinctUntilChanged(isEqual: { $0 == $1 })
                    |> mapToSignal { token -> Signal<Never, NoError> in
                        guard let token = token else {
                            return .complete()
                        }
                        return account.engine.accountData.registerNotificationToken(token: token, type: .voip, sandbox: sandbox, otherAccountUserIds: (account.account.testingEnvironment ? activeTestingUserIds : activeProductionUserIds).filter({ $0 != account.account.peerId.id }), excludeMutedChats: !settings.includeMuted)
                        |> ignoreValues
                    }
                }
                
                appliedApsList.append(Signal<Bool?, NoError>.single(nil) |> then(appliedAps |> map(Optional.init)))
                appliedVoipList.append(appliedVoip)
            }
            
            let allApsSuccess = combineLatest(appliedApsList)
            |> map { values -> Bool in
                return !values.contains(false)
            }
            
            let allVoipSuccess = combineLatest(appliedVoipList)
            
            return combineLatest(
                allApsSuccess,
                Signal<Void, NoError>.single(Void())
                |> then(
                    allVoipSuccess
                    |> map { _ -> Void in
                        return Void()
                    }
                )
            )
            |> map { allApsSuccess, _ -> (Bool, Data?) in
                return (allApsSuccess, apsNotificationToken)
            }
        }
        |> deliverOnMainQueue).start(next: { [weak self] allApsSuccess, apsToken in
            guard let self, let appDelegate = self.appDelegate else {
                return
            }
            if !allApsSuccess {
                if self.invalidatedApsToken != apsToken {
                    self.invalidatedApsToken = apsToken
                    
                    appDelegate.requestNotificationTokenInvalidation()
                }
            }
        }))
    }
    
    public func beginNewAuth(testingEnvironment: Bool) {
        let _ = self.accountManager.transaction({ transaction -> Void in
            let _ = transaction.createAuth([.environment(AccountEnvironmentAttribute(environment: testingEnvironment ? .test : .production))])
        }).start()
    }
    
    public func switchToAccount(id: AccountRecordId, fromSettingsController settingsController: ViewController? = nil, withChatListController chatListController: ViewController? = nil) {
        if self.activeAccountsValue?.primary?.account.id == id {
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
    
    public func openSearch(filter: ChatListSearchFilter, query: String?) {
        if let rootController = self.mainWindow?.viewController as? TelegramRootController {
            rootController.openChatsController(activateSearch: true, filter: filter, query: query)
        }
    }
    
    public func navigateToChat(accountId: AccountRecordId, peerId: PeerId, messageId: MessageId?) {
        self.navigateToChatImpl(accountId, peerId, messageId)
    }
    
    public func messageFromPreloadedChatHistoryViewForLocation(id: MessageId, location: ChatHistoryLocationInput, context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject?, chatLocationContextHolder: Atomic<ChatLocationContextHolder?>, tag: HistoryViewInputTag?) -> Signal<(MessageIndex?, Bool), NoError> {
        let historyView = preloadedChatHistoryViewForLocation(location, context: context, chatLocation: chatLocation, subject: subject, chatLocationContextHolder: chatLocationContextHolder, fixedCombinedReadStates: nil, tag: tag, additionalData: [])
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
    
    public func makeOverlayAudioPlayerController(context: AccountContext, chatLocation: ChatLocation, type: MediaManagerPlayerType, initialMessageId: MessageId, initialOrder: MusicPlaybackSettingsOrder, playlistLocation: SharedMediaPlaylistLocation?, parentNavigationController: NavigationController?) -> ViewController & OverlayAudioPlayerController {
        return OverlayAudioPlayerControllerImpl(context: context, chatLocation: chatLocation, type: type, initialMessageId: initialMessageId, initialOrder: initialOrder, playlistLocation: playlistLocation, parentNavigationController: parentNavigationController)
    }
    
    public func makeTempAccountContext(account: Account) -> AccountContext {
        return AccountContextImpl(sharedContext: self, account: account, limitsConfiguration: .defaultValue, contentSettings: .default, appConfiguration: .defaultValue, availableReplyColors: EngineAvailableColorOptions(hash: 0, options: []), availableProfileColors: EngineAvailableColorOptions(hash: 0, options: []), temp: true)
    }
    
    public func openChatMessage(_ params: OpenChatMessageParams) -> Bool {
        return openChatMessageImpl(params)
    }
    
    public func navigateToCurrentCall() {
        guard let mainWindow = self.mainWindow else {
            return
        }
        if let callController = self.callController {
            if callController.isNodeLoaded && callController.view.superview == nil {
                mainWindow.hostView.containerView.endEditing(true)
                mainWindow.present(callController, on: .calls)
            }
        } else if let groupCallController = self.groupCallController {
            if groupCallController.isNodeLoaded && groupCallController.view.superview == nil {
                mainWindow.hostView.containerView.endEditing(true)
                (mainWindow.viewController as? NavigationController)?.pushViewController(groupCallController)
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
    
    public func makePeerInfoController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peer: Peer, mode: PeerInfoControllerMode, avatarInitiallyExpanded: Bool, fromChat: Bool, requestsContext: PeerInvitationImportersContext?) -> ViewController? {
        let controller = peerInfoControllerImpl(context: context, updatedPresentationData: updatedPresentationData, peer: peer, mode: mode, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: fromChat)
        controller?.navigationPresentation = .modalInLargeLayout
        return controller
    }
    
    public func makeChannelAdminController(context: AccountContext, peerId: PeerId, adminId: PeerId, initialParticipant: ChannelParticipant) -> ViewController? {
        let controller = channelAdminController(context: context, peerId: peerId, adminId: adminId, initialParticipant: initialParticipant, updated: { _ in }, upgradedToSupergroup: { _, _ in }, transferedOwnership: { _ in })
        return controller
    }
    
    public func makeDebugSettingsController(context: AccountContext?) -> ViewController? {
        let controller = debugController(sharedContext: self, context: context)
        return controller
    }
    
    public func openExternalUrl(context: AccountContext, urlContext: OpenURLContext, url: String, forceExternal: Bool, presentationData: PresentationData, navigationController: NavigationController?, dismissInput: @escaping () -> Void) {
        openExternalUrlImpl(context: context, urlContext: urlContext, url: url, forceExternal: forceExternal, presentationData: presentationData, navigationController: navigationController, dismissInput: dismissInput)
    }
    
    public func chatAvailableMessageActions(engine: TelegramEngine, accountPeerId: EnginePeer.Id, messageIds: Set<EngineMessage.Id>, keepUpdated: Bool) -> Signal<ChatAvailableMessageActions, NoError> {
        return chatAvailableMessageActionsImpl(engine: engine, accountPeerId: accountPeerId, messageIds: messageIds, keepUpdated: keepUpdated)
    }
    
    public func chatAvailableMessageActions(engine: TelegramEngine, accountPeerId: EnginePeer.Id, messageIds: Set<EngineMessage.Id>, messages: [EngineMessage.Id: EngineMessage] = [:], peers: [EnginePeer.Id: EnginePeer] = [:]) -> Signal<ChatAvailableMessageActions, NoError> {
        return chatAvailableMessageActionsImpl(engine: engine, accountPeerId: accountPeerId, messageIds: messageIds, messages: messages.mapValues({ $0._asMessage() }), peers: peers.mapValues({ $0._asPeer() }), keepUpdated: false)
    }
    
    public func navigateToChatController(_ params: NavigateToChatControllerParams) {
        navigateToChatControllerImpl(params)
    }
    
    public func navigateToForumChannel(context: AccountContext, peerId: EnginePeer.Id, navigationController: NavigationController) {
        navigateToForumChannelImpl(context: context, peerId: peerId, navigationController: navigationController)
    }
    
    public func navigateToForumThread(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64, messageId: EngineMessage.Id?, navigationController: NavigationController, activateInput: ChatControllerActivateInput?, scrollToEndIfExists: Bool, keepStack: NavigateToChatKeepStack) -> Signal<Never, NoError> {
        return navigateToForumThreadImpl(context: context, peerId: peerId, threadId: threadId, messageId: messageId, navigationController: navigationController, activateInput: activateInput, scrollToEndIfExists: scrollToEndIfExists, keepStack: keepStack)
    }
    
    public func chatControllerForForumThread(context: AccountContext, peerId: EnginePeer.Id, threadId: Int64) -> Signal<ChatController, NoError> {
        return chatControllerForForumThreadImpl(context: context, peerId: peerId, threadId: threadId)
    }
    
    public func openStorageUsage(context: AccountContext) {
        guard let navigationController = self.mainWindow?.viewController as? NavigationController else {
            return
        }
        let controller = StorageUsageScreen(context: context, makeStorageUsageExceptionsScreen: { category in
            return storageUsageExceptionsScreen(context: context, category: category)
        })
        navigationController.pushViewController(controller)
    }
    
    public func openLocationScreen(context: AccountContext, messageId: MessageId, navigationController: NavigationController) {
        var found = false
        for controller in navigationController.viewControllers.reversed() {
            if let controller = controller as? LocationViewController, controller.subject.id.peerId == messageId.peerId {
                controller.goToUserLocation(visibleRadius: nil)
                found = true
                break
            }
        }
        
        if !found {
            let controllerParams = LocationViewParams(sendLiveLocation: { location in
                //let outMessage: EnqueueMessage = .message(text: "", attributes: [], mediaReference: .standalone(media: location), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil)
//                params.enqueueMessage(outMessage)
            }, stopLiveLocation: { messageId in
                if let messageId = messageId {
                    context.liveLocationManager?.cancelLiveLocation(peerId: messageId.peerId)
                }
            }, openUrl: { _ in }, openPeer: { peer in
//                params.openPeer(peer, .info)
            })
            
            let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Messages.Message(id: messageId))
            |> deliverOnMainQueue).start(next: { message in
                guard let message = message else {
                    return
                }
                let controller = LocationViewController(context: context, subject: message, params: controllerParams)
                controller.navigationPresentation = .modal
                navigationController.pushViewController(controller)
            })
        }
    }
    
    public func resolveUrl(context: AccountContext, peerId: PeerId?, url: String, skipUrlAuth: Bool) -> Signal<ResolvedUrl, NoError> {
        return resolveUrlImpl(context: context, peerId: peerId, url: url, skipUrlAuth: skipUrlAuth)
        |> mapToSignal { result -> Signal<ResolvedUrl, NoError> in
            switch result {
            case .progress:
                return .complete()
            case let .result(value):
                return .single(value)
            }
        }
    }
    
    public func resolveUrlWithProgress(context: AccountContext, peerId: PeerId?, url: String, skipUrlAuth: Bool) -> Signal<ResolveUrlResult, NoError> {
        return resolveUrlImpl(context: context, peerId: peerId, url: url, skipUrlAuth: skipUrlAuth)
    }
    
    public func openResolvedUrl(_ resolvedUrl: ResolvedUrl, context: AccountContext, urlContext: OpenURLContext, navigationController: NavigationController?, forceExternal: Bool, forceUpdate: Bool, openPeer: @escaping (EnginePeer, ChatControllerInteractionNavigateToPeer) -> Void, sendFile: ((FileMediaReference) -> Void)?, sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?, sendEmoji: ((String, ChatTextInputTextCustomEmojiAttribute) -> Void)?, requestMessageActionUrlAuth: ((MessageActionUrlSubject) -> Void)?, joinVoiceChat: ((PeerId, String?, CachedChannelData.ActiveCall) -> Void)?, present: @escaping (ViewController, Any?) -> Void, dismissInput: @escaping () -> Void, contentContext: Any?, progress: Promise<Bool>?, completion: (() -> Void)?) {
        openResolvedUrlImpl(resolvedUrl, context: context, urlContext: urlContext, navigationController: navigationController, forceExternal: forceExternal, forceUpdate: forceUpdate, openPeer: openPeer, sendFile: sendFile, sendSticker: sendSticker, sendEmoji: sendEmoji, requestMessageActionUrlAuth: requestMessageActionUrlAuth, joinVoiceChat: joinVoiceChat, present: present, dismissInput: dismissInput, contentContext: contentContext, progress: progress, completion: completion)
    }
    
    public func makeDeviceContactInfoController(context: ShareControllerAccountContext, environment: ShareControllerEnvironment, subject: DeviceContactInfoSubject, completed: (() -> Void)?, cancelled: (() -> Void)?) -> ViewController {
        return deviceContactInfoController(context: context, environment: environment, subject: subject, completed: completed, cancelled: cancelled)
    }
    
    public func makePeersNearbyController(context: AccountContext) -> ViewController {
        return peersNearbyController(context: context)
    }
    
    public func makeChatController(context: AccountContext, chatLocation: ChatLocation, subject: ChatControllerSubject?, botStart: ChatControllerInitialBotStart?, mode: ChatControllerPresentationMode, params: ChatControllerParams?) -> ChatController {
        return ChatControllerImpl(context: context, chatLocation: chatLocation, subject: subject, botStart: botStart, mode: mode, params: params)
    }
    
    public func makeChatHistoryListNode(
        context: AccountContext,
        updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>),
        chatLocation: ChatLocation,
        chatLocationContextHolder: Atomic<ChatLocationContextHolder?>,
        tag: HistoryViewInputTag?,
        source: ChatHistoryListSource,
        subject: ChatControllerSubject?,
        controllerInteraction: ChatControllerInteractionProtocol,
        selectedMessages: Signal<Set<MessageId>?, NoError>,
        mode: ChatHistoryListMode
    ) -> ChatHistoryListNode {
        return ChatHistoryListNodeImpl(
            context: context,
            updatedPresentationData: updatedPresentationData,
            chatLocation: chatLocation,
            chatLocationContextHolder: chatLocationContextHolder,
            tag: tag,
            source: source,
            subject: subject,
            controllerInteraction: controllerInteraction as! ChatControllerInteraction,
            selectedMessages: selectedMessages,
            mode: mode,
            isChatPreview: false,
            messageTransitionNode: { return nil }
        )
    }
    
    public func makePeerSharedMediaController(context: AccountContext, peerId: PeerId) -> ViewController? {
        return nil
    }
    
    public func makeChatRecentActionsController(context: AccountContext, peer: Peer, adminPeerId: PeerId?, starsState: StarsRevenueStats?) -> ViewController {
        return ChatRecentActionsController(context: context, peer: peer, adminPeerId: adminPeerId, starsState: starsState)
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
        return ComposeControllerImpl(context: context)
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
    
    public func makeChatListController(context: AccountContext, location: ChatListControllerLocation, controlsHistoryPreload: Bool, hideNetworkActivityStatus: Bool, previewing: Bool, enableDebugActions: Bool) -> ChatListController {
        return ChatListControllerImpl(context: context, location: location, controlsHistoryPreload: controlsHistoryPreload, hideNetworkActivityStatus: hideNetworkActivityStatus, previewing: previewing, enableDebugActions: enableDebugActions)
    }
    
    public func makePeerSelectionController(_ params: PeerSelectionControllerParams) -> PeerSelectionController {
        return PeerSelectionControllerImpl(params)
    }
    
    public func openAddPeerMembers(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, parentController: ViewController, groupPeer: Peer, selectAddMemberDisposable: MetaDisposable, addMemberDisposable: MetaDisposable) {
        return presentAddMembersImpl(context: context, updatedPresentationData: updatedPresentationData, parentController: parentController, groupPeer: groupPeer, selectAddMemberDisposable: selectAddMemberDisposable, addMemberDisposable: addMemberDisposable)
    }
    
    public func makeChatMessagePreviewItem(context: AccountContext, messages: [Message], theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder, forcedResourceStatus: FileMediaResourceStatus?, tapMessage: ((Message) -> Void)?, clickThroughMessage: ((UIView?, CGPoint?) -> Void)? = nil, backgroundNode: ASDisplayNode?, availableReactions: AvailableReactions?, accountPeer: Peer?, isCentered: Bool, isPreview: Bool, isStandalone: Bool) -> ListViewItem {
        let controllerInteraction: ChatControllerInteraction

        controllerInteraction = ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _, _ in }, openPeerMention: { _, _ in }, openMessageContextMenu: { _, _, _, _, _, _ in }, openMessageReactionContextMenu: { _, _, _, _ in
            }, updateMessageReaction: { _, _, _, _ in }, activateMessagePinch: { _ in
            }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _, _ in }, navigateToMessageStandalone: { _ in
            }, navigateToThreadMessage: { _, _, _ in
            }, tapMessage: { message in
                tapMessage?(message)
        }, clickThroughMessage: { view, location in
            clickThroughMessage?(view, location)
        }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _, _ in }, sendMessage: { _ in }, sendSticker: { _, _, _, _, _, _, _, _, _ in return false }, sendEmoji: { _, _, _ in }, sendGif: { _, _, _, _, _ in return false }, sendBotContextResultAsGif: { _, _, _, _, _, _ in
            return false
        }, requestMessageActionCallback: { _, _, _, _ in }, requestMessageActionUrlAuth: { _, _ in }, activateSwitchInline: { _, _, _ in }, openUrl: { _ in }, shareCurrentLocation: {}, shareAccountContact: {}, sendBotCommand: { _, _ in }, openInstantPage: { _, _ in  }, openWallpaper: { _ in  }, openTheme: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _, _ in }, longTap: { _, _ in }, openCheckoutOrReceipt: { _, _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return .none
        }, canSendMessages: {
            return false
        }, navigateToFirstDateMessage: { _, _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: { _ in
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _, _ in
        }, displayImportedMessageTooltip: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: { _, _ in
        }, displayPremiumStickerTooltip: { _, _ in
        }, displayEmojiPackTooltip: { _, _ in
        }, openPeerContextMenu: { _, _, _, _, _ in
        }, openMessageReplies: { _, _, _ in
        }, openReplyThreadOriginalMessage: { _ in
        }, openMessageStats: { _ in
        }, editMessageMedia: { _, _ in
        }, copyText: { _ in
        }, displayUndo: { _ in
        }, isAnimatingMessage: { _ in
            return false
        }, getMessageTransitionNode: {
            return nil
        }, updateChoosingSticker: { _ in
        }, commitEmojiInteraction: { _, _, _, _ in
        }, openLargeEmojiInfo: { _, _, _ in
        }, openJoinLink: { _ in
        }, openWebView: { _, _, _, _ in
        }, activateAdAction: { _, _, _, _ in
        }, adContextAction: { _, _, _ in
        }, removeAd: { _ in
        }, openRequestedPeerSelection: { _, _, _, _ in
        }, saveMediaToFiles: { _ in
        }, openNoAdsDemo: {
        }, openAdsInfo: {
        }, displayGiveawayParticipationStatus: { _ in
        }, openPremiumStatusInfo: { _, _, _, _ in
        }, openRecommendedChannelContextMenu: { _, _, _ in
        }, openGroupBoostInfo: { _, _ in
        }, openStickerEditor: {
        }, openAgeRestrictedMessageMedia: { _, _ in
        }, playMessageEffect: { _ in
        }, editMessageFactCheck: { _ in
        }, sendGift: { _ in
        }, requestMessageUpdate: { _, _ in
        }, cancelInteractiveKeyboardGestures: {
        }, dismissTextInput: {
        }, scrollToMessageId: { _ in
        }, navigateToStory: { _, _ in
        }, attemptedNavigationToPrivateQuote: { _ in
        }, forceUpdateWarpContents: {
        }, playShakeAnimation: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
        pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(), presentationContext: ChatPresentationContext(context: context, backgroundNode: backgroundNode as? WallpaperBackgroundNode))
        
        var entryAttributes = ChatMessageEntryAttributes()
        entryAttributes.isCentered = isCentered
        
        let content: ChatMessageItemContent
        let chatLocation: ChatLocation
        if messages.count > 1 {
            content = .group(messages: messages.map { ($0, true, .none, entryAttributes, nil) })
            chatLocation = .peer(id: messages.first!.id.peerId)
        } else {
            content = .message(message: messages.first!, read: true, selection: .none, attributes: entryAttributes, location: nil)
            chatLocation = .peer(id: messages.first!.id.peerId)
        }
        
        return ChatMessageItemImpl(presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameOrder, disableAnimations: false, largeEmoji: false, chatBubbleCorners: chatBubbleCorners, animatedEmojiScale: 1.0, isPreview: isPreview), context: context, chatLocation: chatLocation, associatedData: ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .cellular, isRecentActions: false, subject: nil, contactsPeerIds: Set(), animatedEmojiStickers: [:], forcedResourceStatus: forcedResourceStatus, availableReactions: availableReactions, availableMessageEffects: nil, savedMessageTags: nil, defaultReaction: nil, isPremium: false, accountPeer: accountPeer.flatMap(EnginePeer.init), forceInlineReactions: true, isStandalone: isStandalone), controllerInteraction: controllerInteraction, content: content, disableDate: true, additionalContent: nil)
    }
    
    public func makeChatMessageDateHeaderItem(context: AccountContext, timestamp: Int32, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder) -> ListViewItemHeader {
        return ChatMessageDateHeader(timestamp: timestamp, scheduled: false, presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameOrder, disableAnimations: false, largeEmoji: false, chatBubbleCorners: chatBubbleCorners, animatedEmojiScale: 1.0, isPreview: true), controllerInteraction: nil, context: context)
    }
    
    public func makeChatMessageAvatarHeaderItem(context: AccountContext, timestamp: Int32, peer: Peer, message: Message, theme: PresentationTheme, strings: PresentationStrings, wallpaper: TelegramWallpaper, fontSize: PresentationFontSize, chatBubbleCorners: PresentationChatBubbleCorners, dateTimeFormat: PresentationDateTimeFormat, nameOrder: PresentationPersonNameOrder) -> ListViewItemHeader {
        return ChatMessageAvatarHeader(timestamp: timestamp, peerId: peer.id, peer: peer, messageReference: nil, message: message, presentationData: ChatPresentationData(theme: ChatPresentationThemeData(theme: theme, wallpaper: wallpaper), fontSize: fontSize, strings: strings, dateTimeFormat: dateTimeFormat, nameDisplayOrder: nameOrder, disableAnimations: false, largeEmoji: false, chatBubbleCorners: chatBubbleCorners, animatedEmojiScale: 1.0, isPreview: true), context: context, controllerInteraction: nil, storyStats: nil)
    }
    
    public func openImagePicker(context: AccountContext, completion: @escaping (UIImage) -> Void, present: @escaping (ViewController) -> Void) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = legacyWallpaperPicker(context: context, presentationData: presentationData).start(next: { generator in
            let legacyController = LegacyController(presentation: .navigation, theme: presentationData.theme)
            legacyController.navigationPresentation = .modal
            legacyController.statusBar.statusBarStyle = presentationData.theme.rootController.statusBarStyle.style
            
            let controller = generator(legacyController.context)
            legacyController.bind(controller: controller)
            legacyController.deferScreenEdgeGestures = [.top]
            controller.selectionBlock = { [weak legacyController] asset, _ in
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
    
    public func makeInstantPageController(context: AccountContext, message: Message, sourcePeerType: MediaAutoDownloadPeerType?) -> ViewController? {
        return makeInstantPageControllerImpl(context: context, message: message, sourcePeerType: sourcePeerType)
    }
    
    public func makeInstantPageController(context: AccountContext, webPage: TelegramMediaWebpage, anchor: String?, sourceLocation: InstantPageSourceLocation) -> ViewController {
        return makeInstantPageControllerImpl(context: context, webPage: webPage, anchor: anchor, sourceLocation: sourceLocation)
    }
    
    public func openChatWallpaper(context: AccountContext, message: Message, present: @escaping (ViewController, Any?) -> Void) {
        openChatWallpaperImpl(context: context, message: message, present: present)
    }
    
    public func makeRecentSessionsController(context: AccountContext, activeSessionsContext: ActiveSessionsContext) -> ViewController & RecentSessionsController {
        return recentSessionsController(context: context, activeSessionsContext: activeSessionsContext, webSessionsContext: context.engine.privacy.webSessions(), websitesOnly: false)
    }
    
    public func makeChatQrCodeScreen(context: AccountContext, peer: Peer, threadId: Int64?, temporary: Bool) -> ViewController {
        return ChatQrCodeScreen(context: context, subject: .peer(peer: peer, threadId: threadId, temporary: temporary))
    }
    
    public func makePrivacyAndSecurityController(context: AccountContext) -> ViewController {
        return SettingsUI.makePrivacyAndSecurityController(context: context)
    }

    public func makeBioPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, present: @escaping (ViewController) -> Void) {
        SettingsUI.makeBioPrivacyController(context: context, settings: settings, present: present)
    }
    
    public func makeBirthdayPrivacyController(context: AccountContext, settings: Promise<AccountPrivacySettings?>, openedFromBirthdayScreen: Bool, present: @escaping (ViewController) -> Void) {
        SettingsUI.makeBirthdayPrivacyController(context: context, settings: settings, openedFromBirthdayScreen: openedFromBirthdayScreen, present: present)
    }
    
    public func makeSetupTwoFactorAuthController(context: AccountContext) -> ViewController {
        return SettingsUI.makeSetupTwoFactorAuthController(context: context)
    }
    
    public func makeStorageManagementController(context: AccountContext) -> ViewController {
        return StorageUsageScreen(context: context, makeStorageUsageExceptionsScreen: { [weak context] category in
            guard let context else {
                return nil
            }
            return storageUsageExceptionsScreen(context: context, category: category)
        })
    }
    
    public func makeAttachmentFileController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, bannedSendMedia: (Int32, Bool)?, presentGallery: @escaping () -> Void, presentFiles: @escaping () -> Void, send: @escaping (AnyMediaReference) -> Void) -> AttachmentFileController {
        return makeAttachmentFileControllerImpl(context: context, updatedPresentationData: updatedPresentationData, bannedSendMedia: bannedSendMedia, presentGallery: presentGallery, presentFiles: presentFiles, send: send)
    }
    
    public func makeGalleryCaptionPanelView(context: AccountContext, chatLocation: ChatLocation, isScheduledMessages: Bool, isFile: Bool, customEmojiAvailable: Bool, present: @escaping (ViewController) -> Void, presentInGlobalOverlay: @escaping (ViewController) -> Void) -> NSObject? {
        let inputPanelNode = LegacyMessageInputPanelNode(
            context: context,
            chatLocation: chatLocation,
            isScheduledMessages: isScheduledMessages,
            isFile: isFile,
            present: present,
            presentInGlobalOverlay: presentInGlobalOverlay,
            makeEntityInputView: {
                return EntityInputView(context: context, isDark: true, areCustomEmojiEnabled: customEmojiAvailable)
            }
        )
        return inputPanelNode
    }
    
    public func makeHashtagSearchController(context: AccountContext, peer: EnginePeer?, query: String, stories: Bool, forceDark: Bool) -> ViewController {
        return HashtagSearchController(context: context, peer: peer, query: query, mode: stories ? .chatOnly : .generic, stories: stories, forceDark: forceDark)
    }
    
    public func makeStorySearchController(context: AccountContext, scope: StorySearchControllerScope, listContext: SearchStoryListContext?) -> ViewController {
        return StorySearchGridScreen(context: context, scope: scope, listContext: listContext)
    }
    
    public func makeMyStoriesController(context: AccountContext, isArchive: Bool) -> ViewController {
        return PeerInfoStoryGridScreen(context: context, peerId: context.account.peerId, scope: isArchive ? .archive : .saved)
    }
    
    public func makeArchiveSettingsController(context: AccountContext) -> ViewController {
        return archiveSettingsController(context: context)
    }
    
    public func makeFilterSettingsController(context: AccountContext, modal: Bool, scrollToTags: Bool, dismissed: (() -> Void)?) -> ViewController {
        return chatListFilterPresetListController(context: context, mode: modal ? .modal : .default, scrollToTags: scrollToTags, dismissed: dismissed)
    }
    
    public func makeBusinessSetupScreen(context: AccountContext) -> ViewController {
        return PremiumIntroScreen(context: context, mode: .business, source: .settings, modal: false, forceDark: false)
    }
    
    public func makeChatbotSetupScreen(context: AccountContext, initialData: ChatbotSetupScreenInitialData) -> ViewController {
        return ChatbotSetupScreen(context: context, initialData: initialData as! ChatbotSetupScreen.InitialData)
    }
    
    public func makeChatbotSetupScreenInitialData(context: AccountContext) -> Signal<ChatbotSetupScreenInitialData, NoError> {
        return ChatbotSetupScreen.initialData(context: context)
    }
    
    public func makeBusinessLocationSetupScreen(context: AccountContext, initialValue: TelegramBusinessLocation?, completion: @escaping (TelegramBusinessLocation?) -> Void) -> ViewController {
        return BusinessLocationSetupScreen(context: context, initialValue: initialValue, completion: completion)
    }
    
    public func makeBusinessHoursSetupScreen(context: AccountContext, initialValue: TelegramBusinessHours?, completion: @escaping (TelegramBusinessHours?) -> Void) -> ViewController {
        return BusinessHoursSetupScreen(context: context, initialValue: initialValue, completion: completion)
    }
    
    public func makeAutomaticBusinessMessageSetupScreen(context: AccountContext, initialData: AutomaticBusinessMessageSetupScreenInitialData, isAwayMode: Bool) -> ViewController {
        return AutomaticBusinessMessageSetupScreen(context: context, initialData: initialData as! AutomaticBusinessMessageSetupScreen.InitialData, mode: isAwayMode ? .away : .greeting)
    }
    
    public func makeAutomaticBusinessMessageSetupScreenInitialData(context: AccountContext) -> Signal<AutomaticBusinessMessageSetupScreenInitialData, NoError> {
        return AutomaticBusinessMessageSetupScreen.initialData(context: context)
    }
    
    public func makeQuickReplySetupScreen(context: AccountContext, initialData: QuickReplySetupScreenInitialData) -> ViewController {
        return QuickReplySetupScreen(context: context, initialData: initialData as! QuickReplySetupScreen.InitialData, mode: .manage)
    }
    
    public func makeQuickReplySetupScreenInitialData(context: AccountContext) -> Signal<QuickReplySetupScreenInitialData, NoError> {
        return QuickReplySetupScreen.initialData(context: context)
    }
    
    public func makeBusinessIntroSetupScreen(context: AccountContext, initialData: BusinessIntroSetupScreenInitialData) -> ViewController {
        return BusinessIntroSetupScreen(context: context, initialData: initialData as! BusinessIntroSetupScreen.InitialData)
    }
    
    public func makeBusinessIntroSetupScreenInitialData(context: AccountContext) -> Signal<BusinessIntroSetupScreenInitialData, NoError> {
        return BusinessIntroSetupScreen.initialData(context: context)
    }
    
    public func makeBusinessLinksSetupScreen(context: AccountContext, initialData: BusinessLinksSetupScreenInitialData) -> ViewController {
        return BusinessLinksSetupScreen(context: context, initialData: initialData as! BusinessLinksSetupScreen.InitialData)
    }
    
    public func makeBusinessLinksSetupScreenInitialData(context: AccountContext) -> Signal<BusinessLinksSetupScreenInitialData, NoError> {
        return BusinessLinksSetupScreen.makeInitialData(context: context)
    }
    
    public func makeCollectibleItemInfoScreen(context: AccountContext, initialData: CollectibleItemInfoScreenInitialData) -> ViewController {
        return CollectibleItemInfoScreen(context: context, initialData: initialData as! CollectibleItemInfoScreen.InitialData)
    }
    
    public func makeCollectibleItemInfoScreenInitialData(context: AccountContext, peerId: EnginePeer.Id, subject: CollectibleItemInfoScreenSubject) -> Signal<CollectibleItemInfoScreenInitialData?, NoError> {
        return CollectibleItemInfoScreen.initialData(context: context, peerId: peerId, subject: subject)
    }
    
    public func makeBotSettingsScreen(context: AccountContext, peerId: EnginePeer.Id?) -> ViewController {
        if let peerId {
            return botSettingsScreen(context: context, peerId: peerId)
        } else {
            return botListSettingsScreen(context: context)
        }
    }
    
    public func makePremiumIntroController(context: AccountContext, source: PremiumIntroSource, forceDark: Bool, dismissed: (() -> Void)?) -> ViewController {
        var modal = true
        let mappedSource: PremiumSource
        switch source {
        case .settings:
            mappedSource = .settings
            modal = false
        case .stickers:
            mappedSource = .stickers
        case .reactions:
            mappedSource = .reactions
        case .ads:
            mappedSource = .ads
        case .upload:
            mappedSource = .upload
        case .groupsAndChannels:
            mappedSource = .groupsAndChannels
        case .pinnedChats:
            mappedSource = .pinnedChats
        case .publicLinks:
            mappedSource = .publicLinks
        case .savedGifs:
            mappedSource = .savedGifs
        case .savedStickers:
            mappedSource = .savedStickers
        case .folders:
            mappedSource = .folders
        case .chatsPerFolder:
            mappedSource = .chatsPerFolder
        case .appIcons:
            mappedSource = .appIcons
        case .accounts:
            mappedSource = .accounts
        case .about:
            mappedSource = .about
        case let .deeplink(reference):
            mappedSource = .deeplink(reference)
        case let .profile(peerId):
            mappedSource = .profile(peerId)
        case let .emojiStatus(peerId, fileId, file, packTitle):
            mappedSource = .emojiStatus(peerId, fileId, file, packTitle)
        case .voiceToText:
            mappedSource = .voiceToText
        case .fasterDownload:
            mappedSource = .fasterDownload
        case .translation:
            mappedSource = .translation
        case .stories:
            mappedSource = .stories
        case .storiesDownload:
            mappedSource = .storiesDownload
        case .storiesStealthMode:
            mappedSource = .storiesStealthMode
        case .storiesPermanentViews:
            mappedSource = .storiesPermanentViews
        case .storiesFormatting:
            mappedSource = .storiesFormatting
        case .storiesExpirationDurations:
            mappedSource = .storiesExpirationDurations
        case .storiesSuggestedReactions:
            mappedSource = .storiesSuggestedReactions
        case .storiesHigherQuality:
            mappedSource = .storiesHigherQuality
        case .storiesLinks:
            mappedSource = .storiesLinks
        case let .channelBoost(peerId):
            mappedSource = .channelBoost(peerId)
        case .nameColor:
            mappedSource = .nameColor
        case .similarChannels:
            mappedSource = .similarChannels
        case .wallpapers:
            mappedSource = .wallpapers
        case .presence:
            mappedSource = .presence
        case .readTime:
            mappedSource = .readTime
        case .messageTags:
            mappedSource = .messageTags
        case .folderTags:
            mappedSource = .folderTags
        case .messageEffects:
            mappedSource = .messageEffects
        case .animatedEmoji:
            mappedSource = .animatedEmoji
        }
        let controller = PremiumIntroScreen(context: context, source: mappedSource, modal: modal, forceDark: forceDark)
        controller.wasDismissed = dismissed
        return controller
    }
    
    public func makePremiumDemoController(context: AccountContext, subject: PremiumDemoSubject, forceDark: Bool, action: @escaping () -> Void, dismissed: (() -> Void)?) -> ViewController {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var buttonText: String = presentationData.strings.Common_OK
        let mappedSubject: PremiumDemoScreen.Subject
        switch subject {
        case .doubleLimits:
            mappedSubject = .doubleLimits
        case .moreUpload:
            mappedSubject = .moreUpload
        case .fasterDownload:
            mappedSubject = .fasterDownload
        case .voiceToText:
            mappedSubject = .voiceToText
        case .noAds:
            mappedSubject = .noAds
        case .uniqueReactions:
            mappedSubject = .uniqueReactions
        case .premiumStickers:
            mappedSubject = .premiumStickers
        case .advancedChatManagement:
            mappedSubject = .advancedChatManagement
        case .profileBadge:
            mappedSubject = .profileBadge
        case .animatedUserpics:
            mappedSubject = .animatedUserpics
        case .appIcons:
            mappedSubject = .appIcons
        case .animatedEmoji:
            mappedSubject = .animatedEmoji
        case .emojiStatus:
            mappedSubject = .emojiStatus
        case .translation:
            mappedSubject = .translation
        case .stories:
            mappedSubject = .stories
            buttonText = presentationData.strings.Story_PremiumUpgradeStoriesButton
        case .colors:
            mappedSubject = .colors
        case .wallpapers:
            mappedSubject = .wallpapers
        case .messageTags:
            mappedSubject = .messageTags
        case .lastSeen:
            mappedSubject = .lastSeen
        case .messagePrivacy:
            mappedSubject = .messagePrivacy
        case .folderTags:
            mappedSubject = .folderTags
        case .messageEffects:
            mappedSubject = .messageEffects
        case .business:
            mappedSubject = .business
            buttonText = presentationData.strings.Chat_EmptyStateIntroFooterPremiumActionButton
        default:
            mappedSubject = .doubleLimits
        }
        
        switch mappedSubject {
        case .stories, .business, .doubleLimits:
            let controller = PremiumLimitsListScreen(context: context, subject: mappedSubject, source: .other, order: [mappedSubject.perk], buttonText: buttonText, isPremium: false, forceDark: forceDark)
            controller.action = action
            if let dismissed {
                controller.disposed = dismissed
            }
            return controller
        default:
            return PremiumDemoScreen(context: context, subject: mappedSubject, forceDark: forceDark, action: action)
        }
    }
    
    public func makePremiumLimitController(context: AccountContext, subject: PremiumLimitSubject, count: Int32, forceDark: Bool, cancel: @escaping () -> Void, action: @escaping () -> Bool) -> ViewController {
        let mappedSubject: PremiumLimitScreen.Subject
        switch subject {
        case .folders:
            mappedSubject = .folders
        case .chatsPerFolder:
            mappedSubject = .chatsPerFolder
        case .pins:
            mappedSubject = .pins
        case .files:
            mappedSubject = .files
        case .accounts:
            mappedSubject = .accounts
        case .linksPerSharedFolder:
            mappedSubject = .linksPerSharedFolder
        case .membershipInSharedFolders:
            mappedSubject = .membershipInSharedFolders
        case .channels:
            mappedSubject = .channels
        case .expiringStories:
            mappedSubject = .expiringStories
        case .storiesWeekly:
            mappedSubject = .storiesWeekly
        case .storiesMonthly:
            mappedSubject = .storiesMonthly
        case let .storiesChannelBoost(peer, isCurrent, level, currentLevelBoosts, nextLevelBoosts, link, myBoostCount, canBoostAgain):
            mappedSubject = .storiesChannelBoost(peer: peer, boostSubject: .stories, isCurrent: isCurrent, level: level, currentLevelBoosts: currentLevelBoosts, nextLevelBoosts: nextLevelBoosts, link: link, myBoostCount: myBoostCount, canBoostAgain: canBoostAgain)
        }
        return PremiumLimitScreen(context: context, subject: mappedSubject, count: count, forceDark: forceDark, cancel: cancel, action: action)
    }
    
    public func makeStarsGiftController(context: AccountContext, birthdays: [EnginePeer.Id: TelegramBirthday]?, completion: @escaping (([EnginePeer.Id]) -> Void)) -> ViewController {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        var presentBirthdayPickerImpl: (() -> Void)?
        let starsMode: ContactSelectionControllerMode = .starsGifting(birthdays: birthdays, hasActions: false, showSelf: false)
    
        let contactOptions: Signal<[ContactListAdditionalOption], NoError> = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Birthday(id: context.account.peerId))
        |> map { birthday in
            if birthday == nil {
                return [ContactListAdditionalOption(
                    title: presentationData.strings.Premium_Gift_ContactSelection_AddBirthday,
                    icon: .generic(UIImage(bundleImageName: "Contact List/AddBirthdayIcon")!),
                    action: {
                        presentBirthdayPickerImpl?()
                    },
                    clearHighlightAutomatically: true
                )]
            } else {
                return []
            }
        }
        |> deliverOnMainQueue
        
        let options = Promise<[StarsGiftOption]>()
        options.set(context.engine.payments.starsGiftOptions(peerId: nil))
        let controller = context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(
            context: context,
            mode: starsMode,
            autoDismiss: false,
            title: { strings in return strings.Stars_Purchase_GiftStars },
            options: contactOptions
        ))
        let _ = (controller.result
        |> deliverOnMainQueue).start(next: { result in
            if let (peers, _, _, _, _, _) = result, let contactPeer = peers.first, case let .peer(peer, _, _) = contactPeer {
                completion([peer.id])
            }
        })
                              
        presentBirthdayPickerImpl = { [weak controller] in
            guard let controller else {
                return
            }
            let _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: .setupBirthday).startStandalone()
                    
            let settingsPromise: Promise<AccountPrivacySettings?>
            if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface, let current = rootController.getPrivacySettings() {
                settingsPromise = current
            } else {
                settingsPromise = Promise()
                settingsPromise.set(.single(nil) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)))
            }
            let birthdayController = BirthdayPickerScreen(context: context, settings: settingsPromise.get(), openSettings: {
                context.sharedContext.makeBirthdayPrivacyController(context: context, settings: settingsPromise, openedFromBirthdayScreen: true, present: { [weak controller] c in
                    controller?.push(c)
                })
            }, completion: { [weak controller] value in
                let _ = context.engine.accountData.updateBirthday(birthday: value).startStandalone()
                
                controller?.present(UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: presentationData.strings.Birthday_Added, cancel: nil, destructive: false), elevatedLayout: false, action: { _ in
                    return true
                }), in: .current)
            })
            controller.push(birthdayController)
        }
        
        return controller
    }
    
    public func makePremiumGiftController(context: AccountContext, source: PremiumGiftSource, completion: (([EnginePeer.Id]) -> Void)?) -> ViewController {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }

        var presentExportAlertImpl: (() -> Void)?
        var presentTransferAlertImpl: ((EnginePeer) -> Void)?
        
        var presentBirthdayPickerImpl: (() -> Void)?
        var mode: ContactSelectionControllerMode = .generic
        var currentBirthdays: [EnginePeer.Id: TelegramBirthday]?
        
        if case let .starGiftTransfer(birthdays, _, _, _, _) = source {
            mode = .starsGifting(birthdays: birthdays, hasActions: false, showSelf: false)
            currentBirthdays = birthdays
        } else if case let .chatList(birthdays) = source {
            mode = .starsGifting(birthdays: birthdays, hasActions: true, showSelf: true)
            currentBirthdays = birthdays
        } else if case let .settings(birthdays) = source {
            mode = .starsGifting(birthdays: birthdays, hasActions: true, showSelf: true)
            currentBirthdays = birthdays
        } else {
            mode = .starsGifting(birthdays: nil, hasActions: true, showSelf: false)
        }
        
        let contactOptions: Signal<[ContactListAdditionalOption], NoError>
        if case let .starGiftTransfer(_, _, _, _, canExportDate) = source {
            var subtitle: String?
            if let canExportDate {
                let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
                if currentTime > canExportDate {
                    subtitle = nil
                } else {
                    let delta = canExportDate - currentTime
                    let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                    let daysString = presentationData.strings.Gift_Transfer_SendUnlocks_Days(days)
                    subtitle = presentationData.strings.Gift_Transfer_SendUnlocks(daysString).string
                }
                contactOptions = .single([
                    ContactListAdditionalOption(
                        title: presentationData.strings.Gift_Transfer_SendViaBlockchain,
                        subtitle: subtitle,
                        icon: .generic(UIImage(bundleImageName: "Item List/Ton")!),
                        style: .generic,
                        action: {
                            presentExportAlertImpl?()
                        },
                        clearHighlightAutomatically: true
                    )
                ])
            } else {
                contactOptions = .single([])
            }
        } else if currentBirthdays != nil || "".isEmpty {
            contactOptions = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.Birthday(id: context.account.peerId))
            |> map { birthday in
                if birthday == nil {
                    return [ContactListAdditionalOption(
                        title: presentationData.strings.Premium_Gift_ContactSelection_AddBirthday,
                        icon: .generic(UIImage(bundleImageName: "Contact List/AddBirthdayIcon")!),
                        action: {
                            presentBirthdayPickerImpl?()
                        },
                        clearHighlightAutomatically: true
                    )]
                } else {
                    return []
                }
            }
            |> deliverOnMainQueue
        } else {
            contactOptions = .single([])
        }
        
        var openProfileImpl: ((EnginePeer) -> Void)?
        var sendMessageImpl: ((EnginePeer) -> Void)?
        
        let title: String
        if case .starGiftTransfer = source {
            title = presentationData.strings.Gift_Transfer_Title
        } else {
            title = presentationData.strings.Gift_PremiumOrStars_Title
        }
        
        let options = Promise<[PremiumGiftCodeOption]>()
        options.set(context.engine.payments.premiumGiftCodeOptions(peerId: nil))
        let controller = context.sharedContext.makeContactSelectionController(ContactSelectionControllerParams(
            context: context,
            mode: mode,
            autoDismiss: false,
            title: { _ in return title },
            options: contactOptions,
            openProfile: { peer in
                openProfileImpl?(peer)
            },
            sendMessage: { peer in
                sendMessageImpl?(peer)
            }
        ))
        controller.navigationPresentation = .modal
        
        let _ = combineLatest(queue: Queue.mainQueue(), controller.result, options.get())
        .startStandalone(next: { [weak controller] result, options in
            if let (peers, _, _, _, _, _) = result, let contactPeer = peers.first, case let .peer(peer, _, _) = contactPeer, let starsContext = context.starsContext {
                if case .starGiftTransfer = source {
                    presentTransferAlertImpl?(EnginePeer(peer))
                } else {
                    let premiumOptions = options.filter { $0.users == 1 }.map { CachedPremiumGiftOption(months: $0.months, currency: $0.currency, amount: $0.amount, botUrl: "", storeProductId: $0.storeProductId) }
                    let giftController = GiftOptionsScreen(context: context, starsContext: starsContext, peerId: peer.id, premiumOptions: premiumOptions, hasBirthday: currentBirthdays?[peer.id] != nil)
                    giftController.navigationPresentation = .modal
                    controller?.push(giftController)
                }
            }
        })
        
        sendMessageImpl = { [weak self, weak controller] peer in
            guard let self, let controller, let navigationController = controller.navigationController as? NavigationController else {
                return
            }
            self.navigateToChatController(
                NavigateToChatControllerParams(
                    navigationController: navigationController,
                    context: context,
                    chatLocation: .peer(peer)
                )
            )
        }
        
        openProfileImpl = { [weak self, weak controller] peer in
            guard let self, let controller else {
                return
            }
            if let infoController = self.makePeerInfoController(
                context: context,
                updatedPresentationData: nil,
                peer: peer._asPeer(),
                mode: .generic,
                avatarInitiallyExpanded: peer.smallProfileImage != nil,
                fromChat: false,
                requestsContext: nil
            ) {
                controller.replace(with: infoController)
            }
        }
        
        presentBirthdayPickerImpl = { [weak controller] in
            guard let controller else {
                return
            }
            let _ = context.engine.notices.dismissServerProvidedSuggestion(suggestion: .setupBirthday).startStandalone()
                    
            let settingsPromise: Promise<AccountPrivacySettings?>
            if let rootController = context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface, let current = rootController.getPrivacySettings() {
                settingsPromise = current
            } else {
                settingsPromise = Promise()
                settingsPromise.set(.single(nil) |> then(context.engine.privacy.requestAccountPrivacySettings() |> map(Optional.init)))
            }
            let birthdayController = BirthdayPickerScreen(context: context, settings: settingsPromise.get(), openSettings: {
                context.sharedContext.makeBirthdayPrivacyController(context: context, settings: settingsPromise, openedFromBirthdayScreen: true, present: { [weak controller] c in
                    controller?.push(c)
                })
            }, completion: { [weak controller] value in
                let _ = context.engine.accountData.updateBirthday(birthday: value).startStandalone()
                
                controller?.present(UndoOverlayController(presentationData: presentationData, content: .actionSucceeded(title: nil, text: presentationData.strings.Birthday_Added, cancel: nil, destructive: false), elevatedLayout: false, action: { _ in
                    return true
                }), in: .current)
            })
            controller.push(birthdayController)
        }
        
        presentExportAlertImpl = { [weak controller] in
            guard let controller, case let .starGiftTransfer(_, _, _, _, canExportDate) = source, let canExportDate else {
                return
            }
            let currentTime = Int32(CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970)
            let title: String
            let text: String
            if currentTime > canExportDate {
                title = presentationData.strings.Gift_Transfer_UpdateRequired_Title
                text = presentationData.strings.Gift_Transfer_UpdateRequired_Text
            } else {
                let delta = canExportDate - currentTime
                let days: Int32 = Int32(ceil(Float(delta) / 86400.0))
                let daysString = presentationData.strings.Gift_Transfer_UnlockPending_Text_Days(days)
                title = presentationData.strings.Gift_Transfer_UnlockPending_Title
                text = presentationData.strings.Gift_Transfer_UnlockPending_Text(daysString).string
            }
            let alertController = textAlertController(context: context, title: title, text: text, actions: [
                TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})
            ])
            controller.present(alertController, in: .window(.root))
        }
        
        presentTransferAlertImpl = { [weak controller] peer in
            guard let controller, case let .starGiftTransfer(_, _, gift, transferStars, _) = source else {
                return
            }
            let alertController = giftTransferAlertController(context: context, gift: gift, peer: peer, transferStars: transferStars, commit: { [weak controller] in
                completion?([peer.id])
                
                guard let controller, let navigationController = controller.navigationController as? NavigationController else {
                    return
                }
                var controllers = navigationController.viewControllers
                controllers = controllers.filter { !($0 is ContactSelectionController) }
                var foundController = false
                for controller in controllers.reversed() {
                    if let chatController = controller as? ChatController, case .peer(id: peer.id) = chatController.chatLocation {
                        chatController.hintPlayNextOutgoingGift()
                        foundController = true
                        break
                    }
                }
                if !foundController {
                    let chatController = context.sharedContext.makeChatController(context: context, chatLocation: .peer(id: peer.id), subject: nil, botStart: nil, mode: .standard(.default), params: nil)
                    chatController.hintPlayNextOutgoingGift()
                    controllers.append(chatController)
                }
                navigationController.setViewControllers(controllers, animated: true)
                
                Queue.mainQueue().after(0.3) {
                    let tooltipController = UndoOverlayController(
                        presentationData: presentationData,
                        content: .forward(savedMessages: false, text: presentationData.strings.Gift_Transfer_Success("\(gift.title) #\(gift.number)", peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string),
                        elevatedLayout: false,
                        action: { _ in return true }
                    )
                    if let lastController = controllers.last as? ViewController {
                        lastController.present(tooltipController, in: .window(.root))
                    }
                }
            })
            controller.present(alertController, in: .window(.root))
        }
        
        return controller
    }
    
    public func makeGiftOptionsController(context: AccountContext, peerId: EnginePeer.Id, premiumOptions: [CachedPremiumGiftOption], hasBirthday: Bool) -> ViewController {
        guard let starsContext = context.starsContext else {
            fatalError()
        }
        let controller = GiftOptionsScreen(context: context, starsContext: starsContext, peerId: peerId, premiumOptions: premiumOptions, hasBirthday: hasBirthday)
        controller.navigationPresentation = .modal
        return controller
    }
    
    public func makePremiumPrivacyControllerController(context: AccountContext, subject: PremiumPrivacySubject, peerId: EnginePeer.Id) -> ViewController {
        let mappedSubject: PremiumPrivacyScreen.Subject
        let introSource: PremiumIntroSource
        
        switch subject {
        case .presence:
            mappedSubject = .presence
            introSource = .presence
        case .readTime:
            mappedSubject = .readTime
            introSource = .presence
        }
        
        var actionImpl: (() -> Void)?
        var openPremiumIntroImpl: (() -> Void)?
        
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let controller = PremiumPrivacyScreen(
            context: context,
            peerId: peerId,
            subject: mappedSubject,
            action: {
                actionImpl?()
            }, openPremiumIntro: {
                openPremiumIntroImpl?()
            }
        )
        actionImpl = { [weak controller] in
            guard let parentController = controller, let navigationController = parentController.navigationController as? NavigationController else {
                return
            }
            
            let currentPrivacy = Promise<AccountPrivacySettings>()
            currentPrivacy.set(context.engine.privacy.requestAccountPrivacySettings())
            
            let tooltipText: String
            
            switch subject {
            case .presence:
                tooltipText = presentationData.strings.Settings_Privacy_LastSeenRevealedToast
                
                let _ = (currentPrivacy.get()
                |> take(1)
                |> mapToSignal { current in
                    let presence = current.presence
                    var disabledFor: [PeerId: SelectivePrivacyPeer] = [:]
                    switch presence {
                    case let .enableEveryone(disabledForValue), let .enableContacts(_, disabledForValue, _, _):
                        disabledFor = disabledForValue
                    default:
                        break
                    }
                    disabledFor.removeValue(forKey: peerId)
                    
                    return context.engine.privacy.updateSelectiveAccountPrivacySettings(type: .presence, settings: .enableEveryone(disableFor: disabledFor))
                }
                |> deliverOnMainQueue).startStandalone(completed: { [weak navigationController] in
                    let _ = context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peerId).startStandalone()
                    
                    if let parentController = navigationController?.viewControllers.last as? ViewController {
                        parentController.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: tooltipText, timeout: 4.0, customUndoText: nil), elevatedLayout: false, action: { _ in
                            return true
                        }), in: .window(.root))
                    }
                })
            case .readTime:
                tooltipText = presentationData.strings.Settings_Privacy_MessageReadTimeRevealedToast
                
                let _ = (currentPrivacy.get()
                |> take(1)
                |> mapToSignal { current in
                    var settings = current.globalSettings
                    settings.hideReadTime = false
                    return context.engine.privacy.updateGlobalPrivacySettings(settings: settings)
                }
                |> deliverOnMainQueue).startStandalone(completed: { [weak navigationController] in
                    if let parentController = navigationController?.viewControllers.last as? ViewController {
                        parentController.present(UndoOverlayController(presentationData: presentationData, content: .info(title: nil, text: tooltipText, timeout: 4.0, customUndoText: nil), elevatedLayout: false, action: { _ in
                            return true
                        }), in: .window(.root))
                    }
                })
            }
        }
        openPremiumIntroImpl = { [weak controller] in
            guard let parentController = controller else {
                return
            }
            let controller = context.sharedContext.makePremiumIntroController(context: context, source: introSource, forceDark: false, dismissed: nil)
            parentController.push(controller)
        }
                
        return controller
    }
    
    public func makePremiumBoostLevelsController(context: AccountContext, peerId: EnginePeer.Id, subject: BoostSubject, boostStatus: ChannelBoostStatus, myBoostStatus: MyBoostStatus, forceDark: Bool, openStats: (() -> Void)?) -> ViewController {
        let premiumConfiguration = PremiumConfiguration.with(appConfiguration: context.currentAppConfiguration.with { $0 })
        
        var pushImpl: ((ViewController) -> Void)?
        var dismissImpl: (() -> Void)?
        let controller = PremiumBoostLevelsScreen(
            context: context,
            peerId: peerId,
            mode: .owner(subject: subject),
            status: boostStatus,
            myBoostStatus: myBoostStatus,
            openStats: openStats,
            openGift: premiumConfiguration.giveawayGiftsPurchaseAvailable ? {
                var updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
                if forceDark {
                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }.withUpdated(theme: defaultDarkColorPresentationTheme)
                    updatedPresentationData = (presentationData, .single(presentationData))
                }
                let controller = createGiveawayController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, subject: .generic)
                pushImpl?(controller)
                
                Queue.mainQueue().after(0.4) {
                    dismissImpl?()
                }
            } : nil,
            forceDark: forceDark
        )
        pushImpl = { [weak controller] c in
            controller?.push(c)
        }
        dismissImpl = { [weak controller] in
            if let controller, let navigationController = controller.navigationController as? NavigationController {
                navigationController.setViewControllers(navigationController.viewControllers.filter { !($0 is PremiumBoostLevelsScreen) }, animated: false)
            }
        }
        return controller
    }
    
    public func makeStickerPackScreen(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, mainStickerPack: StickerPackReference, stickerPacks: [StickerPackReference], loadedStickerPacks: [LoadedStickerPack], actionTitle: String?, isEditing: Bool, expandIfNeeded: Bool, parentNavigationController: NavigationController?, sendSticker: ((FileMediaReference, UIView, CGRect) -> Bool)?, actionPerformed: ((Bool) -> Void)?) -> ViewController {
        return StickerPackScreen(context: context, updatedPresentationData: updatedPresentationData, mainStickerPack: mainStickerPack, stickerPacks: stickerPacks, loadedStickerPacks: loadedStickerPacks, actionTitle: actionTitle, isEditing: isEditing, expandIfNeeded: expandIfNeeded, parentNavigationController: parentNavigationController, sendSticker: sendSticker, actionPerformed: { actions in
            if let (_, _, action) = actions.first {
                switch action {
                case .add:
                    actionPerformed?(true)
                case .remove:
                    actionPerformed?(false)
                }
            }
        })
    }
    
    public func makeBotPreviewEditorScreen(context: AccountContext, source: Any?, target: Stories.PendingTarget, transitionArguments: (UIView, CGRect, UIImage?)?, transitionOut: @escaping () -> BotPreviewEditorTransitionOut?, externalState: MediaEditorTransitionOutExternalState, completion: @escaping (MediaEditorScreenResult, @escaping (@escaping () -> Void) -> Void) -> Void, cancelled: @escaping () -> Void) -> ViewController {
        let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
        if let asset = source as? PHAsset {
            subject = .single(.asset(asset))
        } else if let image = source as? UIImage {
            subject = .single(.image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .bottomRight))
        } else {
            subject = .single(.empty(PixelDimensions(width: 1080, height: 1920)))
        }
        let editorController = MediaEditorScreenImpl(
            context: context,
            mode: .botPreview,
            subject: subject,
            customTarget: nil,
            transitionIn: transitionArguments.flatMap { .gallery(
                MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
                    sourceView: $0.0,
                    sourceRect: $0.1,
                    sourceImage: $0.2
                )
            ) },
            transitionOut: { finished, isNew in
                if !finished, let transitionArguments {
                    return MediaEditorScreenImpl.TransitionOut(
                        destinationView: transitionArguments.0,
                        destinationRect: transitionArguments.0.bounds,
                        destinationCornerRadius: 0.0
                    )
                } else if finished, let transitionOut = transitionOut(), let destinationView = transitionOut.destinationView {
                    return MediaEditorScreenImpl.TransitionOut(
                        destinationView: destinationView,
                        destinationRect: transitionOut.destinationRect,
                        destinationCornerRadius: transitionOut.destinationCornerRadius,
                        completion: transitionOut.completion
                    )
                }
                return nil
            }, completion: { result, commit in
                completion(result, commit)
            } as (MediaEditorScreenImpl.Result, @escaping (@escaping () -> Void) -> Void) -> Void
        )
        editorController.cancelled = { _ in
            cancelled()
        }
        return editorController
    }
    
    public func makeStickerEditorScreen(context: AccountContext, source: Any?, intro: Bool, transitionArguments: (UIView, CGRect, UIImage?)?, completion: @escaping (TelegramMediaFile, [String], @escaping () -> Void) -> Void, cancelled: @escaping () -> Void) -> ViewController {
        let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
        var mode: MediaEditorScreenImpl.Mode.StickerEditorMode
        var fromCamera = false
        if let (file, emoji) = source as? (TelegramMediaFile, [String]) {
            subject = .single(.sticker(file, emoji))
            mode = .editing
        } else if let asset = source as? PHAsset {
            subject = .single(.asset(asset))
            mode = .addingToPack
        } else if let image = source as? UIImage {
            subject = .single(.image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .bottomRight))
            mode = .addingToPack
        } else if let source = source as? Signal<CameraScreenImpl.Result, NoError> {
            subject = source
            |> map { value -> MediaEditorScreenImpl.Subject? in
                switch value {
                case .pendingImage:
                    return nil
                case let .image(image):
                    return .image(image: image.image, dimensions: PixelDimensions(image.image.size), additionalImage: nil, additionalImagePosition: .topLeft)
                default:
                    return nil
                }
            }
            fromCamera = true
            mode = .addingToPack
        } else {
            subject = .single(.empty(PixelDimensions(width: 1080, height: 1920)))
            mode = .addingToPack
        }
        if intro {
            mode = .businessIntro
        }
        let editorController = MediaEditorScreenImpl(
            context: context,
            mode: .stickerEditor(mode: mode),
            subject: subject,
            transitionIn: fromCamera ? .camera : transitionArguments.flatMap { .gallery(
                MediaEditorScreenImpl.TransitionIn.GalleryTransitionIn(
                    sourceView: $0.0,
                    sourceRect: $0.1,
                    sourceImage: $0.2
                )
            ) },
            transitionOut: { finished, isNew in
                if !finished, let transitionArguments {
                    return MediaEditorScreenImpl.TransitionOut(
                        destinationView: transitionArguments.0,
                        destinationRect: transitionArguments.0.bounds,
                        destinationCornerRadius: 0.0
                    )
                }
                return nil
            }, completion: { result, commit in
                if case let .sticker(file, emoji) = result.media {
                    completion(file, emoji, {
                        commit({})
                    })
                }
            } as (MediaEditorScreenImpl.Result, @escaping (@escaping () -> Void) -> Void) -> Void
        )
        editorController.cancelled = { _ in
            cancelled()
        }
        return editorController
    }
        
    public func makeStoryMediaEditorScreen(context: AccountContext, source: Any?, text: String?, link: (url: String, name: String?)?, completion: @escaping (MediaEditorScreenResult, @escaping (@escaping () -> Void) -> Void) -> Void) -> ViewController {
        let subject: Signal<MediaEditorScreenImpl.Subject?, NoError>
        if let image = source as? UIImage {
            subject = .single(.image(image: image, dimensions: PixelDimensions(image.size), additionalImage: nil, additionalImagePosition: .bottomRight))
        } else if let path = source as? String {
            subject = .single(.video(videoPath: path, thumbnail: nil, mirror: false, additionalVideoPath: nil, additionalThumbnail: nil, dimensions: PixelDimensions(width: 1080, height: 1920), duration: 0.0, videoPositionChanges: [], additionalVideoPosition: .bottomRight))
        } else {
            subject = .single(.empty(PixelDimensions(width: 1080, height: 1920)))
        }
        let editorController = MediaEditorScreenImpl(
            context: context,
            mode: .storyEditor,
            subject: subject,
            customTarget: nil,
            initialCaption: text.flatMap { NSAttributedString(string: $0) },
            initialLink: link,
            transitionIn: nil,
            transitionOut: { finished, isNew in
                return nil
            }, completion: { result, commit in
                completion(result, commit)
            } as (MediaEditorScreenImpl.Result, @escaping (@escaping () -> Void) -> Void) -> Void
        )
//        editorController.cancelled = { _ in
//            cancelled()
//        }
        return editorController
    }
    
    public func makeMediaPickerScreen(context: AccountContext, hasSearch: Bool, completion: @escaping (Any) -> Void) -> ViewController {
        return mediaPickerController(context: context, hasSearch: hasSearch, completion: completion)
    }
    
    public func makeStoryMediaPickerScreen(context: AccountContext, isDark: Bool, forCollage: Bool, selectionLimit: Int?, getSourceRect: @escaping () -> CGRect, completion: @escaping (Any, UIView, CGRect, UIImage?, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void, multipleCompletion: @escaping ([Any]) -> Void, dismissed: @escaping () -> Void, groupsPresented: @escaping () -> Void) -> ViewController {
        return storyMediaPickerController(context: context, isDark: isDark, forCollage: forCollage, selectionLimit: selectionLimit, getSourceRect: getSourceRect, completion: completion, multipleCompletion: multipleCompletion, dismissed: dismissed, groupsPresented: groupsPresented)
    }
    
    public func makeStickerMediaPickerScreen(context: AccountContext, getSourceRect: @escaping () -> CGRect?, completion: @escaping (Any?, UIView?, CGRect, UIImage?, Bool, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void, dismissed: @escaping () -> Void) -> ViewController {
        return stickerMediaPickerController(context: context, getSourceRect: getSourceRect, completion: completion, dismissed: dismissed)
    }
    
    public func makeAvatarMediaPickerScreen(context: AccountContext, getSourceRect: @escaping () -> CGRect?, canDelete: Bool, performDelete: @escaping () -> Void, completion: @escaping (Any?, UIView?, CGRect, UIImage?, Bool, @escaping (Bool?) -> (UIView, CGRect)?, @escaping () -> Void) -> Void, dismissed: @escaping () -> Void) -> ViewController {
        return avatarMediaPickerController(context: context, getSourceRect: getSourceRect, canDelete: canDelete, performDelete: performDelete, completion: completion, dismissed: dismissed)
    }

    public func makeStickerPickerScreen(context: AccountContext, inputData: Promise<StickerPickerInput>, completion: @escaping (FileMediaReference) -> Void) -> ViewController {
        let controller = StickerPickerScreen(context: context, inputData: inputData.get(), expanded: true, hasGifs: false, hasInteractiveStickers: false)
        controller.completion = { content in
            if let content, case let .file(file, _) = content {
                completion(file)
            }
            return true
        }
        return controller
    }
        
    public func makeProxySettingsController(sharedContext: SharedAccountContext, account: UnauthorizedAccount) -> ViewController {
        return proxySettingsController(accountManager: sharedContext.accountManager, sharedContext: sharedContext, postbox: account.postbox, network: account.network, mode: .modal, presentationData: sharedContext.currentPresentationData.with { $0 }, updatedPresentationData: sharedContext.presentationData)
    }
    
    public func makeDataAndStorageController(context: AccountContext, sensitiveContent: Bool) -> ViewController {
        return dataAndStorageController(context: context, focusOnItemTag: sensitiveContent ? DataAndStorageEntryTag.sensitiveContent : nil)
    }
    
    public func makeInstalledStickerPacksController(context: AccountContext, mode: InstalledStickerPacksControllerMode, forceTheme: PresentationTheme?) -> ViewController {
        return installedStickerPacksController(context: context, mode: mode, forceTheme: forceTheme)
    }
    
    public func makeChannelStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peerId: EnginePeer.Id, boosts: Bool, boostStatus: ChannelBoostStatus?) -> ViewController {
        return channelStatsController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, section: boosts ? .boosts : .stats, boostStatus: boostStatus)
    }
    
    public func makeMessagesStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, messageId: EngineMessage.Id) -> ViewController {
        return messageStatsController(context: context, updatedPresentationData: updatedPresentationData, subject: .message(id: messageId))
    }
    
    public func makeStoryStatsController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, peerId: EnginePeer.Id, storyId: Int32, storyItem: EngineStoryItem, fromStory: Bool) -> ViewController {
        return messageStatsController(context: context, updatedPresentationData: updatedPresentationData, subject: .story(peerId: peerId, id: storyId, item: storyItem, fromStory: fromStory))
    }
    
    public func makeStarsTransactionsScreen(context: AccountContext, starsContext: StarsContext) -> ViewController {
        return StarsTransactionsScreen(context: context, starsContext: starsContext)
    }
    
    public func makeStarsPurchaseScreen(context: AccountContext, starsContext: StarsContext, options: [Any], purpose: StarsPurchasePurpose, completion: @escaping (Int64) -> Void) -> ViewController {
        return StarsPurchaseScreen(context: context, starsContext: starsContext, options: options, purpose: purpose, completion: completion)
    }
        
    public func makeStarsTransferScreen(context: AccountContext, starsContext: StarsContext, invoice: TelegramMediaInvoice, source: BotPaymentInvoiceSource, extendedMedia: [TelegramExtendedMedia], inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>, completion: @escaping (Bool) -> Void) -> ViewController {
        return StarsTransferScreen(context: context, starsContext: starsContext, invoice: invoice, source: source, extendedMedia: extendedMedia, inputData: inputData, completion: completion)
    }
    
    public func makeStarsSubscriptionTransferScreen(context: AccountContext, starsContext: StarsContext, invoice: TelegramMediaInvoice, link: String, inputData: Signal<(StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)?, NoError>, navigateToPeer: @escaping (EnginePeer) -> Void) -> ViewController {
        return StarsTransferScreen(context: context, starsContext: starsContext, invoice: invoice, source: .starsChatSubscription(hash: link), extendedMedia: [], inputData: inputData, navigateToPeer: navigateToPeer, completion: { _ in })
    }
    
    public func makeStarsTransactionScreen(context: AccountContext, transaction: StarsContext.State.Transaction, peer: EnginePeer) -> ViewController {
        return StarsTransactionScreen(context: context, subject: .transaction(transaction, peer))
    }
    
    public func makeStarsReceiptScreen(context: AccountContext, receipt: BotPaymentReceipt) -> ViewController {
        return StarsTransactionScreen(context: context, subject: .receipt(receipt))
    }
    
    public func makeStarsSubscriptionScreen(context: AccountContext, subscription: StarsContext.State.Subscription, update: @escaping (Bool) -> Void) -> ViewController {
        return StarsTransactionScreen(context: context, subject: .subscription(subscription), updateSubscription: update)
    }
    
    public func makeStarsSubscriptionScreen(context: AccountContext, peer: EnginePeer, pricing: StarsSubscriptionPricing, importer: PeerInvitationImportersState.Importer, usdRate: Double) -> ViewController {
        return StarsTransactionScreen(context: context, subject: .importer(peer, pricing, importer, usdRate))
    }
    
    public func makeStarsStatisticsScreen(context: AccountContext, peerId: EnginePeer.Id, revenueContext: StarsRevenueStatsContext) -> ViewController {
        return StarsStatisticsScreen(context: context, peerId: peerId, revenueContext: revenueContext)
    }
    
    public func makeStarsAmountScreen(context: AccountContext, initialValue: Int64?, completion: @escaping (Int64) -> Void) -> ViewController {
        return StarsWithdrawScreen(context: context, mode: .paidMedia(initialValue), completion: completion)
    }
    
    public func makeStarsWithdrawalScreen(context: AccountContext, stats: StarsRevenueStats, completion: @escaping (Int64) -> Void) -> ViewController {
        return StarsWithdrawScreen(context: context, mode: .withdraw(stats), completion: completion)
    }
    
    public func makeStarsGiftScreen(context: AccountContext, message: EngineMessage) -> ViewController {
        return StarsTransactionScreen(context: context, subject: .gift(message))
    }
    
    public func makeStarsGiveawayBoostScreen(context: AccountContext, peerId: EnginePeer.Id, boost: ChannelBoostersContext.State.Boost) -> ViewController {
        return StarsTransactionScreen(context: context, subject: .boost(peerId, boost))
    }
    
    public func makeStarsIntroScreen(context: AccountContext) -> ViewController {
        return StarsIntroScreen(context: context)
    }
    
    public func makeGiftViewScreen(context: AccountContext, message: EngineMessage) -> ViewController {
        return GiftViewScreen(context: context, subject: .message(message))
    }
    
    public func makeContentReportScreen(context: AccountContext, subject: ReportContentSubject, forceDark: Bool, present: @escaping (ViewController) -> Void, completion: @escaping () -> Void, requestSelectMessages: ((String, Data, String?) -> Void)?) {
        let _ = (context.engine.messages.reportContent(subject: subject, option: nil, message: nil)
        |> deliverOnMainQueue).startStandalone(next: { result in
            if case let .options(title, options) = result {
                present(ContentReportScreen(context: context, subject: subject, title: title, options: options, forceDark: forceDark, completed: completion, requestSelectMessages: requestSelectMessages))
            }
        })
    }
    
    public func makeMiniAppListScreenInitialData(context: AccountContext) -> Signal<MiniAppListScreenInitialData, NoError> {
        return MiniAppListScreen.initialData(context: context)
    }
    
    public func makeMiniAppListScreen(context: AccountContext, initialData: MiniAppListScreenInitialData) -> ViewController {
        return MiniAppListScreen(context: context, initialData: initialData as! MiniAppListScreen.InitialData)
    }
    
    public func openWebApp(context: AccountContext, parentController: ViewController, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?, botPeer: EnginePeer, chatPeer: EnginePeer?, threadId: Int64?, buttonText: String, url: String, simple: Bool, source: ChatOpenWebViewSource, skipTermsOfService: Bool, payload: String?) {
        openWebAppImpl(context: context, parentController: parentController, updatedPresentationData: updatedPresentationData, botPeer: botPeer, chatPeer: chatPeer, threadId: threadId, buttonText: buttonText, url: url, simple: simple, source: source, skipTermsOfService: skipTermsOfService, payload: payload)
    }
    
    public func makeAffiliateProgramSetupScreenInitialData(context: AccountContext, peerId: EnginePeer.Id, mode: AffiliateProgramSetupScreenMode) -> Signal<AffiliateProgramSetupScreenInitialData, NoError> {
        return AffiliateProgramSetupScreen.content(context: context, peerId: peerId, mode: mode)
    }
    
    public func makeAffiliateProgramSetupScreen(context: AccountContext, initialData: AffiliateProgramSetupScreenInitialData) -> ViewController {
        return AffiliateProgramSetupScreen(context: context, initialContent: initialData)
    }
    
    public func makeAffiliateProgramJoinScreen(context: AccountContext, sourcePeer: EnginePeer, commissionPermille: Int32, programDuration: Int32?, revenuePerUser: Double, mode: JoinAffiliateProgramScreenMode) -> ViewController {
        return JoinAffiliateProgramScreen(context: context, sourcePeer: sourcePeer, commissionPermille: commissionPermille, programDuration: programDuration, revenuePerUser: revenuePerUser, mode: mode)
    }
    
    public func makeGalleryController(context: AccountContext, source: GalleryControllerItemSource, streamSingleVideo: Bool, isPreview: Bool) -> ViewController {
        let controller = GalleryController(context: context, source: source, streamSingleVideo: streamSingleVideo, replaceRootController: { _, _ in
        }, baseNavigationController: nil)
        if isPreview {
            controller.setHintWillBePresentedInPreviewingContext(true)
        }
        return controller
    }
}

private func peerInfoControllerImpl(context: AccountContext, updatedPresentationData: (PresentationData, Signal<PresentationData, NoError>)?, peer: Peer, mode: PeerInfoControllerMode, avatarInitiallyExpanded: Bool, isOpenedFromChat: Bool, requestsContext: PeerInvitationImportersContext? = nil) -> ViewController? {
    if let _ = peer as? TelegramGroup {
        return PeerInfoScreenImpl(context: context, updatedPresentationData: updatedPresentationData, peerId: peer.id, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, nearbyPeerDistance: nil, reactionSourceMessageId: nil, callMessages: [])
    } else if let _ = peer as? TelegramChannel {
        var forumTopicThread: ChatReplyThreadMessage?
        var switchToRecommendedChannels = false
        switch mode {
        case let .forumTopic(thread):
            forumTopicThread = thread
        case .recommendedChannels:
            switchToRecommendedChannels = true
        default:
            break
        }
        return PeerInfoScreenImpl(context: context, updatedPresentationData: updatedPresentationData, peerId: peer.id, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, nearbyPeerDistance: nil, reactionSourceMessageId: nil, callMessages: [], forumTopicThread: forumTopicThread, switchToRecommendedChannels: switchToRecommendedChannels)
    } else if peer is TelegramUser {
        var nearbyPeerDistance: Int32?
        var reactionSourceMessageId: MessageId?
        var callMessages: [Message] = []
        var hintGroupInCommon: PeerId?
        var forumTopicThread: ChatReplyThreadMessage?
        var isMyProfile = false
        var switchToGifts = false
        
        switch mode {
        case let .nearbyPeer(distance):
            nearbyPeerDistance = distance
        case let .calls(messages):
            callMessages = messages
        case .generic:
            break
        case let .group(id):
            hintGroupInCommon = id
        case let .reaction(messageId):
            reactionSourceMessageId = messageId
        case let .forumTopic(thread):
            forumTopicThread = thread
        case .myProfile:
            isMyProfile = true
        case .myProfileGifts:
            isMyProfile = true
            switchToGifts = true
        default:
            break
        }
        return PeerInfoScreenImpl(context: context, updatedPresentationData: updatedPresentationData, peerId: peer.id, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, nearbyPeerDistance: nearbyPeerDistance, reactionSourceMessageId: reactionSourceMessageId, callMessages: callMessages, isMyProfile: isMyProfile, hintGroupInCommon: hintGroupInCommon, forumTopicThread: forumTopicThread, switchToGifts: switchToGifts)
    } else if peer is TelegramSecretChat {
        return PeerInfoScreenImpl(context: context, updatedPresentationData: updatedPresentationData, peerId: peer.id, avatarInitiallyExpanded: avatarInitiallyExpanded, isOpenedFromChat: isOpenedFromChat, nearbyPeerDistance: nil, reactionSourceMessageId: nil, callMessages: [])
    }
    return nil
}
