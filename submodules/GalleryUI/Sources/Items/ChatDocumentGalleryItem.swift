import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import WebKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import RadialStatusNode

class ChatDocumentGalleryItem: GalleryItem {
    var id: AnyHashable {
        return self.message.stableId
    }
    
    let context: AccountContext
    let presentationData: PresentationData
    let message: Message
    let location: MessageHistoryEntryLocation?
    
    init(context: AccountContext, presentationData: PresentationData, message: Message, location: MessageHistoryEntryLocation?) {
        self.context = context
        self.presentationData = presentationData
        self.message = message
        self.location = location
    }
    
    func node(synchronous: Bool) -> GalleryItemNode {
        let node = ChatDocumentGalleryItemNode(context: self.context, presentationData: self.presentationData)
        
        for media in self.message.media {
            if let file = media as? TelegramMediaFile {
                node.setFile(context: context, fileReference: .message(message: MessageReference(self.message), media: file))
                break
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let file = content.file {
                    node.setFile(context: context, fileReference: .message(message: MessageReference(self.message), media: file))
                    break
                }
            }
        }
        
        if let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.index + 1)", "\(location.count)").string))
        }
        node.setMessage(self.message)
        
        return node
    }
    
    func updateNode(node: GalleryItemNode, synchronous: Bool) {
        if let node = node as? ChatDocumentGalleryItemNode, let location = self.location {
            node._title.set(.single(self.presentationData.strings.Items_NOfM("\(location.index + 1)", "\(location.count)").string))
            node.setMessage(self.message)
        }
    }
    
    func thumbnailItem() -> (Int64, GalleryThumbnailItem)? {
        return nil
    }
}

private let registeredURLProtocol: Void = {
    URLProtocol.registerClass(ChatDocumentURLProtocol.self)
}()

private final class ChatDocumentURLProtocol: URLProtocol {
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override class func canInit(with request: URLRequest) -> Bool {
        if let mainDocumentURL = request.mainDocumentURL {
            if mainDocumentURL.scheme == "file" && request.url != mainDocumentURL {
                return true
            }
        }
        return false
    }
    
    override class func requestIsCacheEquivalent(_ a: URLRequest, to b: URLRequest) -> Bool {
        return super.requestIsCacheEquivalent(a, to: b)
    }
    
    override func startLoading() {
    }
    
    override func stopLoading() {
    }
}

class ChatDocumentGalleryItemNode: ZoomableContentGalleryItemNode, WKNavigationDelegate {
    fileprivate let _title = Promise<String>()
    
    private let statusNodeContainer: HighlightableButtonNode
    private let statusNode: RadialStatusNode
    
    private let webView: UIView
    
    private var contextAndFile: (AccountContext, FileMediaReference)?
    private let dataDisposable = MetaDisposable()
    
    private var itemIsVisible = false
    
    private var message: Message?
    
    private let footerContentNode: ChatItemGalleryFooterContentNode
    
    private var fetchDisposable = MetaDisposable()
    private let statusDisposable = MetaDisposable()
    private var status: MediaResourceStatus?
    
    init(context: AccountContext, presentationData: PresentationData) {
        if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
            let preferences = WKPreferences()
            preferences.javaScriptEnabled = false
            let configuration = WKWebViewConfiguration()
            configuration.preferences = preferences
            let webView = WKWebView(frame: CGRect(), configuration: configuration)
            webView.allowsLinkPreview = false
            webView.allowsBackForwardNavigationGestures = false
            self.webView = webView
        } else {
            let _ = registeredURLProtocol
            let webView = UIWebView()
            
            webView.scalesPageToFit = true
            self.webView = webView
        }
        self.footerContentNode = ChatItemGalleryFooterContentNode(context: context, presentationData: presentationData)
        
        self.statusNodeContainer = HighlightableButtonNode()
        self.statusNode = RadialStatusNode(backgroundNodeColor: UIColor(white: 0.0, alpha: 0.5))
        self.statusNode.isHidden = true
        
        super.init()
        
        self.view.insertSubview(self.webView, belowSubview: self.scrollNode.view)
        
        self.statusNodeContainer.addSubnode(self.statusNode)
        self.addSubnode(self.statusNodeContainer)
        
        self.statusNodeContainer.addTarget(self, action: #selector(self.statusPressed), forControlEvents: .touchUpInside)
        
        self.statusNodeContainer.isUserInteractionEnabled = false
    }
    
