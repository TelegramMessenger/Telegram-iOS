import Foundation
import Postbox
import TelegramCore
import SwiftSignalKit

struct PeerMessageHistoryAudioPlaylistItemId: AudioPlaylistItemId {
    let id: MessageId
    
    var hashValue: Int {
        return self.id.hashValue
    }
    
    func isEqual(to: AudioPlaylistItemId) -> Bool {
        if let other = to as? PeerMessageHistoryAudioPlaylistItemId {
            return self.id == other.id
        } else {
            return false
        }
    }
}

private final class PeerMessageHistoryAudioPlaylistItem: AudioPlaylistItem {
    let entry: MessageHistoryEntry
    
    var id: AudioPlaylistItemId {
        return PeerMessageHistoryAudioPlaylistItemId(id: self.entry.index.id)
    }
    
    var resource: MediaResource? {
        switch self.entry {
            case let .MessageEntry(message, _, _):
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        return file.resource
                    }
                }
                return nil
            case .HoleEntry:
                return nil
        }
    }
    
    var info: AudioPlaylistItemInfo? {
        switch self.entry {
            case let .MessageEntry(message, _, _):
                for media in message.media {
                    if let file = media as? TelegramMediaFile {
                        for attribute in file.attributes {
                            if case let .Audio(isVoice, duration, title, performer, waveform: nil) = attribute {
                                if isVoice {
                                    return AudioPlaylistItemInfo(duration: Double(duration), labelInfo: .voice)
                                } else {
                                    return AudioPlaylistItemInfo(duration: Double(duration), labelInfo: .music(title: title, performer: performer))
                                }
                            }
                        }
                        return nil
                    }
                }
            case .HoleEntry:
                break
        }
        
        return nil
    }
    
    init(entry: MessageHistoryEntry) {
        self.entry = entry
    }
    
    func isEqual(to: AudioPlaylistItem) -> Bool {
        if let other = to as? PeerMessageHistoryAudioPlaylistItem {
            return self.entry == other.entry
        } else {
            return false
        }
    }
}

struct PeerMessageHistoryAudioPlaylistId: AudioPlaylistId {
    let peerId: PeerId
    
    func isEqual(to: AudioPlaylistId) -> Bool {
        if let other = to as? PeerMessageHistoryAudioPlaylistId {
            if self.peerId != other.peerId {
                return false
            }
            return true
        } else {
            return false
        }
    }
}

func peerMessageAudioPlaylistAndItemIds(_ message: Message) -> (AudioPlaylistId, AudioPlaylistItemId)? {
    return (PeerMessageHistoryAudioPlaylistId(peerId: message.id.peerId), PeerMessageHistoryAudioPlaylistItemId(id: message.id))
}

func peerMessageHistoryAudioPlaylist(account: Account, messageId: MessageId) -> AudioPlaylist {
    return AudioPlaylist(id: PeerMessageHistoryAudioPlaylistId(peerId: messageId.peerId), navigate: { item, navigation in
        if let item = item as? PeerMessageHistoryAudioPlaylistItem {
            return account.postbox.aroundMessageHistoryViewForPeerId(item.entry.index.id.peerId, index: item.entry.index, count: 10, anchorIndex: item.entry.index, fixedCombinedReadState: nil, topTaggedMessageIdNamespaces: [], tagMask: .Music)
                |> take(1)
                |> map { (view, _, _) -> AudioPlaylistItem? in
                    var index = 0
                    for entry in view.entries {
                        if entry.index.id == item.entry.index.id {
                            switch navigation {
                                case .previous:
                                    if index + 1 < view.entries.count {
                                        return PeerMessageHistoryAudioPlaylistItem(entry: view.entries[index + 1])
                                    } else {
                                        return PeerMessageHistoryAudioPlaylistItem(entry: view.entries.last!)
                                    }
                                case .next:
                                    if index != 0 {
                                        return PeerMessageHistoryAudioPlaylistItem(entry: view.entries[index - 1])
                                    } else {
                                        return PeerMessageHistoryAudioPlaylistItem(entry: view.entries.first!)
                                    }
                            }
                        }
                        index += 1
                    }
                    if !view.entries.isEmpty {
                        return PeerMessageHistoryAudioPlaylistItem(entry: view.entries.first!)
                    } else {
                        return nil
                    }
                }
        } else {
            return account.postbox.messageAtId(messageId)
                |> map { message -> AudioPlaylistItem? in
                    if let message = message {
                        return PeerMessageHistoryAudioPlaylistItem(entry: .MessageEntry(message, false, nil))
                    } else {
                        return nil
                    }
                }
        }
    })
}
