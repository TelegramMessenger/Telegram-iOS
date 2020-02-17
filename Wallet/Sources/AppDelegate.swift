import UIKit
import Display
import OverlayStatusController
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
    private let configurationStorage: FileBackedStorage
    
    init(path: String, configurationPath: String) {
        self.storage = FileBackedStorage(path: path)
        self.configurationStorage = FileBackedStorage(path: configurationPath)
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
    
    func mergedLocalWalletConfiguration() -> Signal<MergedLocalWalletConfiguration, NoError> {
        return self.configurationStorage.watch()
        |> map { data -> MergedLocalWalletConfiguration in
            guard let data = data, !data.isEmpty else {
                return .default
            }
            do {
                return try JSONDecoder().decode(MergedLocalWalletConfiguration.self, from: data)
            } catch let error {
                print("Error deserializing data: \(error)")
                return .default
            }
        }
    }
    
    func localWalletConfiguration() -> Signal<LocalWalletConfiguration, NoError> {
        return self.mergedLocalWalletConfiguration()
        |> mapToSignal { value -> Signal<LocalWalletConfiguration, NoError> in
            return .single(value.configuration)
        }
        |> distinctUntilChanged
    }
    
    func updateMergedLocalWalletConfiguration(_ f: @escaping (MergedLocalWalletConfiguration) -> MergedLocalWalletConfiguration) -> Signal<Never, NoError> {
        return self.configurationStorage.update { data -> (Data, Void) in
            do {
                let current: MergedLocalWalletConfiguration?
                if let data = data, !data.isEmpty {
                    current = try? JSONDecoder().decode(MergedLocalWalletConfiguration.self, from: data)
                } else {
                    current = nil
                }
                let updated = f(current ?? .default)
                let updatedData = try JSONEncoder().encode(updated)
                return (updatedData, Void())
            } catch let error {
                print("Error serializing data: \(error)")
                return (Data(), Void())
            }
        }
        |> ignoreValues
    }
    
    func updateLocalWalletConfiguration(_ f: @escaping (LocalWalletConfiguration) -> LocalWalletConfiguration) -> Signal<Never, NoError> {
        return self.updateMergedLocalWalletConfiguration { value in
            var value = value
            value.configuration = f(value.configuration)
            return value
        }
    }
}

