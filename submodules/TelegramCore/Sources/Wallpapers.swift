import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi

import SyncCore

public func telegramWallpapers(postbox: Postbox, network: Network, forceUpdate: Bool = false) -> Signal<[TelegramWallpaper], NoError> {
    let fetch: ([TelegramWallpaper]?, Int32?) -> Signal<[TelegramWallpaper], NoError> = { current, hash in
        network.request(Api.functions.account.getWallPapers(hash: hash ?? 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<([TelegramWallpaper], Int32), NoError> in
            switch result {
                case let .wallPapers(hash, wallpapers):
                    var items: [TelegramWallpaper] = []
                    var addedBuiltin = false
                    for apiWallpaper in wallpapers {
                        let wallpaper = TelegramWallpaper(apiWallpaper: apiWallpaper)
                        if case let .file(file) = wallpaper, !file.isDefault {
                        } else if !addedBuiltin {
                            addedBuiltin = true
                            items.append(.builtin(WallpaperSettings()))
                        }
                        items.append(wallpaper)
                    }
                    
                    if !addedBuiltin {
                        addedBuiltin = true
                        items.append(.builtin(WallpaperSettings()))
                    }
                    
                    if items == current {
                        return .complete()
                    } else {
                        return .single((items, hash))
                    }
                case .wallPapersNotModified:
                    return .complete()
            }
        }
        |> mapToSignal { items, hash -> Signal<[TelegramWallpaper], NoError> in
            return postbox.transaction { transaction -> [TelegramWallpaper] in
                var entries: [OrderedItemListEntry] = []
                for item in items {
                    var intValue = Int32(entries.count)
                    let id = MemoryBuffer(data: Data(bytes: &intValue, count: 4))
                    entries.append(OrderedItemListEntry(id: id, contents: item))
                }
                transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers, items: entries)
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedWallpapersConfiguration, key: ValueBoxKey(length: 0)), entry: CachedWallpapersConfiguration(hash: hash), collectionSpec: ItemCacheCollectionSpec(lowWaterItemCount: 1, highWaterItemCount: 1))
                return items
            }
        }
    }
    
    if forceUpdate {
        return fetch(nil, nil)
    } else {
        return postbox.transaction { transaction -> ([TelegramWallpaper], Int32?) in
            let configuration = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedWallpapersConfiguration, key: ValueBoxKey(length: 0))) as? CachedWallpapersConfiguration
            let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers)
            if items.count == 0 {
                return ([.builtin(WallpaperSettings())], 0)
            } else {
                return (items.map { $0.contents as! TelegramWallpaper }, configuration?.hash)
            }
        }
        |> mapToSignal { current, hash -> Signal<[TelegramWallpaper], NoError> in
            return .single(current)
            |> then(fetch(current, hash))
        }
    }
}

public enum UploadWallpaperStatus {
    case progress(Float)
    case complete(TelegramWallpaper)
}

public enum UploadWallpaperError {
    case generic
}

private struct UploadedWallpaperData {
    fileprivate let resource: MediaResource
    fileprivate let content: UploadedWallpaperDataContent
}

private enum UploadedWallpaperDataContent {
    case result(MultipartUploadResult)
    case error
}

private func uploadedWallpaper(postbox: Postbox, network: Network, resource: MediaResource) -> Signal<UploadedWallpaperData, NoError> {
    return multipartUpload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .image), hintFileSize: nil, hintFileIsLarge: false)
    |> map { result -> UploadedWallpaperData in
        return UploadedWallpaperData(resource: resource, content: .result(result))
    }
    |> `catch` { _ -> Signal<UploadedWallpaperData, NoError> in
        return .single(UploadedWallpaperData(resource: resource, content: .error))
    }
}

public func uploadWallpaper(account: Account, resource: MediaResource, mimeType: String = "image/jpeg", settings: WallpaperSettings) -> Signal<UploadWallpaperStatus, UploadWallpaperError> {
    return uploadedWallpaper(postbox: account.postbox, network: account.network, resource: resource)
    |> mapError { _ -> UploadWallpaperError in return .generic }
    |> mapToSignal { result -> Signal<(UploadWallpaperStatus, MediaResource?), UploadWallpaperError> in
        switch result.content {
            case .error:
                return .fail(.generic)
            case let .result(resultData):
                switch resultData {
                    case let .progress(progress):
                        return .single((.progress(progress), result.resource))
                    case let .inputFile(file):
                        return account.network.request(Api.functions.account.uploadWallPaper(file: file, mimeType: mimeType, settings: apiWallpaperSettings(settings)))
                        |> mapError { _ in return UploadWallpaperError.generic }
                        |> map { wallpaper -> (UploadWallpaperStatus, MediaResource?) in
                            return (.complete(TelegramWallpaper(apiWallpaper: wallpaper)), result.resource)
                        }
                    default:
                        return .fail(.generic)
                }
        }
    }
    |> map { result, _ -> UploadWallpaperStatus in
        return result
    }
}

public enum GetWallpaperError {
    case generic
}

public func getWallpaper(network: Network, slug: String) -> Signal<TelegramWallpaper, GetWallpaperError> {
    return network.request(Api.functions.account.getWallPaper(wallpaper: .inputWallPaperSlug(slug: slug)))
    |> mapError { _ -> GetWallpaperError in return .generic }
    |> map { wallpaper -> TelegramWallpaper in
        return TelegramWallpaper(apiWallpaper: wallpaper)
    }
}

public func saveWallpaper(account: Account, wallpaper: TelegramWallpaper) -> Signal<Void, NoError> {
    return saveUnsaveWallpaper(account: account, wallpaper: wallpaper, unsave: false)
}

public func deleteWallpaper(account: Account, wallpaper: TelegramWallpaper) -> Signal<Void, NoError> {
    return saveUnsaveWallpaper(account: account, wallpaper: wallpaper, unsave: true)
}

private func saveUnsaveWallpaper(account: Account, wallpaper: TelegramWallpaper, unsave: Bool) -> Signal<Void, NoError> {
    guard case let .file(_, _, _, _, _, _, slug, _, settings) = wallpaper else {
        return .complete()
    }
    return account.network.request(Api.functions.account.saveWallPaper(wallpaper: Api.InputWallPaper.inputWallPaperSlug(slug: slug), unsave: unsave ? Api.Bool.boolTrue : Api.Bool.boolFalse, settings: apiWallpaperSettings(settings)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .complete()
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
}

public func installWallpaper(account: Account, wallpaper: TelegramWallpaper) -> Signal<Void, NoError> {
    guard case let .file(_, _, _, _, _, _, slug, _, settings) = wallpaper else {
        return .complete()
    }
    return account.network.request(Api.functions.account.installWallPaper(wallpaper: Api.InputWallPaper.inputWallPaperSlug(slug: slug), settings: apiWallpaperSettings(settings)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .complete()
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
}

public func resetWallpapers(account: Account) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.account.resetWallPapers())
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .complete()
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
}
