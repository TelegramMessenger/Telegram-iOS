import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ShareController
import LegacyUI
import PeerInfoUI
import ShareItems
import ShareItemsImpl
import SettingsUI
import OpenSSLEncryptionProvider
import AppLock
import Intents
import MobileCoreServices
import OverlayStatusController
import PresentationDataUtils
import ChatImportUI
import ZipArchive
import ActivityIndicator
import DebugSettingsUI
import ManagedFile
import TelegramUIDeclareEncodables
import AnimationCache
import MultiAnimationRenderer
import TelegramUIDeclareEncodables
import TelegramAccountAuxiliaryMethods
import PeerSelectionController
import ContextMenuScreen

private var installedSharedLogger = false

private func setupSharedLogger(rootPath: String, path: String) {
    if !installedSharedLogger {
        installedSharedLogger = true
        Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: path))
    }
}

private enum ShareAuthorizationError {
    case unauthorized
}

private final class ShareControllerEnvironmentExtension: ShareControllerEnvironment {
    let presentationData: PresentationData
    var updatedPresentationData: Signal<PresentationData, NoError> {
        return .single(self.presentationData)
    }
    var isMainApp: Bool {
        return false
    }
    var energyUsageSettings: EnergyUsageSettings {
        return .default
    }
    
    var mediaManager: MediaManager? {
        return nil
    }
    
    var accounts: [ShareControllerAccountContextExtension] = []
    
    init(presentationData: PresentationData) {
        self.presentationData = presentationData
    }
    
    func setAccountUserInterfaceInUse(id: AccountRecordId) -> Disposable {
        if let account = self.accounts.first(where: { $0.accountId == id }) {
            let shouldKeepConnection = account.stateManager.network.shouldKeepConnection
            shouldKeepConnection.set(.single(true))
            return ActionDisposable {
                shouldKeepConnection.set(.single(false))
            }
        } else {
            return EmptyDisposable
        }
    }
    
    func donateSendMessageIntent(account: ShareControllerAccountContext, peerIds: [EnginePeer.Id]) {
    }
}

private final class ShareControllerAccountContextExtension: ShareControllerAccountContext {
    let accountId: AccountRecordId
    let accountPeerId: EnginePeer.Id
    let stateManager: AccountStateManager
    let engineData: TelegramEngine.EngineData
    let animationCache: AnimationCache
    let animationRenderer: MultiAnimationRenderer
    let contentSettings: ContentSettings
    let appConfiguration: AppConfiguration
    
    init(
        accountId: AccountRecordId,
        stateManager: AccountStateManager,
        contentSettings: ContentSettings,
        appConfiguration: AppConfiguration
    ) {
        self.accountId = accountId
        self.accountPeerId = stateManager.accountPeerId
        self.stateManager = stateManager
        self.engineData = TelegramEngine.EngineData(accountPeerId: stateManager.accountPeerId, postbox: stateManager.postbox)
        let cacheStorageBox = stateManager.postbox.mediaBox.cacheStorageBox
        self.animationCache = AnimationCacheImpl(basePath: stateManager.postbox.mediaBox.basePath + "/animation-cache", allocateTempFile: {
            return TempBox.shared.tempFile(fileName: "file").path
        }, updateStorageStats: { path, size in
            if let pathData = path.data(using: .utf8) {
                cacheStorageBox.update(id: pathData, size: size)
            }
        })
        self.animationRenderer = MultiAnimationRendererImpl()
        self.contentSettings = contentSettings
        self.appConfiguration = appConfiguration
    }
    
    func resolveInlineStickers(fileIds: [Int64]) -> Signal<[Int64: TelegramMediaFile], NoError> {
        return _internal_resolveInlineStickers(postbox: self.stateManager.postbox, network: self.stateManager.network, fileIds: fileIds)
    }
}

public struct ShareRootControllerInitializationData {
    public let appBundleId: String
    public let appBuildType: TelegramAppBuildType
    public let appGroupPath: String
    public let apiId: Int32
    public let apiHash: String
    public let languagesCategory: String
    public let encryptionParameters: (Data, Data)
    public let appVersion: String
    public let bundleData: Data?
    public let useBetaFeatures: Bool
    public let makeTempContext: (AccountManager<TelegramAccountManagerTypes>, AppLockContext, TelegramApplicationBindings, InitialPresentationDataAndSettings, NetworkInitializationArguments) -> Signal<AccountContext, NoError>
    
    public init(appBundleId: String, appBuildType: TelegramAppBuildType, appGroupPath: String, apiId: Int32, apiHash: String, languagesCategory: String, encryptionParameters: (Data, Data), appVersion: String, bundleData: Data?, useBetaFeatures: Bool, makeTempContext: @escaping (AccountManager<TelegramAccountManagerTypes>, AppLockContext, TelegramApplicationBindings, InitialPresentationDataAndSettings, NetworkInitializationArguments) -> Signal<AccountContext, NoError>) {
        self.appBundleId = appBundleId
        self.appBuildType = appBuildType
        self.appGroupPath = appGroupPath
        self.apiId = apiId
        self.apiHash = apiHash
        self.languagesCategory = languagesCategory
        self.encryptionParameters = encryptionParameters
        self.appVersion = appVersion
        self.bundleData = bundleData
        self.useBetaFeatures = useBetaFeatures
        self.makeTempContext = makeTempContext
    }
}

private func extractTextFileHeader(path: String) -> String? {
    guard let file = ManagedFile(queue: nil, path: path, mode: .read) else {
        return nil
    }
    guard let size = file.getSize() else {
        return nil
    }
    
    let limit: Int64 = 3000
    
    var data = file.readData(count: Int(min(size, limit)))
    let additionalCapacity = min(10, max(0, Int(size) - data.count))
    
    for alignment in 0 ... additionalCapacity {
        if alignment != 0 {
            data.append(file.readData(count: 1))
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        } else {
            continue
        }
    }
    return nil
}

public class ShareRootControllerImpl {
    private let initializationData: ShareRootControllerInitializationData
    private let getExtensionContext: () -> NSExtensionContext?
    
    private var mainWindow: Window1?
    private var currentShareController: ShareController?
    private var currentPasscodeController: ViewController?
    
    private let disposable = MetaDisposable()
    private var observer1: AnyObject?
    private var observer2: AnyObject?
    
    private weak var navigationController: NavigationController?
    
    public var openUrl: (String) -> Void = { _ in }
    
    public init(initializationData: ShareRootControllerInitializationData, getExtensionContext: @escaping () -> NSExtensionContext?) {
        self.initializationData = initializationData
        self.getExtensionContext = getExtensionContext
    }
    
