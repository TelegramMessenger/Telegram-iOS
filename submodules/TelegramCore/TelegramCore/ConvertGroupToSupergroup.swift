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

public enum ConvertGroupToSupergroupError {
    case generic
}

public func convertGroupToSupergroup(account: Account, peerId: PeerId) -> Signal<PeerId, ConvertGroupToSupergroupError> {
    return account.network.request(Api.functions.messages.migrateChat(chatId: peerId.id))
        |> mapError { error -> ConvertGroupToSupergroupError in
            return .generic
        }
        |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
        |> mapToSignal { updates -> Signal<PeerId, ConvertGroupToSupergroupError> in
            account.stateManager.addUpdates(updates)
            var createdPeerId: PeerId?
            for message in updates.messages {
                if apiMessagePeerId(message) != peerId {
                    createdPeerId = apiMessagePeerId(message)
                    break
                }
            }
            
            if let createdPeerId = createdPeerId {
                return account.postbox.multiplePeersView([createdPeerId])
                |> filter { view in
                    return view.peers[createdPeerId] != nil
                }
                |> take(1)
                |> map { _ in
                    return createdPeerId
                }
                |> mapError { _ -> ConvertGroupToSupergroupError in
                    return .generic
                }
                |> timeout(5.0, queue: Queue.concurrentDefaultQueue(), alternate: .fail(.generic))
            }
            return .fail(.generic)
        }
}
