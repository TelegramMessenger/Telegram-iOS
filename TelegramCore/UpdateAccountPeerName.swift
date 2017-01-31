import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public func updateAccountPeerName(account: Account, firstName: String, lastName: String) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.account.updateProfile(flags: (1 << 0) | (1 << 1), firstName: firstName, lastName: lastName, about: nil))
        |> map { result -> Api.User? in
            return result
        }
        |> `catch` { _ in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<Void, NoError> in
            return account.postbox.modify { modifier -> Void in
                if let result = result {
                    let peer = TelegramUser(user: result)
                    updatePeers(modifier: modifier, peers: [peer], update: { $1 })
                }
            }
        }
}
