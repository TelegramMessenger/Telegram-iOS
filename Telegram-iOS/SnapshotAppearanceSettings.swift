#if DEBUG
    
import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramUI

func snapshotAppearanceSettings(application: UIApplication, mainWindow: UIWindow, window: Window1, statusBarHost: StatusBarHost) {
    let (account, _) = snapshotEnvironment(application: application, mainWindow: mainWindow, statusBarHost: statusBarHost, theme: .day)
    account.network.mockConnectionStatus = .online(proxyAddress: nil)
    
    let _ = (account.postbox.transaction { transaction -> Void in
        if let hole = account.postbox.seedConfiguration.initializeChatListWithHole.topLevel {
            transaction.replaceChatListHole(groupId: nil, index: hole.index, hole: nil)
        }
        
        let accountPeer = TelegramUser(id: account.peerId, accessHash: nil, firstName: "Alena", lastName: "Shy", username: "alenashy", phone: "44321456789", photo: snapshotAvatar(account.postbox, 1), botInfo: nil, restrictionInfo: nil, flags: [])
        transaction.updatePeersInternal([accountPeer], update: { _, updated in
            return updated
        })
    }).start()
    
    let rootController = TelegramRootController(account: account)
    rootController.addRootControllers(showCallsTab: true)
    window.viewController = rootController
    rootController.rootTabController!.selectedIndex = 3
    rootController.pushViewController(themeSettingsController(account: account))
}
    
#endif


