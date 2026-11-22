import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi

/// `feed.likePost` / `feed.dislikePost` for a stored post. A failure is logged and dropped: there is nothing to
/// retry it against, and the next vote on the post replaces it on the server.
func _internal_voteFeedPost(account: Account, id: MessageId, like: Bool) -> Signal<Never, NoError> {
#if TELEGRAM_NEWS_FEED_API
    let method = like ? "likePost" : "dislikePost"
    return account.postbox.transaction { transaction -> Api.InputPeer? in
        return transaction.getPeer(id.peerId).flatMap(apiInputPeer)
    }
    |> mapToSignal { inputPeer -> Signal<Never, NoError> in
        guard let inputPeer else {
            Logger.shared.log("ForYouFeed", "\(method) \(id): no peer")
            return .complete()
        }
        let request = like ? Api.functions.feed.likePost(peer: inputPeer, msgId: id.id) : Api.functions.feed.dislikePost(peer: inputPeer, msgId: id.id)
        return account.network.request(request)
        |> `catch` { error -> Signal<Api.Bool, NoError> in
            Logger.shared.log("ForYouFeed", "\(method) \(id): \(error.errorDescription ?? "error")")
            return .complete()
        }
        |> mapToSignal { _ -> Signal<Never, NoError> in
            Logger.shared.log("ForYouFeed", "\(method) \(id): ok")
            return .complete()
        }
    }
#else
    // The feed API is parked (layer 233 has none): nothing is sent.
    return .complete()
#endif
}
