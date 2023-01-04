import Foundation
import SwiftSignalKit
import TelegramCore
import TelegramUIPreferences
import AccountContext

// MARK: Nicegram MaxAccounts
public let nicegramMaximumNumberOfAccounts = 1000
public let maximumNumberOfAccounts = nicegramMaximumNumberOfAccounts
public let maximumPremiumNumberOfAccounts = nicegramMaximumNumberOfAccounts
//

public func activeAccountsAndPeers(context: AccountContext, includePrimary: Bool = false) -> Signal<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)]), NoError> {
    // MARK: Nicegram DB Changes
    let hiddenIds = context.sharedContext.accountManager.accountRecords()
    |> map { view -> [AccountRecordId] in
        return view.records.filter({ $0.attributes.contains(where: { $0.isHiddenAccountAttribute }) }).map { $0.id }
    }
    |> distinctUntilChanged(isEqual: ==)
    return combineLatest(privatActiveAccountsAndPeers(context: context, includePrimary: includePrimary), hiddenIds) |> map { accountsAndPeers, hiddenIds in
        let isDoubleBottom = hiddenIds.contains { record in
            record == context.account.id
        }
        
        if isDoubleBottom && UserDefaults.standard.bool(forKey: "inDoubleBottom") {
            return (accountsAndPeers.0, accountsAndPeers.1.filter { hiddenIds.contains($0.0.account.id) })
        } else {
            return (accountsAndPeers.0, accountsAndPeers.1)
        }
    }
}

private func privatActiveAccountsAndPeers(context: AccountContext, includePrimary: Bool = false) -> Signal<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)]), NoError> {
    let sharedContext = context.sharedContext
    return context.sharedContext.activeAccountContexts
    |> mapToSignal { primary, activeAccounts, _ -> Signal<((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)]), NoError> in
        var accounts: [Signal<(AccountContext, EnginePeer, Int32)?, NoError>] = []
        func accountWithPeer(_ context: AccountContext) -> Signal<(AccountContext, EnginePeer, Int32)?, NoError> {
            return combineLatest(context.account.postbox.peerView(id: context.account.peerId), renderedTotalUnreadCount(accountManager: sharedContext.accountManager, engine: context.engine))
            |> map { view, totalUnreadCount -> (EnginePeer?, Int32) in
                return (view.peers[view.peerId].flatMap(EnginePeer.init), totalUnreadCount.0)
            }
            |> distinctUntilChanged { lhs, rhs in
                if lhs.0 != rhs.0 {
                    return false
                }
                if lhs.1 != rhs.1 {
                    return false
                }
                return true
            }
            |> map { peer, totalUnreadCount -> (AccountContext, EnginePeer, Int32)? in
                if let peer = peer {
                    return (context, peer, totalUnreadCount)
                } else {
                    return nil
                }
            }
        }
        for (_, context, _) in activeAccounts {
            accounts.append(accountWithPeer(context))
        }
        
        return combineLatest(accounts)
        |> map { accounts -> ((AccountContext, EnginePeer)?, [(AccountContext, EnginePeer, Int32)]) in
            var primaryRecord: (AccountContext, EnginePeer)?
            if let first = accounts.filter({ $0?.0.account.id == primary?.account.id }).first, let (account, peer, _) = first {
                primaryRecord = (account, peer)
            }
            let accountRecords: [(AccountContext, EnginePeer, Int32)] = (includePrimary ? accounts : accounts.filter({ $0?.0.account.id != primary?.account.id })).compactMap({ $0 })
            return (primaryRecord, accountRecords)
        }
    }
}
