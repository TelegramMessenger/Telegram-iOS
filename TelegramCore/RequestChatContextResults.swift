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

public struct ChatContextGeoPoint {
    let latitude: Double
    let longtitude: Double
    public init(latitude: Double, longtitude: Double) {
        self.latitude = latitude
        self.longtitude = longtitude
    }
}

public func requestChatContextResults(account: Account, botId: PeerId, peerId: PeerId, query: String, offset: String, geopoint: ChatContextGeoPoint? = nil) -> Signal<ChatContextResultCollection?, NoError> {
    return account.postbox.modify { modifier -> (bot: Peer, peer: Peer)? in
        if let bot = modifier.getPeer(botId), let peer = modifier.getPeer(peerId) {
            return (bot, peer)
        } else {
            return nil
        }
    }
    |> mapToSignal { botAndPeer -> Signal<ChatContextResultCollection?, NoError> in
        if let (bot, peer) = botAndPeer, let inputBot = apiInputUser(bot) {
            var flags: Int32 = 0
            var inputPeer: Api.InputPeer = .inputPeerEmpty
            if let actualInputPeer = apiInputPeer(peer) {
                inputPeer = actualInputPeer
            }
            var inputGeo: Api.InputGeoPoint? = nil
            if let geopoint = geopoint {
                inputGeo = Api.InputGeoPoint.inputGeoPoint(lat: geopoint.latitude, long: geopoint.longtitude)
                flags |= (1 << 0)
            }
            return account.network.request(Api.functions.messages.getInlineBotResults(flags: flags, bot: inputBot, peer: inputPeer, geoPoint: inputGeo, query: query, offset: offset))
                |> map { result -> ChatContextResultCollection? in
                    return ChatContextResultCollection(apiResults: result, botId: bot.id)
                }
                |> `catch` { _ -> Signal<ChatContextResultCollection?, NoError> in
                    return .single(nil)
                }
        } else {
            return .single(nil)
        }
    }
}
