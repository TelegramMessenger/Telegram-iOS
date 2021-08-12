import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Localization {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func getCountriesList(accountManager: AccountManager<TelegramAccountManagerTypes>, langCode: String?, forceUpdate: Bool = false) -> Signal<[Country], NoError> {
            return _internal_getCountriesList(accountManager: accountManager, network: self.account.network, langCode: langCode, forceUpdate: forceUpdate)
        }

        public func markSuggestedLocalizationAsSeenInteractively(languageCode: String) -> Signal<Void, NoError> {
            return _internal_markSuggestedLocalizationAsSeenInteractively(postbox: self.account.postbox, languageCode: languageCode)
        }

        public func synchronizedLocalizationListState() -> Signal<Never, NoError> {
            return _internal_synchronizedLocalizationListState(postbox: self.account.postbox, network: self.account.network)
        }

        public func suggestedLocalizationInfo(languageCode: String, extractKeys: [String]) -> Signal<SuggestedLocalizationInfo, NoError> {
            return _internal_suggestedLocalizationInfo(network: self.account.network, languageCode: languageCode, extractKeys: extractKeys)
        }

        public func requestLocalizationPreview(identifier: String) -> Signal<LocalizationInfo, RequestLocalizationPreviewError> {
            return _internal_requestLocalizationPreview(network: self.account.network, identifier: identifier)
        }

        public func downloadAndApplyLocalization(accountManager: AccountManager<TelegramAccountManagerTypes>, languageCode: String) -> Signal<Void, DownloadAndApplyLocalizationError> {
            return _internal_downloadAndApplyLocalization(accountManager: accountManager, postbox: self.account.postbox, network: self.account.network, languageCode: languageCode)
        }
    }
}

public extension TelegramEngineUnauthorized {
    final class Localization {
        private let account: UnauthorizedAccount

        init(account: UnauthorizedAccount) {
            self.account = account
        }

        public func getCountriesList(accountManager: AccountManager<TelegramAccountManagerTypes>, langCode: String?, forceUpdate: Bool = false) -> Signal<[Country], NoError> {
        	return _internal_getCountriesList(accountManager: accountManager, network: self.account.network, langCode: langCode, forceUpdate: forceUpdate)
	    }

        public func markSuggestedLocalizationAsSeenInteractively(languageCode: String) -> Signal<Void, NoError> {
            return _internal_markSuggestedLocalizationAsSeenInteractively(postbox: self.account.postbox, languageCode: languageCode)
        }

        public func currentlySuggestedLocalization(extractKeys: [String]) -> Signal<SuggestedLocalizationInfo?, NoError> {
            return _internal_currentlySuggestedLocalization(network: self.account.network, extractKeys: extractKeys)
        }

        public func downloadAndApplyLocalization(accountManager: AccountManager<TelegramAccountManagerTypes>, languageCode: String) -> Signal<Void, DownloadAndApplyLocalizationError> {
            return _internal_downloadAndApplyLocalization(accountManager: accountManager, postbox: self.account.postbox, network: self.account.network, languageCode: languageCode)
        }
    }
}