    deinit {
        self.disposable.dispose()
        if let observer = self.observer1 {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = self.observer2 {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public func loadView() {
        telegramUIDeclareEncodables()
    }
    
    public func viewWillAppear() {
    }
    
    public func viewWillDisappear() {
        self.disposable.dispose()
    }
    
    public func viewDidLayoutSubviews(view: UIView, traitCollection: UITraitCollection) {
        if self.mainWindow == nil {
            let mainWindow = Window1(hostView: childWindowHostView(parent: view), statusBarHost: nil)
            mainWindow.hostView.eventView.backgroundColor = UIColor.clear
            mainWindow.hostView.eventView.isHidden = false
            self.mainWindow = mainWindow
            
            let bounds = view.bounds
            
            view.addSubview(mainWindow.hostView.containerView)
            mainWindow.hostView.containerView.frame = bounds
            
            let rootPath = rootPathForBasePath(self.initializationData.appGroupPath)
            performAppGroupUpgrades(appGroupPath: self.initializationData.appGroupPath, rootPath: rootPath)
            
            TempBox.initializeShared(basePath: rootPath, processType: "share", launchSpecificId: Int64.random(in: Int64.min ... Int64.max))
            
            let logsPath = rootPath + "/logs/share-logs"
            let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
            
            setupSharedLogger(rootPath: rootPath, path: logsPath)
            
            let applicationBindings = TelegramApplicationBindings(isMainApp: false, appBundleId: self.initializationData.appBundleId, appBuildType: self.initializationData.appBuildType, containerPath: self.initializationData.appGroupPath, appSpecificScheme: "tg", openUrl: { [weak self] url in
                self?.openUrl(url)
            }, openUniversalUrl: { _, completion in
                completion.completion(false)
                return
            }, canOpenUrl: { _ in
                return false
            }, getTopWindow: {
                return nil
            }, displayNotification: { _ in
                
            }, applicationInForeground: .single(false), applicationIsActive: .single(false), clearMessageNotifications: { _ in
            }, pushIdleTimerExtension: {
                return EmptyDisposable
            }, openSettings: {
            }, openAppStorePage: {
            }, openSubscriptions: {
            }, registerForNotifications: { _ in }, requestSiriAuthorization: { _ in }, siriAuthorization: { return .notDetermined }, getWindowHost: {
                return nil
            }, presentNativeController: { _ in
            }, dismissNativeController: {
            }, getAvailableAlternateIcons: {
                return []
            }, getAlternateIconName: {
                return nil
            }, requestSetAlternateIconName: { _, f in
                f(false)
            }, forceOrientation: { _ in
            })
            
            let accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: rootPath + "/accounts-metadata", isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: false)
            initializeAccountManagement()
            
            do {
                let semaphore = DispatchSemaphore(value: 0)
                var loggingSettings = LoggingSettings.defaultSettings
                if self.initializationData.appBuildType == .internal {
                    loggingSettings = LoggingSettings(logToFile: true, logToConsole: false, redactSensitiveData: true)
                }
                let _ = (accountManager.transaction { transaction -> LoggingSettings? in
                    if let value = transaction.getSharedData(SharedDataKeys.loggingSettings)?.get(LoggingSettings.self) {
                        return value
                    } else {
                        return nil
                    }
                }).start(next: { value in
                    if let value {
                        loggingSettings = value
                    }
                    semaphore.signal()
                })
                semaphore.wait()
                
                Logger.shared.logToFile = loggingSettings.logToFile
                Logger.shared.logToConsole = loggingSettings.logToConsole
                Logger.shared.redactSensitiveData = loggingSettings.redactSensitiveData
            }
            
            var initialPresentationDataAndSettings: InitialPresentationDataAndSettings?
            let semaphore = DispatchSemaphore(value: 0)
            let systemUserInterfaceStyle: WindowUserInterfaceStyle
            if #available(iOSApplicationExtension 12.0, iOS 12.0, *) {
                systemUserInterfaceStyle = WindowUserInterfaceStyle(style: traitCollection.userInterfaceStyle)
            } else {
                systemUserInterfaceStyle = .light
            }
            let _ = currentPresentationDataAndSettings(accountManager: accountManager, systemUserInterfaceStyle: systemUserInterfaceStyle).start(next: { value in
                initialPresentationDataAndSettings = value
                semaphore.signal()
            })
            semaphore.wait()
            
            let presentationDataPromise = Promise<PresentationData>()
            
            let appLockContext = AppLockContextImpl(rootPath: rootPath, window: nil, rootController: nil, applicationBindings: applicationBindings, accountManager: accountManager, presentationDataSignal: presentationDataPromise.get(), lockIconInitialFrame: {
                return nil
            })
            let presentationData = initialPresentationDataAndSettings!.presentationData
            presentationDataPromise.set(.single(presentationData))
            
            var immediatePeerId: PeerId?
            #if DEBUG
            // Xcode crashes
            immediatePeerId = nil
            #else
            if #available(iOS 13.2, *), let sendMessageIntent = self.getExtensionContext()?.intent as? INSendMessageIntent {
                if let contact = sendMessageIntent.recipients?.first, let handle = contact.customIdentifier, handle.hasPrefix("tg") {
                    let string = handle.suffix(from: handle.index(handle.startIndex, offsetBy: 2))
                    if let peerId = Int64(string) {
                        immediatePeerId = PeerId(peerId)
                    }
                }
            }
            #endif
            
            /*let account: Signal<(SharedAccountContextImpl, Account, [AccountWithInfo]), ShareAuthorizationError> = internalContext.sharedContext.accountManager.transaction { transaction -> (SharedAccountContextImpl, LoggingSettings) in
                return (internalContext.sharedContext, transaction.getSharedData(SharedDataKeys.loggingSettings)?.get(LoggingSettings.self) ?? LoggingSettings.defaultSettings)
            }
            |> castError(ShareAuthorizationError.self)
            |> mapToSignal { sharedContext, loggingSettings -> Signal<(SharedAccountContextImpl, Account, [AccountWithInfo]), ShareAuthorizationError> in
                Logger.shared.logToFile = loggingSettings.logToFile
                Logger.shared.logToConsole = loggingSettings.logToConsole
                Logger.shared.redactSensitiveData = loggingSettings.redactSensitiveData
                
                return combineLatest(sharedContext.activeAccountsWithInfo, accountManager.transaction { transaction -> (Set<AccountRecordId>, PeerId?) in
                    let accountRecords = Set(transaction.getRecords().map { record in
                        return record.id
                    })
                    let intentsSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.intentsSettings)?.get(IntentsSettings.self) ?? IntentsSettings.defaultSettings
                    return (accountRecords, intentsSettings.account)
                })
                |> castError(ShareAuthorizationError.self)
                |> take(1)
                |> mapToSignal { primaryAndAccounts, validAccountIdsAndIntentsAccountId -> Signal<(SharedAccountContextImpl, Account, [AccountWithInfo]), ShareAuthorizationError> in
                    var (maybePrimary, accounts) = primaryAndAccounts
                    let (validAccountIds, intentsAccountId) = validAccountIdsAndIntentsAccountId
                    for i in (0 ..< accounts.count).reversed() {
                        if !validAccountIds.contains(accounts[i].account.id) {
                            accounts.remove(at: i)
                        }
                    }
                    
                    if let _ = immediatePeerId, let intentsAccountId = intentsAccountId {
                        for account in accounts {
                            if account.peer.id == intentsAccountId {
                                maybePrimary = account.account.id
                            }
                        }
                    }
                    
                    guard let primary = maybePrimary, validAccountIds.contains(primary) else {
                        return .fail(.unauthorized)
                    }
                    
                    guard let info = accounts.first(where: { $0.account.id == primary }) else {
                        return .fail(.unauthorized)
                    }
                    
                    return .single((sharedContext, info.account, Array(accounts)))
                }
            }
            |> take(1)*/
            
            let environment = ShareControllerEnvironmentExtension(presentationData: presentationData)
            let initializationData = self.initializationData
            
            let networkArguments = NetworkInitializationArguments(
                apiId: initializationData.apiId,
                apiHash: initializationData.apiHash,
                languagesCategory: initializationData.languagesCategory,
                appVersion: initializationData.appVersion,
                voipMaxLayer: 0,
                voipVersions: [],
                appData: .single(nil),
                externalRequestVerificationStream: .never(),
                externalRecaptchaRequestVerification: { _, _ in return .never() },
                autolockDeadine: .single(nil),
                encryptionProvider: OpenSSLEncryptionProvider(),
                deviceModelName: nil,
                useBetaFeatures: initializationData.useBetaFeatures,
                isICloudEnabled: false
            )
            
            let accountData: Signal<(ShareControllerEnvironment, ShareControllerAccountContext, [ShareControllerSwitchableAccount]), NoError> = accountManager.accountRecords()
            |> take(1)
            |> mapToSignal { view -> Signal<(ShareControllerEnvironment, ShareControllerAccountContext, [ShareControllerSwitchableAccount]), NoError> in
                var signals: [Signal<(AccountRecordId, AccountStateManager, Peer)?, NoError>] = []
                for record in view.records {
                    if record.attributes.contains(where: { attribute in
                        if case .loggedOut = attribute {
                            return true
                        } else {
                            return false
                        }
                    }) {
                        continue
                    }
                    
                    signals.append(standaloneStateManager(
                        accountManager: accountManager,
                        networkArguments: networkArguments,
                        id: record.id,
                        encryptionParameters: ValueBoxEncryptionParameters(
                            forceEncryptionIfNoSet: false,
                            key: ValueBoxEncryptionParameters.Key(data: initializationData.encryptionParameters.0)!,
                            salt: ValueBoxEncryptionParameters.Salt(data: initializationData.encryptionParameters.1)!
                        ),
                        rootPath: rootPath,
                        auxiliaryMethods: makeTelegramAccountAuxiliaryMethods(uploadInBackground: nil)
                    )
                    |> mapToSignal { result -> Signal<(AccountRecordId, AccountStateManager, Peer)?, NoError> in
                        if let result {
                            return result.postbox.transaction { transaction -> (AccountRecordId, AccountStateManager, Peer)? in
                                guard let peer = transaction.getPeer(result.accountPeerId) else {
                                    return nil
                                }
                                
                                return (record.id, result, peer)
                            }
                        } else {
                            return .single(nil)
                        }
                    })
                }
                return combineLatest(signals)
                |> mapToSignal { stateManagers -> Signal<(ShareControllerEnvironment, ShareControllerAccountContext, [ShareControllerSwitchableAccount]), NoError> in
                    var allAccounts: [ShareControllerSwitchableAccount] = []
                    for data in stateManagers {
                        guard let (id, stateManager, peer) = data else {
                            continue
                        }
                        //TODO:content settings
                        allAccounts.append(ShareControllerSwitchableAccount(
                            account: ShareControllerAccountContextExtension(
                                accountId: id,
                                stateManager: stateManager,
                                contentSettings: .default,
                                appConfiguration: .defaultValue
                            ),
                            peer: peer
                        ))
                    }
                    
                    guard let currentAccount = allAccounts.first(where: { $0.account.accountId == view.currentRecord?.id }) else {
                        return .never()
                    }
                    
                    return .single((environment, currentAccount.account, allAccounts))
                }
            }
            
            let applicationInterface: Signal<(ShareControllerEnvironment, ShareControllerAccountContext, PostboxAccessChallengeData, [ShareControllerSwitchableAccount]), ShareAuthorizationError> = accountData
            |> castError(ShareAuthorizationError.self)
            |> mapToSignal { data -> Signal<(ShareControllerEnvironment, ShareControllerAccountContext, PostboxAccessChallengeData, [ShareControllerSwitchableAccount]), ShareAuthorizationError> in
                let (environment, context, otherAccounts) = data
                
                let limitsConfigurationAndContentSettings = TelegramEngine.EngineData(accountPeerId: context.stateManager.accountPeerId, postbox: context.stateManager.postbox).get(
                    TelegramEngine.EngineData.Item.Configuration.Limits(),
                    TelegramEngine.EngineData.Item.Configuration.ContentSettings(),
                    TelegramEngine.EngineData.Item.Configuration.App()
                )
                
                return combineLatest(accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]), limitsConfigurationAndContentSettings, accountManager.accessChallengeData())
                |> take(1)
                |> deliverOnMainQueue
                |> castError(ShareAuthorizationError.self)
                |> map { sharedData, limitsConfigurationAndContentSettings, data -> (ShareControllerEnvironment, ShareControllerAccountContext, PostboxAccessChallengeData, [ShareControllerSwitchableAccount]) in
                    updateLegacyLocalization(strings: environment.presentationData.strings)
                    
                    return (environment, context, data.data, otherAccounts)
                }
            }
            |> deliverOnMainQueue
            |> afterNext { [weak self] environment, context, accessChallengeData, otherAccounts in
                (environment as? ShareControllerEnvironmentExtension)?.accounts = otherAccounts.compactMap { $0.account as? ShareControllerAccountContextExtension }
                
                initializeLegacyComponents(application: nil, currentSizeClassGetter: { return .compact }, currentHorizontalClassGetter: { return .compact }, documentsPath: "", currentApplicationBounds: { return CGRect() }, canOpenUrl: { _ in return false}, openUrl: { _ in })
                setContextMenuControllerProvider { arguments in
                    return ContextMenuControllerImpl(arguments)
                }
                
                let displayShare: () -> Void = {
                    var cancelImpl: (() -> Void)?
                    
                    let beginShare: () -> Void = {
                        let requestUserInteraction: ([UnpreparedShareItemContent]) -> Signal<[PreparedShareItemContent], NoError> = { content in
                            return Signal { [weak self] subscriber in
                                switch content[0] {
                                    case let .contact(data):
                                        let controller = deviceContactInfoController(context: context, environment: environment, subject: .filter(peer: nil, contactId: nil, contactData: data, completion: { peer, contactData in
                                            let phone = contactData.basicData.phoneNumbers[0].value
                                            if let vCardData = contactData.serializedVCard() {
                                                subscriber.putNext([.media(.media(.standalone(media: TelegramMediaContact(firstName: contactData.basicData.firstName, lastName: contactData.basicData.lastName, phoneNumber: phone, peerId: nil, vCardData: vCardData))))])
                                            }
                                            subscriber.putCompletion()
                                        }), completed: nil, cancelled: {
                                            cancelImpl?()
                                        })
                                        
                                        if let strongSelf = self, let window = strongSelf.mainWindow {
                                            controller.presentationArguments = ViewControllerPresentationArguments(presentationAnimation: .modalSheet)
                                            window.present(controller, on: .root)
                                        }
                                        break
                                }
                                return EmptyDisposable
                            } |> runOn(Queue.mainQueue())
                        }
                        
                        let sentItems: ([PeerId], [PeerId: Int64], [PeerId: StarsAmount], [PreparedShareItemContent], ShareControllerAccountContext, Bool, String) -> Signal<ShareControllerExternalStatus, NoError> = { peerIds, threadIds, requireStars, contents, account, silently, additionalText in
                            let sentItems = sentShareItems(accountPeerId: account.accountPeerId, postbox: account.stateManager.postbox, network: account.stateManager.network, stateManager: account.stateManager, auxiliaryMethods: makeTelegramAccountAuxiliaryMethods(uploadInBackground: nil), to: peerIds, threadIds: threadIds, requireStars: requireStars, items: contents, silently: silently, additionalText: additionalText)
                            |> `catch` { _ -> Signal<
                                Float, NoError> in
                                return .complete()
                            }
                            return sentItems
                            |> map { value -> ShareControllerExternalStatus in
                                return .progress(value)
                            }
                            |> then(.single(.done))
                        }
                         
                        var itemCount = 1
                        
                        if let extensionItems = self?.getExtensionContext()?.inputItems as? [NSExtensionItem] {
                            for item in extensionItems {
                                if let attachments = item.attachments {
                                    itemCount = 0
                                    for _ in attachments {
                                        itemCount += 1
                                    }
                                }
                            }
                        }
                        let shareController = ShareController(environment: environment, currentContext: context, subject: .fromExternal(itemCount, { peerIds, threadIds, requireStars, additionalText, account, silently in
                            if let strongSelf = self, let inputItems = strongSelf.getExtensionContext()?.inputItems, !inputItems.isEmpty, !peerIds.isEmpty {
                                let rawSignals = TGItemProviderSignals.itemSignals(forInputItems: inputItems)!
                                return preparedShareItems(postbox: account.stateManager.postbox, network: account.stateManager.network, to: peerIds[0], dataItems: rawSignals)
                                |> map(Optional.init)
                                |> `catch` { error -> Signal<PreparedShareItems?, ShareControllerError> in
                                    switch error {
                                        case .generic:
                                            return .single(nil)
                                        case let .fileTooBig(size):
                                            return .fail(.fileTooBig(size))
                                    }
                                }
                                |> mapToSignal { state -> Signal<ShareControllerExternalStatus, ShareControllerError> in
                                    guard let state = state else {
                                        return .single(.done)
                                    }
                                    switch state {
                                    case let .preparing(long):
                                        return .single(.preparing(long))
                                    case let .progress(value):
                                        return .single(.progress(value))
                                    case let .userInteractionRequired(value):
                                        return requestUserInteraction(value)
                                        |> castError(ShareControllerError.self)
                                        |> mapToSignal { contents -> Signal<ShareControllerExternalStatus, ShareControllerError> in
                                            return sentItems(peerIds, threadIds, requireStars, contents, account, silently, additionalText)
                                            |> castError(ShareControllerError.self)
                                        }
                                    case let .done(contents):
                                        return sentItems(peerIds, threadIds, requireStars, contents, account, silently, additionalText)
                                        |> castError(ShareControllerError.self)
                                    }
                                }
                            } else {
                                return .single(.done)
                            }
                        }), fromForeignApp: true, externalShare: false, switchableAccounts: otherAccounts, immediatePeerId: immediatePeerId)
                        shareController.presentationArguments = ViewControllerPresentationArguments(presentationAnimation: .modalSheet)
                        shareController.dismissed = { _ in
                            //inForeground.set(false)
                            self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                        }
                        
                        var canShareToStory = true
                        if let inputItems = self?.getExtensionContext()?.inputItems, inputItems.count == 1, let item = inputItems[0] as? NSExtensionItem, let attachments = item.attachments {
                            for attachment in attachments {
                                if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                                } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                                } else {
                                    canShareToStory = false
                                }
                            }
                        }
                        
                        if canShareToStory {
                            shareController.shareStory = { [weak self] in
                                guard let self else {
                                    return
                                }
                                if let inputItems = self.getExtensionContext()?.inputItems, inputItems.count == 1, let item = inputItems[0] as? NSExtensionItem, let attachments = item.attachments {
                                    let sessionId = Int64.random(in: 1000000 ..< .max)
                                    
                                    let storiesPath = rootPath + "/share/stories/\(sessionId)"
                                    let _ = try? FileManager.default.createDirectory(atPath: storiesPath, withIntermediateDirectories: true, attributes: nil)
                                    var index = 0
                                    
                                    let dispatchGroup = DispatchGroup()
                                    
                                    for attachment in attachments {
                                        let fileIndex = index
                                        if attachment.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                                            dispatchGroup.enter()
                                            attachment.loadFileRepresentation(forTypeIdentifier: kUTTypeImage as String, completionHandler: { url, _ in
                                                if let url, let imageData = try? Data(contentsOf: url) {
                                                    let filePath = storiesPath + "/\(fileIndex).jpg"
                                                    try? FileManager.default.removeItem(atPath: filePath)
                                                    
                                                    do {
                                                        try imageData.write(to: URL(fileURLWithPath: filePath))
                                                    } catch {
                                                        print("Error: \(error)")
                                                    }
                                                }
                                                dispatchGroup.leave()
                                            })
                                        } else if attachment.hasItemConformingToTypeIdentifier(kUTTypeMovie as String) {
                                            dispatchGroup.enter()
                                            attachment.loadFileRepresentation(forTypeIdentifier: kUTTypeMovie as String, completionHandler: { url, _ in
                                                if let url {
                                                    let filePath = storiesPath + "/\(fileIndex).mp4"
                                                    try? FileManager.default.removeItem(atPath: filePath)
                                                    
                                                    do {
                                                        try FileManager.default.copyItem(at: url, to: URL(fileURLWithPath: filePath))
                                                    } catch {
                                                        print("Error: \(error)")
                                                    }
                                                }
                                                dispatchGroup.leave()
                                            })
                                        }
                                        index += 1
                                    }
                                    
                                    dispatchGroup.notify(queue: .main) {
                                        self.openUrl("tg://shareStory?session=\(sessionId)")
                                    }
                                }
                            }
                        }
                        /*shareController.debugAction = {
                            guard let strongSelf = self else {
                                return
                            }
                            let presentationData = environment.presentationData
                            let navigationController = NavigationController(mode: .single, theme: NavigationControllerTheme(presentationTheme: presentationData.theme))
                            strongSelf.navigationController = navigationController
                            navigationController.viewControllers = [debugController(sharedContext: context.sharedContext, context: context)]
                            strongSelf.mainWindow?.present(navigationController, on: .root)
                        }*/
                        
