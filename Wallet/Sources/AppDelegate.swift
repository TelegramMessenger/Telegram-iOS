import UIKit
import Display
import SwiftSignalKit
import BuildConfig
import WalletUI
import WalletCore
import AVFoundation

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

private final class FileBackedStorageImpl {
    private let queue: Queue
    private let path: String
    private var data: Data?
    private var subscribers = Bag<(Data?) -> Void>()
    
    init(queue: Queue, path: String) {
        self.queue = queue
        self.path = path
    }
    
    func get() -> Data? {
        if let data = self.data {
            return data
        } else {
            self.data = try? Data(contentsOf: URL(fileURLWithPath: self.path))
            return self.data
        }
    }
    
    func set(data: Data) {
        self.data = data
        do {
            try data.write(to: URL(fileURLWithPath: self.path), options: .atomic)
        } catch let error {
            print("Error writng data: \(error)")
        }
        for f in self.subscribers.copyItems() {
            f(data)
        }
    }
    
    func watch(_ f: @escaping (Data?) -> Void) -> Disposable {
        f(self.get())
        let index = self.subscribers.add(f)
        let queue = self.queue
        return ActionDisposable { [weak self] in
            queue.async {
                guard let strongSelf = self else {
                    return
                }
                strongSelf.subscribers.remove(index)
            }
        }
    }
}

private final class FileBackedStorage {
    private let queue = Queue()
    private let impl: QueueLocalObject<FileBackedStorageImpl>
    
    init(path: String) {
        let queue = self.queue
        self.impl = QueueLocalObject(queue: queue, generate: {
            return FileBackedStorageImpl(queue: queue, path: path)
        })
    }
    
