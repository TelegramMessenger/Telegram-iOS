import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
    import TelegramApiMac
#else
    import Postbox
    import SwiftSignalKit
    import TelegramApi
    #if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

public enum CreateGroupError {
    case generic
    case privacy
    case restricted
    case tooMuchLocationBasedGroups
}

public func createGroup(account: Account, title: String, peerIds: [PeerId]) -> Signal<PeerId?, CreateGroupError> {
    return account.postbox.transaction { transaction -> Signal<PeerId?, CreateGroupError> in
        var inputUsers: [Api.InputUser] = []
        for peerId in peerIds {
            if let peer = transaction.getPeer(peerId), let inputUser = apiInputUser(peer) {
                inputUsers.append(inputUser)
            } else {
                return .single(nil)
            }
        }
        return account.network.request(Api.functions.messages.createChat(users: inputUsers, title: title))
        |> mapError { error -> CreateGroupError in
            if error.errorDescription == "USERS_TOO_FEW" {
                return .privacy
            }
            return .generic
        }
        |> mapToSignal { updates -> Signal<PeerId?, CreateGroupError> in
            account.stateManager.addUpdates(updates)
            if let message = updates.messages.first, let peerId = apiMessagePeerId(message) {
                return account.postbox.multiplePeersView([peerId])
                |> filter { view in
                    return view.peers[peerId] != nil
                }
                |> take(1)
                |> introduceError(CreateGroupError.self)
                |> map { _ in
                    return peerId
                }
            } else {
                return .single(nil)
            }
        }
    }
    |> introduceError(CreateGroupError.self)
    |> switchToLatest
}
