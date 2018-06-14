import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif

public struct ImportAccountProvider {
    let mtProtoKeychain: () -> Signal<[String: [String: Data]], NoError>
    let accountState: () -> Signal<AccountState, NoError>
    let peers: () -> Signal<[Peer], NoError>
    
    public init(mtProtoKeychain: @escaping () -> Signal<[String: [String: Data]], NoError>, accountState: @escaping() -> Signal<AccountState, NoError>, peers: @escaping() -> Signal<[Peer], NoError>) {
        self.mtProtoKeychain = mtProtoKeychain
        self.accountState = accountState
        self.peers = peers
    }
}

public func importAccount(account: UnauthorizedAccount, provider: ImportAccountProvider) -> Signal<Void, NoError> {
    return provider.mtProtoKeychain()
        |> mapToSignal { keychain -> Signal<Void, NoError> in
            for (group, dict) in keychain {
                for (key, value) in dict {
                    account.postbox.setKeychainEntryForKey(group + ":" + key, value: value)
                }
            }
            
            let importAccountState = provider.accountState()
                |> mapToSignal { accountState -> Signal<Void, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        transaction.setState(accountState)
                    }
                }
            
            let importPeers = provider.peers()
                |> mapToSignal { peers -> Signal<Void, NoError> in
                    return account.postbox.transaction { transaction -> Void in
                        updatePeers(transaction: transaction, peers: peers, update: { _, updated in
                            return updated
                        })
                    }
                }
            
            return (importAccountState |> then(importPeers)) |> mapToSignal { _ in return .complete() } |> then(.single(Void()))
        }
}
