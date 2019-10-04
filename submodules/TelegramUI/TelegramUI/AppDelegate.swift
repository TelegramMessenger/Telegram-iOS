import UIKit
import SwiftSignalKit
import Display
import TelegramCore
import UserNotifications
import Intents
import HockeySDK
import Postbox
import PushKit
import AsyncDisplayKit
import CloudKit
import TelegramUIPreferences
import TelegramPresentationData
import TelegramCallsUI
import TelegramVoip
import BuildConfig
import DeviceCheck
import AccountContext
import OverlayStatusController
import UndoUI
import LegacyUI
import PassportUI
import WatchBridge
import LegacyDataImport
import SettingsUI
import AppBundle
import WalletUI
import UrlHandling

private let handleVoipNotifications = false

private var testIsLaunched = false

private func encodeText(_ string: String, _ key: Int) -> String {
    var result = ""
    for c in string.unicodeScalars {
        result.append(Character(UnicodeScalar(UInt32(Int(c.value) + key))!))
    }
    return result
}

private let statusBarRootViewClass: AnyClass = NSClassFromString("UIStatusBar")!
private let statusBarPlaceholderClass: AnyClass? = NSClassFromString("UIStatusBar_Placeholder")
private let cutoutStatusBarForegroundClass: AnyClass? = NSClassFromString("_UIStatusBar")
private let keyboardViewClass: AnyClass? = NSClassFromString(encodeText("VJJoqvuTfuIptuWjfx", -1))!
private let keyboardViewContainerClass: AnyClass? = NSClassFromString(encodeText("VJJoqvuTfuDpoubjofsWjfx", -1))!

