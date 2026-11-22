import Foundation
import Postbox
internal import TelegramApi
import SwiftSignalKit

public enum SavedStickerResult {
    case generic
    case limitExceeded(Int32, Int32)
}

func _internal_toggleStickerSaved(postbox: Postbox, network: Network, accountPeerId: PeerId, file: TelegramMediaFile, saved: Bool) -> Signal<SavedStickerResult, AddSavedStickerError> {
    if saved {
        return _internal_saveStickerWithResult(postbox: postbox, network: network, accountPeerId: accountPeerId, file: file)
        |> map { $0.result }
    } else {
        return removeSavedSticker(postbox: postbox, mediaId: file.fileId)
        |> map { _ -> SavedStickerResult in
            return .generic
        }
        |> castError(AddSavedStickerError.self)
    }
}

public struct SavedStickerUpdateResult {
    public let result: SavedStickerResult
    public let locallyApplied: Bool
}

func _internal_saveStickerWithResult(postbox: Postbox, network: Network, accountPeerId: PeerId, file: TelegramMediaFile) -> Signal<SavedStickerUpdateResult, AddSavedStickerError> {
    return postbox.transaction { transaction -> Signal<SavedStickerUpdateResult, AddSavedStickerError> in
        let isPremium = transaction.getPeer(accountPeerId)?.isPremium ?? false
        let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudSavedStickers)

        let appConfiguration = transaction.getPreferencesEntry(key: PreferencesKeys.appConfiguration)?.get(AppConfiguration.self) ?? .defaultValue
        let limitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: false)
        let premiumLimitsConfiguration = UserLimitsConfiguration(appConfiguration: appConfiguration, isPremium: true)

        let result: SavedStickerResult
        if isPremium && items.count >= premiumLimitsConfiguration.maxFavedStickerCount {
            result = .limitExceeded(premiumLimitsConfiguration.maxFavedStickerCount, premiumLimitsConfiguration.maxFavedStickerCount)
        } else if !isPremium && items.count >= limitsConfiguration.maxFavedStickerCount {
            result = .limitExceeded(limitsConfiguration.maxFavedStickerCount, premiumLimitsConfiguration.maxFavedStickerCount)
        } else {
            result = .generic
        }

        return addSavedStickerWithResult(postbox: postbox, network: network, file: file, limit: Int(isPremium ? premiumLimitsConfiguration.maxFavedStickerCount : limitsConfiguration.maxFavedStickerCount))
        |> map { locallyApplied in
            return SavedStickerUpdateResult(result: result, locallyApplied: locallyApplied)
        }
    }
    |> castError(AddSavedStickerError.self)
    |> switchToLatest
}
