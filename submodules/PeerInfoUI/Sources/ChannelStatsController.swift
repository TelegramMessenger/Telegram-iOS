import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import ProgressNavigationButtonNode
import AccountContext

final class ChannelStatsController: ViewController {
    private var controllerNode: ChannelStatsControllerNode {
        return self.displayNode as! ChannelStatsControllerNode
    }
    
    private let context: AccountContext
    private let url: String
    private let peerId: PeerId
    
    private var presentationData: PresentationData
    
    init(context: AccountContext, url: String, peerId: PeerId) {
        self.context = context
        self.url = url
        self.peerId = peerId
        
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style

        self.navigationItem.title = self.presentationData.strings.ChannelInfo_Stats
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func closePressed() {
        self.dismiss()
    }
    
    override func loadDisplayNode() {
        self.displayNode = ChannelStatsControllerNode(context: self.context, presentationData: self.presentationData, peerId: self.peerId, url: self.url, present: { [weak self] c, a in
            self?.present(c, in: .window(.root), with: a)
        }, updateActivity: { [weak self] value in
            guard let strongSelf = self else {
                return
            }
            if value {
                strongSelf.navigationItem.rightBarButtonItem = UIBarButtonItem(customDisplayNode: ProgressNavigationButtonNode(color: strongSelf.presentationData.theme.rootController.navigationBar.controlColor))
            } else {
                strongSelf.navigationItem.rightBarButtonItem = nil
            }
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
