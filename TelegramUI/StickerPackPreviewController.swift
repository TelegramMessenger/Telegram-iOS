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
    
    var sendSticker: ((TelegramMediaFile) -> Void)?
    
    init(account: Account, stickerPack: StickerPackReference) {
        self.account = account
        self.stickerPack = stickerPack
        
        super.init(navigationBarTheme: nil)
        
        self.statusBar.statusBarStyle = .Ignore
        
        self.stickerPackContents.set(loadedStickerPack(postbox: account.postbox, network: account.network, reference: stickerPack))
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
        self.controllerNode.presentPreview = { [weak self] controller, arguments in
            self?.present(controller, in: .window(.root), with: arguments)
        }
        self.controllerNode.sendSticker = { [weak self] file in
            if let sendSticker = self?.sendSticker {
                sendSticker(file)
                return true
            } else {
                return false
            }
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
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: completion)
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
