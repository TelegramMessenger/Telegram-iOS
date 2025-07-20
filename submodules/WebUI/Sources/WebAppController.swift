import Foundation
import UIKit
@preconcurrency import WebKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import ComponentFlow
import TelegramPresentationData
import AccountContext
import AttachmentUI
import ContextUI
import PresentationDataUtils
import HexColor
import ShimmerEffect
import PhotoResources
import MediaResources
import LegacyComponents
import UrlHandling
import MoreButtonNode
import BotPaymentsUI
import PromptUI
import PhoneNumberFormat
import QrCodeUI
import InstantPageUI
import InstantPageCache
import LocalAuth
import OpenInExternalAppUI
import ShareController
import UndoUI
import AvatarNode
import OverlayStatusController
import TelegramUIPreferences
import CoreMotion
import DeviceAccess
import DeviceLocationManager
import LegacyMediaPickerUI
import GenerateStickerPlaceholderImage
import PassKit
import Photos

private let durgerKingBotIds: [Int64] = [5104055776, 2200339955]

public struct WebAppParameters {
    public enum Source {
        case generic
        case button
        case menu
        case attachMenu
        case inline
        case simple
        case settings
        
        var isSimple: Bool {
            if [.simple, .inline, .settings].contains(self) {
                return true
            } else {
                return false
            }
        }
    }
    
    let source: Source
    let peerId: PeerId
    let botId: PeerId
    let botName: String
    let botVerified: Bool
    let botAddress: String
    let appName: String?
    let url: String?
    let queryId: Int64?
    let payload: String?
    let buttonText: String?
    let keepAliveSignal: Signal<Never, KeepWebViewError>?
    let forceHasSettings: Bool
    let fullSize: Bool
    let isFullscreen: Bool
    let appSettings: BotAppSettings?
    
    public init(
        source: Source,
        peerId: PeerId,
        botId: PeerId,
        botName: String,
        botVerified: Bool,
        botAddress: String,
        appName: String?,
        url: String?,
        queryId: Int64?,
        payload: String?,
        buttonText: String?,
        keepAliveSignal: Signal<Never, KeepWebViewError>?,
        forceHasSettings: Bool,
        fullSize: Bool,
        isFullscreen: Bool = false,
        appSettings: BotAppSettings? = nil
    ) {
        self.source = source
        self.peerId = peerId
        self.botId = botId
        self.botName = botName
        self.botVerified = botVerified
        self.botAddress = botAddress
        self.appName = appName
        self.url = url
        self.queryId = queryId
        self.payload = payload
        self.buttonText = buttonText
        self.keepAliveSignal = keepAliveSignal
        self.forceHasSettings = forceHasSettings
        self.fullSize = fullSize || isFullscreen
        self.isFullscreen = isFullscreen
        self.appSettings = appSettings
    }
}

public func generateWebAppThemeParams(_ theme: PresentationTheme) -> [String: Any] {
    return [
        "bg_color": Int32(bitPattern: theme.list.plainBackgroundColor.rgb),
        "secondary_bg_color": Int32(bitPattern: theme.list.blocksBackgroundColor.rgb),
        "text_color": Int32(bitPattern: theme.list.itemPrimaryTextColor.rgb),
        "hint_color": Int32(bitPattern: theme.list.itemSecondaryTextColor.rgb),
        "link_color": Int32(bitPattern: theme.list.itemAccentColor.rgb),
        "button_color": Int32(bitPattern: theme.list.itemCheckColors.fillColor.rgb),
        "button_text_color": Int32(bitPattern: theme.list.itemCheckColors.foregroundColor.rgb),
        "header_bg_color": Int32(bitPattern: theme.rootController.navigationBar.opaqueBackgroundColor.rgb),
        "bottom_bar_bg_color": Int32(bitPattern: theme.rootController.tabBar.backgroundColor.rgb),
        "accent_text_color": Int32(bitPattern: theme.list.itemAccentColor.rgb),
        "section_bg_color": Int32(bitPattern: theme.list.itemBlocksBackgroundColor.rgb),
        "section_header_text_color": Int32(bitPattern: theme.list.freeTextColor.rgb),
        "subtitle_text_color": Int32(bitPattern: theme.list.itemSecondaryTextColor.rgb),
        "destructive_text_color": Int32(bitPattern: theme.list.itemDestructiveColor.rgb),
        "section_separator_color": Int32(bitPattern: theme.list.itemBlocksSeparatorColor.rgb)
    ]
}

