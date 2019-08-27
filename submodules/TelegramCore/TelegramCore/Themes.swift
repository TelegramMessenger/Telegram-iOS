import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import TelegramApiMac
#else
    import Postbox
    import SwiftSignalKit
    import TelegramApi
#endif

final class CachedThemesConfiguration: PostboxCoding {
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

#if os(macOS)
private let themeFormat = "macos"
private let themeFileExtension = "palette"
#else
private let themeFormat = "ios"
private let themeFileExtension = "tgios-theme"
#endif

public func telegramThemes(postbox: Postbox, network: Network, forceUpdate: Bool = false) -> Signal<[TelegramTheme], NoError> {
    let fetch: ([TelegramTheme]?, Int32?) -> Signal<[TelegramTheme], NoError> = { current, hash in
        network.request(Api.functions.account.getThemes(format: themeFormat, hash: hash ?? 0))
        |> retryRequest
        |> mapToSignal { result -> Signal<([TelegramTheme], Int32), NoError> in
            switch result {
                case let .themes(hash, themes):
                    let result = themes.compactMap { TelegramTheme(apiTheme: $0) }
                    if result == current {
                        return .complete()
                    } else {
                        return .single((result, hash))
                    }
                case .themesNotModified:
                    return .complete()
            }
        }
        |> mapToSignal { items, hash -> Signal<[TelegramTheme], NoError> in
            return postbox.transaction { transaction -> [TelegramTheme] in
                var entries: [OrderedItemListEntry] = []
                for item in items {
                    var intValue = Int32(entries.count)
                    let id = MemoryBuffer(data: Data(bytes: &intValue, count: 4))
                    entries.append(OrderedItemListEntry(id: id, contents: item))
                }
                transaction.replaceOrderedItemListItems(collectionId: Namespaces.OrderedItemList.CloudThemes, items: entries)
                transaction.putItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedThemesConfiguration, key: ValueBoxKey(length: 0)), entry: CachedThemesConfiguration(hash: hash), collectionSpec: ItemCacheCollectionSpec(lowWaterItemCount: 1, highWaterItemCount: 1))
                return items
            }
        }
    }
    
    if forceUpdate {
        return fetch(nil, nil)
    } else {
        return postbox.transaction { transaction -> ([TelegramTheme], Int32?) in
            let configuration = transaction.retrieveItemCacheEntry(id: ItemCacheEntryId(collectionId: Namespaces.CachedItemCollection.cachedThemesConfiguration, key: ValueBoxKey(length: 0))) as? CachedThemesConfiguration
            let items = transaction.getOrderedListItems(collectionId: Namespaces.OrderedItemList.CloudThemes)
            return (items.map { $0.contents as! TelegramTheme }, configuration?.hash)
        }
        |> mapToSignal { current, hash -> Signal<[TelegramTheme], NoError> in
            return .single(current)
            |> then(fetch(current, hash))
        }
    }
}

public enum GetThemeError {
    case generic
}

public func getTheme(account: Account, slug: String) -> Signal<TelegramTheme, GetThemeError> {
    return account.network.request(Api.functions.account.getTheme(format: themeFormat, theme: .inputThemeSlug(slug: slug), documentId: 0))
    |> mapError { _ -> GetThemeError in return .generic }
    |> mapToSignal { theme -> Signal<TelegramTheme, GetThemeError> in
        if let theme = TelegramTheme(apiTheme: theme) {
            return .single(theme)
        } else {
            return .fail(.generic)
        }
    }
}

public func saveTheme(account: Account, theme: TelegramTheme) -> Signal<Void, NoError> {
    return saveUnsaveTheme(account: account, theme: theme, unsave: false)
}

public func deleteTheme(account: Account, theme: TelegramTheme) -> Signal<Void, NoError> {
    return saveUnsaveTheme(account: account, theme: theme, unsave: true)
}

private func saveUnsaveTheme(account: Account, theme: TelegramTheme, unsave: Bool) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.account.saveTheme(theme: Api.InputTheme.inputTheme(id: theme.id, accessHash: theme.accessHash), unsave: unsave ? Api.Bool.boolTrue : Api.Bool.boolFalse))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .complete()
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .single(Void())
    }
}

public func installTheme(account: Account, theme: TelegramTheme) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.account.installTheme(format: themeFormat, theme: Api.InputTheme.inputTheme(id: theme.id, accessHash: theme.accessHash)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .complete()
    }
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return .complete()
    }
}

