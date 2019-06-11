import Foundation
import Postbox
import TelegramCore

func chatHistoryEntriesForView(location: ChatLocation, view: MessageHistoryView, includeUnreadEntry: Bool, includeEmptyEntry: Bool, includeChatInfoEntry: Bool, includeSearchEntry: Bool, reverse: Bool, groupMessages: Bool, selectedMessages: Set<MessageId>?, presentationData: ChatPresentationData, historyAppearsCleared: Bool) -> [ChatHistoryEntry] {
    if historyAppearsCleared {
        return []
    }
    var entries: [ChatHistoryEntry] = []
    var adminIds = Set<PeerId>()
    if case let .peer(peerId) = location, peerId.namespace == Namespaces.Peer.CloudChannel {
        for additionalEntry in view.additionalData {
            if case let .cacheEntry(id, data) = additionalEntry {
                if id == cachedChannelAdminIdsEntryId(peerId: peerId), let data = data as? CachedChannelAdminIds {
                    adminIds = data.ids
                }
                break
            }
        }
    }
    
    var groupBucket: [(Message, Bool, ChatHistoryMessageSelection, ChatMessageEntryAttributes)] = []
    loop: for entry in view.entries {
        if entry.message.id.peerId.namespace == Namespaces.Peer.CloudChannel || entry.message.id.peerId.namespace == Namespaces.Peer.CloudUser {
            for media in entry.message.media {
                if let action = media as? TelegramMediaAction {
                    switch action.action {
                        case .channelMigratedFromGroup, .groupMigratedToChannel, .historyCleared:
                            continue loop
                        default:
                            break
                    }
                }
            }
        }
    
        var isAdmin = false
        if let author = entry.message.author {
            isAdmin = adminIds.contains(author.id)
        }
    
        if groupMessages {
            if !groupBucket.isEmpty && entry.message.groupInfo != groupBucket[0].0.groupInfo {
                entries.append(.MessageGroupEntry(groupBucket[0].0.groupInfo!, groupBucket, presentationData))
                groupBucket.removeAll()
            }
            if let _ = entry.message.groupInfo {
                let selection: ChatHistoryMessageSelection
                if let selectedMessages = selectedMessages {
                    selection = .selectable(selected: selectedMessages.contains(entry.message.id))
                } else {
                    selection = .none
                }
                groupBucket.append((entry.message, entry.isRead, selection, ChatMessageEntryAttributes(isAdmin: isAdmin, isContact: entry.attributes.authorIsContact)))
            } else {
                let selection: ChatHistoryMessageSelection
                if let selectedMessages = selectedMessages {
                    selection = .selectable(selected: selectedMessages.contains(entry.message.id))
                } else {
                    selection = .none
                }
                entries.append(.MessageEntry(entry.message, presentationData, entry.isRead, entry.monthLocation, selection, ChatMessageEntryAttributes(isAdmin: isAdmin, isContact: entry.attributes.authorIsContact)))
            }
        } else {
            let selection: ChatHistoryMessageSelection
            if let selectedMessages = selectedMessages {
                selection = .selectable(selected: selectedMessages.contains(entry.message.id))
            } else {
                selection = .none
            }
            entries.append(.MessageEntry(entry.message, presentationData, entry.isRead, entry.monthLocation, selection, ChatMessageEntryAttributes(isAdmin: isAdmin, isContact: entry.attributes.authorIsContact)))
        }
    }
    
    if !groupBucket.isEmpty {
        assert(groupMessages)
        entries.append(.MessageGroupEntry(groupBucket[0].0.groupInfo!, groupBucket, presentationData))
    }
    
    if let maxReadIndex = view.maxReadIndex, includeUnreadEntry {
        var i = 0
        let unreadEntry: ChatHistoryEntry = .UnreadEntry(maxReadIndex, presentationData)
        for entry in entries {
            if entry > unreadEntry {
                entries.insert(unreadEntry, at: i)
                break
            }
            i += 1
        }
    }
    
    if includeChatInfoEntry {
        if view.earlierId == nil {
            var cachedPeerData: CachedPeerData?
            for entry in view.additionalData {
                if case let .cachedPeerData(_, data) = entry {
                    cachedPeerData = data
                    break
                }
            }
            if let cachedPeerData = cachedPeerData as? CachedUserData, let botInfo = cachedPeerData.botInfo, !botInfo.description.isEmpty {
                entries.insert(.ChatInfoEntry(botInfo.description, presentationData), at: 0)
            }
            var isEmpty = true
            if entries.count <= 3 {
                loop: for entry in view.entries {
                    var isEmptyMedia = false
                    for media in entry.message.media {
                        if let action = media as? TelegramMediaAction {
                            switch action.action {
                                case .groupCreated, .photoUpdated, .channelMigratedFromGroup, .groupMigratedToChannel:
                                    isEmptyMedia = true
                                default:
                                    break
                            }
                        }
                    }
                    var isCreator = false
                    if let peer = entry.message.peers[entry.message.id.peerId] as? TelegramGroup, case .creator = peer.role {
                        isCreator = true
                    } else if let peer = entry.message.peers[entry.message.id.peerId] as? TelegramChannel, case .group = peer.info, peer.flags.contains(.isCreator) {
                        isCreator = true
                    }
                    if isEmptyMedia && isCreator {
                    } else {
                        isEmpty = false
                        break loop
                    }
                }
            } else {
                isEmpty = false
            }
            if isEmpty {
                entries.removeAll()
            }
        }
    } else if includeSearchEntry {
        if view.laterId == nil {
            if !view.entries.isEmpty {
                entries.append(.SearchEntry(presentationData.theme.theme, presentationData.strings))
            }
        }
    }
    
    if reverse {
        return entries.reversed()
    } else {
        return entries
    }
}
