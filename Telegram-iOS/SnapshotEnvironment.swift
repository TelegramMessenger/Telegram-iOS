#if DEBUG

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import TelegramUI
import Display
    
enum SnapshotEnvironmentTheme {
    case night
    case day
}

func snapshotEnvironment(application: UIApplication, mainWindow: UIWindow, statusBarHost: StatusBarHost, theme: SnapshotEnvironmentTheme) -> (Account, AccountManager) {
    var randomId: Int64 = 0
    arc4random_buf(&randomId, 8)
    let path = NSTemporaryDirectory() + "\(randomId)"
    
    Logger.setSharedLogger(Logger(basePath: path + "/logs"))
    Logger.shared.logToFile = false
    
    let semaphore = DispatchSemaphore(value: 0)
    var accountManagerValue: AccountManager?
    initializeAccountManagement()
    let _ = accountManager(basePath: path).start(next: { value in
        accountManagerValue = value
        semaphore.signal()
    })
    semaphore.wait()
    precondition(accountManagerValue != nil)
    
    var result: Account?
    while true {
        let account = currentAccount(allocateIfNotExists: true, networkArguments: NetworkInitializationArguments(apiId: 0, languagesCategory: "ios", appVersion: "unknown", voipMaxLayer: 0), supplementary: false, manager: accountManagerValue!, rootPath: path, auxiliaryMethods: AccountAuxiliaryMethods(updatePeerChatInputState: { _, _ in return nil }, fetchResource: { _, _, _, _ in
            return .never()
        }, fetchResourceMediaReferenceHash: { _ in
            return .never()
        })) |> take(1)
        let semaphore = DispatchSemaphore(value: 0)
        let _ = account.start(next: { value in
            switch value! {
                case .upgrading:
                    preconditionFailure()
                case let .unauthorized(account):
                    let _ = account.postbox.transaction({ transaction -> Void in
                        let encoder = PostboxEncoder()
                        encoder.encodeInt32(1, forKey: "masterDatacenterId")
                        encoder.encodeInt64(PeerId(namespace: Namespaces.Peer.CloudUser, id: 1234567).toInt64(), forKey: "peerId")
                        
                        transaction.setState(AuthorizedAccountState(decoder: PostboxDecoder(buffer: encoder.readBufferNoCopy())))
                    }).start()
                case let .authorized(account):
                    result = account
            }
            semaphore.signal()
        })
        semaphore.wait()
        if result != nil {
            break
        }
    }
    
    let applicationBindings = TelegramApplicationBindings(isMainApp: true, containerPath: path, appSpecificScheme: "tg", openUrl: { _ in
    }, openUniversalUrl: { _, completion in
        completion.completion(false)
    }, canOpenUrl: { _ in
        return false
    }, getTopWindow: {
        for window in application.windows.reversed() {
            if window === mainWindow || window === statusBarHost.keyboardWindow {
                return window
            }
        }
        return application.windows.last
    }, displayNotification: { _ in
    }, applicationInForeground: .single(true), applicationIsActive: .single(true), clearMessageNotifications: { _ in
    }, pushIdleTimerExtension: {
        return EmptyDisposable
    }, openSettings: {
    }, openAppStorePage: {
    }, registerForNotifications: { _ in
    }, requestSiriAuthorization: { _ in }, siriAuthorization: { return .notDetermined }, getWindowHost: {
        return nil
    }, presentNativeController: { _ in
    }, dismissNativeController: {
    })
    
    let _ = updatePresentationThemeSettingsInteractively(postbox: result!.postbox, { _ in
        switch theme {
            case .day:
                return PresentationThemeSettings(chatWallpaper: .color(0xffffff), chatWallpaperMode: .still, theme: .builtin(.day), themeAccentColor: nil, fontSize: .regular, automaticThemeSwitchSetting: AutomaticThemeSwitchSetting(trigger: .none, theme: .nightAccent), disableAnimations: false)
            case .night:
                return PresentationThemeSettings(chatWallpaper: .color(0x000000), chatWallpaperMode: .still, theme: .builtin(.nightAccent), themeAccentColor: nil, fontSize: .regular, automaticThemeSwitchSetting: AutomaticThemeSwitchSetting(trigger: .none, theme: .nightAccent), disableAnimations: false)
        }
    }).start()
    
    let semaphore1 = DispatchSemaphore(value: 0)
    var dataAndSettings: InitialPresentationDataAndSettings?
    let _ = currentPresentationDataAndSettings(postbox: result!.postbox).start(next: { value in
        dataAndSettings = value
        semaphore1.signal()
    })
    semaphore1.wait()
    precondition(dataAndSettings != nil)
    
    result!.applicationContext = TelegramApplicationContext(applicationBindings: applicationBindings, accountManager: accountManagerValue!, account: result, initialPresentationDataAndSettings: dataAndSettings!, postbox: result!.postbox)
    
    return (result!, accountManagerValue!)
}

#endif
