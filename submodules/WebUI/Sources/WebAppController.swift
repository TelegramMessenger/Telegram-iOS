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
import MoreButtonNode
import BotPaymentsUI
import PromptUI
import PhoneNumberFormat
import QrCodeUI
import InstantPageUI

private let durgerKingBotIds: [Int64] = [5104055776, 2200339955]

public class WebAppCancelButtonNode: ASDisplayNode {
    public enum State {
        case cancel
        case back
    }
    
    public let buttonNode: HighlightTrackingButtonNode
    private let arrowNode: ASImageNode
    private let labelNode: ImmediateTextNode
    
    public var state: State = .cancel
    
    private var color: UIColor?
    
    private var _theme: PresentationTheme
    public var theme: PresentationTheme {
        get {
            return self._theme
        }
        set {
            self._theme = newValue
            self.setState(self.state, animated: false, animateScale: false, force: true)
        }
    }
    private let strings: PresentationStrings
    
    public func updateColor(_ color: UIColor?, transition: ContainedViewLayoutTransition) {
        let previousColor = self.color
        self.color = color
        
        if case let .animated(duration, curve) = transition, previousColor != color {
            if let snapshotView = self.view.snapshotContentTree() {
                snapshotView.frame = self.bounds
                self.view.addSubview(snapshotView)
                
                snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, timingFunction: curve.timingFunction, removeOnCompletion: false, completion: { _ in
                    snapshotView.removeFromSuperview()
                })
                self.arrowNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction)
                self.labelNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration, timingFunction: curve.timingFunction)
            }
        }
        self.setState(self.state, animated: false, animateScale: false, force: true)
    }
    
    public init(theme: PresentationTheme, strings: PresentationStrings) {
        self._theme = theme
        self.strings = strings
        
        self.buttonNode = HighlightTrackingButtonNode()
        
        self.arrowNode = ASImageNode()
        self.arrowNode.displaysAsynchronously = false
        
        self.labelNode = ImmediateTextNode()
        self.labelNode.displaysAsynchronously = false
        
        super.init()
        
        self.addSubnode(self.buttonNode)
        self.buttonNode.addSubnode(self.arrowNode)
        self.buttonNode.addSubnode(self.labelNode)
        
        self.buttonNode.highligthedChanged = { [weak self] highlighted in
            guard let strongSelf = self else {
                return
            }
            if highlighted {
                strongSelf.arrowNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.arrowNode.alpha = 0.4
                strongSelf.labelNode.layer.removeAnimation(forKey: "opacity")
                strongSelf.labelNode.alpha = 0.4
            } else {
                strongSelf.arrowNode.alpha = 1.0
                strongSelf.arrowNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
                strongSelf.labelNode.alpha = 1.0
                strongSelf.labelNode.layer.animateAlpha(from: 0.4, to: 1.0, duration: 0.2)
            }
        }
        
        self.setState(.cancel, animated: false, force: true)
    }
    
    public func setTheme(_ theme: PresentationTheme, animated: Bool) {
        self._theme = theme
        var animated = animated
        if self.animatingStateChange {
            animated = false
        }
        self.setState(self.state, animated: animated, animateScale: false, force: true)
    }
    
    private var animatingStateChange = false
    public func setState(_ state: State, animated: Bool, animateScale: Bool = true, force: Bool = false) {
        guard self.state != state || force else {
            return
        }
        self.state = state
        
        if animated, let snapshotView = self.buttonNode.view.snapshotContentTree() {
            self.animatingStateChange = true
            snapshotView.layer.sublayerTransform = self.buttonNode.subnodeTransform
            self.view.addSubview(snapshotView)
            
            let duration: Double = animateScale ? 0.25 : 0.3
            if animateScale {
                snapshotView.layer.animateScale(from: 1.0, to: 0.001, duration: 0.25, removeOnCompletion: false)
            }
            snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: duration, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                snapshotView?.removeFromSuperview()
                self.animatingStateChange = false
            })
            
            if animateScale {
                self.buttonNode.layer.animateScale(from: 0.001, to: 1.0, duration: 0.25)
            }
            self.buttonNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: duration)
        }
        
        let color = self.color ?? self.theme.rootController.navigationBar.accentTextColor
        
        self.arrowNode.isHidden = state == .cancel
        self.labelNode.attributedText = NSAttributedString(string: state == .cancel ? self.strings.Common_Cancel : self.strings.Common_Back, font: Font.regular(17.0), textColor: color)
        
        let labelSize = self.labelNode.updateLayout(CGSize(width: 120.0, height: 56.0))
        
        self.buttonNode.frame = CGRect(origin: .zero, size: CGSize(width: labelSize.width, height: self.buttonNode.frame.height))
        self.arrowNode.image = NavigationBarTheme.generateBackArrowImage(color: color)
        if let image = self.arrowNode.image {
            self.arrowNode.frame = CGRect(origin: self.arrowNode.frame.origin, size: image.size)
        }
        self.labelNode.frame = CGRect(origin: self.labelNode.frame.origin, size: labelSize)
        self.buttonNode.subnodeTransform = CATransform3DMakeTranslation(state == .back ? 11.0 : 0.0, 0.0, 0.0)
    }
    
    override public func calculateSizeThatFits(_ constrainedSize: CGSize) -> CGSize {
        self.buttonNode.frame = CGRect(origin: .zero, size: CGSize(width: self.buttonNode.frame.width, height: constrainedSize.height))
        self.arrowNode.frame = CGRect(origin: CGPoint(x: -19.0, y: floorToScreenPixels((constrainedSize.height - self.arrowNode.frame.size.height) / 2.0)), size: self.arrowNode.frame.size)
        self.labelNode.frame = CGRect(origin: CGPoint(x: 0.0, y: floorToScreenPixels((constrainedSize.height - self.labelNode.frame.size.height) / 2.0)), size: self.labelNode.frame.size)

        return CGSize(width: 70.0, height: 56.0)
    }
}

