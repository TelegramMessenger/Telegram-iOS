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

import ZIPFoundation

private let inForeground = ValuePromise<Bool>(false, ignoreRepeated: true)

private final class LinearProgressNode: ASDisplayNode {
    private let trackingNode: HierarchyTrackingNode
    private let backgroundNode: ASImageNode
    private let barNode: ASImageNode
    private let shimmerNode: ASImageNode
    private let shimmerClippingNode: ASDisplayNode
    
    private var currentProgress: CGFloat = 0.0
    private var currentProgressAnimation: (from: CGFloat, to: CGFloat, startTime: Double, completion: () -> Void)?
    
    private var shimmerPhase: CGFloat = 0.0
    
    private var inHierarchyValue: Bool = false
    private var shouldAnimate: Bool = false
    
    private let animator: ConstantDisplayLinkAnimator
    
    override init() {
        var updateInHierarchy: ((Bool) -> Void)?
        self.trackingNode = HierarchyTrackingNode { value in
            updateInHierarchy?(value)
        }
        
        var animationStep: (() -> Void)?
        self.animator = ConstantDisplayLinkAnimator {
            animationStep?()
        }
        
        self.backgroundNode = ASImageNode()
        self.backgroundNode.isLayerBacked = true
        
        self.barNode = ASImageNode()
        self.barNode.isLayerBacked = true
        
        self.shimmerNode = ASImageNode()
        self.shimmerNode.contentMode = .scaleToFill
        self.shimmerClippingNode = ASDisplayNode()
        self.shimmerClippingNode.clipsToBounds = true
        
        super.init()
        
        self.addSubnode(trackingNode)
        self.addSubnode(self.backgroundNode)
        self.addSubnode(self.barNode)
        
        self.shimmerClippingNode.addSubnode(self.shimmerNode)
        self.addSubnode(self.shimmerClippingNode)
        
        updateInHierarchy = { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if strongSelf.inHierarchyValue != value {
                strongSelf.inHierarchyValue = value
                strongSelf.updateAnimations()
            }
        }
        
        animationStep = { [weak self] in
            self?.update()
        }
    }
    
    func updateTheme(theme: PresentationTheme) {
        self.backgroundNode.image = generateStretchableFilledCircleImage(diameter: 3.0, color: theme.list.itemAccentColor.withMultipliedAlpha(0.2))
        self.barNode.image = generateStretchableFilledCircleImage(diameter: 3.0, color: theme.list.itemAccentColor)
        self.shimmerNode.image = generateImage(CGSize(width: 100.0, height: 3.0), opaque: false, rotatedContext: { size, context in
            context.clear(CGRect(origin: CGPoint(), size: size))
            
            let foregroundColor = theme.list.plainBackgroundColor.withAlphaComponent(0.4)
            
            let transparentColor = foregroundColor.withAlphaComponent(0.0).cgColor
            let peakColor = foregroundColor.cgColor
            
            var locations: [CGFloat] = [0.0, 0.5, 1.0]
            let colors: [CGColor] = [transparentColor, peakColor, transparentColor]
            
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: &locations)!
            
            context.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: size.width, y: 0.0), options: CGGradientDrawingOptions())
        })
    }
    
    func updateProgress(value: CGFloat, completion: @escaping () -> Void = {}) {
        if self.currentProgress.isEqual(to: value) {
            self.currentProgressAnimation = nil
            completion()
        } else {
            if value.isEqual(to: 1.0) {
                self.shimmerNode.alpha = 0.0
            }
            self.currentProgressAnimation = (self.currentProgress, value, CACurrentMediaTime(), completion)
        }
    }
    
    private func updateAnimations() {
        let shouldAnimate = self.inHierarchyValue
        if shouldAnimate != self.shouldAnimate {
            self.shouldAnimate = shouldAnimate
            self.animator.isPaused = !shouldAnimate
        }
    }
    
    private func update() {
        if let (fromValue, toValue, startTime, completion) = self.currentProgressAnimation {
            let duration: Double = 0.15
            let timestamp = CACurrentMediaTime()
            let t = CGFloat((timestamp - startTime) / duration)
            if t >= 1.0 {
                self.currentProgress = toValue
                self.currentProgressAnimation = nil
                completion()
            } else {
                let clippedT = max(0.0, t)
                self.currentProgress = (1.0 - clippedT) * fromValue + clippedT * toValue
            }
            
            var progressWidth: CGFloat = self.bounds.width * self.currentProgress
            if progressWidth < 6.0 {
                progressWidth = 0.0
            }
            let progressFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: progressWidth, height: 3.0))
            self.barNode.frame = progressFrame
            self.shimmerClippingNode.frame = progressFrame
        }
        self.backgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: self.bounds.width, height: 3.0))
        
        self.shimmerPhase += 3.5
        let shimmerWidth: CGFloat = 160.0
        let shimmerOffset = self.shimmerPhase.remainder(dividingBy: self.bounds.width + shimmerWidth / 2.0)
        self.shimmerNode.frame = CGRect(origin: CGPoint(x: shimmerOffset - shimmerWidth / 2.0, y: 0.0), size: CGSize(width: shimmerWidth, height: 3.0))
    }
}

