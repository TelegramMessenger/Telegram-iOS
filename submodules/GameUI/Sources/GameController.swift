import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext

public final class GameController: ViewController {
    private var controllerNode: GameControllerNode {
        return self.displayNode as! GameControllerNode
    }
    
    private let context: AccountContext
    private let url: String
    private let message: Message
    
    private var presentationData: PresentationData
    
    public init(context: AccountContext, url: String, message: Message) {
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
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        assert(true)
    }
    
    @objc private func closePressed() {
        self.dismiss()
    }
    
    @objc private func sharePressed() {
        self.controllerNode.shareWithoutScore()
    }
    
    override public func loadDisplayNode() {
        self.displayNode = GameControllerNode(context: self.context, presentationData: self.presentationData, url: self.url, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, message: self.message)
    }
    
    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        
        self.controllerNode.containerLayoutUpdated(layout, navigationBarHeight: self.navigationHeight, transition: transition)
    }
    
    override public var presentationController: UIPresentationController? {
        get {
            return nil
        } set(value) {
        }
    }
}
