import Foundation
import Postbox
import Display
import SwiftSignalKit
import WebKit
import TelegramCore

class ChatDocumentGalleryItem: GalleryItem {
    let account: Account
    let message: Message
    let location: MessageHistoryEntryLocation?
    
    init(account: Account, message: Message, location: MessageHistoryEntryLocation?) {
        self.account = account
        self.message = message
        self.location = location
    }
    
    func node() -> GalleryItemNode {
        let node = ChatDocumentGalleryItemNode()
        
        for media in self.message.media {
            if let file = media as? TelegramMediaFile {
                node.setFile(account: account, file: file)
                break
            } else if let webpage = media as? TelegramMediaWebpage, case let .Loaded(content) = webpage.content {
                if let file = content.file {
                    node.setFile(account: account, file: file)
                    break
                }
            }
        }
        
        if let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
        }
        
        return node
    }
    
    func updateNode(node: GalleryItemNode) {
        if let node = node as? ChatDocumentGalleryItemNode, let location = self.location {
            node._title.set(.single("\(location.index + 1) of \(location.count)"))
        }
    }
}

class ChatDocumentGalleryItemNode: GalleryItemNode {
    fileprivate let _title = Promise<String>()
    
    private let webView: UIView
    
    private var accountAndFile: (Account, TelegramMediaFile)?
    private let dataDisposable = MetaDisposable()
    
    private var itemIsVisible = false
    
    override init() {
        if #available(iOS 9.0, *) {
            let webView = WKWebView()
            self.webView = webView
        } else {
            let webView = UIWebView()
            webView.scalesPageToFit = true
            self.webView = webView
        }
        
        super.init()
        
        self.view.addSubview(self.webView)
    }
    
    deinit {
        self.dataDisposable.dispose()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, navigationBarHeight: CGFloat, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, navigationBarHeight: navigationBarHeight, transition: transition)
        
        self.webView.frame = CGRect(origin: CGPoint(x: 0.0, y: navigationBarHeight), size: CGSize(width: layout.size.width, height: layout.size.height - navigationBarHeight))
    }
    
    override func navigationStyle() -> Signal<GalleryItemNodeNavigationStyle, NoError> {
        return .single(.light)
    }
    
    func setFile(account: Account, file: TelegramMediaFile) {
        let updateFile = self.accountAndFile?.1 != file
        self.accountAndFile = (account, file)
        if updateFile {
            self.maybeLoadContent()
        }
    }
    
    private func maybeLoadContent() {
        if let (account, file) = self.accountAndFile {
            var pathExtension: String?
            if let fileName = file.fileName {
                pathExtension = (fileName as NSString).pathExtension
            }
            let data = account.postbox.mediaBox.resourceData(file.resource, pathExtension: pathExtension, option: .complete(waitUntilFetchStatus: false))
                |> deliverOnMainQueue
            self.dataDisposable.set(data.start(next: { [weak self] data in
                if let strongSelf = self {
                    if data.size == file.size {
                        if let webView = strongSelf.webView as? WKWebView {
                            if #available(iOS 9.0, *) {
                                webView.loadFileURL(URL(fileURLWithPath: data.path), allowingReadAccessTo: URL(fileURLWithPath: data.path))
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
        
        /*if self.isVisible != isVisible {
            self.isVisible = isVisible
            
            if isVisible {
                self.maybeLoadContent()
            } else {
                self.unloadContent()
            }
        }*/
    }
    
    override func title() -> Signal<String, NoError> {
        return self._title.get()
    }
    
    override func animateIn(from node: ASDisplayNode) {
        var transformedFrame = node.view.convert(node.view.bounds, to: self.webView)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: self.webView.superview)
        
        self.webView.layer.animatePosition(from: CGPoint(x: transformedSuperFrame.midX, y: transformedSuperFrame.midY), to: self.webView.layer.position, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring)
        
        transformedFrame.origin = CGPoint()
        
        let transform = CATransform3DScale(self.webView.layer.transform, transformedFrame.size.width / self.webView.layer.bounds.size.width, transformedFrame.size.height / self.webView.layer.bounds.size.height, 1.0)
        self.webView.layer.animate(from: NSValue(caTransform3D: transform), to: NSValue(caTransform3D: self.webView.layer.transform), keyPath: "transform", timingFunction: kCAMediaTimingFunctionSpring, duration: 0.25)
    }
    
    override func animateOut(to node: ASDisplayNode, completion: @escaping () -> Void) {
        var transformedFrame = node.view.convert(node.view.bounds, to: self.webView)
        let transformedSuperFrame = node.view.convert(node.view.bounds, to: self.webView.superview)
        let transformedSelfFrame = node.view.convert(node.view.bounds, to: self.view)
        let transformedCopyViewInitialFrame = self.webView.convert(self.webView.bounds, to: self.view)
        
        var positionCompleted = false
        var boundsCompleted = false
        var copyCompleted = false
        
        let copyView = node.view.snapshotContentTree()!
        
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
    }
}
