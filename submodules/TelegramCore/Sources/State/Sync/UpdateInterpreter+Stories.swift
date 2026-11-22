import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Stories.
extension UpdateInterpreter {
    mutating func applyStory(_ updateStoryData: Api.Update.Cons_updateStory) {
        updatedState.updateStory(peerId: updateStoryData.peer.peerId, story: updateStoryData.story)
    }
    
    mutating func applyReadStories(_ updateReadStoriesData: Api.Update.Cons_updateReadStories) {
        updatedState.readStories(peerId: updateReadStoriesData.peer.peerId, maxId: updateReadStoriesData.maxId)
    }
    
    mutating func applyStoriesStealthMode(_ updateStoriesStealthModeData: Api.Update.Cons_updateStoriesStealthMode) {
        updatedState.updateStoryStealthMode(updateStoriesStealthModeData.stealthMode)
    }
    
    mutating func applySentStoryReaction(_ updateSentStoryReactionData: Api.Update.Cons_updateSentStoryReaction) {
        updatedState.updateStorySentReaction(peerId: updateSentStoryReactionData.peer.peerId, id: updateSentStoryReactionData.storyId, reaction: updateSentStoryReactionData.reaction)
    }
}
