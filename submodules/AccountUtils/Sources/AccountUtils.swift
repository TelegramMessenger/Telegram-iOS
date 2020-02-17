import Foundation
import SwiftSignalKit
import Postbox
import TelegramCore
import SyncCore
import TelegramUIPreferences
import AccountContext

public let maximumNumberOfAccounts = 3

public func activeAccountsAndPeers(context: AccountContext, includePrimary: Bool = false) -> Signal<((Account, Peer)?, [(Account, Peer, Int32)]), NoError> {
    let sharedContext = context.sharedContext
    return context.sharedContext.activeAccounts
    |> mapToSignal { primary, activeAccounts, _ -> Signal<((Account, Peer)?, [(Account, Peer, Int32)]), NoError> in
        var accounts: [Signal<(Account, Peer, Int32)?, NoError>] = []
        func accountWithPeer(_ account: Account) -> Signal<(Account, Peer, Int32)?, NoError> {
            return combineLatest(account.postbox.peerView(id: account.peerId), renderedTotalUnreadCount(accountManager: sharedContext.accountManager, postbox: account.postbox))
            |> map { view, totalUnreadCount -> (Peer?, Int32) in
                return (view.peers[view.peerId], totalUnreadCount.0)
            }
            |> distinctUntilChanged { lhs, rhs in
                return arePeersEqual(lhs.0, rhs.0) && lhs.1 == rhs.1
            }
            |> map { peer, totalUnreadCount -> (Account, Peer, Int32)? in
                if let peer = peer {
                    return (account, peer, totalUnreadCount)
                } else {
                    return nil
                }
            }
        }
        for (_, account, _) in activeAccounts {
            accounts.append(accountWithPeer(account))
        }
        
        return combineLatest(accounts)
        |> map { accounts -> ((Account, Peer)?, [(Account, Peer, Int32)]) in
            var primaryRecord: (Account, Peer)?
            if let first = accounts.filter({ $0?.0.id == primary?.id }).first, let (account, peer, _) = first {
                primaryRecord = (account, peer)
            }
            let accountRecords: [(Account, Peer, Int32)] = (includePrimary ? accounts : accounts.filter({ $0?.0.id != primary?.id })).compactMap({ $0 })
            return (primaryRecord, accountRecords)
        }
    }
}