public struct WebAppParameters {
    public enum Source {
        case generic
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
    let url: String?
    let queryId: Int64?
    let payload: String?
    let buttonText: String?
    let keepAliveSignal: Signal<Never, KeepWebViewError>?
    let forceHasSettings: Bool
    
    public init(
        source: Source,
        peerId: PeerId,
        botId: PeerId,
        botName: String,
        url: String?,
        queryId: Int64?,
        payload: String?,
        buttonText: String?,
        keepAliveSignal: Signal<Never, KeepWebViewError>?,
        forceHasSettings: Bool
    ) {
        self.source = source
        self.peerId = peerId
        self.botId = botId
        self.botName = botName
        self.url = url
        self.queryId = queryId
        self.payload = payload
        self.buttonText = buttonText
        self.keepAliveSignal = keepAliveSignal
        self.forceHasSettings = forceHasSettings
    }
}

public func generateWebAppThemeParams(_ presentationTheme: PresentationTheme) -> [String: Any] {
    var backgroundColor = presentationTheme.list.plainBackgroundColor.rgb
    var secondaryBackgroundColor = presentationTheme.list.blocksBackgroundColor.rgb
    if presentationTheme.list.blocksBackgroundColor.rgb == presentationTheme.list.plainBackgroundColor.rgb {
        backgroundColor = presentationTheme.list.modalPlainBackgroundColor.rgb
        secondaryBackgroundColor = presentationTheme.list.plainBackgroundColor.rgb
    }
    return [
        "bg_color": Int32(bitPattern: backgroundColor),
        "secondary_bg_color": Int32(bitPattern: secondaryBackgroundColor),
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
        
        private let context: AccountContext
        var presentationData: PresentationData
        private var queryId: Int64?
        
        private var placeholderDisposable: Disposable?
        private var iconDisposable: Disposable?
        private var keepAliveDisposable: Disposable?
        
        private var paymentDisposable: Disposable?
        
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
                    let _ = freeMediaFileInteractiveFetched(account: strongSelf.context.account, userLocation: .other, fileReference: fileReference).start()
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
                    let _ = (context.engine.messages.requestSimpleWebView(botId: controller.botId, url: nil, source: .settings, themeParams: generateWebAppThemeParams(presentationData.theme))
                    |> deliverOnMainQueue).start(next: { [weak self] result in
                        guard let strongSelf = self else {
                            return
                        }
                        if let parsedUrl = URL(string: result) {
                            strongSelf.webView?.load(URLRequest(url: parsedUrl))
                        }
                    })
                } else {
                    let _ = (context.engine.messages.requestWebView(peerId: controller.peerId, botId: controller.botId, url: controller.url, payload: controller.payload, themeParams: generateWebAppThemeParams(presentationData.theme), fromMenu: controller.source == .menu, replyToMessageId: controller.replyToMessageId, threadId: controller.threadId)
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
        }
        
        deinit {
            self.placeholderDisposable?.dispose()
            self.iconDisposable?.dispose()
            self.keepAliveDisposable?.dispose()
            self.paymentDisposable?.dispose()
            
            self.webView?.removeObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress))
        }
        
