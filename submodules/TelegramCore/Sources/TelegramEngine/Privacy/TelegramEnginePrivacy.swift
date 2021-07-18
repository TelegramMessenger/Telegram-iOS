import SwiftSignalKit
import Postbox

public extension TelegramEngine {
    final class Privacy {
        private let account: Account

        init(account: Account) {
            self.account = account
        }

        public func requestUpdatePeerIsBlocked(peerId: PeerId, isBlocked: Bool) -> Signal<Void, NoError> {
            return _internal_requestUpdatePeerIsBlocked(account: self.account, peerId: peerId, isBlocked: isBlocked)
        }

        public func activeSessions() -> ActiveSessionsContext {
            return ActiveSessionsContext(account: self.account)
        }

        public func webSessions() -> WebSessionsContext {
            return WebSessionsContext(account: self.account)
        }

        public func requestAccountPrivacySettings() -> Signal<AccountPrivacySettings, NoError> {
            return _internal_requestAccountPrivacySettings(account: self.account)
        }

        public func updateAccountAutoArchiveChats(value: Bool) -> Signal<Never, NoError> {
            return _internal_updateAccountAutoArchiveChats(account: self.account, value: value)
        }

        public func updateAccountRemovalTimeout(timeout: Int32) -> Signal<Void, NoError> {
            return _internal_updateAccountRemovalTimeout(account: self.account, timeout: timeout)
        }

        public func updatePhoneNumberDiscovery(value: Bool) -> Signal<Void, NoError> {
            return _internal_updatePhoneNumberDiscovery(account: self.account, value: value)
        }

        public func updateSelectiveAccountPrivacySettings(type: UpdateSelectiveAccountPrivacySettingsType, settings: SelectivePrivacySettings) -> Signal<Void, NoError> {
            return _internal_updateSelectiveAccountPrivacySettings(account: self.account, type: type, settings: settings)
        }
    }
}
