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

public enum UpdateContactNameError {
    case generic
}

public func updateContactName(account: Account, peerId: PeerId, firstName: String, lastName: String) -> Signal<Void, UpdateContactNameError> {
    return account.postbox.modify { modifier -> Signal<Void, UpdateContactNameError> in
        if let peer = modifier.getPeer(peerId) as? TelegramUser, let phone = peer.phone, !phone.isEmpty {
            return account.network.request(Api.functions.contacts.importContacts(contacts: [Api.InputContact.inputPhoneContact(clientId: 1, phone: phone, firstName: firstName, lastName: lastName)], replace: .boolFalse))
                |> mapError { _ -> UpdateContactNameError in
                    return .generic
                }
                |> mapToSignal { result -> Signal<Void, UpdateContactNameError> in
                    return account.postbox.modify { modifier -> Void in
                        switch result {
                            case let .importedContacts(_, _, users):
                                if let first = users.first {
                                    let user = TelegramUser(user: first)
                                    updatePeers(modifier: modifier, peers: [user], update: { _, updated in
                                        return updated
                                    })
                                }
                        }
                    } |> mapError { _ -> UpdateContactNameError in return .generic }
                }
        } else {
            return .fail(.generic)
        }
    } |> mapError { _ -> UpdateContactNameError in return .generic } |> switchToLatest
}
