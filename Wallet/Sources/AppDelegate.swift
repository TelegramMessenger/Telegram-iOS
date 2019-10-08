import UIKit
import Display
import SwiftSignalKit
import BuildConfig
import WalletUI
import WalletCore

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
        return .single(false)
    }
}

private let records = Atomic<[WalletStateRecord]>(value: [])

private final class WalletStorageInterfaceImpl: WalletStorageInterface {
    func watchWalletRecords() -> Signal<[WalletStateRecord], NoError> {
        return .single(records.with { $0 })
    }
    
    func getWalletRecords() -> Signal<[WalletStateRecord], NoError> {
        return .single(records.with { $0 })
    }
    
    func updateWalletRecords(_ f: @escaping ([WalletStateRecord]) -> [WalletStateRecord]) -> Signal<[WalletStateRecord], NoError> {
        return .single(records.modify(f))
    }
}

private final class WalletContextImpl: WalletContext {
    let storage: WalletStorageInterface
    let tonInstance: TonInstance
    let keychain: TonKeychain
    let presentationData: WalletPresentationData
    
    var inForeground: Signal<Bool, NoError> {
        return .single(true)
    }
    
    func getServerSalt() -> Signal<Data, WalletContextGetServerSaltError> {
        return .single(Data())
    }
    
    func presentNativeController(_ controller: UIViewController) {
        
    }
    
    func idleTimerExtension() -> Disposable {
        return EmptyDisposable
    }
    
    func openUrl(_ url: String) {
        
    }
    
    func shareUrl(_ url: String) {
        
    }
    
    func openPlatformSettings() {
        
    }
    
    func authorizeAccessToCamera(completion: @escaping () -> Void) {
        completion()
    }
    
    func pickImage(completion: @escaping (UIImage) -> Void) {
    }
    
    init(basePath: String, config: String, blockchainName: String, navigationBarTheme: NavigationBarTheme) {
        self.storage = WalletStorageInterfaceImpl()
        self.tonInstance = TonInstance(
            basePath: basePath,
            config: config,
            blockchainName: blockchainName,
            proxy: nil
        )
        self.keychain = TonKeychain(encryptionPublicKey: {
            return .single(Data())
        }, encrypt: { data in
            return .single(TonKeychainEncryptedData(publicKey: Data(), data: data))
        }, decrypt: { data in
            return .single(data.data)
        })
        let accentColor = UIColor(rgb: 0x007ee5)
        self.presentationData = WalletPresentationData(
            theme: WalletTheme(
                info: WalletInfoTheme(
                    incomingFundsTitleColor: UIColor(rgb: 0x00b12c),
                    outgoingFundsTitleColor: UIColor(rgb: 0xff3b30)
                ), setup: WalletSetupTheme(
                    buttonFillColor: accentColor,
                    buttonForegroundColor: .white,
                    inputBackgroundColor: UIColor(rgb: 0xe9e9e9),
                    inputPlaceholderColor: UIColor(rgb: 0x818086),
                    inputTextColor: .black,
                    inputClearButtonColor: UIColor(rgb: 0x7b7b81).withAlphaComponent(0.8)
                ),
                list: WalletListTheme(
                    itemPrimaryTextColor: .black,
                    itemSecondaryTextColor: UIColor(rgb: 0x8e8e93),
                    itemPlaceholderTextColor: UIColor(rgb: 0xc8c8ce),
                    itemDestructiveColor: UIColor(rgb: 0xff3b30),
                    itemAccentColor: accentColor,
                    itemDisabledTextColor: UIColor(rgb: 0x8e8e93),
                    plainBackgroundColor: .white,
                    blocksBackgroundColor: UIColor(rgb: 0xefeff4),
                    itemPlainSeparatorColor: UIColor(rgb: 0xc8c7cc),
                    itemBlocksBackgroundColor: .white,
                    itemBlocksSeparatorColor: UIColor(rgb: 0xc8c7cc),
                    itemHighlightedBackgroundColor: UIColor(rgb: 0xe5e5ea),
                    sectionHeaderTextColor: UIColor(rgb: 0x6d6d72),
                    freeTextColor: UIColor(rgb: 0x6d6d72),
                    freeTextErrorColor: UIColor(rgb: 0xcf3030),
                    inputClearButtonColor: UIColor(rgb: 0xcccccc)
                ),
                statusBarStyle: .Black,
                navigationBar: navigationBarTheme,
                keyboardAppearance: .light,
                alert: AlertControllerTheme(
                    backgroundType: .light,
                    backgroundColor: .white,
                    separatorColor: UIColor(white: 0.9, alpha: 1.0),
                    highlightedItemColor: UIColor(rgb: 0xe5e5ea),
                    primaryColor: .black,
                    secondaryColor: UIColor(rgb: 0x5e5e5e),
                    accentColor: accentColor,
                    destructiveColor: UIColor(rgb: 0xff3b30),
                    disabledColor: UIColor(rgb: 0xd0d0d0)
                ),
                actionSheet: ActionSheetControllerTheme(
                    dimColor: UIColor(white: 0.0, alpha: 0.4),
                    backgroundType: .light,
                    itemBackgroundColor: .white,
                    itemHighlightedBackgroundColor: UIColor(white: 0.9, alpha: 1.0),
                    standardActionTextColor: accentColor,
                    destructiveActionTextColor: UIColor(rgb: 0xff3b30),
                    disabledActionTextColor: UIColor(rgb: 0xb3b3b3),
                    primaryTextColor: .black,
                    secondaryTextColor: UIColor(rgb: 0x5e5e5e),
                    controlAccentColor: accentColor,
                    controlColor: UIColor(rgb: 0x7e8791),
                    switchFrameColor: UIColor(rgb: 0xe0e0e0),
                    switchContentColor: UIColor(rgb: 0x77d572),
                    switchHandleColor: UIColor(rgb: 0xffffff)
                )
            ), strings: WalletStrings(
                primaryComponent: WalletStringsComponent(
                    languageCode: "en",
                    localizedName: "English",
                    pluralizationRulesCode: "en",
                    dict: [:]
                ),
                secondaryComponent: nil,
                groupingSeparator: " "
            ), dateTimeFormat: WalletPresentationDateTimeFormat(
                timeFormat: .regular,
                dateFormat: .dayFirst,
                dateSeparator: ".",
                decimalSeparator: ".",
                groupingSeparator: " "
            )
        )
    }
}

