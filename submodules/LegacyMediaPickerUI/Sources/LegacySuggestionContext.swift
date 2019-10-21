import Foundation
import UIKit
import TelegramCore
import SyncCore
import Postbox
import SwiftSignalKit
import LegacyComponents
import LegacyUI
import SearchPeerMembers
import AccountContext

public func legacySuggestionContext(context: AccountContext, peerId: PeerId) -> TGSuggestionContext {
    let suggestionContext = TGSuggestionContext()
    suggestionContext.userListSignal = { query in
        return SSignal { subscriber in
            if let query = query {
                let normalizedQuery = query.lowercased()
                let disposable = searchPeerMembers(context: context, peerId: peerId, query: query).start(next: { peers in
                    let users = NSMutableArray()
                    for peer in peers {
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
    suggestionContext.hashtagListSignal = { query in
        return SSignal { subscriber in
            let disposable = (recentlyUsedHashtags(postbox: context.account.postbox) |> map { hashtags -> [String] in
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
    suggestionContext.alphacodeSignal = { query, inputLanguageCode in
        guard let query = query, let inputLanguageCode = inputLanguageCode else {
            return SSignal.complete()
        }
        return SSignal { subscriber in
            let disposable = (searchEmojiKeywords(postbox: context.account.postbox, inputLanguageCode: inputLanguageCode, query: query, completeMatch: query.count < 3)
            |> map { keywords -> [TGAlphacodeEntry] in
                var result: [TGAlphacodeEntry] = []
                for keyword in keywords {
                    for emoticon in keyword.emoticons {
                        result.append(TGAlphacodeEntry(emoji: emoticon, code: keyword.keyword))
                    }
                }
                return result
            }).start(next: { result in
                subscriber?.putNext(result)
                subscriber?.putCompletion()
            }, error: nil, completed: {
                subscriber?.putCompletion()
            })
            
            return SBlockDisposable {
                disposable.dispose()
            }
        }
    }
    return suggestionContext
}
