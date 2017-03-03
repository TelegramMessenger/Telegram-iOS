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
        |> map { result -> TelegramMediaWebpage? in
            switch result {
                case let .messageMediaWebPage(webpage):
                    return telegramMediaWebpageFromApiWebpage(webpage)
                default:
                    return nil
            }
        }
}
