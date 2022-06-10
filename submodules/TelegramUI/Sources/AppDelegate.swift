import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import UserNotifications
import Intents
import Postbox
import PushKit
import AsyncDisplayKit
import TelegramUIPreferences
import TelegramPresentationData
import TelegramCallsUI
import TelegramVoip
import BuildConfig
import BuildConfigExtra
import DeviceCheck
import AccountContext
import OverlayStatusController
import UndoUI
import LegacyUI
import PassportUI
import WatchBridge
import SettingsUI
import AppBundle
import UrlHandling
import OpenSSLEncryptionProvider
import AppLock
import PresentationDataUtils
import TelegramIntents
import AccountUtils
import CoreSpotlight
import TelegramAudio
import DebugSettingsUI
import BackgroundTasks
import UIKitRuntimeUtils
import StoreKit

#if canImport(AppCenter)
import AppCenter
import AppCenterCrashes
#endif

private let handleVoipNotifications = false

private var testIsLaunched = false

private func isKeyboardWindow(window: NSObject) -> Bool {
    let typeName = NSStringFromClass(type(of: window))
    if #available(iOS 9.0, *) {
        if typeName.hasPrefix("UI") && typeName.hasSuffix("RemoteKeyboardWindow") {
            return true
        }
    } else {
        if typeName.hasPrefix("UI") && typeName.hasSuffix("TextEffectsWindow") {
            return true
        }
    }
    return false
}

private func isKeyboardView(view: NSObject) -> Bool {
    let typeName = NSStringFromClass(type(of: view))
    if typeName.hasPrefix("UI") && typeName.hasSuffix("InputSetHostView") {
        return true
    }
    return false
}

private func isKeyboardViewContainer(view: NSObject) -> Bool {
    let typeName = NSStringFromClass(type(of: view))
    if typeName.hasPrefix("UI") && typeName.hasSuffix("InputSetContainerView") {
        return true
    }
    return false
}

private class ApplicationStatusBarHost: StatusBarHost {
    private let application = UIApplication.shared
    
    var isApplicationInForeground: Bool {
        switch self.application.applicationState {
        case .background:
            return false
        default:
            return true
        }
    }
    
    var statusBarFrame: CGRect {
        return self.application.statusBarFrame
    }
    var statusBarStyle: UIStatusBarStyle {
        get {
            return self.application.statusBarStyle
        } set(value) {
            self.setStatusBarStyle(value, animated: false)
        }
    }
    
    func setStatusBarStyle(_ style: UIStatusBarStyle, animated: Bool) {
        if self.shouldChangeStatusBarStyle?(style) ?? true {
            self.application.internalSetStatusBarStyle(style, animated: animated)
        }
    }
    
    var shouldChangeStatusBarStyle: ((UIStatusBarStyle) -> Bool)?
    
    func setStatusBarHidden(_ value: Bool, animated: Bool) {
        self.application.internalSetStatusBarHidden(value, animation: animated ? .fade : .none)
    }
    
    var keyboardWindow: UIWindow? {
        for window in UIApplication.shared.windows {
            if isKeyboardWindow(window: window) {
                return window
            }
        }
        return nil
    }
    
    var keyboardView: UIView? {
        guard let keyboardWindow = self.keyboardWindow else {
            return nil
        }
        
        for view in keyboardWindow.subviews {
            if isKeyboardViewContainer(view: view) {
                for subview in view.subviews {
                    if isKeyboardView(view: subview) {
                        return subview
                    }
                }
            }
        }
        return nil
    }
}

private func legacyDocumentsPath() -> String {
    return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0] + "/legacy"
}

protocol SupportedStartCallIntent {
    @available(iOS 10.0, *)
    var contacts: [INPerson]? { get }
}

@available(iOS 10.0, *)
extension INStartAudioCallIntent: SupportedStartCallIntent {}

protocol SupportedStartVideoCallIntent {
    @available(iOS 10.0, *)
    var contacts: [INPerson]? { get }
}

@available(iOS 10.0, *)
extension INStartVideoCallIntent: SupportedStartVideoCallIntent {}

private enum QueuedWakeup: Int32 {
    case call
    case backgroundLocation
}

final class SharedApplicationContext {
    let sharedContext: SharedAccountContextImpl
    let notificationManager: SharedNotificationManager
    let wakeupManager: SharedWakeupManager
    let overlayMediaController: ViewController & OverlayMediaController
    
    init(sharedContext: SharedAccountContextImpl, notificationManager: SharedNotificationManager, wakeupManager: SharedWakeupManager) {
        self.sharedContext = sharedContext
        self.notificationManager = notificationManager
        self.wakeupManager = wakeupManager
        self.overlayMediaController = OverlayMediaControllerImpl()
    }
}

private struct AccountManagerState {
    struct NotificationKey {
        var accountId: AccountRecordId
        var id: Data
        var key: Data
    }

    var notificationKeys: [NotificationKey]
}

private func extractAccountManagerState(records: AccountRecordsView<TelegramAccountManagerTypes>) -> AccountManagerState {
    return AccountManagerState(
        notificationKeys: records.records.compactMap { record -> AccountManagerState.NotificationKey? in
            for attribute in record.attributes {
                if case let .backupData(backupData) = attribute {
                    if let notificationEncryptionKeyId = backupData.data?.notificationEncryptionKeyId, let notificationEncryptionKey = backupData.data?.notificationEncryptionKey {
                        return AccountManagerState.NotificationKey(
                            accountId: record.id,
                            id: notificationEncryptionKeyId,
                            key: notificationEncryptionKey
                        )
                    }
                }
            }
            return nil
        }
    )
}

@objc(AppDelegate) class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate, UNUserNotificationCenterDelegate {
    @objc var window: UIWindow?
    var nativeWindow: (UIWindow & WindowHost)?
    var mainWindow: Window1!
    private var dataImportSplash: LegacyDataImportSplash?
    
    private var buildConfig: BuildConfig?
    let episodeId = arc4random()
    
    private let isInForegroundPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isInForegroundValue = false
    private let isActivePromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isActiveValue = false
    let hasActiveAudioSession = Promise<Bool>(false)
    
    private let sharedContextPromise = Promise<SharedApplicationContext>()
    private let watchCommunicationManagerPromise = Promise<WatchCommunicationManager?>()

    private var accountManager: AccountManager<TelegramAccountManagerTypes>?
    private var accountManagerState: AccountManagerState?
    
    private var contextValue: AuthorizedApplicationContext?
    private let context = Promise<AuthorizedApplicationContext?>()
    private let contextDisposable = MetaDisposable()
    
    private var authContextValue: UnauthorizedApplicationContext?
    private let authContext = Promise<UnauthorizedApplicationContext?>()
    private let authContextDisposable = MetaDisposable()
    
    private let logoutDisposable = MetaDisposable()
    
    private let openNotificationSettingsWhenReadyDisposable = MetaDisposable()
    private let openChatWhenReadyDisposable = MetaDisposable()
    private let openUrlWhenReadyDisposable = MetaDisposable()
    
    private let badgeDisposable = MetaDisposable()
    private let quickActionsDisposable = MetaDisposable()
    
    private var pushRegistry: PKPushRegistry?
    
    private let notificationAuthorizationDisposable = MetaDisposable()
    
    private var replyFromNotificationsDisposables = DisposableSet()
    private var watchedCallsDisposables = DisposableSet()
    
    private var _notificationTokenPromise: Promise<Data>?
    private let voipTokenPromise = Promise<Data>()
    
    private var notificationTokenPromise: Promise<Data> {
        if let current = self._notificationTokenPromise {
            return current
        } else {
            let promise = Promise<Data>()
            self._notificationTokenPromise = promise
            
            return promise
        }
    }
    
    private var clearNotificationsManager: ClearNotificationsManager?
    
    private let idleTimerExtensionSubscribers = Bag<Void>()
    
    private var alertActions: (primary: (() -> Void)?, other: (() -> Void)?)?
    
    private let deviceToken = Promise<Data?>(nil)
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        precondition(!testIsLaunched)
        testIsLaunched = true
        
        let _ = voipTokenPromise.get().start(next: { token in
            self.deviceToken.set(.single(token))
        })
        
        let launchStartTime = CFAbsoluteTimeGetCurrent()
        
