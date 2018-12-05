import Foundation
import TelegramCore
import Postbox
import SwiftSignalKit

import TelegramUIPrivateModule
import LegacyComponents

func legacySuggestionContext(account: Account, peerId: PeerId) -> TGSuggestionContext {
    let context = TGSuggestionContext()
    context.userListSignal = { query in
        return SSignal { subscriber in
            if let query = query {
                let normalizedQuery = query.lowercased()
                let disposable = peerParticipants(postbox: account.postbox, id: peerId).start(next: { peers in
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
    context.hashtagListSignal = { query in
        return SSignal { subscriber in
            let disposable = (recentlyUsedHashtags(postbox: account.postbox) |> map { hashtags -> [String] in
                let normalizedQuery = query?.lowercased()
                var result: [String] = []
                if let normalizedQuery = normalizedQuery {
                    for hashtag in hashtags {
                        if hashtag.lowercased().hasPrefix(normalizedQuery) {
                            result.append(hashtag)
                        }
                    }
                }
                return result
            }
            |> take(1)
            |> deliverOnMainQueue).start(next: { hashtags in
                subscriber?.putNext(hashtags)
                subscriber?.putCompletion()
            })
            
            return SBlockDisposable {
                disposable.dispose()
            }
        }
    }
    context.alphacodeSignal = { query in
        return SSignal { subscriber in
            subscriber?.putNext(TGEmojiSuggestions.suggestions(forQuery: query?.lowercased()))
            subscriber?.putCompletion()
            return nil
        }
    }
    return context
}
