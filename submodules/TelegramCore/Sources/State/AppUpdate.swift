import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit
import TelegramApi


public struct AppUpdateInfo: Equatable {
    public let blocking: Bool
    public let version: String
    public let text: String
    public let entities: [MessageTextEntity]
}

extension AppUpdateInfo {
    init?(apiAppUpdate: Api.help.AppUpdate) {
        switch apiAppUpdate {
            case let .appUpdate(flags, _, version, text, entities, _, _, _):
                self.blocking = (flags & (1 << 0)) != 0
                self.version = version
                self.text = text
                self.entities = messageTextEntitiesFromApiEntities(entities)
            case .noAppUpdate:
                return nil
        }
    }
}

func managedAppUpdateInfo(network: Network, stateManager: AccountStateManager) -> Signal<Never, NoError> {
    let poll = network.request(Api.functions.help.getAppUpdate(source: ""))
    |> retryRequest
    |> mapToSignal { [weak stateManager] result -> Signal<Never, NoError> in
        let updated = AppUpdateInfo(apiAppUpdate: result)
        stateManager?.modifyAppUpdateInfo { _ in
            return updated
        }
        return .complete()
    }
    
    return (poll |> then(.complete() |> suspendAwareDelay(12.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}
