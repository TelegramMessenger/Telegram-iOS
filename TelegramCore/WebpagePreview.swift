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

public func webpagePreview(account: Account, url: String) -> Signal<TelegramMediaWebpage?, NoError> {
    return account.network.request(Api.functions.messages.getWebPagePreview(message: url))
        |> `catch` { _ -> Signal<Api.MessageMedia, NoError> in
            return .single(.messageMediaEmpty)
        }
        |> mapToSignal { result -> Signal<TelegramMediaWebpage?, NoError> in
            switch result {
                case let .messageMediaWebPage(webpage):
                    if let media = telegramMediaWebpageFromApiWebpage(webpage) {
                        if case .Loaded = media.content {
                            return .single(media)
                        } else {
                            return .single(media) |> then(account.stateManager.updatedWebpage(media.webpageId) |> map { Optional($0) })
                        }
                    } else {
                        return .single(nil)
                    }
                default:
                    return .single(nil)
            }
        }
}

public func actualizedWebpage(postbox: Postbox, network: Network, webpage: TelegramMediaWebpage) -> Signal<TelegramMediaWebpage, NoError> {
    if case let .Loaded(content) = webpage.content {
        return network.request(Api.functions.messages.getWebPage(url: content.url, hash: content.hash))
            |> `catch` { _ -> Signal<Api.WebPage, NoError> in
                return .single(.webPageNotModified)
            }
            |> mapToSignal { result -> Signal<TelegramMediaWebpage, NoError> in
                if let updatedWebpage = telegramMediaWebpageFromApiWebpage(result), case .Loaded = updatedWebpage.content {
                    return postbox.modify { modifier -> TelegramMediaWebpage in
                        modifier.updateMedia(updatedWebpage.webpageId, update: updatedWebpage)
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