        let statusBarHost = ApplicationStatusBarHost()
        let (window, hostView) = nativeWindowHostView()
        self.mainWindow = Window1(hostView: hostView, statusBarHost: statusBarHost)
        if let traitCollection = window.rootViewController?.traitCollection {
            if #available(iOS 13.0, *) {
                switch traitCollection.userInterfaceStyle {
                case .light, .unspecified:
                    hostView.containerView.backgroundColor = UIColor.white
                default:
                    hostView.containerView.backgroundColor = UIColor.black
                }
            } else {
                hostView.containerView.backgroundColor = UIColor.white
            }
        } else {
            hostView.containerView.backgroundColor = UIColor.white
        }
        self.window = window
        self.nativeWindow = window
        
        let clearNotificationsManager = ClearNotificationsManager(getNotificationIds: { completion in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getDeliveredNotifications(completionHandler: { notifications in
                    var result: [(String, NotificationManagedNotificationRequestId)] = []
                    for notification in notifications {
                        if let requestId = NotificationManagedNotificationRequestId(string: notification.request.identifier) {
                            result.append((notification.request.identifier, requestId))
                        } else {
                            let payload = notification.request.content.userInfo
                            var notificationRequestId: NotificationManagedNotificationRequestId?
                            
                            var peerId: PeerId?
                            if let fromId = payload["from_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
                            } else if let fromId = payload["chat_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
                            } else if let fromId = payload["channel_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
                            }
                            
                            if let msgId = payload["msg_id"] {
                                let msgIdValue = msgId as! NSString
                                if let peerId = peerId {
                                    notificationRequestId = .messageId(MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue)))
                                }
                            }
                            
                            if let notificationRequestId = notificationRequestId {
                                result.append((notification.request.identifier, notificationRequestId))
                            }
                        }
                    }
                    completion.f(result)
                })
            } else {
                var result: [(String, NotificationManagedNotificationRequestId)] = []
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if let requestId = NotificationManagedNotificationRequestId(string: id) {
                                result.append((id, requestId))
                            }
                        }
                    }
                }
                completion.f(result)
            }
        }, removeNotificationIds: { ids in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
            } else {
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if ids.contains(id) {
                                UIApplication.shared.cancelLocalNotification(notification)
                            }
                        }
                    }
                }
            }
        }, getPendingNotificationIds: { completion in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().getPendingNotificationRequests(completionHandler: { requests in
                    var result: [(String, NotificationManagedNotificationRequestId)] = []
                    for request in requests {
                        if let requestId = NotificationManagedNotificationRequestId(string: request.identifier) {
                            result.append((request.identifier, requestId))
                        }
                    }
                    completion.f(result)
                })
            } else {
                var result: [(String, NotificationManagedNotificationRequestId)] = []
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if let requestId = NotificationManagedNotificationRequestId(string: id) {
                                result.append((id, requestId))
                            }
                        }
                    }
                }
                completion.f(result)
            }
        }, removePendingNotificationIds: { ids in
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
            } else {
                if let notifications = UIApplication.shared.scheduledLocalNotifications {
                    for notification in notifications {
                        if let userInfo = notification.userInfo, let id = userInfo["id"] as? String {
                            if ids.contains(id) {
                                UIApplication.shared.cancelLocalNotification(notification)
                            }
                        }
                    }
                }
            }
        })
        self.clearNotificationsManager = clearNotificationsManager
        
        let appVersion = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "unknown"
        
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        let appGroupName = "group.\(baseAppBundleId)"
        let maybeAppGroupUrl = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupName)
        
        let buildConfig = BuildConfig(baseAppBundleId: baseAppBundleId)
        self.buildConfig = buildConfig
        let signatureDict = BuildConfigExtra.signatureDict()
        
        let apiId: Int32 = buildConfig.apiId
        let apiHash: String = buildConfig.apiHash
        let languagesCategory = "ios"
        
        let autolockDeadine: Signal<Int32?, NoError>
        if #available(iOS 10.0, *) {
            autolockDeadine = .single(nil)
        } else {
            autolockDeadine = self.context.get()
            |> mapToSignal { context -> Signal<Int32?, NoError> in
                guard let context = context else {
                    return .single(nil)
                }
                return context.context.sharedContext.appLockContext.autolockDeadline
            }
        }
        
        let networkArguments = NetworkInitializationArguments(apiId: apiId, apiHash: apiHash, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: PresentationCallManagerImpl.voipMaxLayer, voipVersions: PresentationCallManagerImpl.voipVersions(includeExperimental: true, includeReference: false).map { version, supportsVideo -> CallSessionManagerImplementationVersion in
            CallSessionManagerImplementationVersion(version: version, supportsVideo: supportsVideo)
        }, appData: self.deviceToken.get()
        |> map { token in
            let data = buildConfig.bundleData(withAppToken: token, signatureDict: signatureDict)
            if let data = data, let _ = String(data: data, encoding: .utf8) {
            } else {
                Logger.shared.log("data", "can't deserialize")
            }
            return data
        }, autolockDeadine: autolockDeadine, encryptionProvider: OpenSSLEncryptionProvider(), resolvedDeviceName: nil)
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            self.mainWindow?.presentNative(UIAlertController(title: nil, message: "Error 2", preferredStyle: .alert))
            return true
        }
        
        var isDebugConfiguration = false
        #if DEBUG
        isDebugConfiguration = true
        #endif
        
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            isDebugConfiguration = true
        }
        
        if isDebugConfiguration || buildConfig.isInternalBuild {
            LoggingSettings.defaultSettings = LoggingSettings(logToFile: true, logToConsole: false, redactSensitiveData: true)
        } else {
            LoggingSettings.defaultSettings = LoggingSettings(logToFile: false, logToConsole: false, redactSensitiveData: true)
        }
        
        let rootPath = rootPathForBasePath(appGroupUrl.path)
        performAppGroupUpgrades(appGroupPath: appGroupUrl.path, rootPath: rootPath)
        
        let deviceSpecificEncryptionParameters = BuildConfig.deviceSpecificEncryptionParameters(rootPath, baseAppBundleId: baseAppBundleId)
        let encryptionParameters = ValueBoxEncryptionParameters(forceEncryptionIfNoSet: false, key: ValueBoxEncryptionParameters.Key(data: deviceSpecificEncryptionParameters.key)!, salt: ValueBoxEncryptionParameters.Salt(data: deviceSpecificEncryptionParameters.salt)!)
        
        TempBox.initializeShared(basePath: rootPath, processType: "app", launchSpecificId: Int64.random(in: Int64.min ... Int64.max))
        
        let legacyLogs: [String] = [
            "logs",
            "broadcast-logs",
            "siri-logs",
            "widget-logs",
            "notificationcontent-logs",
            "notification-logs"
        ]
        for item in legacyLogs {
            let _ = try? FileManager.default.removeItem(atPath: "\(rootPath)/\(item)")
        }
        
        let logsPath = rootPath + "/logs/app-logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        Logger.setSharedLogger(Logger(rootPath: rootPath, basePath: logsPath))

        setManagedAudioSessionLogger({ s in
            Logger.shared.log("ManagedAudioSession", s)
            Logger.shared.shortLog("ManagedAudioSession", s)
        })
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath + "/accounts-metadata"), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
            for url in contents {
                Logger.shared.log("App \(self.episodeId)", "metadata: \(url.path)")
            }
        }
        
        if let contents = try? FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: rootPath), includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
            for url in contents {
                Logger.shared.log("App \(self.episodeId)", "root: \(url.path)")
                if url.lastPathComponent.hasPrefix("account-") {
                    if let subcontents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsSubdirectoryDescendants]) {
                        for suburl in subcontents {
                            Logger.shared.log("App \(self.episodeId)", "account \(url.lastPathComponent): \(suburl.path)")
                        }
                    }
                }
            }
        }
        
        //ASDisableLogging()
        
        initializeLegacyComponents(application: application, currentSizeClassGetter: {
            return UIUserInterfaceSizeClass.compact
        }, currentHorizontalClassGetter: {
            return UIUserInterfaceSizeClass.compact
        }, documentsPath: legacyDocumentsPath(), currentApplicationBounds: {
            return UIScreen.main.bounds
        }, canOpenUrl: { url in
            return UIApplication.shared.canOpenURL(url)
        }, openUrl: { url in
            UIApplication.shared.openURL(url)
        })
        
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
        }
        
        GlobalExperimentalSettings.isAppStoreBuild = buildConfig.isAppStoreBuild
        GlobalExperimentalSettings.enableFeed = false
        
        self.window?.makeKeyAndVisible()
        
        self.hasActiveAudioSession.set(MediaManagerImpl.globalAudioSession.isActive())
        
        let applicationBindings = TelegramApplicationBindings(isMainApp: true, appBundleId: baseAppBundleId, appBuildType: buildConfig.isAppStoreBuild ? .public : .internal, containerPath: appGroupUrl.path, appSpecificScheme: buildConfig.appSpecificUrlScheme, openUrl: { url in
            var parsedUrl = URL(string: url)
            if let parsed = parsedUrl {
                if parsed.scheme == nil || parsed.scheme!.isEmpty {
                    parsedUrl = URL(string: "https://\(url)")
                }
                if parsed.scheme == "tg" {
                    return
                }
            }
            
            if let parsedUrl = parsedUrl {
                UIApplication.shared.openURL(parsedUrl)
            } else if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                UIApplication.shared.openURL(parsedUrl)
            }
        }, openUniversalUrl: { url, completion in
            if #available(iOS 10.0, *) {
                var parsedUrl = URL(string: url)
                if let parsed = parsedUrl {
                    if parsed.scheme == nil || parsed.scheme!.isEmpty {
                        parsedUrl = URL(string: "https://\(url)")
                    }
                }
                
                if let parsedUrl = parsedUrl {
                    return UIApplication.shared.open(parsedUrl, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: true as NSNumber], completionHandler: { value in
                        completion.completion(value)
                    })
                } else if let escapedUrl = (url.removingPercentEncoding ?? url).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                    return UIApplication.shared.open(parsedUrl, options: [UIApplication.OpenExternalURLOptionsKey.universalLinksOnly: true as NSNumber], completionHandler: { value in
                        completion.completion(value)
                    })
                } else {
                    completion.completion(false)
                }
            } else {
                completion.completion(false)
            }
        }, canOpenUrl: { url in
            var parsedUrl = URL(string: url)
            if let parsed = parsedUrl {
                if parsed.scheme == nil || parsed.scheme!.isEmpty {
                    parsedUrl = URL(string: "https://\(url)")
                }
            }
            if let parsedUrl = parsedUrl {
                return UIApplication.shared.canOpenURL(parsedUrl)
            } else if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let parsedUrl = URL(string: escapedUrl) {
                return UIApplication.shared.canOpenURL(parsedUrl)
            } else {
                return false
            }
        }, getTopWindow: {
            for window in application.windows.reversed() {
                if window === self.window || window === statusBarHost.keyboardWindow {
                    return window
                }
            }
            return application.windows.last
        }, displayNotification: { text in
        }, applicationInForeground: self.isInForegroundPromise.get(),
           applicationIsActive: self.isActivePromise.get(),
           clearMessageNotifications: { ids in
            for id in ids {
                self.clearNotificationsManager?.append(id)
            }
        }, pushIdleTimerExtension: {
            let disposable = MetaDisposable()
            Queue.mainQueue().async {
                let wasEmpty = self.idleTimerExtensionSubscribers.isEmpty
                let index = self.idleTimerExtensionSubscribers.add(Void())
                
                if wasEmpty {
                    application.isIdleTimerDisabled = true
                }
                
                disposable.set(ActionDisposable {
                    Queue.mainQueue().async {
                        self.idleTimerExtensionSubscribers.remove(index)
                        if self.idleTimerExtensionSubscribers.isEmpty {
                            application.isIdleTimerDisabled = false
                        }
                    }
                })
            }
            
            return disposable
        }, openSettings: {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.openURL(url)
            }
        }, openAppStorePage: {
            let appStoreId = buildConfig.appStoreId
            if let url = URL(string: "itms-apps://itunes.apple.com/app/id\(appStoreId)") {
                UIApplication.shared.openURL(url)
            }
        }, openSubscriptions: {
            if #available(iOS 15, *), let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                Task {
                    try await AppStore.showManageSubscriptions(in: scene)
                }
            } else if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                UIApplication.shared.openURL(url)
            }
        }, registerForNotifications: { completion in
            let _ = (self.context.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { context in
                if let context = context {
                    self.registerForNotifications(context: context.context, authorize: true, completion: completion)
                }
            })
        }, requestSiriAuthorization: { completion in
            if #available(iOS 10, *) {
                INPreferences.requestSiriAuthorization { status in
                    if case .authorized = status {
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            } else {
                completion(false)
            }
        }, siriAuthorization: {
            if #available(iOS 10, *) {
                switch INPreferences.siriAuthorizationStatus() {
                    case .authorized:
                        return .allowed
                    case .denied, .restricted:
                        return .denied
                    case .notDetermined:
                        return .notDetermined
                    @unknown default:
                        return .notDetermined
                }
            } else {
                return .denied
            }
        }, getWindowHost: {
            return self.nativeWindow
        }, presentNativeController: { controller in
            self.window?.rootViewController?.present(controller, animated: true, completion: nil)
        }, dismissNativeController: {
            self.window?.rootViewController?.dismiss(animated: true, completion: nil)
        }, getAvailableAlternateIcons: {
            if #available(iOS 10.3, *) {
                var icons = [
                    PresentationAppIcon(name: "BlueIcon", imageName: "BlueIcon", isDefault: buildConfig.isAppStoreBuild),
                    PresentationAppIcon(name: "New2", imageName: "New2"),
                    PresentationAppIcon(name: "New1", imageName: "New1"),
                    PresentationAppIcon(name: "BlackIcon", imageName: "BlackIcon"),
                    PresentationAppIcon(name: "BlueClassicIcon", imageName: "BlueClassicIcon"),
                    PresentationAppIcon(name: "BlackClassicIcon", imageName: "BlackClassicIcon"),
                    PresentationAppIcon(name: "BlueFilledIcon", imageName: "BlueFilledIcon"),
                    PresentationAppIcon(name: "BlackFilledIcon", imageName: "BlackFilledIcon")
                ]
                if buildConfig.isInternalBuild {
                    icons.append(PresentationAppIcon(name: "WhiteFilledIcon", imageName: "WhiteFilledIcon"))
                }
                
                icons.append(PresentationAppIcon(name: "Premium", imageName: "Premium", isPremium: true))
                icons.append(PresentationAppIcon(name: "PremiumBlack", imageName: "PremiumBlack", isPremium: true))
                icons.append(PresentationAppIcon(name: "PremiumTurbo", imageName: "PremiumTurbo", isPremium: true))
                
                return icons
            } else {
                return []
            }
        }, getAlternateIconName: {
            if #available(iOS 10.3, *) {
                return application.alternateIconName
            } else {
                return nil
            }
        }, requestSetAlternateIconName: { name, completion in
            if #available(iOS 10.3, *) {
                application.setAlternateIconName(name, completionHandler: { error in
                    if let error = error {
                       Logger.shared.log("App \(self.episodeId)", "failed to set alternate icon with error \(error.localizedDescription)")
                    }
                    completion(error == nil)
                })
            } else {
                completion(false)
            }
        }, forceOrientation: { orientation in
            let value = orientation.rawValue
            UIDevice.current.setValue(value, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        })
        
        let accountManager = AccountManager<TelegramAccountManagerTypes>(basePath: rootPath + "/accounts-metadata", isTemporary: false, isReadOnly: false, useCaches: true, removeDatabaseOnError: true)
        self.accountManager = accountManager

        telegramUIDeclareEncodables()
        initializeAccountManagement()
        
        let pushRegistry = PKPushRegistry(queue: .main)
        if #available(iOS 9.0, *) {
            pushRegistry.desiredPushTypes = Set([.voIP])
        }
        self.pushRegistry = pushRegistry
        pushRegistry.delegate = self

        self.accountManagerState = extractAccountManagerState(records: accountManager._internalAccountRecordsSync())
        let _ = (accountManager.accountRecords()
        |> deliverOnMainQueue).start(next: { view in
            self.accountManagerState = extractAccountManagerState(records: view)
        })

        var systemUserInterfaceStyle: WindowUserInterfaceStyle = .light
        if #available(iOS 13.0, *) {
            if let traitCollection = window.rootViewController?.traitCollection {
                systemUserInterfaceStyle = WindowUserInterfaceStyle(style: traitCollection.userInterfaceStyle)
            }
        }
        
        let sharedContextSignal = currentPresentationDataAndSettings(accountManager: accountManager, systemUserInterfaceStyle: systemUserInterfaceStyle)
        |> map { initialPresentationDataAndSettings -> (AccountManager, InitialPresentationDataAndSettings) in
            return (accountManager, initialPresentationDataAndSettings)
        }
        |> deliverOnMainQueue
        |> mapToSignal { accountManager, initialPresentationDataAndSettings -> Signal<(SharedApplicationContext, LoggingSettings), NoError> in
            self.mainWindow?.hostView.containerView.backgroundColor =  initialPresentationDataAndSettings.presentationData.theme.chatList.backgroundColor
            
            let legacyBasePath = appGroupUrl.path
            
            let presentationDataPromise = Promise<PresentationData>()
            let appLockContext = AppLockContextImpl(rootPath: rootPath, window: self.mainWindow!, rootController: self.window?.rootViewController, applicationBindings: applicationBindings, accountManager: accountManager, presentationDataSignal: presentationDataPromise.get(), lockIconInitialFrame: {
                return (self.mainWindow?.viewController as? TelegramRootController)?.chatListController?.lockViewFrame
            })
            
            var setPresentationCall: ((PresentationCall?) -> Void)?
            let sharedContext = SharedAccountContextImpl(mainWindow: self.mainWindow, sharedContainerPath: legacyBasePath, basePath: rootPath, encryptionParameters: encryptionParameters, accountManager: accountManager, appLockContext: appLockContext, applicationBindings: applicationBindings, initialPresentationDataAndSettings: initialPresentationDataAndSettings, networkArguments: networkArguments, premiumProductId: buildConfig.premiumIAPProductId, rootPath: rootPath, legacyBasePath: legacyBasePath, apsNotificationToken: self.notificationTokenPromise.get() |> map(Optional.init), voipNotificationToken: self.voipTokenPromise.get() |> map(Optional.init), setNotificationCall: { call in
                setPresentationCall?(call)
            }, navigateToChat: { accountId, peerId, messageId in
                self.openChatWhenReady(accountId: accountId, peerId: peerId, messageId: messageId)
            }, displayUpgradeProgress: { progress in
                if let progress = progress {
                    if self.dataImportSplash == nil {
                        self.dataImportSplash = makeLegacyDataImportSplash(theme: initialPresentationDataAndSettings.presentationData.theme, strings: initialPresentationDataAndSettings.presentationData.strings)
                        self.dataImportSplash?.serviceAction = {
                            self.debugPressed()
                        }
                        self.mainWindow.coveringView = self.dataImportSplash
                    }
                    self.dataImportSplash?.progress = (.generic, progress)
                } else if let dataImportSplash = self.dataImportSplash {
                    self.dataImportSplash = nil
                    if self.mainWindow.coveringView === dataImportSplash {
                        self.mainWindow.coveringView = nil
                    }
                }
            })
            
            presentationDataPromise.set(sharedContext.presentationData)
            
            sharedContext.presentGlobalController = { [weak self] c, a in
                guard let strongSelf = self else {
                    return
                }
                strongSelf.mainWindow.present(c, on: .root)
            }
            sharedContext.presentCrossfadeController = { [weak self] in
                guard let strongSelf = self else {
                    return
                }
                var exists = false
                strongSelf.mainWindow.forEachViewController({ controller in
                    if controller is ThemeSettingsCrossfadeController || controller is ThemeSettingsController || controller is ThemePreviewController {
                        exists = true
                    }
                    return true
                })
                
                if !exists {
                    strongSelf.mainWindow.present(ThemeSettingsCrossfadeController(), on: .root)
                }
            }
            
            let notificationManager = SharedNotificationManager(episodeId: self.episodeId, application: application, clearNotificationsManager: clearNotificationsManager, inForeground: applicationBindings.applicationInForeground, accounts: sharedContext.activeAccountContexts |> map { primary, accounts, _ in accounts.map({ ($0.1.account, $0.1.account.id == primary?.account.id) }) }, pollLiveLocationOnce: { accountId in
                let _ = (self.context.get()
                |> filter {
                    return $0 != nil
                }
                |> take(1)
                |> deliverOnMainQueue).start(next: { context in
                    if let context = context, context.context.account.id == accountId {
                        context.context.liveLocationManager?.pollOnce()
                    }
                })
            })
            setPresentationCall = { call in
                notificationManager.setNotificationCall(call, strings: sharedContext.currentPresentationData.with({ $0 }).strings)
            }
            let liveLocationPolling = self.context.get()
            |> mapToSignal { context -> Signal<AccountRecordId?, NoError> in
                if let context = context, let liveLocationManager = context.context.liveLocationManager {
                    let accountId = context.context.account.id
                    return combineLatest(queue: .mainQueue(),
                        liveLocationManager.isPolling,
                        liveLocationManager.hasBackgroundTasks
                    )
                    |> map { isPolling, hasBackgroundTasks -> Bool in
                        return isPolling || hasBackgroundTasks
                    }
                    |> distinctUntilChanged
                    |> map { value -> AccountRecordId? in
                        if value {
                            return accountId
                        } else {
                            return nil
                        }
                    }
                } else {
                    return .single(nil)
                }
            }
            let watchTasks = self.context.get()
            |> mapToSignal { context -> Signal<AccountRecordId?, NoError> in
                if let context = context, let watchManager = context.context.watchManager {
                    let accountId = context.context.account.id
                    let runningTasks: Signal<WatchRunningTasks?, NoError> = .single(nil)
                    |> then(watchManager.runningTasks)
                    return runningTasks
                    |> distinctUntilChanged
                    |> map { value -> AccountRecordId? in
                        if let value = value, value.running {
                            return accountId
                        } else {
                            return nil
                        }
                    }
                    |> distinctUntilChanged
                } else {
                    return .single(nil)
                }
            }
            let wakeupManager = SharedWakeupManager(beginBackgroundTask: { name, expiration in application.beginBackgroundTask(withName: name, expirationHandler: expiration) }, endBackgroundTask: { id in application.endBackgroundTask(id) }, backgroundTimeRemaining: { application.backgroundTimeRemaining }, activeAccounts: sharedContext.activeAccountContexts |> map { ($0.0?.account, $0.1.map { ($0.0, $0.1.account) }) }, liveLocationPolling: liveLocationPolling, watchTasks: watchTasks, inForeground: applicationBindings.applicationInForeground, hasActiveAudioSession: self.hasActiveAudioSession.get(), notificationManager: notificationManager, mediaManager: sharedContext.mediaManager, callManager: sharedContext.callManager, accountUserInterfaceInUse: { id in
                return sharedContext.accountUserInterfaceInUse(id)
            })
            let sharedApplicationContext = SharedApplicationContext(sharedContext: sharedContext, notificationManager: notificationManager, wakeupManager: wakeupManager)
            sharedApplicationContext.sharedContext.mediaManager.overlayMediaManager.attachOverlayMediaController(sharedApplicationContext.overlayMediaController)
            
            return accountManager.transaction { transaction -> (SharedApplicationContext, LoggingSettings) in
                return (sharedApplicationContext, transaction.getSharedData(SharedDataKeys.loggingSettings)?.get(LoggingSettings.self) ?? LoggingSettings.defaultSettings)
            }
        }
        self.sharedContextPromise.set(sharedContextSignal
        |> mapToSignal { sharedApplicationContext, loggingSettings -> Signal<SharedApplicationContext, NoError> in
            Logger.shared.logToFile = loggingSettings.logToFile
            Logger.shared.logToConsole = loggingSettings.logToConsole
            Logger.shared.redactSensitiveData = loggingSettings.redactSensitiveData
            
            return .single(sharedApplicationContext)
        })
        
        let watchManagerArgumentsPromise = Promise<WatchManagerArguments?>()
            
        self.context.set(self.sharedContextPromise.get()
        |> deliverOnMainQueue
        |> mapToSignal { sharedApplicationContext -> Signal<AuthorizedApplicationContext?, NoError> in
            return sharedApplicationContext.sharedContext.activeAccountContexts
            |> map { primary, _, _ -> AccountContext? in
                return primary
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs !== rhs {
                    return false
                }
                return true
            })
            |> mapToSignal { context -> Signal<(AccountContext, CallListSettings)?, NoError> in
                return sharedApplicationContext.sharedContext.accountManager.transaction { transaction -> CallListSettings? in
                    return transaction.getSharedData(ApplicationSpecificSharedDataKeys.callListSettings)?.get(CallListSettings.self)
                }
                |> reduceLeft(value: nil) { current, updated -> CallListSettings? in
                    var result: CallListSettings?
                    if let updated = updated {
                        result = updated
                    } else if let current = current {
                        result = current
                    }
                    return result
                }
                |> map { callListSettings -> (AccountContext, CallListSettings)? in
                    if let context = context {
                        return (context, callListSettings ?? .defaultSettings)
                    } else {
                        return nil
                    }
                }
            }
            |> deliverOnMainQueue
            |> map { accountAndSettings -> AuthorizedApplicationContext? in
                return accountAndSettings.flatMap { context, callListSettings in
                    return AuthorizedApplicationContext(sharedApplicationContext: sharedApplicationContext, mainWindow: self.mainWindow, watchManagerArguments: watchManagerArgumentsPromise.get(), context: context as! AccountContextImpl, accountManager: sharedApplicationContext.sharedContext.accountManager, showCallsTab: callListSettings.showTab, reinitializedNotificationSettings: {
                        let _ = (self.context.get()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { context in
                            if let context = context {
                                self.registerForNotifications(context: context.context, authorize: false)
                            }
                        })
                    })
                }
            }
        })
        
        self.authContext.set(self.sharedContextPromise.get()
        |> deliverOnMainQueue
        |> mapToSignal { sharedApplicationContext -> Signal<UnauthorizedApplicationContext?, NoError> in
            return sharedApplicationContext.sharedContext.activeAccountContexts
            |> map { primary, accounts, auth -> (AccountContext?, UnauthorizedAccount, [AccountContext])? in
                if let auth = auth {
                    return (primary, auth, Array(accounts.map({ $0.1 })))
                } else {
                    return nil
                }
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs?.1 !== rhs?.1 {
                    return false
                }
                return true
            })
            |> mapToSignal { authAndAccounts -> Signal<(UnauthorizedAccount, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))?, NoError> in
                if let (primary, auth, accounts) = authAndAccounts {
                    let phoneNumbers = combineLatest(accounts.map { context -> Signal<(AccountRecordId, String, Bool)?, NoError> in
                        return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId))
                        |> map { peer -> (AccountRecordId, String, Bool)? in
                            if case let .user(user) = peer, let phone = user.phone {
                                return (context.account.id, phone, context.account.testingEnvironment)
                            } else {
                                return nil
                            }
                        }
                    })
                    return phoneNumbers
                    |> map { phoneNumbers -> (UnauthorizedAccount, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))? in
                        var primaryNumber: (String, AccountRecordId, Bool)?
                        if let primary = primary {
                            for idAndNumber in phoneNumbers {
                                if let (id, number, testingEnvironment) = idAndNumber, id == primary.account.id {
                                    primaryNumber = (number, id, testingEnvironment)
                                    break
                                }
                            }
                        }
                        return (auth, (primaryNumber, phoneNumbers.compactMap({ $0.flatMap({ ($0.1, $0.0, $0.2) }) })))
                    }
                } else {
                    return .single(nil)
                }
            }
            |> deliverOnMainQueue
            |> map { accountAndSettings -> UnauthorizedApplicationContext? in
                return accountAndSettings.flatMap { account, otherAccountPhoneNumbers in
                    return UnauthorizedApplicationContext(apiId: buildConfig.apiId, apiHash: buildConfig.apiHash, sharedContext: sharedApplicationContext.sharedContext, account: account, otherAccountPhoneNumbers: otherAccountPhoneNumbers)
                }
            }
        })
        
        let contextReadyDisposable = MetaDisposable()
        
        let startTime = CFAbsoluteTimeGetCurrent()
        self.contextDisposable.set((self.context.get()
        |> deliverOnMainQueue).start(next: { context in
            print("Application: context took \(CFAbsoluteTimeGetCurrent() - startTime) to become available")
            
            var network: Network?
            if let context = context {
                network = context.context.account.network
            }
            
            Logger.shared.log("App \(self.episodeId)", "received context \(String(describing: context)) account \(String(describing: context?.context.account.id)) network \(String(describing: network))")
            
            let firstTime = self.contextValue == nil
            if let contextValue = self.contextValue {
                contextValue.passcodeController?.dismiss()
                contextValue.context.account.shouldExplicitelyKeepWorkerConnections.set(.single(false))
                contextValue.context.account.shouldKeepBackgroundDownloadConnections.set(.single(false))
            }
            self.contextValue = context
            if let context = context {
                setupLegacyComponents(context: context.context)
                let isReady = context.isReady.get()
                contextReadyDisposable.set((isReady
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { _ in
                    let readyTime = CFAbsoluteTimeGetCurrent() - startTime
                    if readyTime > 0.5 {
                        print("Application: context took \(readyTime) to become ready")
                    }
                    print("Launch to ready took \((CFAbsoluteTimeGetCurrent() - launchStartTime) * 1000.0) ms")

                    self.mainWindow.debugAction = nil
                    
                    self.mainWindow.viewController = context.rootController
                    if firstTime {
                        let layer = context.rootController.view.layer
                        layer.allowsGroupOpacity = true
                        layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2, completion: { [weak layer] _ in
                            if let layer = layer {
                                layer.allowsGroupOpacity = false
                            }
                        })
                    }
                    self.mainWindow.forEachViewController({ controller in
                        if let controller = controller as? TabBarAccountSwitchController {
                            if let rootController = self.mainWindow.viewController as? TelegramRootController {
                                if let tabsController = rootController.viewControllers.first as? TabBarController {
                                    for i in 0 ..< tabsController.controllers.count {
                                        if let _ = tabsController.controllers[i] as? (SettingsController & ViewController) {
                                            let sourceNodes = tabsController.sourceNodesForController(at: i)
                                            if let sourceNodes = sourceNodes {
                                                controller.dismiss(sourceNodes: sourceNodes)
                                            }
                                            return false
                                        }
                                    }
                                }
                            }
                        }
                        return true
                    })
                    self.mainWindow.topLevelOverlayControllers = [context.sharedApplicationContext.overlayMediaController, context.notificationController]
                    var authorizeNotifications = true
                    if #available(iOS 10.0, *) {
                        authorizeNotifications = false
                    }
                    self.registerForNotifications(context: context.context, authorize: authorizeNotifications)
                    
                    self.resetIntentsIfNeeded(context: context.context)
                }))
            } else {
                self.mainWindow.viewController = nil
                self.mainWindow.topLevelOverlayControllers = []
                contextReadyDisposable.set(nil)
            }
        }))
        
        let authContextReadyDisposable = MetaDisposable()
        
        self.authContextDisposable.set((self.authContext.get()
        |> deliverOnMainQueue).start(next: { context in
            var network: Network?
            if let context = context {
                network = context.account.network
            }
            
            Logger.shared.log("App \(self.episodeId)", "received auth context \(String(describing: context)) account \(String(describing: context?.account.id)) network \(String(describing: network))")
            
            if let authContextValue = self.authContextValue {
                authContextValue.account.shouldBeServiceTaskMaster.set(.single(.never))
                if authContextValue.authorizationCompleted {
                    let accountId = authContextValue.account.id
                    let _ = (self.context.get()
                    |> filter { context in
                        return context?.context.account.id == accountId
                    }
                    |> take(1)
                    |> timeout(4.0, queue: .mainQueue(), alternate: .complete())
                    |> deliverOnMainQueue).start(completed: {
                        authContextValue.rootController.view.endEditing(true)
                        authContextValue.rootController.dismiss()
                    })
                } else {
                    authContextValue.rootController.view.endEditing(true)
                    authContextValue.rootController.dismiss()
                }
            }
            self.authContextValue = context
            if let context = context {
                let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
                let statusController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                self.mainWindow.present(statusController, on: .root)
                let isReady: Signal<Bool, NoError> = context.isReady.get()
                authContextReadyDisposable.set((isReady
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { _ in
                    statusController.dismiss()
                    self.mainWindow.present(context.rootController, on: .root)
                }))
            } else {
                authContextReadyDisposable.set(nil)
            }
        }))


        let logoutDataSignal: Signal<(AccountManager, Set<PeerId>), NoError> = self.sharedContextPromise.get()
        |> take(1)
        |> mapToSignal { sharedContext -> Signal<(AccountManager<TelegramAccountManagerTypes>, Set<PeerId>), NoError> in
            return sharedContext.sharedContext.activeAccountContexts
            |> map { _, accounts, _ -> Set<PeerId> in
                return Set(accounts.map { $0.1.account.peerId })
            }
            |> reduceLeft(value: Set<PeerId>()) { current, updated, emit in
                if !current.isEmpty {
                    emit(current.subtracting(current.intersection(updated)))
                }
                return updated
            }
            |> map { loggedOutAccountPeerIds -> (AccountManager<TelegramAccountManagerTypes>, Set<PeerId>) in
                return (sharedContext.sharedContext.accountManager, loggedOutAccountPeerIds)
            }
        }

        self.logoutDisposable.set(logoutDataSignal.start(next: { accountManager, loggedOutAccountPeerIds in
            let _ = (updateIntentsSettingsInteractively(accountManager: accountManager) { current in
                var updated = current
                for peerId in loggedOutAccountPeerIds {
                    if peerId == updated.account {
                        deleteAllSendMessageIntents()
                        updated = updated.withUpdatedAccount(nil)
                        break
                    }
                }
                return updated
            }).start()
        }))
        
        self.watchCommunicationManagerPromise.set(watchCommunicationManager(context: self.context.get() |> flatMap { WatchCommunicationManagerContext(context: $0.context) }, allowBackgroundTimeExtension: { timeout in
            let _ = (self.sharedContextPromise.get()
            |> take(1)).start(next: { sharedContext in
                sharedContext.wakeupManager.allowBackgroundTimeExtension(timeout: timeout)
            })
        }))
        let _ = self.watchCommunicationManagerPromise.get().start(next: { manager in
            if let manager = manager {
                watchManagerArgumentsPromise.set(.single(manager.arguments))
            } else {
                watchManagerArgumentsPromise.set(.single(nil))
            }
        })
        
        self.resetBadge()
        
        if #available(iOS 9.1, *) {
            self.quickActionsDisposable.set((self.context.get()
            |> mapToSignal { context -> Signal<[ApplicationShortcutItem], NoError> in
                if let context = context {
                    let presentationData = context.context.sharedContext.currentPresentationData.with { $0 }
                    
                    return activeAccountsAndPeers(context: context.context)
                    |> take(1)
                    |> map { primaryAndAccounts -> (AccountContext, EnginePeer, Int32)? in
                        return primaryAndAccounts.1.first
                    }
                    |> map { accountAndPeer -> String? in
                        if let (_, peer, _) = accountAndPeer {
                            return peer.displayTitle(strings: presentationData.strings, displayOrder: presentationData.nameDisplayOrder)
                        } else {
                            return nil
                        }
                    } |> mapToSignal { otherAccountName -> Signal<[ApplicationShortcutItem], NoError> in
                        let presentationData = context.context.sharedContext.currentPresentationData.with { $0 }
                        return .single(applicationShortcutItems(strings: presentationData.strings, otherAccountName: otherAccountName))
                    }
                } else {
                    return .single([])
                }
            }
            |> distinctUntilChanged
            |> deliverOnMainQueue).start(next: { items in
                if items.isEmpty {
                    UIApplication.shared.shortcutItems = nil
                } else {
                    UIApplication.shared.shortcutItems = items.map({ $0.shortcutItem() })
                }
            }))
        }
        
        let _ = self.isInForegroundPromise.get().start(next: { value in
            Logger.shared.log("App \(self.episodeId)", "isInForeground = \(value)")
        })
        let _ = self.isActivePromise.get().start(next: { value in
            Logger.shared.log("App \(self.episodeId)", "isActive = \(value)")
        })
        
        if let url = launchOptions?[.url] {
            if let url = url as? URL, url.scheme == "tg" || url.scheme == buildConfig.appSpecificUrlScheme {
                self.openUrlWhenReady(url: url)
            } else if let urlString = url as? String, urlString.lowercased().hasPrefix("tg:") || urlString.lowercased().hasPrefix("\(buildConfig.appSpecificUrlScheme):"), let url = URL(string: urlString) {
                self.openUrlWhenReady(url: url)
            }
        }
        
        if application.applicationState == .active {
            self.isInForegroundValue = true
            self.isInForegroundPromise.set(true)
            self.isActiveValue = true
            self.isActivePromise.set(true)
        }
        
        if UIApplication.shared.isStatusBarHidden {
            UIApplication.shared.internalSetStatusBarHidden(false, animation: .none)
        }
        
        /*if #available(iOS 13.0, *) {
            BGTaskScheduler.shared.register(forTaskWithIdentifier: baseAppBundleId + ".refresh", using: nil, launchHandler: { task in
                let _ = (self.sharedContextPromise.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { sharedApplicationContext in
                    
                    sharedApplicationContext.wakeupManager.replaceCurrentExtensionWithExternalTime(completion: {
                        task.setTaskCompleted(success: true)
                    }, timeout: 29.0)
                    let _ = (self.context.get()
                    |> take(1)
                    |> deliverOnMainQueue).start(next: { context in
                        guard let context = context else {
                            return
                        }
                        sharedApplicationContext.notificationManager.beginPollingState(account: context.context.account)
                    })
                })
            })
        }*/
        
        self.maybeCheckForUpdates()

        #if canImport(AppCenter)
        if !buildConfig.isAppStoreBuild, let appCenterId = buildConfig.appCenterId, !appCenterId.isEmpty {
            AppCenter.start(withAppSecret: buildConfig.appCenterId, services: [
                Crashes.self
            ])
        }
        #endif
        
        return true
    }

    private func resetBadge() {
        var resetOnce = true
        self.badgeDisposable.set((self.context.get()
        |> mapToSignal { context -> Signal<Int32, NoError> in
            if let context = context {
                return context.applicationBadge
            } else {
                return .single(0)
            }
        }
        |> deliverOnMainQueue).start(next: { count in
            if resetOnce {
                resetOnce = false
                if count == 0 {
                    UIApplication.shared.applicationIconBadgeNumber = 1
                }
            }
            UIApplication.shared.applicationIconBadgeNumber = Int(count)
        }))
    }

    func applicationWillResignActive(_ application: UIApplication) {
        self.isActiveValue = false
        self.isActivePromise.set(false)
        self.clearNotificationsManager?.commitNow()
        
        if let navigationController = self.mainWindow.viewController as? NavigationController {
            for controller in navigationController.viewControllers {
                if let controller = controller as? TabBarController {
                    for subController in controller.controllers {
                        subController.forEachController { controller in
                            if let controller = controller as? UndoOverlayController {
                                controller.dismissWithCommitAction()
                            }
                            return true
                        }
                    }
                }
            }
        }
        self.mainWindow.forEachViewController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            var extendNow = false
            if #available(iOS 9.0, *) {
                if !ProcessInfo.processInfo.isLowPowerModeEnabled {
                    extendNow = true
                }
            }
            #if DEBUG
            extendNow = false
            #endif
            sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 2.0, extendNow: extendNow)
        })
        
        self.isInForegroundValue = false
        self.isInForegroundPromise.set(false)
        self.isActiveValue = false
        self.isActivePromise.set(false)
        
        var taskId: UIBackgroundTaskIdentifier?
        taskId = application.beginBackgroundTask(withName: "lock", expirationHandler: {
            if let taskId = taskId {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        })
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 5.0, execute: {
            if let taskId = taskId {
                UIApplication.shared.endBackgroundTask(taskId)
            }
        })
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        if self.isActiveValue {
            self.isInForegroundValue = true
            self.isInForegroundPromise.set(true)
        } else {
            if #available(iOSApplicationExtension 12.0, *) {
                DispatchQueue.main.async {
                    self.isInForegroundValue = true
                    self.isInForegroundPromise.set(true)
                }
            }
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        self.isInForegroundValue = true
        self.isInForegroundPromise.set(true)
        self.isActiveValue = true
        self.isActivePromise.set(true)

        self.resetBadge()
        
        self.maybeCheckForUpdates()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        Logger.shared.log("App \(self.episodeId)", "terminating")
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.notificationTokenPromise.set(.single(deviceToken))
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 2.0)
        })
        
        var redactedPayload = userInfo
        if var aps = redactedPayload["aps"] as? [AnyHashable: Any] {
            if Logger.shared.redactSensitiveData {
                if aps["alert"] != nil {
                    aps["alert"] = "[[redacted]]"
                }
                if aps["body"] != nil {
                    aps["body"] = "[[redacted]]"
                }
            }
            redactedPayload["aps"] = aps
        }
        
        Logger.shared.log("App \(self.episodeId)", "remoteNotification: \(redactedPayload)")

        if userInfo["p"] == nil {
            completionHandler(.noData)
            return
        }
        
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            sharedApplicationContext.wakeupManager.replaceCurrentExtensionWithExternalTime(completion: {
                completionHandler(.newData)
            }, timeout: 29.0)
            sharedApplicationContext.notificationManager.addNotification(userInfo)
        })
    }
    
    func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
        if (application.applicationState == .inactive) {
            Logger.shared.log("App \(self.episodeId)", "tap local notification \(String(describing: notification.userInfo)), applicationState \(application.applicationState)")
        }
    }

    public func pushRegistry(_ registry: PKPushRegistry, didUpdate credentials: PKPushCredentials, for type: PKPushType) {
        if #available(iOS 9.0, *) {
            if case PKPushType.voIP = type {
                Logger.shared.log("App \(self.episodeId)", "pushRegistry credentials: \(credentials.token as NSData)")
                
                self.voipTokenPromise.set(.single(credentials.token))
            }
        }
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        Logger.shared.log("App \(self.episodeId) PushRegistry", "pushRegistry didReceiveIncomingPushWith \(payload.dictionaryPayload)")
        
        self.pushRegistryImpl(registry, didReceiveIncomingPushWith: payload, for: type, completion: completion)
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        Logger.shared.log("App \(self.episodeId) PushRegistry", "pushRegistry didReceiveIncomingPushWith \(payload.dictionaryPayload)")
        
        self.pushRegistryImpl(registry, didReceiveIncomingPushWith: payload, for: type, completion: {})
    }
    
    private func pushRegistryImpl(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        Logger.shared.log("App \(self.episodeId) PushRegistry", "pushRegistry processing push notification")
        
        let decryptedPayloadAndAccountId: ([AnyHashable: Any], AccountRecordId)?
        
        if let accountIdString = payload.dictionaryPayload["accountId"] as? String, let accountId = Int64(accountIdString) {
            decryptedPayloadAndAccountId = (payload.dictionaryPayload, AccountRecordId(rawValue: accountId))
        } else {
            guard var encryptedPayload = payload.dictionaryPayload["p"] as? String else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "encryptedPayload is nil")
                completion()
                return
            }
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
            while encryptedPayload.count % 4 != 0 {
                encryptedPayload.append("=")
            }
            guard let payloadData = Data(base64Encoded: encryptedPayload) else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't decode encryptedPayload")
                completion()
                return
            }
            guard let keyId = notificationPayloadKeyId(data: payloadData) else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't parse payload key id")
                completion()
                return
            }
            guard let accountManagerState = self.accountManagerState else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "accountManagerState is nil")
                completion()
                return
            }

            var maybeAccountId: AccountRecordId?
            var maybeNotificationKey: MasterNotificationKey?

            for key in accountManagerState.notificationKeys {
                if key.id == keyId {
                    maybeAccountId = key.accountId
                    maybeNotificationKey = MasterNotificationKey(id: key.id, data: key.key)
                    break
                }
            }

            guard let accountId = maybeAccountId, let notificationKey = maybeNotificationKey else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "accountId or notificationKey is nil")
                completion()
                return
            }
            guard let decryptedPayload = decryptedNotificationPayload(key: notificationKey, data: payloadData) else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't decrypt payload")
                completion()
                return
            }
            guard let payloadJson = try? JSONSerialization.jsonObject(with: decryptedPayload, options: []) as? [AnyHashable: Any] else {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't decode payload json")
                completion()
                return
            }
            
            decryptedPayloadAndAccountId = (payloadJson, accountId)
        }
        
        guard let (payloadJson, accountId) = decryptedPayloadAndAccountId else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "decryptedPayloadAndAccountId is nil")
            completion()
            return
        }
        
        guard var updateString = payloadJson["updates"] as? String else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "updates is nil")
            completion()
            return
        }

        updateString = updateString.replacingOccurrences(of: "-", with: "+")
        updateString = updateString.replacingOccurrences(of: "_", with: "/")
        while updateString.count % 4 != 0 {
            updateString.append("=")
        }
        guard let updateData = Data(base64Encoded: updateString) else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't decode updateData")
            completion()
            return
        }
        guard let callUpdate = AccountStateManager.extractIncomingCallUpdate(data: updateData) else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "Couldn't extract call update")
            completion()
            return
        }
        guard let callKitIntegration = CallKitIntegration.shared else {
            Logger.shared.log("App \(self.episodeId) PushRegistry", "CallKitIntegration is not available")
            completion()
            return
        }

        callKitIntegration.reportIncomingCall(
            uuid: CallSessionManager.getStableIncomingUUID(stableId: callUpdate.callId),
            stableId: callUpdate.callId,
            handle: "\(callUpdate.peer.id.id._internalGetInt64Value())",
            isVideo: false,
            displayTitle: callUpdate.peer.debugDisplayTitle,
            completion: { error in
                if let error = error {
                    if error.domain == "com.apple.CallKit.error.incomingcall" && (error.code == -3 || error.code == 3) {
                        Logger.shared.log("PresentationCall", "reportIncomingCall device in DND mode")
                    } else {
                        Logger.shared.log("PresentationCall", "reportIncomingCall error \(error)")
                        /*Queue.mainQueue().async {
                            if let strongSelf = self {
                                strongSelf.callSessionManager.drop(internalId: strongSelf.internalId, reason: .hangUp, debugLog: .single(nil))
                            }
                        }*/
                    }
                }
            }
        )
        
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedApplicationContext in
            let _ = (sharedApplicationContext.sharedContext.activeAccountContexts
            |> take(1)
            |> deliverOnMainQueue).start(next: { activeAccounts in
                var processed = false
                for (_, context, _) in activeAccounts.accounts {
                    if context.account.id == accountId {
                        context.account.stateManager.processIncomingCallUpdate(data: updateData, completion: { _ in
                        })
                        
                        //callUpdate.callId
                        let disposable = MetaDisposable()
                        self.watchedCallsDisposables.add(disposable)
                        
                        disposable.set((context.account.callSessionManager.callState(internalId: CallSessionManager.getStableIncomingUUID(stableId: callUpdate.callId))
                        |> deliverOnMainQueue).start(next: { state in
                            switch state.state {
                            case .terminated:
                                callKitIntegration.dropCall(uuid: CallSessionManager.getStableIncomingUUID(stableId: callUpdate.callId))
                            default:
                                break
                            }
                        }))
                        
                        processed = true
                        
                        break
                    }
                }
                
                if !processed {
                    callKitIntegration.dropCall(uuid: CallSessionManager.getStableIncomingUUID(stableId: callUpdate.callId))
                }
            })
            
            sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 2.0)

            if case PKPushType.voIP = type {
                Logger.shared.log("App \(self.episodeId) PushRegistry", "pushRegistry payload: \(payload.dictionaryPayload)")
                sharedApplicationContext.notificationManager.addNotification(payload.dictionaryPayload)
            }
        })
        
        Logger.shared.log("App \(self.episodeId) PushRegistry", "Invoking completion handler")
        
        completion()
    }
    
    public func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        Logger.shared.log("App \(self.episodeId)", "invalidated token for \(type)")
    }
    
    private func authorizedContext() -> Signal<AuthorizedApplicationContext, NoError> {
        return self.context.get()
        |> mapToSignal { context -> Signal<AuthorizedApplicationContext, NoError> in
            if let context = context {
                return .single(context)
            } else {
                return .complete()
            }
        }
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        guard self.openUrlInProgress != url else {
            return true
        }
        
        self.openUrl(url: url)
        return true
    }
    
    func application(_ application: UIApplication, handleOpen url: URL) -> Bool {
        self.openUrl(url: url)
        return true
    }
    
    private func openUrl(url: URL) {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> mapToSignal { sharedApplicationContext -> Signal<(SharedAccountContextImpl, AuthorizedApplicationContext?, UnauthorizedApplicationContext?), NoError> in
            combineLatest(self.context.get(), self.authContext.get())
            |> filter { $0 != nil || $1 != nil }
            |> take(1)
            |> map { context, authContext -> (SharedAccountContextImpl, AuthorizedApplicationContext?, UnauthorizedApplicationContext?) in
                return (sharedApplicationContext.sharedContext, context, authContext)
            }
        }
        |> deliverOnMainQueue).start(next: { _, context, authContext in
            if let context = context {
                context.openUrl(url)
            } else if let authContext = authContext {
                if let proxyData = parseProxyUrl(url) {
                    authContext.rootController.view.endEditing(true)
                    let presentationData = authContext.sharedContext.currentPresentationData.with { $0 }
                    let controller = ProxyServerActionSheetController(presentationData: presentationData, accountManager: authContext.sharedContext.accountManager, postbox: authContext.account.postbox, network: authContext.account.network, server: proxyData, updatedPresentationData: nil)
                    authContext.rootController.currentWindow?.present(controller, on: PresentationSurfaceLevel.root, blockInteraction: false, completion: {})
                } else if let secureIdData = parseSecureIdUrl(url) {
                    let presentationData = authContext.sharedContext.currentPresentationData.with { $0 }
                    authContext.rootController.currentWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: presentationData.strings.Passport_NotLoggedInMessage, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Calls_NotNow, action: {
                        if let callbackUrl = URL(string: secureIdCallbackUrl(with: secureIdData.callbackUrl, peerId: secureIdData.peerId, result: .cancel, parameters: [:])) {
                            UIApplication.shared.openURL(callbackUrl)
                        }
                    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), on: .root, blockInteraction: false, completion: {})
                } else if let confirmationCode = parseConfirmationCodeUrl(url) {
                    authContext.rootController.applyConfirmationCode(confirmationCode)
                }
            }
        })
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if #available(iOS 10.0, *) {
            var startCallContacts: [INPerson]?
            var startCallIsVideo = false
            if let startCallIntent = userActivity.interaction?.intent as? SupportedStartCallIntent {
                startCallContacts = startCallIntent.contacts
                startCallIsVideo = false
            } else if let startCallIntent = userActivity.interaction?.intent as? SupportedStartVideoCallIntent {
                startCallContacts = startCallIntent.contacts
                startCallIsVideo = true
            }
            
            if let startCallContacts = startCallContacts {
                let startCall: (Int64) -> Void = { userId in
                    self.startCallWhenReady(accountId: nil, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), isVideo: startCallIsVideo)
                }
                
                func cleanPhoneNumber(_ text: String) -> String {
                    var result = ""
                    for c in text {
                        if c == "+" {
                            if result.isEmpty {
                                result += String(c)
                            }
                        } else if c >= "0" && c <= "9" {
                            result += String(c)
                        }
                    }
                    return result
                }
                
                func matchPhoneNumbers(_ lhs: String, _ rhs: String) -> Bool {
                    if lhs.count < 10 && lhs.count == rhs.count {
                        return lhs == rhs
                    } else if lhs.count >= 10 && rhs.count >= 10 && lhs.suffix(10) == rhs.suffix(10) {
                        return true
                    } else {
                        return false
                    }
                }
                
                if let contact = startCallContacts.first {
                    var processed = false
                    if let handle = contact.customIdentifier, handle.hasPrefix("tg") {
                        let string = handle.suffix(from: handle.index(handle.startIndex, offsetBy: 2))
                        if let userId = Int64(string) {
                            startCall(userId)
                            processed = true
                        }
                    }
                    if !processed, let handle = contact.personHandle, let value = handle.value {
                        switch handle.type {
                            case .unknown:
                                if let userId = Int64(value) {
                                    startCall(userId)
                                    processed = true
                                }
                            case .phoneNumber:
                                let phoneNumber = cleanPhoneNumber(value)
                                if !phoneNumber.isEmpty {
                                    guard let context = self.contextValue?.context else {
                                        return true
                                    }
                                    let _ = (context.engine.data.get(TelegramEngine.EngineData.Item.Contacts.List(includePresences: false))
                                    |> map { contactList -> PeerId? in
                                        var result: PeerId?
                                        for peer in contactList.peers {
                                            if case let .user(peer) = peer, let peerPhoneNumber = peer.phone {
                                                if matchPhoneNumbers(phoneNumber, peerPhoneNumber) {
                                                    result = peer.id
                                                    break
                                                }
                                            }
                                        }
                                        return result
                                    }
                                    |> deliverOnMainQueue).start(next: { peerId in
                                        if let peerId = peerId {
                                            startCall(peerId.id._internalGetInt64Value())
                                        }
                                    })
                                    processed = true
                                }
                            default:
                                break
                        }
                    }

                }
            } else if let sendMessageIntent = userActivity.interaction?.intent as? INSendMessageIntent {
                if let contact = sendMessageIntent.recipients?.first, let handle = contact.customIdentifier, handle.hasPrefix("tg") {
                    let string = handle.suffix(from: handle.index(handle.startIndex, offsetBy: 2))
                    if let userId = Int64(string) {
                        self.openChatWhenReady(accountId: nil, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(userId)), activateInput: true)
                    }
                }
            }
        }
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            self.openUrl(url: url)
        }
        
        if userActivity.activityType == CSSearchableItemActionType {
            if let uniqueIdentifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String, uniqueIdentifier.hasPrefix("contact-") {
                if let peerIdValue = Int64(String(uniqueIdentifier[uniqueIdentifier.index(uniqueIdentifier.startIndex, offsetBy: "contact-".count)...])) {
                    let peerId = PeerId(peerIdValue)
                
                    let signal = self.sharedContextPromise.get()
                    |> take(1)
                    |> mapToSignal { sharedApplicationContext -> Signal<(AccountRecordId?, [AccountContext?]), NoError> in
                        return sharedApplicationContext.sharedContext.activeAccountContexts
                        |> take(1)
                        |> mapToSignal { primary, contexts, _ -> Signal<(AccountRecordId?, [AccountContext?]), NoError> in
                            return combineLatest(contexts.map { _, context, _ -> Signal<AccountContext?, NoError> in
                                return context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
                                |> map { peer -> AccountContext? in
                                    if peer != nil {
                                        return context
                                    } else {
                                        return nil
                                    }
                                }
                            })
                            |> map { contexts -> (AccountRecordId?, [AccountContext?]) in
                                return (primary?.account.id, contexts)
                            }
                        }
                    }
                    let _ = (signal
                    |> deliverOnMainQueue).start(next: { primary, contexts in
                        if let primary = primary {
                            for context in contexts {
                                if let context = context, context.account.id == primary {
                                    self.openChatWhenReady(accountId: nil, peerId: peerId)
                                    return
                                }
                            }
                        }
                        
                        for context in contexts {
                            if let context = context {
                                self.openChatWhenReady(accountId: context.account.id, peerId: peerId)
                                return
                            }
                        }
                    })
                }
            }
        }
        
        return true
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let _ = (self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue).start(next: { sharedContext in
            let type = ApplicationShortcutItemType(rawValue: shortcutItem.type)
            let immediately = type == .account
            let proceed: () -> Void = {
                let _ = (self.context.get()
                |> take(1)
                |> deliverOnMainQueue).start(next: { context in
                    if let context = context {
                        if let type = type {
                            switch type {
                                case .search:
                                    context.openRootSearch()
                                case .compose:
                                    context.openRootCompose()
                                case .camera:
                                    context.openRootCamera()
                                case .savedMessages:
                                    self.openChatWhenReady(accountId: nil, peerId: context.context.account.peerId)
                                case .account:
                                    context.switchAccount()
                            }
                        }
                    }
                })
            }
            if let appLockContext = sharedContext.sharedContext.appLockContext as? AppLockContextImpl, !immediately {
                let _ = (appLockContext.isCurrentlyLocked
                |> filter { !$0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { _ in
                    proceed()
                })
            } else {
                proceed()
            }
        })
    }
    
    private func openNotificationSettingsWhenReady() {
        let _ = (self.authorizedContext()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            context.openNotificationSettings()
        })
    }
    
    private func startCallWhenReady(accountId: AccountRecordId?, peerId: PeerId, isVideo: Bool) {
        let signal = self.sharedContextPromise.get()
        |> take(1)
        |> mapToSignal { sharedApplicationContext -> Signal<AuthorizedApplicationContext, NoError> in
            if let accountId = accountId {
                sharedApplicationContext.sharedContext.switchToAccount(id: accountId)
                return self.authorizedContext()
                |> filter { context in
                    context.context.account.id == accountId
                }
                |> take(1)
            } else {
                return self.authorizedContext()
                |> take(1)
            }
        }
        self.openChatWhenReadyDisposable.set((signal
        |> deliverOnMainQueue).start(next: { context in
            context.startCall(peerId: peerId, isVideo: isVideo)
        }))
    }
    
    private func openChatWhenReady(accountId: AccountRecordId?, peerId: PeerId, messageId: MessageId? = nil, activateInput: Bool = false) {
        let signal = self.sharedContextPromise.get()
        |> take(1)
        |> deliverOnMainQueue
        |> mapToSignal { sharedApplicationContext -> Signal<AuthorizedApplicationContext, NoError> in
            if let accountId = accountId {
                sharedApplicationContext.sharedContext.switchToAccount(id: accountId)
                return self.authorizedContext()
                |> filter { context in
                    context.context.account.id == accountId
                }
                |> take(1)
            } else {
                return self.authorizedContext()
                |> take(1)
            }
        }
        self.openChatWhenReadyDisposable.set((signal
        |> deliverOnMainQueue).start(next: { context in
            context.openChatWithPeerId(peerId: peerId, messageId: messageId, activateInput: activateInput)
        }))
    }
    
    private var openUrlInProgress: URL?
    private func openUrlWhenReady(url: URL) {
        self.openUrlInProgress = url
        
        self.openUrlWhenReadyDisposable.set((self.authorizedContext()
        |> take(1)
        |> deliverOnMainQueue).start(next: { [weak self] context in
            context.openUrl(url)
            
            Queue.mainQueue().after(1.0, {
                self?.openUrlInProgress = nil
            })
        }))
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let _ = (accountIdFromNotification(response.notification, sharedContext: self.sharedContextPromise.get())
        |> deliverOnMainQueue).start(next: { accountId in
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                if let peerId = peerIdFromNotification(response.notification) {
                    var messageId: MessageId? = nil
                    if response.notification.request.content.categoryIdentifier == "watch" {
                        messageId = messageIdFromNotification(peerId: peerId, notification: response.notification)
                    }
                    self.openChatWhenReady(accountId: accountId, peerId: peerId, messageId: messageId)
                }
                completionHandler()
            } else if response.actionIdentifier == "reply", let peerId = peerIdFromNotification(response.notification), let accountId = accountId {
                guard let response = response as? UNTextInputNotificationResponse, !response.userText.isEmpty else {
                    completionHandler()
                    return
                }
                let text = response.userText
                let signal = self.sharedContextPromise.get()
                |> take(1)
                |> deliverOnMainQueue
                |> mapToSignal { sharedContext -> Signal<Void, NoError> in
                    sharedContext.wakeupManager.allowBackgroundTimeExtension(timeout: 2.0, extendNow: true)
                    return sharedContext.sharedContext.activeAccountContexts
                    |> mapToSignal { _, contexts, _ -> Signal<Account, NoError> in
                        for context in contexts {
                            if context.1.account.id == accountId {
                                return .single(context.1.account)
                            }
                        }
                        return .complete()
                    }
                    |> take(1)
                    |> deliverOnMainQueue
                    |> mapToSignal { account -> Signal<Void, NoError> in
                        if let messageId = messageIdFromNotification(peerId: peerId, notification: response.notification) {
                            let _ = TelegramEngine(account: account).messages.applyMaxReadIndexInteractively(index: MessageIndex(id: messageId, timestamp: 0)).start()
                        }
                        return enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil, correlationId: nil)])
                        |> map { messageIds -> MessageId? in
                            if messageIds.isEmpty {
                                return nil
                            } else {
                                return messageIds[0]
                            }
                        }
                        |> mapToSignal { messageId -> Signal<Void, NoError> in
                            if let messageId = messageId {
                                return account.postbox.unsentMessageIdsView()
                                |> filter { view in
                                    return !view.ids.contains(messageId)
                                }
                                |> take(1)
                                |> mapToSignal { _ -> Signal<Void, NoError> in
                                    return .complete()
                                }
                            } else {
                                return .complete()
                            }
                        }
                    }
                }
                |> deliverOnMainQueue
                
                let disposable = MetaDisposable()
                disposable.set((signal
                |> afterDisposed { [weak disposable] in
                    Queue.mainQueue().async {
                        if let disposable = disposable {
                            self.replyFromNotificationsDisposables.remove(disposable)
                        }
                        completionHandler()
                    }
                }).start())
                self.replyFromNotificationsDisposables.add(disposable)
            } else {
                completionHandler()
            }
        })
    }
    
    private func registerForNotifications(context: AccountContextImpl, authorize: Bool = true, completion: @escaping (Bool) -> Void = { _ in }) {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let _ = (context.sharedContext.accountManager.transaction { transaction -> Bool in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings)?.get(InAppNotificationSettings.self) ?? InAppNotificationSettings.defaultSettings
            return settings.displayNameOnLockscreen
        }
        |> deliverOnMainQueue).start(next: { displayNames in
            self.registerForNotifications(replyString: presentationData.strings.Notification_Reply, messagePlaceholderString: presentationData.strings.Conversation_InputTextPlaceholder, hiddenContentString: presentationData.strings.Watch_MessageView_Title, includeNames: displayNames, authorize: authorize, completion: completion)
        })
    }

    private func registerForNotifications(replyString: String, messagePlaceholderString: String, hiddenContentString: String, includeNames: Bool, authorize: Bool = true, completion: @escaping (Bool) -> Void = { _ in }) {
        if #available(iOS 10.0, *) {
            let notificationCenter = UNUserNotificationCenter.current()
            notificationCenter.getNotificationSettings(completionHandler: { settings in
                switch (settings.authorizationStatus, authorize) {
                    case (.authorized, _), (.notDetermined, true):
                        var authorizationOptions: UNAuthorizationOptions = [.badge, .sound, .alert, .carPlay]
                        if #available(iOS 12.0, *) {
                            authorizationOptions.insert(.providesAppNotificationSettings)
                        }
                        if #available(iOS 13.0, *) {
                            authorizationOptions.insert(.announcement)
                        }
                        notificationCenter.requestAuthorization(options: authorizationOptions, completionHandler: { result, _ in
                            completion(result)
                            if result {
                                Queue.mainQueue().async {
                                    let reply = UNTextInputNotificationAction(identifier: "reply", title: replyString, options: [], textInputButtonTitle: replyString, textInputPlaceholder: messagePlaceholderString)
                                                                        
                                    let unknownMessageCategory: UNNotificationCategory
                                    let replyMessageCategory: UNNotificationCategory
                                    let replyLegacyMessageCategory: UNNotificationCategory
                                    let replyLegacyMediaMessageCategory: UNNotificationCategory
                                    let replyMediaMessageCategory: UNNotificationCategory
                                    let legacyChannelMessageCategory: UNNotificationCategory
                                    let muteMessageCategory: UNNotificationCategory
                                    let muteMediaMessageCategory: UNNotificationCategory
                                    
                                    if #available(iOS 11.0, *) {
                                        var options: UNNotificationCategoryOptions = []
                                        if includeNames {
                                            options.insert(.hiddenPreviewsShowTitle)
                                        }
                                        
                                        var carPlayOptions = options
                                        carPlayOptions.insert(.allowInCarPlay)
                                        if #available(iOS 13.2, *) {
                                            carPlayOptions.insert(.allowAnnouncement)
                                        }
                                        
                                        unknownMessageCategory = UNNotificationCategory(identifier: "unknown", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        replyMessageCategory = UNNotificationCategory(identifier: "withReply", actions: [reply], intentIdentifiers: [INSearchForMessagesIntentIdentifier], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: carPlayOptions)
                                        replyLegacyMessageCategory = UNNotificationCategory(identifier: "r", actions: [reply], intentIdentifiers: [INSearchForMessagesIntentIdentifier], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: carPlayOptions)
                                        replyLegacyMediaMessageCategory = UNNotificationCategory(identifier: "m", actions: [reply], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: carPlayOptions)
                                        replyMediaMessageCategory = UNNotificationCategory(identifier: "withReplyMedia", actions: [reply], intentIdentifiers: [INSearchForMessagesIntentIdentifier], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: carPlayOptions)
                                        legacyChannelMessageCategory = UNNotificationCategory(identifier: "c", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        muteMessageCategory = UNNotificationCategory(identifier: "withMute", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                        muteMediaMessageCategory = UNNotificationCategory(identifier: "withMuteMedia", actions: [], intentIdentifiers: [], hiddenPreviewsBodyPlaceholder: hiddenContentString, options: options)
                                    } else {
                                        let carPlayOptions: UNNotificationCategoryOptions = [.allowInCarPlay]
                                        
                                        unknownMessageCategory = UNNotificationCategory(identifier: "unknown", actions: [], intentIdentifiers: [], options: [])
                                        replyMessageCategory = UNNotificationCategory(identifier: "withReply", actions: [reply], intentIdentifiers: [INSearchForMessagesIntentIdentifier], options: carPlayOptions)
                                        replyLegacyMessageCategory = UNNotificationCategory(identifier: "r", actions: [reply], intentIdentifiers: [INSearchForMessagesIntentIdentifier], options: carPlayOptions)
                                        replyLegacyMediaMessageCategory = UNNotificationCategory(identifier: "m", actions: [reply], intentIdentifiers: [], options: [])
                                        replyMediaMessageCategory = UNNotificationCategory(identifier: "withReplyMedia", actions: [reply], intentIdentifiers: [INSearchForMessagesIntentIdentifier], options: carPlayOptions)
                                        legacyChannelMessageCategory = UNNotificationCategory(identifier: "c", actions: [], intentIdentifiers: [], options: [])
                                        muteMessageCategory = UNNotificationCategory(identifier: "withMute", actions: [], intentIdentifiers: [], options: [])
                                        muteMediaMessageCategory = UNNotificationCategory(identifier: "withMuteMedia", actions: [], intentIdentifiers: [], options: [])
                                    }
                                    
                                    UNUserNotificationCenter.current().setNotificationCategories([unknownMessageCategory, replyMessageCategory, replyLegacyMessageCategory, replyLegacyMediaMessageCategory, replyMediaMessageCategory, legacyChannelMessageCategory, muteMessageCategory, muteMediaMessageCategory])
                                    
                                    UIApplication.shared.registerForRemoteNotifications()
                                }
                            }
                        })
                    default:
                        break
                }
            })
        } else {
            let reply = UIMutableUserNotificationAction()
            reply.identifier = "reply"
            reply.title = replyString
            reply.isDestructive = false
            if #available(iOS 9.0, *) {
                reply.isAuthenticationRequired = false
                reply.behavior = .textInput
                reply.activationMode = .background
            } else {
                reply.isAuthenticationRequired = true
                reply.activationMode = .foreground
            }
            
            let unknownMessageCategory = UIMutableUserNotificationCategory()
            unknownMessageCategory.identifier = "unknown"
            
            let replyMessageCategory = UIMutableUserNotificationCategory()
            replyMessageCategory.identifier = "withReply"
            replyMessageCategory.setActions([reply], for: .default)
            
            let replyLegacyMessageCategory = UIMutableUserNotificationCategory()
            replyLegacyMessageCategory.identifier = "r"
            replyLegacyMessageCategory.setActions([reply], for: .default)
            
            let replyLegacyMediaMessageCategory = UIMutableUserNotificationCategory()
            replyLegacyMediaMessageCategory.identifier = "m"
            replyLegacyMediaMessageCategory.setActions([reply], for: .default)
            
            let replyMediaMessageCategory = UIMutableUserNotificationCategory()
            replyMediaMessageCategory.identifier = "withReplyMedia"
            replyMediaMessageCategory.setActions([reply], for: .default)
            
            let legacyChannelMessageCategory = UIMutableUserNotificationCategory()
            legacyChannelMessageCategory.identifier = "c"
            
            let muteMessageCategory = UIMutableUserNotificationCategory()
            muteMessageCategory.identifier = "withMute"
           
            let muteMediaMessageCategory = UIMutableUserNotificationCategory()
            muteMediaMessageCategory.identifier = "withMuteMedia"
            
            let settings = UIUserNotificationSettings(types: [.badge, .sound, .alert], categories: [])
            UIApplication.shared.registerUserNotificationSettings(settings)
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let _ = (accountIdFromNotification(notification, sharedContext: self.sharedContextPromise.get())
        |> deliverOnMainQueue).start(next: { accountId in
            if let context = self.contextValue {
                if let accountId = accountId, context.context.account.id != accountId {
                    completionHandler([.alert])
                }
            }
        })
    }
    
    @available(iOS 12.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {
        self.openNotificationSettingsWhenReady()
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        Logger.shared.log("App \(self.episodeId)", "handleEventsForBackgroundURLSession \(identifier)")
        completionHandler()
    }
    
    private var lastCheckForUpdatesTimestamp: Double?
    private let currentCheckForUpdatesDisposable = MetaDisposable()
    
    private func maybeCheckForUpdates() {
        #if targetEnvironment(simulator)
        #else
        guard let buildConfig = self.buildConfig, !buildConfig.isAppStoreBuild, let appCenterId = buildConfig.appCenterId, !appCenterId.isEmpty else {
            return
        }
        let timestamp = CFAbsoluteTimeGetCurrent()
        if self.lastCheckForUpdatesTimestamp == nil || self.lastCheckForUpdatesTimestamp! < timestamp - 10.0 * 60.0 {
            self.lastCheckForUpdatesTimestamp = timestamp
            
            if let url = URL(string: "https://api.appcenter.ms/v0.1/public/sdk/apps/\(appCenterId)/releases/latest") {
                self.currentCheckForUpdatesDisposable.set((downloadHTTPData(url: url)
                |> deliverOnMainQueue).start(next: { [weak self] data in
                    guard let strongSelf = self else {
                        return
                    }
                    guard let json = try? JSONSerialization.jsonObject(with: data, options: []) else {
                        return
                    }
                    guard let dict = json as? [String: Any] else {
                        return
                    }
                    guard let versionString = dict["version"] as? String, let version = Int(versionString) else {
                        return
                    }
                    guard let releaseNotesUrl = dict["release_notes_url"] as? String else {
                        return
                    }
                    guard let currentVersionString = Bundle.main.infoDictionary?["CFBundleVersion"] as? String, let currentVersion = Int(currentVersionString) else {
                        return
                    }
                    if currentVersion < version {
                        let _ = (strongSelf.sharedContextPromise.get()
                        |> take(1)
                        |> deliverOnMainQueue).start(next: { sharedContext in
                            let presentationData = sharedContext.sharedContext.currentPresentationData.with { $0 }
                            sharedContext.sharedContext.mainWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: nil, text: "A new build is available", actions: [
                                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                                TextAlertAction(type: .defaultAction, title: "Show", action: {
                                    sharedContext.sharedContext.applicationBindings.openUrl(releaseNotesUrl)
                                })
                            ]), on: .root, blockInteraction: false, completion: {})
                        })
                    }
                }))
            }
        }
        #endif
    }
    
    override var next: UIResponder? {
        if let context = self.contextValue, let controller = context.context.keyShortcutsController {
            return controller
        }
        return super.next
    }
    
    @objc func debugPressed() {
        let _ = (Logger.shared.collectShortLogFiles()
        |> deliverOnMainQueue).start(next: { logs in
            var activityItems: [Any] = []
            for (_, path) in logs {
                activityItems.append(URL(fileURLWithPath: path))
            }
            
            let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
            
            self.window?.rootViewController?.present(activityController, animated: true, completion: nil)
        })
    }
    
    private func resetIntentsIfNeeded(context: AccountContextImpl) {
        let _ = (context.sharedContext.accountManager.transaction { transaction in
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.intentsSettings)?.get(IntentsSettings.self) ?? IntentsSettings.defaultSettings
            if !settings.initiallyReset || settings.account == nil {
                if #available(iOS 10.0, *) {
                    Queue.mainQueue().async {
                        INInteraction.deleteAll()
                    }
                }
                transaction.updateSharedData(ApplicationSpecificSharedDataKeys.intentsSettings, { _ in
                    return PreferencesEntry(IntentsSettings(initiallyReset: true, account: context.account.peerId, contacts: settings.contacts, privateChats: settings.privateChats, savedMessages: settings.savedMessages, groups: settings.groups, onlyShared: settings.onlyShared))
                })
            }
        }).start()
    }
}

