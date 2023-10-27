import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit


public enum WebpagePreviewResult: Equatable {
    public struct Result: Equatable {
        public var webpage: TelegramMediaWebpage
        public var sourceUrl: String
    }
    
    case progress
    case result(Result?)
}

public func webpagePreview(account: Account, urls: [String], webpageId: MediaId? = nil) -> Signal<WebpagePreviewResult, NoError> {
    return webpagePreviewWithProgress(account: account, urls: urls)
    |> mapToSignal { next -> Signal<WebpagePreviewResult, NoError> in
        if case let .result(result) = next {
            return .single(.result(result))
        } else {
            return .single(.progress)
        }
    }
}

public enum WebpagePreviewWithProgressResult {
    case result(WebpagePreviewResult.Result?)
    case progress(Float)
}

public func normalizedWebpagePreviewUrl(url: String) -> String {
    return url
}

public func webpagePreviewWithProgress(account: Account, urls: [String], webpageId: MediaId? = nil) -> Signal<WebpagePreviewWithProgressResult, NoError> {
    return account.postbox.transaction { transaction -> Signal<WebpagePreviewWithProgressResult, NoError> in
        if let webpageId = webpageId, let webpage = transaction.getMedia(webpageId) as? TelegramMediaWebpage, let url = webpage.content.url {
            var sourceUrl = url
            if urls.count == 1 {
                sourceUrl = urls[0]
            }
            return .single(.result(WebpagePreviewResult.Result(webpage: webpage, sourceUrl: sourceUrl)))
        } else {
            return account.network.requestWithAdditionalInfo(Api.functions.messages.getWebPagePreview(flags: 0, message: urls.joined(separator: " "), entities: nil), info: .progress)
            |> `catch` { _ -> Signal<NetworkRequestResult<Api.MessageMedia>, NoError> in
                return .single(.result(.messageMediaEmpty))
            }
            |> mapToSignal { result -> Signal<WebpagePreviewWithProgressResult, NoError> in
                switch result {
                case .acknowledged:
                    return .complete()
                case let .progress(progress, packetSize):
                    if packetSize > 1024 {
                        return .single(.progress(progress))
                    } else {
                        return .complete()
                    }
                case let .result(result):
                    if let preCachedResources = result.preCachedResources {
                        for (resource, data) in preCachedResources {
                            account.postbox.mediaBox.storeResourceData(resource.id, data: data)
                        }
                    }
                    switch result {
                    case let .messageMediaWebPage(flags, webpage):
                        let _ = flags
                        if let media = telegramMediaWebpageFromApiWebpage(webpage), let url = media.content.url {
                            if case .Loaded = media.content {
                                return .single(.result(WebpagePreviewResult.Result(webpage: media, sourceUrl: url)))
                            } else {
                                return .single(.result(WebpagePreviewResult.Result(webpage: media, sourceUrl: url)))
                                |> then(
                                    account.stateManager.updatedWebpage(media.webpageId)
                                    |> take(1)
                                    |> map { next -> WebpagePreviewWithProgressResult in
                                        if let url = next.content.url {
                                            return .result(WebpagePreviewResult.Result(webpage: next, sourceUrl: url))
                                        } else {
                                            return .result(nil)
                                        }
                                    }
                                )
                            }
                        } else {
                            return .single(.result(nil))
                        }
                    default:
                        return .single(.result(nil))
                    }
                }
            }
        }
    }
    |> switchToLatest
}

public func actualizedWebpage(account: Account, webpage: TelegramMediaWebpage) -> Signal<TelegramMediaWebpage, NoError> {
    if case let .Loaded(content) = webpage.content {
        return account.network.request(Api.functions.messages.getWebPage(url: content.url, hash: content.hash))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.WebPage?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<TelegramMediaWebpage, NoError> in
            if let result = result {
                return account.postbox.transaction { transaction -> Signal<TelegramMediaWebpage, NoError> in
                    switch result {
                    case let .webPage(apiWebpage, chats, users):
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: account.peerId, peers: parsedPeers)

                        if let updatedWebpage = telegramMediaWebpageFromApiWebpage(apiWebpage), case .Loaded = updatedWebpage.content, updatedWebpage.webpageId == webpage.webpageId {
                            return .single(updatedWebpage)
                        } else if case let .webPageNotModified(_, viewsValue) = apiWebpage, let views = viewsValue, case let .Loaded(content) = webpage.content {
                            let updatedContent: TelegramMediaWebpageContent = .Loaded(TelegramMediaWebpageLoadedContent(
                                url: content.url,
                                displayUrl: content.displayUrl,
                                hash: content.hash,
                                type: content.type,
                                websiteName: content.websiteName,
                                title: content.title,
                                text: content.text,
                                embedUrl: content.embedUrl,
                                embedType: content.embedType,
                                embedSize: content.embedSize,
                                duration: content.duration,
                                author: content.author,
                                isMediaLargeByDefault: content.isMediaLargeByDefault,
                                image: content.image,
                                file: content.file,
                                story: content.story,
                                attributes: content.attributes,
                                instantPage: content.instantPage.flatMap({ InstantPage(blocks: $0.blocks, media: $0.media, isComplete: $0.isComplete, rtl: $0.rtl, url: $0.url, views: views) })
                            ))
                            let updatedWebpage = TelegramMediaWebpage(webpageId: webpage.webpageId, content: updatedContent)
                            updateMessageMedia(transaction: transaction, id: webpage.webpageId, media: updatedWebpage)
                            return .single(updatedWebpage)
                        }
                    }
                    return .complete()
                }
                |> switchToLatest
            } else {
                return .complete()
            }
        }
    } else {
        return .complete()
    }
}

func updatedRemoteWebpage(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id, webPage: WebpageReference) -> Signal<TelegramMediaWebpage?, NoError> {
    if case let .webPage(id, url) = webPage.content {
        return network.request(Api.functions.messages.getWebPage(url: url, hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.WebPage?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<TelegramMediaWebpage?, NoError> in
            if let result = result, case let .webPage(webpage, chats, users) = result, let updatedWebpage = telegramMediaWebpageFromApiWebpage(webpage), case .Loaded = updatedWebpage.content, updatedWebpage.webpageId.id == id {
                return postbox.transaction { transaction -> TelegramMediaWebpage? in
                    let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                    updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                    if transaction.getMedia(updatedWebpage.webpageId) != nil {
                        updateMessageMedia(transaction: transaction, id: updatedWebpage.webpageId, media: updatedWebpage)
                    }
                    return updatedWebpage
                }
            } else {
                return .single(nil)
            }
        }
    } else {
        return .single(nil)
    }
}
