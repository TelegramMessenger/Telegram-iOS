import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit
import LegacyComponents

func legacySuggestionContext(account: Account, peerId: PeerId) -> TGSuggestionContext {
    let context = TGSuggestionContext()
    context.userListSignal = { mention in
        return SSignal { subscriber in
            if let mention = mention {
                let normalizedQuery = mention.lowercased()
                let disposable = peerParticipants(account: account, id: peerId).start(next: { peers in
                    let filteredPeers = peers.filter { peer in
                        if peer.indexName.matchesByTokens(normalizedQuery) {
                            return true
                        }
                        if let addressName = peer.addressName, addressName.lowercased().hasPrefix(normalizedQuery) {
                            return true
                        }
                        return false
                    }
                    let sortedPeers = filteredPeers.sorted(by: { lhs, rhs in
                        let result = lhs.indexName.indexName(.lastNameFirst).compare(rhs.indexName.indexName(.lastNameFirst))
                        return result == .orderedAscending
                    })
                    
                    let users = NSMutableArray()
                    for peer in sortedPeers {
                        let user = TGUser()
                        if let peer = peer as? TelegramUser {
                            user.uid = peer.id.id
                            user.firstName = peer.firstName
                            user.lastName = peer.lastName
                            user.userName = peer.addressName
                            if let representation = smallestImageRepresentation(peer.photo) {
                                user.photoUrlSmall = legacyImageLocationUri(resource: representation.resource)
                            }
                            users.add(user)
                        }
                    }
                    
                    subscriber?.putNext(users)
                    subscriber?.putCompletion()
                })
                
                return SBlockDisposable {
                    disposable.dispose()
                }
            } else {
                subscriber?.putNext(NSArray())
                subscriber?.putCompletion()
                return nil
            }
        }
    }
    return context
}
