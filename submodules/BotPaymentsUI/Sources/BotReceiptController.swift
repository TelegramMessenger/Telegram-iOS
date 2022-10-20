import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

public final class BotReceiptController: ViewController {
    private var controllerNode: BotReceiptControllerNode {
        return self.displayNode as! BotReceiptControllerNode
    }
    
    private let _ready = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    private let messageId: EngineMessage.Id
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    public init(context: AccountContext, messageId: EngineMessage.Id) {
        self.context = context
        self.messageId = messageId
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        let title = self.presentationData.strings.Checkout_Receipt_Title
        /*if invoice.flags.contains(.isTest) {
            title += " (Test)"
        }*/
        self.title = title
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func loadDisplayNode() {
        let displayNode = BotReceiptControllerNode(controller: nil, navigationBar: self.navigationBar!, context: self.context, messageId: self.messageId, dismissAnimated: { [weak self] in
            self?.dismiss()
        })
        
        displayNode.dismiss = { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
        }
        
        self.displayNode = displayNode
        super.displayNodeDidLoad()
        self._ready.set(displayNode.ready)
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let presentationArguments = self.presentationArguments as? ViewControllerPresentationArguments, !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            if case .modalSheet = presentationArguments.presentationAnimation {
                self.controllerNode.animateIn()
            }
        }
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition, additionalInsets: UIEdgeInsets())
    }
    
    @objc private func cancelPressed() {
        self.dismiss()
    }
}