private func notificationPayloadKey(data: Data) -> Data? {
    if data.count < 8 {
        return nil
    }
    return data.subdata(in: 0 ..< 8)
}

@available(iOS 10.0, *)
private func accountIdFromNotification(_ notification: UNNotification, sharedContext: Signal<SharedApplicationContext, NoError>) -> Signal<AccountRecordId?, NoError> {
    if let id = notification.request.content.userInfo["accountId"] as? Int64 {
        return .single(AccountRecordId(rawValue: id))
    } else if let idString = notification.request.content.userInfo["accountId"] as? String, let id = Int64(idString) {
        return .single(AccountRecordId(rawValue: id))
    } else {
        var encryptedData: Data?
        if var encryptedPayload = notification.request.content.userInfo["p"] as? String {
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "-", with: "+")
            encryptedPayload = encryptedPayload.replacingOccurrences(of: "_", with: "/")
            while encryptedPayload.count % 4 != 0 {
                encryptedPayload.append("=")
            }
            encryptedData = Data(base64Encoded: encryptedPayload)
        }
        if let encryptedData = encryptedData, let notificationKeyId = notificationPayloadKey(data: encryptedData) {
            return sharedContext
            |> take(1)
            |> mapToSignal { sharedContext -> Signal<AccountRecordId?, NoError> in
                return sharedContext.sharedContext.activeAccountContexts
                |> take(1)
                |> mapToSignal { _, contexts, _ -> Signal<AccountRecordId?, NoError> in
                    let keys = contexts.map { _, context, _ -> Signal<(AccountRecordId, MasterNotificationKey)?, NoError> in
                        return masterNotificationsKey(account: context.account, ignoreDisabled: true)
                        |> map { key in
                            return (context.account.id, key)
                        }
                    }
                    return combineLatest(keys)
                    |> map { keys -> AccountRecordId? in
                        for idAndKey in keys {
                            if let (id, key) = idAndKey, key.id == notificationKeyId {
                                return id
                            }
                        }
                        return nil
                    }
                }
            }
        } else if let userId = notification.request.content.userInfo["userId"] as? Int {
            return sharedContext
            |> take(1)
            |> mapToSignal { sharedContext -> Signal<AccountRecordId?, NoError> in
                return sharedContext.sharedContext.activeAccountContexts
                |> take(1)
                |> map { _, contexts, _ -> AccountRecordId? in
                    for (_, context, _) in contexts {
                        if Int(context.account.peerId.id._internalGetInt64Value()) == userId {
                            return context.account.id
                        }
                    }
                    return nil
                }
            }
        } else {
            return .single(nil)
        }
    }
}

