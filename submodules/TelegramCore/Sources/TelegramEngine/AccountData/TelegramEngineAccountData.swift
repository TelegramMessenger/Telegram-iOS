import SwiftSignalKit

public extension TelegramEngine {
    final class AccountData {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func acceptTermsOfService(id: String) -> Signal<Void, NoError> {
		    return _internal_acceptTermsOfService(account: self.account, id: id)
		}

		public func resetAccountDueTermsOfService() -> Signal<Void, NoError> {
			return _internal_resetAccountDueTermsOfService(network: self.account.network)
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
    }
}
