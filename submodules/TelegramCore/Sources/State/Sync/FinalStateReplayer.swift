import Foundation
import Postbox
import EncryptionProvider

/// What a replay of a final state needs besides the state, the transaction and the delivered-message ids (seam 5): the
/// account's constants and the record of deleted messages the replay feeds. `AccountStateManager.Impl` hands one out
/// (`replayer`). It holds no reference to the manager, nor to the `Network` (it keeps the network's encryption
/// provider itself), so a transaction closure that captures it captures only the account objects below.
struct FinalStateReplayer {
    let accountManager: AccountManager<TelegramAccountManagerTypes>
    let postbox: Postbox
    let accountPeerId: PeerId
    let encryptionProvider: EncryptionProvider
    let auxiliaryMethods: AccountAuxiliaryMethods
    let messagesRemovedContext: MessagesRemovedContext
    var storyReactionContext: StoryReactionContext? = nil
    var storyRefreshContext: StoryRefreshContext? = nil
    var storyViewRefreshContext: StoryViewRefreshContext? = nil

    /// Replays `finalState` in the caller's `transaction` under `policy` (`replayFinalState`, with the account's media
    /// box), logs a replay that took more than a second, and records the messages it deleted in
    /// `messagesRemovedContext` at once, inside the transaction, so a view that transaction updates already finds
    /// them there. Every replay of a final state goes through here; whatever else a caller does in the same
    /// transaction (the channel reset clears its invalidated-channel records first, a discarded batch replays
    /// nothing) stays with the caller. nil: the replay was refused (`ReplayPolicy.verifiesTransaction`).
    func applyReplay(_ finalState: AccountFinalState, policy: ReplayPolicy, removePossiblyDeliveredMessagesUniqueIds: [Int64: PeerId], transaction: Transaction) -> AccountReplayedFinalState? {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = replayFinalState(accountManager: self.accountManager, postbox: self.postbox, accountPeerId: self.accountPeerId, mediaBox: self.postbox.mediaBox, encryptionProvider: self.encryptionProvider, transaction: transaction, auxiliaryMethods: self.auxiliaryMethods, finalState: finalState, removePossiblyDeliveredMessagesUniqueIds: removePossiblyDeliveredMessagesUniqueIds, policy: policy, storyReactionContext: self.storyReactionContext, storyRefreshContext: self.storyRefreshContext, storyViewRefreshContext: self.storyViewRefreshContext)
        let deltaTime = CFAbsoluteTimeGetCurrent() - startTime
        if deltaTime > 1.0 {
            Logger.shared.log("State", "replayFinalState took \(deltaTime)s")
        }
        if let result = result, !result.deletedMessageIds.isEmpty {
            self.messagesRemovedContext.addIsMessagesDeletedInteractively(ids: result.deletedMessageIds)
            self.messagesRemovedContext.addIsMessagesDeletedRemotely(ids: result.deletedMessageIds)
        }
        return result
    }
}