                        cancelImpl = { [weak shareController] in
                            shareController?.dismiss(completion: { [weak self] in
                                //inForeground.set(false)
                                self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                            })
                        }
                        
                        if let strongSelf = self {
                            if let currentShareController = strongSelf.currentShareController {
                                currentShareController.dismiss()
                            }
                            if let navigationController = strongSelf.navigationController {
                                navigationController.dismiss(animated: false)
                            }
                            strongSelf.currentShareController = shareController
                            strongSelf.mainWindow?.present(shareController, on: .root)
                        }
                    }
                    
                    if let strongSelf = self, let inputItems = strongSelf.getExtensionContext()?.inputItems, inputItems.count == 1, let item = inputItems[0] as? NSExtensionItem, let attachments = item.attachments {
                        for attachment in attachments {
                            if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                                attachment.loadItem(forTypeIdentifier: kUTTypeFileURL as String, completionHandler: { result, error in
                                    Queue.mainQueue().async {
                                        guard let url = result as? URL, url.isFileURL else {
                                            beginShare()
                                            return
                                        }
                                        guard let fileName = url.pathComponents.last else {
                                            beginShare()
                                            return
                                        }
                                        let fileExtension = (fileName as NSString).pathExtension
                                        
                                        var archivePathValue: String?
                                        let _ = archivePathValue
                                        var otherEntries: [(SSZipEntry, String, TelegramEngine.HistoryImport.MediaType)] = []
                                        var mainFile: TempBoxFile?
                                        
                                        let appConfiguration = context.appConfiguration
                                        
                                        if fileExtension.lowercased() == "zip" {
                                            let archivePath = url.path
                                            archivePathValue = archivePath
                                            
                                            guard let entries = SSZipArchive.getEntriesForFile(atPath: archivePath) else {
                                                beginShare()
                                                return
                                            }
                                            
                                            var mainFileNameExpressions: [String] = [
                                                "_chat\\.txt",
                                                "KakaoTalkChats\\.txt",
                                                "Talk_.*?\\.txt",
                                            ]
                                            
                                            if let data = appConfiguration.data, let dict = data["history_import_filters"] as? [String: Any] {
                                                if let zip = dict["zip"] as? [String: Any] {
                                                    if let patterns = zip["main_file_patterns"] as? [String] {
                                                        mainFileNameExpressions = patterns
                                                    }
                                                }
                                            }
                                            
                                            let mainFileNames: [NSRegularExpression] = mainFileNameExpressions.compactMap { string -> NSRegularExpression? in
                                                return try? NSRegularExpression(pattern: string)
                                            }
                                            
                                            var maybeMainFileName: String?
                                            mainFileLoop: for entry in entries {
                                                let entryFileName = entry.path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "..", with: "_")
                                                let fullRange = NSRange(entryFileName.startIndex ..< entryFileName.endIndex, in: entryFileName)
                                                for expression in mainFileNames {
                                                    if expression.firstMatch(in: entryFileName, options: [], range: fullRange) != nil {
                                                        maybeMainFileName = entryFileName
                                                        break mainFileLoop
                                                    }
                                                }
                                            }
                                            
                                            guard let mainFileName = maybeMainFileName else {
                                                beginShare()
                                                return
                                            }
                                            
                                            let photoRegex = try! NSRegularExpression(pattern: ".*?\\.jpg")
                                            let videoRegex = try! NSRegularExpression(pattern: "[\\d]+-VIDEO-.*?\\.mp4")
                                            let stickerRegex = try! NSRegularExpression(pattern: "[\\d]+-STICKER-.*?\\.webp")
                                            let voiceRegex = try! NSRegularExpression(pattern: "[\\d]+-AUDIO-.*?\\.opus")
                                            
                                            do {
                                                for entry in entries {
                                                    let entryPath = entry.path.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "..", with: "_")
                                                    if entryPath.isEmpty {
                                                        continue
                                                    }
                                                    let tempFile = TempBox.shared.tempFile(fileName: entryPath)
                                                    if entryPath == mainFileName {
                                                        if SSZipArchive.extractFileFromArchive(atPath: archivePath, filePath: entry.path, toPath: tempFile.path) {
                                                            mainFile = tempFile
                                                        }
                                                    } else {
                                                        let entryFileName = (entryPath as NSString).lastPathComponent
                                                        if !entryFileName.isEmpty {
                                                            let mediaType: TelegramEngine.HistoryImport.MediaType
                                                            let fullRange = NSRange(entryFileName.startIndex ..< entryFileName.endIndex, in: entryFileName)
                                                            if photoRegex.firstMatch(in: entryFileName, options: [], range: fullRange) != nil {
                                                                mediaType = .photo
                                                            } else if videoRegex.firstMatch(in: entryFileName, options: [], range: fullRange) != nil {
                                                                mediaType = .video
                                                            } else if stickerRegex.firstMatch(in: entryFileName, options: [], range: fullRange) != nil {
                                                                mediaType = .sticker
                                                            } else if voiceRegex.firstMatch(in: entryFileName, options: [], range: fullRange) != nil {
                                                                mediaType = .voice
                                                            } else {
                                                                mediaType = .file
                                                            }
                                                            otherEntries.append((entry, entryFileName, mediaType))
                                                        }
                                                    }
                                                }
                                            }
                                        } else if fileExtension.lowercased() == "txt" {
                                            var fileScanExpressions: [String] = [
                                                "^\\[LINE\\]",
                                            ]
                                            
                                            if let data = appConfiguration.data, let dict = data["history_import_filters"] as? [String: Any] {
                                                if let zip = dict["txt"] as? [String: Any] {
                                                    if let patterns = zip["patterns"] as? [String] {
                                                        fileScanExpressions = patterns
                                                    }
                                                }
                                            }
                                            
                                            let filePatterns: [NSRegularExpression] = fileScanExpressions.compactMap { string -> NSRegularExpression? in
                                                return try? NSRegularExpression(pattern: string)
                                            }
                                            
                                            if let mainFileTextHeader = extractTextFileHeader(path: url.path) {
                                                let fullRange = NSRange(mainFileTextHeader.startIndex ..< mainFileTextHeader.endIndex, in: mainFileTextHeader)
                                                var foundMatch = false
                                                for pattern in filePatterns {
                                                    if pattern.firstMatch(in: mainFileTextHeader, options: [], range: fullRange) != nil {
                                                        foundMatch = true
                                                        break
                                                    }
                                                }
                                                if !foundMatch {
                                                    beginShare()
                                                    return
                                                }
                                            } else {
                                                beginShare()
                                                return
                                            }
                                            
                                            let tempFile = TempBox.shared.tempFile(fileName: "History.txt")
                                            if let _ = try? FileManager.default.copyItem(atPath: url.path, toPath: tempFile.path) {
                                                mainFile = tempFile
                                            } else {
                                                beginShare()
                                                return
                                            }
                                        }
                                        
                                        if let mainFile = mainFile, let mainFileHeader = extractTextFileHeader(path: mainFile.path) {
                                            let _ = mainFileHeader
                                            
                                            let presentationData = environment.presentationData
                                            let navigationController = NavigationController(mode: .single, theme: NavigationControllerTheme(presentationTheme: presentationData.theme))
                                            strongSelf.navigationController = navigationController
                                            navigationController.viewControllers = [ChatImportTempController(presentationData: environment.presentationData)]
                                            strongSelf.mainWindow?.present(navigationController, on: .root)
                                            
                                            if let mainWindow = strongSelf.mainWindow {
                                                attemptChatImport(
                                                    context: context,
                                                    getExtensionContext: strongSelf.getExtensionContext,
                                                    accountManager: accountManager,
                                                    appLockContext: appLockContext,
                                                    applicationBindings: applicationBindings,
                                                    initialPresentationDataAndSettings: initialPresentationDataAndSettings!,
                                                    networkInitializationArguments: networkArguments,
                                                    presentationData: environment.presentationData,
                                                    makeTempContext: initializationData.makeTempContext,
                                                    mainWindow: mainWindow,
                                                    navigationController: navigationController,
                                                    archivePathValue: archivePathValue,
                                                    mainFileHeader: mainFileHeader,
                                                    mainFile: mainFile,
                                                    otherEntries: otherEntries,
                                                    beginShare: beginShare
                                                )
                                            } else {
                                                beginShare()
                                            }
                                        } else {
                                            beginShare()
                                            return
                                        }
                                    }
                                })
                                return
                            }
                        }
                        beginShare()
                    } else {
                        beginShare()
                    }
                }
                
                let modalPresentation: Bool
                if #available(iOSApplicationExtension 13.0, iOS 13.0, *) {
                    modalPresentation = true
                } else {
                    modalPresentation = false
                }
                
                let _ = passcodeEntryController(
                    accountManager: accountManager,
                    applicationBindings: applicationBindings,
                    presentationData: environment.presentationData,
                    updatedPresentationData: .single(environment.presentationData),
                    statusBarHost: nil,
                    appLockContext: appLockContext,
                    animateIn: true,
                    modalPresentation: modalPresentation,
                    completion: { value in
                        if value {
                            displayShare()
                        } else {
                            Queue.mainQueue().after(0.5, {
                                //inForeground.set(false)
                                self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                            })
                        }
                    }
                ).start(next: { controller in
                    guard let strongSelf = self, let controller = controller else {
                        return
                    }
                    
                    if let currentPasscodeController = strongSelf.currentPasscodeController {
                        currentPasscodeController.dismiss()
                    }
                    strongSelf.currentPasscodeController = controller
                    strongSelf.mainWindow?.present(controller, on: .root)
                })
            }
            
            self.disposable.set(applicationInterface.start(next: { _, _, _, _ in }, error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                let presentationData = environment.presentationData
                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.Share_AuthTitle, text: presentationData.strings.Share_AuthDescription, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                    //inForeground.set(false)
                    self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                })])
                strongSelf.mainWindow?.present(controller, on: .root)
            }, completed: {}))
        }
    }
}

