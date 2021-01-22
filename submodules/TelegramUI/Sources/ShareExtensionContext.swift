import UIKit
import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
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
import ZIPFoundation

private let inForeground = ValuePromise<Bool>(false, ignoreRepeated: true)

private final class InternalContext {
    let sharedContext: SharedAccountContextImpl
    let wakeupManager: SharedWakeupManager
    
    init(sharedContext: SharedAccountContextImpl) {
        self.sharedContext = sharedContext
        self.wakeupManager = SharedWakeupManager(beginBackgroundTask: { _, _ in nil }, endBackgroundTask: { _ in }, backgroundTimeRemaining: { 0.0 }, activeAccounts: sharedContext.activeAccounts |> map { ($0.0, $0.1.map { ($0.0, $0.1) }) }, liveLocationPolling: .single(nil), watchTasks: .single(nil), inForeground: inForeground.get(), hasActiveAudioSession: .single(false), notificationManager: nil, mediaManager: sharedContext.mediaManager, callManager: sharedContext.callManager, accountUserInterfaceInUse: { id in
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
    public let appGroupPath: String
    public let apiId: Int32
    public let apiHash: String
    public let languagesCategory: String
    public let encryptionParameters: (Data, Data)
    public let appVersion: String
    public let bundleData: Data?
    
    public init(appGroupPath: String, apiId: Int32, apiHash: String, languagesCategory: String, encryptionParameters: (Data, Data), appVersion: String, bundleData: Data?) {
        self.appGroupPath = appGroupPath
        self.apiId = apiId
        self.apiHash = apiHash
        self.languagesCategory = languagesCategory
        self.encryptionParameters = encryptionParameters
        self.appVersion = appVersion
        self.bundleData = bundleData
    }
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
            
            TempBox.initializeShared(basePath: rootPath, processType: "share", launchSpecificId: arc4random64())
            
            let logsPath = rootPath + "/share-logs"
            let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
            
            setupSharedLogger(rootPath: rootPath, path: logsPath)
            
            let applicationBindings = TelegramApplicationBindings(isMainApp: false, containerPath: self.initializationData.appGroupPath, appSpecificScheme: "tg", openUrl: { _ in
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
            }, openSettings: {}, openAppStorePage: {}, registerForNotifications: { _ in }, requestSiriAuthorization: { _ in }, siriAuthorization: { return .notDetermined }, getWindowHost: {
                return nil
            }, presentNativeController: { _ in
            }, dismissNativeController: {
            }, getAvailableAlternateIcons: {
                return []
            }, getAlternateIconName: {
                return nil
            }, requestSetAlternateIconName: { _, f in
                f(false)
            })
            
            let internalContext: InternalContext
            
            let accountManager = AccountManager(basePath: rootPath + "/accounts-metadata")
            
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
                
                let sharedContext = SharedAccountContextImpl(mainWindow: nil, basePath: rootPath, encryptionParameters: ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: self.initializationData.encryptionParameters.0)!, salt: ValueBoxEncryptionParameters.Salt(data: self.initializationData.encryptionParameters.1)!), accountManager: accountManager, appLockContext: appLockContext, applicationBindings: applicationBindings, initialPresentationDataAndSettings: initialPresentationDataAndSettings!, networkArguments: NetworkInitializationArguments(apiId: self.initializationData.apiId, apiHash: self.initializationData.apiHash, languagesCategory: self.initializationData.languagesCategory, appVersion: self.initializationData.appVersion, voipMaxLayer: 0, voipVersions: [], appData: .single(self.initializationData.bundleData), autolockDeadine: .single(nil), encryptionProvider: OpenSSLEncryptionProvider()), rootPath: rootPath, legacyBasePath: nil, legacyCache: nil, apsNotificationToken: .never(), voipNotificationToken: .never(), setNotificationCall: { _ in }, navigateToChat: { _, _, _ in })
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
                return (internalContext.sharedContext, transaction.getSharedData(SharedDataKeys.loggingSettings) as? LoggingSettings ?? LoggingSettings.defaultSettings)
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
                    let intentsSettings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.intentsSettings) as? IntentsSettings ?? IntentsSettings.defaultSettings
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
                let limitsConfigurationAndContentSettings = account.postbox.transaction { transaction -> (LimitsConfiguration, ContentSettings, AppConfiguration) in
                    return (
                        transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue,
                        getContentSettings(transaction: transaction),
                        getAppConfiguration(transaction: transaction)
                    )
                }
                return combineLatest(sharedContext.accountManager.sharedData(keys: [ApplicationSpecificSharedDataKeys.presentationPasscodeSettings]), limitsConfigurationAndContentSettings, sharedContext.accountManager.accessChallengeData())
                |> take(1)
                |> deliverOnMainQueue
                |> castError(ShareAuthorizationError.self)
                |> map { sharedData, limitsConfigurationAndContentSettings, data -> (AccountContext, PostboxAccessChallengeData, [AccountWithInfo]) in
                    updateLegacyLocalization(strings: sharedContext.currentPresentationData.with({ $0 }).strings)
                    let context = AccountContextImpl(sharedContext: sharedContext, account: account, limitsConfiguration: limitsConfigurationAndContentSettings.0, contentSettings: limitsConfigurationAndContentSettings.1, appConfiguration: limitsConfigurationAndContentSettings.2)
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
                        
                        let sentItems: ([PeerId], [PreparedShareItemContent], Account) -> Signal<ShareControllerExternalStatus, NoError> = { peerIds, contents, account in
                            let sentItems = sentShareItems(account: account, to: peerIds, items: contents)
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
                                            
                        let shareController = ShareController(context: context, subject: .fromExternal({ peerIds, additionalText, account in
                            if let strongSelf = self, let inputItems = strongSelf.getExtensionContext()?.inputItems, !inputItems.isEmpty, !peerIds.isEmpty {
                                let rawSignals = TGItemProviderSignals.itemSignals(forInputItems: inputItems)!
                                return preparedShareItems(account: account, to: peerIds[0], dataItems: rawSignals, additionalText: additionalText)
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<PreparedShareItems?, NoError> in
                                    return .single(nil)
                                }
                                |> mapToSignal { state -> Signal<ShareControllerExternalStatus, NoError> in
                                    guard let state = state else {
                                        return .single(.done)
                                    }
                                    switch state {
                                        case .preparing:
                                            return .single(.preparing)
                                        case let .progress(value):
                                            return .single(.progress(value))
                                        case let .userInteractionRequired(value):
                                            return requestUserInteraction(value)
                                            |> mapToSignal { contents -> Signal<ShareControllerExternalStatus, NoError> in
                                                return sentItems(peerIds, contents, account)
                                            }
                                        case let .done(contents):
                                            return sentItems(peerIds, contents, account)
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
                        
                        cancelImpl = { [weak shareController] in
                            shareController?.dismiss(completion: { [weak self] in
                                self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                            })
                        }
                        
                        if let strongSelf = self {
                            if let currentShareController = strongSelf.currentShareController {
                                currentShareController.dismiss()
                            }
                            strongSelf.currentShareController = shareController
                            strongSelf.mainWindow?.present(shareController, on: .root)
                        }
                                            
                        context.account.resetStateManagement()
                    }
                    
                    /*if let application = UIApplication.value(forKeyPath: #keyPath(UIApplication.shared)) as? UIApplication {
                        let selector = NSSelectorFromString("openURL:")
                        let url = URL(string: "tg://open")!
                        application.perform(selector, with: url)
                    }*/
                    
                    if let strongSelf = self, let inputItems = strongSelf.getExtensionContext()?.inputItems, inputItems.count == 1, let item = inputItems[0] as? NSExtensionItem, let attachments = item.attachments {
                        for attachment in attachments {
                            if attachment.hasItemConformingToTypeIdentifier(kUTTypeFileURL as String) {
                                attachment.loadItem(forTypeIdentifier: kUTTypeFileURL as String, completionHandler: { result, error in
                                    Queue.mainQueue().async {
                                        guard let url = result as? URL else {
                                            beginShare()
                                            return
                                        }
                                        guard let fileName = url.pathComponents.last else {
                                            beginShare()
                                            return
                                        }
                                        let fileExtension = (fileName as NSString).pathExtension
                                        guard fileExtension.lowercased() == "zip" else {
                                            beginShare()
                                            return
                                        }
                                        guard let archive = Archive(url: url, accessMode: .read) else {
                                            beginShare()
                                            return
                                        }
                                        guard let _ = archive["_chat.txt"] else {
                                            beginShare()
                                            return
                                        }
                                        
                                        let photoRegex = try! NSRegularExpression(pattern: "[\\d]+-PHOTO-.*?\\.jpg")
                                        let videoRegex = try! NSRegularExpression(pattern: "[\\d]+-VIDEO-.*?\\.mp4")
                                        let stickerRegex = try! NSRegularExpression(pattern: "[\\d]+-STICKER-.*?\\.webp")
                                        let voiceRegex = try! NSRegularExpression(pattern: "[\\d]+-AUDIO-.*?\\.opus")
                                        
                                        var otherEntries: [(Entry, String, ChatHistoryImport.MediaType)] = []
                                        
                                        var mainFile: TempBoxFile?
                                        do {
                                            for entry in archive {
                                                let entryPath = entry.path(using: .utf8).replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "..", with: "_")
                                                if entryPath.isEmpty {
                                                    continue
                                                }
                                                let tempFile = TempBox.shared.tempFile(fileName: entryPath)
                                                if entryPath == "_chat.txt" {
                                                    let _ = try archive.extract(entry, to: URL(fileURLWithPath: tempFile.path))
                                                    mainFile = tempFile
                                                } else {
                                                    let entryFileName = (entryPath as NSString).lastPathComponent
                                                    if !entryFileName.isEmpty {
                                                        let mediaType: ChatHistoryImport.MediaType
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
                                        } catch {
                                        }
                                        
                                        if let mainFile = mainFile, let mainFileText = try? String(contentsOf: URL(fileURLWithPath: mainFile.path)) {
                                            let mainFileHeader: String
                                            if mainFileText.count < 1000 {
                                                mainFileHeader = mainFileText
                                            } else {
                                                mainFileHeader = String(mainFileText[mainFileText.startIndex ..< mainFileText.index(mainFileText.startIndex, offsetBy: 1000)])
                                            }
                                            
                                            final class TempController: ViewController {
                                                override public var _presentedInModal: Bool {
                                                    get {
                                                        return true
                                                    } set(value) {
                                                    }
                                                }
                                                
                                                init(context: AccountContext) {
                                                    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                                                    
                                                    super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: presentationData))
                                                    
                                                    self.title = "Import Chat"
                                                    self.navigationItem.setLeftBarButton(UIBarButtonItem(title: presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
                                                }
                                                
                                                required public init(coder aDecoder: NSCoder) {
                                                    fatalError("init(coder:) has not been implemented")
                                                }
                                                
                                                @objc private func cancelPressed() {
                                                    //self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                }
                                            }
                                            
                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                            let navigationController = NavigationController(mode: .single, theme: NavigationControllerTheme(presentationTheme: presentationData.theme))
                                            navigationController.viewControllers = [TempController(context: context)]
                                            strongSelf.mainWindow?.present(navigationController, on: .root)
                                            
                                            let _ = (ChatHistoryImport.getInfo(account: context.account, header: mainFileHeader)
                                            |> deliverOnMainQueue).start(next: { parseInfo in
                                                switch parseInfo {
                                                case let .group(groupTitle):
                                                    //TODO:localize
                                                    var attemptSelectionImpl: ((Peer) -> Void)?
                                                    var createNewGroupImpl: (() -> Void)?
                                                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyGroups, .onlyManageable, .excludeDisabled, .doNotSearchMessages], hasContactSelector: false, hasGlobalSearch: false, title: "Import Chat", attemptSelection: { peer in
                                                        attemptSelectionImpl?(peer)
                                                    }, createNewGroup: {
                                                        createNewGroupImpl?()
                                                    }, pretendPresentedInModal: true))
                                                    
                                                    controller.customDismiss = {
                                                        self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                    }
                                                    
                                                    controller.peerSelected = { peer in
                                                        attemptSelectionImpl?(peer)
                                                    }
                                                    
                                                    controller.navigationPresentation = .default
                                                    
                                                    let beginWithPeer: (PeerId) -> Void = { peerId in
                                                        navigationController.view.endEditing(true)
                                                        navigationController.pushViewController(ChatImportActivityScreen(context: context, cancel: {
                                                            self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                        }, peerId: peerId, archive: archive, mainEntry: mainFile, otherEntries: otherEntries))
                                                    }
                                                    
                                                    attemptSelectionImpl = { peer in
                                                        var errorText: String?
                                                        if let channel = peer as? TelegramChannel {
                                                            if channel.flags.contains(.isCreator) || channel.adminRights != nil {
                                                            } else {
                                                                errorText = "You need to be an admin of the group to import messages into it."
                                                            }
                                                        } else if let group = peer as? TelegramGroup {
                                                            switch group.role {
                                                            case .creator:
                                                                break
                                                            default:
                                                                errorText = "You need to be an admin of the group to import messages into it."
                                                            }
                                                        } else {
                                                            errorText = "You can't import history into this group."
                                                        }
                                                        
                                                        if let errorText = errorText {
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                                            })])
                                                            strongSelf.mainWindow?.present(controller, on: .root)
                                                        } else {
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                            let text: String
                                                            if let groupTitle = groupTitle {
                                                                text = "Are you sure you want to import messages from **\(groupTitle)** into **\(peer.debugDisplayTitle)**?"
                                                            } else {
                                                                text = "Are you sure you want to import messages into **\(peer.debugDisplayTitle)**?"
                                                            }
                                                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: "Import Messages", text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                                            }), TextAlertAction(type: .defaultAction, title: "Import", action: {
                                                                beginWithPeer(peer.id)
                                                            })], parseMarkdown: true)
                                                            strongSelf.mainWindow?.present(controller, on: .root)
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
                                                        let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: "Create Group and Import Messages", text: "Are you sure you want to create group **\(resolvedGroupTitle)** and import messages from another messaging app?", actions: [TextAlertAction(type: .defaultAction, title: "Create and Import", action: {
                                                            var signal: Signal<PeerId?, NoError> = createSupergroup(account: context.account, title: resolvedGroupTitle, description: nil, isForHistoryImport: true)
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
                                                                    //TODO:localize
                                                                }
                                                            })
                                                        }), TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                                        })], parseMarkdown: true)
                                                        strongSelf.mainWindow?.present(controller, on: .root)
                                                    }
                                                    
                                                    navigationController.viewControllers = [controller]
                                                    strongSelf.mainWindow?.present(navigationController, on: .root)
                                                case let .privateChat(title):
                                                    let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                    let navigationController = NavigationController(mode: .single, theme: NavigationControllerTheme(presentationTheme: presentationData.theme))
                                                    
                                                    //TODO:localize
                                                    var attemptSelectionImpl: ((Peer) -> Void)?
                                                    let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyPrivateChats, .excludeDisabled, .doNotSearchMessages], hasChatListSelector: false, hasContactSelector: true, hasGlobalSearch: false, title: "Import Chat", attemptSelection: { peer in
                                                        attemptSelectionImpl?(peer)
                                                    }, pretendPresentedInModal: true))
                                                    