public enum UploadThemeStatus {
    case progress(Float)
    case complete(TelegramMediaFile)
}

public enum UploadThemeError {
    case generic
}

private struct UploadedThemeData {
    fileprivate let resource: MediaResource
    fileprivate let content: UploadedThemeDataContent
}

private enum UploadedThemeDataContent {
    case result(MultipartUploadResult)
    case error
}

private func uploadedTheme(postbox: Postbox, network: Network, resource: MediaResource) -> Signal<UploadedThemeData, NoError> {
    return multipartUpload(network: network, postbox: postbox, source: .resource(.standalone(resource: resource)), encrypt: false, tag: TelegramMediaResourceFetchTag(statsCategory: .file), hintFileSize: nil, hintFileIsLarge: false)
    |> map { result -> UploadedThemeData in
        return UploadedThemeData(resource: resource, content: .result(result))
    }
    |> `catch` { _ -> Signal<UploadedThemeData, NoError> in
        return .single(UploadedThemeData(resource: resource, content: .error))
    }
}

private func uploadTheme(account: Account, resource: MediaResource) -> Signal<UploadThemeStatus, UploadThemeError> {
    let fileName = "theme.\(themeFileExtension)"
    let mimeType = "application/x-tgtheme-\(themeFormat)"
    
    return uploadedTheme(postbox: account.postbox, network: account.network, resource: resource)
    |> mapError { _ -> UploadThemeError in return .generic }
    |> mapToSignal { result -> Signal<(UploadThemeStatus, MediaResource?), UploadThemeError> in
        switch result.content {
            case .error:
                return .fail(.generic)
            case let .result(resultData):
                switch resultData {
                    case let .progress(progress):
                        return .single((.progress(progress), result.resource))
                    case let .inputFile(file):
                        return account.network.request(Api.functions.account.uploadTheme(flags: 0, file: file, thumb: nil, fileName: fileName, mimeType: mimeType))
                        |> mapError { _ in return UploadThemeError.generic }
                        |> mapToSignal { document -> Signal<(UploadThemeStatus, MediaResource?), UploadThemeError> in
                            if let file = telegramMediaFileFromApiDocument(document) {
                                return .single((.complete(file), result.resource))
                            } else {
                                return .fail(.generic)
                            }
                        }
                    default:
                        return .fail(.generic)
            }
        }
    }
    |> map { result, _ -> UploadThemeStatus in
        return result
    }
}

public enum CreateThemeError {
    case generic
}

public func createTheme(account: Account, resource: MediaResource, title: String, slug: String) -> Signal<TelegramTheme, CreateThemeError> {
    return uploadTheme(account: account, resource: resource)
    |> mapError { _ in return CreateThemeError.generic }
    |> mapToSignal { status -> Signal<TelegramTheme, CreateThemeError> in
        switch status {
            case let .complete(file):
                if let resource = file.resource as? CloudDocumentMediaResource {
                    return account.network.request(Api.functions.account.createTheme(slug: slug, title: title, document: .inputDocument(id: resource.fileId, accessHash: resource.accessHash, fileReference: Buffer(data: resource.fileReference))))
                    |> mapError { _ in return CreateThemeError.generic }
                    |> mapToSignal { apiTheme -> Signal<TelegramTheme, CreateThemeError> in
                        if let theme = TelegramTheme(apiTheme: apiTheme) {
                            return .single(theme)
                        } else {
                            return .fail(.generic)
                        }
                    }
                }
                else {
                    return .fail(.generic)
                }
            default:
                return .complete()
        }
    }
}

public func updateTheme(account: Account, theme: TelegramTheme, title: String?, slug: String?, resource: MediaResource?) -> Signal<TelegramTheme, CreateThemeError> {
    guard title != nil || slug != nil || resource != nil else {
        return .complete()
    }
    
    var flags: Int32 = 0
    if let _ = title {
        flags |= 1 << 1
    }
    if let _ = slug {
        flags |= 1 << 0
    }
    
    return .never()
    //return account.network.request(Api.functions.account.updateTheme(flags: flags, theme: .inputTheme(id: theme.id, accessHash: theme.accessHash), slug: slug, title: title, document: <#T##Api.InputDocument?#>))
}
