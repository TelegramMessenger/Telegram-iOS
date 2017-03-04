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
}

public func importAccount(account: Account, provider: ImportAccountProvider) -> Signal<Void, NoError> {
    return provider.mtProtoKeychain()
        |> mapToSignal { keychain -> Signal<Void, NoError> in
            for (group, dict) in keychain {
                for (key, value) in dict {
                    account.postbox.setKeychainEntryForKey(group + ":" + key, value: value)
                }
            }
            
            let importAccountState = provider.accountState()
                |> mapToSignal { accountState -> Signal<Void, NoError> in
                    return account.postbox.modify { modifier -> Void in
                        modifier.setState(accountState)
                    }
                }
            
            let importPeers = provider.peers()
                |> mapToSignal { peers -> Signal<Void, NoError> in
                    return account.postbox.modify { modifier -> Void in
                        updatePeers(modifier: modifier, peers: peers, update: { _, updated in
                            return updated
                        })
                    }
                }
            
            return importAccountState |> then(importPeers)
        }
}
