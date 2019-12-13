
import Foundation
import SwiftSignalKit
import Postbox
import TelegramApi

public struct InactiveChannel : Equatable {
    public let peer: Peer
    public let lastActivityDate: Int32
    init(peer: Peer, lastActivityDate: Int32) {
        self.peer = peer
        self.lastActivityDate = lastActivityDate
    }
    public static func ==(lhs: InactiveChannel, rhs: InactiveChannel) -> Bool {
        return lhs.peer.isEqual(rhs.peer) && lhs.lastActivityDate == rhs.lastActivityDate
    }
}

public func inactiveChannelList(network: Network) -> Signal<[InactiveChannel], NoError> {
    return network.request(Api.functions.channels.getInactiveChannels())
        |> retryRequest
        |> map { result in
            switch result {
            case let .inactiveChats(dates, chats, users):
                let channels = chats.compactMap {
                    parseTelegramGroupOrChannel(chat: $0)
                }
                var inactive: [InactiveChannel] = []
                for (i, channel) in channels.enumerated() {
                    inactive.append(InactiveChannel(peer: channel, lastActivityDate: dates[i]))
                }
                return inactive
            }
        }
}
