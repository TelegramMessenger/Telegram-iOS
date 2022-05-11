import Foundation
import Postbox
import TelegramApi
import SwiftSignalKit

public enum SavedStickerResult {
    case generic
    case limitExceeded
}

func _internal_toggleStickerSaved(postbox: Postbox, network: Network, accountPeerId: PeerId, file: TelegramMediaFile, saved: Bool) -> Signal<SavedStickerResult, AddSavedStickerError> {
    if saved {
        return postbox.transaction { transaction -> Signal<SavedStickerResult, AddSavedStickerError> in
            let isPremium = transaction.getPeer(accountPeerId)?.isPremium ?? false
            let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers)
            
            let appConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? .defaultValue
            let userLimitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: isPremium)
            
            return addSavedSticker(postbox: postbox, network: network, file: file)
            |> map { _ -> SavedStickerResult in
                return .generic
            }
            |> then(
                .single(items.count == userLimitsConfiguration.maxFavedStickerCount ? .limitExceeded : .generic)
            )
        }
        |> castError(AddSavedStickerError.self)
        |> switchToLatest
    } else {
        return removeSavedSticker(postbox: postbox, mediaId: file.fileId)
        |> map { _ -> SavedStickerResult in
            return .generic
        }
        |> castError(AddSavedStickerError.self)
    }
}
