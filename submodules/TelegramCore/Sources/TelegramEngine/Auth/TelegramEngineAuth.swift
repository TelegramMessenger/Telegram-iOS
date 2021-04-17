import SwiftSignalKit
import Postbox
import TelegramApi

public extension TelegramEngineUnauthorized {
    final class Auth {
        private let account: UnauthorizedAccount

        init(account: UnauthorizedAccount) {
            self.account = account
        }

        public func exportAuthTransferToken(accountManager: AccountManager, otherAccountUserIds: [PeerId.Id], syncContacts: Bool) -> Signal<ExportAuthTransferTokenResult, ExportAuthTransferTokenError> {
            return _internal_exportAuthTransferToken(accountManager: accountManager, account: self.account, otherAccountUserIds: otherAccountUserIds, syncContacts: syncContacts)
        }
    }
}

public enum DeleteAccountError {
    case generic
}

public extension TelegramEngine {
	final class Auth {
		private let account: Account

		init(account: Account) {
			self.account = account
		}

		public func deleteAccount() -> Signal<Never, DeleteAccountError> {
		    return self.account.network.request(Api.functions.account.deleteAccount(reason: "GDPR"))
		    |> mapError { _ -> DeleteAccountError in
		        return .generic
		    }
		    |> ignoreValues
		}
	}
}
