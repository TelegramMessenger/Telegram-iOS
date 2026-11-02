import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// A pts, qts or seq range as the server numbers it: applying it moves the local value from `end - count` to
/// `end`. A pts update carries `(pts, pts_count)`, a qts update `(qts, 1)`, an `updates` container `(seq, 1)` and an
/// `updatesCombined` container `seq_start...seq` (`init(seqStart:seq:)`). The common box's gap checks
/// (`finalStateWithUpdateGroups` below) classify every span with `classify(local:afterHole:)`.
struct SequenceSpan {
    enum Classification {
        /// `local >= end`: what the span carries is already applied, an exact duplicate included (G2).
        case alreadyApplied
        /// `local == end - count` and no hole yet: the span is the next one; applying it moves the local value to `end`.
        case apply
        /// Anything else, and every span not yet applied once a hole was seen (`afterHole`): updates are missing
        /// below the span, or the span starts at or below the local value and ends above it
        /// (`end - count < local < end`). core.telegram.org/api/updates would ignore the latter; here it is a hole
        /// too: the gap wait and one getDifference (pinned by SeqContainerEdgeTests).
        case gap
    }
    
    let end: Int32
    let count: Int32
    
    init(end: Int32, count: Int32) {
        self.end = end
        self.count = count
    }
    
    /// An `updatesCombined` container covers `seqStart...seq`, so its count is `seq - seqStart + 1` (G2): it applies
    /// exactly when `local + 1 == seqStart`. An `updates` container is the one-element case, `(seq, 1)`.
    init(seqStart: Int32, seq: Int32) {
        self.init(end: seq, count: seq - seqStart + 1)
    }
    
    /// The rule is the same for pts, qts and seq. Once one span of a batch is not applied, every later span of the same
    /// kind that is not already applied waits for the difference as well: the caller passes `afterHole: true` and the
    /// answer is `.gap` for it. `end - count` is then not evaluated at all, as in the check this replaced, where a
    /// hole short-circuited it (a malformed span whose start is not an Int32 traps only as the first unapplied span).
    func classify(local: Int32, afterHole: Bool) -> Classification {
        if local >= self.end {
            return .alreadyApplied
        } else if !afterHole && local == self.end - self.count {
            return .apply
        } else {
            return .gap
        }
    }
}

func finalStateWithUpdateGroups(accountPeerId: PeerId, postbox: Postbox, network: Network, state: AccountMutableState, groups: [UpdateGroup], asyncResetChannels: (([(peer: Peer, pts: Int32?)]) -> Void)?) -> Signal<AccountFinalState, NoError> {
    var updatedState = state
    
    var hadReset = false
    var ptsUpdatesAfterHole: [PtsUpdate] = []
    var qtsUpdatesAfterHole: [QtsUpdate] = []
    var seqGroupsAfterHole: [SeqUpdates] = []
    
    for case .reset in groups {
        hadReset = true
        break
    }
    
    let currentPtsUpdates = ptsUpdates(groups)
    
    let currentQtsUpdates = qtsUpdates(groups)
    
    var currentSeqGroups = seqGroups(groups)
    currentSeqGroups.sort(by: { $0.seqRange.end < $1.seqRange.end })
    
    var collectedUpdates: [Api.Update] = []
    
    for update in currentPtsUpdates {
        switch update.ptsRange.classify(local: updatedState.state.pts, afterHole: !ptsUpdatesAfterHole.isEmpty) {
            case .alreadyApplied:
                if let update = update.update, case .updateWebPage = update {
                    collectedUpdates.append(update)
                }
            case .apply:
                updatedState.mergeChats(update.chats)
                updatedState.mergeUsers(update.users)
                
                if let ptsUpdate = update.update {
                    collectedUpdates.append(ptsUpdate)
                }
                
                updatedState.updateState(AuthorizedAccountState.State(pts: update.ptsRange.end, qts: updatedState.state.qts, date: updatedState.state.date, seq: updatedState.state.seq))
            case .gap:
                if ptsUpdatesAfterHole.count == 0 {
                    Logger.shared.log("State", "update pts hole: \(update.ptsRange.end) != \(updatedState.state.pts) + \(update.ptsRange.count)")
                }
                ptsUpdatesAfterHole.append(update)
        }
    }
    
    for update in currentQtsUpdates {
        switch update.qtsRange.classify(local: updatedState.state.qts, afterHole: !qtsUpdatesAfterHole.isEmpty) {
            case .alreadyApplied:
                break
            case .apply:
                updatedState.mergeChats(update.chats)
                updatedState.mergeUsers(update.users)
                
                collectedUpdates.append(update.update)
                
                updatedState.updateState(AuthorizedAccountState.State(pts: updatedState.state.pts, qts: update.qtsRange.end, date: updatedState.state.date, seq: updatedState.state.seq))
            case .gap:
                if qtsUpdatesAfterHole.count == 0 {
                    Logger.shared.log("State", "update qts hole: \(update.qtsRange.end) != \(updatedState.state.qts) + \(update.qtsRange.count)")
                }
                qtsUpdatesAfterHole.append(update)
        }
    }
    
    for group in currentSeqGroups {
        switch group.seqRange.classify(local: updatedState.state.seq, afterHole: !seqGroupsAfterHole.isEmpty) {
            case .alreadyApplied:
                break
            case .apply:
                collectedUpdates.append(contentsOf: group.updates)
                
                updatedState.mergeChats(group.chats)
                updatedState.mergeUsers(group.users)
                
                updatedState.updateState(AuthorizedAccountState.State(pts: updatedState.state.pts, qts: updatedState.state.qts, date: group.date, seq: group.seqRange.end))
            case .gap:
                if seqGroupsAfterHole.count == 0 {
                    Logger.shared.log("State", "update seq hole: \(group.seqRange.end) != \(updatedState.state.seq) + \(group.seqRange.count)")
                }
                seqGroupsAfterHole.append(group)
        }
    }
    
    var currentDateGroups = dateGroups(groups)
    currentDateGroups.sort(by: { group1, group2 -> Bool in
        switch group1 {
            case let .withDate(_, date1, _, _):
                switch group2 {
                    case let .withDate(_, date2, _, _):
                        return date1 < date2
                    default:
                        return false
                }
            default:
                return false
        }
    })
    
    var updatesDate: Int32?
    
    for group in currentDateGroups {
        switch group {
            case let .withDate(updates, date, users, chats):
                collectedUpdates.append(contentsOf: updates)
                
                updatedState.mergeChats(chats)
                updatedState.mergeUsers(users)
                if updatesDate == nil {
                    updatesDate = date
                }
            default:
                break
        }
    }
    
    for case let .updateChannelPts(channelId, pts, ptsCount) in groups {
        collectedUpdates.append(Api.Update.updateDeleteChannelMessages(.init(channelId: channelId, messages: [], pts: pts, ptsCount: ptsCount)))
    }
    
    return finalStateWithUpdates(accountPeerId: accountPeerId, postbox: postbox, network: network, state: updatedState, updates: collectedUpdates, shouldPoll: hadReset, missingUpdates: !ptsUpdatesAfterHole.isEmpty || !qtsUpdatesAfterHole.isEmpty || !seqGroupsAfterHole.isEmpty, shouldResetChannels: false, updatesDate: updatesDate, asyncResetChannels: asyncResetChannels)
}