public final class WebAppController: ViewController, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = { }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var parentController: () -> ViewController? = {
        return nil
    }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void  = { _, _ in }
    public var updateTabBarVisibility: (Bool, ContainedViewLayoutTransition) -> Void = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    
    static var activeDownloads: [FileDownload] = []
    
    fileprivate class Node: ViewControllerTracingNode, WKNavigationDelegate, WKUIDelegate, WKDownloadDelegate, ASScrollViewDelegate {
        private weak var controller: WebAppController?
        
        private let backgroundNode: ASDisplayNode
        private let headerBackgroundNode: ASDisplayNode
        private let topOverscrollNode: ASDisplayNode
        
        fileprivate var webView: WebAppWebView?
        private var placeholderIcon: (UIImage, Bool)?
        private var placeholderNode: ShimmerEffectNode?
        private var fullscreenControls: ComponentView<Empty>?
            
        fileprivate let loadingProgressPromise = Promise<CGFloat?>(nil)
        
        fileprivate var mainButtonState: AttachmentMainButtonState? {
            didSet {
                self.mainButtonStatePromise.set(.single(self.mainButtonState))
            }
        }
        fileprivate let mainButtonStatePromise = Promise<AttachmentMainButtonState?>(nil)
        
        fileprivate var secondaryButtonState: AttachmentMainButtonState? {
            didSet {
                self.secondaryButtonStatePromise.set(.single(self.secondaryButtonState))
            }
        }
        fileprivate let secondaryButtonStatePromise = Promise<AttachmentMainButtonState?>(nil)
        
        private let context: AccountContext
        var presentationData: PresentationData
        private var queryId: Int64?
        fileprivate let canMinimize = true
        
        private var hasBackButton = false
        
        private var placeholderDisposable = MetaDisposable()
        private var keepAliveDisposable: Disposable?
        private var paymentDisposable: Disposable?
        
        private var iconDisposable: Disposable?
        fileprivate var icon: UIImage?
        
        private var lastExpansionTimestamp: Double?
        
        private var didTransitionIn = false
        private var dismissed = false
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        init(context: AccountContext, controller: WebAppController) {
            self.context = context
            self.controller = controller
            self.presentationData = controller.presentationData
                        
            self.backgroundNode = ASDisplayNode()
            self.headerBackgroundNode = ASDisplayNode()
            self.topOverscrollNode = ASDisplayNode()
                        
            super.init()
                                     
            if self.presentationData.theme.list.plainBackgroundColor.rgb == 0x000000 {
                self.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
            } else {
                self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            }
            
            let webView = WebAppWebView(account: context.account)
            webView.alpha = 0.0
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.scrollView.delegate = self.wrappedScrollViewDelegate
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
            webView.tintColor = self.presentationData.theme.rootController.tabBar.iconColor
            webView.handleScriptMessage = { [weak self] message in
                self?.handleScriptMessage(message)
            }
            webView.onFirstTouch = { [weak self] in
                if let self, !self.delayedScriptMessages.isEmpty {
                    let delayedScriptMessages = self.delayedScriptMessages
                    self.delayedScriptMessages.removeAll()
                    for message in delayedScriptMessages {
                        self.handleScriptMessage(message)
                    }
                }
            }
            if #available(iOS 13.0, *) {
                if self.presentationData.theme.overallDarkAppearance {
                    webView.overrideUserInterfaceStyle = .dark
                } else {
                    webView.overrideUserInterfaceStyle = .unspecified
                }
            }
            self.webView = webView
            
            self.addSubnode(self.backgroundNode)
            self.addSubnode(self.headerBackgroundNode)
            
            let placeholderNode = ShimmerEffectNode()
            placeholderNode.allowsGroupOpacity = true
            self.addSubnode(placeholderNode)
            self.placeholderNode = placeholderNode
            
            let placeholder: Signal<(FileMediaReference, Bool)?, NoError>
            if let botAppSettings = controller.botAppSettings {
                Queue.mainQueue().justDispatch {
                    let backgroundColor: Int32?
                    let headerColor: Int32?
                    if let backgroundDarkColor = botAppSettings.backgroundDarkColor, self.presentationData.theme.overallDarkAppearance {
                        backgroundColor = backgroundDarkColor
                    } else {
                        backgroundColor = botAppSettings.backgroundColor
                    }
                    if let headerDarkColor = botAppSettings.headerDarkColor, self.presentationData.theme.overallDarkAppearance {
                        headerColor = headerDarkColor
                    } else {
                        headerColor = botAppSettings.headerColor
                    }
                    if let backgroundColor {
                        self.appBackgroundColor = UIColor(rgb: UInt32(bitPattern: backgroundColor))
                        self.placeholderBackgroundColor = self.appBackgroundColor
                        self.updateBackgroundColor(transition: .immediate)
                    }
                    if let headerColor {
                        self.headerColor = UIColor(rgb: UInt32(bitPattern: headerColor))
                        self.updateHeaderBackgroundColor(transition: .immediate)
                    }
                }
            }
            if let _ = controller.botAppSettings?.placeholderData {
                placeholder = .single(nil)
            } else if durgerKingBotIds.contains(controller.botId.id._internalGetInt64Value()) {
                placeholder = .single(nil)
                |> delay(0.05, queue: Queue.mainQueue())
            } else {
                placeholder = self.context.engine.messages.getAttachMenuBot(botId: controller.botId, cached: true)
                |> map(Optional.init)
                |> `catch` { error -> Signal<AttachMenuBot?, NoError> in
                    return .single(nil)
                }
                |> mapToSignal { bot -> Signal<(FileMediaReference, Bool)?, NoError> in
                    if let bot = bot, let peerReference = PeerReference(bot.peer._asPeer()) {
                        var imageFile: TelegramMediaFile?
                        var isPlaceholder = false
                        if let file = bot.icons[.placeholder] {
                            imageFile = file
                            isPlaceholder = true
                        } else if let file = bot.icons[.iOSStatic] {
                            imageFile = file
                        } else if let file = bot.icons[.default] {
                            imageFile = file
                        }
                        if let imageFile = imageFile {
                            return .single((.attachBot(peer: peerReference, media: imageFile), isPlaceholder))
                        } else {
                            return .complete()
                        }
                    } else {
                        return .single(nil)
                    }
                }
            }
            
            if let placeholderData = controller.botAppSettings?.placeholderData {
                Queue.mainQueue().justDispatch {
                    let size = CGSize(width: 78.0, height: 78.0)
                    if let image = generateStickerPlaceholderImage(data: placeholderData, size: size, scale: min(2.0, UIScreenScale), imageSize: CGSize(width: 512.0, height: 512.0), backgroundColor: nil, foregroundColor: .white) {
                        self.placeholderIcon = (image.withRenderingMode(.alwaysTemplate), false)
                        if let (layout, navigationBarHeight) = self.validLayout {
                            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                        }
                    }
                }
            } else {
                self.placeholderDisposable.set((placeholder
                |> deliverOnMainQueue).start(next: { [weak self] fileReferenceAndIsPlaceholder in
                    guard let strongSelf = self else {
                        return
                    }
                    let fileReference: FileMediaReference?
                    let isPlaceholder: Bool
                    if let (maybeFileReference, maybeIsPlaceholder) = fileReferenceAndIsPlaceholder {
                        fileReference = maybeFileReference
                        isPlaceholder = maybeIsPlaceholder
                    } else {
                        fileReference = nil
                        isPlaceholder = true
                    }
                    
                    if let fileReference = fileReference {
                        let _ = freeMediaFileInteractiveFetched(account: strongSelf.context.account, userLocation: .other, fileReference: fileReference).start()
                        let _ = (svgIconImageFile(account: strongSelf.context.account, fileReference: fileReference, stickToTop: isPlaceholder)
                        |> deliverOnMainQueue).start(next: { [weak self] transform in
                            if let strongSelf = self {
                                let imageSize: CGSize
                                if isPlaceholder, let (layout, _) = strongSelf.validLayout {
                                    let minSize = min(layout.size.width, layout.size.height)
                                    imageSize = CGSize(width: minSize, height: minSize * 2.0)
                                } else {
                                    imageSize = CGSize(width: 78.0, height: 78.0)
                                }
                                let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                                let drawingContext = transform(arguments)
                                if let image = drawingContext?.generateImage()?.withRenderingMode(.alwaysTemplate) {
                                    strongSelf.placeholderIcon = (image, isPlaceholder)
                                    if let (layout, navigationBarHeight) = strongSelf.validLayout {
                                        strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                                    }
                                }
                                strongSelf.placeholderNode?.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                            }
                        })
                    } else {
                        let image = generateImage(CGSize(width: 78.0, height: 78.0), rotatedContext: { size, context in
                            context.clear(CGRect(origin: .zero, size: size))
                            context.setFillColor(UIColor.white.cgColor)
                            
                            let squareSize = CGSize(width: 36.0, height: 36.0)
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: squareSize), cornerRadius: 5.0).cgPath)
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: size.width - squareSize.width, y: 0.0), size: squareSize), cornerRadius: 5.0).cgPath)
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: 0.0, y: size.height - squareSize.height), size: squareSize), cornerRadius: 5.0).cgPath)
                            context.addPath(UIBezierPath(roundedRect: CGRect(origin: CGPoint(x: size.width - squareSize.width, y: size.height - squareSize.height), size: squareSize), cornerRadius: 5.0).cgPath)
                            context.fillPath()
                        })!
                        strongSelf.placeholderIcon = (image.withRenderingMode(.alwaysTemplate), false)
                        if let (layout, navigationBarHeight) = strongSelf.validLayout {
                            strongSelf.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                        }
                    }
                }))
            }
            
            self.iconDisposable = (context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: controller.botId))
            |> mapToSignal { peer -> Signal<UIImage?, NoError> in
                guard let peer else {
                    return .complete()
                }
                return peerAvatarCompleteImage(account: context.account, peer: peer, size: CGSize(width: 32.0, height: 32.0), round: false)
            }
            |> deliverOnMainQueue).start(next: { [weak self] icon in
                guard let self else {
                    return
                }
                self.icon = icon
            })
        }
        
        deinit {
            self.iconDisposable?.dispose()
            self.placeholderDisposable.dispose()
            self.keepAliveDisposable?.dispose()
            self.paymentDisposable?.dispose()
            
            self.webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
            
            if self.motionManager.isAccelerometerActive {
                self.motionManager.stopAccelerometerUpdates()
            }
            if self.motionManager.isGyroActive {
                self.motionManager.stopGyroUpdates()
            }
        }
        
        override func didLoad() {
            super.didLoad()
            
            self.setupWebView()
            
            guard let webView = self.webView else {
                return
            }
            self.view.addSubview(webView)
            webView.scrollView.insertSubview(self.topOverscrollNode.view, at: 0)
        }
        
        func setupWebView() {
            guard let controller = self.controller else {
                return
            }
            
            if let url = controller.url, controller.source != .menu {
                self.queryId = controller.queryId
                if let parsedUrl = URL(string: url) {
                    self.webView?.load(URLRequest(url: parsedUrl))
                }
                if let keepAliveSignal = controller.keepAliveSignal {
                    self.keepAliveDisposable = (keepAliveSignal
                    |> deliverOnMainQueue).start(error: { [weak self] _ in
                        if let strongSelf = self {
                            strongSelf.controller?.dismiss()
                        }
                    }, completed: { [weak self] in
                        if let strongSelf = self {
                            strongSelf.controller?.dismiss()
                        }
                    })
                }
            } else {
                if controller.source.isSimple {
                    let _ = (self.context.engine.messages.requestSimpleWebView(botId: controller.botId, url: nil, source: .settings, themeParams: generateWebAppThemeParams(presentationData.theme))
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        guard let strongSelf = self else {
                            return
                        }
                        if let parsedUrl = URL(string: result.url) {
                            strongSelf.queryId = result.queryId
                            strongSelf.webView?.load(URLRequest(url: parsedUrl))
                        }
                    })
                } else {
                    if let url = controller.url, isTelegramMeLink(url), let internalUrl = parseFullInternalUrl(sharedContext: self.context.sharedContext, context: self.context, url: url), case .peer(_, .appStart) = internalUrl {
                        let _ = (self.context.sharedContext.resolveUrl(context: self.context, peerId: controller.peerId, url: url, skipUrlAuth: false)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
                            guard let self, let controller = self.controller else {
                                return
                            }
                            guard case let .peer(peer, params) = result, let peer, case let .withBotApp(appStart) = params, let botApp = appStart.botApp else {
                                controller.dismiss()
                                return
                            }
                            let _ = (self.context.engine.messages.requestAppWebView(peerId: peer.id, appReference: .id(id: botApp.id, accessHash: botApp.accessHash), payload: appStart.payload, themeParams: generateWebAppThemeParams(self.presentationData.theme), compact: appStart.mode == .compact, fullscreen: appStart.mode == .fullscreen, allowWrite: true)
                            |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
                                guard let self, let parsedUrl = URL(string: result.url) else {
                                    return
                                }
                                self.controller?.titleView?.title = WebAppTitle(title: botApp.title, counter: self.presentationData.strings.WebApp_Miniapp, isVerified: controller.botVerified)
                                self.webView?.load(URLRequest(url: parsedUrl))
                            })
                        })
                    } else {
                        let _ = (self.context.engine.messages.requestWebView(peerId: controller.peerId, botId: controller.botId, url: controller.url, payload: controller.payload, themeParams: generateWebAppThemeParams(presentationData.theme), fromMenu: controller.source == .menu, replyToMessageId: controller.replyToMessageId, threadId: controller.threadId)
                        |> deliverOnMainQueue).start(next: { [weak self] result in
                            guard let strongSelf = self, let parsedUrl = URL(string: result.url) else {
                                return
                            }
                            strongSelf.queryId = result.queryId
                            strongSelf.webView?.load(URLRequest(url: parsedUrl))
                                                        
                            if let keepAliveSignal = result.keepAliveSignal {
                                strongSelf.keepAliveDisposable = (keepAliveSignal
                                |> deliverOnMainQueue).start(error: { [weak self] _ in
                                    if let strongSelf = self {
                                        strongSelf.controller?.dismiss()
                                    }
                                }, completed: { [weak self] in
                                    if let strongSelf = self {
                                        strongSelf.controller?.completion()
                                        strongSelf.controller?.dismiss()
                                    }
                                })
                            }
                        })
                    }
                }
            }
        }
        
        @objc fileprivate func mainButtonPressed() {
            if let mainButtonState = self.mainButtonState, !mainButtonState.isVisible || !mainButtonState.isEnabled {
                return
            }
            self.webView?.lastTouchTimestamp = CACurrentMediaTime()
            self.webView?.sendEvent(name: "main_button_pressed", data: nil)
        }
        
        @objc fileprivate func secondaryButtonPressed() {
            if let secondaryButtonState = self.secondaryButtonState, !secondaryButtonState.isVisible || !secondaryButtonState.isEnabled {
                return
            }
            self.webView?.lastTouchTimestamp = CACurrentMediaTime()
            self.webView?.sendEvent(name: "secondary_button_pressed", data: nil)
        }
        
        private func updatePlaceholder(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
            var shapes: [ShimmerEffect.ShimmerEffectNode.Shape] = []
            var placeholderSize: CGSize = CGSize()
            
            if let (image, _) = self.placeholderIcon {
                shapes = [.image(image: image, rect: CGRect(origin: CGPoint(), size: image.size))]
                placeholderSize = image.size
            }
            
            let foregroundColor: UIColor
            let shimmeringColor: UIColor
            if let backgroundColor = self.placeholderBackgroundColor {
                if backgroundColor.lightness > 0.705 {
                    foregroundColor = backgroundColor.mixedWith(UIColor(rgb: 0x000000), alpha: 0.05)
                    shimmeringColor = UIColor.white.withAlphaComponent(0.2)
                } else {
                    foregroundColor = backgroundColor.mixedWith(UIColor(rgb: 0xffffff), alpha: 0.05)
                    shimmeringColor = UIColor.white.withAlphaComponent(0.4)
                }
            } else {
                let theme = self.presentationData.theme
                foregroundColor = theme.list.mediaPlaceholderColor
                shimmeringColor = theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4)
            }
            
            self.placeholderNode?.update(backgroundColor: .clear, foregroundColor: foregroundColor, shimmeringColor: shimmeringColor, shapes: shapes, horizontal: true, size: placeholderSize, mask: true)
            
            return placeholderSize
        }
        
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping @MainActor (WKNavigationResponsePolicy) -> Void) {
            if #available(iOS 14.5, *), navigationResponse.response.suggestedFilename?.lowercased().hasSuffix(".pkpass") == true {
                decisionHandler(.download)
            } else {
                decisionHandler(.allow)
            }
        }
        
        private var downloadArguments: (String, String)?
        
        @available(iOS 14.5, *)
        func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        @available(iOS 14.5, *)
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }
        
        @available(iOS 14.5, *)
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            let path = NSTemporaryDirectory() + NSUUID().uuidString
            self.downloadArguments = (path, suggestedFilename)
            completionHandler(URL(fileURLWithPath: path))
        }
        
        @available(iOS 14.5, *)
        func downloadDidFinish(_ download: WKDownload) {
            if let (path, fileName) = self.downloadArguments {
                let tempFile = TempBox.shared.file(path: path, fileName: fileName)
                let url = URL(fileURLWithPath: tempFile.path)
                
                if fileName.hasSuffix(".pkpass") {
                    if let data = try? Data(contentsOf: url), let pass = try? PKPass(data: data) {
                        let passLibrary = PKPassLibrary()
                        if passLibrary.containsPass(pass) {
                            let alertController = textAlertController(context: self.context, updatedPresentationData: nil, title: nil, text: self.presentationData.strings.WebBrowser_PassExistsError, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_OK, action: {})])
                            self.controller?.present(alertController, in: .window(.root))
                        } else if let controller = PKAddPassesViewController(pass: pass) {
                            self.controller?.view.window?.rootViewController?.present(controller, animated: true)
                        }
                    }
                }
                self.downloadArguments = nil
            }
        }
        
        @available(iOS 14.5, *)
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            self.downloadArguments = nil
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                if isTelegramMeLink(url) || isTelegraPhLink(url) {
                    decisionHandler(.cancel)
                    self.controller?.openUrl(url, true, false, {})
                } else {
                    decisionHandler(.allow)
                }
            } else {
                decisionHandler(.allow)
            }
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                self.controller?.openUrl(url.absoluteString, true, false, {})
            }
            return nil
        }
        
        private func animateTransitionIn() {
            guard !self.didTransitionIn, let webView = self.webView else {
                return
            }
            self.didTransitionIn = true
            
            let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear)
            transition.updateAlpha(layer: webView.layer, alpha: 1.0)
            
            self.updateHeaderBackgroundColor(transition: transition)
            
            if let placeholderNode = self.placeholderNode {
                self.placeholderNode = nil
                transition.updateAlpha(node: placeholderNode, alpha: 0.0, completion: { [weak placeholderNode] _ in
                    placeholderNode?.removeFromSupernode()
                })
            }
                        
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
                        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            Queue.mainQueue().after(0.6, {
                self.animateTransitionIn()
            })
        }
        
        @available(iOSApplicationExtension 15.0, iOS 15.0, *)
        func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.prompt)
        }
                
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            var completed = false
            let alertController = textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: nil, text: message, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {
                if !completed {
                    completed = true
                    completionHandler()
                }
            })])
            alertController.dismissed = { byOutsideTap in
                if byOutsideTap {
                    if !completed {
                        completed = true
                        completionHandler()
                    }
                }
            }
            self.controller?.present(alertController, in: .window(.root))
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            var completed = false
            let alertController = textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: nil, text: message, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {
                if !completed {
                    completed = true
                    completionHandler(false)
                }
            }), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {
                if !completed {
                    completed = true
                    completionHandler(true)
                }
            })])
            alertController.dismissed = { byOutsideTap in
                if byOutsideTap {
                    if !completed {
                        completed = true
                        completionHandler(false)
                    }
                }
            }
            self.controller?.present(alertController, in: .window(.root))
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            var completed = false
            let promptController = promptController(sharedContext: self.context.sharedContext, updatedPresentationData: self.controller?.updatedPresentationData, text: prompt, value: defaultText, apply: { value in
                if !completed {
                    completed = true
                    if let value = value {
                        completionHandler(value)
                    } else {
                        completionHandler(nil)
                    }
                }
            })
            promptController.dismissed = { byOutsideTap in
                if byOutsideTap {
                    if !completed {
                        completed = true
                        completionHandler(nil)
                    }
                }
            }
            self.controller?.present(promptController, in: .window(.root))
        }
        
        private func updateNavigationBarAlpha(transition: ContainedViewLayoutTransition) {
            let contentOffset = self.webView?.scrollView.contentOffset.y ?? 0.0
            let backgroundAlpha = min(30.0, contentOffset) / 30.0
            self.controller?.navigationBar?.updateBackgroundAlpha(backgroundAlpha, transition: transition)
        }
        
        private var targetContentOffset: CGPoint?
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            self.updateNavigationBarAlpha(transition: .immediate)
            if let targetContentOffset = self.targetContentOffset, scrollView.contentOffset != targetContentOffset {
                scrollView.contentOffset = targetContentOffset
            }
        }
        
        fileprivate func isContainerPanningUpdated(_ isPanning: Bool) {
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
        
        private var updateWebViewWhenStable = false
                
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let previousLayout = self.validLayout?.0
            self.validLayout = (layout, navigationBarHeight)
            
            guard let controller = self.controller else {
                return
            }
            
            self.updateStatusBarStyle()
            
            controller.navigationBar?.alpha = controller.isFullscreen ? 0.0 : 1.0
            transition.updateAlpha(node: self.headerBackgroundNode, alpha: controller.isFullscreen ? 0.0 : 1.0)
            
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: .zero, size: layout.size))
            transition.updateFrame(node: self.headerBackgroundNode, frame: CGRect(origin: .zero, size: CGSize(width: layout.size.width, height: navigationBarHeight)))
            transition.updateFrame(node: self.topOverscrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -1000.0), size: CGSize(width: layout.size.width, height: 1000.0)))
            
            var contentTopInset: CGFloat = 0.0
            if controller.isFullscreen {
                var added = false
                let fullscreenControls: ComponentView<Empty>
                if let current = self.fullscreenControls {
                    fullscreenControls = current
                } else {
                    fullscreenControls = ComponentView<Empty>()
                    self.fullscreenControls = fullscreenControls
                    added = true
                }
                let controlsMargin: CGFloat = 8.0
                let componentTransition: ComponentTransition = added ? .immediate : ComponentTransition(transition)
                let controlsSize = fullscreenControls.update(
                    transition: componentTransition,
                    component: AnyComponent(
                        FullscreenControlsComponent(
                            context: self.context,
                            strings: self.presentationData.strings,
                            title: controller.botName,
                            isVerified: controller.botVerified,
                            insets: UIEdgeInsets(top: 0.0, left: layout.safeInsets.left, bottom: 0.0, right: layout.safeInsets.right),
                            statusBarStyle: self.fullScreenStatusBarStyle,
                            hasBack: self.hasBackButton,
                            backPressed: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.controller?.cancelPressed()
                            },
                            minimizePressed: { [weak self] in
                                guard let self else {
                                    return
                                }
                                self.controller?.requestMinimize(topEdgeOffset: nil, initialVelocity: nil)
                            },
                            morePressed: { [weak self] node, gesture in
                                guard let self else {
                                    return
                                }
                                self.controller?.morePressed(node: node, gesture: gesture)
                            }
                        )
                    ),
                    environment: {},
                    containerSize: layout.size
                )
                if let view = fullscreenControls.view {
                    if view.superview == nil {
                        self.view.addSubview(view)
                    }
                    transition.updateFrame(view: view, frame: CGRect(origin: CGPoint(x: 0.0, y: (layout.statusBarHeight ?? 0.0) + controlsMargin), size: controlsSize))
                    if added {
                        view.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25)
                    }
                }
                contentTopInset = controlsSize.height + controlsMargin * 2.0
            } else if let fullscreenControls = self.fullscreenControls {
                self.fullscreenControls = nil
                fullscreenControls.view?.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { _ in
                    fullscreenControls.view?.removeFromSuperview()
                })
            }
            
            if let webView = self.webView {
                let inputHeight = self.validLayout?.0.inputHeight ?? 0.0
                
                let intrinsicBottomInset = layout.intrinsicInsets.bottom > 40.0 ? layout.intrinsicInsets.bottom : 0.0
                
                var scrollInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: max(inputHeight, intrinsicBottomInset), right: 0.0)
                var frameBottomInset: CGFloat = 0.0
                if scrollInset.bottom > 40.0 {
                    frameBottomInset = scrollInset.bottom
                    scrollInset.bottom = 0.0
                }
                
                let topInset: CGFloat = controller.isFullscreen ? 0.0 : navigationBarHeight
                
                let webViewFrame = CGRect(origin: CGPoint(x: 0.0, y: topInset), size: CGSize(width: layout.size.width, height: max(1.0, layout.size.height - topInset - frameBottomInset)))
                if !webView.frame.width.isZero && webView.frame != webViewFrame {
                    self.updateWebViewWhenStable = true
                }
                                
                var viewportBottomInset = max(frameBottomInset, scrollInset.bottom)
                if (self.validLayout?.0.inputHeight ?? 0.0) < 44.0 {
                    viewportBottomInset += layout.additionalInsets.bottom
                }
                let viewportFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: topInset), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - topInset - viewportBottomInset)))
                
                if webView.scrollView.contentInset != scrollInset {
                    webView.scrollView.contentInset = scrollInset
                    webView.scrollView.horizontalScrollIndicatorInsets = scrollInset
                    webView.scrollView.verticalScrollIndicatorInsets = scrollInset
                }
                
                if previousLayout != nil && (previousLayout?.inputHeight ?? 0.0).isZero, let inputHeight = layout.inputHeight, inputHeight > 44.0, transition.isAnimated {
                    Queue.mainQueue().after(0.4, {
                        if let inputHeight = self.validLayout?.0.inputHeight, inputHeight > 44.0 {
                            webView.scrollToActiveElement(layout: layout, completion: { [weak self] contentOffset in
                                let _ = self
                            //    self?.targetContentOffset = contentOffset
                            }, transition: transition)
                            
                            transition.updateFrame(view: webView, frame: webViewFrame)
//                            Queue.mainQueue().after(0.1) {
//                                self.targetContentOffset = nil
//                            }
                        }
                    })
                } else {
                    transition.updateFrame(view: webView, frame: webViewFrame)
                }
                
                if let snapshotView = self.fullscreenSwitchSnapshotView {
                    self.fullscreenSwitchSnapshotView = nil
                
                    transition.updatePosition(layer: snapshotView.layer, position: webViewFrame.center)
                    transition.updateTransform(layer: snapshotView.layer, transform: CATransform3DMakeScale(webViewFrame.width / snapshotView.frame.width, webViewFrame.height / snapshotView.frame.height, 1.0))
                    transition.updateAlpha(layer: snapshotView.layer, alpha: 0.0, completion: { _ in
                        snapshotView.removeFromSuperview()
                    })
                }
                
                var customInsets: UIEdgeInsets = .zero
                if controller.isFullscreen {
                    customInsets.top = layout.statusBarHeight ?? 0.0
                }
                if layout.intrinsicInsets.bottom > 44.0 || (layout.inputHeight ?? 0.0) > 0.0 {
                    customInsets.bottom = 0.0
                } else {
                    customInsets.bottom = layout.intrinsicInsets.bottom
                }
                customInsets.left = layout.safeInsets.left
                customInsets.right = layout.safeInsets.left
                webView.customInsets = customInsets
                
                if let controller = self.controller {
                    webView.updateMetrics(height: viewportFrame.height, isExpanded: controller.isContainerExpanded(), isStable: !controller.isContainerPanning(), transition: transition)
                    
                    let data: JSON = [
                        "top": Double(contentTopInset),
                        "bottom": 0.0,
                        "left": 0.0,
                        "right": 0.0
                    ]
                    webView.sendEvent(name: "content_safe_area_changed", data: data.string)
                    
                    if self.updateWebViewWhenStable && !controller.isContainerPanning() {
                        self.updateWebViewWhenStable = false
                        webView.setNeedsLayout()
                    }
                }
            }
            
            if let placeholderNode = self.placeholderNode {
                let height: CGFloat
                if case .compact = layout.metrics.widthClass {
                    height = layout.size.height - layout.additionalInsets.bottom - layout.intrinsicInsets.bottom
                } else {
                    height = layout.size.height - layout.intrinsicInsets.bottom
                }
                
                let placeholderSize = self.updatePlaceholder(layout: layout, navigationBarHeight: navigationBarHeight, transition: transition)
                let placeholderY: CGFloat
                if let (_, isPlaceholder) = self.placeholderIcon, isPlaceholder {
                    placeholderY = navigationBarHeight
                } else {
                    placeholderY = floorToScreenPixels((height - placeholderSize.height) / 2.0)
                }
                let placeholderFrame =  CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - placeholderSize.width) / 2.0), y: placeholderY), size: placeholderSize)
                transition.updateFrame(node: placeholderNode, frame: placeholderFrame)
                placeholderNode.updateAbsoluteRect(placeholderFrame, within: layout.size)
            }
            
            if let previousLayout = previousLayout, (previousLayout.inputHeight ?? 0.0).isZero, let inputHeight = layout.inputHeight, inputHeight > 44.0 {
                Queue.mainQueue().justDispatch {
                    self.controller?.requestAttachmentMenuExpansion()
                }
            }
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "estimatedProgress", let webView = self.webView {
                self.loadingProgressPromise.set(.single(CGFloat(webView.estimatedProgress)))
            }
        }
             
        private let hapticFeedback = HapticFeedback()
        
        private weak var currentQrCodeScannerScreen: QrCodeScanScreen?
        
        func requestLayout(transition: ContainedViewLayoutTransition) {
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
        
        private var delayedScriptMessages: [WKScriptMessage] = []
        private func handleScriptMessage(_ message: WKScriptMessage) {
            guard let controller = self.controller else {
                return
            }
            guard let body = message.body as? [String: Any] else {
                return
            }
            guard let eventName = body["eventName"] as? String else {
                return
            }
            let currentTimestamp = CACurrentMediaTime()
            let eventData = (body["eventData"] as? String)?.data(using: .utf8)
            let json = try? JSONSerialization.jsonObject(with: eventData ?? Data(), options: []) as? [String: Any]
            
            switch eventName {
            case "web_app_ready":
                self.animateTransitionIn()
            case "web_app_switch_inline_query":
                if let json, let query = json["query"] as? String {
                    if let chatTypes = json["chat_types"] as? [String], !chatTypes.isEmpty {
                        var requestPeerTypes: [ReplyMarkupButtonRequestPeerType] = []
                        for type in chatTypes {
                            switch type {
                            case "users":
                                requestPeerTypes.append(.user(ReplyMarkupButtonRequestPeerType.User(isBot: false, isPremium: nil)))
                            case "bots":
                                requestPeerTypes.append(.user(ReplyMarkupButtonRequestPeerType.User(isBot: true, isPremium: nil)))
                            case "groups":
                                requestPeerTypes.append(.group(ReplyMarkupButtonRequestPeerType.Group(isCreator: false, hasUsername: nil, isForum: nil, botParticipant: false, userAdminRights: nil, botAdminRights: nil)))
                            case "channels":
                                requestPeerTypes.append(.channel(ReplyMarkupButtonRequestPeerType.Channel(isCreator: false, hasUsername: nil, userAdminRights: nil, botAdminRights: nil)))
                            default:
                                break
                            }
                        }
                        controller.requestSwitchInline(query, requestPeerTypes, { [weak controller] in
                            controller?.dismiss()
                        })
                    } else {
                        controller.dismiss()
                        controller.requestSwitchInline(query, nil, {})
                    }
                }
            case "web_app_data_send":
                if controller.source.isSimple, let eventData = body["eventData"] as? String {
                    self.handleSendData(data: eventData)
                }
            case "web_app_setup_main_button":
                if let webView = self.webView, !webView.didTouchOnce && controller.url == nil && controller.source == .attachMenu {
                    self.delayedScriptMessages.append(message)
                } else if let json = json {
                    if var isVisible = json["is_visible"] as? Bool {
                        let text = json["text"] as? String
                        if (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            isVisible = false
                        }
                        
                        let backgroundColorString = json["color"] as? String
                        let backgroundColor = backgroundColorString.flatMap({ UIColor(hexString: $0) }) ?? self.presentationData.theme.list.itemCheckColors.fillColor
                        let textColorString = json["text_color"] as? String
                        let textColor = textColorString.flatMap({ UIColor(hexString: $0) }) ?? self.presentationData.theme.list.itemCheckColors.foregroundColor
                        
                        let isLoading = json["is_progress_visible"] as? Bool
                        let isEnabled = json["is_active"] as? Bool
                        let hasShimmer = json["has_shine_effect"] as? Bool
                        let state = AttachmentMainButtonState(text: text, font: .bold, background: .color(backgroundColor), textColor: textColor, isVisible: isVisible, progress: (isLoading ?? false) ? .center : .none, isEnabled: isEnabled ?? true, hasShimmer: hasShimmer ?? false)
                        self.mainButtonState = state
                    }
                }
            case "web_app_setup_secondary_button":
                if let webView = self.webView, !webView.didTouchOnce && controller.url == nil && controller.source == .attachMenu {
                    self.delayedScriptMessages.append(message)
                } else if let json = json {
                    if var isVisible = json["is_visible"] as? Bool {
                        let text = json["text"] as? String
                        if (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            isVisible = false
                        }
                        
                        let backgroundColorString = json["color"] as? String
                        let backgroundColor = backgroundColorString.flatMap({ UIColor(hexString: $0) }) ?? self.presentationData.theme.list.itemCheckColors.fillColor
                        let textColorString = json["text_color"] as? String
                        let textColor = textColorString.flatMap({ UIColor(hexString: $0) }) ?? self.presentationData.theme.list.itemCheckColors.foregroundColor
                        
                        let isLoading = json["is_progress_visible"] as? Bool
                        let isEnabled = json["is_active"] as? Bool
                        let hasShimmer = json["has_shine_effect"] as? Bool
                        let position = json["position"] as? String
                        
                        let state = AttachmentMainButtonState(text: text, font: .bold, background: .color(backgroundColor), textColor: textColor, isVisible: isVisible, progress: (isLoading ?? false) ? .center : .none, isEnabled: isEnabled ?? true, hasShimmer: hasShimmer ?? false, position: position.flatMap { AttachmentMainButtonState.Position(rawValue: $0) })
                        self.secondaryButtonState = state
                    }
                }
            case "web_app_request_viewport":
                self.requestLayout(transition: .immediate)
            case "web_app_request_safe_area":
                self.requestLayout(transition: .immediate)
            case "web_app_request_content_safe_area":
                self.requestLayout(transition: .immediate)
            case "web_app_request_theme":
                self.sendThemeChangedEvent()
            case "web_app_expand":
                if let lastExpansionTimestamp = self.lastExpansionTimestamp, currentTimestamp < lastExpansionTimestamp + 1.0 {
                    
                } else {
                    self.lastExpansionTimestamp = currentTimestamp
                    controller.requestAttachmentMenuExpansion()
                    
                    Queue.mainQueue().after(0.4) {
                        self.webView?.setNeedsLayout()
                    }
                }
            case "web_app_close":
                controller.dismiss()
            case "web_app_open_tg_link":
                if let json = json, let path = json["path_full"] as? String {
                    let forceRequest = json["force_request"] as? Bool ?? false
                    controller.openUrl("https://t.me\(path)", false, forceRequest, {
                    })
                }
            case "web_app_open_invoice":
                if let json = json, let slug = json["slug"] as? String {
                    self.paymentDisposable = (self.context.engine.payments.fetchBotPaymentInvoice(source: .slug(slug))
                    |> map(Optional.init)
                    |> `catch` { _ -> Signal<TelegramMediaInvoice?, NoError> in
                        return .single(nil)
                    }
                    |> deliverOnMainQueue).start(next: { [weak self] invoice in
                        if let strongSelf = self, let invoice, let navigationController = strongSelf.controller?.getNavigationController() {
                            let inputData = Promise<BotCheckoutController.InputData?>()
                            inputData.set(BotCheckoutController.InputData.fetch(context: strongSelf.context, source: .slug(slug))
                            |> map(Optional.init)
                            |> `catch` { _ -> Signal<BotCheckoutController.InputData?, NoError> in
                                return .single(nil)
                            })
                            if invoice.currency == "XTR", let starsContext = strongSelf.context.starsContext {
                                let starsInputData = combineLatest(
                                    inputData.get(),
                                    starsContext.state
                                )
                                |> map { data, state -> (StarsContext.State, BotPaymentForm, EnginePeer?, EnginePeer?)? in
                                    if let data, let state {
                                        return (state, data.form, data.botPeer, nil)
                                    } else {
                                        return nil
                                    }
                                }
                                let _ = (starsInputData |> filter { $0 != nil } |> take(1) |> deliverOnMainQueue).start(next: { _ in
                                    let controller = strongSelf.context.sharedContext.makeStarsTransferScreen(
                                        context: strongSelf.context,
                                        starsContext: starsContext,
                                        invoice: invoice,
                                        source: .slug(slug),
                                        extendedMedia: [],
                                        inputData: starsInputData,
                                        completion: { [weak self] paid in
                                            guard let self else {
                                                return
                                            }
                                            self.sendInvoiceClosedEvent(slug: slug, result: paid ? .paid : .cancelled)
                                        }
                                    )
                                    navigationController.pushViewController(controller)
                                })
                            } else {
                                let checkoutController = BotCheckoutController(context: strongSelf.context, invoice: invoice, source: .slug(slug), inputData: inputData, completed: { currencyValue, receiptMessageId in
                                    self?.sendInvoiceClosedEvent(slug: slug, result: .paid)
                                }, cancelled: { [weak self] in
                                    self?.sendInvoiceClosedEvent(slug: slug, result: .cancelled)
                                }, failed: { [weak self] in
                                    self?.sendInvoiceClosedEvent(slug: slug, result: .failed)
                                })
                                checkoutController.navigationPresentation = .modal
                                navigationController.pushViewController(checkoutController)
                            }
                        }
                    })
                }
            case "web_app_open_link":
                if let json = json, let url = json["url"] as? String {
                    let webAppConfiguration = WebAppConfiguration.with(appConfiguration: self.context.currentAppConfiguration.with { $0 })
                    if let escapedUrl = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed), let url = URL(string: escapedUrl), let scheme = url.scheme?.lowercased(), !["http", "https"].contains(scheme) && !webAppConfiguration.allowedProtocols.contains(scheme) {
                        return
                    }
                    
                    let tryInstantView = json["try_instant_view"] as? Bool ?? false
                    let tryBrowser = json["try_browser"] as? String
                    
                    if let lastTouchTimestamp = self.webView?.lastTouchTimestamp, currentTimestamp < lastTouchTimestamp + 10.0 {
                        self.webView?.lastTouchTimestamp = nil
                        if tryInstantView {
                            let _ = (resolveInstantViewUrl(account: self.context.account, url: url)
                            |> mapToSignal { result -> Signal<ResolvedUrl, NoError> in
                                guard case let .result(result) = result else {
                                    return .complete()
                                }
                                return .single(result)
                            }
                            |> deliverOnMainQueue).start(next: { [weak self] result in
                                guard let strongSelf = self else {
                                    return
                                }
                                switch result {
                                case let .instantView(webPage, anchor):
                                    let controller = strongSelf.context.sharedContext.makeInstantPageController(context: strongSelf.context, webPage: webPage, anchor: anchor, sourceLocation: InstantPageSourceLocation(userLocation: .other, peerType: .otherPrivate))
                                    strongSelf.controller?.getNavigationController()?.pushViewController(controller)
                                default:
                                    strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
                                }
                            })
                        } else {
                            var url = url
                            if let tryBrowser {
                                let openInOptions = availableOpenInOptions(context: self.context, item: .url(url: url))
                                var matchingOption: OpenInOption?
                                for option in openInOptions {
                                    if case .other = option.application {
                                        switch tryBrowser {
                                        case "safari":
                                            break
                                        case "chrome":
                                            if option.identifier == "chrome" {
                                                matchingOption = option
                                                break
                                            }
                                        case "firefox":
                                            if ["firefox", "firefoxFocus"].contains(option.identifier) {
                                                matchingOption = option
                                                break
                                            }
                                        case "opera":
                                            if ["operaMini", "operaTouch"].contains(option.identifier) {
                                                matchingOption = option
                                                break
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                                if let matchingOption, case let .openUrl(newUrl) = matchingOption.action() {
                                    url = newUrl
                                }
                            }

                            self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: url, forceExternal: true, presentationData: self.context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
                        }
                    }
                }
            case "web_app_setup_back_button":
                if let json = json, let isVisible = json["is_visible"] as? Bool {
                    self.hasBackButton = isVisible
                    self.controller?.cancelButtonNode.setState(isVisible ? .back : .cancel, animated: true)
                    if controller.isFullscreen {
                        self.requestLayout(transition: .immediate)
                    }
                }
            case "web_app_trigger_haptic_feedback":
                if let json = json, let type = json["type"] as? String {
                    switch type {
                        case "impact":
                            if let impactType = json["impact_style"] as? String {
                                switch impactType {
                                    case "light":
                                        self.hapticFeedback.impact(.light)
                                    case "medium":
                                        self.hapticFeedback.impact(.medium)
                                    case "heavy":
                                        self.hapticFeedback.impact(.heavy)
                                    case "rigid":
                                        self.hapticFeedback.impact(.rigid)
                                    case "soft":
                                        self.hapticFeedback.impact(.soft)
                                    default:
                                        break
                                }
                            }
                        case "notification":
                            if let notificationType = json["notification_type"] as? String {
                                switch notificationType {
                                    case "success":
                                        self.hapticFeedback.success()
                                    case "error":
                                        self.hapticFeedback.error()
                                    case "warning":
                                        self.hapticFeedback.warning()
                                    default:
                                        break
                                }
                            }
                        case "selection_change":
                            self.hapticFeedback.tap()
                        default:
                            break
                    }
                }
            case "web_app_set_background_color":
                if let json = json, let colorValue = json["color"] as? String, let color = UIColor(hexString: colorValue) {
                    self.appBackgroundColor = color
                    self.updateBackgroundColor(transition: .animated(duration: 0.2, curve: .linear))
                }
            case "web_app_set_header_color":
                if let json = json {
                    if let colorKey = json["color_key"] as? String, ["bg_color", "secondary_bg_color"].contains(colorKey) {
                        self.headerColor = nil
                        self.headerColorKey = colorKey
                    } else if let hexColor = json["color"] as? String, let color = UIColor(hexString: hexColor) {
                        self.headerColor = color
                        self.headerColorKey = nil
                    }
                    self.updateHeaderBackgroundColor(transition: .animated(duration: 0.2, curve: .linear))
                }
            case "web_app_set_bottom_bar_color":
                if let json = json {
                    if let hexColor = json["color"] as? String, let color = UIColor(hexString: hexColor) {
                        self.bottomPanelColor = color
                    }
                }
            case "web_app_open_popup":
                if let json, let message = json["message"] as? String, let buttons = json["buttons"] as? [Any] {
                    let presentationData = self.presentationData
                    
                    let title = json["title"] as? String
                    var alertButtons: [TextAlertAction] = []
                    
                    for buttonJson in buttons.reversed() {
                        if let button = buttonJson as? [String: Any], let id = button["id"] as? String, let type = button["type"] as? String {
                            let buttonAction = {
                                self.sendAlertButtonEvent(id: id)
                            }
                            let text = button["text"] as? String
                            switch type {
                                case "default":
                                    if let text = text {
                                        alertButtons.append(TextAlertAction(type: .genericAction, title: text, action: {
                                            buttonAction()
                                        }))
                                    }
                                case "destructive":
                                    if let text = text {
                                        alertButtons.append(TextAlertAction(type: .destructiveAction, title: text, action: {
                                            buttonAction()
                                        }))
                                    }
                                case "ok":
                                    alertButtons.append(TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {
                                        buttonAction()
                                    }))
                                case "cancel":
                                    alertButtons.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {
                                        buttonAction()
                                    }))
                                case "close":
                                    alertButtons.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Close, action: {
                                        buttonAction()
                                    }))
                                default:
                                    break
                            }
                        }
                    }
                    
                    var actionLayout: TextAlertContentActionLayout = .horizontal
                    if alertButtons.count > 2 {
                        actionLayout = .vertical
                        alertButtons = Array(alertButtons.reversed())
                    }
                    let alertController = textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: title, text: message, actions: alertButtons, actionLayout: actionLayout)
                    alertController.dismissed = { byOutsideTap in
                        if byOutsideTap {
                            self.sendAlertButtonEvent(id: nil)
                        }
                    }
                    self.controller?.present(alertController, in: .window(.root))
                }
            case "web_app_setup_closing_behavior":
                if let json, let needConfirmation = json["need_confirmation"] as? Bool {
                    self.needDismissConfirmation = needConfirmation
                }
            case "web_app_open_scan_qr_popup":
                var info: String = ""
                if let json, let text = json["text"] as? String {
                    info = text
                }
                let controller = QrCodeScanScreen(context: self.context, subject: .custom(info: info))
                controller.completion = { [weak self] result in
                    if let strongSelf = self {
                        if let result = result {
                            strongSelf.sendQrCodeScannedEvent(dataString: result)
                        } else {
                            strongSelf.sendQrCodeScannerClosedEvent()
                        }
                    }
                }
                self.currentQrCodeScannerScreen = controller
                self.controller?.present(controller, in: .window(.root))
            case "web_app_close_scan_qr_popup":
                if let controller = self.currentQrCodeScannerScreen {
                    self.currentQrCodeScannerScreen = nil
                    controller.dismissAnimated()
                }
            case "web_app_read_text_from_clipboard":
                if let json, let requestId = json["req_id"] as? String {
                    let botId = controller.botId
                    let isAttachMenu = controller.url == nil
                    
                    let _ = (self.context.engine.messages.attachMenuBots()
                    |> take(1)
                    |> deliverOnMainQueue).startStandalone(next: { [weak self] attachMenuBots in
                        guard let self else {
                            return
                        }
                        let currentTimestamp = CACurrentMediaTime()
                        var fillData = false
                        
                        let attachMenuBot = attachMenuBots.first(where: { $0.peer.id == botId && !$0.flags.contains(.notActivated) })
                        if isAttachMenu || attachMenuBot != nil {
                            if let lastTouchTimestamp = self.webView?.lastTouchTimestamp, currentTimestamp < lastTouchTimestamp + 10.0 {
                                self.webView?.lastTouchTimestamp = nil
                                fillData = true
                            }
                        }
                        
                        self.sendClipboardTextEvent(requestId: requestId, fillData: fillData)
                    })
                }
            case "web_app_request_write_access":
                self.requestWriteAccess()
            case "web_app_request_phone":
                self.shareAccountContact()
            case "web_app_invoke_custom_method":
                if let json, let requestId = json["req_id"] as? String, let method = json["method"] as? String, let params = json["params"] {
                    var paramsString: String?
                    if let string = params as? String {
                        paramsString = string
                    } else if let data1 = try? JSONSerialization.data(withJSONObject: params, options: []), let convertedString = String(data: data1, encoding: String.Encoding.utf8) {
                        paramsString = convertedString
                    }
                    self.invokeCustomMethod(requestId: requestId, method: method, params: paramsString ?? "{}")
                }
            case "web_app_setup_settings_button":
                if let json, let isVisible = json["is_visible"] as? Bool {
                    self.controller?.hasSettings = isVisible
                }
            case "web_app_biometry_get_info":
                self.sendBiometryInfoReceivedEvent()
            case "web_app_biometry_request_access":
                var reason: String?
                if let json, let reasonValue = json["reason"] as? String, !reasonValue.isEmpty {
                    reason = reasonValue
                }
                self.requestBiometryAccess(reason: reason)
            case "web_app_biometry_request_auth":
                self.requestBiometryAuth()
            case "web_app_biometry_update_token":
                var tokenData: Data?
                if let json, let tokenDataValue = json["token"] as? String, !tokenDataValue.isEmpty {
                    tokenData = tokenDataValue.data(using: .utf8)
                }
                self.requestBiometryUpdateToken(tokenData: tokenData)
            case "web_app_biometry_open_settings":
                if let lastTouchTimestamp = self.webView?.lastTouchTimestamp, currentTimestamp < lastTouchTimestamp + 10.0 {
                    self.webView?.lastTouchTimestamp = nil

                    self.openBotSettings()
                }
            case "web_app_setup_swipe_behavior":
                if let json, let isPanGestureEnabled = json["allow_vertical_swipe"] as? Bool {
                    self.controller?._isPanGestureEnabled = isPanGestureEnabled
                }
            case "web_app_share_to_story":
                if let json, let mediaUrl = json["media_url"] as? String {
                    let text = json["text"] as? String
                    let link = json["widget_link"] as? [String: Any]
                    
                    var linkUrl: String?
                    var linkName: String?
                    if let link {
                        if let url = link["url"] as? String {
                            linkUrl = url
                            if let name = link["name"] as? String {
                                linkName = name
                            }
                        }
                    }
                    
                    enum FetchResult {
                        case result(Data)
                        case progress(Float)
                    }
                    
                    let controller = OverlayStatusController(theme: self.presentationData.theme, type: .loading(cancelled: {
                    }))
                    self.controller?.present(controller, in: .window(.root))
                    
                    let _ = (fetchHttpResource(url: mediaUrl)
                    |> map(Optional.init)
                    |> `catch` { error in
                        return .single(nil)
                    }
                    |> mapToSignal { value -> Signal<FetchResult, NoError> in
                        if case let .dataPart(_, data, _, complete) = value, complete {
                            return .single(.result(data))
                        } else if case let .progressUpdated(progress) = value {
                            return .single(.progress(progress))
                        } else {
                            return .complete()
                        }
                    }
                    |> deliverOnMainQueue).start(next: { [weak self, weak controller] next in
                        guard let self else {
                            return
                        }
                        controller?.dismiss()
                        
                        switch next {
                        case let .result(data):
                            var source: Any?
                            if let image = UIImage(data: data) {
                                source = image
                            } else {
                                let tempFile = TempBox.shared.tempFile(fileName: "image.mp4")
                                if let _ = try? data.write(to: URL(fileURLWithPath: tempFile.path), options: .atomic) {
                                    source = tempFile.path
                                }
                            }
                            if let source {
                                let controller = self.context.sharedContext.makeStoryMediaEditorScreen(context: self.context, source: source, text: text, link: linkUrl.flatMap { ($0, linkName) }, remainingCount: 1, completion: { results, externalState, commit in
                                    let target: Stories.PendingTarget = results.first!.target
                                    externalState.storyTarget = target
                                    
                                    if let rootController = self.context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                                        rootController.proceedWithStoryUpload(target: target, results: results, existingMedia: nil, forwardInfo: nil, externalState: externalState, commit: commit)
                                    }
                                })
                                if let navigationController = self.controller?.getNavigationController() {
                                    navigationController.pushViewController(controller)
                                }
                            }
                        default:
                            break
                        }
                    })
                }
            case "web_app_request_fullscreen":
                self.setIsFullscreen(true)
            case "web_app_exit_fullscreen":
                self.setIsFullscreen(false)
            case "web_app_start_accelerometer":
                if let json {
                    let refreshRate = json["refresh_rate"] as? Double
                    self.setIsAccelerometerActive(true, refreshRate: refreshRate)
                }
            case "web_app_stop_accelerometer":
                self.setIsAccelerometerActive(false)
            case "web_app_start_device_orientation":
                if let json {
                    let refreshRate = json["refresh_rate"] as? Double
                    let absolute = (json["need_absolute"] as? Bool) == true
                    self.setIsDeviceOrientationActive(true, refreshRate: refreshRate, absolute: absolute)
                }
            case "web_app_stop_device_orientation":
                self.setIsDeviceOrientationActive(false)
            case "web_app_start_gyroscope":
                if let json {
                    let refreshRate = json["refresh_rate"] as? Double
                    self.setIsGyroscopeActive(true, refreshRate: refreshRate)
                }
            case "web_app_stop_gyroscope":
                self.setIsGyroscopeActive(false)
            case "web_app_set_emoji_status":
                if let json, let emojiIdString = json["custom_emoji_id"] as? String, let emojiId = Int64(emojiIdString) {
                    let duration = json["duration"] as? Double
                    self.setEmojiStatus(emojiId, duration: duration.flatMap { Int32($0) })
                }
            case "web_app_add_to_home_screen":
                self.addToHomeScreen()
            case "web_app_check_home_screen":
                let data: JSON = ["status": "unknown"]
                self.webView?.sendEvent(name: "home_screen_checked", data: data.string)
            case "web_app_request_location":
                self.requestLocation()
            case "web_app_check_location":
                self.checkLocation()
            case "web_app_open_location_settings":
                if let lastTouchTimestamp = self.webView?.lastTouchTimestamp, currentTimestamp < lastTouchTimestamp + 10.0 {
                    self.webView?.lastTouchTimestamp = nil
                    
                    self.openLocationSettings()
                }
            case "web_app_send_prepared_message":
                if let json, let id = json["id"] as? String {
                    self.sendPreparedMessage(id: id)
                }
            case "web_app_request_emoji_status_access":
                self.requestEmojiStatusAccess()
            case "web_app_request_file_download":
                if let json, let url = json["url"] as? String, let fileName = json["file_name"] as? String {
                    self.downloadFile(url: url, fileName: fileName)
                }
            case "web_app_toggle_orientation_lock":
                if let json, let lock = json["locked"] as? Bool {
                    controller.parentController()?.lockOrientation = lock
                }
            case "web_app_device_storage_save_key":
                if let json, let requestId = json["req_id"] as? String {
                    if let key = json["key"] as? String {
                        let value = json["value"]
                        
                        var effectiveValue: String?
                        if let stringValue = value as? String {
                            effectiveValue = stringValue
                        } else if value is NSNull {
                            effectiveValue = nil
                        } else {
                            let data: JSON = [
                                "req_id": requestId,
                                "error": "VALUE_INVALID"
                            ]
                            self.webView?.sendEvent(name: "device_storage_failed", data: data.string)
                            return
                        }
                        let _ = self.context.engine.peers.setBotStorageValue(peerId: controller.botId, key: key, value: effectiveValue).start(error: { [weak self] error in
                            var errorValue = "UNKNOWN_ERROR"
                            if case .quotaExceeded = error {
                                errorValue = "QUOTA_EXCEEDED"
                            }
                            let data: JSON = [
                                "req_id": requestId,
                                "error": errorValue
                            ]
                            self?.webView?.sendEvent(name: "device_storage_failed", data: data.string)
                        }, completed: { [weak self] in
                            let data: JSON = [
                                "req_id": requestId
                            ]
                            self?.webView?.sendEvent(name: "device_storage_key_saved", data: data.string)
                        })
                    } else {
                        let data: JSON = [
                            "req_id": requestId,
                            "error": "KEY_INVALID"
                        ]
                        self.webView?.sendEvent(name: "device_storage_failed", data: data.string)
                    }
                }
            case "web_app_device_storage_get_key":
                if let json, let requestId = json["req_id"] as? String {
                    if let key = json["key"] as? String {
                        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotStorageValue(id: controller.botId, key: key))
                        |> deliverOnMainQueue).start(next: { [weak self] value in
                            let data: JSON = [
                                "req_id": requestId,
                                "value": value ?? NSNull()
                            ]
                            self?.webView?.sendEvent(name: "device_storage_key_received", data: data.string)
                        })
                    } else {
                        let data: JSON = [
                            "req_id": requestId,
                            "error": "KEY_INVALID"
                        ]
                        self.webView?.sendEvent(name: "device_storage_failed", data: data.string)
                    }
                }
            case "web_app_device_storage_clear":
                if let json, let requestId = json["req_id"] as? String {
                    let _ = (self.context.engine.peers.clearBotStorage(peerId: controller.botId)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        let data: JSON = [
                            "req_id": requestId
                        ]
                        self?.webView?.sendEvent(name: "device_storage_cleared", data: data.string)
                    })
                }
            case "web_app_secure_storage_save_key":
                if let json, let requestId = json["req_id"] as? String {
                    if let key = json["key"] as? String {
                        let value = json["value"]

                        var effectiveValue: String?
                        if let stringValue = value as? String {
                            effectiveValue = stringValue
                        } else if value is NSNull {
                            effectiveValue = nil
                        } else {
                            let data: JSON = [
                                "req_id": requestId,
                                "error": "VALUE_INVALID"
                            ]
                            self.webView?.sendEvent(name: "secure_storage_failed", data: data.string)
                            return
                        }
                        let _ = (WebAppSecureStorage.setValue(context: self.context, botId: controller.botId, key: key, value: effectiveValue)
                        |> deliverOnMainQueue).start(error: { [weak self] error in
                            var errorValue = "UNKNOWN_ERROR"
                            if case .quotaExceeded = error {
                                errorValue = "QUOTA_EXCEEDED"
                            }
                            let data: JSON = [
                                "req_id": requestId,
                                "error": errorValue
                            ]
                            self?.webView?.sendEvent(name: "secure_storage_failed", data: data.string)
                        }, completed: { [weak self] in
                            let data: JSON = [
                                "req_id": requestId
                            ]
                            self?.webView?.sendEvent(name: "secure_storage_key_saved", data: data.string)
                        })
                    } else {
                        let data: JSON = [
                            "req_id": requestId,
                            "error": "KEY_INVALID"
                        ]
                        self.webView?.sendEvent(name: "secure_storage_failed", data: data.string)
                    }
                }
            case "web_app_secure_storage_get_key":
                if let json, let requestId = json["req_id"] as? String {
                    if let key = json["key"] as? String {
                        let _ = (WebAppSecureStorage.getValue(context: self.context, botId: controller.botId, key: key)
                        |> deliverOnMainQueue).start(next: { [weak self] value in
                            let data: JSON = [
                                "req_id": requestId,
                                "value": value ?? NSNull()
                            ]
                            self?.webView?.sendEvent(name: "secure_storage_key_received", data: data.string)
                        }, error: { [weak self] error in
                            if case .canRestore = error {
                                let data: JSON = [
                                    "req_id": requestId,
                                    "value": NSNull(),
                                    "canRestore": true
                                ]
                                self?.webView?.sendEvent(name: "secure_storage_key_received", data: data.string)
                            } else {
                                let data: JSON = [
                                    "req_id": requestId,
                                    "value": NSNull()
                                ]
                                self?.webView?.sendEvent(name: "secure_storage_key_received", data: data.string)
                            }
                        })
                    } else {
                        let data: JSON = [
                            "req_id": requestId,
                            "error": "KEY_INVALID"
                        ]
                        self.webView?.sendEvent(name: "secure_storage_failed", data: data.string)
                    }
                }
            case "web_app_secure_storage_restore_key":
                if let json, let requestId = json["req_id"] as? String {
                    if let key = json["key"] as? String {
                        let _ = (WebAppSecureStorage.checkRestoreAvailability(context: self.context, botId: controller.botId, key: key)
                        |> deliverOnMainQueue).start(next: { [weak self] storedKeys in
                            guard let self else {
                                return
                            }
                            guard !storedKeys.isEmpty else {
                                let data: JSON = [
                                    "req_id": requestId,
                                    "error": "RESTORE_UNAVAILABLE"
                                ]
                                self.webView?.sendEvent(name: "secure_storage_failed", data: data.string)
                                return
                            }
                            self.openSecureBotStorageTransfer(requestId: requestId, key: key, storedKeys: storedKeys)
                        }, error: { [weak self] error in
                            var errorValue = "UNKNOWN_ERROR"
                            if case .storageNotEmpty = error {
                                errorValue = "STORAGE_NOT_EMPTY"
                            }
                            let data: JSON = [
                                "req_id": requestId,
                                "error": errorValue
                            ]
                            self?.webView?.sendEvent(name: "secure_storage_failed", data: data.string)
                        })
                    }
                }
            case "web_app_secure_storage_clear":
                if let json, let requestId = json["req_id"] as? String {
                    let _ = (WebAppSecureStorage.clearStorage(context: self.context, botId: controller.botId)
                    |> deliverOnMainQueue).start(completed: { [weak self] in
                        let data: JSON = [
                            "req_id": requestId
                        ]
                        self?.webView?.sendEvent(name: "secure_storage_cleared", data: data.string)
                    })
                }
            case "web_app_hide_keyboard":
                self.view.window?.endEditing(true)
            default:
                break
            }
        }
        
        fileprivate var needDismissConfirmation = false
        
        fileprivate var fullScreenStatusBarStyle: StatusBarStyle = .White
        fileprivate var appBackgroundColor: UIColor?
        fileprivate var placeholderBackgroundColor: UIColor?
        fileprivate var headerColor: UIColor?
        fileprivate var headerPrimaryTextColor: UIColor?
        private var headerColorKey: String?
        
        fileprivate var bottomPanelColor: UIColor? {
            didSet {
                self.bottomPanelColorPromise.set(.single(self.bottomPanelColor))
            }
        }
        fileprivate let bottomPanelColorPromise = Promise<UIColor?>(nil)
        
        private func updateBackgroundColor(transition: ContainedViewLayoutTransition) {
            transition.updateBackgroundColor(node: self.backgroundNode, color: self.appBackgroundColor ?? .clear)
        }
        
        private func updateHeaderBackgroundColor(transition: ContainedViewLayoutTransition) {
            guard let controller = self.controller else {
                return
            }
            
            let color: UIColor?
            var primaryTextColor: UIColor?
            var secondaryTextColor: UIColor?
            let backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            let secondaryBackgroundColor = self.presentationData.theme.list.blocksBackgroundColor
            if let headerColor = self.headerColor {
                color = headerColor
                let textColor = headerColor.lightness > 0.5 ? UIColor(rgb: 0x000000) : UIColor(rgb: 0xffffff)
                func calculateSecondaryAlpha(luminance: CGFloat, targetContrast: CGFloat) -> CGFloat {
                    let targetLuminance = luminance > 0.5 ? 0.0 : 1.0
                    let adaptiveAlpha = (luminance - targetLuminance + targetContrast) / targetContrast
                    return max(0.5, min(0.64, adaptiveAlpha))
                }
                
                primaryTextColor = textColor
                self.headerPrimaryTextColor = textColor
                secondaryTextColor = textColor.withAlphaComponent(calculateSecondaryAlpha(luminance: headerColor.lightness, targetContrast: 2.5))
            } else if let headerColorKey = self.headerColorKey {
                switch headerColorKey {
                    case "bg_color":
                        color = backgroundColor
                    case "secondary_bg_color":
                        color = secondaryBackgroundColor
                    default:
                        color = nil
                }
            } else {
                color = nil
            }
            
            self.updateNavigationBarAlpha(transition: transition)
            controller.updateNavigationBarTheme(transition: transition)
            
            let statusBarStyle: StatusBarStyle
            if let primaryTextColor {
                if primaryTextColor.lightness < 0.5 {
                    statusBarStyle = .Black
                } else {
                    statusBarStyle = .White
                }
            } else {
                statusBarStyle = .White
            }
            
            if statusBarStyle != self.fullScreenStatusBarStyle {
                self.fullScreenStatusBarStyle = statusBarStyle
                self.updateStatusBarStyle()
                self.requestLayout(transition: .immediate)
            }
            
            controller.titleView?.updateTextColors(primary: primaryTextColor, secondary: secondaryTextColor, transition: transition)
            controller.cancelButtonNode.updateColor(primaryTextColor, transition: transition)
            controller.moreButtonNode.updateColor(primaryTextColor, transition: transition)
            transition.updateBackgroundColor(node: self.headerBackgroundNode, color: color ?? .clear)
            transition.updateBackgroundColor(node: self.topOverscrollNode, color: color ?? .clear)
        }
        
        private func updateStatusBarStyle() {
            guard let controller = self.controller, let parentController = controller.parentController() else {
                return
            }
            if controller.isFullscreen {
                if parentController.statusBar.statusBarStyle != self.fullScreenStatusBarStyle {
                    parentController.setStatusBarStyle(self.fullScreenStatusBarStyle, animated: true)
                }
            } else {
                if parentController.statusBar.statusBarStyle != .Ignore {
                    parentController.setStatusBarStyle(.Ignore, animated: true)
                }
            }
        }
        
        private func handleSendData(data string: String) {
            guard let controller = self.controller, let buttonText = controller.buttonText, !self.dismissed else {
                return
            }
            controller.dismiss()
            
            if let data = string.data(using: .utf8), let jsonArray = try? JSONSerialization.jsonObject(with: data, options : .allowFragments) as? [String: Any], let data = jsonArray["data"] {
                var resultString: String?
                if let string = data as? String {
                    resultString = string
                } else if let data1 = try? JSONSerialization.data(withJSONObject: data, options: []), let convertedString = String(data: data1, encoding: String.Encoding.utf8) {
                    resultString = convertedString
                }
                if let resultString = resultString {
                    self.dismissed = true
                    let _ = (self.context.engine.messages.sendWebViewData(botId: controller.botId, buttonText: buttonText, data: resultString)).start()
                }
            }
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
            
            if self.presentationData.theme.list.plainBackgroundColor.rgb == 0x000000 {
                self.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
            } else {
                self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            }
            self.updateHeaderBackgroundColor(transition: .immediate)
            self.sendThemeChangedEvent()
            
            if #available(iOS 13.0, *) {
                if self.presentationData.theme.overallDarkAppearance {
                    self.webView?.overrideUserInterfaceStyle = .dark
                } else {
                    self.webView?.overrideUserInterfaceStyle = .unspecified
                }
            }
        }
        
        private func sendThemeChangedEvent() {
            let themeParams = generateWebAppThemeParams(self.presentationData.theme)
            var themeParamsString = "{theme_params: {"
            for (key, value) in themeParams {
                if let value = value as? Int32 {
                    let color = UIColor(rgb: UInt32(bitPattern: value))
                    
                    if themeParamsString.count > 16 {
                        themeParamsString.append(", ")
                    }
                    themeParamsString.append("\"\(key)\": \"#\(color.hexString)\"")
                }
            }
            themeParamsString.append("}}")
            self.webView?.sendEvent(name: "theme_changed", data: themeParamsString)
        }
        
        enum InvoiceCloseResult {
            case paid
            case pending
            case cancelled
            case failed
            
            var string: String {
                switch self {
                    case .paid:
                        return "paid"
                    case .pending:
                        return "pending"
                    case .cancelled:
                        return "cancelled"
                    case .failed:
                        return "failed"
                    }
            }
        }
        
        private func sendInvoiceClosedEvent(slug: String, result: InvoiceCloseResult) {
            let data: JSON = [
                "slug": slug,
                "status": result.string
            ]
            self.webView?.sendEvent(name: "invoice_closed", data: data.string)
        }
        
        fileprivate func sendBackButtonEvent() {
            self.webView?.sendEvent(name: "back_button_pressed", data: nil)
        }
        
        fileprivate func sendSettingsButtonEvent() {
            self.webView?.sendEvent(name: "settings_button_pressed", data: nil)
        }
        
        fileprivate func sendAlertButtonEvent(id: String?) {
            var data: [String: Any] = [:]
            if let id {
                data["button_id"] = id
            }
            if let serializedData = JSON(dictionary: data)?.string {
                self.webView?.sendEvent(name: "popup_closed", data: serializedData)
            }
        }
                
        fileprivate func sendQrCodeScannedEvent(dataString: String?) {
            var data: [String: Any] = [:]
            if let dataString {
                data["data"] = dataString
            }
            if let serializedData = JSON(dictionary: data)?.string {
                self.webView?.sendEvent(name: "qr_text_received", data: serializedData)
            }
        }
        
        fileprivate func sendQrCodeScannerClosedEvent() {
            self.webView?.sendEvent(name: "scan_qr_popup_closed", data: nil)
        }
        
        fileprivate func sendClipboardTextEvent(requestId: String, fillData: Bool) {
            var data: [String: Any] = [:]
            data["req_id"] = requestId
            if fillData {
                let pasteboardData = UIPasteboard.general.string ?? ""
                data["data"] = pasteboardData
            }
            if let serializedData = JSON(dictionary: data)?.string {
                self.webView?.sendEvent(name: "clipboard_text_received", data: serializedData)
            }
        }
        
        fileprivate func requestWriteAccess() {
            guard let controller = self.controller, !self.dismissed else {
                return
            }
            
            let sendEvent: (Bool) -> Void = { success in
                let data: JSON = [
                    "status": success ? "allowed" : "cancelled"
                ]
                self.webView?.sendEvent(name: "write_access_requested", data: data.string)
            }
            
            let _ = (self.context.engine.messages.canBotSendMessages(botId: controller.botId)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self, let controller = self.controller else {
                    return
                }
                if result {
                    sendEvent(true)
                } else {
                    let alertController = textAlertController(context: self.context, updatedPresentationData: controller.updatedPresentationData, title: self.presentationData.strings.WebApp_AllowWriteTitle, text: self.presentationData.strings.WebApp_AllowWriteConfirmation(controller.botName).string, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {
                        sendEvent(false)
                    }), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: { [weak self] in
                        guard let self else {
                            return
                        }
                        
                        let _ = (self.context.engine.messages.allowBotSendMessages(botId: controller.botId)
                        |> deliverOnMainQueue).start(completed: {
                            sendEvent(true)
                        })
                    })], parseMarkdown: true)
                    alertController.dismissed = { byOutsideTap in
                        if byOutsideTap {
                            sendEvent(false)
                        }
                    }
                    controller.present(alertController, in: .window(.root))
                }
            })
        }
        
        fileprivate func shareAccountContact() {
            guard let context = self.controller?.context, let botId = self.controller?.botId, let botName = self.controller?.botName else {
                return
            }
            let sendEvent: (Bool) -> Void = { success in
                let data: JSON = [
                    "status": success ? "sent" : "cancelled"
                ]
                self.webView?.sendEvent(name: "phone_requested", data: data.string)
            }
            
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId),
                TelegramEngine.EngineData.Item.Peer.IsBlocked(id: botId)
            )
            |> deliverOnMainQueue).start(next: { [weak self, weak controller] accountPeer, isBlocked in
                guard let self, let controller, let accountPeer else {
                    return
                }
                var requiresUnblock = false
                if case let .known(value) = isBlocked, value {
                    requiresUnblock = true
                }
                
                let text: String
                if requiresUnblock {
                    text = self.presentationData.strings.WebApp_SharePhoneConfirmationUnblock(botName).string
                } else {
                    text = self.presentationData.strings.WebApp_SharePhoneConfirmation(botName).string
                }
                
                let alertController = textAlertController(context: self.context, updatedPresentationData: controller.updatedPresentationData, title: self.presentationData.strings.WebApp_SharePhoneTitle, text: text, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {
                    sendEvent(false)
                }), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: { [weak self] in
                    guard let self, case let .user(user) = accountPeer, let phone = user.phone, !phone.isEmpty else {
                        return
                    }
                    
                    let sendMessageSignal = enqueueMessages(account: self.context.account, peerId: botId, messages: [
                        .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaContact(firstName: user.firstName ?? "", lastName: user.lastName ?? "", phoneNumber: phone, peerId: user.id, vCardData: nil)), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
                    ])
                    |> mapToSignal { messageIds in
                        if let maybeMessageId = messageIds.first, let messageId = maybeMessageId {
                            return context.account.pendingMessageManager.pendingMessageStatus(messageId)
                            |> mapToSignal { status, _ -> Signal<Bool, NoError> in
                                if status != nil {
                                    return .never()
                                } else {
                                    return .single(true)
                                }
                            }
                            |> take(1)
                        } else {
                            return .complete()
                        }
                    }
                    
                    let sendMessage = {
                        let _ = (sendMessageSignal
                        |> deliverOnMainQueue).start(completed: {
                            sendEvent(true)
                        })
                    }
                    
                    if requiresUnblock {
                        let _ = (context.engine.privacy.requestUpdatePeerIsBlocked(peerId: botId, isBlocked: false)
                        |> deliverOnMainQueue).start(completed: {
                            sendMessage()
                        })
                    } else {
                        sendMessage()
                    }
                })], parseMarkdown: true)
                alertController.dismissed = { byOutsideTap in
                    if byOutsideTap {
                        sendEvent(false)
                    }
                }
                controller.present(alertController, in: .window(.root))
            })
        }
        
        fileprivate func invokeCustomMethod(requestId: String, method: String, params: String) {
            guard let controller = self.controller, !self.dismissed else {
                return
            }
            let _ = (self.context.engine.messages.invokeBotCustomMethod(botId: controller.botId, method: method, params: params)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let self else {
                    return
                }
                let paramsString = "{req_id: \"\(requestId)\", result: \(result)}"
                self.webView?.sendEvent(name: "custom_method_invoked", data: paramsString)
            })
        }
        
        fileprivate func sendBiometryInfoReceivedEvent() {
            guard let controller = self.controller else {
                return
            }
            
            self.context.engine.peers.updateBotBiometricsState(peerId: controller.botId, update: { state in
                let state = state ?? TelegramBotBiometricsState.create()
                return state
            })
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.BotBiometricsState(id: controller.botId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                guard let state else {
                    return
                }
                
                var data: [String: Any] = [:]
                if let biometricAuthentication = LocalAuth.biometricAuthentication {
                    data["available"] = true
                    switch biometricAuthentication {
                    case .faceId:
                        data["type"] = "face"
                    case .touchId:
                        data["type"] = "finger"
                    }
                    data["access_requested"] = state.accessRequested
                    data["access_granted"] = state.accessGranted
                    data["token_saved"] = state.opaqueToken != nil
                    data["device_id"] = hexString(state.deviceId)
                } else {
                    data["available"] = false
                }
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
                    return
                }
                guard let jsonDataString = String(data: jsonData, encoding: .utf8) else {
                    return
                }
                self.webView?.sendEvent(name: "biometry_info_received", data: jsonDataString)
            })
        }
        
        fileprivate func requestBiometryAccess(reason: String?) {
            guard let controller = self.controller else {
                return
            }
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: controller.botId),
                TelegramEngine.EngineData.Item.Peer.BotBiometricsState(id: controller.botId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] botPeer, currentState in
                guard let self, let botPeer, let controller = self.controller else {
                    return
                }
                
                if let currentState, currentState.accessRequested {
                    self.sendBiometryInfoReceivedEvent()
                    return
                }
                
                let updateAccessGranted: (Bool) -> Void = { [weak self] granted in
                    guard let self else {
                        return
                    }
                    
                    self.context.engine.peers.updateBotBiometricsState(peerId: botPeer.id, update: { state in
                        var state = state ?? TelegramBotBiometricsState.create()
                        
                        state.accessRequested = true
                        state.accessGranted = granted
                        return state
                    })
                    
                    self.sendBiometryInfoReceivedEvent()
                }
                
                var alertTitle: String?
                let alertText: String
                if let reason {
                    if case .touchId = LocalAuth.biometricAuthentication {
                        alertTitle = self.presentationData.strings.WebApp_AlertBiometryAccessTouchIDText(botPeer.compactDisplayTitle).string
                    } else {
                        alertTitle = self.presentationData.strings.WebApp_AlertBiometryAccessText(botPeer.compactDisplayTitle).string
                    }
                    alertText = reason
                } else {
                    if case .touchId = LocalAuth.biometricAuthentication {
                        alertText = self.presentationData.strings.WebApp_AlertBiometryAccessTouchIDText(botPeer.compactDisplayTitle).string
                    } else {
                        alertText = self.presentationData.strings.WebApp_AlertBiometryAccessText(botPeer.compactDisplayTitle).string
                    }
                }
                controller.present(standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: alertTitle, text: alertText, actions: [
                    TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_No, action: {
                        updateAccessGranted(false)
                    }),
                    TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_Yes, action: {
                        updateAccessGranted(true)
                    })
                ], parseMarkdown: false), in: .window(.root))
            })
        }
        
        fileprivate func requestBiometryAuth() {
            guard let controller = self.controller else {
                return
            }
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: controller.botId),
                TelegramEngine.EngineData.Item.Peer.BotBiometricsState(id: controller.botId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] botPeer, state in
                guard let self else {
                    return
                }
                guard let state else {
                    return
                }
                
                if state.accessRequested && state.accessGranted {
                    guard let controller = self.controller else {
                        return
                    }
                    guard let keyId = "A\(UInt64(bitPattern: self.context.account.id.int64))WebBot\(UInt64(bitPattern: controller.botId.toInt64()))".data(using: .utf8) else {
                        return
                    }
                    let appBundleId = self.context.sharedContext.applicationBindings.appBundleId
                    
                    Thread { [weak self] in
                        let key = LocalAuth.getOrCreatePrivateKey(baseAppBundleId: appBundleId, keyId: keyId)
                        
                        let decryptedData: LocalAuth.DecryptionResult
                        if let key {
                            if let encryptedData = state.opaqueToken {
                                if encryptedData.publicKey == key.publicKeyRepresentation {
                                    decryptedData = key.decrypt(data: encryptedData.data)
                                } else {
                                    // The local keychain has been reset
                                    if let emptyEncryptedData = key.encrypt(data: Data()) {
                                        decryptedData = key.decrypt(data: emptyEncryptedData)
                                    } else {
                                        decryptedData = .error(.generic)
                                    }
                                }
                            } else {
                                if let emptyEncryptedData = key.encrypt(data: Data()) {
                                    decryptedData = key.decrypt(data: emptyEncryptedData)
                                } else {
                                    decryptedData = .error(.generic)
                                }
                            }
                        } else {
                            decryptedData = .error(.generic)
                        }
                        
                        DispatchQueue.main.async {
                            guard let self else {
                                return
                            }
                            
                            switch decryptedData {
                            case let .result(token):
                                self.sendBiometryAuthResult(isAuthorized: true, tokenData: state.opaqueToken != nil ? token : nil)
                            case .error:
                                self.sendBiometryAuthResult(isAuthorized: false, tokenData: nil)
                            }
                        }
                    }.start()
                } else {
                    self.sendBiometryAuthResult(isAuthorized: false, tokenData: nil)
                }
            })
        }
        
        fileprivate func sendBiometryAuthResult(isAuthorized: Bool, tokenData: Data?) {
            var data: [String: Any] = [:]
            data["status"] = isAuthorized ? "authorized" : "failed"
            if isAuthorized {
                if let tokenData {
                    data["token"] = String(data: tokenData, encoding: .utf8) ?? ""
                } else {
                    data["token"] = ""
                }
            }
            
            guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
                return
            }
            guard let jsonDataString = String(data: jsonData, encoding: .utf8) else {
                return
            }
            self.webView?.sendEvent(name: "biometry_auth_requested", data: jsonDataString)
        }
        
        fileprivate func requestBiometryUpdateToken(tokenData: Data?) {
            guard let controller = self.controller else {
                return
            }
            guard let keyId = "A\(UInt64(bitPattern: self.context.account.id.int64))WebBot\(UInt64(bitPattern: controller.botId.toInt64()))".data(using: .utf8) else {
                return
            }
            
            if let tokenData {
                let appBundleId = self.context.sharedContext.applicationBindings.appBundleId
                Thread { [weak self] in
                    let key = LocalAuth.getOrCreatePrivateKey(baseAppBundleId: appBundleId, keyId: keyId)
                    
                    var encryptedData: TelegramBotBiometricsState.OpaqueToken?
                    if let key {
                        if let result = key.encrypt(data: tokenData) {
                            encryptedData = TelegramBotBiometricsState.OpaqueToken(
                                publicKey: key.publicKeyRepresentation,
                                data: result
                            )
                        }
                    }
                    
                    DispatchQueue.main.async {
                        guard let self else {
                            return
                        }
                        
                        if let encryptedData {
                            self.context.engine.peers.updateBotBiometricsState(peerId: controller.botId, update: { state in
                                var state = state ?? TelegramBotBiometricsState.create()
                                state.opaqueToken = encryptedData
                                return state
                            })
                            let data: JSON = [
                                "status": "updated"
                            ]
                            self.webView?.sendEvent(name: "biometry_token_updated", data: data.string)
                        } else {
                            let data: JSON = [
                                "status": "failed"
                            ]
                            self.webView?.sendEvent(name: "biometry_token_updated", data: data.string)
                        }
                    }
                }.start()
            } else {
                self.context.engine.peers.updateBotBiometricsState(peerId: controller.botId, update: { state in
                    var state = state ?? TelegramBotBiometricsState.create()
                    state.opaqueToken = nil
                    return state
                })
                let data: JSON = [
                    "status": "removed"
                ]
                self.webView?.sendEvent(name: "biometry_token_updated", data: data.string)
            }
        }
        
        fileprivate func openBotSettings() {
            guard let controller = self.controller else {
                return
            }
            if let navigationController = controller.getNavigationController() {
                let settingsController = self.context.sharedContext.makeBotSettingsScreen(context: self.context, peerId: controller.botId)
                settingsController.navigationPresentation = .modal
                navigationController.pushViewController(settingsController)
            }
        }
        
        private var fullscreenSwitchSnapshotView: UIView?
        fileprivate func setIsFullscreen(_ isFullscreen: Bool) {
            guard let controller = self.controller else {
                return
            }
            guard controller.isFullscreen != isFullscreen else {
                let data: JSON = [
                    "error": "ALREADY_FULLSCREEN"
                ]
                self.webView?.sendEvent(name: "fullscreen_failed", data: data.string)
                return
            }
            
            let data: JSON = [
                "is_fullscreen": isFullscreen
            ]
            self.webView?.sendEvent(name: "fullscreen_changed", data: data.string)
                        
            controller.isFullscreen = isFullscreen
            if isFullscreen {
                controller.requestAttachmentMenuExpansion()
            }
            
            if let (layout, _) = self.validLayout, case .regular = layout.metrics.widthClass {
                if let snapshotView = self.webView?.snapshotView(afterScreenUpdates: false) {
                    self.webView?.superview?.addSubview(snapshotView)
                    self.fullscreenSwitchSnapshotView = snapshotView
                }
            }
            
            (controller.parentController() as? AttachmentController)?.requestLayout(transition: .animated(duration: 0.4, curve: .spring))
        }
        
        private let motionManager = CMMotionManager()
        private var isAccelerometerActive = false
        fileprivate func setIsAccelerometerActive(_ isActive: Bool, refreshRate: Double? = nil) {
            guard self.motionManager.isAccelerometerAvailable else {
                let data: JSON = [
                    "error": "UNSUPPORTED"
                ]
                self.webView?.sendEvent(name: "accelerometer_failed", data: data.string)
                return
            }
            guard self.isAccelerometerActive != isActive else {
                return
            }
            self.isAccelerometerActive = isActive
            if isActive {
                self.webView?.sendEvent(name: "accelerometer_started", data: nil)
                
                if let refreshRate {
                    self.motionManager.accelerometerUpdateInterval = refreshRate * 0.001
                } else {
                    self.motionManager.accelerometerUpdateInterval = 1.0
                }
                self.motionManager.startAccelerometerUpdates(to: OperationQueue.main) { [weak self] accelerometerData, error in
                    guard let self, let accelerometerData else {
                        return
                    }
                    let gravityConstant: Double = 9.81
                    let data: JSON = [
                        "x": Double(accelerometerData.acceleration.x * gravityConstant),
                        "y": Double(accelerometerData.acceleration.y * gravityConstant),
                        "z": Double(accelerometerData.acceleration.z * gravityConstant)
                    ]
                    self.webView?.sendEvent(name: "accelerometer_changed", data: data.string)
                }
            } else {
                if self.motionManager.isAccelerometerActive {
                    self.motionManager.stopAccelerometerUpdates()
                }
                self.webView?.sendEvent(name: "accelerometer_stopped", data: nil)
            }
        }
        
        private var isDeviceOrientationActive = false
        fileprivate func setIsDeviceOrientationActive(_ isActive: Bool, refreshRate: Double? = nil, absolute: Bool = false) {
            guard self.motionManager.isDeviceMotionAvailable else {
                let data: JSON = [
                    "error": "UNSUPPORTED"
                ]
                self.webView?.sendEvent(name: "device_orientation_failed", data: data.string)
                return
            }
            guard self.isDeviceOrientationActive != isActive else {
                return
            }
            self.isDeviceOrientationActive = isActive
            if isActive {
                self.webView?.sendEvent(name: "device_orientation_started", data: nil)
                
                if let refreshRate {
                    self.motionManager.deviceMotionUpdateInterval = refreshRate * 0.001
                } else {
                    self.motionManager.deviceMotionUpdateInterval = 1.0
                }
                
                var effectiveIsAbsolute = false
                let referenceFrame: CMAttitudeReferenceFrame
                
                if absolute && [.authorizedWhenInUse, .authorizedAlways].contains(CLLocationManager.authorizationStatus()) && CMMotionManager.availableAttitudeReferenceFrames().contains(.xTrueNorthZVertical) {
                    referenceFrame = .xTrueNorthZVertical
                    effectiveIsAbsolute = true
                } else if absolute && CMMotionManager.availableAttitudeReferenceFrames().contains(.xMagneticNorthZVertical) {
                    referenceFrame = .xMagneticNorthZVertical
                    effectiveIsAbsolute = true
                } else {
                    if CMMotionManager.availableAttitudeReferenceFrames().contains(.xArbitraryCorrectedZVertical) {
                        referenceFrame = .xArbitraryCorrectedZVertical
                    } else {
                        referenceFrame = .xArbitraryZVertical
                    }
                    effectiveIsAbsolute = false
                }
                self.motionManager.startDeviceMotionUpdates(using: referenceFrame, to: OperationQueue.main) { [weak self] motionData, error in
                    guard let self, let motionData else {
                        return
                    }
                    var alpha: Double
                    if effectiveIsAbsolute {
                        alpha = motionData.heading * .pi / 180.0
                        if alpha > .pi {
                            alpha -= 2.0 * .pi
                        } else if alpha < -.pi {
                            alpha += 2.0 * .pi
                        }
                    } else {
                        alpha = motionData.attitude.yaw
                    }
                    
                    let data: JSON = [
                        "absolute": effectiveIsAbsolute,
                        "alpha": Double(alpha),
                        "beta": Double(motionData.attitude.pitch),
                        "gamma": Double(motionData.attitude.roll)
                    ]
                    self.webView?.sendEvent(name: "device_orientation_changed", data: data.string)
                }
            } else {
                if self.motionManager.isDeviceMotionActive {
                    self.motionManager.stopDeviceMotionUpdates()
                }
                self.webView?.sendEvent(name: "device_orientation_stopped", data: nil)
            }
        }
        
        private var isGyroscopeActive = false
        fileprivate func setIsGyroscopeActive(_ isActive: Bool, refreshRate: Double? = nil) {
            guard self.motionManager.isGyroAvailable else {
                let data: JSON = [
                    "error": "UNSUPPORTED"
                ]
                self.webView?.sendEvent(name: "gyroscope_failed", data: data.string)
                return
            }
            guard self.isGyroscopeActive != isActive else {
                return
            }
            self.isGyroscopeActive = isActive
            if isActive {
                self.webView?.sendEvent(name: "gyroscope_started", data: nil)
                
                if let refreshRate {
                    self.motionManager.gyroUpdateInterval = refreshRate * 0.001
                } else {
                    self.motionManager.gyroUpdateInterval = 1.0
                }
                self.motionManager.startGyroUpdates(to: OperationQueue.main) { [weak self] gyroData, error in
                    guard let self, let gyroData else {
                        return
                    }
                    let data: JSON = [
                        "x": Double(gyroData.rotationRate.x),
                        "y": Double(gyroData.rotationRate.y),
                        "z": Double(gyroData.rotationRate.z)
                    ]
                    self.webView?.sendEvent(name: "gyroscope_changed", data: data.string)
                }
            } else {
                if self.motionManager.isGyroActive {
                    self.motionManager.stopGyroUpdates()
                }
                self.webView?.sendEvent(name: "gyroscope_stopped", data: nil)
            }
        }
        
        fileprivate func sendPreparedMessage(id: String) {
            guard let controller = self.controller else {
                return
            }
            let _ = (self.context.engine.messages.getPreparedInlineMessage(botId: controller.botId, id: id)
            |> deliverOnMainQueue).start(next: { [weak self, weak controller] preparedMessage in
                guard let self, let controller, let preparedMessage else {
                    let data: JSON = [
                        "error": "MESSAGE_EXPIRED"
                    ]
                    self?.webView?.sendEvent(name: "prepared_message_failed", data: data.string)
                    return
                }
                let previewController = WebAppMessagePreviewScreen(context: controller.context, botName: controller.botName, botAddress: controller.botAddress, preparedMessage: preparedMessage, completion: { [weak self] result in
                    guard let self else {
                        return
                    }
                    if result {
                        self.webView?.sendEvent(name: "prepared_message_sent", data: nil)
                    } else {
                        let data: JSON = [
                            "error": "USER_DECLINED"
                        ]
                        self.webView?.sendEvent(name: "prepared_message_failed", data: data.string)
                    }
                })
                previewController.navigationPresentation = .flatModal
                controller.parentController()?.push(previewController)
            })
        }
        
        fileprivate func downloadFile(url: String, fileName: String) {
            guard let controller = self.controller else {
                return
            }
            
            guard !fileName.contains("/") && fileName.lengthOfBytes(using: .utf8) < 256 && url.lengthOfBytes(using: .utf8) < 32768 else {
                let data: JSON = [
                    "status": "cancelled"
                ]
                self.webView?.sendEvent(name: "file_download_requested", data: data.string)
                return
            }
            
            var isMedia = false
            var title: String?
            let photoExtensions = [".jpg", ".png", ".gif", ".tiff"]
            let videoExtensions = [".mp4", ".mov"]
            let lowercasedFilename = fileName.lowercased()
            for ext in photoExtensions {
                if lowercasedFilename.hasSuffix(ext) {
                    title = self.presentationData.strings.WebApp_Download_Photo
                    isMedia = true
                    break
                }
            }
            if title == nil {
                for ext in videoExtensions {
                    if lowercasedFilename.hasSuffix(ext) {
                        title = self.presentationData.strings.WebApp_Download_Video
                        break
                    }
                }
            }
            if title == nil {
                title = self.presentationData.strings.WebApp_Download_Document
            }
            
            let _ = combineLatest(queue: Queue.mainQueue(),
                FileDownload.getFileSize(url: url),
                self.context.engine.messages.checkBotDownload(botId: controller.botId, fileName: fileName, url: url)
            ).start(next: { [weak self] fileSize, canDownload in
                guard let self else {
                    return
                }
                guard canDownload else {
                    let data: JSON = [
                        "status": "cancelled"
                    ]
                    self.webView?.sendEvent(name: "file_download_requested", data: data.string)
                    return
                }
                var fileSizeString = ""
                if let fileSize {
                    fileSizeString = " (\(dataSizeString(fileSize, formatting: DataSizeStringFormatting(presentationData: self.presentationData))))"
                }
                
                let text: String = self.presentationData.strings.WebApp_Download_Text(controller.botName, fileName, fileSizeString).string
                let alertController = standardTextAlertController(theme: AlertControllerTheme(presentationData: self.presentationData), title: title, text: text, actions: [
                    TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: { [weak self] in
                        let data: JSON = [
                            "status": "cancelled"
                        ]
                        self?.webView?.sendEvent(name: "file_download_requested", data: data.string)
                    }),
                    TextAlertAction(type: .defaultAction, title: self.presentationData.strings.WebApp_Download_Download, action: { [weak self] in
                        self?.startDownload(url: url, fileName: fileName, fileSize: fileSize, isMedia: isMedia)
                    })
                ], parseMarkdown: true)
                alertController.dismissed = { [weak self] byOutsideTap in
                    let data: JSON = [
                        "status": "cancelled"
                    ]
                    self?.webView?.sendEvent(name: "file_download_requested", data: data.string)
                }
                controller.present(alertController, in: .window(.root))
            })
        }
        
        fileprivate weak var fileDownloadTooltip: UndoOverlayController?
        fileprivate func startDownload(url: String, fileName: String, fileSize: Int64?, isMedia: Bool) {
            guard let controller = self.controller else {
                return
            }
            let data: JSON = [
                "status": "downloading"
            ]
            self.webView?.sendEvent(name: "file_download_requested", data: data.string)
            
            var removeImpl: (() -> Void)?
            let fileDownload = FileDownload(
                from: URL(string: url)!,
                fileName: fileName,
                fileSize: fileSize,
                isMedia: isMedia,
                progressHandler: { [weak self] progress in
                    guard let self else {
                        return
                    }
                    let text: String
                    if let fileSize {
                        let downloadedSize = Int64(Double(fileSize) * progress)
                        text = "\(dataSizeString(downloadedSize, formatting: DataSizeStringFormatting(presentationData: self.presentationData))) / \(dataSizeString(fileSize, formatting: DataSizeStringFormatting(presentationData: self.presentationData)))"
                    } else {
                        text = "\(Int32(progress))%"
                    }
                    
                    self.fileDownloadTooltip?.content = .progress(
                        progress: progress,
                        title: fileName,
                        text: text,
                        undoText: self.presentationData.strings.WebApp_Download_Cancel
                    )
                },
                completion: { [weak self] resultUrl, _ in
                    if let resultUrl, let self {
                        removeImpl?()
                        
                        let tooltipContent: UndoOverlayContent = .actionSucceeded(title: fileName, text: isMedia ? self.presentationData.strings.WebApp_Download_SavedToPhotos : self.presentationData.strings.WebApp_Download_SavedToFiles, cancel: nil, destructive: false)
                        if isMedia {
                            let saveToPhotos: (URL, Bool) -> Void = { url, isVideo in
                                var fileExtension = (resultUrl.absoluteString as NSString).pathExtension
                                if fileExtension.isEmpty {
                                    fileExtension = "mp4"
                                }
                                PHPhotoLibrary.shared().performChanges({
                                    if isVideo {
                                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                                    } else {
                                        if let fileData = try? Data(contentsOf: url) {
                                            PHAssetCreationRequest.forAsset().addResource(with: .photo, data: fileData, options: nil)
                                        }
                                    }
                                }, completionHandler: { _, error in
                                })
                            }
                            let isVideo = fileName.lowercased().hasSuffix(".mp4") || fileName.lowercased().hasSuffix(".mov")
                            saveToPhotos(resultUrl, isVideo)
                                               
                            if let tooltip = self.fileDownloadTooltip {
                                tooltip.content = tooltipContent
                            } else {
                                let tooltipController = UndoOverlayController(
                                    presentationData: self.presentationData,
                                    content: tooltipContent,
                                    elevatedLayout: false,
                                    position: .top,
                                    action: { _ in
                                        return true
                                    }
                                )
                                controller.present(tooltipController, in: .current)
                            }
                        } else {
                            if let tooltip = self.fileDownloadTooltip {
                                tooltip.dismissWithCommitAction()
                            }
                            
                            let tempFile = TempBox.shared.file(path: resultUrl.absoluteString, fileName: fileName)
                            let url = URL(fileURLWithPath: tempFile.path)
                            try? FileManager.default.copyItem(at: resultUrl, to: url)
                            
                            let pickerController = legacyICloudFilePicker(theme: self.presentationData.theme, mode: .export, url: url, documentTypes: [], forceDarkTheme: false, dismissed: {}, completion: { [weak self, weak controller] urls in
                                guard let self, let controller, !urls.isEmpty else {
                                    return
                                }
                                let tooltipController = UndoOverlayController(
                                    presentationData: self.presentationData,
                                    content: tooltipContent,
                                    elevatedLayout: false,
                                    position: .top,
                                    action: { _ in
                                        return true
                                    }
                                )
                                controller.present(tooltipController, in: .current)
                            })
                            controller.present(pickerController, in: .window(.root))
                        }
                    }
                }
            )
            WebAppController.activeDownloads.append(fileDownload)
            
            removeImpl = { [weak fileDownload] in
                if let fileDownload {
                    WebAppController.activeDownloads.removeAll(where: { $0 === fileDownload })
                }
            }
            
            let text: String
            if let fileSize {
                text = "0 KB / \(dataSizeString(fileSize, formatting: DataSizeStringFormatting(presentationData: self.presentationData)))"
            } else {
                text = "0%"
            }
            
            let tooltipController = UndoOverlayController(
                presentationData: self.presentationData,
                content: .progress(
                    progress: 0.0,
                    title: fileName,
                    text: text,
                    undoText: self.presentationData.strings.WebApp_Download_Cancel
                ),
                elevatedLayout: false,
                position: .top,
                action: { [weak fileDownload] action in
                    if case .undo = action, let fileDownload {
                        fileDownload.cancel()
                        removeImpl?()
                    }
                    return true
                }
            )
            controller.present(tooltipController, in: .current)
            self.fileDownloadTooltip = tooltipController
        }
        
        fileprivate func requestEmojiStatusAccess() {
            guard let controller = self.controller else {
                return
            }
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId)),
                self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: controller.botId)),
                self.context.engine.stickers.loadedStickerPack(reference: .iconStatusEmoji, forceActualized: false)
                |> map { result -> [TelegramMediaFile.Accessor] in
                    switch result {
                    case let .result(_, items, _):
                        return items.map(\.file)
                    default:
                        return []
                    }
                }
                |> take(1)
            ).start(next: { [weak self] accountPeer, botPeer, iconStatusEmoji in
                guard let self, let accountPeer, let controller = self.controller else {
                    return
                }
                let alertController = webAppEmojiStatusAlertController(
                    context: self.context,
                    accountPeer: accountPeer,
                    botName: controller.botName,
                    icons: iconStatusEmoji,
                    completion: { [weak self] result in
                        guard let self, let controller = self.controller else {
                            return
                        }
                        let context = self.context
                        let botId = controller.botId
                        if result {
                            if !context.isPremium {
                                var replaceImpl: ((ViewController) -> Void)?
                                let demoController = context.sharedContext.makePremiumDemoController(context: context, subject: .emojiStatus, forceDark: false, action: {
                                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .animatedEmoji, forceDark: false, dismissed: nil)
                                    replaceImpl?(controller)
                                }, dismissed: nil)
                                replaceImpl = { [weak demoController] c in
                                    demoController?.replace(with: c)
                                }
                                controller.parentController()?.push(demoController)
                                
                                let data: JSON = [
                                    "status": "cancelled"
                                ]
                                self.webView?.sendEvent(name: "emoji_status_access_requested", data: data.string)
                                return
                            }
                            
                            let _ = (context.engine.peers.toggleBotEmojiStatusAccess(peerId: botId, enabled: true)
                            |> deliverOnMainQueue).startStandalone(completed: { [weak self] in
                                let data: JSON = [
                                    "status": "allowed"
                                ]
                                self?.webView?.sendEvent(name: "emoji_status_access_requested", data: data.string)
                            })

                            if let botPeer {
                                let resultController = UndoOverlayController(
                                    presentationData: self.presentationData,
                                    content: .invitedToVoiceChat(context: self.context, peer: botPeer, title: nil, text: self.presentationData.strings.WebApp_EmojiPermission_Succeed(controller.botName).string, action: self.presentationData.strings.WebApp_EmojiPermission_Undo, duration: 5.0),
                                    elevatedLayout: true,
                                    action: { action in
                                        if case .undo = action {
                                            let _ = (context.engine.peers.toggleBotEmojiStatusAccess(peerId: botId, enabled: false)
                                            |> deliverOnMainQueue).startStandalone()
                                        }
                                        return true
                                    }
                                )
                                controller.present(resultController, in: .window(.root))
                            }
                        } else {
                            let data: JSON = [
                                "status": "cancelled"
                            ]
                            self.webView?.sendEvent(name: "emoji_status_access_requested", data: data.string)
                        }
                        
                        let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: botId) { current in
                            return WebAppPermissionsState(location: current?.location, emojiStatus: WebAppPermissionsState.EmojiStatus(isRequested: true))
                        }.startStandalone()
                    }
                )
                alertController.dismissed = { [weak self] byOutsideTap in
                    let data: JSON = [
                        "status": "cancelled"
                    ]
                    self?.webView?.sendEvent(name: "emoji_status_access_requested", data: data.string)
                }
                controller.present(alertController, in: .window(.root))
            })
        }
        
        fileprivate func setEmojiStatus(_ fileId: Int64, duration: Int32? = nil) {
            guard let controller = self.controller else {
                return
            }
            let _ = combineLatest(
                queue: Queue.mainQueue(),
                self.context.engine.stickers.resolveInlineStickers(fileIds: [fileId]),
                self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId)),
                self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: controller.botId))
            ).start(next: { [weak self] files, accountPeer, botPeer in
                guard let self, let accountPeer, let controller = self.controller else {
                    return
                }
                guard let file = files[fileId] else {
                    let data: JSON = [
                        "error": "SUGGESTED_EMOJI_INVALID"
                    ]
                    self.webView?.sendEvent(name: "emoji_status_failed", data: data.string)
                    return
                }
                let confirmController = WebAppSetEmojiStatusScreen(
                    context: self.context,
                    botName: controller.botName,
                    accountPeer: accountPeer,
                    file: file,
                    duration: duration,
                    completion: { [weak self, weak controller] result in
                        guard let self else {
                            return
                        }
                        if result, let controller {
                            let context = self.context
                            if !context.isPremium {
                                var replaceImpl: ((ViewController) -> Void)?
                                let demoController = context.sharedContext.makePremiumDemoController(context: context, subject: .emojiStatus, forceDark: false, action: {
                                    let controller = context.sharedContext.makePremiumIntroController(context: context, source: .animatedEmoji, forceDark: false, dismissed: nil)
                                    replaceImpl?(controller)
                                }, dismissed: nil)
                                replaceImpl = { [weak demoController] c in
                                    demoController?.replace(with: c)
                                }
                                controller.parentController()?.push(demoController)
                                
                                let data: JSON = [
                                    "error": "USER_DECLINED"
                                ]
                                self.webView?.sendEvent(name: "emoji_status_failed", data: data.string)
                                return
                            }
                            
                            var expirationDate: Int32?
                            if let duration {
                                expirationDate = Int32(CFAbsoluteTimeGetCurrent() + NSTimeIntervalSince1970) + duration
                            }
                            let _ = (self.context.engine.accountData.setEmojiStatus(file: file, expirationDate: expirationDate)
                            |> deliverOnMainQueue).start(completed: { [weak self] in
                                self?.webView?.sendEvent(name: "emoji_status_set", data: nil)
                            })
                            let text: String
                            if let duration {
                                let durationString = scheduledTimeIntervalString(strings: self.presentationData.strings, value: duration)
                                text = self.presentationData.strings.WebApp_Emoji_DurationSucceed(durationString).string
                            } else {
                                text = self.presentationData.strings.WebApp_Emoji_Succeed
                            }
                            let resultController = UndoOverlayController(
                                presentationData: self.presentationData,
                                content: .sticker(context: context, file: file, loop: false, title: nil, text: text, undoText: nil, customAction: nil),
                                elevatedLayout: true,
                                action: { action in
                                    if case .undo = action {
                                        
                                    }
                                    return true
                                }
                            )
                            controller.present(resultController, in: .window(.root))
                        } else {
                            let data: JSON = [
                                "error": "USER_DECLINED"
                            ]
                            self.webView?.sendEvent(name: "emoji_status_failed", data: data.string)
                        }
                    }
                )
                controller.parentController()?.push(confirmController)
            })
        }
        
        fileprivate func addToHomeScreen() {
            guard let controller = self.controller else {
                return
            }
            
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: controller.botId))
            |> deliverOnMainQueue
            ).start(next: { [weak controller] peer in
                guard let controller, let peer, let addressName = peer.addressName else {
                    return
                }
                var appName: String = ""
                if let name = controller.appName {
                    appName = "/\(name)"
                }
                let scheme: String
                if #available(iOS 18.0, *) {
                    scheme = "x-safari-https"
                } else {
                    scheme = "https"
                }
                let url = URL(string: "\(scheme)://t.me/\(addressName)\(appName)?startapp&addToHomeScreen")!
                UIApplication.shared.open(url)
            })
        }
        
        fileprivate func openSecureBotStorageTransfer(requestId: String, key: String, storedKeys: [WebAppSecureStorage.ExistingKey]) {
            guard let controller = self.controller else {
                return
            }
            
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: controller.botId))
            |> deliverOnMainQueue).start(next: { [weak self] botPeer in
                guard let self, let botPeer, let controller = self.controller else {
                    return
                }
                let transferController = WebAppSecureStorageTransferScreen(
                    context: self.context,
                    peer: botPeer,
                    existingKeys: storedKeys,
                    completion: { [weak self] uuid in
                        guard let self else {
                            return
                        }
                        guard let uuid else {
                            let data: JSON = [
                                "req_id": requestId,
                                "error": "RESTORE_CANCELLED"
                            ]
                            self.webView?.sendEvent(name: "secure_storage_failed", data: data.string)
                            return
                        }
                        
                        let _ = (WebAppSecureStorage.transferAllValues(context: self.context, fromUuid: uuid, botId: controller.botId)
                        |> deliverOnMainQueue).start(completed: { [weak self] in
                            guard let self else {
                                return
                            }
                            let _ = (WebAppSecureStorage.getValue(context: self.context, botId: controller.botId, key: key)
                            |> deliverOnMainQueue).start(next: { [weak self] value in
                                let data: JSON = [
                                    "req_id": requestId,
                                    "value": value ?? NSNull()
                                ]
                                self?.webView?.sendEvent(name: "secure_storage_key_restored", data: data.string)
                            })
                        })
                    }
                )
                controller.parentController()?.push(transferController)
            })
        }
        
        fileprivate func openLocationSettings() {
            guard let controller = self.controller else {
                return
            }
            let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: controller.botId))
            |> deliverOnMainQueue).start(next: { [weak self] peer in
                guard let self, let controller = self.controller, let peer else {
                    return
                }
                if let infoController = self.context.sharedContext.makePeerInfoController(context: self.context, updatedPresentationData: nil, peer: peer._asPeer(), mode: .generic, avatarInitiallyExpanded: false, fromChat: false, requestsContext: nil) {
                    controller.parentController()?.push(infoController)
                }
            })
        }
        
        fileprivate func checkLocation() {
            guard let controller = self.controller else {
                return
            }
            let _ = (webAppPermissionsState(context: self.context, peerId: controller.botId)
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] state in
                guard let self else {
                    return
                }
                var data: [String: Any] = [:]
                data["available"] = true
                if let location = state?.location {
                    data["access_requested"] = location.isRequested
                    if location.isRequested {
                        data["access_granted"] = location.isAllowed
                    }
                } else {
                    data["access_requested"] = false
                }
                if let serializedData = JSON(dictionary: data)?.string {
                    self.webView?.sendEvent(name: "location_checked", data: serializedData)
                }
            })
        }
        
        private let locationManager = LocationManager()
        fileprivate func requestLocation() {
            let context = self.context
            DeviceAccess.authorizeAccess(to: .location(.send), locationManager: self.locationManager, presentationData: self.presentationData, present: { [weak self] c, a in
                self?.controller?.present(c, in: .window(.root), with: a)
            }, openSettings: {
                context.sharedContext.applicationBindings.openSettings()
            }, { [weak self, weak controller] authorized in
                guard let controller, authorized else {
                    return
                }
                let context = controller.context
                let botId = controller.botId
                let _ = (webAppPermissionsState(context: context, peerId: botId)
                |> take(1)
                |> deliverOnMainQueue).start(next: { [weak self, weak controller] state in
                    guard let self else {
                        return
                    }
                    
                    var shouldRequest = false
                    if let location = state?.location {
                        if location.isRequested {
                            if location.isAllowed {
                                let locationCoordinates = Signal<CLLocation, NoError> { subscriber in
                                    return context.sharedContext.locationManager!.push(mode: DeviceLocationMode.preciseForeground, updated: { location, _ in
                                        subscriber.putNext(location)
                                        subscriber.putCompletion()
                                    })
                                } |> deliverOnMainQueue
                                let _ = locationCoordinates.startStandalone(next: { location in
                                    var data: [String: Any] = [:]
                                    data["available"] = true
                                    data["latitude"] = location.coordinate.latitude
                                    data["longitude"] = location.coordinate.longitude
                                    data["altitude"] = location.altitude
                                    data["course"] = location.course
                                    data["speed"] = location.speed
                                    data["horizontal_accuracy"] = location.horizontalAccuracy
                                    data["vertical_accuracy"] = location.verticalAccuracy
                                    if #available(iOS 13.4, *) {
                                        data["course_accuracy"] = location.courseAccuracy
                                    } else {
                                        data["course_accuracy"] = NSNull()
                                    }
                                    data["speed_accuracy"] = location.speedAccuracy
                                    if let serializedData = JSON(dictionary: data)?.string {
                                        self.webView?.sendEvent(name: "location_requested", data: serializedData)
                                    }
                                })
                            } else {
                                var data: [String: Any] = [:]
                                data["available"] = false
                                self.webView?.sendEvent(name: "location_requested", data: JSON(dictionary: data)?.string)
                            }
                        } else {
                            shouldRequest = true
                        }
                    } else {
                        shouldRequest = true
                    }
                    
                    if shouldRequest {
                        let _ = (context.engine.data.get(
                            TelegramEngine.EngineData.Item.Peer.Peer(id: context.account.peerId),
                            TelegramEngine.EngineData.Item.Peer.Peer(id: botId)
                        )
                        |> deliverOnMainQueue).start(next: { [weak self, weak controller] accountPeer, botPeer in
                            guard let accountPeer, let botPeer, let controller else {
                                return
                            }
                            let alertController = webAppLocationAlertController(
                                context: controller.context,
                                accountPeer: accountPeer,
                                botPeer: botPeer,
                                completion: { [weak self, weak controller] result in
                                    guard let self, let controller else {
                                        return
                                    }
                                    if result {
                                        let resultController = UndoOverlayController(
                                            presentationData: self.presentationData,
                                            content: .invitedToVoiceChat(context: context, peer: botPeer, title: nil, text: self.presentationData.strings.WebApp_LocationPermission_Succeed(botPeer.compactDisplayTitle).string, action: self.presentationData.strings.WebApp_LocationPermission_Undo, duration: 5.0),
                                            elevatedLayout: true,
                                            action: { action in
                                                if case .undo = action {
                                                    
                                                }
                                                return true
                                            }
                                        )
                                        controller.present(resultController, in: .window(.root))
                                        
                                        Queue.mainQueue().after(0.1, {
                                            self.requestLocation()
                                        })
                                    } else {
                                        var data: [String: Any] = [:]
                                        data["available"] = false
                                        self.webView?.sendEvent(name: "location_requested", data: JSON(dictionary: data)?.string)
                                    }
                                    let _ = updateWebAppPermissionsStateInteractively(context: context, peerId: botId) { current in
                                        return WebAppPermissionsState(location: WebAppPermissionsState.Location(isRequested: true, isAllowed: result), emojiStatus: current?.emojiStatus)
                                    }.start()
                                }
                            )
                            controller.present(alertController, in: .window(.root))
                        })
                    }
                })
            })
        }
    }
    
    fileprivate var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var titleView: WebAppTitleView?
    fileprivate let cancelButtonNode: WebAppCancelButtonNode
    fileprivate let moreButtonNode: MoreButtonNode
    
    private let context: AccountContext
    public let source: WebAppParameters.Source
    private let peerId: PeerId
    public let botId: PeerId
    fileprivate let botName: String
    fileprivate let botVerified: Bool
    fileprivate let botAppSettings: BotAppSettings?
    fileprivate let botAddress: String
    fileprivate let appName: String?
    private let url: String?
    private let queryId: Int64?
    private let payload: String?
    private let buttonText: String?
    private let forceHasSettings: Bool
    private let keepAliveSignal: Signal<Never, KeepWebViewError>?
    private let replyToMessageId: MessageId?
    private let threadId: Int64?
    public var isFullscreen: Bool
    
    private var presentationData: PresentationData
    fileprivate let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private var presentationDataDisposable: Disposable?
    
    private var hasSettings = false
    
    public var openUrl: (String, Bool, Bool, @escaping () -> Void) -> Void = { _, _, _, _ in }
    public var getNavigationController: () -> NavigationController? = { return nil }
    public var completion: () -> Void = {}
    public var requestSwitchInline: (String, [ReplyMarkupButtonRequestPeerType]?, @escaping () -> Void) -> Void = { _, _, _ in }
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, params: WebAppParameters, replyToMessageId: MessageId?, threadId: Int64?) {
        self.context = context
        self.source = params.source
        self.peerId = params.peerId
        self.botId = params.botId
        self.botName = params.botName
        self.botVerified = params.botVerified
        self.botAppSettings = params.appSettings
        self.botAddress = params.botAddress
        self.appName = params.appName
        self.url = params.url
        self.queryId = params.queryId
        self.payload = params.payload
        self.buttonText = params.buttonText
        self.forceHasSettings = params.forceHasSettings
        self.keepAliveSignal = params.keepAliveSignal
        self.replyToMessageId = replyToMessageId
        self.threadId = threadId
        self.isFullscreen = params.isFullscreen
        
        self.updatedPresentationData = updatedPresentationData
        
        var presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        let updatedTheme = presentationData.theme.withModalBlocksBackground()
        presentationData = presentationData.withUpdated(theme: updatedTheme)
        self.presentationData = presentationData
        
        self.cancelButtonNode = WebAppCancelButtonNode(theme: self.presentationData.theme, strings: self.presentationData.strings)
        
        self.moreButtonNode = MoreButtonNode(theme: self.presentationData.theme)
        self.moreButtonNode.iconNode.enqueueState(.more, animated: false)
        
        let navigationBarPresentationData = NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme), strings: NavigationBarStrings(back: "", close: ""))
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.automaticallyControlPresentationContextLayout = false
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customDisplayNode: self.cancelButtonNode)
        self.navigationItem.leftBarButtonItem?.action = #selector(self.cancelPressed)
        self.navigationItem.leftBarButtonItem?.target = self
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: self.moreButtonNode)
        self.navigationItem.rightBarButtonItem?.action = #selector(self.moreButtonPressed)
        self.navigationItem.rightBarButtonItem?.target = self
        
        self.navigationItem.backBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Back, style: .plain, target: nil, action: nil)
        
        let titleView = WebAppTitleView(context: self.context, theme: self.presentationData.theme)
        titleView.title = WebAppTitle(title: params.botName, counter: self.presentationData.strings.WebApp_Miniapp, isVerified: params.botVerified)
        self.navigationItem.titleView = titleView
        self.titleView = titleView
        
        self.moreButtonNode.action = { [weak self] _, gesture in
            if let strongSelf = self {
                strongSelf.morePressed(node: strongSelf.moreButtonNode.contextSourceNode, gesture: gesture)
            }
        }
        
        self.presentationDataDisposable = ((updatedPresentationData?.signal ?? context.sharedContext.presentationData)
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self {
                let updatedTheme = presentationData.theme.withModalBlocksBackground()
                let presentationData = presentationData.withUpdated(theme: updatedTheme)
                strongSelf.presentationData = presentationData
                
                strongSelf.updateNavigationBarTheme(transition: .immediate)
                strongSelf.titleView?.theme = presentationData.theme

                strongSelf.cancelButtonNode.theme = presentationData.theme
                strongSelf.moreButtonNode.theme = presentationData.theme
                
                if strongSelf.isNodeLoaded {
                    strongSelf.controllerNode.updatePresentationData(presentationData)
                }
            }
        })
        
        self.longTapWithTabBar = { [weak self] in
            guard let self else {
                return
            }
            
            let _ = (context.engine.messages.attachMenuBots()
            |> take(1)
            |> deliverOnMainQueue).start(next: { [weak self] attachMenuBots in
                guard let self else {
                    return
                }
                let attachMenuBot = attachMenuBots.first(where: { $0.peer.id == self.botId && !$0.flags.contains(.notActivated) })
                if let _ = attachMenuBot, [.attachMenu, .settings, .generic].contains(self.source) {
                    self.removeAttachBot()
                }
            })
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        assert(true)
        self.presentationDataDisposable?.dispose()
    }
    
    public func beforeMaximize(navigationController: NavigationController, completion: @escaping () -> Void) {
        switch self.source {
        case .generic, .settings:
            completion()
        case .button, .inline, .attachMenu, .menu, .simple:
            let _ = (self.context.engine.data.get(
                TelegramEngine.EngineData.Item.Peer.Peer(id: self.peerId)
            )
            |> deliverOnMainQueue).start(next: { [weak self] chatPeer in
                guard let self, let chatPeer else {
                    return
                }
                self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(chatPeer), keepStack: .always, completion: { _ in
                }))
                completion()
            })
        }
    }
    
    fileprivate func updateNavigationBarTheme(transition: ContainedViewLayoutTransition) {
        let navigationBarPresentationData: NavigationBarPresentationData
        if let backgroundColor = self.controllerNode.headerColor, let textColor = self.controllerNode.headerPrimaryTextColor {
            navigationBarPresentationData = NavigationBarPresentationData(
                theme: NavigationBarTheme(
                    buttonColor: textColor,
                    disabledButtonColor: textColor,
                    primaryTextColor: textColor,
                    backgroundColor: backgroundColor,
                    enableBackgroundBlur: true,
                    separatorColor: UIColor(rgb: 0x000000, alpha: 0.25),
                    badgeBackgroundColor: .clear,
                    badgeStrokeColor: .clear,
                    badgeTextColor: .clear
                ),
                strings: NavigationBarStrings(back: "", close: "")
            )
        } else {
            navigationBarPresentationData = NavigationBarPresentationData(
                theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme),
                strings: NavigationBarStrings(back: "", close: "")
            )
        }
        self.navigationBar?.updatePresentationData(navigationBarPresentationData)
    }
    
    @objc fileprivate func cancelPressed() {
        if case .back = self.cancelButtonNode.state {
            self.controllerNode.sendBackButtonEvent()
        } else {
            self.requestDismiss {
                self.dismiss()
            }
        }
    }
    
    @objc fileprivate func moreButtonPressed() {
        self.moreButtonNode.buttonPressed()
    }
    
    @objc fileprivate func morePressed(node: ASDisplayNode, gesture: ContextGesture?) {
        guard let node = node as? ContextReferenceContentNode else {
            return
        }
        let context = self.context
        var presentationData = self.presentationData
        if !presentationData.theme.overallDarkAppearance, let headerColor = self.controllerNode.headerColor {
            if headerColor.lightness < 0.5 {
                presentationData = presentationData.withUpdated(theme: defaultDarkPresentationTheme)
            }
        }
        
        let peerId = self.peerId
        let botId = self.botId
        
        let source = self.source
        
        let hasSettings = self.hasSettings
        
        let activeDownload = WebAppController.activeDownloads.first
        let activeDownloadProgress: Signal<Double?, NoError>
        if let activeDownload {
            activeDownloadProgress = activeDownload.progressSignal
            |> map(Optional.init)
            |> mapToThrottled { next -> Signal<Double?, NoError> in
                return .single(next) |> then(.complete() |> delay(0.2, queue: Queue.mainQueue()))
            }
        } else {
            activeDownloadProgress = .single(nil)
        }
        
        let items = combineLatest(queue: Queue.mainQueue(),
            context.engine.messages.attachMenuBots() |> take(1),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.botId)),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotCommands(id: self.botId)),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotPrivacyPolicyUrl(id: self.botId)),
            activeDownloadProgress
        )
        |> map { [weak self] attachMenuBots, botPeer, botCommands, privacyPolicyUrl, activeDownloadProgress -> ContextController.Items in
            var items: [ContextMenuItem] = []
            
            if let activeDownload, let progress = activeDownloadProgress {
                let isActive = progress < 1.0 - .ulpOfOne
                let progressString: String
                if isActive {
                    if let fileSize = activeDownload.fileSize {
                        let downloadedSize = Int64(Double(fileSize) * progress)
                        progressString = "\(dataSizeString(downloadedSize, formatting: DataSizeStringFormatting(presentationData: presentationData))) / \(dataSizeString(fileSize, formatting: DataSizeStringFormatting(presentationData: presentationData)))"
                    } else {
                        progressString = "\(Int32(progress))%"
                    }
                } else {
                    progressString = activeDownload.isMedia ? presentationData.strings.WebApp_Download_SavedToPhotos : presentationData.strings.WebApp_Download_SavedToFiles
                }
                items.append(.action(ContextMenuActionItem(text: activeDownload.fileName, textLayout: .secondLineWithValue(progressString), icon: { theme in return isActive ? generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Clear"), color: theme.contextMenu.primaryColor) : nil }, iconPosition: .right, action: isActive ? { [weak self, weak activeDownload] _, f in
                    f(.default)
                    
                    WebAppController.activeDownloads.removeAll(where: { $0 === activeDownload })
                    activeDownload?.cancel()
                    
                    if let fileDownloadTooltip = self?.controllerNode.fileDownloadTooltip {
                        fileDownloadTooltip.dismissWithCommitAction()
                    }
                } : nil)))
                items.append(.separator)
            }
            
            let attachMenuBot = attachMenuBots.first(where: { $0.peer.id == botId && !$0.flags.contains(.notActivated) })
            if hasSettings {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_Settings, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Settings"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    
                    if let strongSelf = self {
                        strongSelf.controllerNode.sendSettingsButtonEvent()
                    }
                })))
            }
            
            if peerId != botId {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_OpenBot, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    
                    guard let strongSelf = self else {
                        return
                    }
                    
                    let _ = (context.engine.data.get(
                        TelegramEngine.EngineData.Item.Peer.Peer(id: strongSelf.botId)
                    )
                    |> deliverOnMainQueue).start(next: { botPeer in
                        guard let botPeer = botPeer else {
                            return
                        }
                        if let strongSelf = self, let navigationController = strongSelf.getNavigationController() {
                            (strongSelf.parentController() as? AttachmentController)?.minimizeIfNeeded()
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(botPeer)))
                        }
                    })
                })))
            }
            
            if let addressName = botPeer?.addressName {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_Share, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Forward"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    
                    guard let self else {
                        return
                    }
                    let shareController = ShareController(context: context, subject: .url("https://t.me/\(addressName)?profile"))
                    shareController.actionCompleted = { [weak self] in
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(title: nil, text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
                    }
                    self.present(shareController, in: .window(.root))
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_ReloadPage, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reload"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(completion: nil)
                
                self?.controllerNode.webView?.reload()
            })))
            
            if let _ = self?.appName {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_AddToHomeScreen, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/AddSquare"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    
                    self?.controllerNode.addToHomeScreen()
                })))
            }
                        
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_TermsOfUse, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Info"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(completion: nil)
                
                guard let self, let navigationController = self.getNavigationController() else {
                    return
                }
                
                let context = self.context
                let _ = (cachedWebAppTermsPage(context: context)
                |> deliverOnMainQueue).startStandalone(next: { resolvedUrl in
                    context.sharedContext.openResolvedUrl(resolvedUrl, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: true, forceUpdate: false, openPeer: { peer, navigation in
                    }, sendFile: nil, sendSticker: nil, sendEmoji: nil, requestMessageActionUrlAuth: nil, joinVoiceChat: nil, present: { [weak self] c, arguments in
                        self?.push(c)
                    }, dismissInput: {}, contentContext: nil, progress: nil, completion: nil)
                })
            })))
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_PrivacyPolicy, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Privacy"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                c?.dismiss(completion: nil)
                
                guard let self else {
                    return
                }
                
                (self.parentController() as? AttachmentController)?.minimizeIfNeeded()
                if let privacyPolicyUrl {
                    self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: privacyPolicyUrl, forceExternal: false, presentationData: self.presentationData, navigationController: self.getNavigationController(), dismissInput: {})
                } else if let botCommands, botCommands.contains(where: { $0.text == "privacy" }) {
                    let _ = enqueueMessages(account: self.context.account, peerId: self.botId, messages: [.message(text: "/privacy", attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])]).startStandalone()
                    
                    if let botPeer, let navigationController = self.getNavigationController() {
                        self.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: self.context, chatLocation: .peer(botPeer)))
                    }
                } else {
                    self.context.sharedContext.openExternalUrl(context: self.context, urlContext: .generic, url: self.presentationData.strings.WebApp_PrivacyPolicy_URL, forceExternal: false, presentationData: self.presentationData, navigationController: self.getNavigationController(), dismissInput: {})
                }
            })))
                        
            if let _ = attachMenuBot, [.attachMenu, .settings, .generic].contains(source) {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_RemoveBot, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                }, action: { [weak self] c, _ in
                    c?.dismiss(completion: nil)
                    
                    if let self {
                        self.removeAttachBot()
                    }
                })))
            }
            
            return ContextController.Items(content: .list(items))
        }
        
        let contextController = ContextController(presentationData: presentationData, source: .reference(WebAppContextReferenceContentSource(controller: self, sourceNode: node)), items: items, gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }
    
    private func removeAttachBot() {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        self.present(textAlertController(context: context, title: presentationData.strings.WebApp_RemoveConfirmationTitle, text: presentationData.strings.WebApp_RemoveAllConfirmationText(self.botName).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: { [weak self] in
            guard let self else {
                return
            }
            let _ = self.context.engine.messages.removeBotFromAttachMenu(botId: self.botId).start()
            self.dismiss()
        })], parseMarkdown: true), in: .window(.root))
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self)
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        self.updateTabBarAlpha(1.0, .immediate)
    }
    
    public func isContainerPanningUpdated(_ isPanning: Bool) {
        self.controllerNode.isContainerPanningUpdated(isPanning)
    }
     
    private var validLayout: ContainerViewLayout?
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
        super.containerLayoutUpdated(layout, transition: transition)
        
        var presentationLayout = layout
        if self.isFullscreen {
            presentationLayout.intrinsicInsets.top = (presentationLayout.statusBarHeight ?? 0.0) + 36.0
        } else {
            presentationLayout.intrinsicInsets.top = 56.0
        }
        self.presentationContext.containerLayoutUpdated(presentationLayout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    override public var presentationController: UIPresentationController? {
        get {
            return nil
        } set(value) {
        }
    }
    
    public var mediaPickerContext: AttachmentMediaPickerContext? {
        return WebAppPickerContext(controller: self)
    }
    
    public func prepareForReuse() {
        self.updateTabBarAlpha(1.0, .immediate)
    }
    
    public func refresh() {
        self.controllerNode.setupWebView()
    }
    
    public func requestDismiss(completion: @escaping () -> Void) {
        if self.controllerNode.needDismissConfirmation {
            let actionSheet = ActionSheetController(presentationData: self.presentationData)
            actionSheet.setItemGroups([
                ActionSheetItemGroup(items: [
                    ActionSheetTextItem(title: self.presentationData.strings.WebApp_CloseConfirmation),
                    ActionSheetButtonItem(title: self.presentationData.strings.WebApp_CloseAnyway, color: .destructive, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                        
                        completion()
                    })
                ]),
                ActionSheetItemGroup(items: [
                    ActionSheetButtonItem(title: self.presentationData.strings.Common_Cancel, color: .accent, font: .bold, action: { [weak actionSheet] in
                        actionSheet?.dismissAnimated()
                    })
                ])
            ])
            self.present(actionSheet, in: .window(.root))
        } else {
            completion()
        }
    }
    
    public var isMinimized: Bool = false {
        didSet {
            if self.isMinimized != oldValue {
                if self.isMinimized {
                    self.controllerNode.webView?.hideScrollIndicators()
                } else {
                    self.requestLayout(transition: .immediate)
                    self.controllerNode.webView?.setNeedsLayout()
                }
                
                let data: JSON = [
                    "is_visible": !self.isMinimized,
                ]
                self.controllerNode.webView?.sendEvent(name: "visibility_changed", data: data.string)
            }
        }
    }
    
    public var isMinimizable: Bool {
        return true
    }
    
    public func requestMinimize(topEdgeOffset: CGFloat?, initialVelocity: CGFloat?) {
        (self.parentController() as? AttachmentController)?.requestMinimize(topEdgeOffset: topEdgeOffset, initialVelocity: initialVelocity)
    }
    
    public func shouldDismissImmediately() -> Bool {
        if self.controllerNode.needDismissConfirmation {
            return false
        } else {
            return true
        }
    }
    
    fileprivate var _isPanGestureEnabled = true
    public var isInnerPanGestureEnabled: (() -> Bool)? {
        return { [weak self] in
            guard let self else {
                return true
            }
            return self._isPanGestureEnabled
        }
    }
    
    fileprivate var canMinimize: Bool {
        return self.controllerNode.canMinimize
    }
    
    public var minimizedIcon: UIImage? {
        return self.controllerNode.icon
    }
    
    public func makeContentSnapshotView() -> UIView? {
        guard let webView = self.controllerNode.webView, let _ = self.validLayout else {
            return nil
        }
        
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: webView.frame.size)

        let imageView = UIImageView()
        imageView.frame = CGRect(origin: .zero, size: webView.frame.size)
        webView.takeSnapshot(with: configuration, completionHandler: { image, _ in
            imageView.image = image
        })
        return imageView
    }
}

