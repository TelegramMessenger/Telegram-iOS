#if DEBUG

import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import Display
import TelegramUI

func snapshotSettings(application: UIApplication, mainWindow: UIWindow, window: Window1, statusBarHost: StatusBarHost) {
    let (context, accountManager) = snapshotEnvironment(application: application, mainWindow: mainWindow, statusBarHost: statusBarHost, theme: .night)
    context.account.network.mockConnectionStatus = .online(proxyAddress: nil)
    
    let _ = (context.account.postbox.transaction { transaction -> Void in
        if let hole = context.account.postbox.seedConfiguration.initializeChatListWithHole.topLevel {
            transaction.replaceChatListHole(groupId: nil, index: hole.index, hole: nil)
        }
        
        let accountPeer = TelegramUser(id: context.account.peerId, accessHash: nil, firstName: "Alena", lastName: "Shy", username: "alenashy", phone: "44321456789", photo: snapshotAvatar(context.account.postbox, 1), botInfo: nil, restrictionInfo: nil, flags: [])
        transaction.updatePeersInternal([accountPeer], update: { _, updated in
            return updated
        })
    }).start()
    
    let rootController = TelegramRootController(context: context)
    rootController.addRootControllers(showCallsTab: true)
    window.viewController = rootController
    rootController.rootTabController!.selectedIndex = 3
    rootController.pushViewController(settingsController(context: context, accountManager: accountManager))
}

#endif

