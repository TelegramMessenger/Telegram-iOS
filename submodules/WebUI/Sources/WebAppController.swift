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

private class WeakGameScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private let f: (WKScriptMessage) -> ()
    
    init(_ f: @escaping (WKScriptMessage) -> ()) {
        self.f = f
        
        super.init()
    }
    
    func userContentController(_ controller: WKUserContentController, didReceive scriptMessage: WKScriptMessage) {
        self.f(scriptMessage)
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

private final class LoadingProgressNode: ASDisplayNode {
    var color: UIColor {
        didSet {
            self.foregroundNode.backgroundColor = self.color
        }
    }
    
    private let foregroundNode: ASDisplayNode
    
    init(color: UIColor) {
        self.color = color
        
        self.foregroundNode = ASDisplayNode()
        self.foregroundNode.backgroundColor = color
        
        super.init()
        
        self.addSubnode(self.foregroundNode)
    }
        
    private var _progress: CGFloat = 0.0
    func updateProgress(_ progress: CGFloat, animated: Bool = false) {
        if self._progress == progress && animated {
            return
        }
        
        var animated = animated
        if (progress < self._progress && animated) {
            animated = false
        }
        
        let size = self.bounds.size
        
        self._progress = progress
        
        let transition: ContainedViewLayoutTransition
        if animated && progress > 0.0 {
            transition = .animated(duration: 0.7, curve: .spring)
        } else {
            transition = .immediate
        }
        
        let alpaTransition: ContainedViewLayoutTransition
        if animated {
            alpaTransition = .animated(duration: 0.3, curve: .easeInOut)
        } else {
            alpaTransition = .immediate
        }
        
        transition.updateFrame(node: self.foregroundNode, frame: CGRect(x: -2.0, y: 0.0, width: (size.width + 4.0) * progress, height: size.height))
        
        let alpha: CGFloat = progress < 0.001 || progress > 0.999 ? 0.0 : 1.0
        alpaTransition.updateAlpha(node: self.foregroundNode, alpha: alpha)
    }
    
    override func layout() {
        super.layout()
        
        self.foregroundNode.cornerRadius = self.frame.height / 2.0
    }
}

public final class WebAppController: ViewController, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = { }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void  = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    
    private class Node: ViewControllerTracingNode, WKNavigationDelegate, UIScrollViewDelegate {
        private weak var controller: WebAppController?
        
        fileprivate var webView: WebAppWebView?
        
        private var placeholderIcon: UIImage?
        private var placeholderNode: ShimmerEffectNode?
        
        private let loadingProgressNode: LoadingProgressNode
        
        private let context: AccountContext
        var presentationData: PresentationData
        private let present: (ViewController, Any?) -> Void
        private var queryId: Int64?
        
        private var iconDisposable: Disposable?
        private var keepAliveDisposable: Disposable?
        
        init(context: AccountContext, controller: WebAppController, present: @escaping (ViewController, Any?) -> Void) {
            self.context = context
            self.controller = controller
            self.presentationData = controller.presentationData
            self.present = present
            
            self.loadingProgressNode = LoadingProgressNode(color: presentationData.theme.rootController.tabBar.selectedIconColor)
            
            super.init()
            
            if self.presentationData.theme.list.plainBackgroundColor.rgb == 0x000000 {
                self.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
            } else {
                self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            }
                        
            let configuration = WKWebViewConfiguration()
            let userController = WKUserContentController()
            
            let js = "var TelegramWebviewProxyProto = function() {}; " +
                "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
                "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
                "}; " +
            "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
                        
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userController.addUserScript(userScript)
            userController.add(WeakGameScriptMessageHandler { [weak self] message in
                if let strongSelf = self {
                    strongSelf.handleScriptMessage(message)
                }
            }, name: "performAction")
            
            let selectionString = "var css = '*{-webkit-touch-callout:none;} :not(input):not(textarea){-webkit-user-select:none;}';"
                    + " var head = document.head || document.getElementsByTagName('head')[0];"
                    + " var style = document.createElement('style'); style.type = 'text/css';" +
                    " style.appendChild(document.createTextNode(css)); head.appendChild(style);"
            let selectionScript: WKUserScript = WKUserScript(source: selectionString, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            userController.addUserScript(selectionScript)
            
            configuration.userContentController = userController
            
            configuration.allowsInlineMediaPlayback = true
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                configuration.mediaTypesRequiringUserActionForPlayback = []
            } else if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                configuration.requiresUserActionForMediaPlayback = false
            } else {
                configuration.mediaPlaybackRequiresUserAction = false
            }
            
            let webView = WebAppWebView(frame: CGRect(), configuration: configuration)
            webView.alpha = 0.0
            webView.isOpaque = false
            webView.backgroundColor = .clear
            webView.navigationDelegate = self
            
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                webView.allowsLinkPreview = false
            }
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                webView.scrollView.contentInsetAdjustmentBehavior = .never
            }
            webView.interactiveTransitionGestureRecognizerTest = { point -> Bool in
                return point.x > 30.0
            }
            webView.allowsBackForwardNavigationGestures = false
            webView.scrollView.delegate = self
            webView.scrollView.contentInset = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 1.0, right: 0.0)
            webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: [], context: nil)
            webView.tintColor = self.presentationData.theme.rootController.tabBar.iconColor
            self.webView = webView
            
            let placeholderNode = ShimmerEffectNode()
            self.addSubnode(placeholderNode)
            self.placeholderNode = placeholderNode
            
            if controller.buttonText == nil {
                self.addSubnode(self.loadingProgressNode)
            }
            
            if let iconFile = controller.iconFile {
                let _ = freeMediaFileInteractiveFetched(account: self.context.account, fileReference: .standalone(media: iconFile)).start()
                self.iconDisposable = (svgIconImageFile(account: self.context.account, fileReference: .standalone(media: iconFile))
                |> deliverOnMainQueue).start(next: { [weak self] transform in
                    if let strongSelf = self {
                        let imageSize = CGSize(width: 75.0, height: 75.0)
                        let arguments = TransformImageArguments(corners: ImageCorners(), imageSize: imageSize, boundingSize: imageSize, intrinsicInsets: UIEdgeInsets())
                        let drawingContext = transform(arguments)
                        if let image = drawingContext?.generateImage()?.withRenderingMode(.alwaysTemplate) {
                            strongSelf.placeholderIcon = image
                            
                            strongSelf.updatePlaceholder()
                        }
                    }
                })
            }
            
            if let url = controller.url {
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
                let _ = (context.engine.messages.requestWebView(peerId: controller.peerId, botId: controller.botId, url: controller.url, payload: nil, themeParams: generateWebAppThemeParams(presentationData.theme), replyToMessageId: controller.replyToMessageId)
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
                                strongSelf.controller?.dismiss()
                            }
                        })
                    }
                })
            }
        }
        
        deinit {
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
                        
            if #available(iOS 11.0, *) {
                let webScrollView = webView.subviews.compactMap { $0 as? UIScrollView }.first
                Queue.mainQueue().after(0.1, {
                    let contentView = webScrollView?.subviews.first(where: { $0.interactions.count > 1 })
                    guard let dragInteraction = (contentView?.interactions.compactMap { $0 as? UIDragInteraction }.first) else {
                        return
                    }
                    contentView?.removeInteraction(dragInteraction)
                })
            }
        }
        
        private func updatePlaceholder() {
            guard let image = self.placeholderIcon else {
                return
            }
            let theme = self.presentationData.theme
            self.placeholderNode?.update(backgroundColor: self.backgroundColor ?? .clear, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: [.image(image: image, rect: CGRect(origin: CGPoint(), size: image.size))], horizontal: true, size: image.size)
        }
        
        private var loadCount = 0
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            self.loadCount += 1
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            self.loadCount -= 1
            
            Queue.mainQueue().after(0.1, {
                if self.loadCount == 0, let webView = self.webView {
                    let transition = ContainedViewLayoutTransition.animated(duration: 0.2, curve: .linear)
                    transition.updateAlpha(layer: webView.layer, alpha: 1.0)
                    if let placeholderNode = self.placeholderNode {
                        self.placeholderNode = nil
                        transition.updateAlpha(node: placeholderNode, alpha: 0.0, completion: { [weak placeholderNode] _ in
                            placeholderNode?.removeFromSupernode()
                        })
                    }
                }
            })
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset.y
            self.controller?.navigationBar?.updateBackgroundAlpha(min(30.0, contentOffset) / 30.0, transition: .immediate)
        }
        
        private var animationProgress: CGFloat = 0.0
        private var floatSnapshotView: UIView?
        
        
        
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            if let webView = self.webView, let controller = self.controller {
                let frame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: navigationBarHeight), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - navigationBarHeight - layout.intrinsicInsets.bottom - layout.additionalInsets.bottom)))
                
                webView.updateFrame(frame: frame, panning: controller.isContainerPanning(), transition: transition)
            }
            
            if let placeholderNode = self.placeholderNode {
                let iconSize = CGSize(width: 75.0, height: 75.0)
                
                let height: CGFloat
                if case .compact = layout.metrics.widthClass {
                    height = layout.size.height - layout.additionalInsets.bottom - layout.intrinsicInsets.bottom
                } else {
                    height = layout.size.height - layout.intrinsicInsets.bottom
                }
                
                let placeholderFrame =  CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - iconSize.width) / 2.0), y: floorToScreenPixels((height - iconSize.height) / 2.0)), size: iconSize)
                transition.updateFrame(node: placeholderNode, frame: placeholderFrame)
                placeholderNode.updateAbsoluteRect(placeholderFrame, within: layout.size)
                
                let loadingProgressHeight: CGFloat = 2.0
                transition.updateFrame(node: self.loadingProgressNode, frame: CGRect(origin: CGPoint(x: 0.0, y: height - loadingProgressHeight), size: CGSize(width: layout.size.width, height: loadingProgressHeight)))
            }
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "estimatedProgress", let webView = self.webView {
                self.loadingProgressNode.updateProgress(webView.estimatedProgress, animated: true)
            }
        }
        
        func animateIn() {
            self.layer.animatePosition(from: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), to: self.layer.position, duration: 0.5, timingFunction: kCAMediaTimingFunctionSpring)
        }
        
        func animateOut(completion: (() -> Void)? = nil) {
            self.layer.animatePosition(from: self.layer.position, to: CGPoint(x: self.layer.position.x, y: self.layer.position.y + self.layer.bounds.size.height), duration: 0.2, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue, removeOnCompletion: false, completion: { _ in
                completion?()
            })
        }
        
        private func handleScriptMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else {
                return
            }
            
            guard let eventName = body["eventName"] as? String else {
                return
            }
            
            switch eventName {
                case "web_app_data_send":
                    if let eventData = body["eventData"] as? String {
                        self.handleSendData(data: eventData)
                    }
                case "web_app_close":
                    self.controller?.dismiss()
                default:
                    break
            }
        }
        
        private var dismissed = false
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
        
        func sendEvent(name: String, data: String) {
            let script = "window.TelegramGameProxy.receiveEvent(\"\(name)\", \(data))"
            self.webView?.evaluateJavaScript(script, completionHandler: { _, _ in
                
            })
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
            
            if self.presentationData.theme.list.plainBackgroundColor.rgb == 0x000000 {
                self.backgroundColor = self.presentationData.theme.list.itemBlocksBackgroundColor
            } else {
                self.backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            }
            
            let themeParams = generateWebAppThemeParams(presentationData.theme)
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
            self.sendEvent(name: "theme_changed", data: themeParamsString)
        }
    }
    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var titleView: CounterContollerTitleView?
    private let moreButtonNode: MoreButtonNode
    
    private let context: AccountContext
    private let peerId: PeerId
    private let botId: PeerId
    private let url: String?
    private let queryId: Int64?
    private let buttonText: String?
    private let keepAliveSignal: Signal<Never, KeepWebViewError>?
    private let replyToMessageId: MessageId?
    private let iconFile: TelegramMediaFile?
    
    private var presentationData: PresentationData
    fileprivate let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private var presentationDataDisposable: Disposable?
    
    public var getNavigationController: () -> NavigationController? = { return nil }
        
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, botId: PeerId, botName: String, url: String?, queryId: Int64?, buttonText: String?, keepAliveSignal: Signal<Never, KeepWebViewError>?, replyToMessageId: MessageId?, iconFile: TelegramMediaFile?) {
        self.context = context
        self.peerId = peerId
        self.botId = botId
        self.url = url
        self.queryId = queryId
        self.buttonText = buttonText
        self.keepAliveSignal = keepAliveSignal
        self.replyToMessageId = replyToMessageId
        self.iconFile = iconFile
        
        self.updatedPresentationData = updatedPresentationData
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        var theme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme)
        if self.presentationData.theme.list.plainBackgroundColor.rgb == 0x000000 {
            theme = theme.withUpdatedBackgroundColor(self.presentationData.theme.list.itemBlocksBackgroundColor)
        } else {
            theme = theme.withUpdatedBackgroundColor(self.presentationData.theme.list.plainBackgroundColor)
        }
        let navigationBarPresentationData = NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(back: "", close: ""))
        
        self.moreButtonNode = MoreButtonNode(theme: self.presentationData.theme)
        self.moreButtonNode.iconNode.enqueueState(.more, animated: false)
        
        super.init(navigationBarPresentationData: navigationBarPresentationData)
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: self.moreButtonNode)
        self.navigationItem.rightBarButtonItem?.action = #selector(self.moreButtonPressed)
        self.navigationItem.rightBarButtonItem?.target = self
        
        let titleView = CounterContollerTitleView(theme: self.presentationData.theme)
        titleView.title = CounterContollerTitle(title: botName, counter: self.presentationData.strings.Bot_GenericBotStatus)
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
                
                var theme = NavigationBarTheme(rootControllerTheme: presentationData.theme)
                if presentationData.theme.list.plainBackgroundColor.rgb == 0x000000 {
                    theme = theme.withUpdatedBackgroundColor(presentationData.theme.list.itemBlocksBackgroundColor)
                } else {
                    theme = theme.withUpdatedBackgroundColor(presentationData.theme.list.plainBackgroundColor)
                }
                let navigationBarPresentationData = NavigationBarPresentationData(theme: theme, strings: NavigationBarStrings(back: "", close: ""))
                strongSelf.navigationBar?.updatePresentationData(navigationBarPresentationData)
                strongSelf.titleView?.theme = presentationData.theme
                
                strongSelf.controllerNode.updatePresentationData(presentationData)
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
        self.moreButtonNode.action?(self.moreButtonNode.contextSourceNode, nil)
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
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor)
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
                        let _ = context.engine.messages.removeBotFromAttachMenu(botId: strongSelf.botId).start()
                        strongSelf.dismiss()
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

public func standaloneWebAppController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, botId: PeerId, botName: String, url: String, queryId: Int64?, buttonText: String?, keepAliveSignal: Signal<Never, KeepWebViewError>?) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: .peer(id: peerId), buttons: [.standalone], initialButton: .standalone)
    controller.requestController = { _, completion in
        completion(WebAppController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, botId: botId, botName: botName, url: url, queryId: queryId, buttonText: buttonText, keepAliveSignal: keepAliveSignal, replyToMessageId: nil, iconFile: nil), nil)
    }
    return controller
}