private let keyboardWindowClass: AnyClass? = {
    if #available(iOS 9.0, *) {
        return NSClassFromString(encodeText("VJSfnpufLfzcpbseXjoepx", -1))
    } else {
        return NSClassFromString(encodeText("VJUfyuFggfdutXjoepx", -1))
    }
}()

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
        self.application.setStatusBarStyle(style, animated: animated)
    }
    
    func setStatusBarHidden(_ value: Bool, animated: Bool) {
        self.application.setStatusBarHidden(value, with: animated ? .fade : .none)
    }
    
    var statusBarWindow: UIView? {
        return self.application.value(forKey: "statusBarWindow") as? UIView
    }
    
    var statusBarView: UIView? {
        guard let containerView = self.statusBarWindow?.subviews.first else {
            return nil
        }
        
        if containerView.isKind(of: statusBarRootViewClass) {
            return containerView
        }
        if let statusBarPlaceholderClass = statusBarPlaceholderClass {
            if containerView.isKind(of: statusBarPlaceholderClass) {
                return containerView
            }
        }
            
        
        for subview in containerView.subviews {
            if let cutoutStatusBarForegroundClass = cutoutStatusBarForegroundClass, subview.isKind(of: cutoutStatusBarForegroundClass) {
                return subview
            }
        }
        return nil
    }
    
    var keyboardWindow: UIWindow? {
        guard let keyboardWindowClass = keyboardWindowClass else {
            return nil
        }
        
        for window in UIApplication.shared.windows {
            if window.isKind(of: keyboardWindowClass) {
                return window
            }
        }
        return nil
    }
    
    var keyboardView: UIView? {
        guard let keyboardWindow = self.keyboardWindow, let keyboardViewContainerClass = keyboardViewContainerClass, let keyboardViewClass = keyboardViewClass else {
            return nil
        }
        
        for view in keyboardWindow.subviews {
            if view.isKind(of: keyboardViewContainerClass) {
                for subview in view.subviews {
                    if subview.isKind(of: keyboardViewClass) {
                        return subview
                    }
                }
            }
        }
        return nil
    }
    
    var handleVolumeControl: Signal<Bool, NoError> {
        return MediaManagerImpl.globalAudioSession.isPlaybackActive()
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

@objc(AppDelegate) class AppDelegate: UIResponder, UIApplicationDelegate, PKPushRegistryDelegate, BITHockeyManagerDelegate, UNUserNotificationCenterDelegate, UIAlertViewDelegate {
    @objc var window: UIWindow?
    var nativeWindow: (UIWindow & WindowHost)?
    var mainWindow: Window1!
    private var dataImportSplash: LegacyDataImportSplash?
    
    let episodeId = arc4random()
    
    private let isInForegroundPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isInForegroundValue = false
    private let isActivePromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    private var isActiveValue = false
    let hasActiveAudioSession = Promise<Bool>(false)
    
    private let sharedContextPromise = Promise<SharedApplicationContext>()
    private let watchCommunicationManagerPromise = Promise<WatchCommunicationManager?>()
    
    private var contextValue: AuthorizedApplicationContext?
    private let context = Promise<AuthorizedApplicationContext?>()
    private let contextDisposable = MetaDisposable()
    
    private var authContextValue: UnauthorizedApplicationContext?
    private let authContext = Promise<UnauthorizedApplicationContext?>()
    private let authContextDisposable = MetaDisposable()
    
    private let openChatWhenReadyDisposable = MetaDisposable()
    private let openUrlWhenReadyDisposable = MetaDisposable()
    
    private let badgeDisposable = MetaDisposable()
    private let quickActionsDisposable = MetaDisposable()
    
    private var pushRegistry: PKPushRegistry?
    
    private let notificationAuthorizationDisposable = MetaDisposable()
    
    private var replyFromNotificationsDisposables = DisposableSet()
    
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
    
    func alertView(_ alertView: UIAlertView, clickedButtonAt buttonIndex: Int) {
        if buttonIndex == alertView.firstOtherButtonIndex {
            self.alertActions?.other?()
        } else {
            self.alertActions?.primary?()
        }
    }
    
    private let deviceToken = Promise<Data?>(nil)
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        precondition(!testIsLaunched)
        testIsLaunched = true
        
        self.deviceToken.set(voipTokenPromise.get()
        |> map(Optional.init))
        
        let launchStartTime = CFAbsoluteTimeGetCurrent()
        
        let statusBarHost = ApplicationStatusBarHost()
        let (window, hostView) = nativeWindowHostView()
        self.mainWindow = Window1(hostView: hostView, statusBarHost: statusBarHost)
        hostView.containerView.backgroundColor = UIColor.white
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
                                peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: Int32(fromIdValue.intValue))
                            } else if let fromId = payload["chat_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: Int32(fromIdValue.intValue))
                            } else if let fromId = payload["channel_id"] {
                                let fromIdValue = fromId as! NSString
                                peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: Int32(fromIdValue.intValue))
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
        
        let apiId: Int32 = buildConfig.apiId
        let languagesCategory = "ios"
        
        let networkArguments = NetworkInitializationArguments(apiId: apiId, languagesCategory: languagesCategory, appVersion: appVersion, voipMaxLayer: PresentationCallManagerImpl.voipMaxLayer, appData: self.deviceToken.get()
        |> map { token in
            let data = buildConfig.bundleData(withAppToken: token)
            if let data = data, let jsonString = String(data: data, encoding: .utf8) {
                //Logger.shared.log("data", "\(jsonString)")
            } else {
                Logger.shared.log("data", "can't deserialize")
            }
            return data
        })
        
        guard let appGroupUrl = maybeAppGroupUrl else {
            UIAlertView(title: nil, message: "Error 2", delegate: nil, cancelButtonTitle: "OK").show()
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
        
        TempBox.initializeShared(basePath: rootPath, processType: "app", launchSpecificId: arc4random64())
        
        let logsPath = rootPath + "/logs"
        let _ = try? FileManager.default.createDirectory(atPath: logsPath, withIntermediateDirectories: true, attributes: nil)
        Logger.setSharedLogger(Logger(basePath: logsPath))
        
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
        
        ASDisableLogging()
        
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
        
        telegramUIDeclareEncodables()
        
        GlobalExperimentalSettings.isAppStoreBuild = buildConfig.isAppStoreBuild
        
        GlobalExperimentalSettings.enableFeed = false
        #if DEBUG
            //GlobalExperimentalSettings.enableFeed = true
            #if targetEnvironment(simulator)
                //GlobalTelegramCoreConfiguration.readMessages = false
            #endif
        #endif
        
        self.window?.makeKeyAndVisible()
        
        self.hasActiveAudioSession.set(MediaManagerImpl.globalAudioSession.isActive())
        
        initializeAccountManagement()
        
        let applicationBindings = TelegramApplicationBindings(isMainApp: true, containerPath: appGroupUrl.path, appSpecificScheme: buildConfig.appSpecificUrlScheme, openUrl: { url in
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
                var icons = [PresentationAppIcon(name: "Blue", imageName: "BlueIcon", isDefault: buildConfig.isAppStoreBuild),
                        PresentationAppIcon(name: "Black", imageName: "BlackIcon"),
                        PresentationAppIcon(name: "BlueClassic", imageName: "BlueClassicIcon"),
                        PresentationAppIcon(name: "BlackClassic", imageName: "BlackClassicIcon"),
                        PresentationAppIcon(name: "BlueFilled", imageName: "BlueFilledIcon"),
                        PresentationAppIcon(name: "BlackFilled", imageName: "BlackFilledIcon")]
                if buildConfig.isInternalBuild {
                    icons.append(PresentationAppIcon(name: "WhiteFilled", imageName: "WhiteFilledIcon"))
                }
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
        })
        
        let accountManagerSignal = Signal<AccountManager, NoError> { subscriber in
            let accountManager = AccountManager(basePath: rootPath + "/accounts-metadata")
            return (upgradedAccounts(accountManager: accountManager, rootPath: rootPath, encryptionParameters: encryptionParameters)
            |> deliverOnMainQueue).start(next: { progress in
                if self.dataImportSplash == nil {
                    self.dataImportSplash = LegacyDataImportSplash(theme: nil, strings: nil)
                    self.dataImportSplash?.serviceAction = {
                        self.debugPressed()
                    }
                    self.mainWindow.coveringView = self.dataImportSplash
                }
                self.dataImportSplash?.progress = (.generic, progress)
            }, completed: {
                if let dataImportSplash = self.dataImportSplash {
                    self.dataImportSplash = nil
                    if self.mainWindow.coveringView === dataImportSplash {
                        self.mainWindow.coveringView = nil
                    }
                }
                subscriber.putNext(accountManager)
                subscriber.putCompletion()
            })
        }
        
        let tonKeychain: TonKeychain
        
        #if targetEnvironment(simulator)
        tonKeychain = TonKeychain(encryptionPublicKey: {
            //return .single(nil)
            //return .single("1".data(using: .utf8)!)
            return .single(Data())
        }, encrypt: { data in
            return Signal { subscriber in
                subscriber.putNext(TonKeychainEncryptedData(publicKey: Data(), data: data))
                subscriber.putCompletion()
                return EmptyDisposable
            }
        }, decrypt: { data in
            return Signal { subscriber in
                subscriber.putNext(data.data)
                subscriber.putCompletion()
                return EmptyDisposable
            }
        })
        #else
        tonKeychain = TonKeychain(encryptionPublicKey: {
            return Signal { subscriber in
                BuildConfig.getHardwareEncryptionAvailable(withBaseAppBundleId: baseAppBundleId, completion: { value in
                    subscriber.putNext(value)
                    subscriber.putCompletion()
                })
                return EmptyDisposable
            }
        }, encrypt: { data in
            return Signal { subscriber in
                BuildConfig.encryptApplicationSecret(data, baseAppBundleId: baseAppBundleId, completion: { result, publicKey in
                    if let result = result, let publicKey = publicKey {
                        subscriber.putNext(TonKeychainEncryptedData(publicKey: publicKey, data: result))
                        subscriber.putCompletion()
                    } else {
                        subscriber.putError(.generic)
                    }
                })
                return EmptyDisposable
            }
        }, decrypt: { encryptedData in
            return Signal { subscriber in
                BuildConfig.decryptApplicationSecret(encryptedData.data, publicKey: encryptedData.publicKey, baseAppBundleId: baseAppBundleId, completion: { result, cancelled in
                    if let result = result {
                        subscriber.putNext(result)
                    } else {
                        let error: TonKeychainDecryptDataError
                        if cancelled {
                            error = .cancelled
                        } else {
                            error = .generic
                        }
                        subscriber.putError(error)
                    }
                    subscriber.putCompletion()
                })
                return EmptyDisposable
            }
        })
        #endif
        
        let sharedContextSignal = accountManagerSignal
        |> deliverOnMainQueue
        |> take(1)
        |> deliverOnMainQueue
        |> take(1)
        |> mapToSignal { accountManager -> Signal<(AccountManager, InitialPresentationDataAndSettings), NoError> in
            return currentPresentationDataAndSettings(accountManager: accountManager)
                |> map { initialPresentationDataAndSettings -> (AccountManager, InitialPresentationDataAndSettings) in
                    return (accountManager, initialPresentationDataAndSettings)
            }
        }
        |> deliverOnMainQueue
        |> mapToSignal { accountManager, initialPresentationDataAndSettings -> Signal<(SharedApplicationContext, LoggingSettings), NoError> in
            self.mainWindow?.hostView.containerView.backgroundColor =  initialPresentationDataAndSettings.presentationData.theme.chatList.backgroundColor
            
            let legacyBasePath = appGroupUrl.path
            let legacyCache = LegacyCache(path: legacyBasePath + "/Caches")
            
            var setPresentationCall: ((PresentationCall?) -> Void)?
            let sharedContext = SharedAccountContextImpl(mainWindow: self.mainWindow, basePath: rootPath, encryptionParameters: encryptionParameters, accountManager: accountManager, applicationBindings: applicationBindings, initialPresentationDataAndSettings: initialPresentationDataAndSettings, networkArguments: networkArguments, rootPath: rootPath, legacyBasePath: legacyBasePath, legacyCache: legacyCache, apsNotificationToken: self.notificationTokenPromise.get() |> map(Optional.init), voipNotificationToken: self.voipTokenPromise.get() |> map(Optional.init), setNotificationCall: { call in
                setPresentationCall?(call)
            }, navigateToChat: { accountId, peerId, messageId in
                self.openChatWhenReady(accountId: accountId, peerId: peerId, messageId: messageId)
            }, displayUpgradeProgress: { progress in
                if let progress = progress {
                    if self.dataImportSplash == nil {
                        self.dataImportSplash = LegacyDataImportSplash(theme: initialPresentationDataAndSettings.presentationData.theme, strings: initialPresentationDataAndSettings.presentationData.strings)
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
            
            let rawAccounts = sharedContext.activeAccounts
            |> map { _, accounts, _ -> [Account] in
                return accounts.map({ $0.1 })
            }
            let _ = (sharedAccountInfos(accountManager: sharedContext.accountManager, accounts: rawAccounts)
            |> deliverOn(Queue())).start(next: { infos in
                storeAccountsData(rootPath: rootPath, accounts: infos)
            })
            
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
                strongSelf.mainWindow.forEachViewController { controller in
                    if controller is ThemeSettingsCrossfadeController {
                        exists = true
                    }
                    return true
                }
                
                if !exists {
                    strongSelf.mainWindow.present(ThemeSettingsCrossfadeController(), on: .root)
                }
            }
            
            let notificationManager = SharedNotificationManager(episodeId: self.episodeId, application: application, clearNotificationsManager: clearNotificationsManager, inForeground: applicationBindings.applicationInForeground, accounts: sharedContext.activeAccounts |> map { primary, accounts, _ in accounts.map({ ($0.1, $0.1.id == primary?.id) }) }, pollLiveLocationOnce: { accountId in
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
                    return liveLocationManager.isPolling
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
            let wakeupManager = SharedWakeupManager(beginBackgroundTask: { name, expiration in application.beginBackgroundTask(withName: name, expirationHandler: expiration) }, endBackgroundTask: { id in application.endBackgroundTask(id) }, backgroundTimeRemaining: { application.backgroundTimeRemaining }, activeAccounts: sharedContext.activeAccounts |> map { ($0.0, $0.1.map { ($0.0, $0.1) }) }, liveLocationPolling: liveLocationPolling, watchTasks: watchTasks, inForeground: applicationBindings.applicationInForeground, hasActiveAudioSession: self.hasActiveAudioSession.get(), notificationManager: notificationManager, mediaManager: sharedContext.mediaManager, callManager: sharedContext.callManager, accountUserInterfaceInUse: { id in
                return sharedContext.accountUserInterfaceInUse(id)
            })
            let sharedApplicationContext = SharedApplicationContext(sharedContext: sharedContext, notificationManager: notificationManager, wakeupManager: wakeupManager)
            sharedApplicationContext.sharedContext.mediaManager.overlayMediaManager.attachOverlayMediaController(sharedApplicationContext.overlayMediaController)
            
            return accountManager.transaction { transaction -> (SharedApplicationContext, LoggingSettings) in
                return (sharedApplicationContext, transaction.getSharedData(SharedDataKeys.loggingSettings) as? LoggingSettings ?? LoggingSettings.defaultSettings)
            }
        }
        self.sharedContextPromise.set(sharedContextSignal
        |> mapToSignal { sharedApplicationContext, loggingSettings -> Signal<SharedApplicationContext, NoError> in
            Logger.shared.logToFile = loggingSettings.logToFile
            Logger.shared.logToConsole = loggingSettings.logToConsole
            Logger.shared.redactSensitiveData = loggingSettings.redactSensitiveData
            
            return importedLegacyAccount(basePath: appGroupUrl.path, accountManager: sharedApplicationContext.sharedContext.accountManager, encryptionParameters: encryptionParameters, present: { controller in
                self.window?.rootViewController?.present(controller, animated: true, completion: nil)
            })
            |> `catch` { _ -> Signal<ImportedLegacyAccountEvent, NoError> in
                return Signal { subscriber in
                    let alertView = UIAlertView(title: "", message: "An error occured while trying to upgrade application data. Would you like to logout?", delegate: self, cancelButtonTitle: "No", otherButtonTitles: "Yes")
                    self.alertActions = (primary: {
                        let statusPath = appGroupUrl.path + "/Documents/importcompleted"
                        let _ = try? FileManager.default.createDirectory(atPath: appGroupUrl.path + "/Documents", withIntermediateDirectories: true, attributes: nil)
                        let _ = try? Data().write(to: URL(fileURLWithPath: statusPath))
                        subscriber.putNext(.result(nil))
                        subscriber.putCompletion()
                    }, other: {
                        exit(0)
                    })
                    alertView.show()
                    
                    return EmptyDisposable
                } |> runOn(Queue.mainQueue())
            }
            |> mapToSignal { event -> Signal<SharedApplicationContext, NoError> in
                switch event {
                    case let .progress(type, value):
                        Queue.mainQueue().async {
                            if self.dataImportSplash == nil {
                                self.dataImportSplash = LegacyDataImportSplash(theme: nil, strings: nil)
                                self.dataImportSplash?.serviceAction = {
                                    self.debugPressed()
                                }
                                self.mainWindow.coveringView = self.dataImportSplash
                            }
                            self.dataImportSplash?.progress = (type, value)
                        }
                        return .complete()
                    case let .result(temporaryId):
                        Queue.mainQueue().async {
                            if let _ = self.dataImportSplash {
                                self.dataImportSplash = nil
                                self.mainWindow.coveringView = nil
                            }
                        }
                        if let temporaryId = temporaryId {
                            Queue.mainQueue().after(1.0, {
                                let statusPath = appGroupUrl.path + "/Documents/importcompleted"
                                let _ = try? FileManager.default.createDirectory(atPath: appGroupUrl.path + "/Documents", withIntermediateDirectories: true, attributes: nil)
                                let _ = try? Data().write(to: URL(fileURLWithPath: statusPath))
                            })
                            return sharedApplicationContext.sharedContext.accountManager.transaction { transaction -> SharedApplicationContext in
                                transaction.setCurrentId(temporaryId)
                                transaction.updateRecord(temporaryId, { record in
                                    if let record = record {
                                        return AccountRecord(id: record.id, attributes: record.attributes, temporarySessionId: nil)
                                    }
                                    return record
                                })
                                return sharedApplicationContext
                            }
                        } else {
                            return .single(sharedApplicationContext)
                        }
                }
            }
        })
        
        let watchManagerArgumentsPromise = Promise<WatchManagerArguments?>()
            
        self.context.set(self.sharedContextPromise.get()
        |> deliverOnMainQueue
        |> mapToSignal { sharedApplicationContext -> Signal<AuthorizedApplicationContext?, NoError> in
            return sharedApplicationContext.sharedContext.activeAccounts
            |> map { primary, _, _ -> Account? in
                return primary
            }
            |> distinctUntilChanged(isEqual: { lhs, rhs in
                if lhs !== rhs {
                    return false
                }
                return true
            })
            |> mapToSignal { account -> Signal<(Account, LimitsConfiguration, CallListSettings)?, NoError> in
                return sharedApplicationContext.sharedContext.accountManager.transaction { transaction -> CallListSettings in
                    return transaction.getSharedData(ApplicationSpecificSharedDataKeys.callListSettings) as? CallListSettings ?? CallListSettings.defaultSettings
                }
                |> mapToSignal { callListSettings -> Signal<(Account, LimitsConfiguration, CallListSettings)?, NoError> in
                    if let account = account {
                        return account.postbox.transaction { transaction -> (Account, LimitsConfiguration, CallListSettings)? in
                            let limitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
                            return (account, limitsConfiguration, callListSettings)
                        }
                    } else {
                        return .single(nil)
                    }
                }
            }
            |> deliverOnMainQueue
            |> map { accountAndSettings -> AuthorizedApplicationContext? in
                return accountAndSettings.flatMap { account, limitsConfiguration, callListSettings in
                    let tonContext = StoredTonContext(basePath: account.basePath, postbox: account.postbox, network: account.network, keychain: tonKeychain)
                    let context = AccountContextImpl(sharedContext: sharedApplicationContext.sharedContext, account: account, tonContext: tonContext, limitsConfiguration: limitsConfiguration)
                    return AuthorizedApplicationContext(sharedApplicationContext: sharedApplicationContext, mainWindow: self.mainWindow, watchManagerArguments: watchManagerArgumentsPromise.get(), context: context, accountManager: sharedApplicationContext.sharedContext.accountManager, showCallsTab: callListSettings.showTab, reinitializedNotificationSettings: {
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
            return sharedApplicationContext.sharedContext.activeAccounts
            |> map { primary, accounts, auth -> (Account?, UnauthorizedAccount, [Account])? in
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
                    let phoneNumbers = combineLatest(accounts.map { account -> Signal<(AccountRecordId, String, Bool)?, NoError> in
                        return account.postbox.transaction { transaction -> (AccountRecordId, String, Bool)? in
                            if let phone = (transaction.getPeer(account.peerId) as? TelegramUser)?.phone {
                                return (account.id, phone, account.testingEnvironment)
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
                                if let (id, number, testingEnvironment) = idAndNumber, id == primary.id {
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
            |> mapToSignal { accountAndOtherAccountPhoneNumbers -> Signal<(UnauthorizedAccount, LimitsConfiguration, CallListSettings, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))?, NoError> in
                return sharedApplicationContext.sharedContext.accountManager.transaction { transaction -> CallListSettings in
                    return transaction.getSharedData(ApplicationSpecificSharedDataKeys.callListSettings) as? CallListSettings ?? CallListSettings.defaultSettings
                    }
                |> mapToSignal { callListSettings -> Signal<(UnauthorizedAccount, LimitsConfiguration, CallListSettings, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))?, NoError> in
                    if let (account, otherAccountPhoneNumbers) = accountAndOtherAccountPhoneNumbers {
                        return account.postbox.transaction { transaction -> (UnauthorizedAccount, LimitsConfiguration, CallListSettings, ((String, AccountRecordId, Bool)?, [(String, AccountRecordId, Bool)]))? in
                            let limitsConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.limitsConfiguration) as? LimitsConfiguration ?? LimitsConfiguration.defaultValue
                            return (account, limitsConfiguration, callListSettings, otherAccountPhoneNumbers)
                        }
                    } else {
                        return .single(nil)
                    }
                }
            }
            |> deliverOnMainQueue
            |> map { accountAndSettings -> UnauthorizedApplicationContext? in
                return accountAndSettings.flatMap { account, limitsConfiguration, callListSettings, otherAccountPhoneNumbers in
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
                authContextValue.rootController.view.endEditing(true)
                authContextValue.rootController.dismiss()
            }
            self.authContextValue = context
            if let context = context {
                let presentationData = context.sharedContext.currentPresentationData.with({ $0 })
                let statusController = OverlayStatusController(theme: presentationData.theme, strings: presentationData.strings, type: .loading(cancelled: nil))
                self.mainWindow.present(statusController, on: .root)
                let isReady: Signal<Bool, NoError> = context.isReady.get()
                authContextReadyDisposable.set((isReady
                |> filter { $0 }
                |> take(1)
                |> deliverOnMainQueue).start(next: { _ in
                    statusController.dismiss()
                    self.mainWindow.present(context.rootController, on: .root)                }))
            } else {
                authContextReadyDisposable.set(nil)
            }
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
        
        let pushRegistry = PKPushRegistry(queue: .main)
        if #available(iOS 9.0, *) {
            pushRegistry.desiredPushTypes = Set([.voIP])
        }
        self.pushRegistry = pushRegistry
        pushRegistry.delegate = self
        
        self.badgeDisposable.set((self.context.get()
        |> mapToSignal { context -> Signal<Int32, NoError> in
            if let context = context {
                return context.applicationBadge
            } else {
                return .single(0)
            }
        }
        |> deliverOnMainQueue).start(next: { count in
            UIApplication.shared.applicationIconBadgeNumber = Int(count)
        }))
        
        if #available(iOS 9.1, *) {
            self.quickActionsDisposable.set((self.context.get()
            |> mapToSignal { context -> Signal<[ApplicationShortcutItem], NoError> in
                if let context = context {
                    let presentationData = context.context.sharedContext.currentPresentationData.with { $0 }
                    return .single(applicationShortcutItems(strings: presentationData.strings))
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
                self.openUrlWhenReady(url: url.absoluteString)
            } else if let url = url as? String, url.lowercased().hasPrefix("tg:") || url.lowercased().hasPrefix("\(buildConfig.appSpecificUrlScheme):") {
                self.openUrlWhenReady(url: url)
            }
        }
        
        if application.applicationState == .active {
            self.isInForegroundValue = true
            self.isInForegroundPromise.set(true)
            self.isActiveValue = true
            self.isActivePromise.set(true)
        }
        
        BITHockeyBaseManager.setPresentAlert({ [weak self] alert in
            if let strongSelf = self, let alert = alert {
                var actions: [TextAlertAction] = []
                for action in alert.actions {
                    let isDefault = action.style == .default
                    actions.append(TextAlertAction(type: isDefault ? .defaultAction : .genericAction, title: action.title ?? "", action: {
                        if let action = action as? BITAlertAction {
                            action.invokeAction()
                        }
                    }))
                }
                if let sharedContext = strongSelf.contextValue?.context.sharedContext {
                    let presentationData = sharedContext.currentPresentationData.with { $0 }
                    strongSelf.mainWindow.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: alert.title, text: alert.message ?? "", actions: actions), on: .root)
                }
            }
        })
        
        BITHockeyBaseManager.setPresentView({ [weak self] controller in
            if let strongSelf = self, let controller = controller {
                let parent = LegacyController(presentation: .modal(animateIn: true), theme: nil)
                let navigationController = UINavigationController(rootViewController: controller)
                controller.navigation_setDismiss({ [weak parent] in
                    parent?.dismiss()
                }, rootController: nil)
                parent.bind(controller: navigationController)
                strongSelf.mainWindow.present(parent, on: .root)
            }
        })
        
        if let hockeyAppId = buildConfig.hockeyAppId, !hockeyAppId.isEmpty {
            BITHockeyManager.shared().configure(withIdentifier: hockeyAppId, delegate: self)
            BITHockeyManager.shared().crashManager.crashManagerStatus = .alwaysAsk
            BITHockeyManager.shared().start()
            #if targetEnvironment(simulator)
            #else
            BITHockeyManager.shared().authenticator.authenticateInstallation()
            #endif
        }
        
        if UIApplication.shared.isStatusBarHidden {
            UIApplication.shared.setStatusBarHidden(false, with: .none)
        }
        NotificationCenter.default.addObserver(forName: UIWindow.didBecomeHiddenNotification, object: nil, queue: nil, using: { notification in
            if UIApplication.shared.isStatusBarHidden {
                //UIApplication.shared.setStatusBarHidden(false, with: .none)
            }
        })
        return true
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
        self.mainWindow.forEachViewController { controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        }
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
            sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 4.0, extendNow: extendNow)
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
            sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 4.0)
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
    
    public func pushRegistry(_ registry: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType) {
        if #available(iOS 9.0, *) {
            let _ = (self.sharedContextPromise.get()
            |> take(1)
            |> deliverOnMainQueue).start(next: { sharedApplicationContext in
                sharedApplicationContext.wakeupManager.allowBackgroundTimeExtension(timeout: 4.0)
                
                if case PKPushType.voIP = type {
                    Logger.shared.log("App \(self.episodeId)", "pushRegistry payload: \(payload.dictionaryPayload)")
                    sharedApplicationContext.notificationManager.addNotification(payload.dictionaryPayload)
                }
            })
        }
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
                    let controller = ProxyServerActionSheetController(theme: presentationData.theme, strings: presentationData.strings, accountManager: authContext.sharedContext.accountManager, postbox: authContext.account.postbox, network: authContext.account.network, server: proxyData, presentationData: nil)
                    authContext.rootController.currentWindow?.present(controller, on: PresentationSurfaceLevel.root, blockInteraction: false, completion: {})
                } else if let secureIdData = parseSecureIdUrl(url) {
                    let presentationData = authContext.sharedContext.currentPresentationData.with { $0 }
                    authContext.rootController.currentWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: presentationData.strings.Passport_NotLoggedInMessage, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Calls_NotNow, action: {
                        if let callbackUrl = URL(string: secureIdCallbackUrl(with: secureIdData.callbackUrl, peerId: secureIdData.peerId, result: .cancel, parameters: [:])) {
                            UIApplication.shared.openURL(callbackUrl)
                        }
                    }), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), on: .root, blockInteraction: false, completion: {})
                } else if let confirmationCode = parseConfirmationCodeUrl(url) {
                    authContext.rootController.applyConfirmationCode(confirmationCode)
                } else if let _ = parseWalletUrl(url) {
                    let presentationData = authContext.sharedContext.currentPresentationData.with { $0 }
                    authContext.rootController.currentWindow?.present(standardTextAlertController(theme: AlertControllerTheme(presentationTheme: presentationData.theme), title: nil, text: "Please log in to your account to use Gram Wallet.", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]), on: .root, blockInteraction: false, completion: {})
                }
            }
        })
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        if #available(iOS 10.0, *) {
            if let startCallIntent = userActivity.interaction?.intent as? SupportedStartCallIntent {
                if let contact = startCallIntent.contacts?.first {
                    var processed = false
                    if let handle = contact.personHandle?.value {
                        if let userId = Int32(handle) {
                            if let context = self.contextValue {
                                let _ = context.context.sharedContext.callManager?.requestCall(account: context.context.account, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), endCurrentIfAny: false)
                                processed = true
                            }
                        }
                    }
                    if !processed, let handle = contact.customIdentifier, handle.hasPrefix("tg") {
                        let string = handle.suffix(from: handle.index(handle.startIndex, offsetBy: 2))
                        if let userId = Int32(string) {
                            if let context = self.contextValue {
                                let _ = context.context.sharedContext.callManager?.requestCall(account: context.context.account, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), endCurrentIfAny: false)
                            }
                        }
                    }
                }
            } else if let sendMessageIntent = userActivity.interaction?.intent as? INSendMessageIntent {
                if let contact = sendMessageIntent.recipients?.first, let handle = contact.customIdentifier, handle.hasPrefix("tg") {
                    let string = handle.suffix(from: handle.index(handle.startIndex, offsetBy: 2))
                    if let userId = Int32(string) {
                        self.openChatWhenReady(accountId: nil, peerId: PeerId(namespace: Namespaces.Peer.CloudUser, id: userId), activateInput: true)
                    }
                }
            }
        }
        
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
            self.openUrl(url: url)
        }
        
        return true
    }
    
    @available(iOS 9.0, *)
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        let _ = (self.context.get()
        |> mapToSignal { context -> Signal<AuthorizedApplicationContext?, NoError> in
            if let context = context {
                return context.unlockedState
                |> filter { $0 }
                |> take(1)
                |> map { _ -> AuthorizedApplicationContext? in
                    return context
                }
            } else {
                return .complete()
            }
        }
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            if let context = context {
                if let type = ApplicationShortcutItemType(rawValue: shortcutItem.type) {
                    switch type {
                        case .search:
                            context.openRootSearch()
                        case .compose:
                            context.openRootCompose()
                        case .camera:
                            context.openRootCamera()
                        case .savedMessages:
                            self.openChatWhenReady(accountId: nil, peerId: context.context.account.peerId)
                    }
                }
            }
        })
    }
    
    private func openChatWhenReady(accountId: AccountRecordId?, peerId: PeerId, messageId: MessageId? = nil, activateInput: Bool = false) {
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
            context.openChatWithPeerId(peerId: peerId, messageId: messageId, activateInput: activateInput)
        }))
    }
    
    private func openUrlWhenReady(url: String) {
        self.openUrlWhenReadyDisposable.set((self.authorizedContext()
        |> take(1)
        |> deliverOnMainQueue).start(next: { context in
            let presentationData = context.context.sharedContext.currentPresentationData.with { $0 }
            context.context.sharedContext.openExternalUrl(context: context.context, urlContext: .generic, url: url, forceExternal: false, presentationData: presentationData, navigationController: context.rootController, dismissInput: {
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
                    sharedContext.wakeupManager.allowBackgroundTimeExtension(timeout: 4.0)
                    return sharedContext.sharedContext.activeAccounts
                    |> mapToSignal { _, accounts, _ -> Signal<Account, NoError> in
                        for account in accounts {
                            if account.1.id == accountId {
                                return .single(account.1)
                            }
                        }
                        return .complete()
                    }
                    |> take(1)
                    |> deliverOnMainQueue
                    |> mapToSignal { account -> Signal<Void, NoError> in
                        if let messageId = messageIdFromNotification(peerId: peerId, notification: response.notification) {
                            let _ = applyMaxReadIndexInteractively(postbox: account.postbox, stateManager: account.stateManager, index: MessageIndex(id: messageId, timestamp: 0)).start()
                        }
                        return enqueueMessages(account: account, peerId: peerId, messages: [EnqueueMessage.message(text: text, attributes: [], mediaReference: nil, replyToMessageId: nil, localGroupingKey: nil)])
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
            let settings = transaction.getSharedData(ApplicationSpecificSharedDataKeys.inAppNotificationSettings) as? InAppNotificationSettings ?? InAppNotificationSettings.defaultSettings
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
            
            let categories = [unknownMessageCategory, replyMessageCategory, replyLegacyMessageCategory, replyLegacyMediaMessageCategory, replyMediaMessageCategory, legacyChannelMessageCategory, muteMessageCategory, muteMediaMessageCategory]
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
        
    }
    
    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        Logger.shared.log("App \(self.episodeId)", "handleEventsForBackgroundURLSession \(identifier)")
        completionHandler()
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
                return sharedContext.sharedContext.activeAccounts
                |> take(1)
                |> mapToSignal { _, accounts, _ -> Signal<AccountRecordId?, NoError> in
                    let keys = accounts.map { _, account, _ -> Signal<(AccountRecordId, MasterNotificationKey)?, NoError> in
                        return masterNotificationsKey(account: account, ignoreDisabled: true)
                        |> map { key in
                            return (account.id, key)
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
                return sharedContext.sharedContext.activeAccounts
                |> take(1)
                |> map { _, accounts, _ -> AccountRecordId? in
                    for (_, account, _) in accounts {
                        if Int(account.peerId.id) == userId {
                            return account.id
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
    } else {
        let payload = notification.request.content.userInfo
        var peerId: PeerId?
        if let fromId = payload["from_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudUser, id: Int32(fromIdValue.intValue))
        } else if let fromId = payload["chat_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudGroup, id: Int32(fromIdValue.intValue))
        } else if let fromId = payload["channel_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.CloudChannel, id: Int32(fromIdValue.intValue))
        } else if let fromId = payload["encryption_id"] {
            let fromIdValue = fromId as! NSString
            peerId = PeerId(namespace: Namespaces.Peer.SecretChat, id: Int32(fromIdValue.intValue))
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
