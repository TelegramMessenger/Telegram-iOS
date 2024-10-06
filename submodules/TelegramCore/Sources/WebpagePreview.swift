import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit
import LinkPresentation
#if os(iOS)
import UIKit
#endif
import CoreServices

public enum WebpagePreviewResult: Equatable {
    public struct Result: Equatable {
        public var webpage: TelegramMediaWebpage
        public var sourceUrl: String
    }
    
    case progress
    case result(Result?)
}
#if os(macOS)
private typealias UIImage = NSImage
#endif


public func webpagePreview(account: Account, urls: [String], webpageId: MediaId? = nil, forPeerId: PeerId? = nil) -> Signal<WebpagePreviewResult, NoError> {
    return webpagePreviewWithProgress(account: account, urls: urls, webpageId: webpageId, forPeerId: forPeerId)
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

public func webpagePreviewWithProgress(account: Account, urls: [String], webpageId: MediaId? = nil, forPeerId: PeerId? = nil) -> Signal<WebpagePreviewWithProgressResult, NoError> {
    return account.postbox.transaction { transaction -> Signal<WebpagePreviewWithProgressResult, NoError> in
        if let webpageId = webpageId, let webpage = transaction.getMedia(webpageId) as? TelegramMediaWebpage, let url = webpage.content.url {
            var sourceUrl = url
            if urls.count == 1 {
                sourceUrl = urls[0]
            }
            return .single(.result(WebpagePreviewResult.Result(webpage: webpage, sourceUrl: sourceUrl)))
        } else {
            if #available(iOS 13.0, macOS 10.15, *) {
                if let forPeerId, forPeerId.namespace == Namespaces.Peer.SecretChat, let sourceUrl = urls.first, let url = URL(string: sourceUrl) {
                    let localHosts: [String] = [
                        "twitter.com",
                        "www.twitter.com",
                        "instagram.com",
                        "www.instagram.com",
                        "tiktok.com",
                        "www.tiktok.com"
                    ]
                    if let host = url.host?.lowercased(), localHosts.contains(host) {
                        return Signal { subscriber in
                            subscriber.putNext(.progress(0.0))
                            
                            let metadataProvider = LPMetadataProvider()
                            metadataProvider.shouldFetchSubresources = true
                            metadataProvider.startFetchingMetadata(for: url, completionHandler: { metadata, _ in
                                if let metadata = metadata {
                                    let completeWithImage: (Data?) -> Void = { imageData in
                                        var image: TelegramMediaImage?
                                        if let imageData, let parsedImage = UIImage(data: imageData) {
                                            let resource = LocalFileMediaResource(fileId: Int64.random(in: Int64.min ... Int64.max))
                                            account.postbox.mediaBox.storeResourceData(resource.id, data: imageData)
                                            image = TelegramMediaImage(
                                                imageId: MediaId(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: Int64.min ... Int64.max)),
                                                representations: [
                                                    TelegramMediaImageRepresentation(
                                                        dimensions: PixelDimensions(width: Int32(parsedImage.size.width), height: Int32(parsedImage.size.height)),
                                                        resource: resource,
                                                        progressiveSizes: [],
                                                        immediateThumbnailData: nil,
                                                        hasVideo: false,
                                                        isPersonal: false
                                                    )
                                                ],
                                                immediateThumbnailData: nil,
                                                reference: nil,
                                                partialReference: nil,
                                                flags: []
                                            )
                                        }
                                        
                                        var webpageType: String?
                                        if image != nil {
                                            webpageType = "photo"
                                        }
                                        
                                        let webpage = TelegramMediaWebpage(
                                            webpageId: MediaId(namespace: Namespaces.Media.LocalWebpage, id: Int64.random(in: Int64.min ... Int64.max)),
                                            content: .Loaded(TelegramMediaWebpageLoadedContent(
                                                url: sourceUrl,
                                                displayUrl: metadata.url?.absoluteString ?? sourceUrl,
                                                hash: 0,
                                                type: webpageType,
                                                websiteName: nil,
                                                title: metadata.title,
                                                text: metadata.value(forKey: "_summary") as? String,
                                                embedUrl: nil,
                                                embedType: nil,
                                                embedSize: nil,
                                                duration: nil,
                                                author: nil,
                                                isMediaLargeByDefault: true,
                                                image: image,
                                                file: nil,
                                                story: nil,
                                                attributes: [],
                                                instantPage: nil
                                            ))
                                        )
                                        subscriber.putNext(.result(WebpagePreviewResult.Result(
                                            webpage: webpage,
                                            sourceUrl: sourceUrl
                                        )))
                                        subscriber.putCompletion()
                                    }
                                    
                                    if let imageProvider = metadata.imageProvider {
                                        imageProvider.loadFileRepresentation(forTypeIdentifier: kUTTypeImage as String, completionHandler: { imageUrl, _ in
                                            guard let imageUrl, let imageData = try? Data(contentsOf: imageUrl) else {
                                                completeWithImage(nil)
                                                return
                                            }
                                            completeWithImage(imageData)
                                        })
                                    } else {
                                        completeWithImage(nil)
                                    }
                                } else {
                                    subscriber.putNext(.result(nil))
                                    subscriber.putCompletion()
                                }
                            })
                            
                            return ActionDisposable {
                                metadataProvider.cancel()
                            }
                        }
                    }
                }
            }
            
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

public func updatedRemoteWebpage(postbox: Postbox, network: Network, accountPeerId: EnginePeer.Id, webPage: WebpageReference) -> Signal<TelegramMediaWebpage?, NoError> {
    if case let .webPage(id, url) = webPage.content {
        return network.request(Api.functions.messages.getWebPage(url: url, hash: 0))
        |> map(Optional.init)
        |> `catch` { _ -> Signal<Api.messages.WebPage?, NoError> in
            return .single(nil)
        }
        |> mapToSignal { result -> Signal<TelegramMediaWebpage?, NoError> in
            if let result = result, case let .webPage(webpage, chats, users) = result, let updatedWebpage = telegramMediaWebpageFromApiWebpage(webpage), case .Loaded = updatedWebpage.content {
                if updatedWebpage.webpageId.id == id {
                    return postbox.transaction { transaction -> TelegramMediaWebpage? in
                        let parsedPeers = AccumulatedPeers(transaction: transaction, chats: chats, users: users)
                        updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: parsedPeers)
                        if transaction.getMedia(updatedWebpage.webpageId) != nil {
                            updateMessageMedia(transaction: transaction, id: updatedWebpage.webpageId, media: updatedWebpage)
                        }
                        return updatedWebpage
                    }
                } else if id == 0 {
                    return .single(updatedWebpage)
                } else {
                    return .single(nil)
                }
            } else {
                return .single(nil)
            }
        }
    } else {
        return .single(nil)
    }
}
