import Foundation
import Display
import AsyncDisplayKit
import TelegramCore
import Postbox

final class SecretChatKeyController: ViewController {
    private var controllerNode: SecretChatKeyControllerNode {
        return self.displayNode as! SecretChatKeyControllerNode
    }
    
    private let account: Account
    private let fingerprint: SecretChatKeyFingerprint
    private let peer: Peer
    
    private var presentationData: PresentationData
    
    init(account: Account, fingerprint: SecretChatKeyFingerprint, peer: Peer) {
        self.account = account
        self.fingerprint = fingerprint
        self.peer = peer
        
        self.presentationData = account.telegramApplicationContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBar.style.style
        self.title = self.presentationData.strings.EncryptionKey_Title
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadDisplayNode() {
        self.displayNode = SecretChatKeyControllerNode(account: self.account, presentationData: self.presentationData, fingerprint: self.fingerprint, peer: self.peer, getNavigationController: { [weak self] in
            return self?.navigationController as? NavigationController
        })
        self.displayNodeDidLoad()
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
}
