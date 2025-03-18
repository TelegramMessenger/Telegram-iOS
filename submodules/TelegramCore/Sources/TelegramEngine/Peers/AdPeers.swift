import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

public class AdPeer: Equatable {
    public let opaqueId: Data
    public let peer: EnginePeer
    public let sponsorInfo: String?
    public let additionalInfo: String?
    
    public init(opaqueId: Data, peer: EnginePeer, sponsorInfo: String?, additionalInfo: String?) {
        self.opaqueId = opaqueId
        self.peer = peer
        self.sponsorInfo = sponsorInfo
        self.additionalInfo = additionalInfo
    }
    
    public static func ==(lhs: AdPeer, rhs: AdPeer) -> Bool {
        if lhs.opaqueId != rhs.opaqueId {
            return false
        }
        if lhs.peer != rhs.peer {
            return false
        }
        if lhs.sponsorInfo != rhs.sponsorInfo {
            return false
        }
        if lhs.additionalInfo != rhs.additionalInfo {
            return false
        }
        return true
    }
}

func _internal_searchAdPeers(account: Account, query: String) -> Signal<[AdPeer], NoError> {
    return account.network.request(Api.functions.contacts.getSponsoredPeers(q: query))
    |> map(Optional.init)
    |> `catch` { _ in
        return .single(nil)
    }
    |> mapToSignal { result in
        guard let result else {
            return .single([])
        }
        return account.postbox.transaction { transaction -> [AdPeer] in
            switch result {
            case let .sponsoredPeers(peers, chats, users):
                let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)
                
                var result: [AdPeer] = []
                for peer in peers {
                    switch peer {
                    case let .sponsoredPeer(_, randomId, apiPeer, sponsorInfo, additionalInfo):
                        guard let peer = parsedPeers.get(apiPeer.peerId) else {
                            continue
                        }
                        result.append(
                            AdPeer(
                                opaqueId: randomId.makeData(),
                                peer: EnginePeer(peer),
                                sponsorInfo: sponsorInfo,
                                additionalInfo: additionalInfo
                            )
                        )
                    }
                }
                return result
            default:
                return []
            }
        }
    }
}


func _internal_markAsSeen(account: Account, opaqueId: Data) -> Signal<Never, NoError> {
    let signal: Signal<Never, NoError> = account.network.request(Api.functions.messages.viewSponsoredMessage(randomId: Buffer(data: opaqueId)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .single(.boolFalse)
    }
    |> ignoreValues
    
    
    return signal
}
