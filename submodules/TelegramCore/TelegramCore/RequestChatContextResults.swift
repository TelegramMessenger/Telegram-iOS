import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    #if BUCK
        import MtProtoKit
    #else
        import MtProtoKitDynamic
    #endif
#endif

public func requestChatContextResults(account: Account, botId: PeerId, peerId: PeerId, query: String, location: Signal<(Double, Double)?, NoError> = .single(nil), offset: String) -> Signal<ChatContextResultCollection?, NoError> {
    return combineLatest(account.postbox.transaction { transaction -> (bot: Peer, peer: Peer)? in
        if let bot = transaction.getPeer(botId), let peer = transaction.getPeer(peerId) {
            return (bot, peer)
        } else {
            return nil
        }
    }, location)
    |> mapToSignal { botAndPeer, location -> Signal<ChatContextResultCollection?, NoError> in
        if let (bot, peer) = botAndPeer, let inputBot = apiInputUser(bot) {
            var flags: Int32 = 0
            var inputPeer: Api.InputPeer = .inputPeerEmpty
            var geoPoint: Api.InputGeoPoint?
            if let actualInputPeer = apiInputPeer(peer) {
                inputPeer = actualInputPeer
            }
            if let (latitude, longitude) = location {
                flags |= (1 << 0)
                geoPoint = Api.InputGeoPoint.inputGeoPoint(lat: latitude, long: longitude)
            }
            return account.network.request(Api.functions.messages.getInlineBotResults(flags: flags, bot: inputBot, peer: inputPeer, geoPoint: geoPoint, query: query, offset: offset))
            |> map { result -> ChatContextResultCollection? in
                return ChatContextResultCollection(apiResults: result, botId: bot.id, peerId: peerId, query: query, geoPoint: location)
            }
            |> `catch` { _ -> Signal<ChatContextResultCollection?, NoError> in
                return .single(nil)
            }
        } else {
            return .single(nil)
        }
    }
}