@objc(AppDelegate)
final class AppDelegate: NSObject, UIApplicationDelegate {
    var window: UIWindow?
    
    private var mainWindow: Window1?
    private var walletContext: WalletContextImpl?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        let statusBarHost = ApplicationStatusBarHost()
        let (window, hostView) = nativeWindowHostView()
        self.mainWindow = Window1(hostView: hostView, statusBarHost: statusBarHost)
        hostView.containerView.backgroundColor = UIColor.white
        self.window = window
        
        let navigationBarTheme = NavigationBarTheme(
            buttonColor: .blue,
            disabledButtonColor: .gray,
            primaryTextColor: .black,
            backgroundColor: .lightGray,
            separatorColor: .black,
            badgeBackgroundColor: .red,
            badgeStrokeColor: .red,
            badgeTextColor: .white
        )
        
        let navigationController = NavigationController(
            mode: .single,
            theme: NavigationControllerTheme(
                statusBar: .black,
                navigationBar: navigationBarTheme,
                emptyAreaColor: .white
            ), backgroundDetailsMode: nil
        )
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        
        let config =
"""
{
  "liteservers": [
    {
      "ip": 1137658550,
      "port": 4924,
      "id": {
        "@type": "pub.ed25519",
        "key": "peJTw/arlRfssgTuf9BMypJzqOi7SXEqSPSWiEw2U1M="
      }
    }
  ],
  "validator": {
    "@type": "validator.config.global",
    "zero_state": {
      "workchain": -1,
      "shard": -9223372036854775808,
      "seqno": 0,
      "root_hash": "VCSXxDHhTALFxReyTZRd8E4Ya3ySOmpOWAS4rBX9XBY=",
      "file_hash": "eh9yveSz1qMdJ7mOsO+I+H77jkLr9NpAuEkoJuseXBo="
    }
  }
}
"""
        
        let walletContext = WalletContextImpl(basePath: documentsPath, config: config, blockchainName: "testnet", navigationBarTheme: navigationBarTheme)
        self.walletContext = walletContext
        
        let splashScreen = WalletSplashScreen(context: walletContext, mode: .intro, walletCreatedPreloadState: nil)
        
        navigationController.setViewControllers([splashScreen], animated: false)
        self.mainWindow?.viewController = navigationController
        
        self.window?.makeKeyAndVisible()
        
        return true
    }
}
