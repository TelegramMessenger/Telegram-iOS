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

private final class MainButtonNode: HighlightTrackingButtonNode {
    struct State {
        let text: String?
        let backgroundColor: UIColor
        let textColor: UIColor
        let isEnabled: Bool
        let isVisible: Bool
    }
    private var state: State
    
    private let backgroundNode: ASDisplayNode
    private let textNode: ImmediateTextNode
        
    override init(pointerStyle: PointerStyle? = nil) {
        self.state = State(text: nil, backgroundColor: .clear, textColor: .clear, isEnabled: false, isVisible: false)
        
        self.backgroundNode = ASDisplayNode()
        self.backgroundNode.allowsGroupOpacity = true
        self.backgroundNode.isUserInteractionEnabled = false
        
        self.textNode = ImmediateTextNode()
        self.textNode.textAlignment = .center
        
        super.init(pointerStyle: pointerStyle)
        
        self.addSubnode(self.backgroundNode)
        self.backgroundNode.addSubnode(self.titleNode)
        
        self.highligthedChanged = { [weak self] highlighted in
            if let strongSelf = self, strongSelf.state.isEnabled {
                if highlighted {
                    strongSelf.backgroundNode.layer.removeAnimation(forKey: "opacity")
                    strongSelf.backgroundNode.alpha = 0.65
                } else {
                    strongSelf.backgroundNode.alpha = 1.0
                    strongSelf.backgroundNode.layer.animateAlpha(from: 0.65, to: 1.0, duration: 0.2)
                }
            }
        }
    }
    
    func updateLayout(layout: ContainerViewLayout, state: State, transition: ContainedViewLayoutTransition) -> CGFloat {
        self.state = state
        
        self.isUserInteractionEnabled = state.isVisible
        self.isEnabled = state.isEnabled
        transition.updateAlpha(node: self, alpha: state.isEnabled ? 1.0 : 0.4)
        
        let buttonHeight = 50.0
        if let text = state.text {
            self.textNode.attributedText = NSAttributedString(string: text, font: Font.semibold(16.0), textColor: state.textColor)
            
            let textSize = self.textNode.updateLayout(layout.size)
            self.textNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - textSize.width) / 2.0), y: floorToScreenPixels((buttonHeight - textSize.height) / 2.0)), size: textSize)
            
            self.backgroundNode.backgroundColor = state.backgroundColor
        }
        
        let totalButtonHeight = buttonHeight + layout.intrinsicInsets.bottom
        transition.updateFrame(node: self.backgroundNode, frame: CGRect(origin: CGPoint(), size: CGSize(width: layout.size.width, height: totalButtonHeight)))
        transition.updateSublayerTransformOffset(layer: self.layer, offset: CGPoint(x: 0.0, y: state.isVisible ? 0.0 : totalButtonHeight))
        
        return totalButtonHeight
    }
}

public final class WebAppController: ViewController, AttachmentContainable {
    public var requestAttachmentMenuExpansion: () -> Void = { }
    public var updateNavigationStack: (@escaping ([AttachmentContainable]) -> ([AttachmentContainable], AttachmentMediaPickerContext?)) -> Void = { _ in }
    public var updateTabBarAlpha: (CGFloat, ContainedViewLayoutTransition) -> Void  = { _, _ in }
    public var cancelPanGesture: () -> Void = { }
    public var isContainerPanning: () -> Bool = { return false }
    
    private class Node: ViewControllerTracingNode, WKNavigationDelegate, WKUIDelegate, UIScrollViewDelegate {
        private weak var controller: WebAppController?
        
        fileprivate var webView: WebAppWebView?
        
        private var placeholderIcon: UIImage?
        private var placeholderNode: ShimmerEffectNode?
        private let loadingProgressNode: LoadingProgressNode
        private let mainButtonNode: MainButtonNode
        private var mainButtonState: MainButtonNode.State?
        
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
            self.mainButtonNode = MainButtonNode()
            
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
            self.webView = webView
            
            let placeholderNode = ShimmerEffectNode()
            self.addSubnode(placeholderNode)
            self.placeholderNode = placeholderNode
            self.addSubnode(self.loadingProgressNode)
            self.addSubnode(self.mainButtonNode)
            
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
                                strongSelf.controller?.completion()
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
        }
        