    func get() -> Signal<Data?, NoError> {
        return Signal { subscriber in
            self.impl.with { impl in
                subscriber.putNext(impl.get())
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    func set(data: Data) -> Signal<Never, NoError> {
        return Signal { subscriber in
            self.impl.with { impl in
                impl.set(data: data)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    func update<T>(_ f: @escaping (Data?) -> (Data, T)) -> Signal<T, NoError> {
        return Signal { subscriber in
            self.impl.with { impl in
                let (data, result) = f(impl.get())
                impl.set(data: data)
                subscriber.putNext(result)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
    
    func watch() -> Signal<Data?, NoError> {
        return Signal { subscriber in
            let disposable = MetaDisposable()
            self.impl.with { impl in
                disposable.set(impl.watch({ data in
                    subscriber.putNext(data)
                }))
            }
            return disposable
        }
    }
}

private let records = Atomic<[WalletStateRecord]>(value: [])

private final class WalletStorageInterfaceImpl: WalletStorageInterface {
    private let storage: FileBackedStorage
    
    init(path: String) {
        self.storage = FileBackedStorage(path: path)
    }
    
    func watchWalletRecords() -> Signal<[WalletStateRecord], NoError> {
        return self.storage.watch()
        |> map { data -> [WalletStateRecord] in
            guard let data = data else {
                return []
            }
            do {
                return try JSONDecoder().decode(Array<WalletStateRecord>.self, from: data)
            } catch let error {
                print("Error deserializing data: \(error)")
                return []
            }
        }
    }
    
    func getWalletRecords() -> Signal<[WalletStateRecord], NoError> {
        return self.storage.get()
        |> map { data -> [WalletStateRecord] in
            guard let data = data else {
                return []
            }
            do {
                return try JSONDecoder().decode(Array<WalletStateRecord>.self, from: data)
            } catch let error {
                print("Error deserializing data: \(error)")
                return []
            }
        }
    }
    
    func updateWalletRecords(_ f: @escaping ([WalletStateRecord]) -> [WalletStateRecord]) -> Signal<[WalletStateRecord], NoError> {
        return self.storage.update { data -> (Data, [WalletStateRecord]) in
            let records: [WalletStateRecord] = data.flatMap {
                try? JSONDecoder().decode(Array<WalletStateRecord>.self, from: $0)
            } ?? []
            let updatedRecords = f(records)
            do {
                let updatedData = try JSONEncoder().encode(updatedRecords)
                return (updatedData, updatedRecords)
            } catch let error {
                print("Error serializing data: \(error)")
                return (Data(), updatedRecords)
            }
        }
    }
}

private final class WalletContextImpl: NSObject, WalletContext, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let storage: WalletStorageInterface
    let tonInstance: TonInstance
    let keychain: TonKeychain
    let presentationData: WalletPresentationData
    let window: Window1
    
    private var currentImagePickerCompletion: ((UIImage) -> Void)?
    
    var inForeground: Signal<Bool, NoError> {
        return .single(true)
    }
    
    func getServerSalt() -> Signal<Data, WalletContextGetServerSaltError> {
        return .single(Data())
    }
    
    func presentNativeController(_ controller: UIViewController) {
        self.window.presentNative(controller)
    }
    
    func idleTimerExtension() -> Disposable {
        return EmptyDisposable
    }
    
    func openUrl(_ url: String) {
        if let parsedUrl = URL(string: url) {
            UIApplication.shared.openURL(parsedUrl)
        }
    }
    
    func shareUrl(_ url: String) {
        if let parsedUrl = URL(string: url) {
            self.presentNativeController(UIActivityViewController(activityItems: [parsedUrl], applicationActivities: nil))
        }
    }
    
    func openPlatformSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.openURL(url)
        }
    }
    
    func authorizeAccessToCamera(completion: @escaping () -> Void) {
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { response in
            Queue.mainQueue().async {
                if response {
                    completion()
                }
            }
        }
    }
    
    func pickImage(present: @escaping (ViewController) -> Void, completion: @escaping (UIImage) -> Void) {
        self.currentImagePickerCompletion = completion
        
        let pickerController = UIImagePickerController()
        pickerController.delegate = self
        pickerController.allowsEditing = false
        pickerController.mediaTypes = ["public.image"]
        pickerController.sourceType = .photoLibrary
        self.presentNativeController(pickerController)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let currentImagePickerCompletion = self.currentImagePickerCompletion
        self.currentImagePickerCompletion = nil
        if let image = info[.editedImage] as? UIImage {
            currentImagePickerCompletion?(image)
        } else if let image = info[.originalImage] as? UIImage {
            currentImagePickerCompletion?(image)
        }
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        self.currentImagePickerCompletion = nil
        picker.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    init(basePath: String, config: String, blockchainName: String, navigationBarTheme: NavigationBarTheme, window: Window1) {
        let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: basePath + "/keys"), withIntermediateDirectories: true, attributes: nil)
        
        self.storage = WalletStorageInterfaceImpl(path: basePath + "/data")
        self.window = window
        
        self.tonInstance = TonInstance(
            basePath: basePath + "/keys",
            config: config,
            blockchainName: blockchainName,
            proxy: nil /*TonProxyImpl()*/
        )
        
        let baseAppBundleId = Bundle.main.bundleIdentifier!
        
        #if targetEnvironment(simulator)
        self.keychain = TonKeychain(encryptionPublicKey: {
            return .single(Data())
        }, encrypt: { data in
            return .single(TonKeychainEncryptedData(publicKey: Data(), data: data))
        }, decrypt: { data in
            return .single(data.data)
        })
        #else
        self.keychain = TonKeychain(encryptionPublicKey: {
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
        let accentColor = UIColor(rgb: 0x007ee5)
        self.presentationData = WalletPresentationData(
            theme: WalletTheme(
                info: WalletInfoTheme(
                    buttonBackgroundColor: accentColor,
                    buttonTextColor: .white,
                    incomingFundsTitleColor: UIColor(rgb: 0x00b12c),
                    outgoingFundsTitleColor: UIColor(rgb: 0xff3b30)
                ), transaction: WalletTransactionTheme(
                    descriptionBackgroundColor: UIColor(rgb: 0xf1f1f4),
                    descriptionTextColor: .black
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
        
        super.init()
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
        let mainWindow = Window1(hostView: hostView, statusBarHost: statusBarHost)
        self.mainWindow = mainWindow
        hostView.containerView.backgroundColor = UIColor.white
        self.window = window
        
        let accentColor = UIColor(rgb: 0x007ee5)
        let navigationBarTheme = NavigationBarTheme(
            buttonColor: accentColor,
            disabledButtonColor: UIColor(rgb: 0xd0d0d0),
            primaryTextColor: .black,
            backgroundColor: UIColor(rgb: 0xf7f7f7),
            separatorColor: UIColor(rgb: 0xb1b1b1),
            badgeBackgroundColor: UIColor(rgb: 0xff3b30),
            badgeStrokeColor: UIColor(rgb: 0xff3b30),
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
        
        mainWindow.viewController = navigationController
        
        self.window?.makeKeyAndVisible()
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        #if DEBUG
        print("Starting with \(documentsPath)")
        #endif
        
        let updatedConfigSignal: Signal<String, NoError> = Signal { subscriber in
            let downloadTask = URLSession.shared.downloadTask(with: URL(string: "https://test.ton.org/ton-lite-client-test1.config.json")!, completionHandler: { location, _, error in
                if let location = location, let data = try? Data(contentsOf: location), let string = String(data: data, encoding: .utf8) {
                    subscriber.putNext(string)
                    subscriber.putCompletion()
                }
            })
            downloadTask.resume()
            
            return ActionDisposable {
            }
        }
        
        let updatedConfig = Promise<String>()
        updatedConfig.set(updatedConfigSignal)
        
        let configPath = documentsPath + "/config"
        var initialConfig: Signal<String, NoError> = .complete()
        if let data = try? Data(contentsOf: URL(fileURLWithPath: configPath)), let string = String(data: data, encoding: .utf8) {
            initialConfig = .single(string)
        } else {
            initialConfig = updatedConfig.get() |> take(1)
        }
        
        let _ = (initialConfig
        |> deliverOnMainQueue).start(next: { initialConfig in
            let walletContext = WalletContextImpl(basePath: documentsPath, config: initialConfig, blockchainName: "testnet", navigationBarTheme: navigationBarTheme, window: mainWindow)
            self.walletContext = walletContext
            
            let _ = (updatedConfig.get()
            |> deliverOnMainQueue).start(next: { config in
                if config != initialConfig {
                    let _ = walletContext.tonInstance.updateConfig(config: config, blockchainName: "testnet").start()
                }
            })
            
            let _ = (combineLatest(queue: .mainQueue(),
                walletContext.storage.getWalletRecords(),
                walletContext.keychain.encryptionPublicKey()
            )
            |> deliverOnMainQueue).start(next: { records, publicKey in
                if let record = records.first {
                    if let publicKey = publicKey {
                        print("publicKey = \(publicKey.base64EncodedString())")
                        if record.info.encryptedSecret.publicKey == publicKey {
                            if record.exportCompleted {
                                let _ = (walletAddress(publicKey: record.info.publicKey, tonInstance: walletContext.tonInstance)
                                |> deliverOnMainQueue).start(next: { address in
                                    let infoScreen = WalletInfoScreen(context: walletContext, walletInfo: record.info, address: address, enableDebugActions: false)

                                    navigationController.setViewControllers([infoScreen], animated: false)
                                })
                            } else {
                                let createdScreen = WalletSplashScreen(context: walletContext, mode: .created(record.info, nil), walletCreatedPreloadState: nil)
                                
                                navigationController.setViewControllers([createdScreen], animated: false)
                            }
                        } else {
                            let splashScreen = WalletSplashScreen(context: walletContext, mode: .secureStorageReset(.changed), walletCreatedPreloadState: nil)
                            
                            navigationController.setViewControllers([splashScreen], animated: false)
                        }
                    } else {
                        let splashScreen = WalletSplashScreen(context: walletContext, mode: WalletSplashMode.secureStorageReset(.notAvailable), walletCreatedPreloadState: nil)
                        
                        navigationController.setViewControllers([splashScreen], animated: false)
                    }
                } else {
                    if publicKey != nil {
                        let splashScreen = WalletSplashScreen(context: walletContext, mode: .intro, walletCreatedPreloadState: nil)
                        
                        navigationController.setViewControllers([splashScreen], animated: false)
                    } else {
                        let splashScreen = WalletSplashScreen(context: walletContext, mode: .secureStorageNotAvailable, walletCreatedPreloadState: nil)
                        
                        navigationController.setViewControllers([splashScreen], animated: false)
                    }
                }
            })
        })
        
        return true
    }
}
