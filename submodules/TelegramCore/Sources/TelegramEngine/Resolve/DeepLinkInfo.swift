import Foundation
import SwiftSignalKit
import TelegramApi


public struct DeepLinkInfo {
    public let message: String
    public let entities: [MessageTextEntity]
    public let updateApp: Bool
}

func _internal_getDeepLinkInfo(network: Network, path: String) -> Signal<DeepLinkInfo?, NoError> {
    return network.request(Api.functions.help.getDeepLinkInfo(path: path)) |> retryRequest
    |> map { value -> DeepLinkInfo? in
        switch value {
            case .deepLinkInfoEmpty:
                return nil
            case let .deepLinkInfo(flags, message, entities):
                return DeepLinkInfo(message: message, entities: entities != nil ? messageTextEntitiesFromApiEntities(entities!) : [], updateApp: (flags & (1 << 0)) != 0)
        }
    }
}