        private func updatePlaceholder() {
            guard let image = self.placeholderIcon else {
                return
            }
            let theme = self.presentationData.theme
            self.placeholderNode?.update(backgroundColor: self.backgroundColor ?? .clear, foregroundColor: theme.list.mediaPlaceholderColor, shimmeringColor: theme.list.itemBlocksBackgroundColor.withAlphaComponent(0.4), shapes: [.image(image: image, rect: CGRect(origin: CGPoint(), size: image.size))], horizontal: true, size: image.size)
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
            
            if let (layout, navigationBarHeight) = self.validLayout {
                self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            let contentOffset = scrollView.contentOffset.y
            self.controller?.navigationBar?.updateBackgroundAlpha(min(30.0, contentOffset) / 30.0, transition: .immediate)
        }
        
        private var validLayout: (ContainerViewLayout, CGFloat)?
        func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
            let previous = self.validLayout?.0
            self.validLayout = (layout, navigationBarHeight)
                        
            if let webView = self.webView {
                let frame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: navigationBarHeight), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - navigationBarHeight - layout.intrinsicInsets.bottom)))
                let viewportFrame = CGRect(origin: CGPoint(x: layout.safeInsets.left, y: navigationBarHeight), size: CGSize(width: layout.size.width - layout.safeInsets.left - layout.safeInsets.right, height: max(1.0, layout.size.height - navigationBarHeight - layout.intrinsicInsets.bottom - layout.additionalInsets.bottom)))
                transition.updateFrame(view: webView, frame: frame)
                
                webView.updateFrame(frame: viewportFrame, transition: transition)
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
            
            if let previous = previous, (previous.inputHeight ?? 0.0).isZero, let inputHeight = layout.inputHeight, inputHeight > 44.0 {
                self.controller?.requestAttachmentMenuExpansion()
            }
            
            if let mainButtonState = self.mainButtonState {
                let mainButtonHeight = self.mainButtonNode.updateLayout(layout: layout, state: mainButtonState, transition: transition)
                transition.updateFrame(node: self.mainButtonNode, frame: CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - mainButtonHeight - layout.additionalInsets.bottom), size: CGSize(width: layout.size.width, height: mainButtonHeight)))
            }
        }
        
        override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
            if keyPath == "estimatedProgress", let webView = self.webView {
                self.loadingProgressNode.updateProgress(webView.estimatedProgress, animated: true)
            }
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
                case "web_app_setup_main_button":
                    if let eventData = body["eventData"] as? String {
                        print(eventData)
                        
//                        self.mainButtonState = MainButtonNode.State(text: <#T##String?#>, backgroundColor: <#T##UIColor#>, textColor: <#T##UIColor#>, isEnabled: <#T##Bool#>, isVisible: <#T##Bool#>)
                        if let (layout, navigationBarHeight) = self.validLayout {
                            self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .animated(duration: 0.2, curve: .easeInOut))
                        }
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
            self.webView?.sendEvent(name: "theme_changed", data: themeParamsString)
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
    
    public var openUrl: (String) -> Void = { _ in }
    public var getNavigationController: () -> NavigationController? = { return nil }
    public var completion: () -> Void = {}
        
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

public func standaloneWebAppController(context: AccountContext, updatedPresentationData: (initial: PresentationData, signal: Signal<PresentationData, NoError>)? = nil, peerId: PeerId, botId: PeerId, botName: String, url: String, queryId: Int64?, buttonText: String?, keepAliveSignal: Signal<Never, KeepWebViewError>?, openUrl: @escaping (String) -> Void, completion: @escaping () -> Void = {}) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: .peer(id: peerId), buttons: [.standalone], initialButton: .standalone)
    controller.requestController = { _, present in
        let webAppController = WebAppController(context: context, updatedPresentationData: updatedPresentationData, peerId: peerId, botId: botId, botName: botName, url: url, queryId: queryId, buttonText: buttonText, keepAliveSignal: keepAliveSignal, replyToMessageId: nil, iconFile: nil)
        webAppController.openUrl = openUrl
        webAppController.completion = completion
        present(webAppController, nil)
    }
    return controller
}
