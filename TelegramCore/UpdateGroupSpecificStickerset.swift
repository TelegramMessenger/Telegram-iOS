import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
#else
    import Postbox
    import SwiftSignalKit
#endif


public func updateGroupSpecificStickerset(postbox: Postbox, network: Network, peerId:PeerId, info:StickerPackCollectionInfo?) -> Signal<Void, Void> {
    return postbox.loadedPeerWithId(peerId) |> mapToSignal { peer in
        let inputStickerset: Api.InputStickerSet
        if let info = info {
            inputStickerset = Api.InputStickerSet.inputStickerSetShortName(shortName: info.shortName)
        } else {
            inputStickerset = Api.InputStickerSet.inputStickerSetEmpty
        }
        if let inputChannel = apiInputChannel(peer) {
            let api = Api.functions.channels.setStickers(channel: inputChannel, stickerset: inputStickerset)
            return network.request(api) |> retryRequest |> mapToSignal { value in
                switch value {
                case .boolTrue:
                    return postbox.modify { modifier -> Void in
                        return modifier.updatePeerCachedData(peerIds: [peerId], update: { _, current -> CachedPeerData? in
                            return (current as? CachedChannelData)?.withUpdatedStickerPack(info)
                        })
                    }
                default:
                    return .complete()
                }
            }
        }
        return .complete()
    }
}