    deinit {
        self.dataDisposable.dispose()
        self.fetchDisposable.dispose()
        self.statusDisposable.dispose()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.webView.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight - 44.0 - layout.insets(options: []).bottom))
        
        let statusSize = CGSize(width: 50.0, height: 50.0)
        transition.updateFrame(node: self.statusNodeContainer, frame: CGRect(origin: CGPoint(x: floor((layout.size.width - statusSize.width) / 2.0), y: floor((layout.size.height - statusSize.height) / 2.0)), size: statusSize))
        transition.updateFrame(node: self.statusNode, frame: CGRect(origin: CGPoint(), size: statusSize))
    }
    
    fileprivate func setMessage(_ message: Message) {
        self.footerContentNode.setMessage(message)
    }
    
    override func navigationStyle() -> Signal<GalleryItemNodeNavigationStyle, NoError> {
        return .single(.dark)
    }
    
    func setFile(context: AccountContext, fileReference: FileMediaReference) {
        let updateFile = self.contextAndFile?.1.media != fileReference.media
        self.contextAndFile = (context, fileReference)
        if updateFile {
            if fileReference.media.mimeType.hasPrefix("image/") {
                if let webView = self.webView as? WKWebView {
                    webView.backgroundColor = .black
                }
            }
            self.maybeLoadContent()
            self.setupStatus(context: context, resource: fileReference.media.resource)
        }
    }
    
    private func setupStatus(context: AccountContext, resource: MediaResource) {
        self.statusDisposable.set((context.account.postbox.mediaBox.resourceStatus(resource)
        |> deliverOnMainQueue).start(next: { [weak self] status in
            if let strongSelf = self {
                let previousStatus = strongSelf.status
                strongSelf.status = status
                switch status {
                    case .Remote, .Paused:
                        strongSelf.statusNode.isHidden = false
                        strongSelf.statusNode.alpha = 1.0
                        strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                        strongSelf.statusNode.transitionToState(.download(.white), completion: {})
                    case let .Fetching(_, progress):
                        strongSelf.statusNode.isHidden = false
                        strongSelf.statusNode.alpha = 1.0
                        strongSelf.statusNodeContainer.isUserInteractionEnabled = true
                        let adjustedProgress = max(progress, 0.027)
                        strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: CGFloat(adjustedProgress), cancelEnabled: true, animateRotation: true), completion: {})
                    case .Local:
                        if let previousStatus = previousStatus, case .Fetching = previousStatus {
                            strongSelf.statusNode.transitionToState(.progress(color: .white, lineWidth: nil, value: 1.0, cancelEnabled: true, animateRotation: true), completion: {
                                if let strongSelf = self {
                                    strongSelf.statusNode.alpha = 0.0
                                    strongSelf.statusNodeContainer.isUserInteractionEnabled = false
                                    strongSelf.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in
                                        if let strongSelf = self {
                                            strongSelf.statusNode.transitionToState(.none, animated: false, completion: {})
                                        }
                                    })
                                }
                            })
                        } else if !strongSelf.statusNode.isHidden && !strongSelf.statusNode.alpha.isZero {
                            strongSelf.statusNode.alpha = 0.0
                            strongSelf.statusNodeContainer.isUserInteractionEnabled = false
                            strongSelf.statusNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, completion: { _ in
                                if let strongSelf = self {
                                    strongSelf.statusNode.transitionToState(.none, animated: false, completion: {})
                                }
                            })
                        }
                }
            }
        }))
    }
    
    private func maybeLoadContent() {
        if let (context, fileReference) = self.contextAndFile {
            var pathExtension: String?
            if let fileName = fileReference.media.fileName {
                pathExtension = (fileName as NSString).pathExtension
            }
            let data = context.account.postbox.mediaBox.resourceData(fileReference.media.resource, pathExtension: pathExtension, option: .complete(waitUntilFetchStatus: false))
            |> deliverOnMainQueue
            self.dataDisposable.set(data.start(next: { [weak self] data in
                if let strongSelf = self {
                    if data.complete {
                        if let webView = strongSelf.webView as? WKWebView {
                            if #available(iOSApplicationExtension 11.0, iOS 11.0, *) {
                                let blockRules = """
                                [{
                                    "trigger": {
                                        "url-filter": ".*"
                                    },
                                    "action": {
                                        "type": "block"
                                    }
                                },
                                {
                                "trigger": {
                                "url-filter": "file://\(data.path)"
                                },
                                "action": {
                                "type": "ignore-previous-rules"
                                }
                                }]
"""
                                WKContentRuleListStore.default().compileContentRuleList(
                                    forIdentifier: "ContentBlockingRules",
                                    encodedContentRuleList: blockRules) { [weak webView] contentRuleList, error in
                                        guard let webView = webView, let contentRuleList = contentRuleList else {
                                            return
                                        }
                                        if let _ = error {
                                            return
                                        }
                                        
                                        let configuration = webView.configuration
                                        configuration.userContentController.add(contentRuleList)
                                        
                                        webView.loadFileURL(URL(fileURLWithPath: data.path), allowingReadAccessTo: URL(fileURLWithPath: data.path))
                                }
                            }
                        } else if let webView = strongSelf.webView as? UIWebView {
                            webView.loadRequest(URLRequest(url: URL(fileURLWithPath: data.path)))
                        }
                    }
                }
            }))
        }
    }
    
    /*private func unloadContent() {
        self.dataDisposable.set(nil)
        
        self.webView.stopLoading()
        self.webView.loadHTMLString("<html></html>", baseURL: nil)
    }*/
    
    override func visibilityUpdated(isVisible: Bool) {
        super.visibilityUpdated(isVisible: isVisible)
        
        if self.itemIsVisible != isVisible {
            self.itemIsVisible = isVisible
            
            if isVisible {
            } else {
                self.fetchDisposable.set(nil)
            }
        }
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func animateIn(from node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.webView)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.webView.superview)
        
        self.webView.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.webView.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(self.webView.layer.transform, transformedFrame.size.width / self.webView.layer.bounds.size.width, transformedFrame.size.height / self.webView.layer.bounds.size.height, 1.0)
        self.webView.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: self.webView.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
        
        self.statusNodeContainer.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.statusNodeContainer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        self.statusNodeContainer.layer.animateScale(from: 0.5, to: 1.0, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
    }
    
    override func animateOut(to node: (ASDisplayNode, CGRect, () -> (UIView?, UIView?)), addToTransitionSurface: (UIView) -> Void, completion: @escaping () -> Void) {
        var transformedFrame = node.0.view.convert(node.0.view.bounds, to: self.webView)
        let transformedSuperFrame = node.0.view.convert(node.0.view.bounds, to: self.webView.superview)
        let transformedSelfFrame = node.0.view.convert(node.0.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.webView.convert(self.webView.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let (maybeCopyView, copyViewBackgrond) = node.2()
        copyViewBackgrond?.alpha = 0.0
        let copyView = maybeCopyView!
        
        self.view.insertSubview(copyView, belowSubview: self.webView)
        copyView.frame = transformedSelfFrame
        
        let intermediateCompletion = { [weak copyView] in
            if positionCompleted && boundsCompleted && copyCompleted {
                copyView?.removeFromSuperview()
                completion()
            }
        }
        
        copyView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.1, removeOnCompletion: false)
        
        copyView.layer.animatePosition(from: CGPoint(x: transformedCopyViewInitialFrame.midX, y: transformedCopyViewInitialFrame.midY), to: CGPoint(x: transformedSelfFrame.midX, y: transformedSelfFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        let scale = CGSize(width: transformedCopyViewInitialFrame.size.width / transformedSelfFrame.size.width, height: transformedCopyViewInitialFrame.size.height / transformedSelfFrame.size.height)
        copyView.layer.animate(from: NSValue(caTransform3D: CATransform3DMakeScale(scale.width, scale.height, 1.0)), to: NSValue(caTransform3D: CATransform3DIdentity), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            copyCompleted = true
            intermediateCompletion()
        })
        
        self.webView.layer.animatePosition(from: self.webView.layer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            positionCompleted = true
            intermediateCompletion()
        })
        
        self.webView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(self.webView.layer.transform, transformedFrame.size.width / self.webView.layer.bounds.size.width, transformedFrame.size.height / self.webView.layer.bounds.size.height, 1.0)
        self.webView.layer.animate(from: NSValue(caTransform3D: self.webView.layer.transform), to: NSValue(caTransform3D: transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25, removeOnCompletion: false, completion: { _ in
            boundsCompleted = true
            intermediateCompletion()
        })
        
        self.statusNodeContainer.layer.animatePosition(from: self.statusNodeContainer.position, to: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false)
        self.statusNodeContainer.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.15, timingFunction: CAMediaTimingFunctionName.easeIn.rawValue, removeOnCompletion: false)
    }
    
    override func footerContent() -> Signal<(GalleryFooterContentNode?, GalleryOverlayContentNode?), NoError> {
        return .single((self.footerContentNode, nil))
    }
    
    @objc func statusPressed() {
        if let (context, fileReference) = self.contextAndFile, let status = self.status {
            switch status {
                case .Fetching:
                    context.account.postbox.mediaBox.cancelInteractiveResourceFetch(fileReference.media.resource)
                case .Remote:
                    self.fetchDisposable.set(fetchedMediaResource(mediaBox: context.account.postbox.mediaBox, reference: fileReference.resourceReference(fileReference.media.resource)).start())
                default:
                    break
            }
        }
    }
}
