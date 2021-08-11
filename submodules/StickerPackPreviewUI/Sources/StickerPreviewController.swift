import Foundation
import UIKit
import Display
import AsyncDisplayKit
import Postbox
import TelegramCore
import SwiftSignalKit
import AccountContext

public final class StickerPreviewControllerPresentationArguments {
    let transitionNode: (StickerPackItem) -> ASDisplayNode?
    
    public init(transitionNode: @escaping (StickerPackItem) -> ASDisplayNode?) {
        self.transitionNode = transitionNode
    }
}

public final class StickerPreviewController: ViewController {
    private var controllerNode: StickerPreviewControllerNode {
        return self.displayNode as! StickerPreviewControllerNode
    }
    
    private var animatedIn = false
    
    private let context: AccountContext
    private var item: StickerPackItem
    
    public init(context: AccountContext, item: StickerPackItem) {
        self.context = context
        self.item = item
        
        super.init(navigationBarPresentationData: nil)
        
        self.statusBar.statusBarStyle = .Ignore
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        self.displayNode = StickerPreviewControllerNode(context: self.context)
        self.controllerNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        self.controllerNode.cancel = { [weak self] in
            self?.dismiss()
        }
        self.displayNodeDidLoad()
        self.controllerNode.updateItem(self.item)
        //self.ready.set(self.controllerNode.ready.get())
        self.ready.set(.single(true))
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.animatedIn {
            self.animatedIn = true
            self.controllerNode.animateIn(sourceNode: (self.presentationArguments as? StickerPreviewControllerPresentationArguments)?.transitionNode(self.item))
        }
    }
    
    override public func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(targetNode: (self.presentationArguments as? StickerPreviewControllerPresentationArguments)?.transitionNode(self.item), completion: completion)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    public func updateItem(_ item: StickerPackItem) {
        self.item = item
        self.controllerNode.updateItem(item)
    }
}
