import Foundation
import Postbox
import Display
import SwiftSignalKit
import WebKit

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
    private let _title = Promise<String>()
    
    private let webView: UIView
    
    private var accountAndFile: (Account, TelegramMediaFile)?
    private let dataDisposable = MetaDisposable()
    
    private var isVisible = false
    
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
            let data = account.postbox.mediaBox.resourceData(CloudFileMediaResource(location: file.location, size: file.size), pathExtension: pathExtension, complete: true)
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
}
