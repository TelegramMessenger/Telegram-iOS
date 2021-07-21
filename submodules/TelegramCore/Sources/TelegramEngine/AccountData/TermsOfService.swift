import Foundation
import TelegramApi
import Postbox
import SwiftSignalKit
import MtProtoKit


public struct TermsOfServiceUpdate: Equatable {
    public let id: String
    public let text: String
    public let entities: [MessageTextEntity]
    public let ageConfirmation: Int32?
    
    init(id: String, text: String, entities: [MessageTextEntity], ageConfirmation: Int32?) {
        self.id = id
        self.text = text
        self.entities = entities
        self.ageConfirmation = ageConfirmation
    }
}

extension TermsOfServiceUpdate {
    init?(apiTermsOfService: Api.help.TermsOfService) {
        switch apiTermsOfService {
            case let .termsOfService(_, id, text, entities, minAgeConfirm):
                let idData: String
                switch id {
                case let .dataJSON(data):
                    idData = data
                }
                self.init(id: idData, text: text, entities: messageTextEntitiesFromApiEntities(entities), ageConfirmation: minAgeConfirm)
        }
    }
}

func _internal_acceptTermsOfService(account: Account, id: String) -> Signal<Void, NoError> {
    return account.network.request(Api.functions.help.acceptTermsOfService(id: .dataJSON(data: id)))
    |> `catch` { _ -> Signal<Api.Bool, NoError> in
        return .complete()
    }
    |> mapToSignal { [weak account] _ -> Signal<Void, NoError> in
        account?.stateManager.modifyTermsOfServiceUpdate({ _ in nil })
        return .complete()
    }
}

func _internal_resetAccountDueTermsOfService(network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.account.deleteAccount(reason: "Decline ToS update"))
    |> retryRequest
    |> map { _ in return }
}

func managedTermsOfServiceUpdates(postbox: Postbox, network: Network, stateManager: AccountStateManager) -> Signal<Void, NoError> {
    let poll = network.request(Api.functions.help.getTermsOfServiceUpdate())
    |> retryRequest
    |> mapToSignal { [weak stateManager] result -> Signal<Void, NoError> in
        var updated: TermsOfServiceUpdate?
        switch result {
            case let .termsOfServiceUpdate(_, termsOfService):
                updated = TermsOfServiceUpdate(apiTermsOfService: termsOfService)
            case .termsOfServiceUpdateEmpty:
                break
        }
        stateManager?.modifyTermsOfServiceUpdate { _ in
            return updated
        }
        return .complete()
    }
    
    return (poll |> then(.complete() |> suspendAwareDelay(1.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

