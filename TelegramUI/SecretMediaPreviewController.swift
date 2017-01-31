import Foundation
import AsyncDisplayKit
import Display
import Postbox
import TelegramCore
import SwiftSignalKit

public final class SecretMediaPreviewController: ViewController {
    private let account: Account
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    private var didSetReady = false
    
    private let disposable = MetaDisposable()
    private let markMessageAsConsumedDisposable = MetaDisposable()
    
    private var controllerNode: SecretMediaPreviewControllerNode {
        return self.displayNode as! SecretMediaPreviewControllerNode
    }
    
    private var messageView: MessageView?
    private var currentNodeMessageId: MessageId?
    
    public init(account: Account, messageId: MessageId) {
        self.account = account
        
        super.init()
        
        self.navigationBar.isHidden = true
        self.statusBar.alpha = 0.0
        
        self.disposable.set((account.postbox.messageView(messageId) |> deliverOnMainQueue).start(next: { [weak self] view in
            if let strongSelf = self {
                strongSelf.messageView = view
                if strongSelf.isViewLoaded {
                    strongSelf.applyMessageView()
                }
            }
        }))
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.disposable.dispose()
        self.markMessageAsConsumedDisposable.dispose()
    }
    
    public override func loadDisplayNode() {
        self.displayNode = SecretMediaPreviewControllerNode()
        self.displayNodeDidLoad()
        
        self.controllerNode.dismiss = { [weak self] in
            self?.dismiss()
        }
        
        if let messageView = self.messageView {
            applyMessageView()
        }
    }
    
    private func applyMessageView() {
        if let messageView = self.messageView, let message = messageView.message {
            if self.currentNodeMessageId != message.id {
                self.currentNodeMessageId = message.id
                let item = galleryItemForEntry(account: account, entry: .MessageEntry(message, false, nil))
                let itemNode = item.node()
                self.controllerNode.setItemNode(itemNode)
            
                let ready = (itemNode.ready() |> timeout(2.0, queue: Queue.mainQueue(), alternate: .single(Void()))) |> afterNext { [weak self] _ in
                    self?.didSetReady = true
                }
                self._ready.set(ready |> map { true })
                
                self.markMessageAsConsumedDisposable.set(markMessageContentAsConsumedInteractively(postbox: self.account.postbox, network: self.account.network, messageId: message.id).start())
            }
        } else {
            if !self.didSetReady {
                self._ready.set(.single(true))
            }
            self.dismiss()
        }
    }
    
    public override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.frame = CGRect(origin: CGPoint(), size: layout.size)
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: 0.0, transition: transition)
    }
    
    public func dismiss() {
        self.presentingViewController?.dismiss(animated: false, completion: nil)
    }
}
