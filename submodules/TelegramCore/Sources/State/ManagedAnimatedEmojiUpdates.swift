import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func managedAnimatedEmojiUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = _internal_loadedStickerPack(postbox: postbox, network: network, reference: .animatedEmoji, forceActualized: true)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedAnimatedEmojiAnimationsUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = _internal_loadedStickerPack(postbox: postbox, network: network, reference: .animatedEmojiAnimations, forceActualized: true)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

func managedGenericEmojiEffects(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = _internal_loadedStickerPack(postbox: postbox, network: network, reference: .emojiGenericAnimations, forceActualized: true)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