private final class WalletContextImpl: NSObject, WalletContext, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    var storage: WalletStorageInterface {
        return self.storageImpl
    }
    private let storageImpl: WalletStorageInterfaceImpl
    let tonInstance: TonInstance
    let keychain: TonKeychain
    let presentationData: WalletPresentationData
    let window: Window1
    
    let supportsCustomConfigurations: Bool = true
    let termsUrl: String? = nil
    let feeInfoUrl: String? = nil
    
    private var currentImagePickerCompletion: ((UIImage) -> Void)?
    
    var inForeground: Signal<Bool, NoError> {
        return .single(true)
    }
    
    func getServerSalt() -> Signal<Data, WalletContextGetServerSaltError> {
        return .single(Data())
    }
    
    func downloadFile(url: URL) -> Signal<Data, WalletDownloadFileError> {
        return download(url: url)
        |> mapError { _ in
            return .generic
        }
    }
    
    func updateResolvedWalletConfiguration(source: LocalWalletConfigurationSource, blockchainName: String, resolvedValue: String) -> Signal<Never, NoError> {
        return self.storageImpl.updateMergedLocalWalletConfiguration { configuration in
            var configuration = configuration
            configuration.configuration.source = source
            configuration.configuration.blockchainName = blockchainName
            configuration.resolved = ResolvedLocalWalletConfiguration(source: source, value: resolvedValue)
            return configuration
        }
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
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { [weak self] response in
            Queue.mainQueue().async {
                guard let strongSelf = self else {
                    return
                }
                
                if response {
                    completion()
                } else {
                    let presentationData = strongSelf.presentationData
                    let controller = standardTextAlertController(theme: presentationData.theme.alert, title: presentationData.strings.Wallet_AccessDenied_Title, text: presentationData.strings.Wallet_AccessDenied_Camera, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Wallet_Intro_NotNow, action: {}), TextAlertAction(type: .genericAction, title: presentationData.strings.Wallet_AccessDenied_Settings, action: {
                        strongSelf.openPlatformSettings()
                    })])
                    strongSelf.window.present(controller, on: .root)
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
    
    init(basePath: String, storage: WalletStorageInterfaceImpl, config: String, blockchainName: String, presentationData: WalletPresentationData, navigationBarTheme: NavigationBarTheme, window: Window1) {
        let _ = try? FileManager.default.createDirectory(at: URL(fileURLWithPath: basePath + "/keys"), withIntermediateDirectories: true, attributes: nil)
        self.storageImpl = storage
        
        self.window = window
        
        self.tonInstance = TonInstance(
            basePath: basePath + "/keys",
            config: config,
            blockchainName: blockchainName,
            proxy: nil
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
        
        self.presentationData = presentationData
        
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
        
        let presentationData = WalletPresentationData(
            theme: WalletTheme(
                info: WalletInfoTheme(
                    buttonBackgroundColor: UIColor(rgb: 0x32aafe),
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
        
        let navigationController = NavigationController(
            mode: .single,
            theme: NavigationControllerTheme(
                statusBar: .black,
                navigationBar: navigationBarTheme,
                emptyAreaColor: .white
            ), backgroundDetailsMode: nil
        )
        
        mainWindow.viewController = navigationController
        
        navigationController.setViewControllers([WalletApplicationSplashScreen(theme: presentationData.theme)], animated: false)
        
        self.window?.makeKeyAndVisible()
        
        let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        #if DEBUG
        print("Starting with \(documentsPath)")
        #endif
        
        let storage = WalletStorageInterfaceImpl(path: documentsPath + "/data", configurationPath: documentsPath + "/configuration_v2")
        
        let initialConfigValue = storage.mergedLocalWalletConfiguration()
        |> take(1)
        |> mapToSignal { configuration -> Signal<(ResolvedLocalWalletConfiguration, String), NoError> in
            if let resolved = configuration.resolved, resolved.source == configuration.configuration.source {
                return .single((resolved, configuration.configuration.blockchainName))
            } else {
                return .complete()
            }
        }
        
        let updatedConfigValue = storage.localWalletConfiguration()
        |> mapToSignal { configuration -> Signal<(ResolvedLocalWalletConfiguration, String), NoError> in
            switch configuration.source {
            case let .url(url):
                guard let parsedUrl = URL(string: url) else {
                    return .complete()
                }
                return download(url: parsedUrl)
                |> retry(1.0, maxDelay: 5.0, onQueue: .mainQueue())
                |> mapToSignal { data -> Signal<(ResolvedLocalWalletConfiguration, String), NoError> in
                    if let string = String(data: data, encoding: .utf8) {
                        return .single((ResolvedLocalWalletConfiguration(source: configuration.source, value: string), configuration.blockchainName))
                    } else {
                        return .complete()
                    }
                }
            case let .string(string):
                return .single((ResolvedLocalWalletConfiguration(source: configuration.source, value: string), configuration.blockchainName))
            }
        }
        |> distinctUntilChanged(isEqual: { lhs, rhs in
            return lhs.0 == rhs.0 && lhs.1 == rhs.1
        })
        |> afterNext { (resolved, _) in
            let _ = storage.updateMergedLocalWalletConfiguration { current in
                var current = current
                current.resolved = resolved
                return current
            }
        }
        
        let resolvedInitialConfig = (
            initialConfigValue
            |> then(updatedConfigValue)
        )
        |> take(1)
        
        let _ = (resolvedInitialConfig
        |> deliverOnMainQueue).start(next: { (initialResolvedConfig, initialConfigBlockchainName) in
            let walletContext = WalletContextImpl(basePath: documentsPath, storage: storage, config: initialResolvedConfig.value, blockchainName: initialConfigBlockchainName, presentationData: presentationData, navigationBarTheme: navigationBarTheme, window: mainWindow)
            self.walletContext = walletContext
            
            let beginWithController: (ViewController) -> Void = { controller in
                let begin: (Bool) -> Void = { animated in
                    navigationController.setViewControllers([controller], animated: false)
                    if animated {
                        navigationController.viewControllers.last?.view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.3)
                    }
                    
                    var previousBlockchainName = initialConfigBlockchainName
                    
                    let _ = (updatedConfigValue
                    |> deliverOnMainQueue).start(next: { resolved, blockchainName in
                        let _ = walletContext.tonInstance.validateConfig(config: resolved.value, blockchainName: blockchainName).start(error: { _ in
                        }, completed: {
                            let _ = walletContext.tonInstance.updateConfig(config: resolved.value, blockchainName: blockchainName).start()
                            
                            if previousBlockchainName != blockchainName {
                                previousBlockchainName = blockchainName
                                
                                let overlayController = OverlayStatusController(theme: presentationData.theme, type: .loading(cancelled: nil))
                                mainWindow.present(overlayController, on: .root)
                                
                                let _ = (deleteAllLocalWalletsData(storage: walletContext.storage, tonInstance: walletContext.tonInstance)
                                |> deliverOnMainQueue).start(error: { [weak overlayController] _ in
                                    overlayController?.dismiss()
                                }, completed: { [weak overlayController] in
                                    overlayController?.dismiss()
                                    
                                    navigationController.setViewControllers([WalletSplashScreen(context: walletContext, mode: .intro, walletCreatedPreloadState: nil)], animated: true)
                                })
                            }
                        })
                    })
                }
                
                if let splashScreen = navigationController.viewControllers.first as? WalletApplicationSplashScreen, let _ = controller as? WalletSplashScreen {
                    splashScreen.animateOut(completion: {
                        begin(true)
                    })
                } else {
                    begin(false)
                }
            }
            
            let _ = (combineLatest(queue: .mainQueue(),
                walletContext.storage.getWalletRecords(),
                walletContext.keychain.encryptionPublicKey()
            )
            |> deliverOnMainQueue).start(next: { records, publicKey in
                if let record = records.first {
                    if let publicKey = publicKey {
                        if record.info.encryptedSecret.publicKey == publicKey {
                            if record.exportCompleted {
                                let _ = (walletAddress(publicKey: record.info.publicKey, tonInstance: walletContext.tonInstance)
                                |> deliverOnMainQueue).start(next: { address in
                                    let infoScreen = WalletInfoScreen(context: walletContext, walletInfo: record.info, address: address, enableDebugActions: false)
                                    beginWithController(infoScreen)
                                })
                            } else {
                                let createdScreen = WalletSplashScreen(context: walletContext, mode: .created(record.info, nil), walletCreatedPreloadState: nil)
                                beginWithController(createdScreen)
                            }
                        } else {
                            let splashScreen = WalletSplashScreen(context: walletContext, mode: .secureStorageReset(.changed), walletCreatedPreloadState: nil)
                            beginWithController(splashScreen)
                        }
                    } else {
                        let splashScreen = WalletSplashScreen(context: walletContext, mode: WalletSplashMode.secureStorageReset(.notAvailable), walletCreatedPreloadState: nil)
                        beginWithController(splashScreen)
                    }
                } else {
                    if publicKey != nil {
                        let splashScreen = WalletSplashScreen(context: walletContext, mode: .intro, walletCreatedPreloadState: nil)
                        beginWithController(splashScreen)
                    } else {
                        let splashScreen = WalletSplashScreen(context: walletContext, mode: .secureStorageNotAvailable, walletCreatedPreloadState: nil)
                        beginWithController(splashScreen)
                    }
                }
            })
        })
        
        return true
    }
}

private enum DownloadFileError {
    case network
}

private func download(url: URL) -> Signal<Data, DownloadFileError> {
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

struct ResolvedLocalWalletConfiguration: Codable, Equatable {
    var source: LocalWalletConfigurationSource
    var value: String
}

struct MergedLocalWalletConfiguration: Codable, Equatable {
    var configuration: LocalWalletConfiguration
    var resolved: ResolvedLocalWalletConfiguration?
}

private extension MergedLocalWalletConfiguration {
    static var `default`: MergedLocalWalletConfiguration {
        return MergedLocalWalletConfiguration(configuration: LocalWalletConfiguration(source: .url("https://test.ton.org/config.json"), blockchainName: "testnet2"), resolved: nil)
    }
}
