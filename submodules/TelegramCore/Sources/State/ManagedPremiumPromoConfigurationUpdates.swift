import Foundation
import Postbox
import SwiftSignalKit
import TelegramApi
import MtProtoKit

public func updatePremiumPromoConfigurationOnce(account: Account) -> Signal<Void, NoError> {
    return updatePremiumPromoConfigurationOnce(postbox: account.postbox, network: account.network)
}

func updatePremiumPromoConfigurationOnce(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    return network.request(Api.functions.help.getPremiumPromo())
    |> map(Optional.init)
    |> `catch` { _ -> Signal<Api.help.PremiumPromo?, NoError> in
        return .single(nil)
    }
    |> mapToSignal { result -> Signal<Void, NoError> in
        guard let result = result else {
            return .complete()
        }
        return postbox.transaction { transaction -> Void in
            if case let .premiumPromo(_, _, _, _, _, _, apiUsers) = result {
                let users = apiUsers.map { TelegramUser(user: $0) }
                updatePeers(transaction: transaction, peers: users, update: { current, updated -> Peer in
                    if let updated = updated as? TelegramUser {
                        return TelegramUser.merge(lhs: current as? TelegramUser, rhs: updated)
                    } else {
                        return updated
                    }
                })
            }
            
            updatePremiumPromoConfiguration(transaction: transaction, { configuration -> PremiumPromoConfiguration in
                return PremiumPromoConfiguration(apiPremiumPromo: result)
            })
        }
    }
}

func managedPremiumPromoConfigurationUpdates(postbox: Postbox, network: Network) -> Signal<Void, NoError> {
    let poll = Signal<Void, NoError> { subscriber in
        return updatePremiumPromoConfigurationOnce(postbox: postbox, network: network).start(completed: {
            subscriber.putCompletion()
        })
    }
    return (poll |> then(.complete() |> suspendAwareDelay(10.0 * 60.0 * 60.0, queue: Queue.concurrentDefaultQueue()))) |> restart
}

private func currentPremiumPromoConfiguration(transaction: Transaction) -> PremiumPromoConfiguration {
    if let entry = transaction.getPreferencesEntry(key: PreferencesKeys.premiumPromo)?.get(PremiumPromoConfiguration.self) {
        return entry
    } else {
        return PremiumPromoConfiguration.defaultValue
    }
}

private func updatePremiumPromoConfiguration(transaction: Transaction, _ f: (PremiumPromoConfiguration) -> PremiumPromoConfiguration) {
    let current = currentPremiumPromoConfiguration(transaction: transaction)
    let updated = f(current)
    if updated != current {
        transaction.setPreferencesEntry(key: PreferencesKeys.premiumPromo, value: PreferencesEntry(updated))
    }
}

private extension PremiumPromoConfiguration {
    init(apiPremiumPromo: Api.help.PremiumPromo) {
        switch apiPremiumPromo {
            case let .premiumPromo(statusText, statusEntities, videoSections, videoFiles, currency, monthlyAmount, _):
                self.status = statusText
                self.statusEntities = messageTextEntitiesFromApiEntities(statusEntities)
                self.currency = currency
                self.monthlyAmount = monthlyAmount
                var videos: [String: TelegramMediaFile] = [:]
                for (key, document) in zip(videoSections, videoFiles) {
                    if let file = telegramMediaFileFromApiDocument(document) {
                        videos[key] = file
                    }
                }
                self.videos = videos
        }
    }
}
