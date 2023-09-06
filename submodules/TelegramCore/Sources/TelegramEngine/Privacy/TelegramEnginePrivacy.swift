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

        public func requestUpdatePeerIsBlockedFromStories(peerId: PeerId, isBlocked: Bool) -> Signal<Void, NoError> {
            return _internal_requestUpdatePeerIsBlockedFromStories(account: self.account, peerId: peerId, isBlocked: isBlocked)
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
        
        public func updateGlobalPrivacySettings() -> Signal<Never, NoError> {
            return _internal_updateGlobalPrivacySettings(account: self.account)
        }
        
        public func updateAccountAutoArchiveChats(value: Bool) -> Signal<Never, NoError> {
            return _internal_updateAccountAutoArchiveChats(account: self.account, value: value)
        }
        
        public func updateAccountKeepArchivedFolders(value: Bool) -> Signal<Never, NoError> {
            return _internal_updateAccountKeepArchivedFolders(account: self.account, value: value)
        }
        
        public func updateAccountKeepArchivedUnmuted(value: Bool) -> Signal<Never, NoError> {
            return _internal_updateAccountKeepArchivedUnmuted(account: self.account, value: value)
        }

        public func updateGlobalPrivacySettings(settings: GlobalPrivacySettings) -> Signal<Never, NoError> {
            return _internal_updateGlobalPrivacySettings(account: self.account, settings: settings)
        }

        public func updateAccountRemovalTimeout(timeout: Int32) -> Signal<Void, NoError> {
            return _internal_updateAccountRemovalTimeout(account: self.account, timeout: timeout)
        }
        
        public func updateGlobalMessageRemovalTimeout(timeout: Int32?) -> Signal<Void, NoError> {
            return _internal_updateMessageRemovalTimeout(account: self.account, timeout: timeout)
        }

        public func updatePhoneNumberDiscovery(value: Bool) -> Signal<Void, NoError> {
            return _internal_updatePhoneNumberDiscovery(account: self.account, value: value)
        }

        public func updateSelectiveAccountPrivacySettings(type: UpdateSelectiveAccountPrivacySettingsType, settings: SelectivePrivacySettings) -> Signal<Void, NoError> {
            return _internal_updateSelectiveAccountPrivacySettings(account: self.account, type: type, settings: settings)
        }
        
        public func updateCloseFriends(peerIds: [EnginePeer.Id]) -> Signal<Never, NoError> {
            return _internal_updateCloseFriends(account: self.account, peerIds: peerIds)
        }
        
        public func cleanupSessionReviews() -> Signal<Never, NoError> {
            return _internal_cleanupSessionReviews(account: self.account)
        }
        
        public func confirmNewSessionReview(id: Int64) -> Signal<Never, NoError> {
            let _ = removeNewSessionReviews(postbox: self.account.postbox, ids: [id]).start()
            return _internal_confirmNewSessionReview(account: self.account, id: id)
        }
        
        public func terminateAnotherSession(id: Int64) -> Signal<Never, TerminateSessionError> {
            let _ = removeNewSessionReviews(postbox: self.account.postbox, ids: [id]).start()
            
            return terminateAccountSession(account: self.account, hash: id)
            |> ignoreValues
        }
    }
}