private func attemptChatImport(
    context: ShareControllerAccountContext,
    getExtensionContext: @escaping () -> NSExtensionContext?,
    accountManager: AccountManager<TelegramAccountManagerTypes>,
    appLockContext: AppLockContext,
    applicationBindings: TelegramApplicationBindings,
    initialPresentationDataAndSettings: InitialPresentationDataAndSettings,
    networkInitializationArguments: NetworkInitializationArguments,
    presentationData: PresentationData,
    makeTempContext: @escaping (AccountManager<TelegramAccountManagerTypes>, AppLockContext, TelegramApplicationBindings, InitialPresentationDataAndSettings, NetworkInitializationArguments) -> Signal<AccountContext, NoError>,
    mainWindow: Window1,
    navigationController: NavigationController,
    archivePathValue: String?,
    mainFileHeader: String,
    mainFile: TempBoxFile,
    otherEntries: [(SSZipEntry, String, TelegramEngine.HistoryImport.MediaType)],
    beginShare: @escaping () -> Void
) {
    let _ = (makeTempContext(
        accountManager,
        appLockContext,
        applicationBindings,
        initialPresentationDataAndSettings,
        networkInitializationArguments
    )
    |> deliverOnMainQueue).start(next: { context in
        context.account.resetStateManagement()
        context.account.shouldBeServiceTaskMaster.set(.single(.now))
        
        let _ = (TelegramEngine.HistoryImport(postbox: context.account.stateManager.postbox, network: context.account.stateManager.network).getInfo(header: mainFileHeader)
        |> deliverOnMainQueue).start(next: { [weak mainWindow] parseInfo in
            switch parseInfo {
            case let .group(groupTitle):
                var attemptSelectionImpl: ((EnginePeer) -> Void)?
                var createNewGroupImpl: (() -> Void)?
                
                let controller = PeerSelectionControllerImpl(PeerSelectionControllerParams(context: context, filter: [.onlyGroups, .onlyManageable, .excludeDisabled, .doNotSearchMessages], hasContactSelector: false, hasGlobalSearch: false, title: presentationData.strings.ChatImport_Title, attemptSelection: { peer, _, _ in
                    attemptSelectionImpl?(peer)
                }, createNewGroup: {
                    createNewGroupImpl?()
                }, pretendPresentedInModal: true, selectForumThreads: false))
                
                controller.customDismiss = {
                    //inForeground.set(false)
                    getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                
                controller.peerSelected = { peer, _ in
                    attemptSelectionImpl?(peer)
                }
                
                controller.navigationPresentation = .default
                
                let beginWithPeer: (PeerId) -> Void = { peerId in
                    navigationController.view.endEditing(true)
                    navigationController.pushViewController(ChatImportActivityScreen(context: context, cancel: {
                        //inForeground.set(false)
                        getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                    }, peerId: peerId, archivePath: archivePathValue, mainEntry: mainFile, otherEntries: otherEntries))
                }
                
                attemptSelectionImpl = { peer in
                    var errorText: String?
                    if case let .channel(channel) = peer {
                        if channel.hasPermission(.changeInfo), (channel.flags.contains(.isCreator) || channel.adminRights != nil) {
                        } else {
                            errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                        }
                    } else if case let .legacyGroup(group) = peer {
                        switch group.role {
                        case .creator:
                            break
                        default:
                            errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                        }
                    } else {
                        errorText = presentationData.strings.ChatImport_SelectionErrorGroupGeneric
                    }
                    
                    if let errorText = errorText {
                        let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                        })])
                        mainWindow?.present(controller, on: .root)
                    } else {
                        controller.inProgress = true
                        let _ = (context.engine.historyImport.checkPeerImport(peerId: peer.id)
                                 |> deliverOnMainQueue).start(next: { result in
                            controller.inProgress = false
                            
                            var errorText: String?
                            if case let .channel(channel) = peer {
                                if channel.hasPermission(.changeInfo), (channel.flags.contains(.isCreator) || channel.adminRights != nil) {
                                } else {
                                    errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                                }
                            } else if case let .legacyGroup(group) = peer {
                                switch group.role {
                                case .creator:
                                    break
                                default:
                                    errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                                }
                            } else if case .user = peer {
                            } else {
                                errorText = presentationData.strings.ChatImport_SelectionErrorGroupGeneric
                            }
                            
                            if let errorText = errorText {
                                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                })])
                                mainWindow?.present(controller, on: .root)
                            } else {
                                let text: String
                                switch result {
                                case .allowed:
                                    if let groupTitle = groupTitle {
                                        text = presentationData.strings.ChatImport_SelectionConfirmationGroupWithTitle(groupTitle, peer.debugDisplayTitle).string
                                    } else {
                                        text = presentationData.strings.ChatImport_SelectionConfirmationGroupWithoutTitle(peer.debugDisplayTitle).string
                                    }
                                case let .alert(textValue):
                                    text = textValue
                                }
                                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_SelectionConfirmationAlertTitle, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                }), TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_SelectionConfirmationAlertImportAction, action: {
                                    beginWithPeer(peer.id)
                                })], parseMarkdown: true)
                                mainWindow?.present(controller, on: .root)
                            }
                        }, error: { error in
                            controller.inProgress = false
                            
                            let errorText: String
                            switch error {
                            case .generic:
                                errorText = presentationData.strings.Login_UnknownError
                            case .chatAdminRequired:
                                errorText = presentationData.strings.ChatImportActivity_ErrorNotAdmin
                            case .invalidChatType:
                                errorText = presentationData.strings.ChatImportActivity_ErrorInvalidChatType
                            case .userBlocked:
                                errorText = presentationData.strings.ChatImportActivity_ErrorUserBlocked
                            case .limitExceeded:
                                errorText = presentationData.strings.ChatImportActivity_ErrorLimitExceeded
                            case .notMutualContact:
                                errorText = presentationData.strings.ChatImport_UserErrorNotMutual
                            }
                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                            })])
                            mainWindow?.present(controller, on: .root)
                        })
                    }
                }
                
                createNewGroupImpl = {
                    let resolvedGroupTitle: String
                    if let groupTitle = groupTitle {
                        resolvedGroupTitle = groupTitle
                    } else {
                        resolvedGroupTitle = "Group"
                    }
                    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_CreateGroupAlertTitle, text: presentationData.strings.ChatImport_CreateGroupAlertText(resolvedGroupTitle).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_CreateGroupAlertImportAction, action: {
                        var signal: Signal<PeerId?, NoError> = _internal_createSupergroup(postbox: context.account.stateManager.postbox, network: context.account.stateManager.network, stateManager: context.account.stateManager, title: resolvedGroupTitle, description: nil, username: nil, isForum: false, isForHistoryImport: true)
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<PeerId?, NoError> in
                            return .single(nil)
                        }
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                            mainWindow?.present(controller, on: .root)
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        signal = signal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        let _ = (signal
                                 |> deliverOnMainQueue).start(next: { peerId in
                            if let peerId = peerId {
                                beginWithPeer(peerId)
                            } else {
                            }
                        })
                    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    })], actionLayout: .vertical, parseMarkdown: true)
                    mainWindow?.present(controller, on: .root)
                }
                
                navigationController.viewControllers = [controller]
            case let .privateChat(title):
                var attemptSelectionImpl: ((EnginePeer) -> Void)?
                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyPrivateChats, .excludeDisabled, .doNotSearchMessages, .excludeSecretChats], hasChatListSelector: false, hasContactSelector: true, hasGlobalSearch: false, title: presentationData.strings.ChatImport_Title, attemptSelection: { peer, _, _ in
                    attemptSelectionImpl?(peer)
                }, pretendPresentedInModal: true, selectForumThreads: true))
                
                controller.customDismiss = {
                    //inForeground.set(false)
                    getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                
                controller.peerSelected = { peer, _ in
                    attemptSelectionImpl?(peer)
                }
                
                controller.navigationPresentation = .default
                
                let beginWithPeer: (PeerId) -> Void = { peerId in
                    navigationController.view.endEditing(true)
                    navigationController.pushViewController(ChatImportActivityScreen(context: context, cancel: {
                        //inForeground.set(false)
                        getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                    }, peerId: peerId, archivePath: archivePathValue, mainEntry: mainFile, otherEntries: otherEntries))
                }
                
                attemptSelectionImpl = { [weak controller] peer in
                    controller?.inProgress = true
                    let _ = (context.engine.historyImport.checkPeerImport(peerId: peer.id)
                             |> deliverOnMainQueue).start(next: { result in
                        controller?.inProgress = false
                        
                        let text: String
                        switch result {
                        case .allowed:
                            if let title = title {
                                text = presentationData.strings.ChatImport_SelectionConfirmationUserWithTitle(title, peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                            } else {
                                text = presentationData.strings.ChatImport_SelectionConfirmationUserWithoutTitle(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                            }
                        case let .alert(textValue):
                            text = textValue
                        }
                        let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_SelectionConfirmationAlertTitle, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                        }), TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_SelectionConfirmationAlertImportAction, action: {
                            beginWithPeer(peer.id)
                        })], parseMarkdown: true)
                        mainWindow?.present(controller, on: .root)
                    }, error: { error in
                        controller?.inProgress = false
                        
                        let errorText: String
                        switch error {
                        case .generic:
                            errorText = presentationData.strings.Login_UnknownError
                        case .chatAdminRequired:
                            errorText = presentationData.strings.ChatImportActivity_ErrorNotAdmin
                        case .invalidChatType:
                            errorText = presentationData.strings.ChatImportActivity_ErrorInvalidChatType
                        case .userBlocked:
                            errorText = presentationData.strings.ChatImportActivity_ErrorUserBlocked
                        case .limitExceeded:
                            errorText = presentationData.strings.ChatImportActivity_ErrorLimitExceeded
                        case .notMutualContact:
                            errorText = presentationData.strings.ChatImport_UserErrorNotMutual
                        }
                        let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                        })])
                        mainWindow?.present(controller, on: .root)
                    })
                }
                
                navigationController.viewControllers = [controller]
            case let .unknown(peerTitle):
                var attemptSelectionImpl: ((EnginePeer) -> Void)?
                var createNewGroupImpl: (() -> Void)?
                let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeDisabled, .doNotSearchMessages], hasContactSelector: true, hasGlobalSearch: false, title: presentationData.strings.ChatImport_Title, attemptSelection: { peer, _, _ in
                    attemptSelectionImpl?(peer)
                }, createNewGroup: {
                    createNewGroupImpl?()
                }, pretendPresentedInModal: true, selectForumThreads: true))
                
                controller.customDismiss = {
                    //inForeground.set(false)
                    getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                }
                
                controller.peerSelected = { peer, _ in
                    attemptSelectionImpl?(peer)
                }
                
                controller.navigationPresentation = .default
                
                let beginWithPeer: (EnginePeer.Id) -> Void = { peerId in
                    navigationController.view.endEditing(true)
                    navigationController.pushViewController(ChatImportActivityScreen(context: context, cancel: {
                        //inForeground.set(false)
                        getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                    }, peerId: peerId, archivePath: archivePathValue, mainEntry: mainFile, otherEntries: otherEntries))
                }
                
                attemptSelectionImpl = { [weak controller] peer in
                    controller?.inProgress = true
                    let _ = (context.engine.historyImport.checkPeerImport(peerId: peer.id)
                             |> deliverOnMainQueue).start(next: { result in
                        controller?.inProgress = false
                        
                        var errorText: String?
                        if case let .channel(channel) = peer {
                            if channel.hasPermission(.changeInfo), (channel.flags.contains(.isCreator) || channel.adminRights != nil) {
                            } else {
                                errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                            }
                        } else if case let .legacyGroup(group) = peer {
                            switch group.role {
                            case .creator:
                                break
                            default:
                                errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                            }
                        } else if case .user = peer {
                        } else {
                            errorText = presentationData.strings.ChatImport_SelectionErrorGroupGeneric
                        }
                        
                        if let errorText = errorText {
                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                            })])
                            mainWindow?.present(controller, on: .root)
                        } else {
                            if case .user = peer {
                                let text: String
                                switch result {
                                case .allowed:
                                    if let title = peerTitle {
                                        text = presentationData.strings.ChatImport_SelectionConfirmationUserWithTitle(title, peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                    } else {
                                        text = presentationData.strings.ChatImport_SelectionConfirmationUserWithoutTitle(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                    }
                                case let .alert(textValue):
                                    text = textValue
                                }
                                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_SelectionConfirmationAlertTitle, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                }), TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_SelectionConfirmationAlertImportAction, action: {
                                    beginWithPeer(peer.id)
                                })], parseMarkdown: true)
                                mainWindow?.present(controller, on: .root)
                            } else {
                                let text: String
                                switch result {
                                case .allowed:
                                    if let groupTitle = peerTitle {
                                        text = presentationData.strings.ChatImport_SelectionConfirmationGroupWithTitle(groupTitle, peer.debugDisplayTitle).string
                                    } else {
                                        text = presentationData.strings.ChatImport_SelectionConfirmationGroupWithoutTitle(peer.debugDisplayTitle).string
                                    }
                                case let .alert(textValue):
                                    text = textValue
                                }
                                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_SelectionConfirmationAlertTitle, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                }), TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_SelectionConfirmationAlertImportAction, action: {
                                    beginWithPeer(peer.id)
                                })], parseMarkdown: true)
                                mainWindow?.present(controller, on: .root)
                            }
                        }
                    }, error: { error in
                        controller?.inProgress = false
                        
                        let errorText: String
                        switch error {
                        case .generic:
                            errorText = presentationData.strings.Login_UnknownError
                        case .chatAdminRequired:
                            errorText = presentationData.strings.ChatImportActivity_ErrorNotAdmin
                        case .invalidChatType:
                            errorText = presentationData.strings.ChatImportActivity_ErrorInvalidChatType
                        case .userBlocked:
                            errorText = presentationData.strings.ChatImportActivity_ErrorUserBlocked
                        case .limitExceeded:
                            errorText = presentationData.strings.ChatImportActivity_ErrorLimitExceeded
                        case .notMutualContact:
                            errorText = presentationData.strings.ChatImport_UserErrorNotMutual
                        }
                        let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                        })])
                        mainWindow?.present(controller, on: .root)
                    })
                }
                
                createNewGroupImpl = {
                    let resolvedGroupTitle: String
                    if let groupTitle = peerTitle {
                        resolvedGroupTitle = groupTitle
                    } else {
                        resolvedGroupTitle = "Group"
                    }
                    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_CreateGroupAlertTitle, text: presentationData.strings.ChatImport_CreateGroupAlertText(resolvedGroupTitle).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_CreateGroupAlertImportAction, action: {
                        var signal: Signal<PeerId?, NoError> = _internal_createSupergroup(postbox: context.account.postbox, network: context.account.network, stateManager: context.account.stateManager, title: resolvedGroupTitle, description: nil, username: nil, isForum: false, isForHistoryImport: true)
                        |> map(Optional.init)
                        |> `catch` { _ -> Signal<PeerId?, NoError> in
                            return .single(nil)
                        }
                        
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        let progressSignal = Signal<Never, NoError> { subscriber in
                            let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                            mainWindow?.present(controller, on: .root)
                            return ActionDisposable { [weak controller] in
                                Queue.mainQueue().async() {
                                    controller?.dismiss()
                                }
                            }
                        }
                        |> runOn(Queue.mainQueue())
                        |> delay(0.15, queue: Queue.mainQueue())
                        let progressDisposable = progressSignal.start()
                        
                        signal = signal
                        |> afterDisposed {
                            Queue.mainQueue().async {
                                progressDisposable.dispose()
                            }
                        }
                        let _ = (signal
                                 |> deliverOnMainQueue).start(next: { peerId in
                            if let peerId = peerId {
                                beginWithPeer(peerId)
                            } else {
                            }
                        })
                    }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                    })], actionLayout: .vertical, parseMarkdown: true)
                    mainWindow?.present(controller, on: .root)
                }
                
                navigationController.viewControllers = [controller]
            }
        }, error: { _ in
            beginShare()
        })
    })
}