        override func didLoad() {
            super.didLoad()
            
            guard let webView = self.webView else {
                return
            }
            self.view.addSubview(webView)
            webView.scrollView.insertSubview(self.topOverscrollNode.view, at: 0)
        }
        
        @objc fileprivate func mainButtonPressed() {
            if let mainButtonState = self.mainButtonState, !mainButtonState.isVisible || !mainButtonState.isEnabled {
                return
            }
            self.webView?.lastTouchTimestamp = CACurrentMediaTime()
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
            let alertController = textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: nil, text: message, actions: [TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {
                completionHandler()
            })])
            alertController.dismissed = { byOutsideTap in
                if byOutsideTap {
                    completionHandler()
                }
            }
            self.controller?.present(alertController, in: .window(.root))
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            let alertController = textAlertController(context: self.context, updatedPresentationData: self.controller?.updatedPresentationData, title: nil, text: message, actions: [TextAlertAction(type: .genericAction, title: self.presentationData.strings.Common_Cancel, action: {
                completionHandler(false)
            }), TextAlertAction(type: .defaultAction, title: self.presentationData.strings.Common_OK, action: {
                completionHandler(true)
            })])
            alertController.dismissed = { byOutsideTap in
                if byOutsideTap {
                    completionHandler(false)
                }
            }
            self.controller?.present(alertController, in: .window(.root))
        }

        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            let promptController = promptController(sharedContext: self.context.sharedContext, updatedPresentationData: self.controller?.updatedPresentationData, text: prompt, value: defaultText, apply: { value in
                if let value = value {
                    completionHandler(value)
                } else {
                    completionHandler(nil)
                }
            })
            promptController.dismissed = { byOutsideTap in
                if byOutsideTap {
                    completionHandler(nil)
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
             
        private let hapticFeedback = HapticFeedback()
        
        private weak var currentQrCodeScannerScreen: QrCodeScanScreen?
        
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
                        self.delayedScriptMessage = message
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
                            let state = AttachmentMainButtonState(text: text, font: .bold, background: .color(backgroundColor), textColor: textColor, isVisible: isVisible, progress: (isLoading ?? false) ? .side : .none, isEnabled: isEnabled ?? true)
                            self.mainButtonState = state
                        }
                    }
                case "web_app_request_viewport":
                    if let (layout, navigationBarHeight) = self.validLayout {
                        self.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: .immediate)
                    }
                case "web_app_request_theme":
                    self.sendThemeChangedEvent()
                case "web_app_expand":
                    controller.requestAttachmentMenuExpansion()
                case "web_app_close":
                    controller.dismiss()
                case "web_app_open_tg_link":
                    if let json = json, let path = json["path_full"] as? String {
                        controller.openUrl("https://t.me\(path)", false, { [weak controller] in
                            controller?.dismiss()
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
                            if let strongSelf = self, let invoice = invoice {
                                let inputData = Promise<BotCheckoutController.InputData?>()
                                inputData.set(BotCheckoutController.InputData.fetch(context: strongSelf.context, source: .slug(slug))
                                |> map(Optional.init)
                                |> `catch` { _ -> Signal<BotCheckoutController.InputData?, NoError> in
                                    return .single(nil)
                                })
                                if let navigationController = strongSelf.controller?.getNavigationController() {
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
                        let tryInstantView = json["try_instant_view"] as? Bool ?? false
                        let currentTimestamp = CACurrentMediaTime()
                        if let lastTouchTimestamp = self.webView?.lastTouchTimestamp, currentTimestamp < lastTouchTimestamp + 10.0 {
                            self.webView?.lastTouchTimestamp = nil
                            if tryInstantView {
                                let _ = (resolveInstantViewUrl(account: self.context.account, url: url)
                                |> deliverOnMainQueue).start(next: { [weak self] result in
                                    guard let strongSelf = self else {
                                        return
                                    }
                                    switch result {
                                    case let .instantView(webPage, anchor):
                                        let controller = InstantPageController(context: strongSelf.context, webPage: webPage, sourceLocation: InstantPageSourceLocation(userLocation: .other, peerType: .otherPrivate), anchor: anchor)
                                        strongSelf.controller?.getNavigationController()?.pushViewController(controller)
                                    default:
                                        strongSelf.context.sharedContext.openExternalUrl(context: strongSelf.context, urlContext: .generic, url: url, forceExternal: true, presentationData: strongSelf.context.sharedContext.currentPresentationData.with { $0 }, navigationController: nil, dismissInput: {})
                                    }
                                })
                            } else {
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
                case "web_app_open_popup":
                    if let json = json, let message = json["message"] as? String, let buttons = json["buttons"] as? [Any] {
                        let presentationData = self.presentationData
                        
                        let title = json["title"] as? String
                        var alertButtons: [TextAlertAction] = []
                        
                        for buttonJson in buttons {
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
                        let currentTimestamp = CACurrentMediaTime()
                        var fillData = false
                        if let lastTouchTimestamp = self.webView?.lastTouchTimestamp, currentTimestamp < lastTouchTimestamp + 10.0, self.controller?.url == nil {
                            self.webView?.lastTouchTimestamp = nil
                            fillData = true
                        }
                        self.sendClipboardTextEvent(requestId: requestId, fillData: fillData)
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
                default:
                    break
            }
        }
        
        fileprivate var needDismissConfirmation = false
        
        fileprivate var headerColor: UIColor?
        fileprivate var headerPrimaryTextColor: UIColor?
        private var headerColorKey: String?
        
        private func updateHeaderBackgroundColor(transition: ContainedViewLayoutTransition) {
            guard let controller = self.controller else {
                return
            }
            
            let color: UIColor?
            var primaryTextColor: UIColor?
            var secondaryTextColor: UIColor?
            var backgroundColor = self.presentationData.theme.list.plainBackgroundColor
            var secondaryBackgroundColor = self.presentationData.theme.list.blocksBackgroundColor
            if self.presentationData.theme.list.blocksBackgroundColor.rgb == self.presentationData.theme.list.plainBackgroundColor.rgb {
                backgroundColor = self.presentationData.theme.list.modalPlainBackgroundColor
                secondaryBackgroundColor = self.presentationData.theme.list.plainBackgroundColor
            }
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
                        .message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: TelegramMediaContact(firstName: user.firstName ?? "", lastName: user.lastName ?? "", phoneNumber: phone, peerId: user.id, vCardData: nil)), replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])
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
    }
    
    fileprivate var controllerNode: Node {
        return self.displayNode as! Node
    }
    
    private var titleView: CounterContollerTitleView?
    fileprivate let cancelButtonNode: WebAppCancelButtonNode
    fileprivate let moreButtonNode: MoreButtonNode
    
    private let context: AccountContext
    private let source: WebAppParameters.Source
    private let peerId: PeerId
    private let botId: PeerId
    private let botName: String
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
        self.url = params.url
        self.queryId = params.queryId
        self.payload = params.payload
        self.buttonText = params.buttonText
        self.forceHasSettings = params.forceHasSettings
        self.keepAliveSignal = params.keepAliveSignal
        self.replyToMessageId = replyToMessageId
        self.threadId = threadId
        
        self.updatedPresentationData = updatedPresentationData
        self.presentationData = updatedPresentationData?.initial ?? context.sharedContext.currentPresentationData.with { $0 }
        
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
        let presentationData = self.presentationData
        
        let peerId = self.peerId
        let botId = self.botId
        let url = self.url
        let forceHasSettings = self.forceHasSettings
        
        let source = self.source
        
        let items = context.engine.messages.attachMenuBots()
        |> take(1)
        |> map { [weak self] attachMenuBots -> ContextController.Items in
            var items: [ContextMenuItem] = []
            
            let attachMenuBot = attachMenuBots.first(where: { $0.peer.id == botId && !$0.flags.contains(.notActivated) })
            
            let hasSettings: Bool
            if url == nil {
                if forceHasSettings {
                    hasSettings = true
                } else {
                    hasSettings = attachMenuBot?.flags.contains(.hasSettings) == true
                }
            } else {
                hasSettings = forceHasSettings
            }
            
            if hasSettings {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_Settings, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Settings"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c.dismiss(completion: nil)
                    
                    if let strongSelf = self {
                        strongSelf.controllerNode.sendSettingsButtonEvent()
                    }
                })))
            }
            
            if peerId != botId {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_OpenBot, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Bots"), color: theme.contextMenu.primaryColor)
                }, action: { [weak self] c, _ in
                    c.dismiss(completion: nil)
                    
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
                            strongSelf.dismiss()
                            strongSelf.context.sharedContext.navigateToChatController(NavigateToChatControllerParams(navigationController: navigationController, context: strongSelf.context, chatLocation: .peer(botPeer)))
                        }
                    })
                })))
            }
            
            items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_ReloadPage, icon: { theme in
                return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Reload"), color: theme.contextMenu.primaryColor)
            }, action: { [weak self] c, _ in
                c.dismiss(completion: nil)
                
                self?.controllerNode.webView?.reload()
            })))
            
            if let _ = attachMenuBot, [.attachMenu, .settings].contains(source) {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.WebApp_RemoveBot, textColor: .destructive, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor)
                }, action: { [weak self] c, _ in
                    c.dismiss(completion: nil)
                    
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
        
        let contextController = ContextController(account: self.context.account, presentationData: self.presentationData, source: .reference(WebAppContextReferenceContentSource(controller: self, sourceNode: node)), items: items, gesture: gesture)
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
    
    public func shouldDismissImmediately() -> Bool {
        if self.controllerNode.needDismissConfirmation {
            return false
        } else {
            return true
        }
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
    
    func send(mode: AttachmentMediaPickerSendMode, attachmentMode: AttachmentMediaPickerAttachmentMode) {
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
    getSourceRect: (() -> CGRect?)? = nil) -> ViewController {
    let controller = AttachmentController(context: context, updatedPresentationData: updatedPresentationData, chatLocation: .peer(id: params.peerId), buttons: [.standalone], initialButton: .standalone, fromMenu: params.source == .menu, hasTextInput: false, makeEntityInputView: {
        return nil
    })
    controller.getInputContainerNode = getInputContainerNode
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
    return controller
}