final class WebAppPickerContext: AttachmentMediaPickerContext {
    private weak var controller: WebAppController?
    
    public var loadingProgress: Signal<CGFloat?, NoError> {
        return self.controller?.controllerNode.loadingProgressPromise.get() ?? .single(nil)
    }
    
    public var mainButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return self.controller?.controllerNode.mainButtonStatePromise.get() ?? .single(nil)
    }
    
    public var secondaryButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return self.controller?.controllerNode.secondaryButtonStatePromise.get() ?? .single(nil)
    }
        
    public var bottomPanelBackgroundColor: Signal<UIColor?, NoError> {
        return self.controller?.controllerNode.bottomPanelColorPromise.get() ?? .single(nil)
    }
    
    init(controller: WebAppController) {
        self.controller = controller
    }
    
    func mainButtonAction() {
        self.controller?.controllerNode.mainButtonPressed()
    }
    
    func secondaryButtonAction() {
        self.controller?.controllerNode.secondaryButtonPressed()
    }
}


private final class WebAppContextReferenceContentSource: ContextReferenceContentSource {
    private let controller: ViewController
    private let sourceNode: ContextReferenceContentNode
    
    init(controller: ViewController, sourceNode: ContextReferenceContentNode) {
        self.controller = controller
        self.sourceNode = sourceNode
    }
    
