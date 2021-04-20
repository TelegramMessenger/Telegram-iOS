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
    }
}
