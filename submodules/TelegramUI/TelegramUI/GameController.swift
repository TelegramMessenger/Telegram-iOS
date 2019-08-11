import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData

final class GameController: ViewController {
    private var controllerNode: GameControllerNode {
        return self.displayNode as! GameControllerNode
    }
    
    private let context: AccountContext
    private let url: String
    private let message: Message
    
    private var presentationData: PresentationData
    
    init(context: AccountContext, url: String, message: Message) {
        self.context = context
        self.url = url
        self.message = message
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: PresentationResourcesRootController.navigationShareIcon(self.presentationData.theme), style: .plain, target: self, action: #selector(self.sharePressed))
        
        for media in message.media {
            if let game = media as? TelegramMediaGame {
                let titleView = GameControllerTitleView(theme: self.presentationData.theme)
                
                var botPeer: Peer?
                inner: for attribute in message.attributes {
                    if let attribute = attribute as? InlineBotMessageAttribute, let peerId = attribute.peerId {
                        botPeer = message.peers[peerId]
                        break inner
                    }
                }
                if botPeer == nil {
                    botPeer = message.author
                }
                
                titleView.set(title: game.title, subtitle: "@\(botPeer?.addressName ?? "")")
                self.navigationItem.titleView = titleView
            }
        }
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        assert(true)
    }
    
    @objc func closePressed() {
        self.dismiss()
    }
    
    @objc func sharePressed() {
        self.controllerNode.shareWithoutScore()
    }
    
    override func loadDisplayNode() {
        self.displayNode = GameControllerNode(context: self.context, presentationData: self.presentationData, url: self.url, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, message: self.message)
    }
    
    override func dismiss(completion: (() -> Void)? = nil) {
        self.controllerNode.animateOut(completion: { [weak self] in
            self?.presentingViewController?.dismiss(animated: false, completion: nil)
            completion?()
        })
    }
    
    override func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    override var presentationController: UIPresentationController? {
        get {
            return nil
        } set(value) {
            
        }
    }
}
