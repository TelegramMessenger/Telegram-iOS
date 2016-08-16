import Foundation
import Display
import Postbox
import SwiftSignalKit

class SettingsController: ListController {
    private let account: Account
    
    private let peer = Promise<Peer>()
    private let connectionStatus = Promise<ConnectionStatus>(.Online)
    private let peerAndConnectionStatusDisposable = MetaDisposable()
    
    init(account: Account) {
        self.account = account
        
        super.init()
        
        self.title = "Settings"
        self.tabBarItem.title = "Settings"
        self.tabBarItem.image = UIImage(named: "Chat List/Tabs/IconSettings")?.precomposed()
        self.tabBarItem.selectedImage = UIImage(named: "Chat List/Tabs/IconSettingsSelected")?.precomposed()
        
        let deselectAction = { [weak self] () -> Void in
            self?.listDisplayNode.listView.clearHighlightAnimated(true)
        }
        
        self.items = [
            SettingsAccountInfoItem(account: account, peer: nil, connectionStatus: .Online),
            ListControllerButtonItem(title: "Set Profile Photo", action: deselectAction),
            ListControllerSpacerItem(height: 35.0),
            ListControllerDisclosureActionItem(title: "Notifications and Sounds", action: deselectAction),
            ListControllerDisclosureActionItem(title: "Privacy and Security", action: deselectAction),
            ListControllerDisclosureActionItem(title: "Chat Settings", action: deselectAction),
            //SettingsWallpaperListItem(),
            ListControllerSpacerItem(height: 35.0),
            ListControllerDisclosureActionItem(title: "Phone Number", action: deselectAction),
            ListControllerDisclosureActionItem(title: "Username", action: deselectAction),
            ListControllerSpacerItem(height: 35.0),
            ListControllerDisclosureActionItem(title: "Ask a Question", action: deselectAction),
            ListControllerDisclosureActionItem(title: "Telegram FAQ", action: deselectAction),
            ListControllerSpacerItem(height: 35.0),
            ListControllerButtonItem(title: "Logout", action: { }, color: UIColor.red),
            ListControllerSpacerItem(height: 35.0)
        ]
        
        let peerAndConnectionStatus = combineLatest(peer.get(), connectionStatus.get()) |> deliverOn(Queue.mainQueue()) |> afterNext { [weak self] peer, connectionStatus in
            if let strongSelf = self {
                let item = SettingsAccountInfoItem(account: account, peer: peer, connectionStatus: connectionStatus)
                strongSelf.items[0] = item
                if strongSelf.isNodeLoaded {
                    strongSelf.listDisplayNode.listView.deleteAndInsertItems(deleteIndices: [ListViewDeleteItem(index: 0, directionHint: nil)], insertIndicesAndItems: [ListViewInsertItem(index: 0, previousIndex: 0, item: item, directionHint: .Down)], updateIndicesAndItems: [], options: [.AnimateInsertion])
                }
            }
        }
        peerAndConnectionStatusDisposable.set(peerAndConnectionStatus.start())
        
        peer.set(account.postbox.peerWithId(account.peerId))
        connectionStatus.set(account.network.connectionStatus)
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        peerAndConnectionStatusDisposable.dispose()
    }
}