    func transitionInfo() -> ContextControllerReferenceViewInfo? {
        return ContextControllerReferenceViewInfo(referenceView: self.sourceNode.view, contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

public func standaloneWebAppController(
    context: AccountContext,
    updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil,
    params: WebAppParameters,
    threadId: Int64?,
    openUrl: @escaping (String, Bool, Bool, @escaping () -> Void) -> Void,
    requestSwitchInline: @escaping (String, [ReplyMarkupButtonRequestPeerType]?, @escaping () -> Void) -> Void = { _, _, _ in },
    getInputContainerNode: @escaping () -> (CGFloat, ASDisplayNode, () -> AttachmentController.InputPanelTransition?)? = { return nil },
    completion: @escaping () -> Void = {},
    willDismiss: @escaping () -> Void = {},
    didDismiss: @escaping () -> Void = {},
    getNavigationController: @escaping () -> NavigationController? = { return nil },
    getSourceRect: (() -> CGRect?)? = nil
) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: .peer(id: params.peerId), buttons: [.standalone], initialButton: .standalone, fromMenu: params.source == .menu, hasTextInput: false, isFullSize: params.fullSize, makeEntityInputView: {
        return nil
    })
    controller.requestController = { _, present in
        let webAppController = WebAppController(context: context, updatedPresentationData: updatedPresentationData, params: params, replyToMessageId: nil, threadId: threadId)
        webAppController.openUrl = openUrl
        webAppController.completion = completion
        webAppController.getNavigationController = getNavigationController
        webAppController.requestSwitchInline = requestSwitchInline
        present(webAppController, webAppController.mediaPickerContext)
    }
    controller.willDismiss = willDismiss
    controller.didDismiss = didDismiss
    controller.getSourceRect = getSourceRect
    controller.title = params.botName
    controller.shouldMinimizeOnSwipe = { [weak controller] _ in
        if let controller, let mainController = controller.mainController as? WebAppController {
            return mainController.canMinimize
        }
        return false
    }
    return controller
}

private struct WebAppConfiguration {
    static var defaultValue: WebAppConfiguration {
        return WebAppConfiguration(allowedProtocols: [])
    }
    
    let allowedProtocols: [String]
    
    fileprivate init(allowedProtocols: [String]) {
        self.allowedProtocols = allowedProtocols
    }
    
    static func with(appConfiguration: AppConfiguration) -> WebAppConfiguration {
        if let data = appConfiguration.data {
            var allowedProtocols: [String] = []
            if let value = data["web_app_allowed_protocols"] as? [String] {
                allowedProtocols = value
            }
            return WebAppConfiguration(allowedProtocols: allowedProtocols)
        } else {
            return .defaultValue
        }
    }
}
