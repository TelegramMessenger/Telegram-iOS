import Foundation
import XCTest
import Postbox
@testable import TelegramCore

/// `AccountMutableState.namespacesWithHolesFromPreviousState`: the peer namespaces whose stored top gets a hole above it
/// when the state is replayed. A channel poll on a branch marks its channel (`setNeedsHoleFromPreviousState`), a branch
/// starts with its parent's marks, and `merge(_:)` brings the marks back as a union per peer: each peer namespace once,
/// whichever branch marked it and however often.
final class HolesFromPreviousStateTests: XCTestCase {
    private func channelPeerId(_ id: Int64) -> PeerId {
        return PeerId(namespace: Namespaces.Peer.CloudChannel, id: PeerId.Id._internalFromInt64Value(id))
    }

    private func makeState() -> AccountMutableState {
        let initialState = AccountInitialState(state: AuthorizedAccountState.State(pts: 100, qts: 5, date: 1_700_000_000, seq: 10), peerIds: Set(), peerIdsRequiringLocalChatState: Set(), channelStates: [:], peerChatInfos: [:], locallyGeneratedMessageTimestamps: [:], channelsToPollExplicitely: Set())
        return AccountMutableState(initialState: initialState, initialPeers: [:], initialReferencedReplyMessageIds: ReferencedReplyMessageIds(), initialReferencedGeneralMessageIds: Set(), initialStoredMessages: Set(), initialStoredStories: [:], initialReadInboxMaxIds: [:], storedMessagesByPeerIdAndTimestamp: [:], initialSentScheduledMessageIds: Set())
    }

    func testBranchesMergeBackEachMarkedNamespaceOnce() {
        let first = self.channelPeerId(300)
        let second = self.channelPeerId(301)
        var parent = self.makeState()
        parent.setNeedsHoleFromPreviousState(peerId: first, namespace: Namespaces.Message.Cloud)

        // A branch starts with the parent's marks, before it marks anything itself.
        XCTAssertEqual(parent.branch().namespacesWithHolesFromPreviousState, [first: [Namespaces.Message.Cloud]])

        // Marking a namespace again adds nothing.
        var firstBranch = parent.branch()
        firstBranch.setNeedsHoleFromPreviousState(peerId: first, namespace: Namespaces.Message.Cloud)
        firstBranch.setNeedsHoleFromPreviousState(peerId: second, namespace: Namespaces.Message.Cloud)
        XCTAssertEqual(firstBranch.namespacesWithHolesFromPreviousState, [
            first: [Namespaces.Message.Cloud],
            second: [Namespaces.Message.Cloud]
        ])
        // The other branch marks a different namespace of the same peer.
        var secondBranch = parent.branch()
        secondBranch.setNeedsHoleFromPreviousState(peerId: second, namespace: Namespaces.Message.Local)
        secondBranch.setNeedsHoleFromPreviousState(peerId: second, namespace: Namespaces.Message.Local)
        XCTAssertEqual(secondBranch.namespacesWithHolesFromPreviousState, [
            first: [Namespaces.Message.Cloud],
            second: [Namespaces.Message.Local]
        ])

        parent.merge(firstBranch)
        parent.merge(secondBranch)

        // Each branch marked one of `second`'s two namespaces, so both are there only if `merge` unites them.
        XCTAssertEqual(parent.namespacesWithHolesFromPreviousState, [
            first: [Namespaces.Message.Cloud],
            second: [Namespaces.Message.Cloud, Namespaces.Message.Local]
        ])
    }
}
