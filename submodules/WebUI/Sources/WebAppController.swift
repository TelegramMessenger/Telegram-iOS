import Foundation
import UIKit
import WebKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AttachmentUI
import CounterContollerTitleView
import ContextUI
import PresentationDataUtils
import HexColor
import ShimmerEffect
import PhotoResources
import LegacyComponents
import UrlHandling

private let durgerKingBotIds: [Int64] = [5104055776, 2200339955]

public struct WebAppParameters {
    let peerId: PeerId
    let botId: PeerId
    let botName: String
    let url: String?
    let queryId: Int64?
    let payload: String?
    let buttonText: String?
    let keepAliveSignal: Signal<Never, KeepWebViewError>?
    let fromMenu: Bool
    let isSimple: Bool
    
    public init(
        peerId: PeerId,
        botId: PeerId,
        botName: String,
        url: String?,
        queryId: Int64?,
        payload: String?,
        buttonText: String?,
        keepAliveSignal: Signal<Never, KeepWebViewError>?,
        fromMenu: Bool,
        isSimple: Bool
    ) {
        self.peerId = peerId
        self.botId = botId
        self.botName = botName
        self.url = url
        self.queryId = queryId
        self.payload = payload
        self.buttonText = buttonText
        self.keepAliveSignal = keepAliveSignal
        self.fromMenu = fromMenu
        self.isSimple = isSimple
    }
}

public func generateWebAppThemeParams(_ presentationTheme: PresentationTheme) -> [String: Any] {
    var backgroundColor = presentationTheme.list.plainBackgroundColor.rgb
    if backgroundColor == 0x000000 {
        backgroundColor = presentationTheme.list.itemBlocksBackgroundColor.rgb
    }
    return [
        "bg_color": Int32(bitPattern: backgroundColor),
        "text_color": Int32(bitPattern: presentationTheme.list.itemPrimaryTextColor.rgb),
        "hint_color": Int32(bitPattern: presentationTheme.list.itemSecondaryTextColor.rgb),
        "link_color": Int32(bitPattern: presentationTheme.list.itemAccentColor.rgb),
        "button_color": Int32(bitPattern: presentationTheme.list.itemCheckColors.fillColor.rgb),
        "button_text_color": Int32(bitPattern: presentationTheme.list.itemCheckColors.foregroundColor.rgb)
    ]
}

