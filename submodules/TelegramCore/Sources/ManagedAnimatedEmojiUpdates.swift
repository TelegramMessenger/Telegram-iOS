import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
import MtProtoKitMac
import TelegramApiMac
#else
import Postbox
import SwiftSignalKit
import TelegramApi
#if BUCK
import MtProtoKit
#else
import MtProtoKitDynamic
#endif
#endif

func managedAnimatedEmojiUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = loadedStickerPack(postbox: postbox, network: network, reference: .animatedEmoji, forceActualized: false)
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
    return (poll |> then(.complete() |> suspendAwareDelay(2.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
