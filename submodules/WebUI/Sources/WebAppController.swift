import Foundation
import UIKit
@preconcurrency import WebKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AttachmentUI
import ContextUI
import PresentationDataUtils
import HexColor
import ShimmerEffect
import PhotoResources
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
    let url: String?
    let queryId: Int64?
    let payload: String?
    let buttonText: String?
    let keepAliveSignal: Signal<Never, KeepWebViewError>?
    let forceHasSettings: Bool
    let fullSize: Bool
    
    public init(
        source: Source,
        peerId: PeerId,
        botId: PeerId,
        botName: String,
        botVerified: Bool,
        url: String?,
        queryId: Int64?,
        payload: String?,
        buttonText: String?,
        keepAliveSignal: Signal<Never, KeepWebViewError>?,
        forceHasSettings: Bool,
        fullSize: Bool
    ) {
        self.source = source
        self.peerId = peerId
        self.botId = botId
        self.botName = botName
        self.botVerified = botVerified
        self.url = url
        self.queryId = queryId
        self.payload = payload
        self.buttonText = buttonText
        self.keepAliveSignal = keepAliveSignal
        self.forceHasSettings = forceHasSettings
        self.fullSize = fullSize
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
    
    fileprivate class Node: ViewControllerTracingNode, WKNavigationDelegate, WKUIDelegate, ASScrollViewDelegate {
        private weak var controller: WebAppController?
        
        private let backgroundNode: ASDisplayNode
        private let headerBackgroundNode: ASDisplayNode
        private let topOverscrollNode: ASDisplayNode
        
        fileprivate var webView: WebAppWebView?
        private var placeholderIcon: (UIImage, Bool)?
        private var placeholderNode: ShimmerEffectNode?
            
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
            if durgerKingBotIds.contains(controller.botId.id._internalGetInt64Value()) {
                placeholder = .single(nil)
                |> delay(0.05, queue: Queue.mainQueue())
            } else {
                placeholder = self.context.engine.messages.getAttachMenuBot(botId: controller.botId, cached: true)
                |> map(Optional.init)
                |> `catch` { error -> Signal<AttachMenuBot?, NoError> in
                    return .complete()
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
                        return .complete()
                    }
                }
            }
            
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
                }
                strongSelf.placeholderDisposable.set((svgIconImageFile(account: strongSelf.context.account, fileReference: fileReference, stickToTop: isPlaceholder)
                |> deliverOnMainQueue).start(next: { [weak self] transform in
                    if let strongSelf = self {
                        let imageSize: CGSize
                        if isPlaceholder, let (layout, _) = strongSelf.validLayout {
                            let minSize = min(layout.size.width, layout.size.height)
                            imageSize = CGSize(width: minSize, height: minSize * 2.0)
                        } else {
                            imageSize = CGSize(width: 75.0, height: 75.0)
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
                }))
            }))
            
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
                    if let url = controller.url, isTelegramMeLink(url), let internalUrl = parseFullInternalUrl(sharedContext: self.context.sharedContext, url: url), case .peer(_, .appStart) = internalUrl {
                        let _ = (self.context.sharedContext.resolveUrl(context: self.context, peerId: controller.peerId, url: url, skipUrlAuth: false)
                        |> deliverOnMainQueue).startStandalone(next: { [weak self] result in
                            guard let self, let controller = self.controller else {
                                return
                            }
                            guard case let .peer(peer, params) = result, let peer, case let .withBotApp(appStart) = params, let botApp = appStart.botApp else {
                                controller.dismiss()
                                return
                            }
                            let _ = (self.context.engine.messages.requestAppWebView(peerId: peer.id, appReference: .id(id: botApp.id, accessHash: botApp.accessHash), payload: appStart.payload, themeParams: generateWebAppThemeParams(self.presentationData.theme), compact: appStart.compact, allowWrite: true)
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
         
            let theme = self.presentationData.theme
            self.placeholderNode?.update(backgroundColor: .clear, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, horizontal: true, size: placeholderSize, mask: true)
            
            return placeholderSize
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                if isTelegramMeLink(url) || isTelegraPhLink(url) {
                    decisionHandler(.cancel)
                    self.controller?.openUrl(url, true, {})
                } else {
                    decisionHandler(.allow)
                }
            } else {
                decisionHandler(.allow)
            }
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                self.controller?.openUrl(url.absoluteString, true, {})
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
                
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let previousLayout = self.validLayout?.0
            self.validLayout = (layout, navigationBarHeight)
                        
            transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: .zero, size: layout.size))
            transition.updateFrame(node: self.headerBackgroundNode, frame: CGRect(origin: .zero, size: CGSize(width: layout.size.width, height: navigationBarHeight)))
            transition.updateFrame(node: self.topOverscrollNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -1000.0), size: CGSize(width: layout.size.width, height: 1000.0)))
            
            if let webView = self.webView {
                var scrollInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: layout.intrinsicInsets.bottom, right: 0.0)
                var frameBottomInset: CGFloat = 0.0
                if scrollInset.bottom > 40.0 {
                    frameBottomInset = scrollInset.bottom
                    scrollInset.bottom = 0.0
                }
                
                let frame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: navigationBarHeight), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - navigationBarHeight - frameBottomInset)))
                
                var bottomInset = layout.intrinsicInsets.bottom + layout.additionalInsets.bottom
                if let inputHeight = self.validLayout?.0.inputHeight, inputHeight > 44.0 {
                    bottomInset = max(bottomInset, inputHeight)
                }
                let viewportFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: navigationBarHeight), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - navigationBarHeight - bottomInset)))
                
                if webView.scrollView.contentInset != scrollInset {
                    webView.scrollView.contentInset = scrollInset
                    webView.scrollView.scrollIndicatorInsets = scrollInset
                }
                
                if previousLayout != nil && (previousLayout?.inputHeight ?? 0.0).isZero, let inputHeight = layout.inputHeight, inputHeight > 44.0, transition.isAnimated {
                    webView.scrollToActiveElement(layout: layout, completion: { [weak self] contentOffset in
                        self?.targetContentOffset = contentOffset
                    }, transition: transition)
                    Queue.mainQueue().after(0.4, {
                        if let inputHeight = self.validLayout?.0.inputHeight, inputHeight > 44.0 {
                            transition.updateFrame(view: webView, frame: frame)
                            Queue.mainQueue().after(0.1) {
                                self.targetContentOffset = nil
                            }
                        }
                    })
                } else {
                    transition.updateFrame(view: webView, frame: frame)
                }
                
                if let controller = self.controller {
                    webView.updateMetrics(height: viewportFrame.height, isExpanded: controller.isContainerExpanded(), isStable: !controller.isContainerPanning(), transition: transition)
                }
                
                webView.customBottomInset = layout.intrinsicInsets.bottom
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
                    if let (layout, navigationBarHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    }
                case "web_app_request_theme":
                    self.sendThemeChangedEvent()
                case "web_app_expand":
                    if let lastExpansionTimestamp = self.lastExpansionTimestamp, currentTimestamp < lastExpansionTimestamp + 1.0 {
                        
                    } else {
                        self.lastExpansionTimestamp = currentTimestamp
                        controller.requestAttachmentMenuExpansion()
                    }
                case "web_app_close":
                    controller.dismiss()
                case "web_app_open_tg_link":
                    if let json = json, let path = json["path_full"] as? String {
                        controller.openUrl("https://t.me\(path)", false, { [weak controller] in
                            let _ = controller
//                            controller?.dismiss()
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
                        self.controller?.cancelButtonNode.setState(isVisible ? .back : .cancel, animated: true)
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
                        let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear)
                        transition.updateBackgroundColor(node: self.backgroundNode, color: color)
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
                    if let json = json, let message = json["message"] as? String, let buttons = json["buttons"] as? [Any] {
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
                    if let json = json, let needConfirmation = json["need_confirmation"] as? Bool {
                        self.needDismissConfirmation = needConfirmation
                    }
                case "web_app_open_scan_qr_popup":
                    var info: String = ""
                    if let json = json, let text = json["text"] as? String {
                        info = text
                    }
                    let controller = QrCodeScanScreen(context: self.context, subject: .custom(info: info))
                    controller.completion = { [weak self] result in
                        if let strongSelf = self {
                            if let result = result {
                                strongSelf.sendQrCodeScannedEvent(data: result)
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
                    if let json = json, let requestId = json["req_id"] as? String {
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
                    if let json = json, let isVisible = json["is_visible"] as? Bool {
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
                    if let json = json, let isPanGestureEnabled = json["allow_vertical_swipe"] as? Bool {
                        self.controller?._isPanGestureEnabled = isPanGestureEnabled
                    }
                case "web_app_share_to_story":
                    if let json = json, let mediaUrl = json["media_url"] as? String {
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
                                    let externalState = MediaEditorTransitionOutExternalState(
                                        storyTarget: nil,
                                        isForcedTarget: false,
                                        isPeerArchived: false,
                                        transitionOut: nil
                                    )
                                    let controller = self.context.sharedContext.makeStoryMediaEditorScreen(context: self.context, source: source, text: text, link: linkUrl.flatMap { ($0, linkName) }, completion: { result, commit in
                                        let target: Stories.PendingTarget = result.target
                                        externalState.storyTarget = target
                                        
                                        if let rootController = self.context.sharedContext.mainWindow?.viewController as? TelegramRootControllerInterface {
                                            rootController.proceedWithStoryUpload(target: target, result: result, existingMedia: nil, forwardInfo: nil, externalState: externalState, commit: commit)
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
                default:
                    break
            }
        }
        
        fileprivate var needDismissConfirmation = false
                
        fileprivate var headerColor: UIColor?
        fileprivate var headerPrimaryTextColor: UIColor?
        private var headerColorKey: String?
        
        fileprivate var bottomPanelColor: UIColor? {
            didSet {
                self.bottomPanelColorPromise.set(.single(self.bottomPanelColor))
            }
        }
        fileprivate let bottomPanelColorPromise = Promise<UIColor?>(nil)
        
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
            
            controller.titleView?.updateTextColors(primary: primaryTextColor, secondary: secondaryTextColor, transition: transition)
            controller.cancelButtonNode.updateColor(primaryTextColor, transition: transition)
            controller.moreButtonNode.updateColor(primaryTextColor, transition: transition)
            transition.updateBackgroundColor(node: self.headerBackgroundNode, color: color ?? .clear)
            transition.updateBackgroundColor(node: self.topOverscrollNode, color: color ?? .clear)
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
            let paramsString = "{slug: \"\(slug)\", status: \"\(result.string)\"}"
            self.webView?.sendEvent(name: "invoice_closed", data: paramsString)
        }
        
        fileprivate func sendBackButtonEvent() {
            self.webView?.sendEvent(name: "back_button_pressed", data: nil)
        }
        
        fileprivate func sendSettingsButtonEvent() {
            self.webView?.sendEvent(name: "settings_button_pressed", data: nil)
        }
        
        fileprivate func sendAlertButtonEvent(id: String?) {
            var paramsString: String?
            if let id = id {
                paramsString = "{button_id: \"\(id)\"}"
            }
            self.webView?.sendEvent(name: "popup_closed", data: paramsString ?? "{}")
        }
        
        fileprivate func sendPhoneRequestedEvent(phone: String?) {
            var paramsString: String?
            if let phone = phone {
                paramsString = "{phone_number: \"\(phone)\"}"
            }
            self.webView?.sendEvent(name: "phone_requested", data: paramsString)
        }
        
        fileprivate func sendQrCodeScannedEvent(data: String?) {
            let paramsString = data.flatMap { "{data: \"\($0)\"}" } ?? "{}"
            self.webView?.sendEvent(name: "qr_text_received", data: paramsString)
        }
        
        fileprivate func sendQrCodeScannerClosedEvent() {
            self.webView?.sendEvent(name: "scan_qr_popup_closed", data: nil)
        }
        
        fileprivate func sendClipboardTextEvent(requestId: String, fillData: Bool) {
            var paramsString: String
            if fillData {
                let data = UIPasteboard.general.string ?? ""
                paramsString = "{req_id: \"\(requestId)\", data: \"\(data)\"}"
            } else {
                paramsString = "{req_id: \"\(requestId)\"}"
            }
            self.webView?.sendEvent(name: "clipboard_text_received", data: paramsString)
        }
        
        fileprivate func requestWriteAccess() {
            guard let controller = self.controller, !self.dismissed else {
                return
            }
            
            let sendEvent: (Bool) -> Void = { success in
                var paramsString: String
                if success {
                    paramsString = "{status: \"allowed\"}"
                } else {
                    paramsString = "{status: \"cancelled\"}"
                }
                self.webView?.sendEvent(name: "write_access_requested", data: paramsString)
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
            guard let controller = self.controller, let botId = self.controller?.botId, let botName = self.controller?.botName else {
                return
            }
            
            
            let sendEvent: (Bool) -> Void = { success in
                var paramsString: String
                if success {
                    paramsString = "{status: \"sent\"}"
                } else {
                    paramsString = "{status: \"cancelled\"}"
                }
                self.webView?.sendEvent(name: "phone_requested", data: paramsString)
            }
            
            let context = self.context
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
                            
                            var data: [String: Any] = [:]
                            data["status"] = "updated"
                            
                            guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
                                return
                            }
                            guard let jsonDataString = String(data: jsonData, encoding: .utf8) else {
                                return
                            }
                            self.webView?.sendEvent(name: "biometry_token_updated", data: jsonDataString)
                        } else {
                            var data: [String: Any] = [:]
                            data["status"] = "failed"
                            
                            guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
                                return
                            }
                            guard let jsonDataString = String(data: jsonData, encoding: .utf8) else {
                                return
                            }
                            self.webView?.sendEvent(name: "biometry_token_updated", data: jsonDataString)
                        }
                    }
                }.start()
            } else {
                self.context.engine.peers.updateBotBiometricsState(peerId: controller.botId, update: { state in
                    var state = state ?? TelegramBotBiometricsState.create()
                    state.opaqueToken = nil
                    return state
                })
                
                var data: [String: Any] = [:]
                data["status"] = "removed"
                
                guard let jsonData = try? JSONSerialization.data(withJSONObject: data) else {
                    return
                }
                guard let jsonDataString = String(data: jsonData, encoding: .utf8) else {
                    return
                }
                self.webView?.sendEvent(name: "biometry_token_updated", data: jsonDataString)
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
    private let botName: String
    private let botVerified: Bool
    private let url: String?
    private let queryId: Int64?
    private let payload: String?
    private let buttonText: String?
    private let forceHasSettings: Bool
    private let keepAliveSignal: Signal<Never, KeepWebViewError>?
    private let replyToMessageId: MessageId?
    private let threadId: Int64?
    
    private var presentationData: PresentationData
    fileprivate let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private var presentationDataDisposable: Disposable?
    
    private var hasSettings = false
    
    public var openUrl: (String, Bool, @escaping () -> Void) -> Void = { _, _, _ in }
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
        self.url = params.url
        self.queryId = params.queryId
        self.payload = params.payload
        self.buttonText = params.buttonText
        self.forceHasSettings = params.forceHasSettings
        self.keepAliveSignal = params.keepAliveSignal
        self.replyToMessageId = replyToMessageId
        self.threadId = threadId
        
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
        
//        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
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
    
    @objc private func cancelPressed() {
        if case .back = self.cancelButtonNode.state {
            self.controllerNode.sendBackButtonEvent()
        } else {
            self.requestDismiss {
                self.dismiss()
            }
        }
    }
    
    @objc private func moreButtonPressed() {
        self.moreButtonNode.buttonPressed()
    }
    
    @objc private func morePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
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
        
        let items = combineLatest(queue: Queue.mainQueue(),
            context.engine.messages.attachMenuBots(),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.botId)),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotCommands(id: self.botId)),
            context.engine.data.get(TelegramEngine.EngineData.Item.Peer.BotPrivacyPolicyUrl(id: self.botId))
        )
        |> take(1)
        |> map { [weak self] attachMenuBots, botPeer, botCommands, privacyPolicyUrl -> ContextController.Items in
            var items: [ContextMenuItem] = []
            
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
                        self?.present(UndoOverlayController(presentationData: presentationData, content: .linkCopied(text: presentationData.strings.Conversation_LinkCopied), elevatedLayout: false, animateInAsReplacement: false, action: { _ in return false }), in: .window(.root))
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
                    context.sharedContext.openResolvedUrl(resolvedUrl, context: context, urlContext: .generic, navigationController: navigationController, forceExternal: true, openPeer: { peer, navigation in
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
                    
                    if let strongSelf = self {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.present(textAlertController(context: context, title: presentationData.strings.WebApp_RemoveConfirmationTitle, text: presentationData.strings.WebApp_RemoveAllConfirmationText(strongSelf.botName).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: { [weak self] in
                            if let strongSelf = self {
                                let _ = context.engine.messages.removeBotFromAttachMenu(botId: strongSelf.botId).start()
                                strongSelf.dismiss()
                            }
                        })], parseMarkdown: true), in: .window(.root))
                    }
                })))
            }
            
            return ContextController.Items(content: .list(items))
        }
        
        let contextController = ContextController(presentationData: presentationData, source: .reference(WebAppContextReferenceContentSource(controller: self, sourceNode: node)), items: items, gesture: gesture)
        self.presentInGlobalOverlay(contextController)
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
            }
        }
    }
    
    public var isMinimizable: Bool {
        return true
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
    openUrl: @escaping (String, Bool, @escaping () -> Void) -> Void,
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
