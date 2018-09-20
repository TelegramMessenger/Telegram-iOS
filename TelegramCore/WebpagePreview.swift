import Foundation
#if os(macOS)
    import PostboxMac
    import SwiftSignalKitMac
    import MtProtoKitMac
#else
    import Postbox
    import SwiftSignalKit
    import MtProtoKitDynamic
#endif

public func webpagePreview(account: Account, url: String, webpageId: MediaId? = nil) -> Signal<TelegramMediaWebpage?, NoError> {
    return account.postbox.transaction { transaction -> Signal<TelegramMediaWebpage?, NoError> in
        if let webpageId = webpageId, let webpage = transaction.getMedia(webpageId) as? TelegramMediaWebpage {
            return .single(webpage)
        } else {
            return account.network.request(Api.functions.messages.getWebPagePreview(flags: 0, message: url, entities: nil))
                |> `catch` { _ -> Signal<Api.MessageMedia, NoError> in
                    return .single(.messageMediaEmpty)
                }
                |> mapToSignal { result -> Signal<TelegramMediaWebpage?, NoError> in
                    switch result {
                        case let .messageMediaWebPage(webpage):
                            if let media = telegramMediaWebpageFromApiWebpage(webpage, url: url) {
                                if case .Loaded = media.content {
                                    return .single(media)
                                } else {
                                    return .single(media) |> then(account.stateManager.updatedWebpage(media.webpageId) |> map(Optional.init))
                                }
                            } else {
                                return .single(nil)
                            }
                        default:
                            return .single(nil)
                    }
                }
        }
    } |> switchToLatest
}

public func actualizedWebpage(postbox: Postbox, network: Network, webpage: TelegramMediaWebpage) -> Signal<TelegramMediaWebpage, NoError> {
    if case let .Loaded(content) = webpage.content {
        return network.request(Api.functions.messages.getWebPage(url: content.url, hash: content.hash))
            |> `catch` { _ -> Signal<Api.WebPage, NoError> in
                return .single(.webPageNotModified)
            }
            |> mapToSignal { result -> Signal<TelegramMediaWebpage, NoError> in
                if let updatedWebpage = telegramMediaWebpageFromApiWebpage(result, url: nil), case .Loaded = updatedWebpage.content, updatedWebpage.webpageId == webpage.webpageId {
                    return postbox.transaction { transaction -> TelegramMediaWebpage in
                        updateMessageMedia(transaction: transaction, id: webpage.webpageId, media: updatedWebpage)
                        return updatedWebpage
                    }
                } else {
                    return .complete()
                }
            }
    } else {
        return .complete()
    }
}

func updatedRemoteWebpage(postbox: Postbox, network: Network, webPage: WebpageReference) -> Signal<TelegramMediaWebpage?, NoError> {
    if case let .webPage(id, url) = webPage.content {
        return network.request(Api.functions.messages.getWebPage(url: url, hash: 0))
        |> `catch` { _ -> Signal<Api.WebPage, NoError> in
            return .single(.webPageNotModified)
        }
        |> mapToSignal { result -> Signal<TelegramMediaWebpage?, NoError> in
            if let updatedWebpage = telegramMediaWebpageFromApiWebpage(result, url: nil), case .Loaded = updatedWebpage.content, updatedWebpage.webpageId.id == id {
                return postbox.transaction { transaction -> TelegramMediaWebpage? in
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
