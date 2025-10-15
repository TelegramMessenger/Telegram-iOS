import Foundation
import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Notices {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func set<T: Codable>(id: NoticeEntryKey, item: T?) -> Signal<Never, NoError> {
            return self.account.postbox.transaction { transaction -> Void in
                if let item = item, let entry = CodableEntry(item) {
                    transaction.setNoticeEntry(key: id, value: entry)
                } else {
                    transaction.setNoticeEntry(key: id, value: nil)
                }
            }
            |> ignoreValues
        }
        
        public func getServerProvidedSuggestions() -> Signal<[ServerProvidedSuggestion], NoError> {
            return _internal_getServerProvidedSuggestions(account: self.account)
        }
        
        public func getServerDismissedSuggestions() -> Signal<[String], NoError> {
            return _internal_getServerDismissedSuggestions(account: self.account)
        }
        
        public func dismissServerProvidedSuggestion(suggestion: String) -> Signal<Never, NoError> {
            return _internal_dismissServerProvidedSuggestion(account: self.account, suggestion: suggestion)
        }
        
        public func getPeerSpecificServerProvidedSuggestions(peerId: EnginePeer.Id) -> Signal<[PeerSpecificServerProvidedSuggestion], NoError> {
            return _internal_getPeerSpecificServerProvidedSuggestions(postbox: self.account.postbox, peerId: peerId)
        }
        
        public func dismissPeerSpecificServerProvidedSuggestion(peerId: PeerId, suggestion: PeerSpecificServerProvidedSuggestion) -> Signal<Never, NoError> {
            return _internal_dismissPeerSpecificServerProvidedSuggestion(account: self.account, peerId: peerId, suggestion: suggestion)
        }
    }
}
