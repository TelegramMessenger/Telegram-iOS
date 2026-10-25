import Foundation
import Postbox
import SwiftSignalKit
internal import TelegramApi
import MtProtoKit
import EncryptionProvider

/// Stories.
extension ReplayContext {
    func applyUpdateStory(_ peerId: PeerId, _ story: Api.StoryItem) {
        var updatedPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)
        let previousEntryStory = updatedPeerEntries.first(where: { item in
            return item.id == story.id
        }).flatMap { item -> Stories.Item? in
            if let value = item.value.get(Stories.StoredItem.self), case let .item(item) = value {
                return item
            } else {
                return nil
            }
        }

        let storedItem = Stories.StoredItem(apiStoryItem: story, existingItem: previousEntryStory, peerId: peerId, transaction: transaction)
        if let storedItem = storedItem {
            if let currentIndex = updatedPeerEntries.firstIndex(where: { $0.id == storedItem.id }) {
                if case .item = storedItem {
                    if let codedEntry = CodableEntry(storedItem) {
                        updatedPeerEntries[currentIndex] = StoryItemsTableEntry(value: codedEntry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends, isLiveStream: storedItem.isLiveStream)
                    }
                }
            } else {
                if let codedEntry = CodableEntry(storedItem) {
                    updatedPeerEntries.append(StoryItemsTableEntry(value: codedEntry, id: storedItem.id, expirationTimestamp: storedItem.expirationTimestamp, isCloseFriends: storedItem.isCloseFriends, isLiveStream: storedItem.isLiveStream))
                }
            }
            if case .item = storedItem {
                if let codedEntry = CodableEntry(storedItem) {
                    transaction.setStory(id: StoryId(peerId: peerId, id: storedItem.id), value: codedEntry)
                }
            }
        } else {
            if case let .storyItemDeleted(storyItemDeletedData) = story {
                if let index = updatedPeerEntries.firstIndex(where: { $0.id == storyItemDeletedData.id }) {
                    updatedPeerEntries.remove(at: index)
                }
            }
        }

        var appliedMaxReadId: Int32?
        if let currentState = transaction.getPeerStoryState(peerId: peerId)?.entry.get(Stories.PeerState.self) {
            if let appliedMaxReadIdValue = appliedMaxReadId {
                appliedMaxReadId = max(appliedMaxReadIdValue, currentState.maxReadId)
            } else {
                appliedMaxReadId = currentState.maxReadId
            }
        }

        transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)
        transaction.setPeerStoryState(peerId: peerId, state: Stories.PeerState(
            maxReadId: appliedMaxReadId ?? 0
        ).postboxRepresentation)

        // The item as stored: a min story takes its views, reaction, isMy and forward info from the
        // previous entry, which a parse without `existingItem` would drop from the event.
        if let storedItem = storedItem {
            storyUpdates.append(InternalStoryUpdate.added(peerId: peerId, item: storedItem))
        } else {
            storyUpdates.append(InternalStoryUpdate.deleted(peerId: peerId, id: story.id))
        }
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
        var updatedPeerEntries: [StoryItemsTableEntry] = transaction.getStoryItems(peerId: peerId)

        if let index = updatedPeerEntries.firstIndex(where: { item in
            return item.id == id
        }) {
            if let value = updatedPeerEntries[index].value.get(Stories.StoredItem.self), case let .item(item) = value {
                let updatedReaction = MessageReaction.Reaction(apiReaction: reaction)

                let updatedItem: Stories.StoredItem = .item(Stories.Item(
                    id: item.id,
                    timestamp: item.timestamp,
                    expirationTimestamp: item.expirationTimestamp,
                    media: item.media,
                    alternativeMediaList: item.alternativeMediaList,
                    mediaAreas: item.mediaAreas,
                    text: item.text,
                    entities: item.entities,
                    views: _internal_updateStoryViewsForMyReaction(isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, views: item.views, previousReaction: item.myReaction, reaction: updatedReaction),
                    privacy: item.privacy,
                    isPinned: item.isPinned,
                    isExpired: item.isExpired,
                    isPublic: item.isPublic,
                    isCloseFriends: item.isCloseFriends,
                    isContacts: item.isContacts,
                    isSelectedContacts: item.isSelectedContacts,
                    isForwardingDisabled: item.isForwardingDisabled,
                    isEdited: item.isEdited,
                    isMy: item.isMy,
                    myReaction: updatedReaction,
                    forwardInfo: item.forwardInfo,
                    music: item.music,
                    authorId: item.authorId,
                    folderIds: item.folderIds
                ))
                if let entry = CodableEntry(updatedItem) {
                    updatedPeerEntries[index] = StoryItemsTableEntry(value: entry, id: item.id, expirationTimestamp: item.expirationTimestamp, isCloseFriends: item.isCloseFriends, isLiveStream: item.isLiveStream)
                }
            }
        }
        transaction.setStoryItems(peerId: peerId, items: updatedPeerEntries)

        if let value = transaction.getStory(id: StoryId(peerId: peerId, id: id))?.get(Stories.StoredItem.self), case let .item(item) = value {
            let updatedReaction = MessageReaction.Reaction(apiReaction: reaction)

            let updatedItem: Stories.StoredItem = .item(Stories.Item(
                id: item.id,
                timestamp: item.timestamp,
                expirationTimestamp: item.expirationTimestamp,
                media: item.media,
                alternativeMediaList: item.alternativeMediaList,
                mediaAreas: item.mediaAreas,
                text: item.text,
                entities: item.entities,
                views: _internal_updateStoryViewsForMyReaction(isChannel: peerId.namespace == Namespaces.Peer.CloudChannel, views: item.views, previousReaction: item.myReaction, reaction: updatedReaction),
                privacy: item.privacy,
                isPinned: item.isPinned,
                isExpired: item.isExpired,
                isPublic: item.isPublic,
                isCloseFriends: item.isCloseFriends,
                isContacts: item.isContacts,
                isSelectedContacts: item.isSelectedContacts,
                isForwardingDisabled: item.isForwardingDisabled,
                isEdited: item.isEdited,
                isMy: item.isMy,
                myReaction: MessageReaction.Reaction(apiReaction: reaction),
                forwardInfo: item.forwardInfo,
                music: item.music,
                authorId: item.authorId,
                folderIds: item.folderIds
            ))
            if let entry = CodableEntry(updatedItem) {
                transaction.setStory(id: StoryId(peerId: peerId, id: id), value: entry)
                storyUpdates.append(InternalStoryUpdate.added(peerId: peerId, item: updatedItem))
            }
        }
    }
}
