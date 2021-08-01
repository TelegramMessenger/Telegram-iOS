import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit


public enum UpdateGroupSpecificStickersetError {
    case generic
}

func _internal_updateGroupSpecificStickerset(postbox: Postbox, network: Network, peerId: PeerId, info: StickerPackCollectionInfo?) -> Signal<Void, UpdateGroupSpecificStickersetError> {
    return postbox.loadedPeerWithId(peerId)
    |> castError(UpdateGroupSpecificStickersetError.self)
    |> mapToSignal { peer -> Signal<Void, UpdateGroupSpecificStickersetError> in
        let inputStickerset: Api.InputStickerSet
        if let info = info {
            inputStickerset = Api.InputStickerSet.inputStickerSetShortName(shortName: info.shortName)
        } else {
            inputStickerset = Api.InputStickerSet.inputStickerSetEmpty
        }
        if let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.setStickers(channel: inputChannel, stickerset: inputStickerset))
            |> mapError { _ -> UpdateGroupSpecificStickersetError in
                return .generic
            }
            |> mapToSignal { value -> Signal<Void, UpdateGroupSpecificStickersetError> in
                switch value {
                    case .boolTrue:
                        return postbox.transaction { transaction -> Void in
                            return transaction.updatePeerCachedData(peerIds: [peerId], update: { _, current -> CachedPeerData? in
                                return (current as? CachedChannelData)?.withUpdatedStickerPack(info)
                            })
                        }
                    |> castError(UpdateGroupSpecificStickersetError.self)
                    default:
                        return .complete()
                }
            }
        }
        return .complete()
    }
}
