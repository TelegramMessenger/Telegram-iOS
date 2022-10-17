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

private let inForeground = ValuePromise<Bool>(false, ignoreRepeated: true)

private final class InternalContext {
    let sharedContext: SharedAccountContextImpl
    let wakeupManager: SharedWakeupManager
    
    init(sharedContext: SharedAccountContextImpl) {
        self.sharedContext = sharedContext
        self.wakeupManager = SharedWakeupManager(beginBackgroundTask: { _, _ in nil }, endBackgroundTask: { _ in }, backgroundTimeRemaining: { 0.0 }, activeAccounts: sharedContext.activeAccountContexts |> map { ($0.0?.account, $0.1.map { ($0.0, $0.1.account) }) }, liveLocationPolling: .single(nil), watchTasks: .single(nil), inForeground: inForeground.get(), hasActiveAudioSession: .single(false), notificationManager: nil, mediaManager: sharedContext.mediaManager, callManager: sharedContext.callManager, accountUserInterfaceInUse: { id in
            return sharedContext.accountUserInterfaceInUse(id)
        })
    }
}

private var globalInternalContext: InternalContext?

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
    
    public init(appBundleId: String, appBuildType: TelegramAppBuildType, appGroupPath: String, apiId: Int32, apiHash: String, languagesCategory: String, encryptionParameters: (Data, Data), appVersion: String, bundleData: Data?) {
        self.appBundleId = appBundleId
        self.appBuildType = appBuildType
        self.appGroupPath = appGroupPath
        self.apiId = apiId
        self.apiHash = apiHash
        self.languagesCategory = languagesCategory
        self.encryptionParameters = encryptionParameters
        self.appVersion = appVersion
        self.bundleData = bundleData
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
    
    private var shouldBeMaster = Promise<Bool>()
    private let disposable = MetaDisposable()
    private var observer1: AnyObject?
    private var observer2: AnyObject?
    
    private weak var navigationController: NavigationController?
    
    public init(initializationData: ShareRootControllerInitializationData, getExtensionContext: @escaping () -> NSExtensionContext?) {
        self.initializationData = initializationData
        self.getExtensionContext = getExtensionContext
    }
    
    deinit {
        self.disposable.dispose()
        self.shouldBeMaster.set(.single(false))
        if let observer = self.observer1 {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = self.observer2 {
            NotificationCenter.default.removeObserver(observer)
        }
    }
    
    public func loadView() {
        telegramUIDeclareEncodables()
        
        if #available(iOSApplicationExtension 8.2, iOS 8.2, *) {
            self.observer1 = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSExtensionHostDidBecomeActive, object: nil, queue: nil, using: { _ in
                inForeground.set(true)
            })
            
            self.observer2 = NotificationCenter.default.addObserver(forName: NSNotification.Name.NSExtensionHostWillResignActive, object: nil, queue: nil, using: { _ in
                inForeground.set(false)
            })
        }
    }
    
    public func viewWillAppear() {
        inForeground.set(true)
    }
    
    public func viewWillDisappear() {
        self.disposable.dispose()
        inForeground.set(false)
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
            
            let applicationBindings = TelegramApplicationBindings(isMainApp: false, appBundleId: self.initializationData.appBundleId, appBuildType: self.initializationData.appBuildType, containerPath: self.initializationData.appGroupPath, appSpecificScheme: "tg", openUrl: { _ in
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
            
            let internalContext: InternalContext
            
            let accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: rootPath + "/accounts-metadata", isTemporary: true, isReadOnly: false, useCaches: false, removeDatabaseOnError: false)
            
            if let globalInternalContext = globalInternalContext {
                internalContext = globalInternalContext
            } else {
                initializeAccountManagement()
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
                
                let sharedContext = SharedAccountContextImpl(mainWindow: nil, sharedContainerPath: self.initializationData.appGroupPath, basePath: rootPath, encryptionParameters: ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: self.initializationData.encryptionParameters.0)!, salt: ValueBoxEncryptionParameters.Salt(data: self.initializationData.encryptionParameters.1)!), accountManager: accountManager, appLockContext: appLockContext, applicationBindings: applicationBindings, initialPresentationDataAndSettings: initialPresentationDataAndSettings!, networkArguments: NetworkInitializationArguments(apiId: self.initializationData.apiId, apiHash: self.initializationData.apiHash, languagesCategory: self.initializationData.languagesCategory, appVersion: self.initializationData.appVersion, voipMaxLayer: 0, voipVersions: [], appData: .single(self.initializationData.bundleData), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider(), resolvedDeviceName: nil), hasInAppPurchases: false, rootPath: rootPath, legacyBasePath: nil, apsNotificationToken: .never(), voipNotificationToken: .never(), setNotificationCall: { _ in }, navigateToChat: { _, _, _ in })
                presentationDataPromise.set(sharedContext.presentationData)
                internalContext = InternalContext(sharedContext: sharedContext)
                globalInternalContext = internalContext
            }
            
            var immediatePeerId: PeerId?
            if #available(iOS 13.2, *), let sendMessageIntent = self.getExtensionContext()?.intent as? INSendMessageIntent {
                if let contact = sendMessageIntent.recipients?.first, let handle = contact.customIdentifier, handle.hasPrefix("tg") {
                    let string = handle.suffix(from: handle.index(handle.startIndex, offsetBy: 2))
                    if let peerId = Int64(string) {
                        immediatePeerId = PeerId(peerId)
                    }
                }
            }
            
            let account: Signal<(SharedAccountContextImpl, Account, [AccountWithInfo]), ShareAuthorizationError> = internalContext.sharedContext.accountManager.transaction { transaction -> (SharedAccountContextImpl, LoggingSettings) in
                return (internalContext.sharedContext, transaction.getSharedData(SharedDataKeys.loggingSettings)?.get(LoggingSettings.self) ?? LoggingSettings.defaultSettings)
            }
            |> castError(ShareAuthorizationError.self)
            |> mapToSignal { sharedContext, loggingSettings -> Signal<(SharedAccountContextImpl, Account, [AccountWithInfo]), ShareAuthorizationError> in
                Logger.shared.logToFile = true//loggingSettings.logToFile
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
            |> take(1)
            
            let applicationInterface = account
            |> mapToSignal { sharedContext, account, otherAccounts -> Signal<(AccountContext, PostboxAccessChallengeData, [AccountWithInfo]), ShareAuthorizationError> in
                let limitsConfigurationAndContentSettings = TelegramEngine(account: account).data.get(
                    TelegramEngine.EngineData.Item.Configuration.Limits(),
                    TelegramEngine.EngineData.Item.Configuration.ContentSettings(),
                    TelegramEngine.EngineData.Item.Configuration.App()
                )
                
                return combineLatest(sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]), limitsConfigurationAndContentSettings, sharedContext.accountManager.accessChallengeData())
                |> take(1)
                |> deliverOnMainQueue
                |> castError(ShareAuthorizationError.self)
                |> map { sharedData, limitsConfigurationAndContentSettings, data -> (AccountContext, PostboxAccessChallengeData, [AccountWithInfo]) in
                    updateLegacyLocalization(strings: sharedContext.currentPresentationData.with({ $0 }).strings)
                    let context = AccountContextImpl(sharedContext: sharedContext, account: account, limitsConfiguration: limitsConfigurationAndContentSettings.0._asLimits(), contentSettings: limitsConfigurationAndContentSettings.1, appConfiguration: limitsConfigurationAndContentSettings.2)
                    return (context, data.data, otherAccounts)
                }
            }
            |> deliverOnMainQueue
            |> afterNext { [weak self] context, accessChallengeData, otherAccounts in
                setupLegacyComponents(context: context)
                initializeLegacyComponents(application: nil, currentSizeClassGetter: { return .compact }, currentHorizontalClassGetter: { return .compact }, documentsPath: "", currentApplicationBounds: { return CGRect() }, canOpenUrl: { _ in return false}, openUrl: { _ in })
                
                let displayShare: () -> Void = {
                    var cancelImpl: (() -> Void)?
                    
                    let beginShare: () -> Void = {
                        let requestUserInteraction: ([UnpreparedShareItemContent]) -> Signal<[PreparedShareItemContent], NoError> = { content in
                            return Signal { [weak self] subscriber in
                                switch content[0] {
                                    case let .contact(data):
                                        let controller = deviceContactInfoController(context: context, subject: .filter(peer: nil, contactId: nil, contactData: data, completion: { peer, contactData in
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
                        
                        let sentItems: ([PeerId], [PreparedShareItemContent], Account, Bool) -> Signal<ShareControllerExternalStatus, NoError> = { peerIds, contents, account, silently in
                            let sentItems = sentShareItems(account: account, to: peerIds, items: contents, silently: silently)
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
                                            
                        let shareController = ShareController(context: context, subject: .fromExternal({ peerIds, additionalText, account, silently in
                            if let strongSelf = self, let inputItems = strongSelf.getExtensionContext()?.inputItems, !inputItems.isEmpty, !peerIds.isEmpty {
                                let rawSignals = TGItemProviderSignals.itemSignals(forInputItems: inputItems)!
                                return preparedShareItems(account: account, to: peerIds[0], dataItems: rawSignals, additionalText: additionalText)
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
                                                return sentItems(peerIds, contents, account, silently)
                                                |> castError(ShareControllerError.self)
                                            }
                                        case let .done(contents):
                                            return sentItems(peerIds, contents, account, silently)
                                            |> castError(ShareControllerError.self)
                                    }
                                }
                            } else {
                                return .single(.done)
                            }
                        }), fromForeignApp: true, externalShare: false, switchableAccounts: otherAccounts, immediatePeerId: immediatePeerId)
                        shareController.presentationArguments = ViewControllerPresentationArguments(presentationAnimation: .modalSheet)
                        shareController.dismissed = { _ in
                            self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                        }
                        shareController.debugAction = {
                            guard let strongSelf = self else {
                                return
                            }
                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                            let navigationController = NavigationController(mode: .single, theme: NavigationControllerTheme(presentationTheme: presentationData.theme))
                            strongSelf.navigationController = navigationController
                            navigationController.viewControllers = [debugController(sharedContext: context.sharedContext, context: context)]
                            strongSelf.mainWindow?.present(navigationController, on: .root)
                        }
                        
                        cancelImpl = { [weak shareController] in
                            shareController?.dismiss(completion: { [weak self] in
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
                                            
                        context.account.resetStateManagement()
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
                                        var otherEntries: [(SSZipEntry, String, TelegramEngine.HistoryImport.MediaType)] = []
                                        var mainFile: TempBoxFile?
                                        
                                        let appConfiguration = context.currentAppConfiguration.with({ $0 })
                                        
                                        /*
                                         history_import_filters: {
                                             "zip": {
                                                 "main_file_patterns": [
                                                     "_chat\\.txt",
                                                     "KakaoTalkChats\\.txt",
                                                     "Talk_.*?\\.txt"
                                                 ]
                                             },
                                             "txt": {
                                                 "patterns": [
                                                     "^\\[LINE\\]"
                                                 ]
                                             }
                                         }
                                         */
                                        
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
                                        
                                        if let mainFile = mainFile, let mainFileHeader = extractTextFileHeader(path :mainFile.path) {
                                            final class TempController: ViewController {
                                                override public var _presentedInModal: Bool {
                                                    get {
                                                        return true
                                                    } set(value) {
                                                    }
                                                }
                                                
                                                private let activityIndicator: ActivityIndicator
                                                
                                                init(context: AccountContext) {
                                                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                                    
                                                    self.activityIndicator = ActivityIndicator(type: .custom(presentationData.theme.list.itemAccentColor, 22.0, 1.0, false))
                                                    
                                                    super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
                                                    
                                                    self.title = presentationData.strings.ChatImport_Title
                                                    self.navigationItem.setLeftBarButton(UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
                                                }
                                                
                                                required public init(coder aDecoder: NSCoder) {
                                                    fatalError("init(coder:) has not been implemented")
                                                }
                                                
                                                @objc private func cancelPressed() {
                                                    //self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                }
                                                
                                                override func displayNodeDidLoad() {
                                                    super.displayNodeDidLoad()
                                                    
                                                    self.displayNode.addSubnode(self.activityIndicator)
                                                }
                                                
                                                override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
                                                    super.containerLayoutUpdated(layout, transition: transition)
                                                    
                                                    let indicatorSize = self.activityIndicator.measure(CGSize(width: 100.0, height: 100.0))
                                                    let navigationHeight = self.navigationLayout(layout: layout).navigationFrame.maxY
                                                    transition.updateFrame(node: self.activityIndicator, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - indicatorSize.width) / 2.0), y: navigationHeight + floor((layout.size.height - navigationHeight - indicatorSize.height) / 2.0)), size: indicatorSize))
                                                }
                                            }
                                            
                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                            let navigationController = NavigationController(mode: .single, theme: NavigationControllerTheme(presentationTheme: presentationData.theme))
                                            strongSelf.navigationController = navigationController
                                            navigationController.viewControllers = [TempController(context: context)]
                                            strongSelf.mainWindow?.present(navigationController, on: .root)
                                            
                                            let _ = (context.engine.historyImport.getInfo(header: mainFileHeader)
                                            |> deliverOnMainQueue).start(next: { parseInfo in
                                                switch parseInfo {
                                                case let .group(groupTitle):
                                                    var attemptSelectionImpl: ((Peer) -> Void)?
                                                    var createNewGroupImpl: (() -> Void)?
                                                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyGroups, .onlyManageable, .excludeDisabled, .doNotSearchMessages], hasContactSelector: false, hasGlobalSearch: false, title: presentationData.strings.ChatImport_Title, attemptSelection: { peer, _ in
                                                        attemptSelectionImpl?(peer)
                                                    }, createNewGroup: {
                                                        createNewGroupImpl?()
                                                    }, pretendPresentedInModal: true))
                                                    
                                                    controller.customDismiss = {
                                                        self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                    }
                                                    
                                                    controller.peerSelected = { peer, _ in
                                                        attemptSelectionImpl?(peer)
                                                    }
                                                    
                                                    controller.navigationPresentation = .default
                                                    
                                                    let beginWithPeer: (PeerId) -> Void = { peerId in
                                                        navigationController.view.endEditing(true)
                                                        navigationController.pushViewController(ChatImportActivityScreen(context: context, cancel: {
                                                            self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                        }, peerId: peerId, archivePath: archivePathValue, mainEntry: mainFile, otherEntries: otherEntries))
                                                    }
                                                    
                                                    attemptSelectionImpl = { peer in
                                                        var errorText: String?
                                                        if let channel = peer as? TelegramChannel {
                                                            if channel.hasPermission(.changeInfo), (channel.flags.contains(.isCreator) || channel.adminRights != nil) {
                                                            } else {
                                                                errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                                                            }
                                                        } else if let group = peer as? TelegramGroup {
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
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                                            })])
                                                            strongSelf.mainWindow?.present(controller, on: .root)
                                                        } else {
                                                            controller.inProgress = true
                                                            let _ = (context.engine.historyImport.checkPeerImport(peerId: peer.id)
                                                            |> deliverOnMainQueue).start(next: { result in
                                                                controller.inProgress = false
                                                                
                                                                let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                                
                                                                var errorText: String?
                                                                if let channel = peer as? TelegramChannel {
                                                                    if channel.hasPermission(.changeInfo), (channel.flags.contains(.isCreator) || channel.adminRights != nil) {
                                                                    } else {
                                                                        errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                                                                    }
                                                                } else if let group = peer as? TelegramGroup {
                                                                    switch group.role {
                                                                    case .creator:
                                                                        break
                                                                    default:
                                                                        errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                                                                    }
                                                                } else if let _ = peer as? TelegramUser {
                                                                } else {
                                                                    errorText = presentationData.strings.ChatImport_SelectionErrorGroupGeneric
                                                                }
                                                                
                                                                if let errorText = errorText {
                                                                    let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                                    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                                                    })])
                                                                    strongSelf.mainWindow?.present(controller, on: .root)
                                                                } else {
                                                                    let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
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
                                                                    strongSelf.mainWindow?.present(controller, on: .root)
                                                                }
                                                            }, error: { error in
                                                                controller.inProgress = false
                                                                
                                                                let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
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
                                                                strongSelf.mainWindow?.present(controller, on: .root)
                                                            })
                                                        }
                                                    }
                                                    
                                                    createNewGroupImpl = {
                                                        let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                        let resolvedGroupTitle: String
                                                        if let groupTitle = groupTitle {
                                                            resolvedGroupTitle = groupTitle
                                                        } else {
                                                            resolvedGroupTitle = "Group"
                                                        }
                                                        let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_CreateGroupAlertTitle, text: presentationData.strings.ChatImport_CreateGroupAlertText(resolvedGroupTitle).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_CreateGroupAlertImportAction, action: {
                                                            var signal: Signal<PeerId?, NoError> = context.engine.peers.createSupergroup(title: resolvedGroupTitle, description: nil, isForHistoryImport: true)
                                                            |> map(Optional.init)
                                                            |> `catch` { _ -> Signal<PeerId?, NoError> in
                                                                return .single(nil)
                                                            }
                                                            
                                                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                                            let progressSignal = Signal<Never, NoError> { subscriber in
                                                                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                                                                if let strongSelf = self {
                                                                    strongSelf.mainWindow?.present(controller, on: .root)
                                                                }
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
                                                        strongSelf.mainWindow?.present(controller, on: .root)
                                                    }
                                                    
                                                    navigationController.viewControllers = [controller]
                                                case let .privateChat(title):
                                                    let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                    
                                                    var attemptSelectionImpl: ((Peer) -> Void)?
                                                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyPrivateChats, .excludeDisabled, .doNotSearchMessages, .excludeSecretChats], hasChatListSelector: false, hasContactSelector: true, hasGlobalSearch: false, title: presentationData.strings.ChatImport_Title, attemptSelection: { peer, _ in
                                                        attemptSelectionImpl?(peer)
                                                    }, pretendPresentedInModal: true))
                                                    
                                                    controller.customDismiss = {
                                                        self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                    }
                                                    
                                                    controller.peerSelected = { peer, _ in
                                                        attemptSelectionImpl?(peer)
                                                    }
                                                    
                                                    controller.navigationPresentation = .default
                                                    
                                                    let beginWithPeer: (PeerId) -> Void = { peerId in
                                                        navigationController.view.endEditing(true)
                                                        navigationController.pushViewController(ChatImportActivityScreen(context: context, cancel: {
                                                            self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                        }, peerId: peerId, archivePath: archivePathValue, mainEntry: mainFile, otherEntries: otherEntries))
                                                    }
                                                    
                                                    attemptSelectionImpl = { [weak controller] peer in
                                                        controller?.inProgress = true
                                                        let _ = (context.engine.historyImport.checkPeerImport(peerId: peer.id)
                                                        |> deliverOnMainQueue).start(next: { result in
                                                            controller?.inProgress = false
                                                            
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                            let text: String
                                                            switch result {
                                                            case .allowed:
                                                                if let title = title {
                                                                    text = presentationData.strings.ChatImport_SelectionConfirmationUserWithTitle(title, EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                                                } else {
                                                                    text = presentationData.strings.ChatImport_SelectionConfirmationUserWithoutTitle(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                                                }
                                                            case let .alert(textValue):
                                                                text = textValue
                                                            }
                                                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_SelectionConfirmationAlertTitle, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                                            }), TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_SelectionConfirmationAlertImportAction, action: {
                                                                beginWithPeer(peer.id)
                                                            })], parseMarkdown: true)
                                                            strongSelf.mainWindow?.present(controller, on: .root)
                                                        }, error: { error in
                                                            controller?.inProgress = false
                                                            
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
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
                                                            strongSelf.mainWindow?.present(controller, on: .root)
                                                        })
                                                    }
                                                    
                                                    navigationController.viewControllers = [controller]
                                                case let .unknown(peerTitle):
                                                    var attemptSelectionImpl: ((Peer) -> Void)?
                                                    var createNewGroupImpl: (() -> Void)?
                                                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.excludeDisabled, .doNotSearchMessages], hasContactSelector: true, hasGlobalSearch: false, title: presentationData.strings.ChatImport_Title, attemptSelection: { peer, _ in
                                                        attemptSelectionImpl?(peer)
                                                    }, createNewGroup: {
                                                        createNewGroupImpl?()
                                                    }, pretendPresentedInModal: true))
                                                    
                                                    controller.customDismiss = {
                                                        self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                    }
                                                    
                                                    controller.peerSelected = { peer, _ in
                                                        attemptSelectionImpl?(peer)
                                                    }
                                                    
                                                    controller.navigationPresentation = .default
                                                    
                                                    let beginWithPeer: (PeerId) -> Void = { peerId in
                                                        navigationController.view.endEditing(true)
                                                        navigationController.pushViewController(ChatImportActivityScreen(context: context, cancel: {
                                                            self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                        }, peerId: peerId, archivePath: archivePathValue, mainEntry: mainFile, otherEntries: otherEntries))
                                                    }
                                                    
                                                    attemptSelectionImpl = { [weak controller] peer in
                                                        controller?.inProgress = true
                                                        let _ = (context.engine.historyImport.checkPeerImport(peerId: peer.id)
                                                        |> deliverOnMainQueue).start(next: { result in
                                                            controller?.inProgress = false
                                                            
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                            
                                                            var errorText: String?
                                                            if let channel = peer as? TelegramChannel {
                                                                if channel.hasPermission(.changeInfo), (channel.flags.contains(.isCreator) || channel.adminRights != nil) {
                                                                } else {
                                                                    errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                                                                }
                                                            } else if let group = peer as? TelegramGroup {
                                                                switch group.role {
                                                                case .creator:
                                                                    break
                                                                default:
                                                                    errorText = presentationData.strings.ChatImport_SelectionErrorNotAdmin
                                                                }
                                                            } else if let _ = peer as? TelegramUser {
                                                            } else {
                                                                errorText = presentationData.strings.ChatImport_SelectionErrorGroupGeneric
                                                            }
                                                            
                                                            if let errorText = errorText {
                                                                let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                                                })])
                                                                strongSelf.mainWindow?.present(controller, on: .root)
                                                            } else {
                                                                let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                                if let _ = peer as? TelegramUser {
                                                                    let text: String
                                                                    switch result {
                                                                    case .allowed:
                                                                        if let title = peerTitle {
                                                                            text = presentationData.strings.ChatImport_SelectionConfirmationUserWithTitle(title, EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                                                        } else {
                                                                            text = presentationData.strings.ChatImport_SelectionConfirmationUserWithoutTitle(EnginePeer(peer).displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)).string
                                                                        }
                                                                    case let .alert(textValue):
                                                                        text = textValue
                                                                    }
                                                                    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_SelectionConfirmationAlertTitle, text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                                                    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_SelectionConfirmationAlertImportAction, action: {
                                                                        beginWithPeer(peer.id)
                                                                    })], parseMarkdown: true)
                                                                    strongSelf.mainWindow?.present(controller, on: .root)
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
                                                                    strongSelf.mainWindow?.present(controller, on: .root)
                                                                }
                                                            }
                                                        }, error: { error in
                                                            controller?.inProgress = false
                                                            
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
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
                                                            strongSelf.mainWindow?.present(controller, on: .root)
                                                        })
                                                    }
                                                    
                                                    createNewGroupImpl = {
                                                        let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                        let resolvedGroupTitle: String
                                                        if let groupTitle = peerTitle {
                                                            resolvedGroupTitle = groupTitle
                                                        } else {
                                                            resolvedGroupTitle = "Group"
                                                        }
                                                        let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.ChatImport_CreateGroupAlertTitle, text: presentationData.strings.ChatImport_CreateGroupAlertText(resolvedGroupTitle).string, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.ChatImport_CreateGroupAlertImportAction, action: {
                                                            var signal: Signal<PeerId?, NoError> = context.engine.peers.createSupergroup(title: resolvedGroupTitle, description: nil, isForHistoryImport: true)
                                                            |> map(Optional.init)
                                                            |> `catch` { _ -> Signal<PeerId?, NoError> in
                                                                return .single(nil)
                                                            }
                                                            
                                                            let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                                            let progressSignal = Signal<Never, NoError> { subscriber in
                                                                let controller = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                                                                if let strongSelf = self {
                                                                    strongSelf.mainWindow?.present(controller, on: .root)
                                                                }
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
                                                        strongSelf.mainWindow?.present(controller, on: .root)
                                                    }
                                                    
                                                    navigationController.viewControllers = [controller]
                                                }
                                            }, error: { _ in
                                                beginShare()
                                            })
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
                
                let _ = passcodeEntryController(context: context, animateIn: true, modalPresentation: modalPresentation, completion: { value in
                    if value {
                        displayShare()
                    } else {
                        Queue.mainQueue().after(0.5, {
                            self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                        })
                    }
                }).start(next: { controller in
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
            
            self.disposable.set(applicationInterface.start(next: { _, _, _ in }, error: { [weak self] error in
                guard let strongSelf = self else {
                    return
                }
                let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: presentationData.strings.Share_AuthTitle, text: presentationData.strings.Share_AuthDescription, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                    self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                })])
                strongSelf.mainWindow?.present(controller, on: .root)
            }, completed: {}))
        }
    }
}
