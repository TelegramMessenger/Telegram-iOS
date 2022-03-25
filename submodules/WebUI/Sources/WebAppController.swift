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

private func generateThemeParams(_ presentationTheme: PresentationTheme) -> [String: Any] {
    return [
        "bg_color": Int32(bitPattern: presentationTheme.list.plainBackgroundColor.rgb),
        "text_color": Int32(bitPattern: presentationTheme.list.itemPrimaryTextColor.rgb),
        "hint_color": Int32(bitPattern: presentationTheme.list.blocksBackgroundColor.rgb),
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
    
    private class Node: ViewControllerTracingNode {
        private weak var controller: WebAppController?
        
        private var webView: WKWebView?
        
        private let context: AccountContext
        var presentationData: PresentationData
        private let present: (ViewController, Any?) -> Void
        private var queryId: Int64?
        
        init(context: AccountContext, controller: WebAppController, presentationData: PresentationData, peerId: PeerId, botId: PeerId, url: String?, present: @escaping (ViewController, Any?) -> Void) {
            self.context = context
            self.controller = controller
            self.presentationData = presentationData
            self.present = present
            
            super.init()
            
            self.backgroundColor = .white
            
            let js = "var TelegramWebviewProxyProto = function() {}; " +
                "TelegramWebviewProxyProto.prototype.postEvent = function(eventName, eventData) { " +
                "window.webkit.messageHandlers.performAction.postMessage({'eventName': eventName, 'eventData': eventData}); " +
                "}; " +
            "var TelegramWebviewProxy = new TelegramWebviewProxyProto();"
            
            let configuration = WKWebViewConfiguration()
            let userController = WKUserContentController()
            
            let userScript = WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            userController.addUserScript(userScript)
            
            userController.add(WeakGameScriptMessageHandler { [weak self] message in
                if let strongSelf = self {
                    strongSelf.handleScriptMessage(message)
                }
            }, name: "performAction")
            
            configuration.userContentController = userController
            
            configuration.allowsInlineMediaPlayback = true
            if #available(iOSApplicationExtension 10.0, iOS 10.0, *) {
                configuration.mediaTypesRequiringUserActionForPlayback = []
            } else if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                configuration.requiresUserActionForMediaPlayback = false
            } else {
                configuration.mediaPlaybackRequiresUserAction = false
            }
            
            let webView = WKWebView(frame: CGRect(), configuration: configuration)
            if #available(iOSApplicationExtension 9.0, iOS 9.0, *) {
                webView.allowsLinkPreview = false
            }
            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                webView.scrollView.contentInsetAdjustmentBehavior = .never
            }
            webView.interactiveTransitionGestureRecognizerTest = { point -> Bool in
                return point.x > 30.0
            }
            
            self.view.addSubview(webView)
            self.webView = webView
            
            let _ = (context.engine.messages.requestWebView(peerId: peerId, botId: botId, url: url, themeParams: generateThemeParams(presentationData.theme))
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self else {
                    return
                }
                switch result {
                    case let .webViewResult(queryId, url):
                        if let parsedUrl = URL(string: url) {
                            strongSelf.queryId = queryId
                            strongSelf.webView?.load(URLRequest(url: parsedUrl))
                        }
                    case .requestConfirmation:
                        break
                }
            })
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            if let webView = self.webView {
                webView.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: max(1.0, layout.size.height - navigationBarHeight - layout.intrinsicInsets.bottom)))
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
                case "webview_send_result_message":
                    self.handleSendResultMessage()
                case "webview_close":
                    self.controller?.dismiss()
                default:
                    break
            }
        }
        
        func sendEvent(name: String, data: String) {
            let script = "window.TelegramGameProxy.receiveEvent(\"\(name)\", \(data))"
            self.webView?.evaluateJavaScript(script, completionHandler: { _, _ in
                
            })
        }
        
        func updatePresentationData(_ presentationData: PresentationData) {
            self.presentationData = presentationData
            
            let themeParams = generateThemeParams(presentationData.theme)
            var themeParamsString = "{"
            for (key, value) in themeParams {
                if let value = value as? Int32 {
                    let color = UIColor(rgb: UInt32(bitPattern: value))
                    
                    if themeParamsString.count > 1 {
                        themeParamsString.append(", ")
                    }
                    themeParamsString.append("\"\(key)\": \"#\(color.hexString)\"")
                }
            }
            themeParamsString.append("}")
            self.sendEvent(name: "theme_changed", data: themeParamsString)
        }
        
        private func handleSendResultMessage() {
            guard let controller = self.controller, let queryId = self.queryId else {
                return
            }

            let _ = (self.context.engine.messages.getWebViewResult(peerId: controller.peerId, botId: controller.botId, queryId: queryId)
            |> deliverOnMainQueue).start(next: { [weak self] result in
                guard let strongSelf = self, let controller = strongSelf.controller else {
                    return
                }
                
                controller.present(textAlertController(context: strongSelf.context, updatedPresentationData: controller.updatedPresentationData, title: nil, text: "Send result?", actions: [TextAlertAction(type: .genericAction, title: strongSelf.presentationData.strings.Common_Cancel, action: {}), TextAlertAction(type: .defaultAction, title: strongSelf.presentationData.strings.Common_OK, action: { [weak self] in
                    guard let strongSelf = self, let controller = strongSelf.controller else {
                        return
                    }
                    let _ = strongSelf.context.engine.messages.enqueueOutgoingMessageWithChatContextResult(to: controller.peerId, botId: controller.botId, result: result)
                    controller.dismiss()
                })]), in: .window(.root))
            })
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
    
    private var presentationData: PresentationData
    fileprivate let updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)?
    private var presentationDataDisposable: Disposable?
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, botId: PeerId, botName: String, url: String?) {
        self.context = context
        self.peerId = peerId
        self.botId = botId
        self.url = url
        
        self.updatedPresentationData = updatedPresentationData
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
        var theme = NavigationBarTheme(rootControllerTheme: self.presentationData.theme)
        theme = theme.withUpdatedBackgroundColor(self.presentationData.theme.list.plainBackgroundColor)
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
                theme = theme.withUpdatedBackgroundColor(presentationData.theme.list.plainBackgroundColor)
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
        var items: [ContextMenuItem] = []
        
        if self.botId != self.peerId {
            items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.WebApp_OpenBot, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: theme.contextMenu.primaryColor)
            }, action: { _, f in
                f(.default)
                
//                if let strongSelf = self {
//                    strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: strongSelf., context: strongSelf.context, chatLocation: .peer(id: strongSelf.peerId)))
//                }
            })))
        }
    
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.WebApp_ReloadPage, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.default)
            
            
        })))
        
        items.append(.action(ContextMenuActionItem(text: self.presentationData.strings.WebApp_RemoveBot, textColor: .destructive, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
        }, action: { [weak self] _, f in
            f(.default)
            
            if let strongSelf = self {
                let _ = context.engine.messages.removeBotFromAttachMenu(peerId: strongSelf.botId).start()
                strongSelf.dismiss()
            }
        })))
    
        let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .reference(WebAppContextReferenceContentSource(controller: self, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, controller: self, presentationData: self.presentationData, peerId: self.peerId, botId: self.botId, url: self.url, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        })
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
