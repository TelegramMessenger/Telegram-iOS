import Foundation
#if os(macOS)
import PostboxMac
import SwiftSignalKitMac
#else
import Postbox
import SwiftSignalKit
#endif

public func telegramWallpapers(postbox: Postbox, network: Network) -> Signal<[TelegramWallpaper], NoError> {
    return postbox.transaction { transaction -> [TelegramWallpaper] in
        let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudWallpapers)
        if items.count == 0 {
            return [.builtin]
        } else {
            return items.map { $0.contents as! TelegramWallpaper }
        }
    } |> mapToSignal { list -> Signal<[TelegramWallpaper], NoError> in
        let remote = network.request(Api.functions.account.getWallPapers())
        |> retryRequest
        |> mapToSignal { result -> Signal<[TelegramWallpaper], NoError> in
            var items: [TelegramWallpaper] = []
            for wallpaper in result {
                items.append(TelegramWallpaper(apiWallpaper: wallpaper))
            }
            items.removeFirst()
            items.insert(.builtin, at: 0)
            
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
                    
                    return items
                }
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
                        return account.network.request(Api.functions.account.uploadWallPaper(file: file, mimeType: mimeType))
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
                if case let .file(_, _, _, _, _, file, _) = wallpaper, let resource = resource {
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
