import Foundation
import UIKit
import WebKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext
import AttachmentUI
import CounterContollerTitleView
import ContextUI

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

public final class WebAppController: ViewController, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = { }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void  = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    
    private class Node: ViewControllerTracingNode {
        private var webView: WKWebView?
        
        private let context: AccountContext
        var presentationData: PresentationData
        private let present: (ViewController, Any?) -> Void
        private let message: EngineMessage?
        
        init(context: AccountContext, presentationData: PresentationData, url: String, present: @escaping (ViewController, Any?) -> Void, message: EngineMessage?) {
            self.context = context
            self.presentationData = presentationData
            self.present = present
            self.message = message
            
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
            
            if let parsedUrl = URL(string: url) {
                webView.load(URLRequest(url: parsedUrl))
            }
        }
        
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            if let webView = self.webView {
                webView.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: max(1.0, layout.size.height - navigationBarHeight)))
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
        
        private func shareData() -> (EnginePeer, String)? {
            guard let message = self.message else {
                return nil
            }
            var botPeer: EnginePeer?
            var gameName: String?
            for media in message.media {
                if let game = media as? TelegramMediaGame {
                    inner: for attribute in message.attributes {
                        if let attribute = attribute as? InlineBotMessageAttribute, let peerId = attribute.peerId {
                            botPeer = message.peers[peerId].flatMap(EnginePeer.init)
                            break inner
                        }
                    }
                    if botPeer == nil {
                        botPeer = message.author
                    }
                    
                    gameName = game.name
                }
            }
            if let botPeer = botPeer, let gameName = gameName {
                return (botPeer, gameName)
            }
            
            return nil
        }
        
        private func handleScriptMessage(_ message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else {
                return
            }
            
            guard let eventName = body["eventName"] as? String else {
                return
            }
            
            if eventName == "share_game" || eventName == "share_score" {
                if let (botPeer, gameName) = self.shareData(), let addressName = botPeer.addressName, !addressName.isEmpty, !gameName.isEmpty {
                    if eventName == "share_score" {
                       
                    } else {
                        
                    }
                }
            }
        }
    }

    
    private var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private let moreButtonNode: MoreButtonNode
    
    private let context: AccountContext
    private let url: String
    private let message: EngineMessage?
    
    private var presentationData: PresentationData
    
    public init(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, url: String, message: EngineMessage?) {
        self.context = context
        self.url = url
        self.message = message
        
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
        titleView.title = CounterContollerTitle(title: "Web App", counter: self.presentationData.strings.Bot_GenericBotStatus)
        self.navigationItem.titleView = titleView
        
        self.moreButtonNode.action = { [weak self] _, gesture in
            if let strongSelf = self {
                strongSelf.morePressed(node: strongSelf.moreButtonNode.contextSourceNode, gesture: gesture)
            }
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        assert(true)
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
    
    @objc private func moreButtonPressed() {
        self.moreButtonNode.action?(self.moreButtonNode.contextSourceNode, nil)
    }
    
    @objc private func morePressed(node: ContextReferenceContentNode, gesture: ContextGesture?) {
        var items: [ContextMenuItem] = []
        items.append(.action(ContextMenuActionItem(text: "Open Bot", icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: theme.contextMenu.primaryColor)
        }, action: { [weak self] _, f in
            f(.default)
            
            guard let strongSelf = self else {
                return
            }
            let controller = addWebAppToAttachmentController(sharedContext: strongSelf.context.sharedContext)
            strongSelf.present(controller, in: .window(.root))
        })))
    
        items.append(.action(ContextMenuActionItem(text: "Reload Page", icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Share"), color: theme.contextMenu.primaryColor)
        }, action: { _, f in
            f(.default)
            
            
        })))
        
        items.append(.action(ContextMenuActionItem(text: "Remove Bot", textColor: .destructive, icon: { theme in
            return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
        }, action: { _, f in
            f(.default)
            
        })))
    
        let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .reference(WebAppContextReferenceContentSource(controller: self, sourceNode: node)), items: .single(ContextController.Items(content: .list(items))), gesture: gesture)
        self.presentInGlobalOverlay(contextController)
    }
    
    override public func loadDisplayNode() {
        self.displayNode = Node(context: self.context, presentationData: self.presentationData, url: self.url, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, message: self.message)
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
