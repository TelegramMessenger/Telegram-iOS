import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Stories.
extension ReplayContext {
    func applyUpdateStory(_ peerId: PeerId, _ story: Api.StoryItem) {
        _internal_invalidateStoryResolution(postbox: postbox, peerId: peerId, ids: [story.id])
        storyRefreshContext?.invalidate(peerId: peerId, ids: [story.id])
        if _internal_storyUpdatesViews(story) {
            storyViewRefreshContext?.invalidate(peerId: peerId, ids: [story.id])
        }
        storyUpdates.append(contentsOf: _internal_applyStoryUpdate(transaction: transaction, peerId: peerId, story: story, storyReactionContext: storyReactionContext))
    }
    
    func applyUpdateReadStories(_ peerId: PeerId, _ maxId: Int32) {
        var appliedMaxReadId = maxId
        if let currentState = transaction.getPeerStoryState(peerId: peerId)?.entry.get(Stories.PeerState.self) {
            appliedMaxReadId = max(appliedMaxReadId, currentState.maxReadId)
        }

        transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(
            maxReadId: appliedMaxReadId
        ).postboxRepresentation)

        storyUpdates.append(InternalStoryUpdate.read(peerId: peerId, maxId: maxId))
    }
    
    func applyUpdateStoryStealthMode(_ data: Api.StoriesStealthMode) {
        var configuration = _internal_getStoryConfigurationState(transaction: transaction)
        configuration.stealthModeState = Stories.StealthModeState(apiMode: data)
        _internal_setStoryConfigurationState(transaction: transaction, state: configuration)
    }
    
    func applyUpdateStorySentReaction(_ peerId: PeerId, _ id: Int32, _ reaction: Api.Reaction) {
        _internal_invalidateStoryResolution(postbox: postbox, peerId: peerId, ids: [id])
        storyRefreshContext?.invalidate(peerId: peerId, ids: [id])
        storyViewRefreshContext?.invalidate(peerId: peerId, ids: [id])
        var updatedReaction = MessageReaction.Reaction(apiReaction: reaction)
        if let storyReactionContext, let pendingReaction = storyReactionContext.pendingReaction(for: StoryId(peerId: peerId, id: id)) {
            if updatedReaction != pendingReaction {
                storyReactionContext.requireRefresh(for: StoryId(peerId: peerId, id: id))
            }
            updatedReaction = pendingReaction
        }
        _ = _internal_applyStoryReaction(transaction: transaction, peerId: peerId, id: id, reaction: updatedReaction)
        storyUpdates.append(.updateMyReaction(peerId: peerId, id: id, reaction: updatedReaction))
    }
}
