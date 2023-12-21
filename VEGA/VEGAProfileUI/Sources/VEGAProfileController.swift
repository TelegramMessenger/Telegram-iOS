import Foundation
import UIKit
import Display
import AsyncDisplayKit
import TelegramCore
import SwiftSignalKit
import TelegramPresentationData
import PresentationDataUtils
import AccountContext
import AppBundle
import LocalizedPeerData
import ContextUI
import TelegramBaseController
import LyraProfile
import Combine
import octo
import LyraData
import CoreUIWidget

public final class VEGAProfileController: TelegramBaseController {
    
    private let _ready = Promise<Bool>(false)
    override public var ready: Promise<Bool> {
        return self._ready
    }
    
    private let context: AccountContext
    
    private var presentationData: PresentationData
    private var presentationDataDisposable: Disposable?
    
    private let peerViewDisposable = MetaDisposable()
        
    private var isEmpty: Bool?
    private var editingMode: Bool = false
    
    private let createActionDisposable = MetaDisposable()
    private let clearDisposable = MetaDisposable()
    
    public init(context: AccountContext) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        
        super.init(context: context, navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData), mediaAccessoryPanelVisibility: .none, locationBroadcastPanelSource: .none, groupCallPanelSource: .none)
        
        self.tabBarItemContextActionType = .always
        
        self.statusBar.statusBarStyle = self.presentationData.theme.rootController.statusBarStyle.style
        
        let icon: UIImage?
        if useSpecialTabBarIcons() {
            icon = UIImage(bundleImageName: "Chat List/Tabs/Holiday/IconCalls")
        } else {
            icon = UIImage(bundleImageName: "Chat List/Tabs/vega-gem-icon-48")
        }
        self.tabBarItem.title = "VEGA"
        self.tabBarItem.image = icon
        self.tabBarItem.selectedImage = icon
        
        if #available(iOS 13, *) {
            let user = LyraPersonalUser()
            user.username = "vg_benny"
            user.vegaId = "e216949b-ba1e-4233-81c2-d8c10a1fe403"
            user.profilePictureUrl = "https://cdn.nba.com/headshots/nba/latest/1040x760/2544.png"
            user.isFollowing = true
            
            let controller = OtherProfileController(user: user)
            self.addChild(controller)
            self.view.addSubview(controller.view)
            controller.view.fillSuperview()
        }
    }
    
    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        self.createActionDisposable.dispose()
        self.presentationDataDisposable?.dispose()
        self.peerViewDisposable.dispose()
        self.clearDisposable.dispose()
    }
}
