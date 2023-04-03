import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Themes {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func getChatThemes(accountManager: AccountManager<TelegramAccountManagerTypes>, forceUpdate: Bool = false, onlyCached: Bool = false) -> Signal<[TelegramTheme], NoError> {
            return _internal_getChatThemes(accountManager: accountManager, network: self.account.network, forceUpdate: forceUpdate, onlyCached: onlyCached)
        }
        
        public func setChatTheme(peerId: PeerId, emoticon: String?) -> Signal<Void, NoError> {
            return _internal_setChatTheme(account: self.account, peerId: peerId, emoticon: emoticon)
        }
        
        public func setChatWallpaper(peerId: PeerId, wallpaper: TelegramWallpaper?) -> Signal<Void, NoError> {
            return _internal_setChatWallpaper(account: self.account, peerId: peerId, wallpaper: wallpaper)
        }
        
        public func setExistingChatWallpaper(messageId: MessageId) -> Signal<Void, SetExistingChatWallpaperError> {
            return _internal_setExistingChatWallpaper(account: self.account, messageId: messageId)
        }
    }
}
