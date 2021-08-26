import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Themes {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func getChatThemes(accountManager: AccountManager<TelegramAccountManagerTypes>, forceUpdate: Bool = false, onlyCached: Bool = false) -> Signal<[ChatTheme], NoError> {
            return _internal_getChatThemes(accountManager: accountManager, network: self.account.network, forceUpdate: forceUpdate, onlyCached: onlyCached)
        }
        
        public func setChatTheme(peerId: PeerId, emoticon: String?) -> Signal<Void, NoError> {
            return _internal_setChatTheme(postbox: self.account.postbox, network: self.account.network, stateManager: self.account.stateManager, peerId: peerId, emoticon: emoticon)
        }
    }
}