public final class WebAppController: ViewController, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = { }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void  = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    public var isContainerExpanded: () -> Bool = { return false }
    
    fileprivate class Node: ViewControllerTracingNode, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
        private weak var controller: WebAppController?
        
        fileprivate var webView: WebAppWebView?
        private var placeholderIcon: (UIImage, Bool)?
        private var placeholderNode: ShimmerEffectNode?
    
        fileprivate let loadingProgressPromise = Promise<CGFloat?>(nil)
        fileprivate let mainButtonStatePromise = Promise<AttachmentMainButtonState?>(nil)
        
        private let context: AccountContext
        var presentationData: PresentationData
        private let present: (ViewController, Any?) -> Void
        private var queryId: Int64?
        
        private var placeholderDisposable: Disposable?
        private var iconDisposable: Disposable?
        private var keepAliveDisposable: Disposable?
        
        private var didTransitionIn = false
        private var dismissed = false
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        
        init(context: AccountContext, controller: WebAppController, present: @escaping (ViewController, Any?) -> Void) {
            self.context = context
            self.controller = controller
            self.presentationData = controller.presentationData
            self.present = present
            
            super.init()
            
            if self.presentationData.theme.list.plainBackgroundColor.rgb == 0x000000 {
                self.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
            } else {
                self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            }
                         
            let webView = WebAppWebView()
            webView.alpha = 0.0
            webView.navigationDelegate = self
            webView.uiDelegate = self
            webView.scrollView.delegate = self
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
            webView.tintColor = self.presentationData.theme.rootController.tabBar.iconColor
            webView.handleScriptMessage = { [weak self] message in
                self?.handleScriptMessage(message)
            }
            webView.onFirstTouch = { [weak self] in
                if let strongSelf = self, let delayedScriptMessage = strongSelf.delayedScriptMessage {
                    strongSelf.delayedScriptMessage = nil
                    strongSelf.handleScriptMessage(delayedScriptMessage)
                }
            }
            self.webView = webView
            
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
                    if let bot = bot, let peerReference = PeerReference(bot.peer) {
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
            
            self.placeholderDisposable = (placeholder
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
                    let _ = freeMediaFileInteractiveFetched(account: strongSelf.context.account, fileReference: fileReference).start()
                }
                strongSelf.iconDisposable = (svgIconImageFile(account: strongSelf.context.account, fileReference: fileReference, stickToTop: isPlaceholder)
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
                })
            })
                
            if let url = controller.url, !controller.fromMenu {
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
                let _ = (context.engine.messages.requestWebView(peerId: controller.peerId, botId: controller.botId, url: controller.url, payload: controller.payload, themeParams: generateWebAppThemeParams(presentationData.theme), fromMenu: controller.fromMenu, replyToMessageId: controller.replyToMessageId)
                |> deliverOnMainQueue).start(next: { [weak self] result in
                    guard let strongSelf = self else {
                        return
                    }
                    if let parsedUrl = URL(string: result.url) {
                        strongSelf.queryId = result.queryId
                        strongSelf.webView?.load(URLRequest(url: parsedUrl))
                        
                        strongSelf.keepAliveDisposable = (result.keepAliveSignal
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
        
        deinit {
            self.placeholderDisposable?.dispose()
            self.iconDisposable?.dispose()
            self.keepAliveDisposable?.dispose()
            
            self.webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        }
        
        override func didLoad() {
            super.didLoad()
            
            guard let webView = self.webView else {
                return
            }
            self.view.addSubview(webView)
        }
        
        @objc fileprivate func mainButtonPressed() {
            self.webView?.sendEvent(name: "main_button_pressed", data: nil)
        }
        
        private func updatePlaceholder(layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) -> CGSize {
            var shapes: [ShimmerEffect.ShimmerEffectNode.Shape] = []
            var placeholderSize: CGSize = CGSize()
            
            if let (image, _) = self.placeholderIcon {
                shapes = [.image(image: image, rect: CGRect(origin: CGPoint(), size: image.size))]
                placeholderSize = image.size
            }
         
            let theme = self.presentationData.theme
            self.placeholderNode?.update(backgroundColor: self.backgroundColor ?? .clear, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: shapes, horizontal: true, size: placeholderSize)
            
            return placeholderSize
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url?.absoluteString {
                if isTelegramMeLink(url) || isTelegraPhLink(url) {
                    decisionHandler(.cancel)
                    self.controller?.openUrl(url)
                } else {
                    decisionHandler(.allow)
                }
            } else {
                decisionHandler(.allow)
            }
        }
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                self.controller?.openUrl(url.absoluteString)
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
                
        private var targetContentOffset: CGPoint?
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset.y
            self.controller?.navigationBar?.updateBackgroundAlpha(min(30.0, contentOffset) / 30.0, transition: .immediate)
            
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
                        
            if let webView = self.webView {
                let frame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: navigationBarHeight), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - navigationBarHeight - layout.intrinsicInsets.bottom)))
                let viewportFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: navigationBarHeight), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - navigationBarHeight - layout.intrinsicInsets.bottom - layout.additionalInsets.bottom)))
                
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
             
        private var delayedScriptMessage: WKScriptMessage?
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
            
            switch eventName {
                case "web_app_ready":
                    self.animateTransitionIn()
                case "web_app_data_send":
                    if controller.isSimple, let eventData = body["eventData"] as? String {
                        self.handleSendData(data: eventData)
                    }
                case "web_app_setup_main_button":
                    if let webView = self.webView, !webView.didTouchOnce {
                        self.delayedScriptMessage = message
                    } else if let eventData = (body["eventData"] as? String)?.data(using: .utf8), let json = try? JSONSerialization.jsonObject(with: eventData, options: []) as? [String: Any] {
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
                            let state = AttachmentMainButtonState(text: text, backgroundColor: backgroundColor, textColor: textColor, isVisible: isVisible, isLoading: isLoading ?? false, isEnabled: isEnabled ?? true)
                            self.mainButtonStatePromise.set(.single(state))
                        }
                    }
                case "web_app_request_viewport":
                    if let (layout, navigationBarHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    }
                case "web_app_request_theme":
                    self.sendThemeChangedEvent()
                case "web_app_expand":
                    self.controller?.requestAttachmentMenuExpansion()
                case "web_app_close":
                    self.controller?.dismiss()
                default:
                    break
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
                } else if let data1 = try? JSONSerialization.data(withJSONObject: data, options: JSONSerialization.WritingOptions.prettyPrinted), let convertedString = String(data: data1, encoding: String.Encoding.utf8) {
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
            self.sendThemeChangedEvent()
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
    }
    
    fileprivate var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var titleView: CounterContollerTitleView?
    private let moreButtonNode: MoreButtonNode
    
    private let context: AccountContext
    private let peerId: PeerId
    private let botId: PeerId
    private let botName: String
    private let url: String?
    private let queryId: Int64?
    private let payload: String?
    private let buttonText: String?
    private let fromMenu: Bool
    private let isSimple: Bool
    private let keepAliveSignal: Signal<Never, KeepWebViewError>?
    private let replyToMessageId: MessageId?
    
    private var presentationData: PresentationData
    fileprivate let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private var presentationDataDisposable: Disposable?
    
    public var openUrl: (String) -> Void = { _ in }
    public var getNavigationController: () -> NavigationController? = { return nil }
    public var completion: () -> Void = {}
        
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, params: WebAppParameters, replyToMessageId: MessageId?) {
        self.context = context
        self.peerId = params.peerId
        self.botId = params.botId
        self.botName = params.botName
        self.url = params.url
        self.queryId = params.queryId
        self.payload = params.payload
        self.buttonText = params.buttonText
        self.fromMenu = params.fromMenu
        self.isSimple = params.isSimple
        self.keepAliveSignal = params.keepAliveSignal
        self.replyToMessageId = replyToMessageId
        
        self.updatedPresentationData = updatedPresentationData
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        self.moreButtonNode = MoreButtonNode(theme: self.presentationData.theme)
        self.moreButtonNode.iconNode.enqueueState(.more, animated: false)
        
        let navigationBarPresentationData = NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: self.presentationData.theme), strings: NavigationBarStrings(back: "", close: ""))
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: self.moreButtonNode)
        self.navigationItem.rightBarButtonItem?.action = #selector(self.moreButtonPressed)
        self.navigationItem.rightBarButtonItem?.target = self
        
        let titleView = CounterContollerTitleView(theme: self.presentationData.theme)
        titleView.title = CounterContollerTitle(title: params.botName, counter: self.presentationData.strings.Bot_GenericBotStatus)
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
                strongSelf.presentationData = presentationData
                
                let navigationBarPresentationData = NavigationBarPresentationData(theme: NavigationBarTheme(rootControllerTheme: presentationData.theme), strings: NavigationBarStrings(back: "", close: ""))
                strongSelf.navigationBar?.updatePresentationData(navigationBarPresentationData)
                strongSelf.titleView?.theme = presentationData.theme
                
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
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func moreButtonPressed() {
        self.moreButtonNode.buttonPressed()
    }
    
    @objc private func morePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        let context = self.context
        let presentationData = self.presentationData
        
        let peerId = self.peerId
        let botId = self.botId
        
        let items = context.engine.messages.attachMenuBots()
        |> map { [weak self] attachMenuBots -> ContextController.Items in
            var items: [ContextMenuItem] = []
            if peerId != botId {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_OpenBot, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    
                    if let strongSelf = self, let navigationController = strongSelf.getNavigationController() {
                        strongSelf.dismiss()
                        strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(id: strongSelf.botId)))
                    }
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_ReloadPage, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reload"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] _, f in
                f(.default)
                
                self?.controllerNode.webView?.reload()
            })))
            
            if let _ = attachMenuBots.firstIndex(where: { $0.peer.id == botId}) {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_RemoveBot, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    
                    if let strongSelf = self {
                        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
                        strongSelf.present(textAlertController(context: context, title: presentationData.strings.WebApp_RemoveConfirmationTitle, text: presentationData.strings.WebApp_RemoveConfirmationText(strongSelf.botName).string, actions: [TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: { [weak self] in
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
        
        let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .reference(WebAppContextReferenceContentSource(controller: self, sourceNode: node)), items: items, gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        })
        
        self.navigationBar?.updateBackgroundAlpha(0.0, transition: .immediate)
        self.updateTabBarAlpha(1.0, .immediate)
    }
    
    public func isContainerPanningUpdated(_ isPanning: Bool) {
        self.controllerNode.isContainerPanningUpdated(isPanning)
    }
        
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
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
}

final class WebAppPickerContext: AttachmentMediaPickerContext {
    private weak var controller: WebAppController?
    
    var selectionCount: Signal<Int, NoError> {
        return .single(0)
    }
    
    var caption: Signal<NSAttributedString?, NoError> {
        return .single(nil)
    }
    
    public var loadingProgress: Signal<CGFloat?, NoError> {
        return self.controller?.controllerNode.loadingProgressPromise.get() ?? .single(nil)
    }
    
    public var mainButtonState: Signal<AttachmentMainButtonState?, NoError> {
        return self.controller?.controllerNode.mainButtonStatePromise.get() ?? .single(nil)
    }
        
    init(controller: WebAppController) {
        self.controller = controller
    }
    
    func setCaption(_ caption: NSAttributedString) {
    }
    
    func send(silently: Bool, mode: AttachmentMediaPickerSendMode) {
    }
    
    func schedule() {
    }
    
    func mainButtonAction() {
        self.controller?.controllerNode.mainButtonPressed()
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

public func standaloneWebAppController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, params: WebAppParameters, openUrl: @escaping (String) -> Void, getInputContainerNode: @escaping () -> (CGFloat, ASDisplayNode, () -> AttachmentController.InputPanelTransition?)? = { return nil }, completion: @escaping () -> Void = {}, willDismiss: @escaping () -> Void = {}, didDismiss: @escaping () -> Void = {}) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: .peer(id: params.peerId), buttons: [.standalone], initialButton: .standalone, fromMenu: params.fromMenu)
    controller.getInputContainerNode = getInputContainerNode
    controller.requestController = { _, present in
        let webAppController = WebAppController(context: context, updatedPresentationData: updatedPresentationData, params: params, replyToMessageId: nil)
        webAppController.openUrl = openUrl
        webAppController.completion = completion
        present(webAppController, webAppController.mediaPickerContext)
    }
    controller.willDismiss = willDismiss
    controller.didDismiss = didDismiss
    return controller
}
