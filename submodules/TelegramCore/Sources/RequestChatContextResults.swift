import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit
import SyncCore

public enum RequestChatContextResultsError {
    case generic
    case locationRequired
}

public func requestChatContextResults(account: Account, botId: PeerId, peerId: PeerId, query: String, location: Signal<(Double, Double)?, NoError> = .single(nil), offset: String) -> Signal<ChatContextResultCollection?, RequestChatContextResultsError> {
    return account.postbox.transaction { transaction -> (bot: Peer, peer: Peer)? in
        if let bot = transaction.getPeer(botId), let peer = transaction.getPeer(peerId) {
            return (bot, peer)
        } else {
            return nil
        }
    }
    |> mapToSignal { botAndPeer -> Signal<((bot: Peer, peer: Peer)?, (Double, Double)?), NoError> in
        if let (bot, _) = botAndPeer, let botUser = bot as? TelegramUser, let botInfo = botUser.botInfo, botInfo.flags.contains(.requiresGeolocationForInlineRequests) {
            return location
            |> take(1)
            |> map { location -> ((bot: Peer, peer: Peer)?, (Double, Double)?) in
                return (botAndPeer, location)
            }
        } else {
            return .single((botAndPeer, nil))
        }
    }
    |> castError(RequestChatContextResultsError.self)
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
