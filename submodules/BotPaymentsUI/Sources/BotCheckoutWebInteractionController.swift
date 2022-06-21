import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import AccountContext

enum BotCheckoutWebInteractionControllerIntent {
    case addPaymentMethod((BotCheckoutPaymentWebToken) -> Void)
    case externalVerification((Bool) -> Void)
}

final class BotCheckoutWebInteractionController: ViewController {
    private var controllerNode: BotCheckoutWebInteractionControllerNode {
        return self.displayNode as! BotCheckoutWebInteractionControllerNode
    }
    
    private let context: AccountContext
    private let url: String
    private let intent: BotCheckoutWebInteractionControllerIntent
    
    private var presentationData: PresentationData
    
    private var didPlayPresentationAnimation = false
    
    init(context: AccountContext, url: String, intent: BotCheckoutWebInteractionControllerIntent) {
        self.context = context
        self.url = url
        self.intent = intent
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: (context.sharedContext.currentPresentationData.with { $0 })))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Cancel, style: .plain, target: self, action: #selector(self.cancelPressed))
        
        switch intent {
            case .addPaymentMethod:
                self.title = self.presentationData.strings.Checkout_NewCard_Title
            case .externalVerification:
                self.title = self.presentationData.strings.Checkout_WebConfirmation_Title
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func cancelPressed() {
        if case let .externalVerification(completion) = self.intent {
            completion(false)
        }
        self.dismiss()
    }
    
    override func loadDisplayNode() {
        self.displayNode = BotCheckoutWebInteractionControllerNode(presentationData: self.presentationData, url: self.url, intent: self.intent)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !self.didPlayPresentationAnimation {
            self.didPlayPresentationAnimation = true
            self.controllerNode.animateIn()
        }
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationLayout(layout: layout).navigationFrame.maxY, transition: transition)
    }
    
    override var presentationController: UIPresentationController? {
        get {
            return nil
        } set(value) {
            
        }
    }
}