private final class ChatImportProgressController: ViewController {
    private final class Node: ViewControllerTracingNode {
        private weak var controller: ChatImportProgressController?
        
        private let context: AccountContext
        private var presentationData: PresentationData
        
        private let statusText: ImmediateTextNode
        private let statusButtonText: ImmediateTextNode
        private let statusButton: HighlightableButtonNode
        
        private let messagesProgressText: ImmediateTextNode
        private let messagesProgressNode: LinearProgressNode
        
        private let mediaProgressText: ImmediateTextNode
        private let mediaProgressNode: LinearProgressNode
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        private let mediaCount: Int
        private var mediaProgress: Int
        private var messagesProgress: CGFloat = 0.0
        private var isDone: Bool = false
        
        init(controller: ChatImportProgressController, context: AccountContext, mediaCount: Int) {
            self.controller = controller
            self.context = context
            
            self.mediaCount = mediaCount
            self.mediaProgress = 0
            
            self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
            
            self.messagesProgressText = ImmediateTextNode()
            self.messagesProgressText.isUserInteractionEnabled = false
            self.messagesProgressText.displaysAsynchronously = false
            self.messagesProgressText.maximumNumberOfLines = 1
            self.messagesProgressText.isAccessibilityElement = false
            
            self.mediaProgressText = ImmediateTextNode()
            self.mediaProgressText.isUserInteractionEnabled = false
            self.mediaProgressText.displaysAsynchronously = false
            self.mediaProgressText.maximumNumberOfLines = 1
            self.mediaProgressText.isAccessibilityElement = false
            
            self.statusText = ImmediateTextNode()
            self.statusText.textAlignment = .center
            self.statusText.isUserInteractionEnabled = false
            self.statusText.displaysAsynchronously = false
            self.statusText.maximumNumberOfLines = 0
            self.statusText.isAccessibilityElement = false
            
            self.statusButtonText = ImmediateTextNode()
            self.statusButtonText.isUserInteractionEnabled = false
            self.statusButtonText.displaysAsynchronously = false
            self.statusButtonText.maximumNumberOfLines = 1
            self.statusButtonText.isAccessibilityElement = false
            
            self.statusButton = HighlightableButtonNode()
            
            self.messagesProgressNode = LinearProgressNode()
            self.messagesProgressNode.updateTheme(theme: self.presentationData.theme)
            
            self.mediaProgressNode = LinearProgressNode()
            self.mediaProgressNode.updateTheme(theme: self.presentationData.theme)
            
            super.init()
            
            self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            
            self.addSubnode(self.messagesProgressText)
            self.addSubnode(self.messagesProgressNode)
            self.addSubnode(self.mediaProgressText)
            self.addSubnode(self.mediaProgressNode)
            self.addSubnode(self.statusText)
            self.addSubnode(self.statusButtonText)
            self.addSubnode(self.statusButton)
            
            self.statusButton.addTarget(self, action: #selector(self.statusButtonPressed), forControlEvents: .touchUpInside)
            self.statusButton.highligthedChanged = { [weak self] highlighted in
                if let strongSelf = self {
                    if highlighted {
                        strongSelf.statusButtonText.layer.removeAnimation(forKey: "opacity")
                        strongSelf.statusButtonText.alpha = 0.4
                    } else {
                        strongSelf.statusButtonText.alpha = 1.0
                        strongSelf.statusButtonText.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                    }
                }
            }
        }
        
        @objc private func statusButtonPressed() {
            self.controller?.cancel()
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            self.validLayout = (layout, navigationHeight)
            
            //TODO:localize
            
            self.messagesProgressText.attributedText = NSAttributedString(string: "Message Texts", font: Font.regular(15.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let messagesProgressTextSize = self.messagesProgressText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            self.mediaProgressText.attributedText = NSAttributedString(string: "\(self.mediaProgress) media out of \(self.mediaCount)", font: Font.regular(15.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
            let mediaProgressTextSize = self.mediaProgressText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            self.statusButtonText.attributedText = NSAttributedString(string: "Done", font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemAccentColor)
            let statusButtonTextSize = self.statusButtonText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            var statusTextOffset: CGFloat = 0.0
            let statusButtonSpacing: CGFloat = 10.0
            
            if !self.isDone {
                self.statusText.attributedText = NSAttributedString(string: "Please keep this window open\nduring the import.", font: Font.regular(16.0), textColor: self.presentationData.theme.list.itemSecondaryTextColor)
            } else {
                self.statusText.attributedText = NSAttributedString(string: "This chat has been imported\nsuccessfully.", font: Font.semibold(16.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)
                statusTextOffset -= statusButtonTextSize.height - statusButtonSpacing
            }
            let statusTextSize = self.statusText.updateLayout(CGSize(width: layout.size.width - 16.0 * 2.0, height: .greatestFiniteMagnitude))
            
            let mediaProgressHeight: CGFloat = 4.0
            let progressSpacing: CGFloat = 16.0
            let sectionSpacing: CGFloat = 50.0
            
            let contentOriginY = navigationHeight + floor((layout.size.height - navigationHeight - messagesProgressTextSize.height - progressSpacing - mediaProgressHeight - sectionSpacing - mediaProgressTextSize.height - progressSpacing - mediaProgressHeight) / 2.0)
            
            let messagesProgressTextFrame = CGRect(origin: CGPoint(x: 16.0, y: contentOriginY), size: messagesProgressTextSize)
            self.messagesProgressText.frame = messagesProgressTextFrame
            let messagesProgressFrame = CGRect(origin: CGPoint(x: 16.0, y: messagesProgressTextFrame.maxY + progressSpacing), size: CGSize(width: layout.size.width - 16.0 * 2.0, height: mediaProgressHeight))
            self.messagesProgressNode.frame = messagesProgressFrame
            
            let mediaProgressTextFrame = CGRect(origin: CGPoint(x: 16.0, y: messagesProgressFrame.maxY + sectionSpacing), size: mediaProgressTextSize)
            self.mediaProgressText.frame = mediaProgressTextFrame
            let mediaProgressFrame = CGRect(origin: CGPoint(x: 16.0, y: mediaProgressTextFrame.maxY + progressSpacing), size: CGSize(width: layout.size.width - 16.0 * 2.0, height: mediaProgressHeight))
            self.mediaProgressNode.frame = mediaProgressFrame
            
            let statusTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusTextSize.width) / 2.0), y: layout.size.height - layout.intrinsicInsets.bottom - 16.0 - statusTextSize.height + statusTextOffset), size: statusTextSize)
            self.statusText.frame = statusTextFrame
            
            let statusButtonTextFrame = CGRect(origin: CGPoint(x: floor((layout.size.width - statusButtonTextSize.width) / 2.0), y: statusTextFrame.maxY + statusButtonSpacing), size: statusButtonTextSize)
            self.statusButtonText.frame = statusButtonTextFrame
            
            self.statusButtonText.isHidden = !self.isDone
            self.statusButton.isHidden = !self.isDone
            self.statusButton.frame = statusButtonTextFrame.insetBy(dx: -10.0, dy: -10.0)
        }
        
        func updateProgress(mediaProgress: Int, messagesProgress: CGFloat, isDone: Bool, animated: Bool) {
            self.mediaProgress = mediaProgress
            self.isDone = isDone
            
            if let (layout, navigationHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationHeight: navigationHeight, transition: .immediate)
                self.messagesProgressNode.updateProgress(value: messagesProgress)
                self.mediaProgressNode.updateProgress(value: CGFloat(mediaProgress) / CGFloat(self.mediaCount))
            }
        }
    }
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let context: AccountContext
    private var presentationData: PresentationData
    let cancel: () -> Void
    private let peerId: PeerId
    private let archive: Archive
    private let mainEntry: TempBoxFile
    private let otherEntries: [(Entry, String, ChatHistoryImport.MediaType)]
    
