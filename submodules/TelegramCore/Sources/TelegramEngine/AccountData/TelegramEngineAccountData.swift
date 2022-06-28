import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class AccountData {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func acceptTermsOfService(id: String) -> Signal<Void, NoError> {
		    return _internal_acceptTermsOfService(account: self.account, id: id)
		}

        public func requestChangeAccountPhoneNumberVerification(phoneNumber: String) -> Signal<ChangeAccountPhoneNumberData, RequestChangeAccountPhoneNumberVerificationError> {
            return _internal_requestChangeAccountPhoneNumberVerification(account: self.account, phoneNumber: phoneNumber)
        }

        public func requestNextChangeAccountPhoneNumberVerification(phoneNumber: String, phoneCodeHash: String) -> Signal<ChangeAccountPhoneNumberData, RequestChangeAccountPhoneNumberVerificationError> {
            return _internal_requestNextChangeAccountPhoneNumberVerification(account: self.account, phoneNumber: phoneNumber, phoneCodeHash: phoneCodeHash)
        }

        public func requestChangeAccountPhoneNumber(phoneNumber: String, phoneCodeHash: String, phoneCode: String) -> Signal<Void, ChangeAccountPhoneNumberError> {
            return _internal_requestChangeAccountPhoneNumber(account: self.account, phoneNumber: phoneNumber, phoneCodeHash: phoneCodeHash, phoneCode: phoneCode)
        }

        public func updateAccountPeerName(firstName: String, lastName: String) -> Signal<Void, NoError> {
            return _internal_updateAccountPeerName(account: self.account, firstName: firstName, lastName: lastName)
        }

        public func updateAbout(about: String?) -> Signal<Void, UpdateAboutError> {
            return _internal_updateAbout(account: self.account, about: about)
        }

        public func unregisterNotificationToken(token: Data, type: NotificationTokenType, otherAccountUserIds: [PeerId.Id]) -> Signal<Never, NoError> {
            return _internal_unregisterNotificationToken(account: self.account, token: token, type: type, otherAccountUserIds: otherAccountUserIds)
        }

        public func registerNotificationToken(token: Data, type: NotificationTokenType, sandbox: Bool, otherAccountUserIds: [PeerId.Id], excludeMutedChats: Bool) -> Signal<Never, NoError> {
            return _internal_registerNotificationToken(account: self.account, token: token, type: type, sandbox: sandbox, otherAccountUserIds: otherAccountUserIds, excludeMutedChats: excludeMutedChats)
        }

        public func updateAccountPhoto(resource: MediaResource?, videoResource: MediaResource?, videoStartTimestamp: Double?, mapResourceToAvatarSizes: @escaping (MediaResource, [TelegramMediaImageRepresentation]) -> Signal<[Int: Data], NoError>) -> Signal<UpdatePeerPhotoStatus, UploadPeerPhotoError> {
            return _internal_updateAccountPhoto(account: self.account, resource: resource, videoResource: videoResource, videoStartTimestamp: videoStartTimestamp, mapResourceToAvatarSizes: mapResourceToAvatarSizes)
        }

        public func updatePeerPhotoExisting(reference: TelegramMediaImageReference) -> Signal<TelegramMediaImage?, NoError> {
            return _internal_updatePeerPhotoExisting(network: self.account.network, reference: reference)
        }

        public func removeAccountPhoto(reference: TelegramMediaImageReference?) -> Signal<Void, NoError> {
            return _internal_removeAccountPhoto(network: self.account.network, reference: reference)
        }
    }
}