                                                    controller.customDismiss = {
                                                        self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                    }
                                                    
                                                    controller.peerSelected = { peer in
                                                        attemptSelectionImpl?(peer)
                                                    }
                                                    
                                                    controller.navigationPresentation = .default
                                                    
                                                    let beginWithPeer: (PeerId) -> Void = { peerId in
                                                        navigationController.view.endEditing(true)
                                                        navigationController.pushViewController(ChatImportActivityScreen(context: context, cancel: {
                                                            self?.getExtensionContext()?.completeRequest(returningItems: nil, completionHandler: nil)
                                                        }, peerId: peerId, archive: archive, mainEntry: mainFile, otherEntries: otherEntries))
                                                    }
                                                    
                                                    attemptSelectionImpl = { [weak controller] peer in
                                                        controller?.inProgress = true
                                                        let _ = (ChatHistoryImport.checkPeerImport(account: context.account, peerId: peer.id)
                                                        |> deliverOnMainQueue).start(error: { error in
                                                            controller?.inProgress = false
                                                            
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                            let errorText: String
                                                            switch error {
                                                            case .generic:
                                                                errorText = presentationData.strings.Login_UnknownError
                                                            case .userIsNotMutualContact:
                                                                errorText = "You can only import messages into private chats with users who added you in their contact list."
                                                            }
                                                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: errorText, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                                            })])
                                                            strongSelf.mainWindow?.present(controller, on: .root)
                                                        }, completed: {
                                                            controller?.inProgress = false
                                                            
                                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                            let text: String
                                                            if let title = title {
                                                                text = "Are you sure you want to import messages from **\(title)** into the chat with **\(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))**?"
                                                            } else {
                                                                text = "Are you sure you want to import messages into the chat with **\(peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder))**?"
                                                            }
                                                            let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: "Import Messages", text: text, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                                            }), TextAlertAction(type: .defaultAction, title: "Import", action: {
                                                                beginWithPeer(peer.id)
                                                            })], parseMarkdown: true)
                                                            strongSelf.mainWindow?.present(controller, on: .root)
                                                        })
                                                    }
                                                    
                                                    navigationController.viewControllers = [controller]
                                                    strongSelf.mainWindow?.present(navigationController, on: .root)
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
