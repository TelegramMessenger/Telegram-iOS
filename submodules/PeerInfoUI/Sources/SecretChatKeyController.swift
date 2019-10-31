import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import Postbox
import TelegramPresentationData
import AccountContext

final class SecretChatKeyController: ViewController {
    private var controllerNode: SecretChatKeyControllerNode {
        return self.displayNode as! SecretChatKeyControllerNode
    }
    
    private let context: AccountContext
    private let fingerprint: SecretChatKeyFingerprint
    private let peer: Peer
    
    private var presentationData: PresentationData
    
    init(context: AccountContext, fingerprint: SecretChatKeyFingerprint, peer: Peer) {
        self.context = context
        self.fingerprint = fingerprint
        self.peer = peer
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.navigationPresentation = .modal
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        self.title = self.presentationData.strings.EncryptionKey_Title
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = SecretChatKeyControllerNode(context: self.context, presentationData: self.presentationData, fingerprint: self.fingerprint, peer: self.peer, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        })
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
