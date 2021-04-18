import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Localization {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func getCountriesList(accountManager: AccountManager, langCode: String?, forceUpdate: Bool = false) -> Signal<[Country], NoError> {
            return _internal_getCountriesList(accountManager: accountManager, network: self.account.network, langCode: langCode, forceUpdate: forceUpdate)
        }
    }
}

public extension TelegramEngineUnauthorized {
    final class Localization {
        private let account: UnauthorizedAccount

        init(account: UnauthorizedAccount) {
            self.account = account
        }

        public func getCountriesList(accountManager: AccountManager, langCode: String?, forceUpdate: Bool = false) -> Signal<[Country], NoError> {
        	return _internal_getCountriesList(accountManager: accountManager, network: self.account.network, langCode: langCode, forceUpdate: forceUpdate)
	    }
    }
}
