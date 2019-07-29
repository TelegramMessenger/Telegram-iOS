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

public enum RequestChatContextResultsError {
    case generic
    case locationRequired
}

public func requestChatContextResults(account: Account, botId: PeerId, peerId: PeerId, query: String, location: Signal<(Double, Double)?, NoError> = .single(nil), offset: String) -> Signal<ChatContextResultCollection?, RequestChatContextResultsError> {
    return combineLatest(account.postbox.transaction { transaction -> (bot: Peer, peer: Peer)? in
        if let bot = transaction.getPeer(botId), let peer = transaction.getPeer(peerId) {
            return (bot, peer)
        } else {
            return nil
        }
    }, location)
    |> introduceError(RequestChatContextResultsError.self)
    |> mapToSignal { botAndPeer, location -> Signal<ChatContextResultCollection?, RequestChatContextResultsError> in
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
            |> mapError { error -> RequestChatContextResultsError in
                if error.errorDescription == "BOT_INLINE_GEO_REQUIRED" {
                    return .locationRequired
                } else {
                    return .generic
                }
            }
        } else {
            return .single(nil)
        }
    }
}
