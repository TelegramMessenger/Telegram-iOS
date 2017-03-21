import Foundation
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit

final class StickerPackPreviewController: ViewController {
    private var controllerNode: StickerPackPreviewControllerNode {
        return self.displayNode as! StickerPackPreviewControllerNode
    }
    
    private var animatedIn = false
    
    private let account: Account
    private let stickerPack: StickerPackReference
    
    private let stickerPackDisposable = MetaDisposable()
    private let stickerPackContents = Promise<LoadedStickerPack>()
    
    private let stickerPackInstalledDisposable = MetaDisposable()
    private let stickerPackInstalled = Promise<Bool>()
    
    init(account: Account, stickerPack: StickerPackReference) {
        self.account = account
        self.stickerPack = stickerPack
        
        super.init(navigationBar: NavigationBar())
        
        self.navigationBar.isHidden = true
        
        self.stickerPackContents.set(loadedStickerPack(account: account, reference: stickerPack))
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.stickerPackDisposable.dispose()
        self.stickerPackInstalledDisposable.dispose()
    }
    
    override func loadDisplayNode() {
        self.displayNode = StickerPackPreviewControllerNode(account: self.account)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.displayNodeDidLoad()
        self.stickerPackDisposable.set((self.stickerPackContents.get() |> deliverOnMainQueue).start(next: { [weak self] next in
            self?.controllerNode.updateStickerPack(next)
        }))
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override func dismiss() {
        self.controllerNode.animateOut()
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