    private var pendingEntries = Set<String>()
    
    private let disposable = MetaDisposable()
    
    init(context: AccountContext, cancel: @escaping () -> Void, peerId: PeerId, archive: Archive, mainEntry: TempBoxFile, otherEntries: [(Entry, String, ChatHistoryImport.MediaType)]) {
        self.context = context
        self.cancel = cancel
        self.peerId = peerId
        self.archive = archive
        self.mainEntry = mainEntry
        self.otherEntries = otherEntries
        
        self.pendingEntries = Set(otherEntries.map { $0.1 })
        
        self.presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        //TODO:localize
        self.title = "Importing Chat"
        
        self.navigationItem.setLeftBarButton(UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed)), animated: false)
        
        self.attemptNavigation = { _ in
            return false
        }
        
        self.beginImport()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
    }
    
    @objc private func cancelPressed() {
        self.cancel()
    }
    
    override func loadDisplayNode() {
        self.displayNode = Node(controller: self, context: self.context, mediaCount: self.otherEntries.count)
        
        self.displayNodeDidLoad()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationHeight: self.navigationHeight, transition: transition)
    }
    
    private func beginImport() {
        enum ImportError {
            case generic
        }
        
        let context = self.context
        let archive = self.archive
        let otherEntries = self.otherEntries
        self.disposable.set((ChatHistoryImport.initSession(account: self.context.account, peerId: self.peerId, file: self.mainEntry, mediaCount: Int32(otherEntries.count))
        |> mapError { _ -> ImportError in
            return .generic
        }
        |> mapToSignal { session -> Signal<String, ImportError> in
            var importSignal: Signal<String, ImportError> = .single("")
            
            for (entry, fileName, mediaType) in otherEntries {
                let unpackedFile = Signal<TempBoxFile, ImportError> { subscriber in
                    let tempFile = TempBox.shared.tempFile(fileName: fileName)
                    do {
                        let _ = try archive.extract(entry, to: URL(fileURLWithPath: tempFile.path))
                        subscriber.putNext(tempFile)
                        subscriber.putCompletion()
                    } catch {
                        subscriber.putError(.generic)
                    }
                    
                    return EmptyDisposable
                }
                let uploadedMedia = unpackedFile
                |> mapToSignal { tempFile -> Signal<String, ImportError> in
                    return ChatHistoryImport.uploadMedia(account: context.account, session: session, file: tempFile, fileName: fileName, type: mediaType)
                    |> mapError { _ -> ImportError in
                        return .generic
                    }
                    |> map { _ -> String in
                    }
                    |> then(.single(fileName))
                }
                
                importSignal = importSignal
                |> then(uploadedMedia)
            }
            
            importSignal = importSignal
            |> then(ChatHistoryImport.startImport(account: context.account, session: session)
            |> mapError { _ -> ImportError in
                return .generic
            }
            |> map { _ -> String in
            })
            
            return importSignal
        }
        |> deliverOnMainQueue).start(next: { [weak self] fileName in
            guard let strongSelf = self else {
                return
            }
            strongSelf.pendingEntries.remove(fileName)
            strongSelf.controllerNode.updateProgress(mediaProgress: strongSelf.otherEntries.count - strongSelf.pendingEntries.count, messagesProgress: 1.0, isDone: false, animated: true)
        }, error: { [weak self] _ in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateProgress(mediaProgress: 0, messagesProgress: 0.0, isDone: false, animated: true)
        }, completed: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.controllerNode.updateProgress(mediaProgress: strongSelf.otherEntries.count, messagesProgress: 1.0, isDone: true, animated: true)
        }))
    }
}

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
                                        
                                        let groupCreationRegexList = [
                                            try! NSRegularExpression(pattern: "created group “(.*?)”"),
                                            try! NSRegularExpression(pattern: "] (.*?): ‎Messages and calls are end-to-end encrypted")
                                        ]
                                        
                                        var groupTitle: String?
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
                                                    if let fileContents = try? String(contentsOfFile: tempFile.path) {
                                                        let fullRange = NSRange(fileContents.startIndex ..< fileContents.endIndex, in: fileContents)
                                                        for regex in groupCreationRegexList {
                                                            if groupTitle != nil {
                                                                break
                                                            }
                                                            if let match = regex.firstMatch(in: fileContents, options: [], range: fullRange) {
                                                                let range = match.range(at: 1)
                                                                if let mappedRange = Range(range, in: fileContents) {
                                                                    groupTitle = String(fileContents[mappedRange])
                                                                }
                                                            }
                                                        }
                                                    }
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
                                        if let mainFile = mainFile, let groupTitle = groupTitle {
                                            let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                            let navigationController = NavigationController(mode: .single, theme: NavigationControllerTheme(presentationTheme: presentationData.theme))
                                            
                                            //TODO:localize
                                            var attemptSelectionImpl: ((Peer) -> Void)?
                                            var createNewGroupImpl: (() -> Void)?
                                            let controller = context.sharedContext.makePeerSelectionController(PeerSelectionControllerParams(context: context, filter: [.onlyGroups, .onlyManageable, .excludeDisabled], hasContactSelector: false, title: "Import Chat", attemptSelection: { peer in
                                                attemptSelectionImpl?(peer)
                                            }, createNewGroup: {
                                                createNewGroupImpl?()
                                            }))
                                            
                                            controller.peerSelected = { peer in
                                                attemptSelectionImpl?(peer)
                                            }
                                            
                                            controller.navigationPresentation = .default
                                            
                                            let beginWithPeer: (PeerId) -> Void = { peerId in
                                                navigationController.pushViewController(ChatImportProgressController(context: context, cancel: {
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
                                                    let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: "Import Messages", text: "Are you sure you want to import messages from \(groupTitle) into \(peer.debugDisplayTitle)?", actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                                    }), TextAlertAction(type: .defaultAction, title: "Import", action: {
                                                        beginWithPeer(peer.id)
                                                    })])
                                                    strongSelf.mainWindow?.present(controller, on: .root)
                                                }
                                            }
                                            
                                            createNewGroupImpl = {
                                                let presentationData = internalContext.sharedContext.currentPresentationData.with { $0 }
                                                let controller = standardTextAlertController(theme: AlertControllerTheme(presentationData: presentationData), title: "Create Group and Import Messages", text: "Are you sure you want to create group \(groupTitle) and import messages from another messaging app?", actions: [TextAlertAction(type: .defaultAction, title: "Create and Import", action: {
                                                    var signal: Signal<PeerId?, NoError> = createSupergroup(account: context.account, title: groupTitle, description: nil)
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
                                                })])
                                                strongSelf.mainWindow?.present(controller, on: .root)
                                            }
                                            
                                            navigationController.viewControllers = [controller]
                                            strongSelf.mainWindow?.present(navigationController, on: .root)
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
