import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

final class CachedWallpapersConfiguration: PostboxCoding {
    let hash: Int32
    
    init(hash: Int32) {
        self.hash = hash
    }
    
    init(decoder: PostboxDecoder) {
        self.hash = decoder.decodeInt32ForKey("hash", orElse: 0)
    }
    
    func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.hash, forKey: "hash")
    }
}

public func telegramWallpapers(postbox: Postbox, network: Network) -> Signal<[TelegramWallpaper], NoError> {
    return postbox.transaction { transaction -> ([TelegramWallpaper], Int32?) in
        let configuration = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedWallpapersConfiguration, key: ValueBoxKey(length: 0))) as? CachedWallpapersConfiguration
        let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers)
        if items.count == 0 {
            return ([.builtin], 0)
        } else {
            return (items.map { $0.contents as! TelegramWallpaper }, configuration?.hash)
        }
    }
    |> mapToSignal { list, hash -> Signal<[TelegramWallpaper], NoError> in
        let remote = network.request(Api.functions.account.getWallPapers(hash: hash ?? 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<[TelegramWallpaper], NoError> in
            switch result {
                case let .wallPapers(hash, wallpapers):
                    var items: [TelegramWallpaper] = []
                    var addedBuiltin = false
                    for apiWallpaper in wallpapers {
                        let wallpaper = TelegramWallpaper(apiWallpaper: apiWallpaper)
                        if case let .file(_, _, _, isDefault, _, _, _, _) = wallpaper, !isDefault {
                        } else if !addedBuiltin {
                            addedBuiltin = true
                            items.append(.builtin)
                        }
                        items.append(wallpaper)
                    }
                    
                    if !addedBuiltin {
                        addedBuiltin = true
                        items.append(.builtin)
                    }
                    
                    if items == list {
                        return .complete()
                    } else {
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
                case .wallPapersNotModified:
                    return .complete()
            }
        }
        return .single(list)
        |> then(remote)
    }
}

public enum UploadWallpaperStatus {
    case progress(Float)
    case complete(TelegramWallpaper)
}

public enum UploadWallpaperError {
    case generic
}

public struct UploadedWallpaperData {
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

public func uploadWallpaper(account: Account, resource: MediaResource, mimeType: String = "image/jpeg") -> Signal<UploadWallpaperStatus, UploadWallpaperError> {
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
                        return account.network.request(Api.functions.account.uploadWallPaper(file: file, mimeType: mimeType, settings: apiWallpaperSettings(WallpaperSettings())))
                        |> mapError {_ in return UploadWallpaperError.generic}
                        |> mapToSignal { wallpaper -> Signal<(UploadWallpaperStatus, MediaResource?), UploadWallpaperError> in
                            return .single((.complete(TelegramWallpaper(apiWallpaper: wallpaper)), result.resource))
                        }
                    default:
                        return .fail(.generic)
                }
        }
    }
    |> map { result, resource -> UploadWallpaperStatus in
        switch result {
            case let .complete(wallpaper):
                if case let .file(_, _, _, _, _, _, file, _) = wallpaper, let resource = resource {
                    account.postbox.mediaBox.moveResourceData(from: resource.id, to: file.resource.id)
                }
            default:
                break
        }
        return result
    }
}

public enum GetWallpaperError {
    case generic
}

public func getWallpaper(account: Account, slug: String) -> Signal<TelegramWallpaper, GetWallpaperError> {
    return account.network.request(Api.functions.account.getWallPaper(wallpaper: .inputWallPaperSlug(slug: slug)))
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
    guard case let .file(_, _, _, _, _, slug, _, settings) = wallpaper else {
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
    guard case let .file(_, _, _, _, _, slug, _, settings) = wallpaper else {
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
