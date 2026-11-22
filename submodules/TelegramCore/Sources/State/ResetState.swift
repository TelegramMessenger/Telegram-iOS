import Foundation
import SwiftSignalKit
import Postbox
internal import TelegramApi

/// What the reset's transaction writes from the network.
private struct FetchedAccountReset {
    let chats: FetchedChatList
    /// When the reset sent its first request (`FetchedAnswerAge.now()`): no answer it writes is older.
    let fetchStartedAt: Double
}

/// The account reset after `updates.differenceTooLong` (spec section 3 of the differenceTooLong design).
/// Fetches the first chat-list page, the pinned chats and the first page of each folder they reference; then,
/// in one transaction, puts a hole over every non-secret chat's history, rebuilds the chat list from the
/// answers, deletes the ghost tail (every stored message above a fetched dialog's top message) and moves the
/// stored pts to `pts`, the one differenceTooLong carried. qts, date and seq stay, so the caller's next
/// getDifference still fetches the gap's secret-chat messages and dated updates (G10). Nothing is written until
/// every answer is in. The caller polls again afterwards.
///
/// A top message or reply target deleted while the answers were in flight is not stored again (owner decision D2,
/// `fetchedMessagesWithoutRecentDeletions`). Answers older than the record of recent deletions keeps one when the
/// transaction runs write nothing; then the reset starts again from the chat list (`FetchedAnswerAge`), after
/// `FetchedAnswerAge.staleRestartDelay` for its place in the row (`staleRestarts`, which callers leave at 0). It
/// never gives up.
func _internal_resetAccountState(postbox: Postbox, network: Network, accountPeerId: PeerId, pts: Int32, staleRestarts: Int = 0) -> Signal<Never, NoError> {
    return deferred { () -> Signal<(fetchedChats: FetchedChatList?, fetchStartedAt: Double), NoError> in
        // The page is several requests; none of their answers is older than this.
        let fetchStartedAt = FetchedAnswerAge.now()
        return fetchChatList(accountPeerId: accountPeerId, postbox: postbox, network: network, location: .general, upperBound: .absoluteUpperBound(), hash: 0, limit: 100)
        |> map { fetchedChats -> (fetchedChats: FetchedChatList?, fetchStartedAt: Double) in
            return (fetchedChats: fetchedChats, fetchStartedAt: fetchStartedAt)
        }
    }
    |> mapToSignal { answer -> Signal<FetchedAccountReset, NoError> in
        let fetchStartedAt = answer.fetchStartedAt
        guard let fetchedChats = answer.fetchedChats else {
            // messages.dialogsNotModified: there is nothing to reset from. Complete without writing: pts stays
            // where it was, so the cycle's next getDifference meets differenceTooLong again and the reset is
            // retried on the consecutive-reset backoff until a chat list arrives (spec section 3 point 6).
            Logger.shared.log("State", "account reset got messages.dialogsNotModified, keeping the state; the next differenceTooLong retries the reset")
            return .complete()
        }
        return .single(FetchedAccountReset(chats: fetchedChats, fetchStartedAt: fetchStartedAt))
    }
    |> mapToSignal { fetched -> Signal<Never, NoError> in
        let fetchedChats = fetched.chats
        return withResolvedAssociatedMessages(postbox: postbox, source: .network(network), accountPeerId: accountPeerId, parsedPeers: fetchedChats.peers, storeMessages: fetchedChats.storeMessages, resolveThreads: false, { transaction, additionalPeers, additionalMessages -> Bool in
            // Answers older than the record of recent deletions keeps one may predate a deletion it has already
            // forgotten (FetchedAnswerAge): they write nothing, and the reset starts again below.
            if FetchedAnswerAge.isTooOldToStore(answeredAt: fetched.fetchStartedAt) {
                Logger.shared.log("State", "account reset: the answers are \(Int(FetchedAnswerAge.now() - fetched.fetchStartedAt)) s old, older than the record of recent deletions keeps one; writing nothing, fetching the chat list again")
                return false
            }
            for peerId in transaction.chatListGetAllPeerIds() {
                if peerId.namespace != Namespaces.Peer.SecretChat {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .notIncluded)
                }
                
                if peerId.namespace != Namespaces.Peer.SecretChat {
                    transaction.addHole(peerId: peerId, threadId: nil, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                }
                
                if peerId.namespace == Namespaces.Peer.CloudChannel {
                    if let channel = transaction.getPeer(peerId) as? TelegramChannel, channel.isForumOrMonoForum {
                        transaction.setPeerPinnedThreads(peerId: peerId, threadIds: [])
                        for threadId in transaction.setMessageHistoryThreads(peerId: peerId) {
                            transaction.setMessageHistoryThreadInfo(peerId: peerId, threadId: threadId, info: nil)
                            transaction.addHole(peerId: peerId, threadId: threadId, namespace: Namespaces.Message.Cloud, space: .everywhere, range: 1 ... (Int32.max - 1))
                        }
                    }
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, _ in nil })
                    transaction.setPeerThreadCombinedState(peerId: peerId, state: nil)
                }
            }
            
            transaction.removeAllChatListEntries(groupId: .root, exceptPeerNamespace: Namespaces.Peer.SecretChat)
            transaction.removeAllChatListEntries(groupId: .group(1), exceptPeerNamespace: Namespaces.Peer.SecretChat)
            
            updatePeers(transaction: transaction, accountPeerId: accountPeerId, peers: fetchedChats.peers.union(with: additionalPeers))
            _internal_applyFetchedChatInputStates(transaction: transaction, accountPeerId: accountPeerId, inputStates: fetchedChats.inputStates)

            for (threadMessageId, data) in fetchedChats.threadInfos {
                if let entry = StoredMessageHistoryThreadInfo(data.data) {
                    transaction.setMessageHistoryThreadInfo(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, info: entry)
                }
                transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadMentionCount, maxId: data.topMessageId)
                transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadReactionCount, maxId: data.topMessageId)
                transaction.replaceMessageTagSummary(peerId: threadMessageId.peerId, threadId: threadMessageId.threadId, tagMask: .unseenPollVote, namespace: Namespaces.Message.Cloud, customTag: nil, count: data.unreadPollVoteCount, maxId: data.topMessageId)
            }
            
            transaction.updateCurrentPeerNotificationSettings(fetchedChats.notificationSettings)
            // A top message or reply target deleted while the answers were in flight is not stored again (owner
            // decision D2): its chat keeps the hole put over its history above, from that top message up, so the
            // chat's next history fill asks the server what is there now. Its chat-list entry takes its index from
            // the newest message still stored (it leaves the list if none is and nothing else includes it), as
            // after a deletion that lands once the top message is stored. Each dialog brings its top message, and a
            // forum's can bring its topics' top messages too (`resolveForumThreads`); `.UpperHistoryBlock` removes the
            // hole above the lowest message it stores for a chat.
            // One edited while the answers were in flight is stored as its edit (owner decision 2026-10-25).
            let topMessages = fetchedMessagesWithRecentEdits(transaction: transaction, messages: fetchedMessagesWithoutRecentDeletions(transaction: transaction, messages: fetchedChats.storeMessages, logTag: "State", logPrefix: "account reset, top messages"), since: fetched.fetchStartedAt, logTag: "State", logPrefix: "account reset, top messages")
            let _ = transaction.addMessages(topMessages, location: .UpperHistoryBlock)
            let _ = transaction.addMessages(fetchedMessagesWithRecentEdits(transaction: transaction, messages: fetchedMessagesWithoutRecentDeletions(transaction: transaction, messages: additionalMessages, logTag: "State", logPrefix: "account reset, reply targets"), since: fetched.fetchStartedAt, logTag: "State", logPrefix: "account reset, reply targets"), location: .Random)
            // The ghost tail (spec section 3 point 3, as amended 2026-10-24): every stored Cloud message above a
            // fetched dialog's top message, deleted as a received deletion without asking the server. The top messages
            // were just stored with `.UpperHistoryBlock`, which removes the hole from them upward, so such a message
            // would otherwise be shown at once as the chat's newest and become its chat-list preview. A dialog's
            // `top_message` is the chat's newest message when the server built the answer, so such a message was
            // deleted during the gap or is newer than the answer; a newer one (the account's own reply, sent while
            // this reset was in flight) has a pts above `pts`, so the follow-up getDifference delivers it again.
            // After both stores; before the read states are reset, so the server's read counts win over what the
            // deletions adjust.
            let ghostTail = storedCloudMessagesAboveTopMessages(transaction: transaction, fetchedChats: fetchedChats)
            if !ghostTail.isEmpty {
                let deletedIds = deleteStoredMessagesAsReceivedDeletion(transaction: transaction, mediaBox: postbox.mediaBox, ids: ghostTail)
                Logger.shared.log("State", "account reset: deleted \(deletedIds.count) stored message(s) above the fetched top messages")
            }
            transaction.resetIncomingReadStates(fetchedChats.readStates)
            
            for (peerId, autoremoveValue) in fetchedChats.ttlPeriods {
                transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                    if peerId.namespace == Namespaces.Peer.CloudUser {
                        let current = (current as? CachedUserData) ?? CachedUserData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else if peerId.namespace == Namespaces.Peer.CloudChannel {
                        let current = (current as? CachedChannelData) ?? CachedChannelData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else if peerId.namespace == Namespaces.Peer.CloudGroup {
                        let current = (current as? CachedGroupData) ?? CachedGroupData()
                        return current.withUpdatedAutoremoveTimeout(autoremoveValue)
                    } else {
                        return current
                    }
                })
            }
            for (peerId, value) in fetchedChats.viewForumAsMessages {
                if value {
                    transaction.updatePeerCachedData(peerIds: Set([peerId]), update: { _, current in
                        if peerId.namespace == Namespaces.Peer.CloudChannel {
                            let current = (current as? CachedChannelData) ?? CachedChannelData()
                            return current.withUpdatedViewForumAsMessages(.known(value))
                        } else {
                            return current
                        }
                    })
                }
            }
            
            for hole in transaction.allChatListHoles(groupId: .root) {
                transaction.replaceChatListHole(groupId: .root, index: hole.index, hole: nil)
            }
            for hole in transaction.allChatListHoles(groupId: .group(1)) {
                transaction.replaceChatListHole(groupId: .group(1), index: hole.index, hole: nil)
            }
            
            if let hole = fetchedChats.lowerNonPinnedIndex.flatMap(ChatListHole.init) {
                transaction.addChatListHole(groupId: .root, hole: hole)
            }
            transaction.addChatListHole(groupId: .group(1), hole: ChatListHole(index: MessageIndex(id: MessageId(peerId: PeerId(namespace: Namespaces.Peer.Empty, id: PeerId.Id._internalFromInt64Value(0)), namespace: Namespaces.Message.Cloud, id: 1), timestamp: Int32.max - 1)))
            
            for peerId in fetchedChats.chatPeerIds {
                if let peer = transaction.getPeer(peerId) {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: .root, pinningIndex: transaction.getPeerChatListIndex(peerId)?.1.pinningIndex, minTimestamp: minTimestampForPeerInclusion(peer)))
                } else {
                    assertionFailure()
                }
            }
            
            for (peerId, peerGroupId) in fetchedChats.peerGroupIds {
                if let peer = transaction.getPeer(peerId) {
                    transaction.updatePeerChatListInclusion(peerId, inclusion: .ifHasMessagesOrOneOf(groupId: peerGroupId, pinningIndex: nil, minTimestamp: minTimestampForPeerInclusion(peer)))
                } else {
                    assertionFailure()
                }
            }
            
            for (peerId, channelPts) in fetchedChats.channelStates {
                if let current = transaction.getPeerChatState(peerId) as? ChannelState {
                    if current.pts != channelPts {
                        // The account reset skips the channel's own difference, so what is stored below the new
                        // pts is unverified: raising invalidatedPts makes the channel's history validation check
                        // it when the history is next shown. It never lowers it: an older page's lower pts would
                        // stop the revalidation of what the higher one marks. A channel whose pts did not move is
                        // left alone.
                        transaction.setPeerChatState(peerId, state: current.withUpdatedPts(channelPts).withUpdatedInvalidatedPts(max(current.invalidatedPts ?? channelPts, channelPts)))
                    }
                } else {
                    transaction.setPeerChatState(peerId, state: ChannelState(pts: channelPts, invalidatedPts: nil, synchronizedUntilMessageId: nil))
                }
            }
            
            if let replacePinnedItemIds = fetchedChats.pinnedItemIds {
                transaction.setPinnedItemIds(groupId: .root, itemIds: replacePinnedItemIds.map(PinnedItemId.peer))
            }
            
            for (peerId, summary) in fetchedChats.mentionTagSummaries {
                transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenPersonalMessage, namespace: Namespaces.Message.Cloud, customTag: nil, count: summary.count, maxId: summary.range.maxId)
            }
            for (peerId, summary) in fetchedChats.reactionTagSummaries {
                transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenReaction, namespace: Namespaces.Message.Cloud, customTag: nil, count: summary.count, maxId: summary.range.maxId)
            }
            for (peerId, summary) in fetchedChats.pollVoteTagSummaries {
                transaction.replaceMessageTagSummary(peerId: peerId, threadId: nil, tagMask: .unseenPollVote, namespace: Namespaces.Message.Cloud, customTag: nil, count: summary.count, maxId: summary.range.maxId)
            }
            
            for (groupId, summary) in fetchedChats.folderSummaries {
                transaction.resetPeerGroupSummary(groupId: groupId, namespace: Namespaces.Message.Cloud, summary: summary)
            }
            
            let savedMessageTags = transaction.getMessageTagSummaryCustomTags(peerId: accountPeerId, threadId: nil, tagMask: [], namespace: Namespaces.Message.Cloud)
            if !savedMessageTags.isEmpty {
                for tag in savedMessageTags {
                    transaction.replaceMessageTagSummary(peerId: accountPeerId, threadId: nil, tagMask: [], namespace: Namespaces.Message.Cloud, customTag: tag, count: 0, maxId: 1)
                }
                transaction.invalidateMessageHistoryTagsSummary(peerId: accountPeerId, threadId: nil, namespace: Namespaces.Message.Cloud, tagMask: [], customTag: savedMessageTags[0])
            }
            
            transaction.reindexUnreadCounters()
            
            if let currentState = transaction.getState() as? AuthorizedAccountState, let currentInnerState = currentState.state {
                // The pts differenceTooLong carried is the state to continue from (the constructor's own
                // definition; tdlib and Android do the same). qts, date and seq stay, so the next getDifference
                // fetches the gap's secret-chat messages and dated updates, which updates.getState skipped (G10).
                Logger.shared.log("State", "account reset: pts \(currentInnerState.pts) -> \(pts), keeping qts \(currentInnerState.qts), date \(currentInnerState.date), seq \(currentInnerState.seq)")
                transaction.setState(currentState.changedState(AuthorizedAccountState.State(pts: pts, qts: currentInnerState.qts, date: currentInnerState.date, seq: currentInnerState.seq)))
            }
            return true
        })
        |> mapToSignal { written -> Signal<Never, NoError> in
            if written {
                return .complete()
            }
            let restarts = staleRestarts + 1
            let restartDelay = FetchedAnswerAge.staleRestartDelay(restarts)
            Logger.shared.log("State", "account reset: restart \(restarts) in a row after answers too old to store, waiting \(restartDelay) s first")
            let restart = _internal_resetAccountState(postbox: postbox, network: network, accountPeerId: accountPeerId, pts: pts, staleRestarts: restarts)
            if restartDelay > 0.0 {
                // Inside this reset's subscription, so whoever holds it (the manager's `accountResetDisposable`)
                // still cancels the wait.
                return restart |> delay(restartDelay, queue: Queue.concurrentDefaultQueue())
            }
            return restart
        }
    }
}
