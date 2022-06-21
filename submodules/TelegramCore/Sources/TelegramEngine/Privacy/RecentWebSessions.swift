import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


public struct WebAuthorization : Equatable {
    public let hash: Int64
    public let botId: PeerId
    public let domain: String
    public let browser: String
    public let platform: String
    public let dateCreated: Int32
    public let dateActive: Int32
    public let ip: String
    public let region: String
    
    public static func ==(lhs: WebAuthorization, rhs: WebAuthorization) -> Bool {
        return lhs.hash == rhs.hash && lhs.botId == rhs.botId && lhs.domain == rhs.domain && lhs.browser == rhs.browser && lhs.platform == rhs.platform && lhs.dateActive == rhs.dateActive && lhs.dateCreated == rhs.dateCreated && lhs.ip == rhs.ip && lhs.region == rhs.region
    }
}

func webSessions(network: Network) -> Signal<([WebAuthorization], [PeerId: Peer]), NoError> {
    return network.request(Api.functions.account.getWebAuthorizations())
        |> retryRequest
        |> map { result -> ([WebAuthorization], [PeerId : Peer]) in
            var sessions: [WebAuthorization] = []
            var peers:[PeerId : Peer] = [:]
            switch result {
            case let .webAuthorizations(authorizations, users):
                for authorization in authorizations {
                    switch authorization {
                    case let .webAuthorization(hash, botId, domain, browser, platform, dateCreated, dateActive, ip, region):
                        sessions.append(WebAuthorization(hash: hash, botId: PeerId(namespace: Namespaces.Peer.CloudUser, id: PeerId.Id._internalFromInt64Value(botId)), domain: domain, browser: browser, platform: platform, dateCreated: dateCreated, dateActive: dateActive, ip: ip, region: region))
                        
                    }
                }
                for user in users {
                    let peer = TelegramUser(user: user)
                    peers[peer.id] = peer
                }
            }
            return (sessions, peers)
    }
}


func terminateWebSession(network: Network, hash: Int64) -> Signal<Bool, NoError> {
    return network.request(Api.functions.account.resetWebAuthorization(hash: hash))
    |> retryRequest
    |> map { result in
        switch result {
            case .boolFalse:
                return false
            case .boolTrue:
                return true
        }
    }
}



func terminateAllWebSessions(network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.account.resetWebAuthorizations())
    |> retryRequest
    |> map { _ in }
}