@available(iOS 10.0, *)
private func peerIdFromNotification(_ notification: UNNotification) -> PeerId? {
    if let peerId = notification.request.content.userInfo["peerId"] as? Int64 {
        return PeerId(peerId)
    } else if let peerIdString = notification.request.content.userInfo["peerId"] as? String, let peerId = Int64(peerIdString) {
        return PeerId(peerId)
    } else {
        let payload = notification.request.content.userInfo
        var peerId: PeerId?
        if let fromId = payload["from_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
        } else if let fromId = payload["chat_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
        } else if let fromId = payload["channel_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
        } else if let fromId = payload["encryption_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.SecretChat, id: PeerId.Id._internalFromInt64Value(Int64(fromIdValue as String) ?? 0))
        }
        return peerId
    }
}

@available(iOS 10.0, *)
private func messageIdFromNotification(peerId: PeerId, notification: UNNotification) -> MessageId? {
    let payload = notification.request.content.userInfo
    if let messageIdNamespace = payload["messageId.namespace"] as? Int32, let messageIdId = payload["messageId.id"] as? Int32 {
        return MessageId(peerId: peerId, namespace: messageIdNamespace, id: messageIdId)
    }
    
    if let msgId = payload["msg_id"] {
        let msgIdValue = msgId as! NSString
        return MessageId(peerId: peerId, namespace: Namespaces.Message.Cloud, id: Int32(msgIdValue.intValue))
    }
    return nil
}

private enum DownloadFileError {
    case network
}

private func downloadHTTPData(url: URL) -> Signal<Data, DownloadFileError> {
    return Signal { subscriber in
        let completed = Atomic<Bool>(value: false)
        let downloadTask = URLSession.shared.downloadTask(with: url, completionHandler: { location, _, error in
            let _ = completed.swap(true)
            if let location = location, let data = try? Data(contentsOf: location) {
                subscriber.putNext(data)
                subscriber.putCompletion()
            } else {
                subscriber.putError(.network)
            }
        })
        downloadTask.resume()
        
        return ActionDisposable {
            if !completed.with({ $0 }) {
                downloadTask.cancel()
            }
        }
    }
}
