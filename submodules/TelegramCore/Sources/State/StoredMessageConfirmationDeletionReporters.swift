import Foundation
import Postbox
import SwiftSignalKit

/// Where `deleteStoredMessagesAsReceivedDeletion` reports the messages it deleted, so that they fire the events a
/// received deletion fires (owner decision D1, 2026-10-15): `MessagesRemovedContext` and
/// `AccountStateManager.deletedMessages`. Such a deletion is a deletion the server made while the account was not
/// listening.
///
/// It runs inside the account reset (its ghost tail) and every history fill (what its confirmation found missing),
/// and the history fills are started from call sites that hold no state manager (ManagedMessageHistoryHoles,
/// ChatHistoryPreloadManager, SparseMessageList, ReplyThreadHistory, ForumChannels). What every application does
/// pass is the account Postbox's media box (`postbox.mediaBox`), so each `AccountStateManager` registers here under
/// its Postbox's media box, and no fill had to change. A Postbox has one media box, and an account one state
/// manager. A deletion made with a media box that no manager is registered for (a fill a test drives without one)
/// reports nothing; its storage change is the same.
final class StoredMessageConfirmationDeletionReporters {
    private final class Entry {
        weak var mediaBox: MediaBox?
        let report: ([MessageId], Transaction) -> Void

        init(mediaBox: MediaBox, report: @escaping ([MessageId], Transaction) -> Void) {
            self.mediaBox = mediaBox
            self.report = report
        }
    }

    static let shared = StoredMessageConfirmationDeletionReporters()

    private let lock = NSLock()
    private var entries: [Entry] = []

    /// Calls `report` with the ids that each deletion made with `mediaBox` removes, and the transaction that
    /// deletes them, until the returned disposable is disposed. `report` runs inside that transaction, on the
    /// Postbox queue, so it must not wait for that Postbox; what must not be seen before the deletion is committed
    /// it defers with `transaction.afterCommit`.
    func register(mediaBox: MediaBox, report: @escaping ([MessageId], Transaction) -> Void) -> Disposable {
        let entry = Entry(mediaBox: mediaBox, report: report)
        self.lock.lock()
        // An entry whose media box is gone is never reported to again.
        self.entries.removeAll(where: { $0.mediaBox == nil })
        self.entries.append(entry)
        self.lock.unlock()
        return ActionDisposable { [weak self] in
            guard let strongSelf = self else {
                return
            }
            strongSelf.lock.lock()
            strongSelf.entries.removeAll(where: { $0 === entry })
            strongSelf.lock.unlock()
        }
    }

    /// Hands `ids`, which a deletion made with `mediaBox` removed in `transaction`, to every registration
    /// for `mediaBox`. Does nothing for an empty `ids`.
    func report(_ ids: [MessageId], mediaBox: MediaBox, transaction: Transaction) {
        if ids.isEmpty {
            return
        }
        self.lock.lock()
        let reports = self.entries.filter({ $0.mediaBox === mediaBox }).map({ $0.report })
        self.lock.unlock()
        for report in reports {
            report(ids, transaction)
        }
    }
}

extension DeletedMessageId {
    /// `id` named as a received deletion names it: a private-chat or basic-group message by its account-global id
    /// (`.DeleteMessagesWithGlobalIds`, `applyDeleteMessagesWithGlobalIds` in StateReplay+Messages.swift), any other
    /// by its full id (`.DeleteMessages`, `applyDeleteMessages` there, channel messages). `MessagesRemovedContext`
    /// looks ids up the same way.
    init(receivedDeletionOf id: MessageId) {
        if id.peerId.namespace == Namespaces.Peer.CloudUser || id.peerId.namespace == Namespaces.Peer.CloudGroup {
            self = .global(id.id)
        } else {
            self = .messageId(id)
        }
    }
}
