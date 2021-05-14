import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SyncCore
import SwiftSignalKit
import TelegramUIPreferences
import AccountContext
import ShareController
import StickerResources
import AlertUI
import PresentationDataUtils
import UndoUI

public final class ImportStickerPackController: ViewController, StandalonePresentableController {
    private var controllerNode: ImportStickerPackControllerNode {
        return self.displayNode as! ImportStickerPackControllerNode
    }
    
    private var animatedIn = false
    private var isDismissed = false
        
    public var dismissed: (() -> Void)?
    
    private let context: AccountContext
    private weak var parentNavigationController: NavigationController?
    
    private let stickerPack: ImportStickerPack
    private var presentationDataDisposable: Disposable?
            

    public init(context: AccountContext, stickerPack: ImportStickerPack, parentNavigationController: NavigationController?) {
        self.context = context
        self.parentNavigationController = parentNavigationController
        
        self.stickerPack = stickerPack
        
        super.init(navigationBarPresentationData: nil)
        
        self.blocksBackgroundWhenInOverlay = true
        self.acceptsFocusWhenInOverlay = true
        self.statusBar.statusBarStyle = .Ignore
        
        self.presentationDataDisposable = (context.sharedContext.presentationData
        |> deliverOnMainQueue).start(next: { [weak self] presentationData in
            if let strongSelf = self, strongSelf.isNodeLoaded {
                strongSelf.controllerNode.updatePresentationData(presentationData)
            }
        })
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = ImportStickerPackControllerNode(context: self.context)
        self.controllerNode.dismiss = { [weak self] in
            self?.dismissed?()
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.controllerNode.presentInGlobalOverlay = { [weak self] controller, arguments in
            self?.presentInGlobalOverlay(controller, with: arguments)
        }
      
        Queue.mainQueue().after(0.1) {
            self.controllerNode.updateStickerPack(self.stickerPack)
        }
        self.ready.set(self.controllerNode.ready.get())
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn()
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        if !self.isDismissed {
            self.isDismissed = true
        } else {
            return
        }
        self.acceptsFocusWhenInOverlay = false
        self.requestUpdateParameters()
        self.controllerNode.animateOut(completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
}

