import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

func managedAnimatedEmojiUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = loadedStickerPack(postbox: postbox, network: network, reference: .animatedEmoji, forceActualized: false)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
